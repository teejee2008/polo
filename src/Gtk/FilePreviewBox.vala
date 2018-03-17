/*
 * FilePreviewBox.vala
 *
 * Copyright 2012-18 Tony George <teejeetech@gmail.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
 * MA 02110-1301, USA.
 *
 *
 */

using Gtk;
using Gee;

using TeeJee.Logging;
using TeeJee.FileSystem;
using TeeJee.JsonHelper;
using TeeJee.ProcessHelper;
using TeeJee.GtkHelper;
using TeeJee.System;
using TeeJee.Misc;

public class FilePreviewBox : Gtk.Box {

	private FileItem file_item;
	private MediaFile mfile;

	private Gtk.DrawingArea canvas;
	private MediaPlayer mpv;
	private Gtk.Image image;
	private Gtk.Box box_controls;

	private Gtk.Window window;

	private bool panel_mode = false;

	// player ui
	private Gtk.Scale scale_pos;
	private Gtk.Scale scale_vol;
	private Gtk.Button btn_play;
	private Gtk.Button btn_mute;
	private Gtk.Button btn_fullscreen;
	private uint tmr_status = 0;

	public FilePreviewBox(Gtk.Window parent_window, bool _panel_mode){
		//base(Gtk.Orientation.VERTICAL, 6); // issue with vala
		Object(orientation: Gtk.Orientation.VERTICAL, spacing: 0); // work-around

		window = parent_window;

		panel_mode = _panel_mode;

		init_ui();
	}

	private void init_ui(){

		init_ui_player();

		init_ui_player_controls();

		init_ui_image();
		
		this.expand = true;
	}

	private void init_ui_player(){

		canvas = new Gtk.DrawingArea();
		canvas.set_size_request(256,256);
		canvas.expand = true;
		//canvas.halign = Align.CENTER;
		//this.pack_start(canvas, true, true, 0);
		this.add(canvas);

		box_controls = new Gtk.Box(Orientation.HORIZONTAL, 6);
		box_controls.margin = 6;
		this.add(box_controls);

		if (cmd_exists("mpv")){
			mpv = new MediaPlayer("mpv");
		}
		else if (cmd_exists("mplayer2")){
			mpv = new MediaPlayer("mplayer2");
		}
		else
		if (cmd_exists("mplayer")){
			mpv = new MediaPlayer("mplayer");
		}
		else {
			mpv = null;
		}
		
		if (mpv != null){

			mpv.volume = App.audio_volume;

			mpv.is_muted = App.audio_muted;

			mpv.is_paused = App.playback_paused;
			
			this.canvas.realize.connect(() => {
				mpv.window_id = get_widget_xid(canvas);
				mpv.start_player();
			});
		}

		gtk_hide(canvas);

		gtk_hide(box_controls);
	}

	private void init_ui_image(){

		image = new Gtk.Image();
		image.xalign = 0.5f;
		image.yalign = 0.5f;
		this.add(image);

		image.expand = true;

		gtk_hide(image);
	}
	
	public void preview_file(FileItem _file_item){

		log_debug("FilePreviewBox: preview_file()");
		
		file_item = _file_item;

		gtk_hide(canvas);
		gtk_hide(box_controls);
		gtk_hide(image);

		if (file_item.is_mplayer_supported && (mpv != null)){

			preview_mplayer();
			
			return;
		}
		
		if (file_item.is_image_gdk_supported){

			if (preview_image()){
				
				return;
			}
		}

		preview_thumbnail();
	}

	private bool preview_image(){
	
		log_debug("FilePreviewBox: preview_image()");

		gtk_show(image);

		try{
			var pix = new Gdk.Pixbuf.from_file_at_scale(file_item.file_path, 256, 256, true);
			pix = IconManager.resize_icon(pix, 256);
			image.set_from_pixbuf(pix);
			return true;
		}
		catch(Error e){
			//ignore
		}

		return false;
	}

