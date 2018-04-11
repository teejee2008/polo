
/*
 * TeeJee.ProcessHelper.vala
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
 
namespace TeeJee.ProcessHelper{
	
	using TeeJee.Logging;
	using TeeJee.FileSystem;
	using TeeJee.Misc;

	public string TEMP_DIR;
	
	/* Convenience functions for executing commands and managing processes */

	// execute process ---------------------------------
	
    public static void init_tmp(string subdir_name){

		TEMP_DIR = Environment.get_tmp_dir() + "/" + subdir_name;
		dir_create(TEMP_DIR);
		chmod(TEMP_DIR, "a+rwx"); // allow application to create folders when running as nomal user

		//log_msg("chmod: %s: %s".printf(TEMP_DIR, "a+rwx"));
		
		TEMP_DIR += "/" + random_string();
		dir_create(TEMP_DIR);
		chmod(TEMP_DIR, "a+rwx");

		//log_msg("chmod: %s: %s".printf(TEMP_DIR, "a+rwx"));

		string std_out, std_err;
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
		chmod (sh_path, "a+x");

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
			chmod(sh_path_admin, "a+x");
			
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
}
