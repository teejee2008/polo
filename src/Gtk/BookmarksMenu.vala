/*
 * BookmarksMenu.vala
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

public class BookmarksMenu : Gtk.Menu, IPaneActive {

	public BookmarksMenu(){

		reserve_toggle_size = false;
		
		build_menu();
	}

	public void build_menu(){

		log_debug("BookmarksMenu: build_menu()");
		
		// menu_item
		var menu_item = new Gtk.MenuItem();
		this.append(menu_item);

		var box = new Gtk.Box(Orientation.HORIZONTAL, 3);
		menu_item.add(box);

		if (view.current_item != null){
			
			var path = view.current_item.file_path;
			var uri =  view.current_item.file_uri;
			
			if (GtkBookmark.is_bookmarked(uri)){
				var lbl = new Gtk.Label(_("Remove Bookmark"));
				lbl.xalign = 0.0f;
				lbl.margin_right = 6;
				box.add(lbl);

				menu_item.activate.connect (() => {
					if ((path != "/") && (path != App.user_home)){
						GtkBookmark.remove_bookmark(uri);
						window.sidebar.refresh();
					}
				});
			}
			else{
				var lbl = new Gtk.Label(_("Add Bookmark"));
				lbl.xalign = 0.0f;
				lbl.margin_right = 6;
				box.add(lbl);

				menu_item.activate.connect (() => {
					if (!GtkBookmark.is_bookmarked(uri)
						&& (path != "/")
						&& (path != App.user_home)){

						GtkBookmark.add_bookmark(uri);
						window.sidebar.refresh();
					}
				});
			}
		}

		gtk_menu_add_separator(this);

		add_bookmark(new GtkBookmark("file:///", "Filesystem"));
		add_bookmark(new GtkBookmark("file://" + App.user_home, "Home"));
		add_bookmark(new GtkBookmark("file://" + path_combine(App.user_home,"Desktop"), "Desktop"));
		add_bookmark(new GtkBookmark("trash:///", "Trash"));

		gtk_menu_add_separator(this);

		foreach(var bm in GtkBookmark.bookmarks){
			add_bookmark(bm);
		}

		this.show_all();
	}

	private void add_bookmark(GtkBookmark bm){

		// menu_item
		var menu_item = new Gtk.MenuItem();
		this.append(menu_item);

		var box = new Gtk.Box(Orientation.HORIZONTAL, 3);
		menu_item.add(box);

		var image = new Gtk.Image();
		image.pixbuf = bm.get_icon();
		box.add(image);

		// name and label

		var label = new Gtk.Label(bm.name);
		label.xalign = 0.0f;
		label.margin_right = 6;
		label.set_tooltip_text(bm.path);
		box.add(label);

		// check if path exists

		menu_item.sensitive = bm.exists();
		if (!menu_item.sensitive){
			label.set_tooltip_text(_("Path not found") + ": %s".printf(bm.path));
		}

		// navigate to path on click

		menu_item.activate.connect (() => {
			log_debug("bookmark_navigate: %s".printf(bm.path));
			view.set_view_path(bm.path);
			//sidebar.refresh();
		});

		// TODO: Allow user to edit bookmark name
	}

	public bool show_menu(Gdk.EventButton? event) {

		if (event != null) {
			this.popup (null, null, null, event.button, event.time);
		}
		else {
			this.popup (null, null, null, 0, Gtk.get_current_event_time());
		}

		return true;
	}

	public void hide_menu() {
		this.popdown();
	}
}


