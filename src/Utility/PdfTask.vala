/*
 * PdfTask.vala
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

public enum PdfTaskType {
	SPLIT,
	MERGE,
	COMPRESS,
	UNCOMPRESS,
	PROTECT,
	UNPROTECT,
	DECOLOR,
	OPTIMIZE,
	ROTATE
}

public class PdfTask : AsyncTask {
	
	public Gee.ArrayList<string> files = new Gee.ArrayList<string>();
	
	public string optimize_target = "";
	public string rotate_direction = "";
	public string password = "";
	public bool inplace = false;
	
	public PdfTaskType action;

	public Gee.ArrayList<string> output_files = new Gee.ArrayList<string>();
	
	public PdfTask(){
		init_regular_expressions();
	}
	
	private void init_regular_expressions(){
		
		regex_list = new Gee.HashMap<string, Regex>();
		
		try {
			//Batch: 1/1 complete
			regex_list["status"] = new Regex("""^Batch:[ \t]*([0-9.]+)/([0-9.]+)[ \t]*complete""");
			regex_list["input"] = new Regex("""^Input:[ \t]*(.*)""");
			regex_list["output"] = new Regex("""^((Created|Replaced|Removed):[ \t]*(.*))""");
		}
		catch (Error e) {
			log_error (e.message);
		}
	}
	
	public void prepare() {
	
		string script_text = build_script();
		script_file = save_bash_script_temp(script_text, script_file, true, false, false);

		count_completed = 0;
		count_total = (action == PdfTaskType.MERGE) ? 1 : files.size;
	}

	private string build_script() {
	
		var cmd = "polo-pdf";

		switch(action){
		case PdfTaskType.SPLIT:
			cmd += " split";
			cmd += inplace ? " --inplace" : "";
			foreach(var file in files){
				cmd += " '%s'".printf(escape_single_quote(file));
			}
			break;
			
		case PdfTaskType.MERGE:
			cmd += " merge";
			cmd += inplace ? " --inplace" : "";
			foreach(var file in files){
				cmd += " '%s'".printf(escape_single_quote(file));
			}
			break;
			
		case PdfTaskType.COMPRESS:
			cmd += " compress";
			cmd += inplace ? " --inplace" : "";
			foreach(var file in files){
				cmd += " '%s'".printf(escape_single_quote(file));
			}
			break;
			
		case PdfTaskType.UNCOMPRESS:
			cmd += " uncompress";
			cmd += inplace ? " --inplace" : "";
			foreach(var file in files){
				cmd += " '%s'".printf(escape_single_quote(file));
			}
			break;
			
		case PdfTaskType.PROTECT:
			cmd += " protect";
			cmd += " --pass '%s'".printf(escape_single_quote(password));
			cmd += inplace ? " --inplace" : "";
			foreach(var file in files){
				cmd += " '%s'".printf(escape_single_quote(file));
			}
			break;
			
		case PdfTaskType.UNPROTECT:
			cmd += " unprotect";
			cmd += " --pass '%s'".printf(escape_single_quote(password));
			cmd += inplace? " --inplace" : "";
			foreach(var file in files){
				cmd += " '%s'".printf(escape_single_quote(file));
			}
			break;
			
		case PdfTaskType.DECOLOR:
			cmd += " decolor";
			cmd += inplace ? " --inplace" : "";
			foreach(var file in files){
				cmd += " '%s'".printf(escape_single_quote(file));
			}
			break;
			
		case PdfTaskType.OPTIMIZE:
			cmd += " optimize";
			cmd += " --target %s".printf(optimize_target);
			cmd += inplace ? " --inplace" : "";
			foreach(var file in files){
				cmd += " '%s'".printf(escape_single_quote(file));
			}
			break;
			
		case PdfTaskType.ROTATE:
			cmd += " rotate";
			cmd += " --rotation %s".printf(rotate_direction);
			cmd += inplace ? " --inplace" : "";
			foreach(var file in files){
				cmd += " '%s'".printf(escape_single_quote(file));
			}
			break;
		}

		log_debug(cmd);
		
		return cmd;
	}
	
	// execution ----------------------------

	public void split(Gee.ArrayList<string> _files, bool _inplace){
		action = PdfTaskType.SPLIT;
		files = _files;
		inplace = _inplace;
		//execute();
	}
	
	public void merge(Gee.ArrayList<string> _files, bool _inplace){
		action = PdfTaskType.MERGE;
		files = _files;
		inplace = _inplace;
		//execute();
	}

	public void compress(Gee.ArrayList<string> _files, bool _inplace){
		action = PdfTaskType.COMPRESS;
		files = _files;
		inplace = _inplace;
		//execute();
	}

	public void uncompress(Gee.ArrayList<string> _files, bool _inplace){
		action = PdfTaskType.UNCOMPRESS;
		files = _files;
		inplace = _inplace;
		//execute();
	}

	public void protect(Gee.ArrayList<string> _files, string _password, bool _inplace){
		action = PdfTaskType.PROTECT;
		files = _files;
		password = _password;
		inplace = _inplace;
		//execute();
	}

	public void unprotect(Gee.ArrayList<string> _files, string _password, bool _inplace){
		action = PdfTaskType.UNPROTECT;
		files = _files;
		password = _password;
		inplace = _inplace;
		//execute();
	}

	public void decolor(Gee.ArrayList<string> _files, bool _inplace){
		action = PdfTaskType.DECOLOR;
		files = _files;
		inplace = _inplace;
		//execute();
	}

	public void optimize(Gee.ArrayList<string> _files, string target, bool _inplace){
		action = PdfTaskType.OPTIMIZE;
		files = _files;
		optimize_target = target;
		inplace = _inplace;
		//execute();
	}

	public void rotate(Gee.ArrayList<string> _files, string direction, bool _inplace){
		action = PdfTaskType.ROTATE;
		files = _files;
		rotate_direction = direction;
		inplace = _inplace;
		//execute();
	}
	
	public void execute() {

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

		log_msg("ERR:" + err_line);
		
		update_progress_parse_console_output(err_line);
	}

	public bool update_progress_parse_console_output (string line) {

		if ((line == null) || (line.length == 0)) { return true; }

		mutex_parser.lock();
		
		MatchInfo match;
		if (regex_list["status"].match(line, 0, out match)) {
			count_completed = int64.parse(match.fetch(1));
			progress = (count_completed * 1.0) / count_total;
		}
		else if (regex_list["input"].match(line, 0, out match)) {
			current_file = file_basename(match.fetch(1).strip());
		}
		else if (regex_list["output"].match(line, 0, out match)){
			output_files.add(match.fetch(1).strip());
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
