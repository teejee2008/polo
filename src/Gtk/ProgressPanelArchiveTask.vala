/*
 * ProgressPanel.vala
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

public class ProgressPanelArchiveTask : ProgressPanel {

	private ArchiveTask task;
	
	private FileItem dest_archive;
	private FileItemArchive? archive;

	// ui for archive_task
	private Gtk.Spinner spinner;
	private Gtk.Label lbl_header;
	private Gtk.Box hbox_bar;
	private Gtk.DrawingArea drawing_area;
	private Gtk.Label lbl_file_count_value;
	private Gtk.Label lbl_data_value;
	private Gtk.Label lbl_processed_value;
	private Gtk.Label lbl_compressed_value;
	private Gtk.Label lbl_ratio_value;
	private Gtk.Label lbl_elapsed_value;
	private Gtk.Label lbl_remaining_value;
	private Gtk.Label lbl_speed_value;
	
	//actions
	private Gtk.Button btn_background;
	private Gtk.Button btn_pause;
	private Gtk.Button btn_stop;
	private Gtk.Button btn_finish;
	private double progress_prev;

	private Gtk.Label lbl_prg_status;
	private Gtk.ProgressBar prg_status;

	private Gtk.Label lbl_prg_ratio;
	private Gtk.ProgressBar prg_ratio;
	
	private uint tmr_password = 0;
	private uint tmr_next = 0;
	
	private bool was_restarted = false;
	public bool create_new_folder = true;
	private FileItem? previous_archive = null;

	private Gee.ArrayList<FileItemArchive> archives = new Gee.ArrayList<FileItemArchive>();
	private bool file_cancelled = false;

	public ProgressPanelArchiveTask(FileViewPane _pane,
		Gee.ArrayList<FileItem> _items, FileActionType _action, bool _create_new_folder){
	
		base(_pane, _items, _action);

		task = new ArchiveTask(window);
		task.extract_to_new_folder = _create_new_folder;
	}

	public void set_archive(FileItem _dest_archive){
		dest_archive = _dest_archive;
	}

	public void set_task(ArchiveTask _task){
		task = _task;
	}

	public override void init_ui(){

		string txt = "";
		switch(action_type){
		case FileActionType.COMPRESS:
			txt = _("Compressing");
			break;
		case FileActionType.EXTRACT:
			txt = _("Extracting");
			break;
		case FileActionType.LIST_ARCHIVE:
			txt = _("Reading");
			break;
		case FileActionType.TEST_ARCHIVE:
			txt = _("Testing");
			break;
		default:
			break;
		}

		// heading ----------------

		var hbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
		contents.add(hbox);
		
		var label = new Gtk.Label("<b>" + txt + ": </b>");
		label.set_use_markup(true);
		label.xalign = 0.0f;
		label.margin_bottom = 12;
		hbox.add(label);

		label = new Gtk.Label("");
		label.set_use_markup(true);
		label.xalign = 0.0f;
		label.margin_bottom = 12;
		hbox.add(label);
		lbl_header = label;
		
		init_labels();
		
		init_progress_bar();
		
		init_command_buttons();
	}

	private void init_labels() {

		var hbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
		contents.add(hbox);
		
		//grid_stats
		var grid_stats = new Grid();
		grid_stats.set_column_spacing(20);
		grid_stats.set_row_spacing (3);
		grid_stats.column_homogeneous = true;
		//grid_stats.hexpand = true;
		hbox.add(grid_stats);

		grid_stats.margin_bottom = 12;

		int row = -1;

		//lbl_file_count -----------------------------------------
		
		var lbl_file_count = new Gtk.Label(_("Files:"));
		lbl_file_count.xalign = 0.0f;
		grid_stats.attach(lbl_file_count, 0, ++row, 1, 1);

		//lbl_file_count_value
		lbl_file_count_value = new Gtk.Label(_("???"));
		lbl_file_count_value.xalign = 1.0f;
		grid_stats.attach(lbl_file_count_value, 1, row, 1, 1);

		//lbl_elapsed -----------------------------------------
		
		var lbl_elapsed = new Gtk.Label(_("Elapsed:"));
		lbl_elapsed.xalign = 0.0f;
		grid_stats.attach(lbl_elapsed, 0, ++row, 1, 1);

		//lbl_elapsed_value
		lbl_elapsed_value = new Gtk.Label(_("???"));
		lbl_elapsed_value.xalign = 1.0f;
		grid_stats.attach(lbl_elapsed_value, 1, row, 1, 1);

		//lbl_remaining -----------------------------------------
		
		var lbl_remaining = new Gtk.Label(_("Remaining:"));
		lbl_remaining.xalign = 0.0f;
		grid_stats.attach(lbl_remaining, 0, ++row, 1, 1);

		//lbl_remaining_value
		lbl_remaining_value = new Gtk.Label(_("???"));
		lbl_remaining_value.xalign = 1.0f;
		grid_stats.attach(lbl_remaining_value, 1, row, 1, 1);

		//lbl_speed -----------------------------------------
		
		var lbl_speed = new Gtk.Label(_("Speed:"));
		lbl_speed.xalign = 0.0f;
		grid_stats.attach(lbl_speed, 0, ++row, 1, 1);

		//lbl_speed_value
		lbl_speed_value = new Gtk.Label(_("???"));
		lbl_speed_value.xalign = 1.0f;
		grid_stats.attach(lbl_speed_value, 1, row, 1, 1);

		row = -1;

		//lbl_data -------------------------------------------------
		
		var lbl_data = new Gtk.Label(_("Data:"));
		lbl_data.xalign = 0.0f;
		//lbl_data.margin_left = 12;
		grid_stats.attach(lbl_data, 2, ++row, 1, 1);

		//lbl_data_value
		lbl_data_value = new Gtk.Label(_("???"));
		lbl_data_value.xalign = 1.0f;
		grid_stats.attach(lbl_data_value, 3, row, 1, 1);

		//lbl_processed ------------------------------------------
		
		var lbl_processed = new Gtk.Label(_("Processed:"));
		lbl_processed.xalign = 0.0f;
		//lbl_processed.margin_left = 12;
		grid_stats.attach(lbl_processed, 2, ++row, 1, 1);

		//lbl_processed_value
		lbl_processed_value = new Gtk.Label(_("???"));
		lbl_processed_value.xalign = 1.0f;
		grid_stats.attach(lbl_processed_value, 3, row, 1, 1);

		//lbl_compressed -----------------------------------------
		
		var lbl_compressed = new Gtk.Label(_("Compressed:"));
		lbl_compressed.xalign = 0.0f;
		//lbl_compressed.margin_left = 12;
		grid_stats.attach(lbl_compressed, 2, ++row, 1, 1);

		//lbl_compressed_value
		lbl_compressed_value = new Gtk.Label(_("???"));
		lbl_compressed_value.xalign = 1.0f;
		grid_stats.attach(lbl_compressed_value, 3, row, 1, 1);

		//lbl_ratio -----------------------------------------
		
		var lbl_ratio = new Gtk.Label(_("Ratio:"));
		lbl_ratio.xalign = 0.0f;
		//lbl_ratio.margin_left = 12;
		grid_stats.attach(lbl_ratio, 2, ++row, 1, 1);

		//lbl_ratio_value
		lbl_ratio_value = new Gtk.Label(_("???"));
		lbl_ratio_value.xalign = 1.0f;
		grid_stats.attach(lbl_ratio_value, 3, row, 1, 1);

		var label = new Gtk.Label("");
		label.hexpand = true;
		hbox.add(label);
	}

	private void init_progress_bar() {

		var hbox = new Gtk.Box(Orientation.HORIZONTAL, 6);
		contents.add(hbox);
		
		var label = new Gtk.Label(_("Progress:"));
		label.xalign = 0.0f;
		hbox.add(label);

		label = new Gtk.Label("");
		label.xalign = 0.0f;
		hbox.add(label);
		
		lbl_prg_status = label;
		
		var prg = new Gtk.ProgressBar();
		//prg.show_text = true;
		contents.add(prg);
		prg_status = prg;

		// ----------------------------------------------------

		hbox = new Gtk.Box(Orientation.HORIZONTAL, 6);
		contents.add(hbox);

		label = new Gtk.Label(_("Compression:"));
		label.xalign = 0.0f;
		hbox.add(label);

		label = new Gtk.Label("");
		label.xalign = 0.0f;
		hbox.add(label);
		
		lbl_prg_ratio = label;

		prg = new Gtk.ProgressBar();
		contents.add(prg);
		prg_ratio= prg;
	}

	private void init_command_buttons() {

		var hbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
		contents.add(hbox);
		
		//hbox_actions
		var hbox_actions = new Gtk.Box(Gtk.Orientation.HORIZONTAL,6);
		hbox_actions.margin_top = 6;
		hbox_actions.homogeneous = true;
		hbox.add(hbox_actions);

		//btn_pause ---------------------------------------------------

		btn_pause = new Gtk.Button();
		btn_pause.set_tooltip_text (_("Pause"));
		hbox_actions.add(btn_pause);

		btn_pause.label = _("Pause");
		btn_pause.always_show_image = true;
		btn_pause.image_position = PositionType.LEFT;
		btn_pause.image = IconManager.lookup_image("media-playback-pause", 16);

		btn_pause.clicked.connect(() => {
			switch (task.status) {
			case AppStatus.RUNNING:
				task.pause();
				spinner.stop();
				spinner.visible = false;
				break;
			case AppStatus.PAUSED:
				task.resume();
				spinner.start();
				spinner.visible = true;
				break;
			}

			switch (task.status) {
			case AppStatus.RUNNING:
				btn_pause.label = _("Pause");
				btn_pause.set_tooltip_text (_("Pause"));
				btn_pause.image = IconManager.lookup_image("media-playback-pause", 16);
				break;
			case AppStatus.PAUSED:
				btn_pause.label = _("Resume");
				btn_pause.set_tooltip_text (_("Resume"));
				btn_pause.image = IconManager.lookup_image("media-playback-start", 16);
				break;
			}
		});

		//btn_stop -----------------------------------------------------
		
		btn_stop = new Gtk.Button();
		btn_stop.set_tooltip_text (_("Stop"));
		hbox_actions.add(btn_stop);

		btn_stop.label = _("Stop");
		btn_stop.always_show_image = true;
		btn_stop.image_position = PositionType.LEFT;
		btn_stop.image = IconManager.lookup_image("process-stop", 16);

		btn_stop.clicked.connect(() => {
			cancel();
			gtk_do_events();
		});

		//btn_finish ---------------------------------------------------

		btn_finish = new Gtk.Button();
		btn_finish.set_tooltip_text (_("Close this window"));
		btn_finish.set_size_request(100,30);
		btn_finish.no_show_all = true;
		hbox_actions.add(btn_finish);
		hbox_actions.set_child_packing(btn_finish,false,false,0,PackType.START);
		
		btn_finish.label = _("OK");
		btn_finish.always_show_image = true;
		btn_finish.image_position = PositionType.LEFT;
		btn_finish.image = IconManager.lookup_image("window-close", 16);

		btn_finish.clicked.connect(() => {
			finish();
			gtk_do_events();
		});
		
		btn_background.get_style_context().add_class(Gtk.STYLE_CLASS_LINKED);
		btn_pause.get_style_context().add_class(Gtk.STYLE_CLASS_LINKED);
		btn_stop.get_style_context().add_class(Gtk.STYLE_CLASS_LINKED);

		var label = new Gtk.Label("");
		label.hexpand = true;
		hbox.add(label);
	}

	public override void execute(){

		log_debug("ProgressPanelArchiveTask: execute(%s): %d".printf(action_type.to_string(), items.size));
		
		if (items.size == 0){
			log_error("items.size=0");
			return;
		}

		pane.refresh_file_action_panel();
		pane.clear_messages();

		switch (action_type){
		case FileActionType.EXTRACT:
			archives = new Gee.ArrayList<FileItemArchive>();
			foreach(var item in items){
				if (item is FileItemArchive){
					var arch = (FileItemArchive) item;
					archives.add(arch);
				}
			}
			break;
		}
		
		start_task();
	}

	public override void start_task(){

		log_debug("ProgressPanelArchiveTask: start_task()");

		err_log_clear();

		//archive = items[0];
		init_status();

		switch (action_type){
		case FileActionType.COMPRESS:
			task.compress((FileItemArchive)dest_archive);
			break;
			
		case FileActionType.EXTRACT:

			if (!was_restarted){
				if (archives.size > 0){
					archive = archives[0];
					archives.remove(archive);
				}
			}

			if (archive.extraction_path.length == 0){
				string txt = _("Extraction path not specified");
				string msg = archive.file_name;
				gtk_messagebox(txt, msg, window, true);
				finish();
				return;
			}

			bool create_new_folder = !was_restarted && task.extract_to_new_folder;
			task.extract_archive(archive, create_new_folder);
			break;

		case FileActionType.LIST_ARCHIVE:
			task.open(archives[0], false);
			break;
			
		case FileActionType.TEST_ARCHIVE:
			//task.test(archive, false);
			break;
		}

		gtk_do_events();
		
		tmr_status = Timeout.add(500, update_status);
	}

	public override void init_status(){

		log_debug("ProgressPanelArchiveTask: init_status()");
		
		spinner.start();
		spinner.visible = true;
		gtk_do_events();
		
		//lbl_status.label = "Preparing...";
		progress_prev = 0.0;
		task.progress = 0.0;

		file_cancelled = false;

		btn_pause.set_tooltip_text (_("Pause"));
		btn_pause.image = IconManager.lookup_image("media-playback-pause", 16);
	}
	
	public override bool update_status(){

		log_debug("ProgressPanelArchiveTask: update_status()");

		switch (task.status) {
		case AppStatus.PAUSED:
			//this.title = "CPU: %0.0f %%".printf(ProcStats.get_cpu_usage());
			break;

		case AppStatus.RUNNING:
			//this.title = "CPU: %0.0f %%".printf(ProcStats.get_cpu_usage());

			task.query_io_stats();

			if (task.archive != null){
				lbl_header.label = "<b>" + task.archive.file_name + "</b>";
			}
			
			// status line
			//lbl_status.label = task.stat_status_line;

			// elapsed time
			lbl_elapsed_value.label = task.stat_time_elapsed;

			// remaining time
			lbl_remaining_value.label =  task.stat_time_remaining;

			// file count
			lbl_file_count_value.label = task.stat_file_count;

			// processed size
			lbl_processed_value.label = task.stat_data_processed;

			// compressed size
			lbl_compressed_value.label = task.stat_data_compressed;

			// compression ratio
			lbl_ratio_value.label = task.stat_compression_ratio;

			// speed
			lbl_speed_value.label = task.stat_speed;

			if ((task.archive != null) && (task.archive != previous_archive)){
				lbl_file_count_value.label = "%'d".printf(task.archive.file_count_total);
				lbl_data_value.label = format_file_size(task.archive.file_size);
				previous_archive = task.archive;
			}

			prg_status.fraction = task.progress;

			lbl_prg_status.label = "%.0f %%".printf(task.progress * 100.0);

			prg_ratio.fraction = task.compression_ratio / 100.0;

			lbl_prg_ratio.label = task.stat_compression_ratio;
			
			gtk_do_events();

			break;

		case AppStatus.PASSWORD_REQUIRED:
			// remove progress timers
			Source.remove (tmr_password);
			// prompt for password
			tmr_password = Timeout.add(200, prompt_for_password_and_restart_task);
			return false;
			
		case AppStatus.FINISHED:
			finish();
			return false;
			
		case AppStatus.CANCELLED:
			finish();
			return false;
		}

		return true;
	}
	
	public override void cancel(){

		log_debug("ProgressPanelArchiveTask: cancel()");
		
		aborted = true;

		stop_status_timer();
		
		if (task != null){
			task.stop();
		}
		
		task_complete();
		
		finish();
	}

	public override void finish(){

		log_debug("ProgressPanelArchiveTask: finish()");

		stop_status_timer();
		
		var status = task.get_exit_code();

		log_debug("status: %d".printf(status));

		if (file_cancelled){

			switch (task.action){
			case ArchiveAction.CREATE:
				pane.add_message(_("Cancelled") + ": %s".printf(task.archive_path), Gtk.MessageType.WARNING);
				break;
			case ArchiveAction.EXTRACT:
				pane.add_message(_("Cancelled") + ": %s".printf(archive.file_name), Gtk.MessageType.WARNING);
				break;
			case ArchiveAction.TEST:
				gtk_messagebox("","Archive is OK", window,false);
				break;
			}	
		}
		else if (status == 0){ // valid archive, success
			//task_is_running = false;

			switch (task.action){
			case ArchiveAction.CREATE:
				pane.add_message(_("Created") + ": %s".printf(task.archive_path), Gtk.MessageType.INFO);
				break;
			case ArchiveAction.EXTRACT:
				pane.add_message(_("Extracted") + ": %s ➔ %s".printf(archive.file_name, archive.extraction_path), Gtk.MessageType.INFO);
				break;
			case ArchiveAction.TEST:
				gtk_messagebox("","Archive is OK", window,false);
				break;
			}
		}
		else if ((task.action == ArchiveAction.LIST)
			&& (task.archive.archive_type.length == 0)
			&& (task.archive.children.keys.size == 0)){

			// invalid archive, error
			string txt = _("Unknown Format");
			string msg = _("File is not an archive or format is unsupported") + "\n\n%s".printf(task.archive.file_name);
			gtk_messagebox(txt, msg, window, true);

			pane.add_message(_("Error") + ": %s: %s".printf(archive.file_name, _("Unknown Format")), Gtk.MessageType.ERROR);
			//task_is_running = false;
		}
		else if (!aborted && !file_cancelled){
			
			// valid archive, error
			switch (task.action){
			case ArchiveAction.TEST:
			case ArchiveAction.EXTRACT:
				if (task.get_error_message().length > 0){
					gtk_messagebox("",_("There were errors while processing the archive.") + "\n\n" + task.get_error_message(), window, true);
					pane.add_message(_("Error") + ": %s: %s".printf(archive.file_name, task.get_error_message()), Gtk.MessageType.ERROR);
				}
				break;
			}
		}

		switch (task.action){
		case ArchiveAction.TEST:
		case ArchiveAction.EXTRACT:
			if (archives.size > 0){
				tmr_next = Timeout.add(200, start_next_task);
				return;
			}
			break;
		}
		
		pane.file_operations.remove(this);
		pane.refresh_file_action_panel();
		pane.refresh_message_panel();
		task_complete();
	}

	private bool prompt_for_password_and_restart_task(){

		log_debug("ProgressPanelArchiveTask: prompt_for_password_and_restart_task()");
		
		if (tmr_password > 0) {
			Source.remove(tmr_password);
			tmr_password = 0;
		}

		this.hide();

		if (task.archive.prompt_for_password(window)){
			this.show();
			was_restarted = true;
			start_task(); // start again
		}
		else{
			log_msg(_("Cancelled by user"));
			file_cancelled = true;
			finish();
		}
		
		return false;
	}

	private bool start_next_task(){

		log_debug("ProgressPanelArchiveTask: start_next_task()");
		
		if (tmr_next > 0) {
			Source.remove(tmr_next);
			tmr_next = 0;
		}

		was_restarted = false;
		
		start_task(); // start next
		
		return false;
	}

}




