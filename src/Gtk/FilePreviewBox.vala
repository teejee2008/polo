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
	private Gtk.Scale scalePos;
	private Gtk.Scale scaleVolume;
	private Gtk.Button btnPlay;
	private Gtk.Button btnMute;
	private Gtk.Button btnFullscreen;
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

			mpv.Volume = App.audio_volume;
			
			this.canvas.realize.connect(() => {
				mpv.WindowID = get_widget_xid(canvas);
				mpv.StartPlayer();
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

		gtk_show(canvas);
		gtk_show(box_controls);

		log_debug("FilePreviewBox: preview_mplayer()");

		mfile = new MediaFile(file_item.file_path);

		mfile.query_mediainfo_formatted();

		//log_debug("FilePreviewBox: mpv.Open()");
	
		if (mpv != null){
			
			//mpv.detect_borders(mfile);
			
			//mpv.StartPlayerWithCropFilter();

			//mpv.StartPlayer();
			
			update_player_controls_for_file();

			mpv.Open(mfile, false, false, true);
		}

		log_debug("FilePreviewBox: preview_mplayer(): done");

		return true;
	}

	public void stop(){
		mpv.Stop();
	}

	public void quit(){
		mpv.Quit();
	}

	// player ui --------------------

	private void update_player_controls_for_file(){

		gtk_container_remove_children(box_controls);
		
		//btnPlay
		btnPlay = new Gtk.Button();
		btnPlay.always_show_image = true;
		box_controls.add(btnPlay);

		btnPlay.clicked.connect(() => {
			mpv.PauseToggle();
			set_play_icon();
		});

		//btnMute
		btnMute = new Gtk.Button();
		btnMute.always_show_image = true;
		box_controls.add(btnMute);

		btnMute.clicked.connect(() => {
			if (mpv.IsMuted){
				mpv.UnMute();
			}
			else{
				mpv.Mute();
			}
			set_mute_icon();
		});

		//btnFullscreen
		/*btnFullscreen = new Gtk.Button();
		btnFullscreen.always_show_image = true;
		box_controls.add(btnFullscreen);

		btnFullscreen.clicked.connect(() => {
			mpv.ToggleFullScreen();
			//IsMaximized = !IsMaximized;
			if (IsMaximized){
				//this.fullscreen();
				//vboxMain.set_child_packing(canvas, true, true, 0, Gtk.PackType.START);
				//canvas.halign = Align.FILL;
				//canvas.valign = Align.FILL;
			}
			else{
				//this.unfullscreen();
			}
			set_fullscreen_icon();
		});*/


		//scalePos
		scalePos = new Gtk.Scale.with_range (Gtk.Orientation.HORIZONTAL, 0, 1000, 1);
		scalePos.adjustment.value = 0;
		//scalePos.has_origin = true;
		scalePos.value_pos = PositionType.BOTTOM;
		scalePos.hexpand = true;
		scalePos.set_size_request(100,-1);
		box_controls.add(scalePos);

		scalePos_value_changed_connect();
		
		scalePos.format_value.connect((val)=>{
			return format_duration((long) (val * 1000.0)) + " / " + format_duration(mfile.Duration);
		});

		//scaleVolume
		scaleVolume = new Gtk.Scale.with_range (Gtk.Orientation.HORIZONTAL, 0, 100, 1);
		scaleVolume.adjustment.value = App.audio_volume;
		scaleVolume.has_origin = true;
		scaleVolume.value_pos = PositionType.BOTTOM;
		scaleVolume.hexpand = false;
		scaleVolume.set_size_request(50,-1);
		box_controls.add(scaleVolume);

		scaleVolume.value_changed.connect(()=>{
			int vol = (int)scaleVolume.adjustment.value;
			mpv.SetVolume(vol);
			App.audio_volume = vol;
		});

		set_play_icon();
		set_mute_icon();
		set_fullscreen_icon();

		btnMute.visible = mfile.HasAudio;
		
		btnFullscreen.visible = mfile.HasVideo;

		scalePos.adjustment.upper = (mfile.Duration/1000.0);
		
		status_timer_start();
	}

	private void scalePos_value_changed(){
		mpv.Seek(scalePos.get_value());
	}
	
	private void scalePos_value_changed_connect(){
		scalePos.value_changed.connect(scalePos_value_changed);
	}

	private void scalePos_value_changed_disconnect(){
		scalePos.value_changed.disconnect(scalePos_value_changed);
	}

	private int BUTTON_ICON_SIZE = 16;

	private void set_play_icon(){
		
		if (mpv.IsPaused){
			btnPlay.set_tooltip_text (_("Play"));
			btnPlay.image = IconManager.lookup_image("media-playback-start-symbolic", BUTTON_ICON_SIZE);
		}
		else{
			btnPlay.set_tooltip_text (_("Pause"));
			btnPlay.image = IconManager.lookup_image("media-playback-pause-symbolic", BUTTON_ICON_SIZE);
		}
		
		gtk_do_events();
	}
	
	private void set_mute_icon(){
		
		if (mpv.IsMuted){
			btnMute.set_tooltip_text (_("Mute"));
			btnMute.image = IconManager.lookup_image("audio-volume-muted-symbolic", BUTTON_ICON_SIZE);
		}
		else{
			btnMute.set_tooltip_text (_("Mute"));
			btnMute.image = IconManager.lookup_image("audio-volume-high-symbolic", BUTTON_ICON_SIZE);
		}
		
		gtk_do_events();
	}

	private void set_fullscreen_icon(){
		
		btnFullscreen.set_tooltip_text (_("Fullscreen"));
		btnFullscreen.image = IconManager.lookup_image("view-fullscreen-symbolic", BUTTON_ICON_SIZE);
		
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
		
		status_timer_stop();

		scalePos_value_changed_disconnect();
		scalePos.adjustment.value = (double) mpv.Position;
		scalePos_value_changed_connect();

		set_play_icon();
		set_mute_icon();

		gtk_do_events();

		status_timer_start();
		return true;
	}
}


