
/*
 * TeeJee.System.vala
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

extern void exit(int exit_code);

namespace TeeJee.System{

	using TeeJee.ProcessHelper;
	using TeeJee.Logging;
	using TeeJee.Misc;
	using TeeJee.FileSystem;
	
	// user ---------------------------------------------------

	public void check_admin_access(){ 
     
		if (!user_is_admin()){ 

			log_error("Admin access is needed!"); 
			log_error("Run as root, or using 'sudo' or 'pkexec'"); 
			exit(1); 
		} 
	}
  
	public bool user_is_admin(){
		
		return (get_user_id_effective() == 0);
	}
	
	public int get_user_id(){

		// returns actual user id of current user (even for applications executed with sudo and pkexec)
		
		string pkexec_uid = GLib.Environment.get_variable("PKEXEC_UID");

		if (pkexec_uid != null){
			return int.parse(pkexec_uid);
		}

		string sudo_user = GLib.Environment.get_variable("SUDO_USER");

		if (sudo_user != null){
			return get_user_id_from_username(sudo_user);
		}

		return get_user_id_effective(); // normal user
	}

	public int get_user_id_effective(){
		
		// returns effective user id (0 for applications executed with sudo and pkexec)

		int uid = -1;
		string cmd = "id -u";
		string std_out, std_err;
		exec_sync(cmd, out std_out, out std_err);
		if ((std_out != null) && (std_out.length > 0)){
			uid = int.parse(std_out);
		}

		return uid;
	}
	
	public string get_username(){

		// returns actual username of current user (even for applications executed with sudo and pkexec)
		
		return get_username_from_uid(get_user_id());
	}

	public string get_username_effective(){

		// returns effective user id ('root' for applications executed with sudo and pkexec)
		
		return get_username_from_uid(get_user_id_effective());
	}

	public int get_user_id_from_username(string username){
		
		int user_id = -1;

		foreach(var line in file_read("/etc/passwd").split("\n")){
			var arr = line.split(":");
			if (arr.length < 3) { continue; }
			if (arr[0] == username){
				user_id = int.parse(arr[2]);
				break;
			}
		}

		return user_id;
	}

	public string get_username_from_uid(int user_id){
		
		string username = "";

		foreach(var line in file_read("/etc/passwd").split("\n")){
			var arr = line.split(":");
			if (arr.length < 3) { continue; }
			if (int.parse(arr[2]) == user_id){
				username = arr[0];
				break;
			}
		}

		return username;
	}

	public string get_user_home(string username = get_username()){
		
		string userhome = "";

		foreach(var line in file_read("/etc/passwd").split("\n")){
			var arr = line.split(":");
			if (arr.length < 6) { continue; }
			if (arr[0] == username){
				userhome = arr[5];
				break;
			}
		}

		return userhome;
	}

	public string get_user_home_effective(){
		return get_user_home(get_username_effective());
	}
	
	// application -----------------------------------------------
	
	public string get_app_path(){

		/* Get path of current process */

		try{
			return GLib.FileUtils.read_link ("/proc/self/exe");
		}
		catch (Error e){
	        log_error (e.message);
	        return "";
	    }
	}

	public string get_app_dir(){

		/* Get parent directory of current process */

		try{
			return (File.new_for_path (GLib.FileUtils.read_link ("/proc/self/exe"))).get_parent ().get_path ();
		}
		catch (Error e){
	        log_error (e.message);
	        return "";
	    }
	}

	// system ------------------------------------

	// dep: cat TODO: rewrite
	public double get_system_uptime_seconds(){

		/* Returns the system up-time in seconds */

		string cmd = "";
		string std_out;
		string std_err;
		int ret_val;

		try{
			cmd = "cat /proc/uptime";
			Process.spawn_command_line_sync(cmd, out std_out, out std_err, out ret_val);
			string uptime = std_out.split(" ")[0];
			double secs = double.parse(uptime);
			return secs;
		}
		catch(Error e){
			log_error (e.message);
			return 0;
		}
	}

	public Gee.ArrayList<string> list_dir_names(string path){
		var list = new Gee.ArrayList<string>();
		
		try
		{
			File f_home = File.new_for_path (path);
			FileEnumerator enumerator = f_home.enumerate_children ("%s".printf(FileAttribute.STANDARD_NAME), 0);
			FileInfo file;
			while ((file = enumerator.next_file ()) != null) {
				string name = file.get_name();
				//string item = path + "/" + name;
				list.add(name);
			}
		}
		catch (Error e) {
			log_error (e.message);
		}

		//sort the list
		CompareDataFunc<string> entry_compare = (a, b) => {
			return strcmp(a,b);
		};
		list.sort((owned) entry_compare);

		return list;
	}

	// internet helpers ----------------------
	
	public bool check_internet_connectivity(){
		
		bool connected = false;
		connected = check_internet_connectivity_test();

		if (connected){
			return connected;
		}
		
		if (!connected){
			log_error("Internet connection is not active");
		}

	    return connected;
	}

	public bool check_internet_connectivity_test(){
		
		string std_err, std_out;

		string cmd = "url='http://google.com'\n";
		
		cmd += "httpCode=$(curl -o /dev/null --silent --head --write-out '%{http_code}\n' $url)";
		
		cmd += "test $httpCode -lt 400 && test $httpCode -gt 0\n";
		
		cmd += "exit $?";
		
		int status = exec_script_sync(cmd, out std_out, out std_err, false);

	    return (status == 0);
	}

	public bool check_internet_connectivity_test1(){

		// Deprecated: 'ping' may be disabled on enterprise systems

		string std_err, std_out;

		string cmd = "ping -q -w 1 -c 1 `ip r | grep default | cut -d ' ' -f 3`\n";
		
		cmd += "exit $?";
		
		int status = exec_script_sync(cmd, out std_out, out std_err, false);

	    return (status == 0);
	}

	public bool check_internet_connectivity_test2(){

		// Deprecated: 'ping' may be disabled on enterprise systems
		
		string std_err, std_out;

		string cmd = "ping -q -w 1 -c 1 google.com\n";
		
		cmd += "exit $?";
		
		int status = exec_script_sync(cmd, out std_out, out std_err, false);

	    return (status == 0);
	}

	public bool shutdown (){

		/* Shutdown the system immediately */

		try{
			string[] argv = { "shutdown", "-h", "now" };
			Pid procId;
			Process.spawn_async(null, argv, null, SpawnFlags.SEARCH_PATH, null, out procId);
			return true;
		}
		catch (Error e) {
			log_error (e.message);
			return false;
		}
	}

	public bool command_exists(string command){
		string path = get_cmd_path(command);
		return ((path != null) && (path.length > 0));
	}
	
	// open -----------------------------

	public bool xdg_open (string file, string user = ""){
		
		string path = get_cmd_path ("xdg-open");
		
		if ((path != null) && (path != "")){
			
			string cmd = "xdg-open '%s'".printf(escape_single_quote(file));
			
			if (user.length > 0){
				cmd = "pkexec --user %s env DISPLAY=$DISPLAY XAUTHORITY=$XAUTHORITY ".printf(user) + cmd;
			}
			
			log_debug(cmd);
			
			int status = exec_script_async(cmd);
			
			return (status == 0);
		}
		
		return false;
	}

	public bool using_efi_boot(){
		
		/* Returns true if the system was booted in EFI mode
		 * and false for BIOS mode */
		 
		return dir_exists("/sys/firmware/efi");
	}

	public void open_terminal_window(
		string terminal_emulator,
		string working_dir,
		string script_file_to_execute,
		bool run_as_admin){
			
		string cmd = "";
		if (run_as_admin){
			cmd += "pkexec env DISPLAY=$DISPLAY XAUTHORITY=$XAUTHORITY ";
		}

		string term = terminal_emulator;
		if (!command_exists(term)){
			term = "gnome-terminal";
			if (!command_exists(term)){
				term = "xfce4-terminal";
			}
		}

		cmd += term;
		
		switch (term){
		case "gnome-terminal":
		case "xfce4-terminal":
			if (working_dir.length > 0){
				cmd += " --working-directory='%s'".printf(escape_single_quote(working_dir));
			}
			if (script_file_to_execute.length > 0){
				cmd += " -e '%s\n; echo Press ENTER to exit... ; read dummy;'".printf(escape_single_quote(script_file_to_execute));
			}
			break;
		}

		log_debug(cmd);
		exec_script_async(cmd);
	}
	
	// timers --------------------------------------------------
	
	public GLib.Timer timer_start(){
		var timer = new GLib.Timer();
		timer.start();
		return timer;
	}

	public void timer_restart(GLib.Timer timer){
		timer.reset();
		timer.start();
	}

	public ulong timer_elapsed(GLib.Timer timer, bool stop = true){
		ulong microseconds;
		double seconds;
		seconds = timer.elapsed (out microseconds);
		if (stop){
			timer.stop();
		}
		return (ulong)((seconds * 1000 ) + (microseconds / 1000));
	}

	public void sleep(int milliseconds){
		Thread.usleep ((ulong) milliseconds * 1000);
	}

	public string timer_elapsed_string(GLib.Timer timer, bool stop = true){
		ulong microseconds;
		double seconds;
		seconds = timer.elapsed (out microseconds);
		if (stop){
			timer.stop();
		}
		return "%.0f ms".printf((seconds * 1000 ) + microseconds/1000);
	}

	public void timer_elapsed_print(GLib.Timer timer, bool stop = true){
		ulong microseconds;
		double seconds;
		seconds = timer.elapsed (out microseconds);
		if (stop){
			timer.stop();
		}
		log_msg("%s %lu\n".printf(seconds.to_string(), microseconds));
	}	


	public void set_numeric_locale(string type){
		Intl.setlocale(GLib.LocaleCategory.NUMERIC, type);
	    Intl.setlocale(GLib.LocaleCategory.COLLATE, type);
	    Intl.setlocale(GLib.LocaleCategory.TIME, type);
	}
}
