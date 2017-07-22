
/*
 * GvfsMount.vala
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
using TeeJee.GtkHelper;
using TeeJee.System;

public class GvfsMounts: GLib.Object {

	// static methods
	
	public static Gee.ArrayList<FileItem> get_mounts(int userid){

		string gvfs_root_path = "/run/user/%d/gvfs".printf(userid);
		
		var mounts = new Gee.ArrayList<FileItem>();

		log_debug("gvfs_root: %s".printf(gvfs_root_path));
		
		var gvfs = new FileItem.from_path(gvfs_root_path);
		
		gvfs.query_children(1);
		
		foreach(var child in gvfs.children.values){
			
			map_display_name(child);
			mounts.add(child);

			log_debug("");
			log_debug("found_gvfs: %s".printf(child.display_name));
			log_debug("child.file_name: %s".printf(child.file_name));
			log_debug("child.file_location: %s".printf(child.file_location));
			log_debug("child.display_name: %s".printf(child.display_name));
		}

		mounts.sort((a,b)=>{ return strcmp(a.display_name,b.display_name); });

		return mounts;
	}

	public static void map_display_name(FileItem item){

		//log_debug("item.file_name: %s".printf(item.file_name));

		//mtp:host=%5Busb%3A002%2C010%5D
		//mtp:host=[usb:002,010]
		var info = regex_match("""^mtp:host=(\[usb:[0-9]+,[0-9]+\])""", uri_decode(item.file_name));
		if (info != null){
			item.display_name = "mtp:%s".printf(info.fetch(1));
			return;
		}

		//ftp:host=192.168.43.140,port=3721
		info = regex_match("""^ftp:host=([0-9.]+),port=([0-9.]+)""", uri_decode(item.file_name));
		if (info != null){
			item.display_name = "ftp:%s:%s".printf(info.fetch(1), info.fetch(2));
			return;
		}
		
		item.display_name = uri_decode(item.file_name);

		//item.is_gvfs = true;
		
		// set some properties to be passed to children
		//item.gvfs_basepath = item.file_path;
		

		//FileItem.add_to_cache(item);
		
		/*var item = this.add_child_from_disk(trash_file, 0);

		item.trash_original_path = uri_decode(orig_path);

		if (item.trash_original_path.length > 0){
			item.display_name = file_basename(item.trash_original_path);
		}
		
		item.trash_item_name = item_name;
		item.trash_deletion_date = trash_date;
		item.trash_info_file = info_file;
		item.trash_data_file = trash_file;*/
	}
}


