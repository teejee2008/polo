/*
 * ImageTask.vala
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

public enum ImageTaskType {
	OPTIMIZE_PNG,
	REDUCE_JPEG,
	DECOLOR,
	BOOST_COLOR,
	REDUCE_COLOR,
	RESIZE,
	ROTATE,
	CONVERT
}

public class ImageTask : AsyncTask {
	
	public Gee.ArrayList<string> files = new Gee.ArrayList<string>();
	
	public int width = 0;
	public int height = 0;
	public string format = "";
	public int quality = 0;
	public bool keep_aspect = true;
	public bool upscale = false;
	public bool inplace = false;
	public bool silent = false;
	public string rotate_direction = "";
	public string level = "";
	public Gee.ArrayList<string> output_files = new Gee.ArrayList<string>();
	
	public ImageTaskType action;

	public ImageTask(){
		init_regular_expressions();
	}
	
	private void init_regular_expressions(){
		
		regex_list = new Gee.HashMap<string, Regex>();
		
		try {
			//Batch: 1/1 complete
			regex_list["status"] = new Regex("""^Batch:[ \t]*([0-9.]+)/([0-9.]+)[ \t]*complete""");
			regex_list["input"] = new Regex("""^Input:[ \t]*(.*)""");
			regex_list["output"] = new Regex("""^(Created|Replaced):[ \t]*(.*)""");
		}
		catch (Error e) {
			log_error (e.message);
		}
	}
	
	public void prepare() {
	
		string script_text = build_script();
		script_file = save_bash_script_temp(script_text, script_file, true, false, false);

		count_completed = 0;
		count_total = files.size;
	}

	private string build_script() {
	
		var cmd = "polo-image";

		switch(action){
		case ImageTaskType.OPTIMIZE_PNG:
			cmd += " optimize-png";
			cmd += inplace ? " --inplace" : "";
			foreach(var file in files){
				cmd += " '%s'".printf(escape_single_quote(file));
			}
			break;
			
		case ImageTaskType.REDUCE_JPEG:
			cmd += " reduce-jpeg";
			cmd += inplace ? " --inplace" : "";
			foreach(var file in files){
				cmd += " '%s'".printf(escape_single_quote(file));
			}
			break;

		case ImageTaskType.DECOLOR:
			cmd += " decolor";
			cmd += inplace ? " --inplace" : "";
			foreach(var file in files){
				cmd += " '%s'".printf(escape_single_quote(file));
			}
			break;

		case ImageTaskType.BOOST_COLOR:
			cmd += " boost-color";
			cmd += " --level %s".printf(level);
			cmd += inplace ? " --inplace" : "";
			foreach(var file in files){
				cmd += " '%s'".printf(escape_single_quote(file));
			}
			break;

		case ImageTaskType.REDUCE_COLOR:
			cmd += " reduce-color";
			cmd += " --level %s".printf(level);
			cmd += inplace ? " --inplace" : "";
			foreach(var file in files){
				cmd += " '%s'".printf(escape_single_quote(file));
			}
			break;
			
		case ImageTaskType.RESIZE:
			cmd += " resize";
			cmd += " --width %d".printf(width);
			cmd += " --height %d".printf(height);
			cmd += inplace ? " --inplace" : "";
			foreach(var file in files){
				cmd += " '%s'".printf(escape_single_quote(file));
			}
			break;
			
		case ImageTaskType.ROTATE:
			cmd += " rotate";
			cmd += " --rotation %s".printf(rotate_direction);
			cmd += inplace ? " --inplace" : "";
			foreach(var file in files){
				cmd += " '%s'".printf(escape_single_quote(file));
			}
			break;
			
		case ImageTaskType.CONVERT:
			cmd += " convert";
			cmd += " --format %s".printf(format.down());
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

	public void optimize_png(Gee.ArrayList<string> _files, bool _inplace){
		action = ImageTaskType.OPTIMIZE_PNG;
		files = _files;
		inplace = _inplace;
		//execute();
	}
	
	public void reduce_jpeg(Gee.ArrayList<string> _files, bool _inplace){
		action = ImageTaskType.REDUCE_JPEG;
		files = _files;
		inplace = _inplace;
		//execute();
	}

	public void decolor(Gee.ArrayList<string> _files, bool _inplace){
		action = ImageTaskType.DECOLOR;
		files = _files;
		inplace = _inplace;
		//execute();
	}

	public void boost_color(Gee.ArrayList<string> _files, string _level, bool _inplace){
		action = ImageTaskType.BOOST_COLOR;
		files = _files;
		level = _level;
		inplace = _inplace;
		//execute();
	}

	public void reduce_color(Gee.ArrayList<string> _files, string _level, bool _inplace){
		action = ImageTaskType.REDUCE_COLOR;
		files = _files;
		level = _level;
		inplace = _inplace;
		//execute();
	}

	public void resize(Gee.ArrayList<string> _files, int _width, int _height, bool _inplace){
		action = ImageTaskType.RESIZE;
		files = _files;
		inplace = _inplace;
		width = _width;
		height = _height;
		//execute();
	}

	public void rotate(Gee.ArrayList<string> _files, string _direction, bool _inplace){
		action = ImageTaskType.ROTATE;
		files = _files;
		rotate_direction = _direction;
		inplace = _inplace;
		//execute();
	}

	public void convert(Gee.ArrayList<string> _files, string _format, int _quality, bool _inplace){
		action = ImageTaskType.CONVERT;
		files = _files;
		format = _format;
		quality = _quality;
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

		log_error(err_line);

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
			output_files.add(match.fetch(2).strip());
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

	public override string get_error_message(){

		// cleanup some verbose debug messages from pngcrush

		string msg = "";
		foreach(string line in error_msg.split("\n")){
			if ((action == ImageTaskType.OPTIMIZE_PNG) && line.has_prefix(" | ")){
				continue; // skip line
			}
			msg += "%s\n".printf(line);
		}

		return msg.strip();
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
