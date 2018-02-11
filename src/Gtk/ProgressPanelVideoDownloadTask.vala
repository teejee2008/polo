/*
 * ProgressPanelVideoDownloadTask.vala
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

public class ProgressPanelVideoDownloadTask : ProgressPanel {

	private VideoDownloadTask task;
	private string url;
	private bool fetch_in_progress = false;
	
	private const int FETCH_WAIT_INTERVAL = 15000;
	private int fetch_wait_interval = FETCH_WAIT_INTERVAL;
	
	// ui 
	public Gtk.Label lbl_status;
	public Gtk.Label lbl_stats;
	public Gtk.ProgressBar progressbar;

	public ProgressPanelVideoDownloadTask(FileViewPane _pane, string _url){
		base(_pane, null, FileActionType.VIDEO_LIST_FORMATS);

		url = _url;
	}

	public override void init_ui(){ // TODO: make protected
		init_ui_parser();
	}

	public void init_ui_parser(){
		
		gtk_container_remove_children(contents);

		string txt = _("Fetching info...");

		// heading ----------------

		var label = new Gtk.Label("<b>" + txt + "</b>");
		label.set_use_markup(true);
		label.xalign = 0.0f;
		label.margin_bottom = 12;
		contents.add(label);
		
		var hbox_outer = new Gtk.Box(Orientation.HORIZONTAL, 6);
		hbox_outer.margin_right = 6;
		contents.add(hbox_outer);

		var vbox_outer = new Gtk.Box(Orientation.VERTICAL, 6);
		hbox_outer.add(vbox_outer);

		var hbox = new Gtk.Box(Orientation.HORIZONTAL, 6);
		vbox_outer.add(hbox);

		// spinner ------------------------------------

		var spinner = new Gtk.Spinner();
		spinner.start();
		hbox.add(spinner);

		// status message -------------------------------------

		label = new Gtk.Label(_("Fetching info..."));
		label.xalign = 0.0f;
		label.ellipsize = Pango.EllipsizeMode.START;
		label.max_width_chars = 100;
		hbox.add(label);
		lbl_status = label;

		// spacer
		label = new Gtk.Label("");
		label.hexpand = true;
		hbox.add(label);

		// cancel button ------------------------------

		var button = new Gtk.Button.with_label("");
		button.label = "";
		button.image = IconManager.lookup_image("process-stop", 32);
		button.always_show_image = true;
		button.set_tooltip_text(_("Cancel"));
		hbox.add(button);

		button.clicked.connect(()=>{
			cancel();
		});

		// ------------------------------------------

		hbox.margin_bottom = 6;

		show_all();
	}

	public void init_ui_selection(){
		
		gtk_container_remove_children(contents);

		var hbox_outer = new Gtk.Box(Orientation.HORIZONTAL, 6);
		contents.add(hbox_outer);

		var vbox_info = new Gtk.Box(Orientation.VERTICAL, 6);
		hbox_outer.add(vbox_info);

		var vbox_thumb = new Gtk.Box(Orientation.VERTICAL, 6);
		hbox_outer.add(vbox_thumb);

		// scrolled
		var scrolled = new Gtk.ScrolledWindow(null, null);
		scrolled.set_shadow_type (ShadowType.ETCHED_IN);
		scrolled.hscrollbar_policy = PolicyType.AUTOMATIC;
		scrolled.vscrollbar_policy = PolicyType.AUTOMATIC;
		scrolled.expand = true;

		var vbox = new Gtk.Box(Orientation.VERTICAL, 0);
		vbox.margin = 6;
		
		scrolled.add(vbox);
		contents.add(scrolled);

		var hbox = new Gtk.Box(Orientation.HORIZONTAL, 6);
		contents.add(hbox);

		// -----------------------------

		Gtk.RadioButton? radio = null;
		Gtk.RadioButton? last_radio = null;

		if (task.list.size > 1){

			// best 
			
			radio = new Gtk.RadioButton.with_label_from_widget(last_radio, _("Best (audio + video)"));
			vbox.add(radio);
			last_radio = radio;

			radio.toggled.connect(()=>{
				task.format = "best";
				log_debug("task.set_format: %s".printf(task.format));
			});

			// best video
			
			radio = new Gtk.RadioButton.with_label_from_widget(last_radio, _("Best (audio only)"));
			vbox.add(radio);
			last_radio = radio;

			radio.toggled.connect(()=>{
				task.format = "bestaudio";
				log_debug("task.set_format: %s".printf(task.format));
			});

			// best audio
			
			radio = new Gtk.RadioButton.with_label_from_widget(last_radio, _("Best (video only)"));
			vbox.add(radio);
			last_radio = radio;

			radio.toggled.connect(()=>{
				task.format = "bestvideo";
				log_debug("task.set_format: %s".printf(task.format));
			});

			// best video + audio
			
			radio = new Gtk.RadioButton.with_label_from_widget(last_radio, _("Best Video + Best Audio (merge)"));
			vbox.add(radio);
			last_radio = radio;

			radio.toggled.connect(()=>{
				task.format = "bestvideo+bestaudio";
				log_debug("task.set_format: %s".printf(task.format));
			});
		}
			
		foreach(var item in task.list){
			
			radio = new Gtk.RadioButton.with_label_from_widget(last_radio, item.description);
			vbox.add(radio);
			last_radio = radio;

			radio.set_tooltip_text(item.tooltip_text);

			radio.toggled.connect(()=>{
				task.format = item.code;
				log_debug("task.set_format: %s".printf(task.format));
			});
		}

		// info ----------------------------

		var sg_label = new Gtk.SizeGroup(Gtk.SizeGroupMode.HORIZONTAL);
		var sg_info = new Gtk.SizeGroup(Gtk.SizeGroupMode.HORIZONTAL);
		
		ui_add_info_title(vbox_info, sg_label, sg_info);

		ui_add_info_url(vbox_info, sg_label, sg_info);
		
		ui_add_info_duration(vbox_info, sg_label, sg_info);

		ui_add_header(vbox_info);
		
		// image ---------------------------

		try {
			if (file_exists(task.thumb_path)){
				var pixbuf = new Gdk.Pixbuf.from_file_at_scale(task.thumb_path, -1, 128, true);
				var img = new Gtk.Image.from_pixbuf(pixbuf);
				vbox_thumb.add(img);
			}
		}
		catch (Error e){
			log_error(e.message);
		}

		// download -----------------------------------------
		
		var button = new Gtk.Button.with_label(_("Download"));
		button.set_tooltip_text(_("Download Selected Format"));
		hbox.add(button);

		button.clicked.connect(()=>{
			task.action = VideoDownloadTaskType.DOWNLOAD_VIDEO;
			init_ui_download();
			start_task();
		});

		// cancel -----------------------------------------

		button = new Gtk.Button.with_label(_("Cancel"));
		button.set_tooltip_text(_("Cancel"));
		hbox.add(button);

		button.clicked.connect(()=>{
			cancel();
		});

		show_all();
	}

	public void ui_add_header(Gtk.Box box){

		string txt = _("Select Format") + ":";
		var label = new Gtk.Label("<b>" + txt + "</b>");
		label.set_use_markup(true);
		label.xalign = 0.0f;
		label.yalign = 1.0f;
		label.margin_top = 6;
		box.add(label);
	}

	public void ui_add_info_title(Gtk.Box box, Gtk.SizeGroup sg_label, Gtk.SizeGroup sg_info){

		if (task.title.length == 0){ return; }
		
		var hbox = new Gtk.Box(Orientation.HORIZONTAL, 6);
		box.add(hbox);

		// label ----------------
		
		var label = new Gtk.Label (_("Title") + ":");
		label.xalign = 1.0f;
		hbox.add(label);
		
		sg_label.add_widget(label);

		// entry ----------------
		
		var entry = new Gtk.Entry();
		entry.hexpand = true;
		entry.set_size_request(200,-1);
		hbox.add(entry);

		entry.editable = false;

		entry.text = task.title;

		sg_info.add_widget(entry);
	}

	public void ui_add_info_duration(Gtk.Box box, Gtk.SizeGroup sg_label, Gtk.SizeGroup sg_info){

		if (task.duration.length == 0){ return; }
		
		var hbox = new Gtk.Box(Orientation.HORIZONTAL, 6);
		box.add(hbox);

		// label ----------------
		
		var label = new Gtk.Label (_("Duration") + ":");
		label.xalign = 1.0f;
		hbox.add(label);
		
		sg_label.add_widget(label);

		// entry ----------------
		
		var entry = new Gtk.Entry();
		entry.hexpand = true;
		entry.set_size_request(200,-1);
		hbox.add(entry);

		entry.editable = false;

		entry.text = task.duration;

		sg_info.add_widget(entry);
	}

	public void ui_add_info_url(Gtk.Box box, Gtk.SizeGroup sg_label, Gtk.SizeGroup sg_info){

		if (task.url.length == 0){ return; }
		
		var hbox = new Gtk.Box(Orientation.HORIZONTAL, 6);
		box.add(hbox);

		// label ----------------
		
		var label = new Gtk.Label (_("Web Page") + ":");
		label.xalign = 1.0f;
		hbox.add(label);
		
		sg_label.add_widget(label);

		// entry ----------------
		
		var entry = new Gtk.Entry();
		entry.hexpand = true;
		entry.set_size_request(200,-1);
		hbox.add(entry);

		entry.editable = false;

		entry.text = task.url;

		sg_info.add_widget(entry);
	}

	public void init_ui_download(){

		gtk_container_remove_children(contents);
		
		//string txt = _("Download");

		// heading ----------------

		/*var label = new Gtk.Label("<b>" + txt + "</b>");
		label.set_use_markup(true);
		label.xalign = 0.0f;
		//label.margin_bottom = 12;
		contents.add(label);*/
		
		var hbox_outer = new Gtk.Box(Orientation.HORIZONTAL, 6);
		contents.add(hbox_outer);

		try {
			if (file_exists(task.thumb_path)){
				var pixbuf = new Gdk.Pixbuf.from_file_at_scale(task.thumb_path, -1, 64, true);
				var img = new Gtk.Image.from_pixbuf(pixbuf);
				hbox_outer.add(img);
			}
		}
		catch (Error e){
			log_error(e.message);
		}

		var vbox_outer = new Gtk.Box(Orientation.VERTICAL, 6);
		hbox_outer.add(vbox_outer);

		var hbox = new Gtk.Box(Orientation.HORIZONTAL, 6);
		vbox_outer.add(hbox);

		// spinner --------------------

		var spinner = new Gtk.Spinner();
		spinner.start();
		hbox.add(spinner);

		// status message ------------------

		var label = new Gtk.Label(_("Preparing..."));
		label.xalign = 0.0f;
		label.ellipsize = Pango.EllipsizeMode.START;
		label.max_width_chars = 100;
		hbox.add(label);
		lbl_status = label;

		// progressbar ----------------------------

		progressbar = new Gtk.ProgressBar();
		progressbar.fraction = 0;
		progressbar.hexpand = true;
		vbox_outer.add(progressbar);

		// stats label ----------------

		label = new Gtk.Label("...");
		label.xalign = 0.0f;
		label.ellipsize = Pango.EllipsizeMode.END;
		label.max_width_chars = 100;
		vbox_outer.add(label);
		lbl_stats = label;

		// cancel button

		var button = new Gtk.Button.with_label("");
		button.label = "";
		button.image = IconManager.lookup_image("process-stop", 32);
		button.always_show_image = true;
		button.set_tooltip_text(_("Cancel"));
		hbox_outer.add(button);

		button.clicked.connect(()=>{
			cancel();
		});

		show_all();
	}
	
	public override void execute(){

		log_debug("ProgressPanelVideoDownloadTask: execute(%s)");

		task = new VideoDownloadTask(url, destination.file_path);
		
		pane.refresh_file_action_panel();
		pane.clear_messages();
		
		start_task();
	}

	public override void init_status(){

		log_debug("ProgressPanelVideoDownloadTask: init_status()");

		progressbar.fraction = 0.0;
		lbl_status.label = "Preparing...";
		lbl_stats.label = "";
	}
	
	public override void start_task(){

		log_debug("ProgressPanelVideoDownloadTask: start_task()");

		err_log_clear();

		if (task.format.length == 0){
			fetch_in_progress = true;
			fetch_wait_interval = FETCH_WAIT_INTERVAL;
			lbl_status.label = url;
			task.list_formats();
		}
		else{
			fetch_in_progress = false;
			task.download();
		}

		gtk_do_events();
		
		tmr_status = Timeout.add(500, update_status);
	}

	public override bool update_status() {

		if (task.is_running){
			
			log_debug("ProgressPanelVideoDownloadTask: update_status()");

			if (task.current_file.length > 0){
				lbl_status.label = "%s: %s".printf(_("Downloading"), task.current_file);
			}

			if (fetch_in_progress){

				if (fetch_wait_interval < 0){
					
					string txt = _("Could not fetch video info");
					string msg = "%s\n\n%s".printf(
						_("Check your internet connectivity."),_("Try pasting the URL again."));
					gtk_messagebox(txt, msg, window, true);
					
					cancel();
				}

				fetch_wait_interval -= 500;
				//log_debug("fetch_wait_interval: %d".printf(fetch_wait_interval));
			}
			
			//lbl_stats.label = task.stat_status_line;

			if (progressbar != null){
				progressbar.fraction = task.progress;
				lbl_stats.label = task.stat_status_line;
			}
			
			gtk_do_events();
		}
		else{
			finish();
		}

		return task.is_running;
	}

	public override void cancel(){

		log_debug("ProgressPanelVideoDownloadTask: cancel()");
		
		aborted = true;

		stop_status_timer();
		
		if (task != null){
			task.stop();
		}

		finish();
	}

	public override void finish(){

		log_debug("task.finish()");
		
		task_complete();

		stop_status_timer();
		
		if (!aborted && (task.format.length == 0)){
			
			log_debug("task.list_size: %d".printf(task.list.size));
			
			if (task.list.size > 0){

				if (task.list.size == 1){
					task.format = task.list[0].code;
				}
				else{
					task.format = "best";
				}
				
				task.current_file = task.title;
				init_ui_selection();
			}
			else{

				string txt = _("Could not fetch video info");

				string msg = "%s\n\n%s".printf(
						_("Check if the link is from a supported website."),
						_("Update youtube-dl to a newer version."));
						
				gtk_messagebox(txt, msg, window, true);
					
				cancel();
			}
		}
		else{
			log_debug("ProgressPanelVideoDownloadTask: finish()");

			pane.file_operations.remove(this);
			pane.refresh_file_action_panel();

			if (task.get_error_message().length > 0){
				gtk_messagebox(_("Finished with errors"), task.get_error_message(), window, true);
			}
		}
	}
}




