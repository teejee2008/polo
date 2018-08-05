/*
 * GvfsTask.vala
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

public enum GvfsTaskType {
	MOUNT,
	UNMOUNT
}

public class GvfsTask : AsyncTask {
	
	public string uri = "";
	public string domain = "";
	public string username = "";
	public string password = "";

	public GvfsTaskType action;
	
	public GvfsTask(){
		init_regular_expressions();
	}
	
	private void init_regular_expressions(){
		
		regex_list = new Gee.HashMap<string, Regex>();
		
		try {
			// none
		}
		catch (Error e) {
			log_error (e.message);
		}
	}
	
	public void prepare() {
	
		string script_text = build_script();
		script_file = save_bash_script_temp(script_text, script_file, true, false, false);

		//count_completed = 0;
		//count_total = (action == PdfTaskType.MERGE) ? 1 : files.size;
	}

	private string build_script() {

		string sh = "";
		string cmd = "";
		
		switch(action){
		case GvfsTaskType.MOUNT:
		
			if (uri.has_prefix("smb://")){
				
				sh += "echo '%s' >> samba.props \n".printf(escape_single_quote(username));
				sh += "echo '%s' >> samba.props \n".printf(escape_single_quote(domain));
				sh += "echo '%s' >> samba.props \n".printf(escape_single_quote(password));
				
				cmd = "gio mount '%s' < ./samba.props".printf(escape_single_quote(uri));
				sh += cmd + "\n";
			}
			else{
				// ftp://server:port, will ask for username and password
				// pass {empty, empty} or {anonymous, empty}
				// or use ftp://anonymous@server:port, which will not ask for username or password
				sh += "echo '%s' >> samba.props \n".printf(escape_single_quote(username));
				sh += "echo '%s' >> samba.props \n".printf(escape_single_quote(password));
				
				cmd = "gio mount '%s' < ./samba.props".printf(escape_single_quote(uri));
				sh += cmd + "\n";
			}

			break;
			
		case GvfsTaskType.UNMOUNT:
			cmd += "gio mount -u '%s'".printf(escape_single_quote(uri));
			sh += cmd + "\n";
			break;
		}

		log_debug(cmd);

		return sh;
	}
	
	// execution ----------------------------

	public void mount(string _uri, string _domain, string _username, string _password){
		action = GvfsTaskType.MOUNT;
		uri = _uri;
		domain = _domain;
		username = _username;
		password = _password;
		//execute();
	}
	
	public void unmount(string _uri){
		action = GvfsTaskType.UNMOUNT;
		uri = _uri;
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

		log_error(out_line); // any output from gvfs-mount indicates error
		
		// nothing to parse
	}
	
	public override void parse_stderr_line(string err_line){

		if (is_terminated) { return; }

		log_error(err_line);

		// nothing to parse
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
}
