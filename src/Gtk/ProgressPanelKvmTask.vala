/*
 * ProgressPanelKvmTask.vala
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

public class ProgressPanelKvmTask : ProgressPanel {

	public KvmTask task;
	private string file_path = "";
	private string base_file = "";
	private string derived_file = "";
	private double disk_size = 0; 

	// ui 
	public Gtk.Label lbl_status;
	public Gtk.Label lbl_stats;
	public Gtk.ProgressBar progressbar;

	public ProgressPanelKvmTask(FileViewPane _pane, FileActionType _action){
		base(_pane, null, _action);
	}

	public void set_parameters(string _file_path, string _base_file, string _derived_file, double _disk_size){
		file_path = _file_path;
		base_file = _base_file;
		derived_file = _derived_file;
		disk_size = _disk_size;
	}

	public override void init_ui(){ // TODO: make protected

		string txt = "";
		switch(action_type){
		case FileActionType.KVM_DISK_MERGE:
			txt = _("Creating merged disk...");
			break;
		default:
			break;
		}

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
		//label.set_use_markup(true);
		label.xalign = (float) 0.0;
		//label.margin_top = 12;
		label.ellipsize = Pango.EllipsizeMode.START;
		label.max_width_chars = 100;
		hbox.add(label);
		lbl_status = label;

		// progressbar ----------------------------

		//hbox = new Gtk.Box(Orientation.HORIZONTAL, 6);
		//vbox_outer.add(hbox);

		progressbar = new Gtk.ProgressBar();
		progressbar.fraction = 0;
		progressbar.hexpand = true;
		//progressbar.set_size_request(-1, 25);
		//progressbar.pulse_step = 0.1;
		vbox_outer.add(progressbar);

		// stats label ----------------

		label = new Gtk.Label("...");
		//label.set_use_markup(true);
		label.xalign = (float) 0.0;
		//label.margin_bottom = 12;
		label.ellipsize = Pango.EllipsizeMode.END;
		label.max_width_chars = 100;
		vbox_outer.add(label);
		lbl_stats = label;

		// cancel button

		var button = new Gtk.Button.with_label("");
		button.label = "";
		button.image = get_shared_icon("process-stop-symbolic", "", 16);
		button.always_show_image = true;
		button.set_tooltip_text(_("Cancel"));
		hbox_outer.add(button);

		button.clicked.connect(()=>{
			cancel();
		});
	}

	public override void execute(){

		task = new KvmTask();
		
		log_debug("ProgressPanelKvmTask: execute(%s)".printf(action_type.to_string()));

		//if (items.size == 0){
		//	log_error("items.size=0");
		//	return;
		//}

		pane.refresh_file_action_panel();

		switch (action_type){
		case FileActionType.KVM_DISK_MERGE:
			start_task();
			break;
		}
	}

	public override void init_status(){

		log_debug("ProgressPanelKvmTask: init_status()");

		progressbar.fraction = 0.0;
		lbl_status.label = "Preparing...";
		lbl_stats.label = "";
	}
	
	public override void start_task(){

		log_debug("ProgressPanelKvmTask: start_task()");

		err_log_clear();

		switch (action_type){
		case FileActionType.KVM_DISK_MERGE:
			task.create_disk_merged(file_path, derived_file, (Gtk.Window) window);
			task.execute();
			break;
		}

		gtk_do_events();
		
		tmr_status = Timeout.add (500, update_status);
	}

	public override bool update_status() {

		if (task.is_running){
			
			log_debug("ProgressPanelKvmTask: update_status()");
			
			// refresh UI
			lbl_status.label = "%s: %s".printf(_("File"), file_basename(file_path));
			lbl_stats.label = "";
			progressbar.fraction = task.progress;
			gtk_do_events();
		}
		else{

			var error_message = err_log_read();
			if (error_message.length > 0){
				string title = _("Error");
				string msg = error_message;
				gtk_messagebox(title, msg, window, true);
				finish();
				return false;
			}
		}

		return true;
	}

	public override void cancel(){

		log_debug("ProgressPanelKvmTask: cancel()");
		
		aborted = true;

		stop_status_timer();
		
		if (task != null){
			task.stop();
		}

		finish();
	}

	public override void finish(){

		task_complete();

		stop_status_timer();
		
		log_debug("ProgressPanelKvmTask: finish()");

		pane.file_operations.remove(this);
		pane.refresh_file_action_panel();
	}
}