	private bool preview_thumbnail(){

		log_debug("FilePreviewBox: preview_thumbnail()");

		gtk_show(image);
		
		ThumbTask task;
		var thumb = file_item.get_image(256, true, false, false, out task);

		if (task != null){
			while (!task.completed){
				sleep(100);
				gtk_do_events();
			}
			thumb = file_item.get_image(256, true, false, false, out task);
		}
		
		if (thumb != null) {
			image.pixbuf = thumb;
			log_debug("setting from file_item.get_image()");
		}
		else if (file_item.icon != null) {
			image.gicon = file_item.icon;
			log_debug("setting from file_item.gicon");
		}
		else{
			if (file_item.file_type == FileType.DIRECTORY) {
				image.pixbuf = IconManager.generic_icon_directory(256);
			}
			else{
				image.pixbuf = IconManager.generic_icon_file(256);
			}
		}

		return true;
	}

	private bool preview_mplayer(){

		log_debug("FilePreviewBox: preview_mplayer()");
		
		gtk_show(canvas);
		
		gtk_show(box_controls);

		log_debug("FilePreviewBox: new MediaFile()");

		mfile = new MediaFile(file_item.file_path);

		log_debug("FilePreviewBox: query_mediainfo_formatted");
		
		mfile.query_mediainfo_formatted();

		//log_debug("FilePreviewBox: mpv.Open()");
	
		if (mpv != null){
			
			//mpv.detect_borders(mfile);
			
			//mpv.StartPlayerWithCropFilter();

			//mpv.StartPlayer();
			
			update_player_controls_for_file();

			mpv.open_file(mfile, App.playback_paused, App.audio_muted, true, App.audio_volume);
		}

		log_debug("FilePreviewBox: preview_mplayer(): done");

		return true;
	}

	public void stop(){
		
		mpv.playback_stop();
	}

	public void quit(){
		
		mpv.quit();
	}

	// player ui --------------------

	private void init_ui_player_controls(){

		log_debug("FilePreviewBox: init_ui_player_controls()");
	
		//btn_play
		btn_play = new Gtk.Button();
		btn_play.always_show_image = true;
		box_controls.add(btn_play);

		btn_play.clicked.connect(btn_pause_clicked);

		//btn_mute
		btn_mute = new Gtk.Button();
		btn_mute.always_show_image = true;
		box_controls.add(btn_mute);

		btn_mute.clicked.connect(btn_mute_clicked);

		//scale_pos
		scale_pos = new Gtk.Scale.with_range (Gtk.Orientation.HORIZONTAL, 0, 1000, 1);
		scale_pos.adjustment.value = 0;
		//scale_pos.has_origin = true;
		scale_pos.value_pos = PositionType.BOTTOM;
		scale_pos.hexpand = true;
		scale_pos.set_size_request(100,-1);
		box_controls.add(scale_pos);

		//scale_pos_value_changed_connect();
		
		scale_pos.format_value.connect(scale_pos_format_value);

		//scale_vol
		scale_vol = new Gtk.Scale.with_range (Gtk.Orientation.HORIZONTAL, 0, 100, 1);
		scale_vol.adjustment.value = App.audio_volume;
		scale_vol.has_origin = true;
		scale_vol.value_pos = PositionType.BOTTOM;
		scale_vol.hexpand = false;
		scale_vol.set_size_request(50,-1);
		box_controls.add(scale_vol);

		scale_vol.value_changed.connect(scale_vol_value_changed);

		set_play_icon();
		set_mute_icon();
		set_fullscreen_icon();

		status_timer_start();
	}
	
