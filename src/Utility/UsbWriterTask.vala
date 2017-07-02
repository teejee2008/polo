/*
 * UsbWriterTask.vala
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

using GLib;
using Gtk;
using Gee;
using Json;

using TeeJee.Logging;
using TeeJee.FileSystem;
using TeeJee.JsonHelper;
using TeeJee.ProcessHelper;
using TeeJee.GtkHelper;
using TeeJee.System;
using TeeJee.Misc;


public class UsbWriterTask : AsyncTask {

	public string device = "";
	public string iso_file = "";

	public string error_log = "";
	
	public UsbWriterTask(){
		init_regular_expressions();
	}
	
	private void init_regular_expressions(){
		
		regex_list = new Gee.HashMap<string, Regex>();
		
		try {
			//719323136 bytes (719 MB, 686 MiB) copied, 120.449 s, 6.0 MB/s
			regex_list["status"] = new Regex("""^[ \t]*([0-9.]+)[ \t]*.*""");
		}
		catch (Error e) {
			log_error (e.message);
		}
	}
	
	public void prepare() {
	
		string script_text = build_script();
		script_file = save_bash_script_temp(script_text, script_file, true, false, true);

		bytes_completed = 0;
		bytes_total = file_get_size(iso_file);
	}

	private string build_script() {
	
		//var cmd = "dd";
		//cmd += " if='%s'".printf(iso_file);
		//cmd += " of='%s'".printf(device);
		//cmd += " bs=8M status=progress oflag=direct";

		string cmd = "polo-iso write";
		cmd += " --iso '%s'".printf(iso_file);
		cmd += " --device '%s'".printf(device);
		
		return cmd;
	}
	
	// execution ----------------------------

	public void write_iso_to_device(string _iso_file, string _device){
		iso_file = _iso_file;
		device = _device;
		execute();
	}
	
	private void execute() {

		prepare();

		begin();

		if (status == AppStatus.RUNNING){
			
			
		}
	}

	public override void parse_stdout_line(string out_line){
		
		if (is_terminated) { return; }

		update_progress_parse_console_output(out_line);
	}
	
	public override void parse_stderr_line(string err_line){
		
		if (is_terminated) { return; }

		update_progress_parse_console_output(err_line);
	}

	public bool update_progress_parse_console_output (string line) {

		if ((line == null) || (line.length == 0)) { return true; }

		// dd and polo-iso write output to stderr
		
		MatchInfo match;
		if (regex_list["status"].match(line, 0, out match)) {
			bytes_completed = int64.parse(match.fetch(1));
			progress = (bytes_completed * 1.0) / bytes_total;
		}
		else if (line.has_prefix("E:")){
			error_log += "%s\n".printf(line);
			log_error(line);
		}

		return true;
	}

	protected override void finish_task(){
		if ((status != AppStatus.CANCELLED) && (status != AppStatus.PASSWORD_REQUIRED)) {
			status = AppStatus.FINISHED;
		}
	}

	public int read_status(){
		var status_file = working_dir + "/status";
		var f = File.new_for_path(status_file);
		if (f.query_exists()){
			var txt = file_read(status_file);
			return int.parse(txt);
		}
		return -1;
	}

	public new string get_error_message(){
		return error_log;
	}

	// stats

	public string stat_status_line{
		
		owned get{
			var txt = "";
			
			txt = "%.2f %% complete, %s elapsed, %s remaining, %s".printf(
				progress * 100.0, stat_time_elapsed, stat_time_remaining, stat_speed);

			return txt;
		}
	}
	
	public string stat_speed{
		owned get{
			long elapsed = (long) timer_elapsed(timer);
			long speed = (long)(bytes_completed / (elapsed / 1000.0));
			return format_file_size(speed) + "/s";
		}
	}

}
