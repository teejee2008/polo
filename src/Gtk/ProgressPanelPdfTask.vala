/*
 * ProgressPanelPdfTask.vala
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

public class ProgressPanelPdfTask : ProgressPanel {

	private PdfTask task;

	// ui 
	public Gtk.Label lbl_status;
	public Gtk.Label lbl_stats;
	public Gtk.ProgressBar progressbar;

	public ProgressPanelPdfTask(FileViewPane _pane, PdfTask _task){
		base(_pane, null, FileActionType.ISO_WRITE);

		task = _task;
	}

	public override void init_ui(){ // TODO: make protected

		string txt = _("Executing action...");

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
	}

	public override void execute(){

		log_debug("ProgressPanelPdfTask: execute(%s)");

		pane.refresh_file_action_panel();
		pane.clear_messages();
		
		start_task();
	}

	public override void init_status(){

		log_debug("ProgressPanelPdfTask: init_status()");

		progressbar.fraction = 0.0;
		lbl_status.label = "Preparing...";
		lbl_stats.label = "";
	}
	
	public override void start_task(){

		log_debug("ProgressPanelPdfTask: start_task()");

		err_log_clear();

		task.execute();

		gtk_do_events();
		
		tmr_status = Timeout.add (500, update_status);
	}

	public override bool update_status() {

		if (task.is_running){
			
			log_debug("ProgressPanelPdfTask: update_status()");
			
			if (task.current_file.length > 0){
				lbl_status.label = "%s: %s".printf(_("File"), task.current_file);
			}
			
			lbl_stats.label = task.stat_status_line;
				
			progressbar.fraction = task.progress;
			
			gtk_do_events();
		}
		else{
			finish();
			return false;
		}

		return true;
	}

	public override void cancel(){

		log_debug("ProgressPanelPdfTask: cancel()");
		
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
		
		log_debug("ProgressPanelPdfTask: finish()");

		if (!aborted){
			if (task.output_files.size == 0){
				string msg = _("Error") + ": %s".printf(task.get_error_message());
				pane.add_message(msg, Gtk.MessageType.ERROR);
			}
			else{
				string msg = "";
				var list = new Gee.ArrayList<string>();
				
				foreach(string outline in task.output_files){
					if (msg.length > 0) { msg += "\n"; }

					if (outline.contains(": ")){
						//var arr = outline.split(": ");
						//list.add(arr[1]);
						msg += "%s: %s".printf(arr[0], file_basename(arr[1]));
					}
					else{
						msg += outline;
					}
				}
				
				pane.add_message(msg, Gtk.MessageType.INFO);
				//view.select_items_by_file_path(list);

				// do not select items when operation completes
				// it will be dangerous if selection changes while user is executing another action
			}
		}

		pane.file_operations.remove(this);
		pane.refresh_file_action_panel();

		if (task.get_error_message().length > 0){
			gtk_messagebox(_("Finished with errors"), task.get_error_message(), window, true);
		}
	}
}




