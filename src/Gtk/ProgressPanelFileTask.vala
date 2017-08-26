/*
 * ProgressPanel.vala
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

public class ProgressPanelFileTask : ProgressPanel {

	public FileTask task;

	// ui 
	public Gtk.Label lbl_status;
	public Gtk.Label lbl_stats;
	public Gtk.ProgressBar progressbar;
	
	private bool first_pass = true;
	private FileReplaceMode replace_mode = FileReplaceMode.NONE;
	private Gee.HashMap<string, FileConflictItem> conflicts;

	private int64 copied_bytes = 0;
	private int stalled_counter_limit = 10 * (1000 / 200);
	private int stalled_counter = (int) stalled_counter_limit;
	private bool stalled_warning_shown = false;
		
	public ProgressPanelFileTask(FileViewPane _pane, Gee.ArrayList<FileItem> _items, FileActionType _action){
		base(_pane, _items, _action);

		//task = new FileTask();
	}

	public override void init_ui(){ // TODO: make protected

		string txt = "";
		switch(action_type){
		case FileActionType.COPY:
			txt = _("Copying items...");
			break;
		case FileActionType.CUT:
			txt = _("Moving items...");
			break;
		case FileActionType.RESTORE:
			txt = _("Restoring items...");
			break;
		case FileActionType.TRASH:
			txt = _("Moving items to trash...");
			break;
		case FileActionType.DELETE:
		case FileActionType.DELETE_TRASHED:
			txt = _("Deleting items...");
			break;
		case FileActionType.PASTE_SYMLINKS_AUTO:
		case FileActionType.PASTE_SYMLINKS_ABSOLUTE:
		case FileActionType.PASTE_SYMLINKS_RELATIVE:
			txt = _("Creating symbolic links...");
			break;
		case FileActionType.PASTE_HARDLINKS:
			txt = _("Creating hard links...");
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
		label.xalign = 0.0f;
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
		label.xalign = 0.0f;
		//label.margin_bottom = 12;
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

		task = new FileTask();

		log_debug("ProgressPanelFileTask: execute(%s): %d".printf(action_type.to_string(), items.size));

		if (items.size == 0){
			log_error("items.size=0");
			return;
		}

		replace_mode = FileReplaceMode.NONE;
		conflicts = null;

		pane.refresh_file_action_panel();

		switch (action_type){
		case FileActionType.PASTE_SYMLINKS_AUTO:
		case FileActionType.PASTE_SYMLINKS_ABSOLUTE:
		case FileActionType.PASTE_SYMLINKS_RELATIVE:
		case FileActionType.PASTE_HARDLINKS:
			int count = 0;
			bool ok = true;

			foreach(var item in items){
				if (file_or_dir_exists(item.file_path)){
					string src = item.file_path;
					string dst = path_combine(destination.file_path, item.file_name);

					lbl_status.label = item.file_name;

					bool? relative_flag = null;

					switch(action_type){
					case FileActionType.PASTE_SYMLINKS_AUTO:
						relative_flag = null;
						break;
					case FileActionType.PASTE_SYMLINKS_ABSOLUTE:
						relative_flag = false;
						break;
					case FileActionType.PASTE_SYMLINKS_RELATIVE:
						relative_flag = true;
						break;
					}

					switch (action_type){
					case FileActionType.PASTE_SYMLINKS_AUTO:
					case FileActionType.PASTE_SYMLINKS_ABSOLUTE:
					case FileActionType.PASTE_SYMLINKS_RELATIVE:
						ok = file_create_symlink(src, dst, relative_flag, window);
						break;
					case FileActionType.PASTE_HARDLINKS:
						ok = file_create_hardlink(src, dst, window);
						break;
					}

					count++;

					progressbar.fraction = count / (1.0 * items.size);
					gtk_do_events();

					if (!ok){
						finish();
						return;
					}
				}
			}

			finish();
			break;

		case FileActionType.COPY:
		case FileActionType.CUT:
		case FileActionType.RESTORE:
		case FileActionType.DELETE:
		case FileActionType.DELETE_TRASHED:
		case FileActionType.TRASH:

			start_task();
			break;
		}
	}

	public override void init_status(){

		log_debug("ProgressPanelFileTask: init_status()");

		progressbar.fraction = 0.0;
		lbl_status.label = "Preparing...";
		lbl_stats.label = "";
	}
	
	public override void start_task(){

		log_debug("ProgressPanelFileTask: start_task()");

		err_log_clear();

		switch (action_type){
		case FileActionType.CUT:
			task.move_items_to_path(source, destination.file_path, items.to_array(),
				replace_mode, conflicts, (Gtk.Window) window);
			break;
		case FileActionType.COPY:
			task.copy_items_to_path(source, destination.file_path, items.to_array(),
				replace_mode, conflicts, (Gtk.Window) window);
			break;
		case FileActionType.RESTORE:
			task.restore_trashed_items(items.to_array(), (Gtk.Window) window);
			break;
		case FileActionType.DELETE:
		case FileActionType.DELETE_TRASHED:
			log_debug("------------------------------------------%d".printf(items.size));
			task.delete_items(source, items.to_array(), (Gtk.Window) window);
			break;
		case FileActionType.TRASH:
			log_debug("------------------------------------------%d".printf(items.size));
			task.trash_items(source, items.to_array(), (Gtk.Window) window);
			break;
		}

		gtk_do_events();
		
		tmr_status = Timeout.add (500, update_status);
	}

	public override bool update_status() {

		if (task.is_running){
			
			log_debug("ProgressPanelFileTask: update_status()");

			lbl_status.label = task.status;

			lbl_stats.label = task.stats;
			
			progressbar.fraction = task.progress;
			
			gtk_do_events();

			// do events ~10 times/sec but refresh stats ~5 times/sec
			copied_bytes = task.bytes_batch;

			//check_if_stalled();
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

			if (first_pass && ((action_type == FileActionType.CUT) || (action_type == FileActionType.COPY))){
				
				if (aborted){ return false; }

				log_debug("conflicts=%d".printf(task.conflicts.keys.size));

				int response = Gtk.ResponseType.OK;
				if (task.conflicts.keys.size > 0){

					lbl_status.label = _("Resolving conflicts...");
					lbl_stats.label = "";
					gtk_do_events();

					var dlg = new FileConflictDialog.with_parent(window, task);
					response = dlg.run();
					replace_mode = dlg.replace_mode;
					dlg.destroy();
					gtk_do_events();
				}
				if (response == Gtk.ResponseType.OK){
					first_pass = false;
					conflicts = task.conflicts;

					stop_status_timer();
					start_task();
					return false;
				}
				else{
					finish();
					return false;
				}
			}
			else{
				finish();
				return false;
			}
		}

		return true;
	}

	private bool check_if_stalled(){

		switch (action_type){
		case FileActionType.DELETE:
		case FileActionType.DELETE_TRASHED:
		case FileActionType.TRASH:
			return false;
		}

		if (task.bytes_batch == copied_bytes){
			// no bytes were copied in last 200 ms
			stalled_counter--;
		}
		else{
			// reset
			stalled_counter = stalled_counter_limit;
			copied_bytes = task.bytes_batch;
		}

		switch (action_type){
		case FileActionType.CUT:
		case FileActionType.COPY:
			if ((copied_bytes > 0) && (stalled_counter < 0) && !stalled_warning_shown){
				string title = _("Not Responding");
				string msg = _("The data transfer seems to have stopped. Check if device is working correctly and if connection with the device is reliable.");
				gtk_messagebox(title, msg, window, true);
				stalled_warning_shown = true;
				return true;
			}
			break;
		}

		return false;
	}

	public override void cancel(){

		log_debug("ProgressPanelFileTask: cancel()");
		
		aborted = true;

		stop_status_timer();
		
		if (task != null){
			task.cancel_task();
		}

		finish();
	}

	public override void finish(){

		task_complete();

		stop_status_timer();
		
		log_debug("ProgressPanelFileTask: finish()");
		
		switch (action_type){
		case FileActionType.TRASH:
		case FileActionType.DELETE_TRASHED:
		case FileActionType.RESTORE:
			window.refresh_trash();
			break;
		}

		if ((source != null) && (source is FileItemCloud)){
			window.refresh_remote_views(source.file_path);
		}

		if ((destination != null) && (destination is FileItemCloud)){
			window.refresh_remote_views(destination.file_path);
		}

		pane.file_operations.remove(this);
		pane.refresh_file_action_panel();
	}
}




