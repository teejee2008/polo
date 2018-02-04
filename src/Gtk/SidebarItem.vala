/*
 * SidebarItem.vala
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


using Gtk;
using Gee;

using TeeJee.Logging;
using TeeJee.FileSystem;
using TeeJee.JsonHelper;
using TeeJee.ProcessHelper;
using TeeJee.GtkHelper;
using TeeJee.System;
using TeeJee.Misc;

public enum SidebarItemType{
	HEADER_LOCATIONS,
	HEADER_BOOKMARKS,
	HEADER_DEVICES,
	HEADER_DISK,
	BOOKMARK,
	BOOKMARK_ACTION_ADD,
	BOOKMARK_ACTION_REMOVE,
	DEVICE,
	TRASH
}

public class SidebarItem : GLib.Object {
	
	public string name = "";
	public string tooltip = "";
	public string node_key = "";
	public SidebarItemType type;

	public GtkBookmark bookmark;
	public Device device;

	private SidebarItem(){
		// make default constructor private
	}

	public SidebarItem.from_bookmark(GtkBookmark _bookmark){
		
		type = SidebarItemType.BOOKMARK;
		bookmark = _bookmark;

		name = ellipsize(bookmark.name, 30);
		tooltip = bookmark.path;
	}

	public SidebarItem.from_device(Device _dev, bool show_device_file_name){
		
		type = SidebarItemType.DEVICE;
		device = _dev;

		name = device.name;
		tooltip = device.tooltip_text();

		if (device.pkname.length == 0){
			
			name = device.description_simple(show_device_file_name);
			type = SidebarItemType.HEADER_DISK;
			node_key = device.kname;
		}
		else{
			
			name = device.kname;
			
			if (device.is_on_encrypted_partition){
				//name = "%s%s".printf(device.pkname, _(" (unlocked)"));
				name = "%s".printf(device.pkname);
			}
			else if (device.is_encrypted_partition){
				//name = "%s%s".printf(device.kname, _(" (locked)"));
				name = "%s".printf(device.kname);
			}

			if (device.label.length > 0){
				name += " (%s)".printf(device.label);
			}
		}
	}

	public SidebarItem.for_header(string _name, SidebarItemType _type){
		type = _type;
		name = _name;
		//tooltip = bookmark.path;
		node_key = name.down();
	}

	public SidebarItem.bookmark_action(string _name, SidebarItemType _type){
		type = _type;
		name = _name;
		//tooltip = bookmark.path;
		//node_key = name.down();
	}

	public Gdk.Pixbuf? get_icon(){
		if (type == SidebarItemType.BOOKMARK){
			return bookmark.get_icon();
		}
		else{
			return IconManager.generic_icon_directory(16);
		}
	}
}




