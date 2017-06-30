
/*
 * IconCache.vala
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

public class IconCache : GLib.Object {
	
	public Gtk.TreeStore model = null;
	public FileItem file_item = null;

	private static Gee.HashMap<string,Gdk.Pixbuf> cache = new Gee.HashMap<string,Gdk.Pixbuf>();
	private static bool enabled = true;

	public static void add(string key, Gdk.Pixbuf pixbuf){

		if (!enabled){ return; }

		if (!cache.has_key(key)){
			cache[key] = pixbuf;
		}
	}

	public static Gdk.Pixbuf? lookup(string key){

		if (!enabled){ return null; }
		
		if (cache.has_key(key)){
			//log_debug("in cache: %s".printf(key));
			return cache[key];
		}
		else{
			//log_debug("not in cache: %s".printf(key));
		}

		return null;
	}


	public static void add_icon_fileitem(Gdk.Pixbuf pixbuf, string file_path, DateTime? changed, int icon_size,
		bool load_thumbnail, bool add_transparency, bool add_emblems){

		if (!enabled){ return; }

		string key = icon_key_fileitem(file_path, changed, icon_size, load_thumbnail, add_transparency, add_emblems);
		add(key, pixbuf);
	}

	public static Gdk.Pixbuf? lookup_icon_fileitem(string file_path, DateTime? changed, int icon_size,
		bool load_thumbnail, bool add_transparency, bool add_emblems){
	
		if (!enabled){ return null; }

		string key = icon_key_fileitem(file_path, changed, icon_size, load_thumbnail, add_transparency, add_emblems);
		return lookup(key);
	}

	public static string icon_key_fileitem(string file_path, DateTime? changed, int icon_size,
		bool load_thumbnail, bool add_transparency, bool add_emblems){

		string txt = "";
		txt += file_path;
		txt += (changed == null) ? "" : changed.to_string();
		txt += icon_size.to_string();
		txt += load_thumbnail ? "1" : "0";
		txt += add_transparency ? "1" : "0";
		txt += add_emblems ? "1" : "0";
		return txt;
	}
	
	public static void enable(){
		enabled = true;
		cache = new Gee.HashMap<string,Gdk.Pixbuf>();
	}

	public static void disable(){
		enabled = false;
		cache = new Gee.HashMap<string,Gdk.Pixbuf>();
	}
}



