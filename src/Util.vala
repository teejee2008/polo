

	extern void exit(int exit_code);
	
	// process ------------------------------------------
	
	public string get_cmd_path (string cmd_tool){

		try {
			int exitCode;
			string stdout, stderr;
			Process.spawn_command_line_sync("which " + cmd_tool, out stdout, out stderr, out exitCode);
			stdout = stdout.strip().replace("\n","");
			return stdout;
		}
		catch (Error e){
			stderr.printf(e.message + "\n");
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

	public bool file_exists(string item_path){
		
		var item = File.parse_name(item_path);
		return item.query_exists();
	}

	public string escape_single_quote(string file_path){
		
		return file_path.replace("'","'\\''");
	}

	public void check_admin_access(){
		
		if (!user_is_admin()){
			
			log_error("Admin access is needed!");
			log_error("Run as root, or using 'sudo' or 'pkexec'");
			exit(1);
		}
	}

	public bool user_is_admin (){

		/* Check if current application is running with admin priviledges */

		try{
			// create a process
			string[] argv = { "sleep", "10" };
			Pid procId;
			Process.spawn_async(null, argv, null, SpawnFlags.SEARCH_PATH, null, out procId);

			// try changing the priority
			Posix.setpriority (Posix.PRIO_PROCESS, procId, -5);

			// check if priority was changed successfully
			if (Posix.getpriority (Posix.PRIO_PROCESS, procId) == -5)
				return true;
			else
				return false;
		}
		catch (Error e) {
			log_error (e.message);
			return false;
		}
	}

	public string get_temp_file_path(bool with_temp_folder = true){

		/* Generates temporary file path */

		string txt = "/tmp/%s".printf(timestamp_numeric() + (new Rand()).next_int().to_string());

		if (with_temp_folder){
			dir_create(txt);
			txt += "/%s".printf(timestamp_numeric() + (new Rand()).next_int().to_string());
		}

		return txt;
	}

	public void thread_sleep(int milliseconds){
		Thread.usleep ((ulong) milliseconds * 1000);
	}
	
	// file ---------------------------------------

	public string file_parent(string file_path){

		string text = "";
		var arr = file_path.split("/");
		int index = 0;
		
		while (index < arr.length - 1){
			
			if (index == 0){
				// append first part without / prefix
				// appends empty string in case of /path/file and non-empty string in case of path/file
				text += "%s".printf(arr[index++]);
				continue;
			}

			text += "/%s".printf(arr[index++]);
		}
		
		if (text.length == 0){
			// parent for /path
			text = "/";
		}
		
		return text;
		
		//return File.new_for_path(file_path).get_parent().get_path();
	}

	public string file_basename(string file_path){
		
		var arr = file_path.split("/");
		
		if (arr.length == 1){
			return file_path;
		}
		else{
			return arr[arr.length - 1];
		}
		
		//return File.new_for_path(file_path).get_basename();
	}

	public string file_get_title(string file_path){
		
		string file_name = file_basename(file_path);

		int end = file_name.length - file_get_extension(file_path).length;
		return file_name[0:end];
	}

	public string file_get_extension(string file_path){
		
		string file_name = file_basename(file_path);

		string[] parts = file_name.split(".");

		if (parts.length == 1){
			// no extension
			return "";
		}
		
		if (parts.length > 2){
			
			string ext1 = parts[parts.length-2];
			string ext2 = parts[parts.length-1];
			
			if ((ext1.length <= 4) && (ext2.length <= 4) && (ext1 == "tar")){
				// 2-part extension
				return ".%s.%s".printf(parts[parts.length-2], parts[parts.length-1]);
			}
		}
		
		if (parts.length > 1){
			return ".%s".printf(parts[parts.length - 1]);
		}

		return "";
	}


	public string path_combine(string part1, string part2){
		return GLib.Path.build_path("/", part1, part2);
	}

	public string? file_read (string file_path){

		/* Reads text from file */

		string txt;
		size_t size;

		try{
			GLib.FileUtils.get_contents (file_path, out txt, out size);
			return txt;
		}
		catch (Error e){
			stderr.printf(e.message);
		}

		return null;
	}

	public bool file_write (string file_path, string contents, out string error_msg = null, bool overwrite_in_place = false){

		/* Write text to file */

		try{

			dir_create(file_parent(file_path));
			
			var file = File.new_for_path (file_path);

			if (file.query_exists() && overwrite_in_place){

				var iostream = file.open_readwrite();
				//int64 fsize = iostream.query_info("%s".printf(FileAttribute.STANDARD_SIZE)).get_size();
				//iostream.seek (0, GLib.SeekType.END);
				iostream.truncate_fn(0);
				//iostream.seek (0, GLib.SeekType.SET);
				var ostream = iostream.output_stream;
				var data_stream = new DataOutputStream(ostream);
				data_stream.put_string(contents);
				data_stream.close();
			}
			else{

				if (file.query_exists()) {
					file.delete();
				}

				var file_stream = file.create(FileCreateFlags.REPLACE_DESTINATION);
				var data_stream = new DataOutputStream (file_stream);
				data_stream.put_string (contents);
				data_stream.close();
			}
			
			return true;
		}
		catch (Error e) {
			stderr.printf(e.message);
			error_msg = e.message;
			return false;
		}
	}

	public bool dir_create(string dir_path, bool show_message = false){

		try{
			var dir = File.parse_name (dir_path);
			if (dir.query_exists () == false) {
				dir.make_directory_with_parents (null);
			}
			return true;
		}
		catch (Error e) {
			stderr.printf(e.message);
			return false;
		}
	}

	// logging -----------------------------------------

	public bool LOG_ENABLE = true;
	public bool LOG_TIMESTAMP = false;
	public bool LOG_COLORS = true;
	public bool LOG_DEBUG = false;
	public bool LOG_TRACE = false;
	public bool LOG_COMMANDS = false;
	
	public void log_msg (string message, bool highlight = false, bool is_warning = false){

		if (!LOG_ENABLE) { return; }

		string msg = "";

		if (LOG_COLORS){
			if (highlight){
				msg += "\033[1;38;5;34m";
			}
			else if (is_warning){
				msg += "\033[1;38;5;93m";
			}
		}

		if (LOG_TIMESTAMP){
			msg += "[" + timestamp(true) +  "] ";
		}

		if (is_warning){
			msg += "W: ";
		}
			
		msg += message;

		if (LOG_COLORS){
			msg += "\033[0m";
		}

		msg += "\n";

		stdout.printf (msg);
		stdout.flush();
	}

	public void log_error(string message){
			
		if (!LOG_ENABLE) { return; }

		string msg = "";

		if (LOG_COLORS){
			msg += "\033[1;38;5;160m";
		}

		if (LOG_TIMESTAMP){
			msg += "[" + timestamp(true) +  "] ";
		}

		msg += "E: ";

		msg += message;

		if (LOG_COLORS){
			msg += "\033[0m";
		}

		msg += "\n";

		stderr.printf(msg);
		stderr.flush();
	}

	// misc -----------------

	// timestamp ----------------
	
	public string timestamp (bool show_millis = false){

		/* Returns a formatted timestamp string */

		// NOTE: format() does not support milliseconds

		DateTime now = new GLib.DateTime.now_local();
		
		if (show_millis){
			var msec = now.get_microsecond () / 1000;
			return "%s.%03d".printf(now.format("%H:%M:%S"), msec);
		}
		else{
			return now.format ("%H:%M:%S");
		}
	}

	public string timestamp_numeric (){

		/* Returns a numeric timestamp string */

		return "%ld".printf((long) time_t ());
	}

	public string timestamp_for_path (){

		/* Returns a formatted timestamp string */

		Time t = Time.local (time_t ());
		return t.format ("%Y-%d-%m_%H-%M-%S");
	}

	// string formatting -------------------------------------------------

	public string format_date(DateTime date){
		return date.format ("%Y-%m-%d %H:%M");
	}
	
	public string format_date_12_hour(DateTime date){
		return date.format ("%Y-%m-%d %I:%M %p");
	}
	
	public string format_duration (long millis){

		/* Converts time in milliseconds to format '00:00:00.0' */

	    double time = millis / 1000.0; // time in seconds

	    double hr = Math.floor(time / (60.0 * 60));
	    time = time - (hr * 60 * 60);
	    double min = Math.floor(time / 60.0);
	    time = time - (min * 60);
	    double sec = Math.floor(time);

        return "%02.0lf:%02.0lf:%02.0lf".printf (hr, min, sec);
	}

	public string format_duration_simple (long millis){

		/* Converts time in milliseconds to format '00:00:00.0' */

	    double time = millis / 1000.0; // time in seconds

	    double hr = Math.floor(time / (60.0 * 60));
	    time = time - (hr * 60 * 60);
	    double min = Math.floor(time / 60.0);
	    time = time - (min * 60);
	    double sec = Math.floor(time);

	    if (hr > 0){
			return "%2.0lfh %2.0lfm %2.0lfs".printf(hr, min, sec);
		}
		else if (min > 0){
			return "%2.0lfm %2.0lfs".printf(min, sec);
		}
		else {
			return "%2.0lfs".printf(sec);
		}
	}

	public string format_time_left(int64 millis){
		double mins = (millis * 1.0) / 60000;
		double secs = ((millis * 1.0) % 60000) / 1000;
		string txt = "";
		if (mins >= 1){
			txt += "%.0fm ".printf(mins);
		}
		txt += "%.0fs".printf(secs);
		return txt;
	}
	
	public double parse_time (string time){

		/* Converts time in format '00:00:00.0' to milliseconds */

		string[] arr = time.split (":");
		double millis = 0;
		if (arr.length >= 3){
			millis += double.parse(arr[0]) * 60 * 60;
			millis += double.parse(arr[1]) * 60;
			millis += double.parse(arr[2]);
		}
		return millis;
	}
	
	public DateTime date_now(){
		return new GLib.DateTime.now_local();
	}
	
	public bool dates_are_equal(DateTime? dt1, DateTime? dt2){
		if ((dt1 == null) || (dt2 == null)){
			return false;
		}
		return Math.fabs(dt2.difference(dt1)) < (1 * TimeSpan.SECOND);
	}
	
	// device is mounted

	public bool device_is_mounted(string device){

		string mtab_path = "/proc/mounts";
		
		File f = File.new_for_path(mtab_path);
		
		if (!f.query_exists()){
			
			mtab_path = "/proc/self/mounts";
			
			f = File.new_for_path(mtab_path);
			
			if (!f.query_exists()){
				
				mtab_path = "/etc/mtab";
				
				f = File.new_for_path(mtab_path);
				
				if (!f.query_exists()){
					
					return false;
				}
			}
		}

		var lines = file_read(mtab_path).split("\n");

		foreach (var line in lines){

			if (line.strip().length == 0) { continue; }

			int k = 1;
			
			foreach(string val in line.strip().split(" ")){

				if (val.strip().length == 0){ continue; }

				switch(k++){
				case 1:
					if (val.strip() == device){
						return true;
					}
					break;
				}
			}
		}

		return false;
	}
