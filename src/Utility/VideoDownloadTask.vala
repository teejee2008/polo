/*
 * VideoDownloadTask.vala
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

public enum VideoDownloadTaskType {
	LIST_FORMATS,
	DOWNLOAD_VIDEO
}

public class VideoDownloadFormat : GLib.Object {
	
	public string code = "";
	public string ext = "";
	public string resolution = "";
	public string type = "";
	public string size = "";
	public string note = "";
	//public string description = "";

	private string _description = "";
	public string description {
		owned get {

			if (_description.length > 0){ return _description; }

			string txt = "";
			
			switch(type){
			case "audio":
				txt += _("Audio");
				txt += (format.length > 0) ? " %s".printf(format) : "";
				txt += (audio_codec.length > 0) ? " %s".printf(audio_codec) : "";
				txt += (audio_bitrate.length > 0) ? " (%s)".printf(audio_bitrate) : "";
				break;
				
			case "video":
				txt += _("Video");
				txt += (format.length > 0) ? " %s".printf(format) : "";
				txt += (video_codec.length > 0) ? " %s".printf(video_codec) : "";
				txt += (video_resolution.length > 0) ? " (%s)".printf(video_resolution) : "";
				break;

			case "audio+video":
				txt += "%s".printf(format);
				txt += (video_codec.length > 0) ? " %s".printf(video_codec) : "";
				txt += (video_resolution.length > 0) ? " (%s)".printf(video_resolution) : "";
				txt += " ~";
				txt += (audio_codec.length > 0) ? " %s".printf(audio_codec) : "";
				txt += (audio_bitrate.length > 0) ? " (%s)".printf(audio_bitrate) : "";
				break;
				
			default:
				txt += "%s".printf(format);
				break;
			}

			if (size.length > 0){
				txt += " ~ %s".printf(size);
			}

			if (txt.strip().length == 0){
				txt = code;
			}

			_description = txt;

			return txt;
		}
	}

	private string _format = "";
	public string format {
		owned get {

			if (_format.length > 0){ return _format; }
			
			string txt = "";
			
			if (ext == "webm"){
				txt += "WebM";
			}
			else {
				// mp4, 3gp, m4a
				txt += ext.up();
			}

			_format = txt;
			
			return txt;
		}
	}

	private string _audio_codec = "";
	public string audio_codec {
		owned get {

			if (_audio_codec.length > 0){ return _audio_codec; }
			
			string txt = "";
			
			if (note.down().contains("opus")){
				txt += "Opus";
			}
			else if (note.down().contains("vorbis")){
				txt += "Vorbis";
			}
			else if (note.down().contains("m4a") || note.down().contains("mp4a")){
				txt += "AAC";
			}

			_audio_codec = txt;
			
			return txt;
		}
	}

	private string _audio_bitrate = "";
	public string audio_bitrate {
		owned get {

			if (_audio_bitrate.length > 0){ return _audio_bitrate; }
			
			string txt = "";

			if (type == "audio"){
			
				var match = regex_match("""([0-9]+k)""", note);
				if (match != null){
					txt = match.fetch(1);
				}
			}
			else if (type == "audio+video"){

				var s = note;
				s = s[s.index_of("opus")   + 4 : s.length];
				s = s[s.index_of("vorbis") + 6 : s.length];
				s = s[s.index_of("m4a")    + 3 : s.length];
				s = s[s.index_of("mp4a")   + 4 : s.length];

				var match = regex_match("""([0-9]+k)""", s);
				if (match != null){
					txt = match.fetch(1);
				}
			}

			_audio_bitrate = txt;
			
			return txt;
		}
	}

	private string _video_codec = "";
	public string video_codec {
		owned get {

			if (_video_codec.length > 0){ return _video_codec; }
			
			string txt = "";
			
			if (note.down().contains("avc1")){
				txt += "H264-AVC";
			}
			else if (note.down().contains("vp8")){
				txt += "VP8";
			}
			else if (note.down().contains("vp9")){
				txt += "VP9";
			}

			_video_codec = txt;
			
			return txt;
		}
	}

	private string _video_resolution = "";
	public string video_resolution {
		owned get {

			if (_video_resolution.length > 0){ return _video_resolution; }
			
			string txt = "";

			var match = regex_match("""([0-9])+x([0-9]+)""", resolution);
			if (match != null){
				txt = match.fetch(2) + "p";
			}

			if (txt.length == 0){
				
				match = regex_match("""([0-9])+x([0-9]+)""", note);
				if (match != null){
					txt = match.fetch(2) + "p";
				}
			}

			if (txt.length == 0){

				match = regex_match("""([0-9]+p)""", note);
				if (match != null){
					txt = match.fetch(1);
				}
			}

			if (txt.length == 0){

				match = regex_match("""^(small|medium|large),""", note);
				if (match != null){
					txt = match.fetch(1);
				}
			}

			if (txt.length == 0){

				if (note.contains("hd720")){
					txt = "720p";
				}
			}

			//if (txt == "720p"){
			//	txt = "HD";
			//}
			//else if (txt == "1080p"){
			//	txt = "FHD";
			//}

			if (video_fps == "60"){
				txt += "60";
			}

			_video_resolution = txt;
			
			return txt;
		}
	}

	private string _video_bitrate = "";
	public string video_bitrate {
		owned get {

			if (_video_bitrate.length > 0){ return _video_bitrate; }
			
			string txt = "";
			
			var match = regex_match("""([0-9]+k)""", note);
			if (match != null){
				txt = match.fetch(1);
			}

			_video_bitrate = txt;
			
			return txt;
		}
	}

	private string _video_fps = "";
	public string video_fps {
		owned get {

			if (_video_fps.length > 0){ return _video_fps; }
			
			string txt = "";
			
			var match = regex_match("""([0-9]+)fps""", note);
			if (match != null){
				txt = match.fetch(1);
			}

			_video_fps = txt;
			
			return txt;
		}
	}

	private string _tooltip_text = "";
	public string tooltip_text {
		owned get {

			if (_tooltip_text.length > 0){ return _tooltip_text; }
			
			string txt = "";
			
			txt += (code.length > 0) ? "%s: %s\n".printf(_("Code"), code) : "";
			txt += (ext.length > 0) ? "%s: %s\n".printf(_("Extension"), ext) : "";
			txt += (resolution.length > 0) ? "%s: %s\n".printf(_("Resolution"), resolution) : "";
			txt += (type.length > 0) ? "%s: %s\n".printf(_("Type"), type) : "";
			txt += (size.length > 0) ? "%s: %s\n".printf(_("Size"), size) : "";
			txt += (note.length > 0) ? "%s: %s\n".printf(_("Notes"), note) : "";

			txt += "%s\n".printf(string.nfill(40,'-'));

			txt += (video_codec.length > 0) ? "%s: %s\n".printf(_("Video Codec"), video_codec) : "";
			txt += (video_resolution.length > 0) ? "%s: %s\n".printf(_("Video Resolution"), video_resolution) : "";
			txt += (audio_codec.length > 0) ? "%s: %s\n".printf(_("Audio Codec"), audio_codec) : "";
			txt += (audio_bitrate.length > 0) ? "%s: %s\n".printf(_("Audio Bitrate"), audio_bitrate) : "";

			_tooltip_text = txt;
			
			return txt;
		}
	}
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
			
			regex_list["list"] = new Regex("""^code='(.*)',ext='(.*)',resolution='(.*)',type='(.*)',size='(.*)',note='(.*)'""");

			regex_list["info"] = new Regex("""^thumb_url='(.*)',thumb_path='(.*)',title='(.*)',duration='(.*)'""");

			//[download]   4.8% of 21.77MiB at 343.95KiB/s ETA 01:01
			regex_list["status"] = new Regex("""\[download\][ \t]*([0-9.]+)%[ \t]*of[ \t]*([0-9.]+(K|M|G)iB)[ \t]*at[ \t]*([0-9.]+(K|M|G)iB)\/s[ \t]*ETA[ \t]*([0-9.:]+)""");
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
			string res = match.fetch(3);
			string type = match.fetch(4);
			string size = match.fetch(5);
			string note = match.fetch(6);

			var fmt = new VideoDownloadFormat();
			fmt.code = code;
			fmt.ext = ext;
			fmt.resolution = res;
			fmt.type = type.down();
			fmt.size = size;
			fmt.note = note.down();
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

		list.sort((a,b)=>{

			if (a.type == "audio"){
				
				switch(b.type){
				case "audio":
					if ((a.audio_bitrate.length > 0) && (b.audio_bitrate.length > 0)
						&& (a.format == b.format) && (a.audio_codec == b.audio_codec)){
						return int.parse(a.audio_bitrate) - int.parse(b.audio_bitrate);
					}
					else{
						return strcmp(a.description, b.description);
					}
					
				case "video":
					return -1;
					
				case "audio+video":
					return 1;
					
				default:
					return strcmp(a.description, b.description);
				}
			}
			else if (a.type == "video"){

				switch(b.type){
				case "audio":
					return 1;
					
				case "video":
					if ((a.video_resolution.length > 0) && (b.video_resolution.length > 0)
						&& (a.format == b.format) && (a.video_codec == b.video_codec)){
						return int.parse(a.video_resolution) - int.parse(b.video_resolution);
					}
					else{
						return strcmp(a.description, b.description);
					}
					
				case "audio+video":
					return 1;
					
				default:
					return strcmp(a.description, b.description);
				}
			}
			else if (a.type == "audio+video"){

				switch(b.type){
				case "audio":
					return -1;
					
				case "video":
					return -1;
					
				case "audio+video":

					if ((a.video_resolution.length > 0) && (b.video_resolution.length > 0)
						&& (a.format == b.format) && (a.video_codec == b.video_codec)){
						return int.parse(a.video_resolution) - int.parse(b.video_resolution);
					}
					else{
						return strcmp(a.description, b.description);
					}
					
				default:
					return strcmp(a.description, b.description);
				}
			}
			else {
				return strcmp(a.description, b.description);
			}
		});

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
