


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
