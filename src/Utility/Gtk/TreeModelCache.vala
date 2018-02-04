
/*
 * TreeModelCache.vala
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


public class TreeModelCache : GLib.Object {
	
	public Gtk.TreeStore model = null;
	public FileItem file_item = null;
	private int icon_size;
	private DateTime timestamp;

	private static Gee.ArrayList<TreeModelCache> cache;
	private static bool enabled = false;
	
	public static void add(FileItem _file_item, Gtk.TreeStore _model, int _icon_size){

		if (!enabled){ return; }

		var existing = find_cache_item(_file_item.file_path, _icon_size);
		
		if (existing != null){
			existing.model = _model;
			existing.file_item = _file_item;
			existing.timestamp = new DateTime.now_local();
		}
		else{
			var item = new TreeModelCache();
			item.file_item = _file_item;
			item.model = _model;
			item.icon_size = _icon_size;
			item.timestamp = new DateTime.now_local();
			cache.add(item);
		}
	}

	public static TreeModelCache? find_cache_item(string _path, int _icon_size){

		if (!enabled){ return null; }
		
		var now = new DateTime.now_local();

		int i = 0;
		
		while (i < cache.size){
			
			var item = cache[i];

			if (now.difference(item.timestamp) < (1 * TimeSpan.SECOND)){
				if ((item.file_item.file_path == _path) && (item.icon_size == _icon_size)){
					return item;
				}
				else{
					i++;
				}
			}
			else{
				cache.remove(item);
			}
		}

		return null;
	}
	
	public static Gtk.TreeStore? find_model(string _path, int _icon_size){

		if (!enabled){ return null; }
		
		var now = new DateTime.now_local();

		int i = 0;
		
		while (i < cache.size){
			
			var item = cache[i];

			if (now.difference(item.timestamp) < (1 * TimeSpan.SECOND)){
				if ((item.file_item.file_path == _path) && (item.icon_size == _icon_size)){
					return item.model;
				}
				else{
					i++;
				}
			}
			else{
				cache.remove(item);
			}
		}

		return null;
	}

	public static FileItem? find_file_item(string _path){

		if (!enabled){ return null; }
		
		var now = new DateTime.now_local();

		int i = 0;
		
		while (i < cache.size){
			
			var item = cache[i];

			if (now.difference(item.timestamp) < (1 * TimeSpan.SECOND)){
				if (item.file_item.file_path == _path){
					return item.file_item;
				}
				else{
					i++;
				}
			}
			else{
				cache.remove(item);
			}
		}

		return null;
	}

	public static void enable(){
		enabled = true;
		cache = new Gee.ArrayList<TreeModelCache>();
	}

	public static void disable(){
		enabled = false;
		cache = new Gee.ArrayList<TreeModelCache>();
	}
}



