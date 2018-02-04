/*
 * ArchiveTask.vala
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

public class ArchiveTask : AsyncTask {

	// compression
	public string format = "7z";
	public string method = "lzma";
	public string level = "5";
	public string dict_size = "16m";
	public string word_size = "32";
	public string block_size = "2g";
	public string passes = "0";

	// encryption
	public bool encrypt_header = false;
	public string encrypt_method = "AES256";
	
	// splitting
	public string split_mb = "0";

	// password for creation new archive
	public string password = "";
	public string keyfile = "";
	
	// archive
	public FileItemArchive archive;
	public Gee.ArrayList<FileItemArchive> archives = new Gee.ArrayList<FileItemArchive>();
	public Gee.ArrayList<FileItem> items = new Gee.ArrayList<FileItem>();
	
	public ArchiveAction action = ArchiveAction.CREATE;
	public string parser_name;
	public string archive_path; // may not always be same as 'archive' FileItem
	public string archiver_name;
	public string extraction_path = "";
	public string virtual_archive_path = "";
	//public string file_path_prefix_backup = "";
	public bool extract_to_new_folder = false;
	
	// stats vars
	private int archiver_pid;
	public string proc_io_name;
	public int64 archive_file_size;
	public int64 proc_read_bytes;
	public int64 proc_write_bytes;
	//public int64 processed_bytes;
	public int64 compressed_bytes;
	public long processed_file_count;
	public double compression_ratio;

	private MatchInfo match;
	private double dblVal;

	private static string 7zip_version_name;

	private Gtk.Window? window = null;

	public ArchiveTask(Gtk.Window? _window) {

		if (_window != null){
			window = _window;
		}
		else{
			window = App.main_window;
		}
		
		init_regular_expressions();
	}

	private void init_regular_expressions(){
		if (regex_list != null){
			return; // already initialized
		}
		
		regex_list = new Gee.HashMap<string, Regex>();
		
		try {
			//Extracting  packages/option.d.ts
			//Compressing  packages/option.d.ts
			//Compressing  packages/option.d.ts 100%
			regex_list["7z"] = new Regex("""[^ \t]{3,}[ ]{2}(.*)""");
			
			// 20% 12653 - atom/packages/atom-beautify/node_modules/.bin/uuid
			regex_list["7z1509"] = new Regex("""^[ \t]*([0-9]+)%[ \t]*[0-9]*[ \t]*-[ \t]*(.*)""");

			//- atom/packages/atom-beautify/node_modules/.bin/uuid
			//+ atom/packages/atom-beautify/node_modules/.bin/uuid
			regex_list["7z1509prg"] = new Regex("""^[\-+][ \t]+(.*)""");

			//Example: atom/keymap.cson
			regex_list["tar"] = new Regex("""^(.*)$""");
			
			//Example: 10
			regex_list["pv"] = new Regex("""([0-9]+)""");
		
			//Example: drwxrwxr-x teejee/teejee     0 2015-10-19 10:05 atom/node-uuid/uuid.js
			regex_list["tar_list"] = new Regex("""^([^ \t]{1})([^ \t]*)[ \t]+([^ \t\/]+)\/([^ \t\/]+)[ \t]+([0-9]+)[ \t]+([0-9-]+)[ \t]+([0-9:]+)[ \t]+(.+)$""");

			//Example: 2015-10-19 10:05:22 D....            0            0  atom/.apm/agent-base
			//Example: 2015-10-19 10:05:22 ....A            0               atom/somefile
			regex_list["7z_list"] = new Regex("""^([0-9- ]+)[ \t]+([0-9: ]+)[ \t]+([A-Za-z\.]+)[ \t]+([0-9]*)[ \t]+([0-9]*)[ \t]+(.+)$""");

			/* Sample:
			method      compressed  uncompr. ratio uncompressed_name
			LZO1X-1      13638179  25001168  54.6% /home/teejee/aam/samples/ffmpeg
			*/
			regex_list["lzop_list"] = new Regex("""^([a-zA-Z\-0-9]+)[ \t]*([0-9]+)[ \t]+([0-9]+)[ \t]+([0-9\.]+)%[ \t]+(.*)$""");
		}
		catch (Error e) {
			log_error (e.message);
		}
	}

	public static double 7zip_version {
		get {
			if ((7zip_version_name == null) || (7zip_version_name.length == 0)){
				
				string std_out, std_err;
				exec_sync("7z", out std_out, out std_err);
				
				foreach(string line in std_out.split("\n")){
					
					if ((line == null) || (line.strip().length == 0)){ continue; }

					// 7-Zip [64] 9.20  Copyright (c) 1999-2010 Igor Pavlov  2010-11-18
					string expression = """^[^ \t]+[ ]+[^ \t]+[ ]+([0-9.]*)[ ]+""";
					
					MatchInfo match = regex_match(expression, line);
					if (match != null){
						7zip_version_name = match.fetch(1);
					}
					break;
				}
			}
			
			if (7zip_version_name.length > 0){
				return double.parse(7zip_version_name);
			}
			else{
				return -1;
			}
		}
	}

	// build command string --------------

	public void prepare() {

		init_temp_directories();
		
		string script_text = build_script();

		// use archive's temp dir
		//working_dir = working_dir;
		//script_file = archive.script_file;
		//log_file = archive.log_file;
		
		save_bash_script_temp(script_text, script_file);
	}

	private string build_script() {
		var script = new StringBuilder();

		switch (action) {
		case ArchiveAction.CREATE:
			script.append("if [ -f '%s' ]; then\n".printf(escape_single_quote(archive_path)));
			script.append("  rm '%s'\n".printf(escape_single_quote(archive_path)));
			script.append("fi\n");
			
			if (file_exists(archive_path + ".tmp")) {
				script.append("rm '%s.tmp'\n".printf(escape_single_quote(archive_path)));
			}
			script.append(get_commands_compress());
			break;

		case ArchiveAction.LIST:
			script.append(get_commands_list());
			break;

		case ArchiveAction.INFO:
			script.append(get_commands_list_archive_info());
			break;
			
		case ArchiveAction.EXTRACT:
		case ArchiveAction.TEST:
			script.append(get_commands_extract());
			break;
		}

		return script.str;
	}

	public string get_commands_compress() {

		log_debug("ArchiveTask: get_commands_compress()");
		
		string cmd = "";

		if (format == "tar") {
			return get_commands_compress_tar();
		}

		//tar options
		if (format.has_prefix("tar_")) {
			cmd += "tar cf -";
			foreach (string key in archive.children.keys) {
				var item = archive.children[key];
				cmd += " -C '%s'".printf(escape_single_quote(file_parent(item.file_path)));
				cmd += " '%s'".printf(escape_single_quote(file_basename(item.file_path)));
			}
			cmd += " | ";
			cmd += "pv --size %lld -n".printf(archive.file_size);
			cmd += " | ";

			parser_name = "pv";
		}

		//main archiver options
		switch (format) {
		case "7z":
		case "tar_7z":
		case "bz2":
		case "tar_bz2":
		case "gz":
		case "tar_gz":
		case "xz":
		case "tar_xz":
		case "zip":
		case "tar_zip":
			// use 7zip program
			cmd += get_commands_compress_7zip();
			parser_name = "7z";
			archiver_name = "7z";
			break;
		case "lzo":
		case "tar_lzo":
			// use lzop program
			cmd += get_commands_compress_lzop();
			parser_name = "lzop";
			archiver_name = "lzop";
			break;
		case "zpaq":
		case "tar_zpaq":
			// use zpaq program
			//cmd += get_commands_compress_zpaq();
			parser_name = "zpaq";
			archiver_name = "zpaq";
			break;
		case "tar":
			// already handled
			break;
		}
		
		return cmd;
	}

	public string get_commands_compress_tar(){
		string cmd = "";

		cmd += "tar cvf";

		if (split_mb != "0"){
			cmd += " -";
		}
		else{
			cmd += " '%s'".printf(escape_single_quote(archive_path));
		}
		
		foreach (string key in archive.children.keys) {
			var item = archive.children[key];
			cmd += " -C '%s'".printf(escape_single_quote(file_parent(item.file_path)));
			cmd += " '%s'".printf(escape_single_quote(file_basename(item.file_path)));
		}
		
		if (split_mb != "0"){
			cmd += " | split -d --bytes=%sMB - '%s.'".printf(
				split_mb,
				escape_single_quote(archive_path));
		}

		parser_name = "tar";
		archiver_name = "tar";

		return cmd;
	}
	
	public string get_commands_compress_7zip(){
		string cmd = "";

		cmd += "7z a -bd";
		if (password.length > 0) {
			cmd += " '-p%s'".printf(password);
			if (encrypt_header) {
				cmd += " -mhe";
			}
		}
			
		//format and method
		switch (format) {
		case "7z":
		case "tar_7z":
			cmd += " -t7z";
			cmd += " -m0=" + method; //format supports multiple methods
			break;
		case "bz2":
		case "tar_bz2":
			cmd += " -tBZip2";
			//default method: bzip2
			break;
		case "gz":
		case "tar_gz":
			cmd += " -tGZip";
			//default method: deflate
			break;
		case "xz":
		case "tar_xz":
			cmd += " -tXZ";
			//default method: lzma2
			break;
		case "zip":
		case "tar_zip":
			cmd += " -tZip";
			cmd += " -mm=" + method; //format supports multiple methods
			break;
		}

		//multi-threading
		switch (format) {
		case "7z":
		case "tar_7z":
		case "bz2":
		case "tar_bz2":
		case "xz":
		case "tar_xz":
			cmd += " -mmt=on";
			break;
		case "gz":
		case "tar_gz":
		case "zip":
		case "tar_zip":
			//not supported
			break;
		}

		switch (method) {
		case "lzma":
		case "lzma2":
			cmd += " -mx" + level;
			cmd += " -md=" + dict_size;
			cmd += " -mfb=" + word_size;
			break;

		case "ppmd":
			cmd += " -mmem=" + dict_size;
			cmd += " -mo=" + word_size;
			break;

		case "bzip2":
			cmd += " -mx" + level;
			cmd += " -md=" + dict_size;
			cmd += " -mpass=" + passes;
			break;

		case "deflate":
		case "deflate64":
			cmd += " -mx" + level;
			cmd += " -mfb=" + word_size;
			cmd += " -mpass=" + passes;
			break;

		case "copy":
			//no options
			break;
		}

		//solid blocks
		switch (format) {
		case "7z":
		case "tar_7z":
			switch (method) {
			case "lzma":
			case "lzma2":
			case "ppmd":
			case "bzip2":
				if (block_size == "non-solid") {
					cmd += " -ms=off";
				}
				else {
					cmd += " -ms=" + block_size;
				}
				break;
			case "copy":
			case "deflate":
			case "deflate64":
				//not supported
				break;
			}
			break;

		default:
			//not supported
			break;
		}

		// split into volumes
		if (split_mb != "0"){
			cmd += " -v%sm".printf(split_mb);
		}

		// verbose output
		if (ArchiveTask.7zip_version >= 15.05){
			cmd += " -bb1";
		}

		//output file
		if (archive_path.length > 0) {
			cmd += " '-w%s'".printf(escape_single_quote(file_parent(archive_path)));
			cmd += " '%s'".printf(escape_single_quote(archive_path));
		}

		//input files
		if (format.has_prefix("tar_")) {
			cmd += " -si";
		}
		else {
			foreach (string key in archive.children.keys) {
				var item = archive.children[key];
				cmd += " '%s'".printf(escape_single_quote(item.file_path));
			}
		}

		return cmd;
	}
	
	public string get_commands_compress_lzop(){
		string cmd = "";
		
		cmd += "lzop";

		cmd += " -%s".printf(level);
		
		// input files
		if (format.has_prefix("tar_")) {
			cmd += ""; // nothing required
		}
		else {
			foreach (string key in archive.children.keys) {
				var item = archive.children[key];
				cmd += " '%s'".printf(escape_single_quote(item.file_path));
			}
		}

		cmd += " '-o%s'".printf(escape_single_quote(archive_path));

		return cmd;
	}

	public string get_commands_compress_zpaq(string tar_file){
		string cmd = "";

		cmd += "\n";
		cmd += "zpaq c";

		//cmd += " c%s".printf(level);

		cmd += " '%s'".printf(escape_single_quote(archive_path));
		
		// input files
		if (format.has_prefix("tar_")) {
			cmd += ""; // nothing required
		}
		else {
			foreach (string key in archive.children.keys) {
				var item = archive.children[key];
				cmd += " '%s'".printf(escape_single_quote(item.file_path));
			}
		}

		return cmd;
	}

	public string get_commands_list_archive_info() {
		string cmd = "";

		cmd += "7z l -slt '%s' -y".printf(escape_single_quote(archive_path));
		
		if ((archive.password.length > 0)||(archive.keyfile.length > 0)){
			cmd += " '-p%s'\n".printf(archive.password);
		}
		else{
			cmd += " -p --\n"; //required for non-encrypted archives
		}
					
		parser_name = "7z_list";
		archiver_name = "7z";
				
		return cmd;
		
		//string cmd = get_commands_list();
		//change parser
		//parser_name = parser_name.replace("list","info");
		//return cmd;
	}
	
	public string get_commands_list() {
		string cmd = "";

		// check if multi-volume TAR (.tar.00, etc)
		
		string file_pattern;
		bool is_tar_volume = ArchiveTask.is_multi_volume_tar(archive_path, out file_pattern);	
		if (is_tar_volume){
			// escape spaces in path and do not enclose in quotes
			cmd += "cat %s | tar tvf -".printf(file_pattern.replace(" ","\\ "));
			parser_name = "tar_list";
			archiver_name = "tar";
			return cmd;
		}

		// check if TAR or compressed TAR archive
		
		foreach(string extension in array_concat(
			Main.extensions_tar_compressed,Main.extensions_tar)) {
				
			if (archive_path.has_suffix(extension)) {
				cmd += "tar tvf '%s'".printf(escape_single_quote(archive_path));
				parser_name = "tar_list";
				archiver_name = "tar";
				return cmd;
			}
		}

		// check if it is a compressed file format that 7zip cannot handle

		if (archive_path.has_suffix(".lzo")){
			cmd += "lzop -l '%s'".printf(escape_single_quote(archive_path));
			parser_name = "lzop_list";
			archiver_name = "lzop";
			return cmd;
		}
		
		// check if TAR archive packed with 7zip or Zip

		foreach(var extension in Main.extensions_tar_packed) {
			if (archive_path.has_suffix(extension)) {
				string file_title = file_basename(archive_path);

				if (archive_path.has_suffix(".deb")) {
					file_title = "data";
				}
				else {
					foreach(var ext in Main.extensions_tar_packed) {
						if (file_title.has_suffix(ext)){
							file_title = file_title.replace(ext, "");
						}	
					}
				}

				cmd += "7z x '%s' '-o%s' '-w%s' -y".printf(
					escape_single_quote(archive_path),
					escape_single_quote(working_dir),
					escape_single_quote(working_dir));

				if (ArchiveTask.7zip_version >= 15.05){
					cmd += " -bb1";
				}
		
				if ((archive.password.length > 0)||(archive.keyfile.length > 0)){
					cmd += " '-p%s'\n".printf(archive.password);
				}
				else{
					cmd += " -p --\n"; //required for non-encrypted archives
				}
				
				cmd += "tar tvf '%s/%s.tar'".printf(
					escape_single_quote(working_dir),
					escape_single_quote(file_title));

				parser_name = "tar_list";
				archiver_name = "tar";
				return cmd;
			}
		}

		// attempt to open all remaining extensions using 7zip
			
		cmd += "7z l '%s' -y".printf(escape_single_quote(archive_path));

		if (ArchiveTask.7zip_version >= 15.05){
			cmd += " -bb1";
		}

		if ((archive.password.length > 0)||(archive.keyfile.length > 0)){
			cmd += " '-p%s'\n".printf(archive.password);
		}
		else{
			cmd += " -p --\n"; //required for non-encrypted archives
		}
		
		parser_name = "7z_list";
		archiver_name = "7z";
		return cmd;
	}

	public string get_commands_extract() {
		string cmd = "";

		// check if multi-volume TAR (.tar.00, etc)
		
		string file_pattern;
		bool is_tar_volume = ArchiveTask.is_multi_volume_tar(archive_path, out file_pattern);	
		if (is_tar_volume){
			// escape spaces in path and do not enclose in quotes
			cmd += "cat %s | tar xvf - -C '%s' --overwrite --overwrite-dir".printf(
				file_pattern.replace(" ","\\ "),
				escape_single_quote(extraction_path));

			foreach(var item in archive.extract_list){
				cmd += " '%s'".printf(escape_single_quote(item));
			}
			archive.extract_list.clear();
				
			parser_name = "tar";
			archiver_name = "tar";
			return cmd;
		}

		// check if TAR or compressed TAR archive
		
		foreach(string extension in array_concat(Main.extensions_tar_compressed, Main.extensions_tar)) {
			if (archive_path.has_suffix(extension)) {
				cmd += "tar xvf '%s' -C '%s' --overwrite --overwrite-dir".printf(
					escape_single_quote(archive_path),
					escape_single_quote(extraction_path));

				foreach(var item in archive.extract_list){
					cmd += " '%s'".printf(escape_single_quote(item));
				}
				archive.extract_list.clear();
				
				parser_name = "tar";
				archiver_name = "tar";
				return cmd;
			}
		}

		// check if it is a compressed file format that 7zip cannot handle

		if (archive_path.has_suffix(".lzo")){
			cmd += "lzop -d '%s' '-p%s'".printf(
				escape_single_quote(archive_path),
				escape_single_quote(extraction_path));

			parser_name = "lzop";
			archiver_name = "lzop";
			return cmd;
		}

		// check if TAR archive packed with 7zip or Zip
		
		foreach(string extension in Main.extensions_tar_packed) {
			if (archive_path.has_suffix(extension)) {
				string file_title = file_basename(archive_path);

				if (archive_path.has_suffix(".deb")) {
					file_title = "data";
				}
				else {
					foreach(var ext in Main.extensions_tar_packed) {
						if (file_title.has_suffix(ext)){
							file_title = file_title.replace(ext, "");
						}	
					}
				}

				cmd += "7z x '%s' '-o%s' '-w%s' -y".printf(
					escape_single_quote(archive_path),
					escape_single_quote(working_dir),
					escape_single_quote(working_dir));

				if (ArchiveTask.7zip_version >= 15.05){
					cmd += " -bb1";
				}
				
				if ((archive.password.length > 0)||(archive.keyfile.length > 0)){
					cmd += " '-p%s'\n".printf(archive.password);
				}
				else{
					cmd += " -p --\n"; //required for non-encrypted archives
				}
				
				cmd += "tar xvf '%s/%s.tar' -C '%s'".printf(
					escape_single_quote(working_dir),
					escape_single_quote(file_title),
					escape_single_quote(extraction_path));

				foreach(var item in archive.extract_list){
					cmd += " '%s'".printf(escape_single_quote(item));
				}
				archive.extract_list.clear();
				
				parser_name = "tar";
				archiver_name = "tar";
				return cmd;
			}
		}

		// attempt to extract all remaining extensions using 7zip
			
		cmd += "7z x '%s' '-o%s' '-w%s' -y".printf(
			escape_single_quote(archive_path),
			escape_single_quote(extraction_path),
			escape_single_quote(extraction_path));

		foreach(var item in archive.extract_list){
			cmd += " '%s'".printf(escape_single_quote(item));
		}
		archive.extract_list.clear();
		
		if (ArchiveTask.7zip_version >= 15.05){
			cmd += " -bb1";
		}
		
		if ((archive.password.length > 0)||(archive.keyfile.length > 0)){
			cmd += " '-p%s'\n".printf(archive.password);
		}
		else{
			cmd += " -p --\n"; //required for non-encrypted archives
		}
		
		parser_name = "7z";
		archiver_name = "7z";
		return cmd;
	}

	public void print_archive_action(){
		switch(action){
		case ArchiveAction.CREATE:
			log_debug("action=%s".printf("CREATE"));
			break;
		case ArchiveAction.UPDATE:
			log_debug("action=%s".printf("UPDATE"));
			break;
		case ArchiveAction.LIST:
			log_debug("action=%s".printf("LIST"));
			break;
		case ArchiveAction.TEST:
			log_debug("action=%s".printf("TEST"));
			break;
		case ArchiveAction.EXTRACT:
			log_debug("action=%s".printf("EXTRACT"));
			break;
		case ArchiveAction.INFO:
			log_debug("action=%s".printf("INFO"));
			break;
		}
	}

	// actions ----------------------------------

	public void compress(FileItemArchive arch) {
		
		this.archive = arch;
		//this.items = _items;
		this.archive_path = archive.file_path;

		log_msg("\nAction: CREATE");
		log_msg("Archive: %s".printf(archive_path));
		action = ArchiveAction.CREATE;

		if (archive_path.length == 0){
			log_error("Main.compress(): archive_path not set");
			exit(1);
		}

		// set some values for estimating progress
		
		prg_bytes_total = archive.file_size;
		log_debug("data_size: %s".printf(format_file_size(prg_bytes_total)));
		
		prg_count_total = archive.file_count_total;
		log_debug("file_count: %lld".printf(prg_count_total));

		// begin
		
		execute(arch);
	}

	public void extract_archives(Gee.ArrayList<FileItemArchive> _archives, bool _extract_to_new_folder) {

		log_debug("ArchiveTask: extract_archives(): %d".printf(_archives.size));

		var list = new Gee.ArrayList<FileItemArchive>();
		foreach(var item in _archives){ list.add(item); }
		this.archives = list;

		this.action = ArchiveAction.EXTRACT;

		this.extract_to_new_folder = _extract_to_new_folder;

		extract_next_archive();
	}

	private bool extract_next_archive(){ 

		log_debug("ArchiveTask: extract_next_archive(): %d".printf(archives.size)); 

		if (archives.size > 0){ 
			var arch = archives[0]; 
			archives.remove(arch); 
			extract_archive(arch, extract_to_new_folder);
			return true;
		} 

		return false; 
	} 

	public void extract_archive(FileItemArchive arch, bool _extract_to_new_folder) {

		log_debug("ArchiveTask: extract_archive(): %s".printf(arch.file_path));
		
		this.archive = arch;

		// set some properties to be passed to children
		this.archive.archive_base_item = this.archive;

		archive_path = archive.archive_base_item.file_path;

		if (_extract_to_new_folder){
			archive.extraction_path = file_generate_unique_name(archive.extraction_path);
		}
		
		this.extraction_path = archive.extraction_path;
		
		log_msg("\nAction: EXTRACT");
		log_msg("Archive: %s".printf(archive_path));
		this.action = ArchiveAction.EXTRACT;

		if (archive_path.length == 0){
			log_error("Main.extract(): archive_path not set");
			exit(1);
		}

		if (extraction_path.length == 0){
			log_error("Main.extract(): extraction_path not set");
			exit(1);
		}
		else{
			dir_create(extraction_path);
			log_msg("Extraction Path: %s".printf(extraction_path));
		}

		// set some values for estimating progress
		prg_bytes_total = file_get_size(archive_path);
		log_debug("archive_size: %lld".printf(prg_bytes_total));

		// begin
		execute(arch);
	}

	public void test(FileItemArchive arch, bool wait = false) {

		this.archive = arch;

		// set some properties to be passed to children
		this.archive.archive_base_item = this.archive;

		archive_path = archive.archive_base_item.file_path;
		
		log_msg("\nAction: TEST");
		log_msg("Archive: %s".printf(archive_path));
		action = ArchiveAction.TEST;

		if (archive_path.length == 0){
			log_error("Main.extract(): archive_path not set");
			exit(1);
		}
			
		if (extraction_path.length == 0){
			log_error("Main.extract(): extraction_path not set");
			exit(1);
		}
		else{
			dir_create(extraction_path);
			log_msg("Test Extraction Path: %s".printf(extraction_path));
		}

		// set some values for estimating progress
		prg_bytes_total = file_get_size(archive_path);
		log_debug("archive_size: %lld".printf(prg_bytes_total));

		execute(arch, wait);
	}
	
	public void open(FileItemArchive arch, bool wait = false, bool info_only = false) {

		this.archive = arch;

		// set some properties to be passed to children
		this.archive.archive_base_item = this.archive;

		archive_path = archive.archive_base_item.file_path;

		if (info_only){
			log_msg("\nAction: INFO");
			action = ArchiveAction.INFO;
		}
		else{
			log_msg("\nAction: LIST");
			action = ArchiveAction.LIST;
		}

		log_msg("Opening: %s".printf(archive_path));

		if (archive_path.length > 0) {
			var file = File.parse_name(archive_path);
			if (file.query_exists()) {
				try {
					var finfo = file.query_info("%s,%s".printf(
						FileAttribute.STANDARD_SIZE, FileAttribute.TIME_MODIFIED), 0);

					archive.archive_size = finfo.get_size();
					archive.archive_modified = (new DateTime.from_timeval_utc(finfo.get_modification_time())).to_local();
				}
				catch (Error e) {
					log_error(e.message);
				}
			}
		}
		
		archive.clear_children();

		if (archive_path.length == 0){
			log_error("ArchiveTask.open(): archive_path not set");
			exit(1);
		}

		if (!file_exists(archive_path)){
			log_error("ArchiveTask.open(): file not found: %s".printf(archive_path));
			exit(1);
		}
		
		// set some values for estimating progress
		//archiver.prg_bytes_total = file_get_size(task.file_path);
		//log_debug("archive_size: %lld".printf(archiver.prg_bytes_total));

		execute(arch, wait);
	}

	public void open_info(FileItemArchive arch, bool wait = false) {
		this.archive = arch;
		open(arch, wait, true);
	}

	// execution ----------------------------

	public void execute(FileItemArchive arch, bool wait = false) {

		log_debug("ArchiveTask: execute()");
		
		this.archive = arch;
		
		prepare();

		//this.script_file = archive.script_file;
		//this.working_dir = working_dir;

		log_debug(string.nfill(70,'='));
		log_debug(script_file);
		log_debug(string.nfill(70,'='));
		log_debug(file_read(script_file));
		log_debug(string.nfill(70,'='));

		// set the virtual path (if specified) before process begins
		/*if (virtual_archive_path.length > 0){
			log_debug("setting virtual archive path: %s".printf(virtual_archive_path));
			log_debug("actual path: %s".printf(archive_path));
			archive_path = archive.display_name;
		}*/
		
		begin();

		if (status == AppStatus.RUNNING){
			int attempts = 0;
			archiver_pid = -1;
			while ((archiver_pid == -1) && (attempts < 10)) {
				sleep(100);
				//archiver_pid = get_pid_by_command(task.archiver_name);
				var children = get_process_children(child_pid);
				log_debug("children: %d".printf(children.length));
				if (children.length > 0){
					archiver_pid = children[0];
				}
				attempts++;
			}

			log_debug("archiver_name: %s".printf(archiver_name));
			log_debug("archiver_pid: %d".printf(archiver_pid));
			log_debug("parser_name: %s".printf(parser_name));
		}
		
		if (wait){
			while (status == AppStatus.RUNNING){ // don't wait if AppStatus.PASSWORD_REQUIRED
				sleep(200);
				gtk_do_events();
			}

			wait_for_threads_to_finish();
		}
	}

	public override void parse_stdout_line(string out_line){
		
		if (is_terminated) { return; }

		//log_msg("O: " + out_line);
		
		update_progress_parse_console_output(out_line);
	}
	
	public override void parse_stderr_line(string err_line){

		if (is_terminated) { return; }

		log_error(err_line);

		if (err_line.down().contains("wrong password?")){
			
			archive.archive_is_encrypted = true;
			is_terminated = true;
			
			if (archive.password.length == 0){
				log_error(_("Password not set for encrypted archive"));
			}
			else{
				log_error(_("Incorrect password for encrypted archive"));
			}

			//archive.password = ""; // don't reset, we will use the wrong password as a flag
			stop(AppStatus.PASSWORD_REQUIRED);
			return;
		}
	}

	public bool update_progress_parse_console_output (string line) {
		
		if ((line == null) || (line.length == 0)) {
			return true;
		}

		mutex_parser.lock();

		switch (parser_name) {
		case "pv":
			if (regex_list[parser_name].match(line, 0, out match)) {
				dblVal = double.parse(match.fetch(1));
				progress = (dblVal / 100.00);
			}
			break;

		case "7z":
			if (regex_list["7z"].match(line, 0, out match)) {
				//log_debug("7z: %s".printf(line));
				
				status_line = match.fetch(1);
				if (!status_line.has_suffix("/")){
					processed_file_count += 1;
				}
			}
			else if (regex_list["7z1509"].match(line, 0, out match)) {
				//log_debug("7z1509: %s".printf(line));
				
				status_line = match.fetch(2);
				progress = double.parse(match.fetch(1));
			}
			else if (regex_list["7z1509prg"].match(line, 0, out match)) {
				//log_debug("7z1509prg: %s".printf(line));
				
				status_line = match.fetch(1);
				//progress = double.parse(match.fetch(1));
			}
			else{
				log_debug("7z: unknown: %s".printf(line));
			}
			break;

		case "tar":
			if (regex_list[parser_name].match(line, 0, out match)) {
				status_line = match.fetch(1);
				if (!status_line.has_suffix("/")){
					processed_file_count += 1;
				}
			}
			break;
			
		case "tar_list":
			//Example: (d)(rwxrwxr-x) (teejee)/(teejee)     (0) (2015-10-19) (10:05) (atom/node-uuid/uuid.js)
			
			if (regex_list[parser_name].match(line, 0, out match)) {
				string type = match.fetch(1).strip();
				string permissions = match.fetch(2).strip();
				string owner = match.fetch(3).strip();
				string group = match.fetch(4).strip();
				string size = match.fetch(5).strip();
				string modified = "%s %s".printf(match.fetch(6).strip(), match.fetch(7).strip());
				string last_field = match.fetch(8).strip();
				string symlink_target = "";
				string file_path = "";

				if (last_field.contains("->")) {
					file_path = last_field.split("->")[0].strip();
					symlink_target = last_field.split("->")[1].strip();
				}
				else {
					file_path = last_field;
				}

				if (file_path.has_prefix("./")) {
					if (file_path.length > 2) {
						file_path = file_path[2:file_path.length].strip();
					}
					else {
						file_path = "";
					}
				}

				if (file_path.length > 0) {
					int64 item_size = int64.parse(size);

					var item = archive.add_descendant(file_path, FileType.REGULAR, item_size, 0);
					
					item.modified = datetime_from_string(modified);
					item.permissions = permissions;
					item.owner_user = owner;
					item.owner_group = group;
					item.symlink_target = symlink_target;
					item.is_symlink = (type == "l");
					//FileItem.add_to_cache(item);  // added by FileItemArchive.add_child()

					//log_debug("added: " + file_path);
				}
			}

			break;

		case "7z_list":

			//log_debug("7z_list: " + line);
			
			if (regex_list[parser_name].match(line, 0, out match)) {

				string modified = "%s %s".printf(match.fetch(1).strip(), match.fetch(2).strip());
				string attr = match.fetch(3).strip();
				string size = match.fetch(4).strip();
				string size_compressed = match.fetch(5).strip();
				string file_path = match.fetch(6).strip();

				//log_debug("file_path=%s".printf(file_path));

				var file_type = (attr.contains("D")) ? FileType.DIRECTORY : FileType.REGULAR;
				var item = (FileItemArchive) archive.add_descendant(file_path, file_type, int64.parse(size), int64.parse(size_compressed));
				item.modified = datetime_from_string(modified);
				//item.set_archive_base_item(archive);
				FileItem.add_to_cache(item);
			}
			else if (line.contains("=")){

				//log_debug("7z_list: " +line);

				if (line.has_prefix("Type = ")){
					string val = line.split("=",2)[1];
					val = (val == null) ? "" : val.strip();
					archive.archive_type = val;
				}
				else if (line.has_prefix("Method = ")){
					string val = line.split("=",2)[1];
					val = (val == null) ? "" : val.strip();
					archive.archive_method = val;
					
					if (archive.archive_method.contains("7zAES")){

						//this info is available only if archive header is not encrypted
						archive.archive_is_encrypted = true;
						
						switch (action){
						case ArchiveAction.EXTRACT:
						case ArchiveAction.TEST:
							//stop task if password is not specified
							if (archive.password.length == 0){
								log_error(_("Password not set for encrypted archive"));
								is_terminated = true;
								stop(AppStatus.PASSWORD_REQUIRED);
								return true;
							}
							break;
						case ArchiveAction.LIST:
							// do nothing
							break;
						}
					}
				}
				else if (line.has_prefix("Solid = ")){
					string val = line.split("=",2)[1];
					val = (val == null) ? "" : val.strip();
					archive.archive_is_solid = (val == "+") ? true : false;
				}
				else if (line.has_prefix("Blocks = ")){
					string val = line.split("=",2)[1];
					val = (val == null) ? "0" : val.strip();
					archive.archive_blocks = int.parse(val);
				}
				else if (line.has_prefix("Headers Size = ")){
					string val = line.split("=",2)[1];
					val = (val == null) ? "0" : val.strip();
					archive.archive_header_size = int64.parse(val);
				}
				else if (line.has_prefix("Size = ")){
					string val = line.split("=",2)[1];
					val = (val == null) ? "0" : val.strip();
					archive.archive_unpacked_size = int64.parse(val);
					
					if ((action == ArchiveAction.INFO) || (action == ArchiveAction.LIST)){
						log_msg("Archive Unpacked Size: %'ld bytes".printf(
							archive.archive_unpacked_size));
					}

					if (action == ArchiveAction.INFO){
						is_terminated = true;
						stop(AppStatus.FINISHED); //TODO: stop after last line in archive info
					}
				}
				else if (line.has_prefix("Packed Size = ")){
					string val = line.split("=",2)[1];
					val = (val == null) ? "0" : val.strip();
					archive.archive_size = int64.parse(val);
				}
			}
			break;
			
		case "lzop_list":
			if (regex_list[parser_name].match(line, 0, out match)) {
				//string method = match.fetch(1).strip();;
				string size_compressed = match.fetch(2).strip();
				string size = match.fetch(3).strip();
				//string percent = match.fetch(4).strip();
				string file_path = file_basename(match.fetch(5).strip());
				var file_type = FileType.REGULAR;

				var item = archive.add_descendant(file_path, file_type, int64.parse(size), int64.parse(size_compressed));
				//item.source_archive = archive;
				FileItem.add_to_cache(item);
			}
			break;
		case "zpaq":
			log_debug("zpaq: " + line);
			break;
		}

		mutex_parser.unlock();

		return true;
	}

	private void wait_for_threads_to_finish(){
		log_debug("ArchiveTask: wait_for_pending_threads");
		while (threads_are_pending()){
			sleep(200);
			gtk_do_events();
		}
		log_debug("ArchiveTask: wait_for_pending_threads: done");
	}
	
	protected override void finish_task(){

		log_debug("ArchiveTask: finish_task()");

		wait_for_threads_to_finish();
		
		/*if (status == AppStatus.PASSWORD_REQUIRED){

			log_debug("ArchiveTask: finish_task(): password_required");
			
			if (archive.prompt_for_password()){
				log_debug("ArchiveTask: finish_task(): password_entered: execute()");
				execute(archive);
				return;
			}
			else{
				// cancel - user did not provide password
				log_debug("ArchiveTask: finish_task(): password_cancelled: finish");
				status = AppStatus.CANCELLED;
			}
		}*/

		if (!is_terminated && (action == ArchiveAction.LIST)){
			archive.archive_size = file_get_size(archive_path);
			archive.compression_ratio = (archive.archive_size * 100.00) / archive.file_size;
		}

		/*if ((status != AppStatus.CANCELLED) && (status != AppStatus.PASSWORD_REQUIRED)) {
			if (archives.size > 0){
				log_debug("ArchiveTask: finish_task(): process_next_archive");
				if (process_next_archive()){
					return;
				}
			}
		}*/

		// finish  ---------------------------------
		
		if ((status != AppStatus.CANCELLED) && (status != AppStatus.PASSWORD_REQUIRED)) {
			log_debug("ArchiveTask: finish_task(): set AppStatus.FINISHED");
			status = AppStatus.FINISHED;
		}

		//if (action == ArchiveAction.LIST){
		//	archive_path_prefix = file_path_prefix_backup;
		//}

		log_debug("ArchiveTask: finish_task(): exit");
	}
	
	// query stats ---------------------------
	
	public bool query_io_stats () {
		if (archiver_pid > 0) {
			get_proc_io_stats(archiver_pid, out proc_read_bytes, out proc_write_bytes);

			//log_debug("%d Processed: %s, Written: %s".printf(archiver_pid, 
			//	format_file_size(proc_read_bytes),
			//	format_file_size(proc_write_bytes)));

			prg_bytes = proc_read_bytes;
		}

		//log_debug("prg_count_total: %.0f, Progress: %.0f".printf(progress));
		
		if (percent > 0){
			progress = percent;
			//log_debug("Percent: Progress: %.2f".printf(progress));
		}
		else if ((prg_count_total > 0) && (prg_count > 0)){
			progress = (prg_count * 1.0) / prg_count_total;
			//log_debug("Count: Progress: %.2f".printf(progress));
		}
		else if ((prg_bytes_total > 0) && (prg_bytes > 0)){
			progress = (prg_bytes * 1.0) / prg_bytes_total;
			//log_debug("Bytes: Progress: %.2f".printf(progress));
		}

		switch(action){
		case ArchiveAction.CREATE:
			// get archive size from disk
			compressed_bytes = file_get_size(archive_path);
			if (compressed_bytes == -1) {
				compressed_bytes = file_get_size(archive_path + ".tmp");
			}
			break;
			
		case ArchiveAction.EXTRACT:
		case ArchiveAction.TEST:
			// set archive size
			if (compressed_bytes == 0){
				compressed_bytes = file_get_size(archive_path);
				if (compressed_bytes == -1) {
					compressed_bytes = file_get_size(archive_path + ".tmp");
				}
			}
			break;
		}

		return true;
	}

	public string stat_status_line{
		owned get{
			var txt = "";

			/*switch(action){
			case ArchiveAction.CREATE:
				txt = _("Compressing");
				break;
			case ArchiveAction.EXTRACT:
				txt = _("Extracting");
				break;
			case ArchiveAction.TEST:
				txt = _("Verifying");
				break;
			}
			
			if ((status_line != null) && (status_line.length > 0)) {
				txt += ": %s".printf(status_line);
			}
			else {
				txt += "...";
			}*/

			txt = status_line;

			return txt;
		}
	}
	
	public string stat_speed{
		owned get{
			long elapsed = (long) timer_elapsed(timer);
			long speed = (long)(proc_read_bytes / (elapsed / 1000.0));
			return format_file_size(speed) + "/s";
		}
	}

	public string stat_compression_ratio{
		owned get{
			if ((action == ArchiveAction.CREATE) && (compressed_bytes > 0) && (proc_read_bytes > 0)){
				compression_ratio = (compressed_bytes * 100.00) / proc_read_bytes;
				return "%0.1f %%".printf(compression_ratio);
			}
			else if (archive.compression_ratio > 0){
				// return archive property
				compression_ratio = archive.compression_ratio;
				return "%0.1f %%".printf(compression_ratio);
			}
			else {
				compression_ratio = 0;
				return "???";
			}
		}
	}

	public string stat_file_count{
		owned get{
			if ((processed_file_count > 0) && (archive.file_count_total > 0)) {
				return "%'d / %'d".printf(processed_file_count, archive.file_count_total);
			}
			else if (processed_file_count > 0) {
				return "%'d".printf(processed_file_count);
			}
			else if (archive.file_count_total > 0) {
				return "%'d".printf(archive.file_count_total);
			}
			else {
				return "???";
			}
		}
	}

	public string stat_data_read{
		owned get{
			if (proc_read_bytes > 0){
				return format_file_size(proc_read_bytes);
			}
			else if ((progress > 0) && (archive.file_size > 0)){
				var bytes = (int64)(progress * (archive.file_size));
				return format_file_size(bytes);
			}
			else {
				return "???";
			}
		}
	}

	public string stat_data_written{
		owned get{
			if (proc_write_bytes > 0){
				return format_file_size(proc_write_bytes);
			}
			else if ((progress > 0) && (archive.file_size > 0)){
				var bytes = (int64)(progress * (archive.file_size));
				return format_file_size(bytes);
			}
			else {
				return "???";
			}
		}
	}

	public string stat_data_processed{
		owned get{
			return stat_data_read;
		}
	}

	public string stat_data_compressed{
		owned get{
			if (compressed_bytes > 0){
				return format_file_size(compressed_bytes);
			}
			else {
				return "???";
			}
		}
	}

	// serialize --------------------------
	
	public Json.Object to_json() {
		var task = new Json.Object();
		task.set_string_member("format", format);
		task.set_string_member("method", method);
		task.set_string_member("level", level);
		task.set_string_member("dict_size", dict_size);
		task.set_string_member("word_size", word_size);
		task.set_string_member("block_size", block_size);
		task.set_string_member("passes", passes);
		task.set_string_member("encrypt_header", encrypt_header.to_string());
		task.set_string_member("encrypt_method", encrypt_method);
		task.set_string_member("split_mb", split_mb.to_string());
		return task;
	}

	public void load_from_json(Json.Object task) {
		format = json_get_string(task, "format", "7z");
		method = json_get_string(task, "method", "lzma");
		level = json_get_string(task, "level", "5");
		dict_size = json_get_string(task, "dict_size", "16m");
		word_size = json_get_string(task, "word_size", "32");
		block_size = json_get_string(task, "block_size", "2g");
		passes = json_get_string(task, "passes", "0");
		encrypt_header = json_get_bool_from_string(task, "encrypt_header", false);
		encrypt_method = json_get_string(task, "encrypt_method", "AES256");
		split_mb = json_get_string(task, "split_mb", "0");
	}

	// helper methods ------------------------------
	
	public static bool is_multi_volume_tar(string archive_path, out string pattern){
		Regex rex = null;
		try {
			// Ex: /some/path/archive.tar.00
			rex = new Regex("""(.*\.tar\.)[0-9]+$""");
		}
		catch (Error e) {
			log_error (e.message);
		}
		
		MatchInfo match;
		if (rex.match(archive_path, 0, out match)) {
			pattern = match.fetch(1) + "*";
			return true;
		}
		else{
			pattern = "";
			return false;
		}
	}


}

public enum ArchiveAction {
	CREATE,
	UPDATE,
	LIST,
	TEST,
	EXTRACT,
	INFO
}

