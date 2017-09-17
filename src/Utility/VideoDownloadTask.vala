/*
 * VideoDownloadTask.vala
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

public enum VideoDownloadTaskType {
	LIST_FORMATS,
	DOWNLOAD_VIDEO
}

public class VideoDownloadFormat : GLib.Object {
	public string code = "";
	public string description = "";
}

public class VideoDownloadTask : AsyncTask {

	public string url = "";
	public string format = "";
	public string dest_path = "";
	public string thumb_url = "";
	public string thumb_path = "";
	public string duration = "";
	public string title = "";
	public string desc = "";

	public VideoDownloadTaskType action;

	public string error_log = "";

	public Gee.ArrayList<VideoDownloadFormat> list = new Gee.ArrayList<VideoDownloadFormat>();
	
	public VideoDownloadTask(string _url, string _dest_path){
		url = _url;
		dest_path = _dest_path;
		init_regular_expressions();
	}
	
	private void init_regular_expressions(){
		
		regex_list = new Gee.HashMap<string, Regex>();
		
		try {
			
			regex_list["list"] = new Regex("""^code='(.*)',ext='(.*)',type='(.*)',size='(.*)',note='(.*)'""");

			regex_list["info"] = new Regex("""^thumb_url='(.*)',thumb_path='(.*)',title='(.*)',duration='(.*)'""");

			//[download]   4.8% of 21.77MiB at 343.95KiB/s ETA 01:01
			regex_list["status"] = new Regex("""\[download\][ \t]*([0-9.]+)% of ([0-9.]+(K|M|G)iB) at ([0-9.]+(K|M|G)iB)\/s ETA ([0-9.:]+)""");
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

		string cmd = "polo-yt";
		
		switch(action){
		case VideoDownloadTaskType.LIST_FORMATS:
			cmd += " list";
			cmd += " --url '%s'".printf(url);
			break;
			
		case VideoDownloadTaskType.DOWNLOAD_VIDEO:
			cmd += " download";
			cmd += " --format '%s'".printf(format);
			cmd += " --output '%s'".printf(path_combine(dest_path, "%(title)s-%(id)s-" + format + ".%(ext)s"));
			cmd += " --url '%s'".printf(url);
			break;
		}

		cmd += " --scripted";

		log_debug(cmd);
		
		return cmd;
	}
	
	// execution ----------------------------

	public void list_formats(){
		//url = _url;
		action = VideoDownloadTaskType.LIST_FORMATS;
		execute();
	}

	public void download(){
		//url = _url;
		//format = _format;
		if (format.length == 0){ format = "best"; }
		action = VideoDownloadTaskType.DOWNLOAD_VIDEO;
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

		MatchInfo match;
		if (regex_list["list"].match(line, 0, out match)) {
			log_debug("format: %s".printf(line));

			string code = match.fetch(1);
			string ext = match.fetch(2);
			string type = match.fetch(3);
			string size = match.fetch(4);
			string note = match.fetch(5);

			string desc = ext.up();
			desc += (type.length > 0) ? " (%s)".printf(type) : "";
			desc += (size.length > 0) ? ", %s".printf(size) : "";
			desc += (note.length > 0) ? " ~ %s".printf(note) : "";
			
			var fmt = new VideoDownloadFormat();
			fmt.code = code;
			fmt.description = desc;
			list.add(fmt);
		}
		else if (regex_list["info"].match(line, 0, out match)) {
			log_debug("info: %s".printf(line));

			thumb_url = match.fetch(1);
			thumb_path = match.fetch(2);
			title = match.fetch(3);
			duration = match.fetch(4);
		}
		else if (regex_list["status"].match(line, 0, out match)) {
			//bytes_completed = int64.parse(match.fetch(1));
			progress = double.parse(match.fetch(1))/100.0;

			if (prg_bytes_total == 0){  // fetch the value only once
				switch(match.fetch(3)){
				case "K":
					prg_bytes_total = (int64) (double.parse(match.fetch(2)) * KiB);
					break;
				case "M":
					prg_bytes_total = (int64) (double.parse(match.fetch(2)) * MiB);
					break;
				case "G":
					prg_bytes_total = (int64) (double.parse(match.fetch(2)) * GiB);
					break;
				}
			}

			if (prg_bytes_total > 0){
				prg_bytes = (int64) (progress * prg_bytes_total);
			}

			rate = match.fetch(4) + "/s";
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
			
			if (prg_bytes_total > 0){
				txt = "%.2f %% complete, %s/%s downloaded, %s elapsed, %s remaining, %s".printf(
					progress * 100.0,
					format_file_size(prg_bytes, true, "", true),
					format_file_size(prg_bytes_total, true, "", true),
					stat_time_elapsed,
					stat_time_remaining,
					rate);
			}
			else{
				txt = "%.2f %% complete, %s elapsed, %s remaining".printf(
					progress * 100.0,
					stat_time_elapsed,
					stat_time_remaining);
			}

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
