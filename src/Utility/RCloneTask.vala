/*
 * RCloneTask.vala
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

public enum RcloneActionType {
	COPY,
	MOVE,
	DELETE
}

public class RCloneTask : AsyncTask{
	
	// settings
	public string source_path = "";
	public string dest_path = "";
	public RcloneActionType action = RcloneActionType.COPY;

	public Gee.ArrayList<string> exclude_list;

	public bool dry_run = false;
	public string rclone_log_file = "";
	public string filter_from_file = "";
	public string error_messages = "";

	public int64 count_errors;
	public int64 count_checks;
	public int64 count_trans;
	
	public RCloneTask(){
	
		init_regular_expressions();
		
		exclude_list = new Gee.ArrayList<string>();
	}
	
	private void init_regular_expressions(){
		
		regex_list = new Gee.HashMap<string, Regex>();
		
		try {
			//  Transferred:   15.656 MBytes (240.279 kBytes/s)
			regex_list["status"] = new Regex("""Transferred:[ \t]*([0-9.]+ [MGKTmgkt]*Bytes)[ \t]*\(([0-9.]+ [MGKTmgkt]*Bytes)\/s\)""");

			//  Errors:                 0
			regex_list["errors"] = new Regex("""Errors:[ \t]*([0-9.]+)""");

			//  Checks:                 1
			regex_list["checks"] = new Regex("""Checks:[ \t]*([0-9.]+)""");

			//  Transferred:            0
			regex_list["trans"] = new Regex("""Transferred:[ \t]*([0-9.]+)""");

			//  Elapsed time:        1.7s
			regex_list["elapsed"] = new Regex("""Elapsed time:[ \t]*([0-9.]*h*[ ]*[0-9.]*m*[ ]*[0-9.]*s*)""");
		}
		catch (Error e) {
			log_error (e.message);
		}
	}
	
	public void prepare() {
	
		string script_text = build_script();

		log_debug(script_text);
		
		save_bash_script_temp(script_text, script_file);

		count_completed = 0;
		count_total = 100;
	}

	private string build_script() {
	
		var cmd = "rclone";

		switch (action){
		case RcloneActionType.COPY:
			cmd += " copy";
			break;
		case RcloneActionType.MOVE:
			cmd += " move";
			break;
		case RcloneActionType.DELETE:
			cmd += " delete";
			break;
		}

		cmd += " -v --stats=1s";

		if (dry_run){
			cmd += " --dry-run";
		}

		// filters ---------------------------
		
		string txt = "";
		foreach(string pattern in exclude_list){
			txt += "%s\n".printf(pattern);
		}

		log_debug(string.nfill(80,'-'));
		log_debug("Exclude Patterns:\n%s".printf(txt));
		log_debug(string.nfill(80,'-'));
		
		if (txt.length > 0){
			filter_from_file = path_combine(working_dir, "filter.list");
			file_write(filter_from_file, txt);
		}

		if (filter_from_file.length > 0){
			cmd += " --filter-from='%s'".printf(escape_single_quote(filter_from_file));
		}

		// source and dest ---------------------------

		// source
		source_path = remove_trailing_slash(source_path);
		cmd += " '%s/'".printf(escape_single_quote(source_path));
		
		switch (action){
		case RcloneActionType.COPY:
		case RcloneActionType.MOVE:
			// dest
			dest_path = remove_trailing_slash(dest_path);
			cmd += " '%s/'".printf(escape_single_quote(dest_path));
			break;
		case RcloneActionType.DELETE:
			// NA
			break;
		}
		
		return cmd;
	}

	public string add_rule_exclude(string file_path, bool is_directory){
		return add_rule(file_path, is_directory, false);
	}

	public string add_rule_include(string file_path, bool is_directory){
		return add_rule(file_path, is_directory, true);
	}

	public void add_rule_exclude_others(){
		exclude_list.add("- **");
	}
	
	private string add_rule(string file_path, bool is_directory, bool include){

		string relative_path = "";
		if (file_path.has_prefix(source_path)){
			relative_path = file_path[source_path.length + 1: file_path.length];
		}
		else{
			relative_path = file_path;
		}

		relative_path = relative_path.replace("*","\\*").replace("?","\\?").replace("#","\\#").replace("[","\\[").replace("]","\\]");

		string pattern = "%s%s%s".printf((include ? "+ " : "- "), relative_path, (is_directory ? "/**" : ""));
		exclude_list.add(pattern);
		
		return pattern;
	}
	
	// execution ----------------------------

	public void execute() {

		prepare();

		begin();

		if (status == AppStatus.RUNNING){
			
			
		}
	}

	public override void parse_stdout_line(string out_line){
	
		if (is_terminated) { return; }
		
		//update_progress_parse_console_output(out_line);
	}
	
	public override void parse_stderr_line(string err_line){
	
		if (is_terminated) { return; }

		update_progress_parse_console_output(err_line);
	}

	public bool update_progress_parse_console_output (string line) {

		if ((line == null) || (line.length == 0)) { return true; }

		MatchInfo match;
		if (regex_list["status"].match(line, 0, out match)) {

			//log_debug("match.fetch(1): %s".printf(match.fetch(1)));
			
			string txt = match.fetch(1);
			double completed = double.parse(txt.split(" ")[0]);
			
			switch(txt.split(" ")[1].up()){
			case "TBYTES":
				completed = completed * TB;
				break;
			case "GBYTES":
				completed = completed * GB;
				break;
			case "MBYTES":
				completed = completed * MB;
				break;
			case "KBYTES":
				completed = completed * KB;
				break;
			case "BYTES":
				// no multiplier needed
				break;
			}

			bytes_completed = (int64) completed;

			//log_debug("bytes_completed: %lld".printf(bytes_completed));
			
			rate = match.fetch(2);

			if (rate != null){
				rate = rate.replace("ytes","") + "/s";
			}

			if (bytes_total > 0){
				progress = ((bytes_completed * 1.0) / bytes_total);
			}

			//status_line = "%lld%%".printf(count_completed);
		}
		else if (regex_list["errors"].match(line, 0, out match)) {
			
			count_errors = int64.parse(match.fetch(1));
		}
		else if (regex_list["checks"].match(line, 0, out match)) {
		
			count_checks = int64.parse(match.fetch(1));
		}
		else if (regex_list["trans"].match(line, 0, out match)) {

			count_trans = int64.parse(match.fetch(1));
		}
		else if (regex_list["elapsed"].match(line, 0, out match)) {

			// catch and ignore
		}
		else{
			error_messages += "%s\n".printf(line);
		}

		return true;
	}

	protected override void finish_task(){
		if ((status != AppStatus.CANCELLED) && (status != AppStatus.PASSWORD_REQUIRED)) {
			status = AppStatus.FINISHED;
		}

		if (get_exit_code() != 0){
			log_error(error_messages);
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

	public string stats{
		owned get {

			string txt = "";

			txt += "%s".printf(format_file_size(bytes_completed));

			if (bytes_total > 0){
				txt += " / %s".printf(format_file_size(bytes_total));
			}

			txt += " %s".printf(_("transferred"));
			
			txt += " (%.0f%%),".printf(progress * 100.0);

			txt += " %s,".printf(rate);

			txt += " %s elapsed,".printf(stat_time_elapsed);

			txt += " %s remaining".printf(stat_time_remaining);

			return txt;
		}
	}
}
