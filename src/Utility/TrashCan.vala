
/*
 * Trash.vala
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

using TeeJee.Logging;
using TeeJee.FileSystem;
using TeeJee.ProcessHelper;
using TeeJee.Misc;
using TeeJee.System;
using TeeJee.GtkHelper;

public class TrashCan : FileItem {

	public int64 trash_can_size = 0;
	public string user_id = "";
	public string user_name = "";
	public string user_home = "";
	
	//public new signal void changed();
	public new signal void query_completed();

	private bool thread_running;
	private bool thread_cancelled;

	public new string size_formatted{
		owned get {
			return format_file_size(trash_can_size);
		}
	}

	public TrashCan(int _user_id, string _user_name, string _user_home) {
		this.is_trash = true;
		this.user_id = _user_id.to_string();
		this.user_name = _user_name;
		this.user_home = _user_home;
	}

	public void query_items(bool wait){
		
		thread_cancelled = false;

		try {
			thread_running = true;
			Thread.create<void> (query_items_thread, true);
		} catch (ThreadError e) {
			thread_running = false;
			log_error (e.message);
		}

		if (wait){
			while(thread_running){
				sleep(200);
				gtk_do_events();
			}
		}
	}

	public void query_items_thread(){

		log_debug("TrashCan: query_items(): %s".printf(string.nfill(30,'-')));
		
		this.children.clear();
		this.trash_can_size = 0;

		load_trash_directory(path_combine(App.user_home,".local/share/Trash"));

		foreach(var dev in Device.get_devices()){
			if (dev.is_snap_volume) { continue; }
			foreach(var mnt in dev.mount_points){
				if (mnt.mount_point.length == 0) { continue; }

				string trash_path = path_combine(mnt.mount_point, ".Trash");
				trash_path = path_combine(trash_path, user_id);
				//log_debug("trash_path=%s".printf(trash_path));
				if (dir_exists(trash_path)){
					load_trash_directory(trash_path, mnt.mount_point);
				}
				
				trash_path = path_combine(mnt.mount_point, ".Trash-%s".printf(user_id));
				//log_debug("trash_path=%s".printf(trash_path));
				if (dir_exists(trash_path)){
					load_trash_directory(trash_path, mnt.mount_point);
				}
			}
		}

		FileItem.add_to_cache(this);

		thread_running = false;

		log_debug("TrashCan: query_items():end %s".printf(string.nfill(30,'-')));
		
		query_completed();		
	}

	private void load_trash_directory(string trash_path, string mount_path = ""){

		log_debug("TrashCan: load_trash_directory: %s".printf(trash_path), true);

		remove_orphaned_trashinfo(trash_path);
		
		string dir_files = path_combine(trash_path, "files");
		string dir_info = path_combine(trash_path, "info");
		//string dir_expunged = path_combine(trash_path, "expunged");

		if (!dir_exists(dir_files) || !dir_exists(dir_info)){
			log_error("Trash: directories 'info' and 'files' not found: %s".printf(trash_path));
			return;
		}

		var fi = new FileItem.from_path(dir_files);
		fi.query_children(1, false);
		foreach(var item in fi.children.values){
			string item_name = item.file_name;
			read_trash_info(dir_files, dir_info, item_name, mount_path);
		}
	}

	private void remove_orphaned_trashinfo(string trash_path){

		//log_debug("Trash: remove_orphaned_trashinfo(): %s".printf(trash_path));
		
		string dir_files = path_combine(trash_path, "files");
		string dir_info = path_combine(trash_path, "info");
		//string dir_expunged = path_combine(trash_path, "expunged");
		
		var dir = new FileItem.from_path(dir_info);
		dir.query_children(1, false);
		
		foreach(var item in dir.children.values){
			
			string item_name = item.file_name.replace(".trashinfo","");
			string info_file = path_combine(dir_info, item_name) + ".trashinfo";
			string data_file = path_combine(dir_files, item_name);

			//log_debug("Trash: info_file: %s".printf(info_file));
			//log_debug("Trash: data_file: %s".printf(data_file));
			
			if (!file_or_dir_exists(data_file)){
				// delete the orphaned .trashinfo file
				log_msg("Trash: Deleting orphaned file: %s".printf(info_file));
				file_delete(info_file);
			}
		}
	}

	private void read_trash_info(string dir_files, string dir_info, string item_name, string mount_path){
		/*
		[Trash Info]
		Path=/home/teejee/Pictures/Terminal_106.png
		DeletionDate=2017-03-26T13:45:41
		*/
		
		//log_debug("TrashCan: read_trash_info: item_name: %s".printf(item_name), true);
		
		string orig_path = "";
		DateTime trash_date = new DateTime.now_utc();

		string info_file = path_combine(dir_info, item_name) + ".trashinfo";
		string trash_file = path_combine(dir_files, item_name);
		int64 trash_size = 0;

		string file_info_text = "[Trash Info]\n";

		if (file_exists(info_file)){ 

			file_info_text = file_read(info_file);
			foreach(string line in file_info_text.split("\n")){
				if (line.down().has_prefix("path=")){
					orig_path = line[line.index_of("=") + 1: line.length];
					if (mount_path.length > 0){
						orig_path = path_combine(mount_path, orig_path);
					}
				}
				else if (line.down().has_prefix("deletiondate=")){
					var txt = line[line.index_of("=") + 1: line.length];
					trash_date = parse_deletion_date(txt);
				}
				else if (line.down().has_prefix("size=")){
					var txt = line[line.index_of("=") + 1: line.length];
					trash_size = int64.parse(txt);
					//log_debug("Size=%s".printf(txt));
				}
			}
		}
		else{
			// .trashinfo file is missing for item in /files
			var fi = new FileItem.from_path(trash_file); 
			trash_date = fi.changed;
		}

		//log_debug("trashed item------------------------");
		//log_debug("trash_file: %s".printf(trash_file));
		//log_debug("info_file: %s".printf(info_file));

		// set some properties to be passed to children
		
		
		var item = this.add_child_from_disk(trash_file, 0);
		item.is_trashed_item = true;
		item.trash_basepath = file_parent(trash_file);
		item.trash_original_path = uri_decode(orig_path);
		item.trash_item_name = item_name;
		item.trash_deletion_date = trash_date;
		item.trash_info_file = info_file;
		item.trash_data_file = trash_file;
		
		if (item.trash_original_path.length > 0){
			item.display_name = file_basename(item.trash_original_path);
		}

		//FileItem.add_to_cache(item); // do not add to cache
		//log_debug("trashed item: %s".printf(orig_path));
		//log_debug("trashed on  : %s".printf(item.trash_deletion_date.format ("%Y-%m-%d %H:%M")));
		//log_debug("trashed type: %s".printf(item.content_type));

		if (trash_size == 0) {
			if (item.file_type == FileType.DIRECTORY){
				log_msg("Trash: Calculating trashed folder size: %s".printf(trash_file));
				trash_size = dir_size(trash_file);
			}
			else{
				trash_size = file_get_size(trash_file);
			}

			item.file_size = trash_size;

			if (file_exists(info_file)){
				log_msg("Trash: Updating trashinfo file: %s".printf(info_file));
				if (!file_info_text.has_suffix("\n")){
					file_info_text += "\n";
				}
				file_info_text += "Size=%lld".printf(trash_size);
				// write file in-place without changing owner or permissions
				file_write(info_file, file_info_text, null, null, true);
				//chown(info_file, App.user_name, App.user_name, false, null);
			}
		}

		log_debug("item: %s, %s".printf(orig_path, format_file_size(trash_size)));

		item.file_size = trash_size;

		this.trash_can_size += trash_size;
		//log_debug("trash_can_size += %lld".printf(trash_size));
	}

	private DateTime parse_deletion_date(string del_date){

		// 2017-03-26T13:45:41
		// YYYY-MM-DDThh:mm:ss
		// 0123456789012345678

		//log_debug("parse_deletion_date: %s".printf(del_date));

		int year = int.parse(del_date[0:3+1]);
		int month = int.parse(del_date[5:6+1]);
		int day = int.parse(del_date[8:9+1]);
		int hr = int.parse(del_date[11:12+1]);
		int min = int.parse(del_date[14:15+1]);
		double sec = int.parse(del_date[17:18+1]);

		//log_debug("parsed: %d-%d-%d %d:%d:%.0f".printf(year, month, day, hr, min, sec));

		return new DateTime.utc(year, month, day, hr, min, sec);
	}

	public static bool empty_trash(){
		if (cmd_exists("gvfs-trash")){
			int status = exec_sync("gvfs-trash --empty");
			return (status == 0);
		}
		return false;
	}
}
