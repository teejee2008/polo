/*
 * FileItemCloud.vala
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

public class FileItemCloud : FileItem {

	public string remote_name = "";
	
	public static string cache_dir;
	public DateTime? cached_date = null;
	public string error_msg = "";

	// contructors -------------------------------

	public FileItemCloud.from_path(string _file_path){
		// _file_path can be a local path, or GIO uri
		resolve_file_path(_file_path);
		//query_file_info();
		object_count++;
	}

	public FileItemCloud.from_path_and_type(string _file_path, FileType _file_type) {
		resolve_file_path(_file_path);
		file_type = _file_type;
		//if (query_info){
		//	query_file_info();
		//}
		object_count++;
	}
	
	private void resolve_file_path(string _file_path){

		GLib.File file;
		
		if (_file_path.contains("://")){
			file_uri = _file_path;
			file = File.new_for_uri(file_uri);
			file_path = file.get_path();
		}
		else {
			file_path = _file_path;
			file = File.new_for_path(file_path);
			file_uri = file.get_uri();
		}

		if (file_path == null){ file_path = ""; }

		file_uri_scheme = file.get_uri_scheme(); // will be 'file'

		remote_name = _file_path.split(":/")[0];
		
		//log_debug("");
		//log_debug("file_path      : %s".printf(file_path));
		//log_debug("file.get_path(): %s".printf(file.get_path()));
		//log_debug("file_uri       : %s".printf(file_uri));
		//log_debug("file_uri_scheme: %s".printf(file_uri_scheme));
		//log_debug("remote_name: %s".printf(remote_name));
	}

	// static helpers ---------------------------------

	public static bool is_remote_path(string _file_path){
		if (!GvfsMounts.is_gvfs_uri(_file_path) && !_file_path.contains("://") && !_file_path.has_prefix("/")){
			return true;
		}
		return false;
	}
	
	// properties ------------------------------------------------
	
	public string cached_file_path {
		owned get {
			return path_combine(App.rclone.rclone_cache, thumb_key);
		}
	}
	
	// actions ---------------------------------------------------

	public override void query_file_info() {
		// ignore
		return;
	}
	
	public override void query_children(int depth = -1) {

		/* Queries the file item's children using the file_path
		 * depth = -1, recursively find and add all children from disk
		 * depth =  1, find and add direct children
		 * depth =  0, meaningless, should not be used
		 * depth =  X, find and add children upto X levels
		 * */

		if (query_children_aborted) { return; }

		if (query_children_running) { return; }

		// check if directory and continue -------------------
		
		if (!is_directory) {
			//query_file_info();
			query_children_running = false;
			query_children_pending = false;
			return;
		}

		if (depth == 0){ return; } // incorrect method call

		log_debug("FileItemCloud: query_children(%d): %s".printf(depth, file_path), true);

		query_children_running = true;
		
		//mutex_children.lock();

		if (depth < 0){
			dir_size_queried = false;
		}

		// query immediate children ---------------
		
		save_to_cache(depth);
			
		read_children_from_cache(depth);

		// recurse children -----------------------

		foreach(var child in children.values){
			child.query_children(depth - 1);
		}

		if (depth < 0){
			get_dir_size_recursively(true);
		}

		query_children_running = false;
		query_children_pending = false;

		//mutex_children.unlock();
	}

	private void save_to_cache(int depth = -1){
		
		if (file_exists(cached_file_path)){
			var file_date = file_get_modified_date(cached_file_path);
			var now = new GLib.DateTime.now_local();
			if (file_date.add_minutes(60).compare(now) > 0){
				log_debug("FileItemCloud: save_to_cache(): skipped");
				return;
			}
		}

		log_debug("FileItemCloud: save_to_cache()");
		
		error_msg = "";
		
		string cmd, std_out, std_err;
			
		cmd = "rclone lsjson --max-depth %d '%s'".printf(depth, escape_single_quote(file_path));
		
		log_debug(cmd);
		
		exec_sync(cmd, out std_out, out std_err);
		
		if (std_err.length > 0){
			error_msg = std_err;
			log_error("std_err:\n%s\n".printf(std_err));
		}

		file_write(cached_file_path, std_out);
		
		log_debug("save_cache: %s".printf(cached_file_path));
	}
	
	private void read_children_from_cache(int depth = -1){

		if (!file_exists(cached_file_path)){ return; }
		
		var file_date = file_get_modified_date(cached_file_path);
		if (dates_are_equal(cached_date, file_date)){
			log_debug("FileItemCloud: read_children_from_cache(): skipped");
			return;
		}

		log_debug("FileItemCloud: read_children_from_cache()");

		// mark existing children as stale -------------------
		
		foreach(var child in children.values){
			child.is_stale = true;
		}

		// reset counts --------------

		item_count = 0;
		file_count = 0;
		dir_count = 0;
		
		// load children from cached file ------------------------
		
		var f = File.new_for_path(cached_file_path);
		if (!f.query_exists()) {
			return;
		}

		var parser = new Json.Parser();
		try {
			parser.load_from_file(cached_file_path);
		}
		catch (Error e) {
			log_error (e.message);
		}

		var node = parser.get_root();
		var arr = node.get_array();

		foreach(var node_child in arr.get_elements()){
			
			var obj_child = node_child.get_object();
			string path = json_get_string(obj_child, "Path", "");
			string name = json_get_string(obj_child, "Name", "");
			int64 size = json_get_int64(obj_child, "Size", 0);
			string modtime = json_get_string(obj_child, "ModTime", "");
			bool isdir = json_get_bool(obj_child, "IsDir", true);

			string child_name = name;
			string child_path = path_combine(file_path, child_name);
			var child_type = isdir ? FileType.DIRECTORY : FileType.REGULAR;
			var child_modified = parse_date_time(modtime, true);
			
			var child = (FileItemCloud) this.add_child(child_path, child_type, size, 0, false);
			child.set_properties();
			modified = child_modified;
			accessed = child_modified;
			changed = child_modified;

			if (isdir){
				add_to_cache(child);
			}
		}

		// remove stale children ----------------------------
		
		var list = new Gee.ArrayList<string>();
		foreach(var key in children.keys){
			if (children[key].is_stale){
				list.add(key);
			}
		}
		foreach(var key in list){
			//log_debug("unset: key: %s, name: %s".printf(key, children[key].file_name));
			children.unset(key);
		}

		// update counts --------------------------

		foreach(var child in children.values){
			if (child.is_directory){
				dir_count++;
			}
			else{
				file_count++;
			}
			item_count++;
		}
		children_queried = true;

		// update timestamp ----------------

		cached_date = file_date;
	}

	public override void query_children_async() {

		log_debug("FileItemCloud: query_children_async(): %s".printf(file_path));

		query_children_async_is_running = true;
		query_children_aborted = false;

		try {
			//start thread
			Thread.create<void> (query_children_async_thread, true);
		}
		catch (Error e) {
			log_error ("FileItemCloud: query_children_async(): error");
			log_error (e.message);
		}
	}

	private void query_children_async_thread() {
		log_debug("FileItemCloud: query_children_async_thread()");
		query_children(-1); // always add to cache
		query_children_async_is_running = false;
		//query_children_aborted = false; // reset
	}
	
	public override FileItem add_child(string item_file_path, FileType item_file_type, int64 item_size, 
		int64 item_size_compressed, bool item_query_file_info){

		// create new item ------------------------------

		//log_debug("add_child: %s ---------------".printf(item_file_path));

		FileItemCloud item = null;

		//item.tag = this.tag;

		// check existing ----------------------------

		bool existing_file = false;

		string item_name = file_basename(item_file_path);
		
		if (children.has_key(item_name) && (children[item_name].file_name == item_name)){

			existing_file = true;
			item = (FileItemCloud) children[item_name];

			//log_debug("existing child, queried: %s".printf(item.fileinfo_queried.to_string()));
		}
		/*else if (cache.has_key(item_file_path) && (cache[item_file_path].file_path == item_file_path)){
			
			item = (FileItemCloud) cache[item_file_path];

			// set relationships
			item.parent = this;
			this.children[item.file_name] = item;
		}*/
		else{

			if (item == null){
				item = new FileItemCloud.from_path_and_type(item_file_path, item_file_type);
			}
			
			// set relationships
			item.parent = this;
			this.children[item.file_name] = item;
		}

		item.is_stale = false; // mark fresh

		if (item_file_type == FileType.REGULAR) {

			//log_debug("add_child: regular file");

			item.file_size = item_size;

			// update hidden count -------------------------

			if (!existing_file){
				if (item.is_backup_or_hidden){
					this.hidden_count++;
				}
			}
		}
		else if (item_file_type == FileType.DIRECTORY) {

			//log_debug("add_child: directory");
		}

		return item;
	}

	public void remove_cached_file(){
		file_delete(cached_file_path);
	}
	
	protected void set_properties(){

		set_content_type_from_extension();
		
		can_read = true;
		can_write = true;
		can_execute = false;
		
		can_trash = false;
		can_delete = true;
		can_rename = true;

		owner_user = App.user_name;
		owner_group = App.user_name;
	}
	
}
