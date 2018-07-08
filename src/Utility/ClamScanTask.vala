/*
 * DeviceWriterTask.vala
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


public class ClamScanTask : AsyncTask {

	public Gee.ArrayList<string> scan_list;
	public string scan_mode = "fast";
	
	public string scanned = "";
	public string found = "";
	public string elapsed = "";
	public string file_path = "";

	public string error_log = "";

	public Gee.ArrayList<ClamScanResult> results;

	public signal void file_found(ClamScanResult res);

	public ClamScanTask(){
		
		init_regular_expressions();
		
		results = new Gee.ArrayList<ClamScanResult>();
	}
	
	private void init_regular_expressions(){
		
		regex_list = new Gee.HashMap<string, Regex>();
		
		try {
			//0 scanned, 0 found, 00:00:00 elapsed ~ /filepath
			regex_list["status"] = new Regex("""^([0-9]+) scanned, ([0-9]+) found, ([0-9:]+) elapsed ~ (.*)$""");
			regex_list["found"] = new Regex("""^(.*): (.*) (FOUND)$""");
		}
		catch (Error e) {
			log_error (e.message);
		}
	}
	
	public void prepare() {
	
		string script_text = build_script();
		
		script_file = save_bash_script_temp(script_text, script_file, true, false, false);
	}

	private string build_script() {
	
		string cmd = "";

		cmd = "pkexec polo-clamav --scripted";

		if (scan_mode == "fast"){
			cmd += " --fast-scan";
		}
		else if (scan_mode == "deep"){
			cmd += " --deep-scan";
		}

		cmd += " --scan";
		
		foreach(string path in scan_list){
			cmd += " '%s'".printf(escape_single_quote(path));
		}
		
		log_debug(cmd);

		return cmd;
	}
	
	// execution ----------------------------

	public void scan(Gee.ArrayList<string> _scan_list){

		log_debug("ClamScanTask.scan()");
		
		scan_list = _scan_list;

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

		//log_debug(line);

		mutex_parser.lock();
		
		MatchInfo match;
		if (regex_list["status"].match(line, 0, out match)) {

			scanned = match.fetch(1);
			found = match.fetch(2);
			elapsed = match.fetch(3);
			file_path = match.fetch(4);
			
			status_line = line;
		}
		else if (regex_list["found"].match(line, 0, out match)) {

			var res = new ClamScanResult();
			
			res.file_path = match.fetch(1);
			res.signature = match.fetch(2);

			if (file_exists(res.file_path)){

				res.size = format_file_size(file_get_size(res.file_path));
				res.modified = file_get_modified_date(res.file_path).format("%Y-%m-%d %H:%M:%S");
			}
			
			results.add(res);

			file_found(res); // signal
		}
		else if (line.has_prefix("E:")){
			error_log += "%s\n".printf(line);
			log_error(line);
		}

		mutex_parser.unlock();

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


public class ClamScanResult : GLib.Object{

	public string file_path = "";
	public string signature = "";
	public string modified = "";
	public string size = "";

	public bool selected = true;
}