	private void update_player_controls_for_file(){

		status_timer_stop();
		
		log_debug("FilePreviewBox: update_player_controls_for_file()");

		// set scale_pos ----------------------------
		
		scale_pos.value_changed.disconnect(scale_pos_value_changed);

		scale_pos.adjustment.value = 0;
		
		scale_pos.value_changed.connect(scale_pos_value_changed);

		// set scale_vol -------------------
		
		scale_vol.value_changed.disconnect(scale_vol_value_changed);

		scale_vol.adjustment.value = App.audio_volume;
		
		scale_vol.value_changed.connect(scale_vol_value_changed);

		// set icons -----------------------
		
		set_play_icon();
		
		set_mute_icon();
		
		set_fullscreen_icon();

		btn_mute.visible = mfile.HasAudio;
		
		btn_fullscreen.visible = mfile.HasVideo;

		scale_pos.adjustment.upper = (mfile.Duration/1000.0);
		
		status_timer_start();
	}

	private string scale_pos_format_value(double val){
		
		if (mfile == null){
			return "";
		}
		else{
			return format_duration((long) (val * 1000.0)) + " / " + format_duration(mfile.Duration);
		}
	}
	
	private void scale_pos_value_changed(){
		
		mpv.seek(scale_pos.get_value());
	}

	private void scale_vol_value_changed(){
		
		int vol = (int) scale_vol.adjustment.value;
		
		mpv.set_volume(vol);
		
		App.audio_volume = vol;
	}

	private void btn_mute_clicked(){

		log_debug("FilePreviewBox: btn_mute_clicked()");
		
		if (mpv.is_muted){
			mpv.unmute();
		}
		else{
			mpv.mute();
		}
		
		set_mute_icon();

		App.audio_muted = mpv.is_muted;
		
		log_msg("audio_muted: " + App.audio_muted.to_string());
	}

	private void btn_pause_clicked(){

		log_debug("FilePreviewBox: btn_pause_clicked()");

		mpv.toggle_pause();
		
		set_play_icon();
		
		App.playback_paused = mpv.is_paused;
		
		log_msg("playback_paused: " + App.audio_muted.to_string());
	}

	private int BUTTON_ICON_SIZE = 16;

	private void set_play_icon(){
		
		if (mpv.is_paused){
			btn_play.set_tooltip_text (_("Play"));
			btn_play.image = IconManager.lookup_image("media-playback-start-symbolic", BUTTON_ICON_SIZE);
		}
		else{
			btn_play.set_tooltip_text (_("Pause"));
			btn_play.image = IconManager.lookup_image("media-playback-pause-symbolic", BUTTON_ICON_SIZE);
		}
		
		gtk_do_events();
	}
	
	private void set_mute_icon(){
		
		if (mpv.is_muted){
			btn_mute.set_tooltip_text (_("Mute"));
			btn_mute.image = IconManager.lookup_image("audio-volume-muted-symbolic", BUTTON_ICON_SIZE);
		}
		else{
			btn_mute.set_tooltip_text (_("Mute"));
			btn_mute.image = IconManager.lookup_image("audio-volume-high-symbolic", BUTTON_ICON_SIZE);
		}
		
		gtk_do_events();
	}

	private void set_fullscreen_icon(){
		
		btn_fullscreen.set_tooltip_text (_("Fullscreen"));
		btn_fullscreen.image = IconManager.lookup_image("view-fullscreen-symbolic", BUTTON_ICON_SIZE);
		
		gtk_do_events();
	}

	private void status_timer_start(){
		
		status_timer_stop();

		tmr_status = Timeout.add(1000, status_timeout);
	}

	private void status_timer_stop(){
		
		if (tmr_status > 0) {
			Source.remove(tmr_status);
			tmr_status = 0;
		}
	}
	
	private bool status_timeout(){

		log_debug("FilePreviewBox: status_timeout()");
		
		scale_pos.value_changed.disconnect(scale_pos_value_changed);
		scale_pos.adjustment.value = (double) mpv.position;
		scale_pos.value_changed.connect(scale_pos_value_changed);

		set_play_icon();
		
		set_mute_icon();

		gtk_do_events();

		return true;
	}
}


