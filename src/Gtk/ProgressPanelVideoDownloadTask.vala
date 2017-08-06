/*
 * ProgressPanelVideoDownloadTask.vala
 *
 * Copyright 2017 Tony George <teejeetech@gmail.com>
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
		contents.add(hbox_outer);

		var vbox_outer = new Gtk.Box(Orientation.VERTICAL, 6);
		hbox_outer.add(vbox_outer);

		var hbox = new Gtk.Box(Orientation.HORIZONTAL, 6);
		vbox_outer.add(hbox);

		// -----------------------------

		// spinner --------------------

		var spinner = new Gtk.Spinner();
		spinner.start();
		hbox.add(spinner);

		// status message ------------------

		label = new Gtk.Label(_("Fetching info..."));
		label.xalign = 0.0f;
		label.ellipsize = Pango.EllipsizeMode.START;
		label.max_width_chars = 100;
		hbox.add(label);
		lbl_status = label;

		hbox.margin_bottom = 12;

		show_all();
	}

	public void init_ui_selection(){
		
		gtk_container_remove_children(contents);

		string txt = _("Select Format...");

		// heading ----------------

		var label = new Gtk.Label("<b>" + txt + "</b>");
		label.set_use_markup(true);
		label.xalign = 0.0f;
		label.margin_bottom = 12;
		contents.add(label);
		
		var hbox_outer = new Gtk.Box(Orientation.HORIZONTAL, 6);
		contents.add(hbox_outer);

		var vbox_outer = new Gtk.Box(Orientation.VERTICAL, 6);
		hbox_outer.add(vbox_outer);

		// scrolled
		var scrolled = new Gtk.ScrolledWindow(null, null);
		scrolled.set_shadow_type (ShadowType.ETCHED_IN);
		scrolled.hscrollbar_policy = PolicyType.AUTOMATIC;
		scrolled.vscrollbar_policy = PolicyType.AUTOMATIC;
		scrolled.expand = true;

		var vbox = new Gtk.Box(Orientation.VERTICAL, 0);
		vbox.margin = 6;
		
		scrolled.add(vbox);
		vbox_outer.add(scrolled);

		var hbox = new Gtk.Box(Orientation.HORIZONTAL, 6);
		vbox_outer.add(hbox);

		// -----------------------------

		Gtk.RadioButton? last_radio = null;

		// best 
		
		var radio = new Gtk.RadioButton.with_label_from_widget(last_radio, _("Best (audio + video)"));
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
			
		foreach(var item in task.list){
			
			radio = new Gtk.RadioButton.with_label_from_widget(last_radio, item.description);
			vbox.add(radio);
			last_radio = radio;

			radio.toggled.connect(()=>{
				task.format = item.code;
				log_debug("task.set_format: %s".printf(task.format));
			});
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

	public void init_ui_download(){

		gtk_container_remove_children(contents);
		
		string txt = _("Downloading...");

		// heading ----------------

		var label = new Gtk.Label("<b>" + txt + "</b>");
		label.set_use_markup(true);
		label.xalign = 0.0f;
		label.margin_bottom = 12;
		contents.add(label);
		
		var hbox_outer = new Gtk.Box(Orientation.HORIZONTAL, 6);
		contents.add(hbox_outer);

		var vbox_outer = new Gtk.Box(Orientation.VERTICAL, 6);
		hbox_outer.add(vbox_outer);

		var hbox = new Gtk.Box(Orientation.HORIZONTAL, 6);
		vbox_outer.add(hbox);

		// spinner --------------------

		var spinner = new Gtk.Spinner();
		spinner.start();
		hbox.add(spinner);

		// status message ------------------

		label = new Gtk.Label(_("Preparing..."));
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
		button.image = IconManager.lookup_image("process-stop", 16);
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
			task.list_formats();
		}
		else{
			task.download();
		}

		gtk_do_events();
		
		tmr_status = Timeout.add (500, update_status);
	}

	public override bool update_status() {

		if (task.is_running){
			
			log_debug("ProgressPanelVideoDownloadTask: update_status()");

			//if (task.current_file.length > 0){
			//	lbl_status.label = "%s: %s".printf(_("File"), task.current_file);
			//}
			
			//lbl_stats.label = task.stat_status_line;

			if (progressbar != null){
				progressbar.fraction = task.progress;
				lbl_stats.label = task.stat_status_line;
			}
			
			gtk_do_events();
		}
		else{
			finish();
			return false;
		}

		return true;
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
				init_ui_selection();
				task.format = "best";
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




