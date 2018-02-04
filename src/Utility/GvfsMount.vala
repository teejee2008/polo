
/*
 * GvfsMount.vala
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

using TeeJee.Logging;
using TeeJee.FileSystem;
using TeeJee.ProcessHelper;
using TeeJee.Misc;
using TeeJee.GtkHelper;
using TeeJee.System;

public class GvfsMounts: GLib.Object {

	public static Gee.HashMap<string,FileItem> map;

	// static methods
	
	public static Gee.ArrayList<FileItem> get_mounts(int userid){

		map = new Gee.HashMap<string,FileItem>();

		string gvfs_root_path = "/run/user/%d/gvfs".printf(userid);
		
		var mounts = new Gee.ArrayList<FileItem>();

		log_debug("gvfs_root: %s".printf(gvfs_root_path));
		
		var gvfs = new FileItem.from_path(gvfs_root_path);
		
		gvfs.query_children(1, false);
		
		foreach(var child in gvfs.children.values){
			
			map_display_name(child);
			mounts.add(child);

			map[child.file_path] = child;

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

		string file_name_decoded = uri_decode(item.file_name);
		
		//mtp:host=%5Busb%3A002%2C010%5D
		//mtp:host=[usb:002,010]
		var info = regex_match("""^mtp:host=(\[usb:[0-9]+,[0-9]+\])""", file_name_decoded);
		if (info != null){
			item.display_name = "mtp:%s".printf(info.fetch(1));
			return;
		}

		//ftp:host=192.168.43.140,port=3721
		info = regex_match("""^(ftp|sftp|ssh):host=([0-9.]+),port=([0-9.]+)""", file_name_decoded);
		if (info != null){
			item.display_name = "%s://%s:%s".printf(info.fetch(1), info.fetch(2), info.fetch(3));
			return;
		}

		//smb-share:server=cp8676,share=storage
		info = regex_match("""^smb-share:server=(.*),share=(.*)""", file_name_decoded);
		if (info != null){
			item.display_name = "smb://%s/%s".printf(info.fetch(1), info.fetch(2));
			return;
		}
		
		item.display_name = file_name_decoded;
	}

	public static bool is_gvfs_uri(string uri){
		var match = regex_match("""^(file|trash|computer|network|recent|mtp|ftp|sftp|ssh|smb):\/\/""", uri);
		return (match != null);
	}
	
	public static string get_gvfs_basepath(string file_uri){

		//file:///home/user
		//trash:///sss
		var info = regex_match("""^((file|trash):\/\/\/*)""", file_uri);
		if (info != null){
			return info.fetch(1);
		}

		//ftp://user:password@192.168.43.140:3721/sss
		info = regex_match("""^((ftp|sftp|ssh):*\/*\/*.*[0-9.]*:*[0-9.]*\/*)""", file_uri);
		if (info != null){
			return info.fetch(1);
		}

		//mtp://[usb:002,010]/sss
		info = regex_match("""^(mtp:\/\/\[usb:[0-9]+,[0-9]+\]\/*)""", file_uri);
		if (info != null){
			return info.fetch(1);
		}

		//smb://DATA/share1
		info = regex_match("""^(smb:\/\/.*\/*.*)""", file_uri);
		if (info != null){
			return info.fetch(1);
		}
		
		if (file_uri.has_prefix("/")){
			return "/";
		}
		else{
			return file_uri.split("/")[0];
		}
	}

	public static FileItem? find_by_uri(string uri){
		
		foreach(var item in GvfsMounts.get_mounts(App.user_id)){
			log_debug("item: %s".printf(item.file_uri));
			if (item.file_uri.down() == uri.down()){
				return item;
			}
		}
		return null;
	}

	public static bool mount(string file_uri, string smb_domain, string smb_username, string smb_password){

		if (file_uri.has_prefix("smb://")){
			return gvfs_mount_samba(file_uri, smb_domain, smb_username, smb_password);
		}
		else{
			return gvfs_mount(file_uri, false);
		}
	}

	private static bool gvfs_mount(string file_uri, bool unmount){

		string std_out, std_err;

		string cmd = "gvfs-mount";
		if (unmount){
			cmd += " -u";
		}
		cmd += " '%s'".printf(escape_single_quote(file_uri));

		log_debug(cmd);
		
		int status = exec_sync(cmd, out std_out, out std_err);

		if (std_err.length > 0){
			log_error(std_err);
		}
		
		return (status == 0) && (std_err.strip().length == 0);
	}

	private static bool gvfs_mount_samba(string file_uri, string smb_username, string smb_domain, string smb_password){
		
		string sh = "";
		sh += "echo '%s' >> samba.props \n".printf(escape_single_quote(smb_username));
		sh += "echo '%s' >> samba.props \n".printf(escape_single_quote(smb_domain));
		sh += "echo '%s' >> samba.props \n".printf(escape_single_quote(smb_password));

		string cmd = "gvfs-mount '%s' < ./samba.props".printf(escape_single_quote(file_uri));
		sh += cmd + "\n";
		log_debug(cmd);
		
		string std_out, std_err;
		int status = exec_script_sync(sh, out std_out, out std_err);

		if (std_err.length > 0){
			log_error(std_err);
		}
		
		return (status == 0) && (std_err.strip().length == 0);
	}
	
	public static bool unmount(string file_uri){
		
		string std_out, std_err;

		string cmd = "gvfs-mount -u '%s'".printf(escape_single_quote(file_uri));

		log_debug(cmd);
		
		int status = exec_sync(cmd, out std_out, out std_err);

		if (std_err.length > 0){
			log_error(std_err);
		}
		
		return (status == 0) && (std_err.strip().length == 0);
	}

}


