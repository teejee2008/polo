
/*
 * TeeJee.ProcessHelper.vala
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
 
namespace TeeJee.ProcessHelper{
	using TeeJee.Logging;
	using TeeJee.FileSystem;
	using TeeJee.Misc;

	public string TEMP_DIR;
	
	/* Convenience functions for executing commands and managing processes */

	// execute process ---------------------------------
	
    public static void init_tmp(string subdir_name){
		string std_out, std_err;

		TEMP_DIR = Environment.get_tmp_dir() + "/" + subdir_name + "/" + random_string();
		dir_create(TEMP_DIR);

		exec_script_sync("echo 'ok'",out std_out,out std_err, true);
		if ((std_out == null)||(std_out.strip() != "ok")){
			TEMP_DIR = Environment.get_home_dir() + "/.temp/" + subdir_name + "/" + random_string();
			exec_sync("rm -rf '%s'".printf(TEMP_DIR), null, null);
			dir_create(TEMP_DIR);
		}

		//log_debug("TEMP_DIR=" + TEMP_DIR);
	}

	public string create_temp_subdir(){
		var temp = "%s/%s".printf(TEMP_DIR, random_string());
		dir_create(temp);
		return temp;
	}
	
	public int exec_sync (string cmd, out string? std_out, out string? std_err){

		/* Executes single command synchronously.
		 * Pipes and multiple commands are not supported.
		 * std_out, std_err can be null. Output will be written to terminal if null. */

		try {
			int status;
			Process.spawn_command_line_sync(cmd, out std_out, out std_err, out status);
	        return status;
		}
		catch (Error e){
	        log_error (e.message);
	        return -1;
	    }
	}
	
	public int exec_script_sync (string script,
		out string? std_out = null, out string? std_err = null,
		bool supress_errors = false, bool run_as_admin = false,
		bool cleanup_tmp = true, bool print_to_terminal = false){

		/* Executes commands synchronously.
		 * Pipes and multiple commands are fully supported.
		 * Commands are written to a temporary bash script and executed.
		 * std_out, std_err can be null. Output will be written to terminal if null.
		 * */

		std_out = "";
		std_err = "";

		string sh_file = save_bash_script_temp(script, null, true, supress_errors, run_as_admin);

		//log_debug("exec_script_sync(): %s".printf(sh_file));
		
		try {
			string[] argv = new string[1];
			argv[0] = sh_file;

			string[] env = Environ.get();

			int exit_code;

			if (print_to_terminal){
				
				Process.spawn_sync (
					file_parent(sh_file), //working dir
					argv, //argv
					env, //environment
					SpawnFlags.SEARCH_PATH,
					null,   // child_setup
					null,
					null,
					out exit_code
					);
			}
			else{
		
				Process.spawn_sync (
					file_parent(sh_file), //working dir
					argv, //argv
					env, //environment
					SpawnFlags.SEARCH_PATH,
					null,   // child_setup
					out std_out,
					out std_err,
					out exit_code
					);
			}

			// Process.spawn_sync() exit_code is not reliable when executed as script
			
			string status_file = path_combine(file_parent(sh_file), "status");
			if (file_exists(status_file)){
				exit_code = int.parse(file_read(status_file));
			}

			//log_debug("exec_script_sync(): exit_code: %d".printf(exit_code));

			if (cleanup_tmp){
				file_delete(sh_file);
			}
			
			return exit_code;
		}
		catch (Error e){
			if (!supress_errors){
				log_error (e.message);
			}
			return -1;
		}
	}

	public int exec_script_async (string script, bool admin_mode = false){

		/* Executes commands synchronously.
		 * Pipes and multiple commands are fully supported.
		 * Commands are written to a temporary bash script and executed.
		 * Return value indicates if script was started successfully.
		 *  */

		try {

			string sh_file = save_bash_script_temp (script, null, false, false, admin_mode);

			string[] argv = new string[1];
			argv[0] = sh_file;

			string[] env = Environ.get();
			
			Pid child_pid;
			Process.spawn_async_with_pipes(
			    file_parent(sh_file), //working dir
			    argv, //argv
			    env, //environment
			    SpawnFlags.SEARCH_PATH,
			    null,
			    out child_pid);

			return child_pid;
		}
		catch (Error e){
	        log_error (e.message);
	        return -1;
	    }
	}

	public string? save_bash_script_temp (string commands, string? script_path = null,
		bool force_locale = true, bool supress_errors = false, bool admin_mode = false){

		string sh_path = script_path;
		
		/* Creates a temporary bash script with given commands
		 * Returns the script file path */

		string sh = "";
		sh += "#!/bin/bash\n";
		sh += "\n";
		if (force_locale){
			sh += "LANG=C\n";
		}
		sh += "\n";
		sh += "%s\n".printf(commands);
		sh += "\n\nexitCode=$?\n";
		sh += "echo ${exitCode} > ${exitCode}\n";
		sh += "echo ${exitCode} > status\n";
		sh += "exit ${exitCode}\n";
		
		if ((sh_path == null) || (sh_path.length == 0)){
			sh_path = get_temp_file_path() + ".sh";
		}

		// write file
		file_write(sh_path, sh);
		// set execute permission
		chmod (sh_path, "u+x");

		if (admin_mode){
			
			sh = "";
			sh += "#!/bin/bash\n";
			sh += "pkexec env DISPLAY=$DISPLAY XAUTHORITY=$XAUTHORITY";
			sh += " '%s'\n".printf(escape_single_quote(sh_path));
			sh += "if [ -f status ]; then exit $(cat status); else exit 0; fi\n";

			string sh_path_admin = GLib.Path.build_filename(file_parent(sh_path),"script-admin.sh");

			// do not use script wrapper, write script file manually
			//save_bash_script_temp(script_admin, sh_file_admin, true, supress_errors);

			// write file
			file_write(sh_path_admin, sh);
			
			// set execute permission
			chmod (sh_path_admin, "u+x");
			
			return sh_path_admin;
		}
		else{
			return sh_path;
		}
	}

	public string get_temp_file_path(bool with_temp_folder = true){

		/* Generates temporary file path */

		string txt = "%s/%s".printf(TEMP_DIR, timestamp_numeric() + (new Rand()).next_int().to_string());

		if (with_temp_folder){
			dir_create(txt);
			txt += "/%s".printf(timestamp_numeric() + (new Rand()).next_int().to_string());
		}

		return txt;
	}

	public void exec_process_new_session(string command){
		exec_script_async("setsid %s &".printf(command));
	}
	
	// find process -------------------------------
	
	// dep: which
	public string get_cmd_path (string cmd_tool){

		/* Returns the full path to a command */

		try {
			int exitCode;
			string stdout, stderr;
			Process.spawn_command_line_sync("which " + cmd_tool, out stdout, out stderr, out exitCode);
			stdout = stdout.strip().replace("\n","");
	        return stdout;
		}
		catch (Error e){
	        log_error (e.message);
	        return "";
	    }
	}

	public bool cmd_exists(string cmd_tool){
		string path = get_cmd_path (cmd_tool);
		if ((path == null) || (path.length == 0)){
			return false;
		}
		else{
			return true;
		}
	}

	// dep: pidof, TODO: Rewrite using /proc
	public int get_pid_by_name (string name){

		/* Get the process ID for a process with given name */

		string std_out, std_err;
		exec_sync("pidof \"%s\"".printf(name), out std_out, out std_err);
		
		if (std_out != null){
			string[] arr = std_out.split ("\n");
			if (arr.length > 0){
				return int.parse (arr[0]);
			}
		}

		return -1;
	}

	public int get_pid_by_command(string cmdline){

		/* Searches for process using the command line used to start the process.
		 * Returns the process id if found.
		 * */
		 
		try {
			FileEnumerator enumerator;
			FileInfo info;
			File file = File.parse_name ("/proc");

			enumerator = file.enumerate_children ("standard::name", 0);
			while ((info = enumerator.next_file()) != null) {
				try {
					string io_stat_file_path = "/proc/%s/cmdline".printf(info.get_name());
					var io_stat_file = File.new_for_path(io_stat_file_path);
					if (file.query_exists()){
						var dis = new DataInputStream (io_stat_file.read());

						string line;
						string text = "";
						size_t length;
						while((line = dis.read_until ("\0", out length)) != null){
							text += " " + line;
						}

						if ((text != null) && text.contains(cmdline)){
							return int.parse(info.get_name());
						}
					} //stream closed
				}
				catch(Error e){
					// do not log
					// some processes cannot be accessed by non-admin user
				}
			}
		}
		catch(Error e){
		  log_error (e.message);
		}

		return -1;
	}

	public void get_proc_io_stats(int pid, out int64 read_bytes, out int64 write_bytes){

		/* Returns the number of bytes read and written by a process to disk */
		
		string io_stat_file_path = "/proc/%d/io".printf(pid);
		var file = File.new_for_path(io_stat_file_path);

		read_bytes = 0;
		write_bytes = 0;

		try {
			if (file.query_exists()){
				var dis = new DataInputStream (file.read());
				string line;
				while ((line = dis.read_line (null)) != null) {
					if(line.has_prefix("rchar:")){
						read_bytes = int64.parse(line.replace("rchar:","").strip());
					}
					else if(line.has_prefix("wchar:")){
						write_bytes = int64.parse(line.replace("wchar:","").strip());
					}
				}
			} //stream closed
		}
		catch(Error e){
			log_error (e.message);
		}
	}

	// dep: ps TODO: Rewrite using /proc
	public bool process_is_running(long pid){

		/* Checks if given process is running */

		string cmd = "";
		string std_out;
		string std_err;
		int ret_val;

		try{
			cmd = "ps --pid %ld".printf(pid);
			Process.spawn_command_line_sync(cmd, out std_out, out std_err, out ret_val);
		}
		catch (Error e) {
			log_error (e.message);
			return false;
		}

		return (ret_val == 0);
	}

	// dep: pgrep TODO: Rewrite using /proc
	public bool process_is_running_by_name(string proc_name){

		/* Checks if given process is running */

		string cmd = "";
		string std_out;
		string std_err;
		int ret_val;

		try{
			cmd = "pgrep -f '%s'".printf(proc_name);
			Process.spawn_command_line_sync(cmd, out std_out, out std_err, out ret_val);
		}
		catch (Error e) {
			log_error (e.message);
			return false;
		}

		return (ret_val == 0);
	}
	
	// dep: ps TODO: Rewrite using /proc
	public int[] get_process_children (Pid parent_pid){

		/* Returns the list of child processes spawned by given process */

		string std_out, std_err;
		exec_sync("ps --ppid %d".printf(parent_pid), out std_out, out std_err);

		int pid;
		int[] procList = {};
		string[] arr;

		foreach (string line in std_out.split ("\n")){
			
			arr = line.strip().split (" ");
			if (arr.length < 1) { continue; }

			pid = 0;
			pid = int.parse(arr[0]);

			if (pid != 0){
				procList += pid;

				var children = get_process_children(pid);
				foreach(var child_pid in children){
					procList += child_pid;
				}
			}
		}
		
		return procList;
	}

	public class Proc{
		
		public int pid = -1;
		public int ppid = -1;
		public string user = "";
		public double cpu = 0.0;
		public double mem = 0.0;
		public int64 rss = 0;
		public string cmdline = "";

		public Proc(){ }

		public static Proc[] list_processes(){

			string cmd = "ps -ewo pid,ppid,user,%cpu,%mem,rss,cmd";

			//log_debug(cmd);
			
			string std_out, std_err;
			exec_sync(cmd, out std_out, out std_err);

			Proc[] procList = {};

			/*
			USER       PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
			teejee   22053  0.0  0.0 180184  5668 pts/19   Ss   20:47   0:00 /usr/bin/fish
			*/

			//log_debug(std_out);

			foreach(string line in std_out.split("\n")){
				
				var match = regex_match("""([0-9]+)[ \t]+([0-9]+)[ \t]+([^ \t]+)[ \t]+([^ \t]+)[ \t]+([^ \t]+)[ \t]+([^ \t]+)[ \t]+(.+)""", line);
				
				if (match != null){

					//log_debug("match.fetch_all().length: %d".printf(match.fetch_all().length));
					
					if (match.fetch_all().length != 8){ continue; }

					var proc = new Proc();
					proc.pid = int.parse(match.fetch(1));
					proc.ppid = int.parse(match.fetch(2));
					proc.user = match.fetch(3);
					proc.cpu = double.parse(match.fetch(4));
					proc.mem = double.parse(match.fetch(5));
					proc.rss = int64.parse(match.fetch(6));
					proc.cmdline = match.fetch(7);

					if (proc.pid > 0){						
						procList += proc;
					}
				}
				else{
					//log_debug("match is null");
				}
			}

			//log_debug("procList.size: %d".printf(procList.length));
			
			return procList;
		}

		public static Proc[] enumerate_descendants(Pid parent_pid, Proc[]? process_list){
			
			Proc[]? procs = process_list;

			if (procs == null){
				procs = list_processes();
			}

			Proc[] descendants = {};

			foreach(var proc in procs){
				
				if (proc.ppid == parent_pid){
					
					descendants += proc;

					var procs2 = enumerate_descendants(proc.pid, procs);
					foreach(var child in procs2){
						descendants += proc;
					}
				}
			}
	
			return descendants;
		}
	}

	// manage process ---------------------------------
	
	public void process_quit(Pid process_pid, bool killChildren = true){

		/* Kills specified process and its children (optional).
		 * Sends signal SIGTERM to the process to allow it to quit gracefully.
		 * */

		if (process_pid < 1){ return; }

		int[] child_pids = get_process_children(process_pid);
		Posix.kill(process_pid, Posix.SIGTERM);
		log_debug("SIGTERM: pid=%d".printf(process_pid));
		
		if (killChildren){
			Pid childPid;
			foreach (long pid in child_pids){
				childPid = (Pid) pid;
				if (childPid > 1){
					Posix.kill(childPid, Posix.SIGTERM);
					log_debug("SIGTERM: pid=%d".printf(childPid));
				}
			}
		}
	}
	
	public void process_kill(Pid process_pid, bool killChildren = true){

		/* Kills specified process and its children (optional).
		 * Sends signal SIGKILL to the process to kill it forcefully.
		 * It is recommended to use the function process_quit() instead.
		 * */

		if (process_pid < 1){ return; }
		
		int[] child_pids = get_process_children (process_pid);
		Posix.kill (process_pid, Posix.SIGKILL);
		log_debug("SIGKILL: pid=%d".printf(process_pid));
		
		if (killChildren){
			Pid childPid;
			foreach (long pid in child_pids){
				childPid = (Pid) pid;
				if (childPid > 1){
					Posix.kill (childPid, Posix.SIGKILL);
					log_debug("SIGKILL: pid=%d".printf(childPid));
				}
			}
		}
	}

	// dep: kill
	public int process_pause (Pid procID){

		/* Pause/Freeze a process */

		return exec_sync ("kill -STOP %d".printf(procID), null, null);
	}

	// dep: kill
	public int process_resume (Pid procID){

		/* Resume/Un-freeze a process*/

		return exec_sync ("kill -CONT %d".printf(procID), null, null);
	}

	// dep: ps TODO: Rewrite using /proc
	public void process_quit_by_name(string cmd_name, string cmd_to_match, bool exact_match){

		/* Kills a specific command */
		
		string std_out, std_err;
		exec_sync ("ps w -C '%s'".printf(cmd_name), out std_out, out std_err);
		//use 'ps ew -C conky' for all users

		string pid = "";
		foreach(string line in std_out.split("\n")){
			if ((exact_match && line.has_suffix(" " + cmd_to_match))
			|| (!exact_match && (line.index_of(cmd_to_match) != -1))){
				pid = line.strip().split(" ")[0];
				Posix.kill ((Pid) int.parse(pid), 15);
				log_debug(_("Stopped") + ": [PID=" + pid + "] ");
			}
		}
	}

	// process priority ---------------------------------------
	
	public void process_set_priority (Pid procID, int prio){

		/* Set process priority */

		if (Posix.getpriority (Posix.PRIO_PROCESS, procID) != prio)
			Posix.setpriority (Posix.PRIO_PROCESS, procID, prio);
	}

	public int process_get_priority (Pid procID){

		/* Get process priority */

		return Posix.getpriority (Posix.PRIO_PROCESS, procID);
	}

	public void process_set_priority_normal (Pid procID){

		/* Set normal priority for process */

		process_set_priority (procID, 0);
	}

	public void process_set_priority_low (Pid procID){

		/* Set low priority for process */

		process_set_priority (procID, 5);
	}
}
