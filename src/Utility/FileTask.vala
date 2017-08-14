/*
 * FileTask.vala
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


public class FileTask : GLib.Object {

	// copy operation
	private FileItem source;
	private FileItem destination;
	private string action;
	private FileItem[] items;
	
	private string log;
	private bool aborted;
	private Cancellable cancellable;
	private FileItem current_query_item;
	public Gee.HashMap<string, FileConflictItem> conflicts;
	private FileReplaceMode replace_mode;
	private bool first_pass;

	private Gtk.Window? window;

	// status
	public bool is_running = false;
	private int64 bytes_file = 0;
	private int64 bytes_file_total = 0;
	private int64 bytes_completed_files = 0;
	private int64 bytes_batch_total = 0;
	private int64 count_batch_completed = 0;
	private int64 count_batch_total = 0;
	public string status = "";
	private GLib.Timer timer = new GLib.Timer();
	private GLib.Timer rate_timer = new GLib.Timer();
	private Mutex mutex = Mutex();

	public signal void complete();

	private void init_task(){

		// file byte status --------------

		bytes_file = 0;
		bytes_file_total = 0;

		// batch byte status ---------

		bytes_completed_files = 0;
		//bytes_batch = 0; //derived
		if (first_pass){
			bytes_batch_total = 0;
		}

		// batch count status ----------------

		count_batch_completed = 0;
		if (first_pass){
			count_batch_total = 0;
		}

		// other --------------------

		cancellable = null;
		_stats = "";
		status = "";
		log = "";
		aborted = false;
	}

	public void copy_items_to_path(FileItem _source, string dest_path, FileItem[] _items,
		FileReplaceMode _replace_mode, Gee.HashMap<string, FileConflictItem>? _conflicts, Gtk.Window? _window){

		copy_or_move_items_to_path(_source, dest_path, _items, false, _replace_mode, _conflicts, _window);
	}

	public void move_items_to_path(FileItem _source, string dest_path, FileItem[] _items,
		FileReplaceMode _replace_mode, Gee.HashMap<string, FileConflictItem>? _conflicts, Gtk.Window? _window){

		copy_or_move_items_to_path(_source, dest_path, _items, true, _replace_mode, _conflicts, _window);
	}
		
	public void copy_or_move_items_to_path(FileItem _source, string dest_path, FileItem[] _items, bool move,
		FileReplaceMode _replace_mode, Gee.HashMap<string, FileConflictItem>? _conflicts, Gtk.Window? _window){

		is_running = true;
		
		// assign arguments -----------------
		
		action = move ? "move" : "copy";
		
		items = _items;

		replace_mode = _replace_mode;

		window = _window;

		source = _source;
		
		destination = new FileItem.from_path(dest_path);

		first_pass = (_conflicts == null);
		if (_conflicts == null){
			conflicts = new Gee.HashMap<string, FileConflictItem>();
		}
		else{
			conflicts = _conflicts;
		}

		log_debug("FileTask: copy_or_move_items_to_path(%s): %s".printf(dest_path, action));

		// init -----------------------
		
		init_task();

		status = _("Preparing...");
		timer = new GLib.Timer();
		timer.start();

		log_debug("dest_path=%s".printf(dest_path));
		log_debug("items=%d".printf(items.length));

		try {
			//start thread for copy operation
			Thread.create<void> (copy_items_thread, true);
		} catch (Error e) {
			log_error ("FileTask: copy_items_thread(): error");
			log_error (e.message);
		}
	}

	private void copy_items_thread(){

		if (first_pass){
			build_file_list_for_copy();
		}
		else{
			log_debug("replace_mode: %s".printf(replace_mode.to_string()));
			foreach(var con in conflicts.values){
				log_debug("%s: %s".printf(con.replace.to_string(), con.source_item.file_path));
			}
		}

		if (!aborted) {

			rate_timer = new GLib.Timer();
			rate_timer.start();

			destination.query_children(1);

			foreach(var item in items){
				if (aborted) { break; }

				string dest_item_name = item.file_name;
				if (source.file_path == destination.file_path){
					if (destination.children.has_key(item.file_name)){
						int index = 1;
						do{
							dest_item_name = "%s%s%s".printf(item.file_title, " (%d)".printf(index++), item.file_extension);
						}
						while(file_or_dir_exists(path_combine(destination.file_path, dest_item_name)));
					}
				}

				copy_item_to_dir(item, destination, (action == "move"), dest_item_name);
			}

			rate_timer.stop();
		}

		timer.stop();

		log_debug("FileTask: copy_items_thread(): thread exit");
		is_running = false;

		complete();
	}

	private void build_file_list_for_copy(){

		status = _("Building file list...");

		bytes_batch_total = 0;
		count_batch_total = 0;

		foreach(var item in items){

			if (aborted) { break; }

			if (item.file_type == FileType.DIRECTORY){
				
				current_query_item = item;
				item.query_children_async();

				while(item.query_children_async_is_running){

					_stats = "%'lld items (%s), %s elapsed".printf(
						count_batch_total + item.file_count_total + item.dir_count_total,
						format_file_size(bytes_batch_total + item.size),
						stats_time_elapsed
						);

					sleep(100);
					gtk_do_events();

					sleep(100);
					gtk_do_events();

					sleep(100);
					gtk_do_events();

					sleep(100);
					gtk_do_events();
				}
			}

			bytes_batch_total += item.size;
			count_batch_total += item.file_count_total + item.dir_count_total;
		}

		_stats = "";
		log_debug("FileTask: build_file_list(): batch_size=%lld".printf(bytes_batch_total));
	}

	private bool copy_item_to_dir(FileItem src_item, FileItem dest_dir, bool move, string dest_item_name){

		//log_debug("copy_item_to_dir: %s".printf(src_item.file_path));

		if (aborted) { return false; }

		if (dest_dir.file_type != FileType.DIRECTORY){
			log += "Copy destination is a file!\n";
			return false;
		}

		if (src_item.file_type == FileType.REGULAR){

			//copy file

			if (dest_dir.children.has_key(dest_item_name)){

				//log_debug("exists");

				var dest_item = dest_dir.children[dest_item_name];

				if (first_pass){
					// save conflict item
					log_debug("conflict: %s".printf(src_item.file_path));
					var conflict = new FileConflictItem(src_item, dest_item, source, destination);
					conflicts[src_item.file_path] = conflict;
				}
				else{

					bool replace = get_replace_action(src_item, dest_item);

					if (dest_item.file_type == FileType.REGULAR){
						if (replace){
							// replace
							log_debug("overwrite: %s".printf(dest_item.file_path));
							log += "Replaced: %s\n".printf(dest_item.file_path);
							return copy_file(src_item.file_path, dest_item.file_path, move);
						}
					}
					else{
						if (replace){
							// copy
							log_debug("copy: %s".printf(dest_item.file_path));
							return copy_file(src_item.file_path, dest_item.file_path, move);
						}
					}
				}
			}
			else{

				if (!first_pass){

					// copy
					var dest_item_path = path_combine(dest_dir.file_path, dest_item_name);
					log_debug("copy: %s".printf(dest_item_path));
					return copy_file(src_item.file_path, dest_item_path, move);
				}
			}

		}
		else { // src.file_type == FileType.DIRECTORY

			FileItem dest_item = null;
			var dest_item_path = path_combine(dest_dir.file_path, dest_item_name);

			if (dest_dir.children.has_key(dest_item_name)){

				dest_item = dest_dir.children[dest_item_name];

				if (dest_item.file_type == FileType.DIRECTORY){

					dest_item.query_children(1);

					if (!first_pass){

						// merge - no action needed
						log_debug("merging dirs: %s -> %s".printf(src_item.file_path, dest_item.file_path));
						log += "Merging directories: %s\n".printf(dest_item.file_path);
					}
				}
				else{

					if (first_pass){
						log_debug("conflict: %s".printf(src_item.file_path));
						var conflict = new FileConflictItem(src_item, dest_item, source, destination);
						conflicts[src_item.file_path] = conflict;
					}
					else {
						bool replace = get_replace_action(src_item, dest_item);

						if (replace){

							log_debug("dest dir is a file: %s -> %s".printf(src_item.file_path, dest_item.file_path));
							log += "File exists at destination: %s\n".printf(dest_item.file_path);

							log_debug("delete file: %s".printf(dest_item.file_path));
							string err_msg = "";
							if (!file_delete(dest_item.file_path, null, out err_msg)){
								log += "Failed to delete: %s\n".printf(dest_item.file_path);
								log += err_msg;
								aborted = true;
								return false;
							}

							log += "deleted file: %s\n".printf(dest_item.file_path);

							log_debug("create dir: %s".printf(dest_item.file_path));
							err_msg = "";
							if (!dir_create(dest_item.file_path, false, null, out err_msg)){
								log += "Failed to create directory: %s\n".printf(dest_item.file_path);
								log += err_msg;
								aborted = true;
								return false;
							}
						}
					}
				}
			}
			else{

				if (!first_pass){

					// copy
					log_debug("create dir: %s".printf(dest_item_path));

					if (!dir_create(dest_item_path)){
						aborted = true;
						return false;
					}
				}

				dest_item = new FileItem.from_path(dest_item_path);
				// empty, no need to query children

			}

			foreach(var child_item in src_item.children.values){
				if (aborted) { return false; }
				copy_item_to_dir(child_item, dest_item, move, child_item.file_name); // do not create new name
			}

			if (!first_pass){
				if (move){
					dir_delete_if_empty(src_item.file_path);
				}
			}
		}

		return false;
	}

	private bool get_replace_action(FileItem src_item, FileItem dest_item){

		bool replace = false;

		if (replace_mode == FileReplaceMode.REPLACE){
			replace = true;
		}
		else if (replace_mode == FileReplaceMode.REPLACE_OLDER){
			if (src_item.modified.compare(dest_item.modified) > 0){
				replace = true;
			}
		}
		else if (replace_mode == FileReplaceMode.CUSTOM){

			FileConflictItem conflict = null;
			if (conflicts.has_key(src_item.file_path)){
				conflict = conflicts[src_item.file_path];
			}
			if (conflict != null){
				replace = conflict.replace;
			}
		}

		return replace;
	}

	private bool copy_file(string src_path, string dest_path, bool move){

		bool ok = false;
		
		var src = File.new_for_path(src_path);
		var dest = File.new_for_path(dest_path);
		
		if (!src.query_exists()){
			return true; // ignore, src may have been a symlink which was moved
		}
		
		bytes_file = 0;
		bytes_file_total = 0;

		if (move){
			status = "%s".printf(src_path);
		}
		else{
			status = "%s".printf(src_path);
		}

		cancellable = new Cancellable();

		FileProgressCallback progress_callback = ((current_num_bytes, total_num_bytes)=>{
			bytes_file = current_num_bytes;
			bytes_file_total = total_num_bytes;
			//log_debug("copied:%lld".printf(bytes_file));
		});

		try{
			if (move){
				src.move(dest, GLib.FileCopyFlags.OVERWRITE | GLib.FileCopyFlags.NOFOLLOW_SYMLINKS,
					cancellable, progress_callback);
			}
			else{
				src.copy(dest, GLib.FileCopyFlags.OVERWRITE | GLib.FileCopyFlags.NOFOLLOW_SYMLINKS,
					cancellable, progress_callback);
			}
			ok = true;
		}
		catch(Error e){
			//log_error(_("Failed to copy file") + ": %s".printf(dest_path));
			log_error(dest_path);
			log_error(e.message);
			log_error("");
			aborted = true;
			ok = false;
		}

		bytes_completed_files += bytes_file_total;
		bytes_file = 0;
		bytes_file_total = 0;
		return ok;
	}

	public void cancel_task(){
		log_debug("FileTask: cancel_task()");

		aborted = true;

		if (current_query_item != null){
			current_query_item.query_children_aborted = true;
		}

		if (cancellable != null){
			cancellable.cancel();
		}

		//gtk_do_events();
		//log_debug("FileTask: cancel_task(): aborted = %s".printf(aborted.to_string()));
		//log_debug("FileTask: cancel_task(): query_children_aborted = %s".printf(query_children_aborted.to_string()));
	}

	public void verify_copy(){


	}

	// restore task -----------------------

	
	public void restore_trashed_items(FileItem[] _items, Gtk.Window? _window){

		is_running = true;
		
		// assign arguments -----------------
		
		action = "move";
		
		items = _items;

		window = _window;

		first_pass = false;
		conflicts = new Gee.HashMap<string, FileConflictItem>();

		replace_mode = FileReplaceMode.REPLACE;

		log_debug("FileTask: restore_trashed_items(): %d".printf(_items.length));

		// init -----------------------
		
		init_task();

		status = _("Preparing...");
		timer = new GLib.Timer();
		timer.start();

		//log_debug("dest_path=%s".printf(dest_path));
		//log_debug("items=%d".printf(items.length));

		try {
			//start thread for copy operation
			Thread.create<void> (restore_items_thread, true);
		} catch (Error e) {
			log_error ("FileTask: restore_items_thread(): error");
			log_error (e.message);
		}
	}

	private void restore_items_thread(){

		build_file_list_for_copy();

		if (!aborted) {

			rate_timer = new GLib.Timer();
			rate_timer.start();

			foreach(var item in items){
				if (aborted) { break; }

				source = new FileItem.from_path(item.trash_data_file);
				source.query_children();
				
				destination = new FileItem.from_path(file_parent(item.trash_original_path));
				destination.query_children(1);

				string dest_item_name = item.file_name;
				if (destination.children.has_key(item.file_name)){
					int index = 1;
					do{
						dest_item_name = "%s%s%s".printf(item.file_title, " (%d)".printf(index++), item.file_extension);
						// TODO: restore to same path?
					}
					while(file_or_dir_exists(path_combine(destination.file_path, dest_item_name)));
				}

				bool ok = copy_item_to_dir(source, destination, (action == "move"), dest_item_name);
				if (ok){
					file_delete(item.trash_info_file);
				}
			}

			rate_timer.stop();
		}

		timer.stop();

		log_debug("FileTask: restore_items_thread(): thread exit");
		is_running = false;

		complete();
	}

	// delete task ---------------------

	public void delete_items(FileItem[] _items, Gtk.Window? _window){
		window = _window;
		items = _items;
		remove_items(false);
	}

	public void trash_items(FileItem[] _items, Gtk.Window? _window){
		window = _window;
		items = _items;
		remove_items(true);
	}

	private void remove_items(bool send_to_trash){

		action = send_to_trash ? "trash" : "delete";
		
		log_debug("FileTask: remove_items(%s): %d".printf(action, items.length));

		is_running = true;
		init_task();

		status = _("Preparing...");
		timer = new GLib.Timer();
		timer.start();

		try {
			//start thread for copy operation
			Thread.create<void> (delete_items_thread, true);
		} catch (Error e) {
			log_error ("FileTask: remove_items(): error");
			log_error (e.message);
		}
	}

	private void delete_items_thread(){

		if (action == "delete"){
			build_file_list_for_copy();
		}
		else if (action == "trash"){
			bytes_batch_total = 0;
			count_batch_total = 0;
			foreach(var item in items){
				count_batch_total++;
			}
		}

		if (!aborted) {

			rate_timer = new GLib.Timer();
			rate_timer.start();

			foreach(var item in items){
				if (aborted) { break; }

				bool send_to_trash = (action == "trash");
				bool ok = delete_item(item, send_to_trash);
				if (!send_to_trash && !ok){
					aborted = true; // abort on first error for delete action only
				}
			}

			rate_timer.stop();
		}

		timer.stop();

		log_debug("FileTask: delete_items(): thread exit");
		is_running = false;

		complete();
	}

	private bool delete_item(FileItem item, bool send_to_trash){

		if (aborted) { return false; }

		// trash -----------------------
		
		if (send_to_trash){

			status = _("Item") + ": %s".printf(item.file_path);
			
			log_debug("trash: %s".printf(item.file_path));
			
			bool ok = file_trash(item.file_path, null); // pass window=null to avoid weird XWindow issue
			bytes_completed_files += item.size;
			count_batch_completed += 1;
			return ok; 
		}

		// delete ----------------------------
		
		if (item.file_type != FileType.DIRECTORY){

			status = "%s".printf(item.file_path);

			if (!file_delete(item.file_path, null)){ // pass window=null to avoid weird XWindow issue
				aborted = true;
			}
			else{
				bytes_completed_files += item.size;
				count_batch_completed += 1;
				log_debug("delete: %s".printf(item.file_path));
			}
		}
		else { // item.file_type == FileType.DIRECTORY
			foreach(var child_item in item.children.values){
				if (aborted) { return false; }
				if (!delete_item(child_item, send_to_trash)){
					aborted = true;
				}
			}
			status = "%s".printf(item.file_path);
			if (!dir_delete_if_empty(item.file_path)){
				aborted = true;
			}
			else{
				//bytes_completed_files += item.size; // skip for dirs
				count_batch_completed += 1;
			}
		}

		return !aborted;
	}

	// query async -------------------------

	public bool query_children_async_is_running = false;
	public bool query_children_async_aborted = false;
	
	public void query_children_async(FileItem[] _items) {

		is_running = true;
		
		items = _items;
		
		log_debug("FileTask: query_children_async(): %d".printf(items.length));

		query_children_async_is_running = true;
		query_children_async_aborted = false;

		foreach(var item in items){
			if (item.is_directory){
				item.query_children_pending = true;
			}
		}
		
		try {
			//start thread
			Thread.create<void> (query_children_async_thread, true);
			//Thread<void*> thread = new Thread<void*>.try("", query_children_async_thread);
		}
		catch (Error e) {
			log_error ("FileItem: query_children_async(): error");
			log_error (e.message);
		}
	}

	private void query_children_async_thread() {
		
		log_debug("FileTask: query_children_async_thread()");

		foreach(var item in items){
			if (item.is_directory){
				item.query_children();
			}
		}

		/*while(true){
			
			int running_count = 0;
			foreach(var item in items){
				if (item.is_directory){
					if (item.query_children_async_is_running){
						running_count++;
						break;
					}
				}
			}
			if (running_count == 0){
				break;
			}
			else{
				sleep(1000);
			}
		}*/
		
		query_children_async_is_running = false;
		query_children_async_aborted = false; // reset

		is_running = false;
		complete();

		log_debug("FileTask: query_children_async_thread(): exit");
	}

	// stats -------------------------------

	public int64 bytes_batch{
		get {
			return bytes_completed_files + bytes_file;
		}
	}

	public double progress{
		get {
			return (bytes_batch * 1.0) / bytes_batch_total;
		}
	}

	private string _stats = "";

	public string stats{
		owned get {
			if (_stats.length > 0){
				return _stats;
			}

			switch(action){
			case "move":
			case "copy":
				if (bytes_batch == 0){
					return "%s elapsed".printf(
						//format_file_size(bytes_batch_total),
						stats_time_elapsed);
				}
				else{
					return "%s / %s %s (%.0f%%), %s, %s elapsed, %s remaining".printf(
						format_file_size(bytes_batch),
						format_file_size(bytes_batch_total),
						((action == "move") ? _("moved") : _("copied")),
						progress * 100.0,
						stats_speed,
						stats_time_elapsed,
						stats_time_remaining
						);
				}

			case "delete":
			case "trash":
				if (count_batch_completed == 0){
					return "%s elapsed".printf(
						//format_file_size(bytes_batch_total),
						stats_time_elapsed);
				}
				else{
					return "%'lld / %'lld items %s (%.0f%%), %s elapsed, %s remaining".printf(
						count_batch_completed,
						count_batch_total,
						((action == "delete") ? _("deleted") : _("trashed")),
						progress * 100.0,
						stats_time_elapsed,
						stats_time_remaining
						);
				}

			default:
				return "%s elapsed".printf(
					//bytes_batch_total,
					stats_time_elapsed);
			}
		}
	}

	public string stats_time_elapsed{
		owned get{
			long elapsed = (long) timer_elapsed(timer);
			return format_duration(elapsed);
		}
	}

	public string stats_time_remaining{
		owned get{
			if (progress > 0){
				long elapsed = (long) timer_elapsed(rate_timer);
				long remaining = (long)((elapsed / progress) * (1.0 - progress));
				if (remaining < 0){
					remaining = 0;
				}
				return format_duration(remaining);
			}
			else{
				return "???";
			}
		}
	}

	public string stats_speed{
		owned get{
			long elapsed = (long) timer_elapsed(rate_timer);
			long speed = (long)((bytes_batch + bytes_file) / (elapsed / 1000.0));
			return format_file_size(speed, false, "", true, 0) + "/s";
		}
	}

}

public enum FileReplaceMode{
	NONE,
	REPLACE,
	REPLACE_OLDER,
	RENAME,
	SKIP,
	CUSTOM
}

public class FileConflictItem : GLib.Object {

	public FileItem source_item;
	public FileItem dest_item;

	public FileItem source_base_dir;
	public FileItem dest_base_dir;

	public bool replace;

	public FileConflictItem(FileItem src, FileItem dest, FileItem src_base, FileItem dest_base){
		source_item = src;
		dest_item = dest;
		source_base_dir = src_base;
		dest_base_dir = dest_base;
		replace = true;
	}
	
	public string location {
		owned get {
			return source_item.file_location[source_base_dir.file_path.length + 1: source_item.file_location.length];
		}
	}
}
