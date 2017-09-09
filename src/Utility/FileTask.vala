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

public enum FileActionType{
	NONE,
	CUT,
	COPY,
	PASTE,
	TRASH,
	TRASH_EMPTY,
	DELETE,
	DELETE_TRASHED,
	RESTORE,
	SHRED,
	PASTE_SYMLINKS_AUTO,
	PASTE_SYMLINKS_ABSOLUTE,
	PASTE_SYMLINKS_RELATIVE,
	PASTE_HARDLINKS,
	LIST_ARCHIVE,
	TEST_ARCHIVE,
	EXTRACT,
	COMPRESS,
	KVM_DISK_MERGE,
	KVM_DISK_CONVERT,
	ISO_WRITE,
	VIDEO_LIST_FORMATS,
	VIDEO_DOWNLOAD,
	CLOUD_RENAME
}

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
	public Gee.ArrayList<FileConflictItem> conflicts_sorted;
	public Gee.HashMap<string, FileCopyItem> copy_list;
	
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
	
	private GLib.Timer timer = new GLib.Timer();
	private GLib.Timer rate_timer = new GLib.Timer();
	private Mutex mutex = Mutex();

	public RsyncTask rsync;

	public RCloneTask rclone;

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

	// public actions --------------
	
	public void copy_items_to_path(FileItem _source, string dest_path, FileItem[] _items,
		FileReplaceMode _replace_mode, Gee.HashMap<string, FileConflictItem>? _conflicts, Gtk.Window? _window){

		copy_or_move_items_to_path(_source, dest_path, _items, false, _replace_mode, _conflicts, _window);
	}

	public void move_items_to_path(FileItem _source, string dest_path, FileItem[] _items,
		FileReplaceMode _replace_mode, Gee.HashMap<string, FileConflictItem>? _conflicts, Gtk.Window? _window){

		copy_or_move_items_to_path(_source, dest_path, _items, true, _replace_mode, _conflicts, _window);
	}

	public void cloud_rename(string _source_file, string new_name, Gtk.Window? _window){

		log_debug("FileTask: cloud_rename(): %s, %s".printf(_source_file, new_name));
		
		is_running = true;
		
		window = _window;

		init_task();

		status = _("Renaming items...");
		log_debug(status);
		
		timer = new GLib.Timer();
		timer.start();


		// start timers
		rate_timer = new GLib.Timer();
		rate_timer.start();

		// init rclone task
		rclone = new RCloneTask();
		rclone.source_path = _source_file;
		rclone.dest_path = path_combine(file_parent(_source_file), new_name);
		rclone.action = RcloneActionType.RENAME;
		
		// ---------------------

		//rclone.dry_run = true;

		rclone.task_complete.connect(()=>{

			rate_timer.stop();

			timer.stop();

			log_debug("FileTask: cloud_rename(): exit");
			is_running = false;

			complete();
		});

		rclone.execute();
	}


	// private helpers --------------
	
	private void copy_or_move_items_to_path(FileItem _source, string dest_path, FileItem[] _items, bool move,
		FileReplaceMode _replace_mode, Gee.HashMap<string, FileConflictItem>? _conflicts, Gtk.Window? _window){

		is_running = true;
		
		// assign arguments -----------------
		
		action = move ? "move" : "copy";
		
		items = _items;

		replace_mode = _replace_mode;

		window = _window;

		source = _source;

		first_pass = (_conflicts == null);
		if (_conflicts == null){
			conflicts = new Gee.HashMap<string, FileConflictItem>();
			copy_list = new Gee.HashMap<string, FileCopyItem>();
		}
		else{
			conflicts = _conflicts;
		}

		if (first_pass){
			if (FileItemCloud.is_remote_path(dest_path)){
				log_debug("FileTask: is_remote_path: %s".printf(dest_path));
				destination = new FileItemCloud.from_path_and_type(dest_path, FileType.DIRECTORY);
			}
			else{	
				destination = new FileItem.from_path(dest_path);
			}
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
			//start thread

			if (first_pass){
				Thread.create<void> (check_conflicts_thread, true);
			}
			else if ((source is FileItemCloud) || (destination is FileItemCloud)){
				Thread.create<void> (rclone_copy_thread, true);
			}
			else {
				//Thread.create<void> (rsync_copy_thread, true);
				Thread.create<void> (copy_items_thread, true);
			}
			
		} catch (Error e) {
			log_error ("FileTask: copy_or_move_items_to_path(): error");
			log_error (e.message);
		}
	}

	private void check_conflicts_thread(){

		log_debug("FileTask: check_conflicts_thread() ----------");
		
		rate_timer = new GLib.Timer();
		rate_timer.start();

		status = _("Listing destination items...");
		log_debug(status);
		
		destination.query_children(1, false);
			
		status = _("Listing source items...");
		log_debug(status);
		
		query_source_items();

		status = _("Comparing items...");
		log_debug(status);
		
		foreach(var item in items){
			if (aborted) { break; }

			string dest_item_name = item.file_name;

			if (source.file_path == destination.file_path){
				if (destination.children.has_key(item.file_name)){

					string dest_path = path_combine(destination.file_path, dest_item_name);
					dest_path = file_generate_unique_name(dest_path);
					dest_item_name = file_basename(dest_path);
				}
			}

			compare_item(item, destination, (action == "move"), dest_item_name, true);
		}

		sort_conflicts();

		//count_items_for_copy();
		print_copy_list();

		rate_timer.stop();

		timer.stop();

		log_debug("FileTask: check_conflicts_thread(): exit");
		is_running = false;

		complete();
	}
	
	private void copy_items_thread(){
		
		log_debug("FileTask: copy_items_thread(): start ----------");

		//log_debug("replace_mode: %s".printf(replace_mode.to_string()));
		//foreach(var con in conflicts.values){
		//	log_debug("%s: %s".printf(con.replace.to_string(), con.source_item.file_path));
		//}

		log_debug("FileTask: copy_items_thread(): %lld items, %s".printf(count_batch_total, format_file_size(bytes_batch_total)));

		rate_timer = new GLib.Timer();
		rate_timer.start();

		status = _("Building file list...");
		log_debug(status);
		
		update_copy_list();

		//count_items_for_copy();

		status = _("Copying items...");
		log_debug(status);

		foreach(var item in items){
			if (aborted) { break; }

			string dest_item_name = item.file_name;
			if (source.file_path == destination.file_path){
				if (destination.children.has_key(item.file_name)){

					string dest_path = path_combine(destination.file_path, dest_item_name);
					dest_path = file_generate_unique_name(dest_path);
					dest_item_name = file_basename(dest_path);
				}
			}

			compare_item(item, destination, (action == "move"), dest_item_name, false);
		}
		
		rate_timer.stop();

		timer.stop();

		log_debug("FileTask: copy_items_thread(): exit");
		is_running = false;

		complete();
	}

	private void rsync_copy_thread(){
		
		log_debug("FileTask: rsync_copy_thread(): start");

		log_debug("FileTask: rsync_copy_thread(): %lld items, %s".printf(count_batch_total, format_file_size(bytes_batch_total)));

		// start timers
		rate_timer = new GLib.Timer();
		rate_timer.start();

		// init rsync task
		rsync = new RsyncTask();
		rsync.source_path = source.file_path;
		rsync.dest_path = destination.file_path;

		if (action == "move"){
			rsync.remove_source_files = true;
		}

		status = _("Building file list...");
		log_debug(status);
		
		update_copy_list();

		//count_items_for_copy();
		
		status = _("Copying...");
		log_debug(status);

		//rsync.dry_run = true;

		rsync.task_complete.connect(()=>{
			
			rate_timer.stop();

			timer.stop();

			log_debug("FileTask: rsync_copy_thread(): exit");
			is_running = false;

			complete();
		});

		rsync.execute();

		/*
		Limitations:
		* Rclone does not remove sub folders when moving
		* No way to specify destination item name ?
		*/
	}

	private void rclone_copy_thread(){
		
		log_debug("FileTask: rclone_copy_thread(): start");

		//log_debug("replace_mode: %s".printf(replace_mode.to_string()));
		//foreach(var con in conflicts.values){
		//	log_debug("%s: %s".printf(con.replace.to_string(), con.source_item.file_path));
		//}

		log_debug("FileTask: rclone_copy_thread(): %lld items, %s".printf(count_batch_total, format_file_size(bytes_batch_total)));

		// start timers
		rate_timer = new GLib.Timer();
		rate_timer.start();

		// init rclone task
		rclone = new RCloneTask();
		rclone.source_path = source.file_path;
		rclone.dest_path = destination.file_path;
		rclone.action = RcloneActionType.COPY;
		
		if (action == "move"){
			rclone.action = RcloneActionType.MOVE;
			//rclone.remove_source_files = true;
		}
		else{
			rclone.action = RcloneActionType.COPY;
		}

		// ---------------------

		status = _("Building file list...");
		log_debug(status);
		
		update_copy_list();

		//count_items_for_copy();

		// ---------------------
		
		if (source is FileItemCloud){ 
			status = _("Downloading items...");
		}
		else if (destination is FileItemCloud){
			status = _("Uploading items...");
		}
		else{
			status = _("Copying items...");
		}

		log_debug(status);

		//rclone.dry_run = true;

		rclone.task_complete.connect(()=>{

			rate_timer.stop();

			timer.stop();

			log_debug("FileTask: rclone_copy_thread(): exit");
			is_running = false;

			complete();
		});

		rclone.execute();
	}

	// ---------------------------------------------------------
	
	private bool compare_item(FileItem src_item, FileItem dest_dir, bool move, string dest_item_name, bool dry_run){

		//log_debug("compare_item: src_item: %s, dest: %s, dest_item_name: %s".printf(src_item.file_path, dest_dir.file_path, dest_item_name));

		if (aborted) { return false; }

		if (dest_dir.file_type != FileType.DIRECTORY){
			log += "Copy destination is a file!\n";
			return false;
		}

		if ((src_item.file_type == FileType.REGULAR) || src_item.is_symlink){

			// source is file

			if (dest_dir.children.has_key(dest_item_name)){

				// dest exists

				var dest_item = dest_dir.children[dest_item_name];

				if (dry_run){
					// save conflict item
					log_msg("conflict: %s".printf(src_item.file_path));
					var conflict = new FileConflictItem(src_item, dest_item, source, destination);
					conflicts[src_item.file_path] = conflict;

					copy_list[src_item.file_path] = new FileCopyItem(src_item.file_path, dest_item.file_path, src_item.file_size);
				}
				else{

					bool replace = get_replace_action(src_item, dest_item);

					if (dest_item.file_type == FileType.REGULAR){
						if (replace){
							log += "Replaced: %s\n".printf(dest_item.file_path);
							return copy_file(src_item.file_path, dest_item.file_path, move);
						}
					}
					else{
						if (replace){
							return copy_file(src_item.file_path, dest_item.file_path, move);
						}
					}
				}
			}
			else{
				// dest not existing

				var dest_item_path = path_combine(dest_dir.file_path, dest_item_name);
				
				if (dry_run){
					copy_list[src_item.file_path] = new FileCopyItem(src_item.file_path, dest_item_path, src_item.file_size);
				}
				else{
					return copy_file(src_item.file_path, dest_item_path, move);
				}
			}

		}
		else {

			// source is folder

			FileItem dest_item = null;
			var dest_item_path = path_combine(dest_dir.file_path, dest_item_name);

			if (dest_dir.children.has_key(dest_item_name)){

				// dest exists
				
				dest_item = dest_dir.children[dest_item_name];

				if (dest_item.file_type == FileType.DIRECTORY){

					// dest is folder
					
					dest_item.query_children(1, false);

					if (!dry_run){

						// merge - no action needed
						log_debug("merging dirs: %s -> %s".printf(src_item.file_path, dest_item.file_path));
						log += "Merging directories: %s\n".printf(dest_item.file_path);
					}
				}
				else{

					// dest is file

					if (dry_run){
						log_msg("conflict: %s".printf(src_item.file_path));
						var conflict = new FileConflictItem(src_item, dest_item, source, destination);
						conflicts[src_item.file_path] = conflict;

						copy_list[src_item.file_path] = new FileCopyItem(src_item.file_path, dest_item.file_path, 0);
					}
					else {
						bool replace = get_replace_action(src_item, dest_item);

						if (replace){

							log_debug("dest dir is a file: %s -> %s".printf(src_item.file_path, dest_item.file_path));
							log += "File exists at destination: %s\n".printf(dest_item.file_path);

							log_msg("deleted: %s".printf(dest_item.file_path));
							string err_msg = "";
							if (!file_delete(dest_item.file_path, null, out err_msg)){
								log += "Failed to delete: %s\n".printf(dest_item.file_path);
								log += err_msg;
								aborted = true;
								return false;
							}

							log += "deleted file: %s\n".printf(dest_item.file_path);

							log_msg("mkdir: %s/".printf(dest_item.file_path));
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

				// dest not existing

				if (dry_run){
					copy_list[src_item.file_path] = new FileCopyItem(src_item.file_path, dest_item_path, 0);
				}
				else{

					// copy
					log_msg("mkdir: %s/".printf(dest_item_path));

					if (!dir_create(dest_item_path)){
						aborted = true;
						return false;
					}
				}

				dest_item = new FileItem.from_path_and_type(dest_item_path, FileType.DIRECTORY, false);
				// empty, no need to query children

			}

			foreach(var child_item in src_item.children.values){
				if (aborted) { return false; }
				compare_item(child_item, dest_item, move, child_item.file_name, dry_run); // do not create new name
			}

			if (!dry_run){
				if (move){
					dir_delete_if_empty(src_item.file_path);
				}
			}
		}

		return false;
	}

	private void update_copy_list(){

		foreach(var con in conflicts.values){
			if (!get_replace_action(con.source_item, con.dest_item)){
				var item = con.source_item;
				copy_list.unset(con.source_item.file_path);
				bytes_batch_total -= item.file_size;
				count_batch_total -= 1;

				if (rsync != null){
					rsync.add_rule_exclude(con.source_item.file_path, con.source_item.is_directory);
				}

				if (rclone != null){
					rclone.add_rule_exclude(con.source_item.file_path, con.source_item.is_directory);
				}
			}
		}

		if (rsync != null){
			foreach(var item in items){
				rsync.add_rule_include(item.file_path, item.is_directory);
			}
			rsync.add_rule_exclude_others();
		}

		if (rclone != null){
			foreach(var item in items){
				rclone.add_rule_include(item.file_path, item.is_directory);
			}
			rclone.add_rule_exclude_others();

			rclone.bytes_total = bytes_batch_total; // will be used by rclone.stats
		}

		print_copy_list();
	}

	private Gee.ArrayList<FileCopyItem> get_copy_list_sorted(){

		var list = new Gee.ArrayList<FileCopyItem>();
		
		foreach(var item in copy_list.values){
			list.add(item);
		}
		
		list.sort((a,b)=>{
			return strcmp(a.source_path, b.source_path);
		});
		
		return list;
	}

	private void print_copy_list(){
		var list = get_copy_list_sorted();
		log_debug("Copy List: %d items".printf(list.size));
		foreach(var item in list){
			log_debug("%s, %s".printf(item.source_path, format_file_size(item.size)));
		}
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
	
	private void sort_conflicts(){
		
		var list = new Gee.ArrayList<FileConflictItem>();
		
		foreach(var con in conflicts.values){
			list.add(con);
		}
		
		list.sort((a,b)=>{
			int val = strcmp(a.location, b.location);
			if (val == 0){
				return strcmp(a.source_item.file_name, b.source_item.file_name);
			}
			else {
				return val;
			}
		});
		
		conflicts_sorted =  list;
	}

	private bool copy_file(string src_path, string dest_path, bool move){

		bool ok = false;
		
		var src = File.new_for_path(src_path);
		var dest = File.new_for_path(dest_path);
		
		if (!src.query_exists()){
			return true; // ignore, src may have been a symlink which was moved
		}

		bool is_replace = dest.query_exists();
		
		bytes_file = 0;
		bytes_file_total = 0;

		if (move){
			status = "%s %'lld / %'lld - %s".printf(_("Moving file"),
				count_batch_completed + 1, count_batch_total, src_path[source.file_path.length + 1:src_path.length]);
		}
		else{
			status = "%s %'lld / %'lld - %s".printf(_("Copying file"),
				count_batch_completed + 1, count_batch_total, src_path[source.file_path.length + 1:src_path.length]);
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

				//if (is_replace){
				//	log_msg("replaced: %s".printf(dest_path));
				//}
				//else{
					log_msg("move: %s".printf(dest_path));
				//}
			}
			else{
				src.copy(dest, GLib.FileCopyFlags.OVERWRITE | GLib.FileCopyFlags.NOFOLLOW_SYMLINKS,
					cancellable, progress_callback);

				//if (is_replace){
				//	log_msg("copy: %s".printf(dest_path));
				//}
				//else{
					log_msg("copy: %s".printf(dest_path));
				//}
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
		count_batch_completed++;
		return ok;
	}

	public void stop(){
		log_debug("FileTask: stop()");

		aborted = true;
		
		if (rsync != null){
			rsync.stop();
		}

		if (rclone != null){
			rclone.stop();
		}

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

		query_source_items();

		if (!aborted) {

			rate_timer = new GLib.Timer();
			rate_timer.start();

			foreach(var item in items){
				if (aborted) { break; }

				source = new FileItem.from_path(item.trash_data_file);
				source.query_children(-1, false);
				
				destination = new FileItem.from_path(file_parent(item.trash_original_path));
				destination.query_children(1, false);

				string dest_item_name = item.file_name;
				if (destination.children.has_key(item.file_name)){
					int index = 1;
					do{
						dest_item_name = "%s%s%s".printf(item.file_title, " (%d)".printf(index++), item.file_extension);
						// TODO: restore to same path?
					}
					while(file_or_dir_exists(path_combine(destination.file_path, dest_item_name)));
				}

				bool ok = compare_item(source, destination, (action == "move"), dest_item_name, true);
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

	public void delete_items(FileItem? _source, FileItem[] _items, Gtk.Window? _window){
		window = _window;
		items = _items;
		source = _source;
		remove_items(false);
	}

	public void trash_items(FileItem? _source, FileItem[] _items, Gtk.Window? _window){
		window = _window;
		items = _items;
		source = _source;
		remove_items(true);
	}


	public void empty_trash(){
		
		//action = send_to_trash ? "trash" : "delete";
		
		log_debug("FileTask: empty_trash()");

		is_running = true;
		init_task();

		status = _("Emptying trash...");
		timer = new GLib.Timer();
		timer.start();

		try {
			// start thread
			Thread.create<void> (empty_trash_thread, true);
		}
		catch (Error e) {
			log_error ("FileTask: empty_trash_thread(): error");
			log_error (e.message);
		}
	}
	
	public void empty_trash_thread(){

		log_debug("FileTask: empty_trash_thread(): enter");
		
		TrashCan.empty_trash();

		timer.stop();

		log_debug("FileTask: empty_trash_thread(): exit");
		is_running = false;

		complete();
	}
	
	// ----------------
	
	private void remove_items(bool send_to_trash){

		action = send_to_trash ? "trash" : "delete";
		
		log_debug("FileTask: remove_items(%s): %d".printf(action, items.length));

		is_running = true;
		init_task();

		status = _("Preparing...");
		timer = new GLib.Timer();
		timer.start();

		try {
			//start thread for operation
			if ((source is FileItemCloud) || (destination is FileItemCloud)){
				Thread.create<void> (rclone_delete_thread, true);
			}
			else{
				Thread.create<void> (delete_items_thread, true);
			}
			
		} catch (Error e) {
			log_error ("FileTask: remove_items(): error");
			log_error (e.message);
		}
	}

	private void delete_items_thread(){

		log_debug("FileTask: delete_items(): enter");
		
		if (action == "delete"){
			query_source_items();
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

		log_debug("FileTask: delete_items(): exit");
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
			bytes_completed_files += item.file_size;
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
				bytes_completed_files += item.file_size;
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

	private void rclone_delete_thread(){
		
		log_debug("FileTask: rclone_delete_thread(): start");

		//log_debug("FileTask: rclone_delete_thread(): %lld items, %s".printf(count_batch_total, format_file_size(bytes_batch_total)));

		// start timers
		rate_timer = new GLib.Timer();
		rate_timer.start();

		// init rclone task
		rclone = new RCloneTask();
		rclone.source_path = source.file_path;
		rclone.action = RcloneActionType.DELETE;

		// ---------------------
		
		status = _("Building file list...");
		log_debug(status);
		
		query_source_items();

		// ---------------------
		
		status = _("Building file list...");
		log_debug(status);
		
		update_rclone_delete_list();

		//count_items_for_copy();

		// ---------------------
		
		status = _("Removing items...");
		log_debug(status);

		//rclone.dry_run = true;

		rclone.task_complete.connect(()=>{

			rate_timer.stop();

			timer.stop();

			log_debug("FileTask: rclone_delete_thread(): exit");
			is_running = false;

			complete();
		});

		rclone.execute();
	}

	private void update_rclone_delete_list(){

		foreach(var item in items){
			rclone.add_rule_include(item.file_path, item.is_directory);
		}
		rclone.add_rule_exclude_others();
	}
	
	// query async -------------------------

	private void query_source_items(){
		
		log_debug("FileTask: query_source_items()");

		//status = _("Building file list...");

		bytes_batch_total = 0;
		count_batch_total = 0;

		foreach(var item in items){

			if (aborted) { break; }

			if (item.file_type == FileType.DIRECTORY){
				
				current_query_item = item;
				item.query_children_async(false);

				while(item.query_children_async_is_running){

					_stats = "%'lld items (%s), %s elapsed".printf(
						count_batch_total + item.file_count_total + item.dir_count_total,
						format_file_size(bytes_batch_total + item.file_size),
						stat_time_elapsed
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

			bytes_batch_total += item.file_size;
			count_batch_total += item.get_file_count_recursively(true);
		}

		_stats = "";
		log_debug("FileTask: query_source_items(): %lld items, %s".printf(count_batch_total, format_file_size(bytes_batch_total)));
	}

	// calculate_dirsize ------------------------------------------
	
	public void calculate_dirsize_async(FileItem[] _items) {

		is_running = true;
		aborted = false;
		
		items = _items;
		
		log_debug("FileTask: calculate_dirsize_async(): %d".printf(items.length));

		foreach(var item in items){
			if (item.is_directory){
				item.query_children_pending = true;
			}
		}
		
		try {
			//start thread
			Thread.create<void> (calculate_dirsize_async_thread, true);
			//Thread<void*> thread = new Thread<void*>.try("", calculate_dirsize_async_thread);
		}
		catch (Error e) {
			log_error ("FileItem: calculate_dirsize_async(): error");
			log_error (e.message);
		}
	}

	private void calculate_dirsize_async_thread() {
		
		log_debug("FileTask: calculate_dirsize_async_thread()");

		foreach(var item in items){
			if (aborted){ break; }
			if (item.is_directory){
				item.query_children(-1, true);
				//item.query_children_pending = false;
			}
		}

		foreach(var item in items){
			if (item.is_directory){
				item.query_children_pending = false;
			}
		}

		is_running = false;
		complete();

		log_debug("FileTask: calculate_dirsize_async_thread(): exit");
	}


	// stats -------------------------------

	public int64 bytes_batch{
		get {
			return bytes_completed_files + bytes_file;
		}
	}

	public double progress{
		get {
			if (rsync != null){
				return rsync.progress;
			}
			else if (rclone != null){
				return rclone.progress;
			}
			else{
				return (bytes_batch * 1.0) / bytes_batch_total;
			}
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
				if ((rsync != null) && (rsync.is_running)){
					return rsync.stats;
				}
				else if ((rclone != null) && (rclone.is_running)){
					return rclone.stats;
				}
				else {

					string txt = "";

					txt += "%s".printf(format_file_size(bytes_batch));

					if (bytes_batch_total > 0){
						txt += " / %s".printf(format_file_size(bytes_batch_total));
					}

					//txt += " %s".printf(_("transferred"));
					
					txt += " (%.0f%%),".printf(progress * 100.0);

					txt += " %s,".printf(stat_speed);

					txt += " %s elapsed,".printf(stat_time_elapsed);

					txt += " %s remaining".printf(stat_time_remaining);

					return txt;
				}

			case "delete":
			case "trash":
				if (count_batch_completed == 0){
					return "%s elapsed".printf(
						//format_file_size(bytes_batch_total),
						stat_time_elapsed);
				}
				else{
					return "%'lld / %'lld items %s (%.0f%%), %s elapsed, %s remaining".printf(
						count_batch_completed,
						count_batch_total,
						((action == "delete") ? _("deleted") : _("trashed")),
						progress * 100.0,
						stat_time_elapsed,
						stat_time_remaining
						);
				}

			default:
				return "%s elapsed".printf(
					//bytes_batch_total,
					stat_time_elapsed);
			}
		}
	}

	public string stat_time_elapsed{
		owned get{
			long elapsed = (long) timer_elapsed(timer);
			return format_duration(elapsed);
		}
	}

	public string stat_time_remaining{
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

	public string stat_speed{
		owned get{
			long elapsed = (long) timer_elapsed(rate_timer);
			long speed = (long)((bytes_batch + bytes_file) / (elapsed / 1000.0));
			return format_file_size(speed, false, "", true, 0) + "/s";
		}
	}

	private string _status = "";
	
	public string status{
		owned get {
			if ((rsync != null) && (rsync.is_running)){
				return rsync.status_line;
			}
			else{
				return _status;
			}
		}
		set {
			_status = value;
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
			if (source_item.file_location.length == source_base_dir.file_path.length){
				return "";
			}
			else{
				return source_item.file_location[source_base_dir.file_path.length + 1: source_item.file_location.length];
			}
		}
	}
}

public class FileCopyItem : GLib.Object {
	
	public string source_path = "";
	public string dest_path = "";
	public int64 size = 0;

	public FileCopyItem(string _source_path, string _dest_path, int64 _size){
		source_path = _source_path;
		dest_path = _dest_path;
		size = _size;
	}
	
}
