
/*
 * GtkBookmark.vala
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

public class GtkBookmark : GLib.Object {
	
	public string uri = "";
	public string name = "";

	private string _path = "";
	public string path {
		owned get{
			if (_path.length > 0){ return _path; }
			var file = File.new_for_uri(uri);
			_path = file.get_path();
			if (_path == null){ _path = ""; }
			return _path;
		}
	}

	public static string user_name;
	public static string user_home;
	
	public static Gee.ArrayList<GtkBookmark> bookmarks = new Gee.ArrayList<GtkBookmark>();

	private const string gtk_template = "%s/.config/gtk-3.0/bookmarks";
	private const string custom_template = "%s/.config/%s-bookmarks";
	private static string config_file;
	
	// constructors
	
	public GtkBookmark(string _uri, string _name = ""){
		uri = _uri;

		if (path != null){
			name = "%s".printf((_name.length > 0) ? _name : file_basename(path));
		}
		else{
			name = "%s".printf((_name.length > 0) ? _name : file_basename(uri));
		}
	}

	// static methods
	
	public static void load_bookmarks(string _user_name, bool use_gtk_bookmarks){

		user_name = _user_name;
		user_home = get_user_home(user_name);

		if (use_gtk_bookmarks){
			config_file = gtk_template.printf(user_home);
		}
		else{
			config_file = custom_template.printf(user_home, AppShortName);
		}

		bookmarks = new Gee.ArrayList<GtkBookmark>();
		
		if (file_exists(config_file)){
			
			log_debug("Reading bookmarks: %s".printf(config_file));

			// sample:
			// file:///path/to/folder Bookmark name with spaces
			
			foreach(var line in file_read(config_file).split("\n")){
			
				string[] parts = line.split(" ");

				if (parts.length == 0) { continue; }
				
				string bm_uri = "";
				string bm_name = "";
				for(int i = 0; i < parts.length; i++){
					if (i == 0){
						bm_uri = parts[i]; // first part is the uri
					}
					else{
						if (bm_name.length > 0) { bm_name += " "; }
						bm_name += parts[i];
					}
				}

				if (bm_name.length == 0){
					bm_name = file_basename(bm_uri);
					//bm_name = uri_decode(bm_name); // it's not encoded
				}

				var bm = new GtkBookmark(bm_uri, bm_name);
				bookmarks.add(bm);
				log_debug("Bookmark: uri: %s, name: %s".printf(bm.uri, bm.name));
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

	public static void add_bookmark(string uri){

		foreach(var bm in bookmarks){
			if (bm.uri == uri){
				return; // already exists
			}
		}

		if (is_bookmarked(uri)){
			return; 
		}

		if (!uri.contains("://")){
			return;
		}
		
		var bm = new GtkBookmark(uri);
		bookmarks.add(bm);
		save_bookmarks();
	}

	public static void remove_bookmark(string uri){

		if ((uri == null) || (uri.strip().length == 0)){
			return; 
		}

		if (!uri.contains("://")){
			return;
		}
		
		GtkBookmark bm_remove = null;
		foreach(var bm in bookmarks){
			if (bm.uri == uri){
				bm_remove = bm;
				break;
			}
		}

		if (bm_remove != null){
			bookmarks.remove(bm_remove);
			save_bookmarks();
		}
	}

	public static bool is_bookmarked(string uri){

		if ((uri == null) || (uri.strip().length == 0)){
			return true; 
		}

		if (!uri.contains("://")){
			return false;
		}
		
		foreach(var bm in bookmarks){
			if (bm.uri == uri){
				return true;
			}
		}

		return false;
	}

	// instance methods

	public bool exists(){
		return uri_exists(uri);
	}

	public Gdk.Pixbuf? get_icon(int icon_size = 16){

		if (exists()){

			if (uri == "trash:///"){
				return IconManager.lookup("user-trash-symbolic",16);
			}
			else{
				//log_debug("", true);
				//log_debug("uri      : %s".printf(uri), true);
				var item = new FileItem.from_path(uri);
				//log_debug("file_path: %s".printf(item.file_path), true);
				//log_debug("file_uri : %s".printf(item.file_uri), true);
				return item.get_icon(icon_size, true, false);
			}
		}
		else{
			return IconManager.generic_icon_directory(icon_size);
		}
	}
}


