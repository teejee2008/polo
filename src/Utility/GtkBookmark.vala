
/*
 * GtkBookmark.vala
 *
 * Copyright 2017 Tony George <teejee2008@gmail.com>
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

public class GtkBookmark : GLib.Object {
	
	public string uri = "";
	public string name = "";

	public static string user_name;
	public static string user_home;
	
	public static Gee.ArrayList<GtkBookmark> bookmarks = new Gee.ArrayList<GtkBookmark>();

	private static const string config_path_gtk_template = "%s/.config/gtk-3.0/bookmarks";
	private static const string config_path_custom_template = "%s/.config/%s-bookmarks";
	private static string config_file;
	private static bool use_config_file_custom;
	
	// properties
	
	public string path {
		owned get{
			return uri_decode(uri.replace("file://",""));
		}
	}

	// constructors
	
	public GtkBookmark(string _uri, string _name = ""){
		uri = _uri;
		name = (_name.length > 0) ? _name : file_basename(_uri);
	}

	// static methods
	
	public static void load_bookmarks(string _user_name, bool use_gtk_bookmarks){

		user_name = _user_name;
		user_home = get_user_home(user_name);

		if (use_gtk_bookmarks){
			config_file = config_path_gtk_template.printf(user_home);
		}
		else{
			config_file = config_path_custom_template.printf(user_home, AppShortName);
		}

		bookmarks = new Gee.ArrayList<GtkBookmark>();
		
		if (file_exists(config_file)){
			
			log_debug("Reading bookmarks: %s".printf(config_file));
			
			foreach(var line in file_read(config_file).split("\n")){
			
				string[] parts = line.split(" ");

				if (parts.length == 0) { continue; }
				
				string bm_uri = "";
				string bm_name = "";
				for(int i = 0; i < parts.length; i++){
					if (i == 0){
						bm_uri = parts[i];
					}
					else{
						bm_name += parts[i];
					}
				}

				var bm = new GtkBookmark(bm_uri, bm_name);
				bookmarks.add(bm);
				//log_debug("Read bookmark: %s".printf(bm.uri));
			}
		}
		else{
			log_error(_("File not found") + ": %s".printf(config_file));
		}
	}

	public static void save_bookmarks(){

		// never save empty bookmark file
		if (bookmarks.size == 0){ return; }
		
		file_delete(config_file);

		string text = "";
		foreach(var bm in bookmarks){
			if (bm.uri.strip().length > 0){
				text += "%s %s\n".printf(bm.uri, bm.name);
			}
		}
		file_write(config_file, text);
	}

	public static void add_bookmark_from_path(string location){

		foreach(var bm in bookmarks){
			if (bm.path == location){
				return; // already exists
			}
		}

		if (is_bookmarked(location)){
			return; 
		}
		
		var bm = new GtkBookmark("file://" + uri_encode(location, false));
		bookmarks.add(bm);
		save_bookmarks();
	}

	public static void remove_bookmark_by_path(string location){

		if ((location == null) || (location.strip().length == 0)){
			return; 
		}
		
		GtkBookmark bm_remove = null;
		foreach(var bm in bookmarks){
			if (bm.path == location){
				bm_remove = bm;
				break;
			}
		}

		if (bm_remove != null){
			bookmarks.remove(bm_remove);
			save_bookmarks();
		}
	}

	public static bool is_bookmarked(string location){

		if ((location == null) || (location.strip().length == 0)){
			return true; 
		}
		
		foreach(var bm in bookmarks){
			if (bm.path == location){
				return true;
			}
		}

		return false;
	}
	
	// instance methods

	public bool path_exists(){
		return file_or_dir_exists(uri);
	}

	public Gdk.Pixbuf? get_icon(int icon_size = 16){
		if (path_exists()){
			if (uri == "trash:///"){
				return IconManager.lookup("user-trash",16);
			}
			else{
				var item = new FileItem.from_path(uri);
				return item.get_icon(icon_size, true, false);
			}
		}
		else{
			return IconManager.generic_icon_directory(icon_size);
		}
	}
}


