/*
 * BookmarkContextMenu.vala
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


using Gtk;
using Gee;

using TeeJee.Logging;
using TeeJee.FileSystem;
using TeeJee.JsonHelper;
using TeeJee.ProcessHelper;
using TeeJee.GtkHelper;
using TeeJee.System;
using TeeJee.Misc;

public class BookmarkContextMenu : Gtk.Menu, IPaneActive {

	private Gtk.SizeGroup sg_icon;
	private Gtk.SizeGroup sg_label;

	private GtkBookmark bm;
	private Gtk.Entry entry;
	private Gtk.Box label_box;
	private Gtk.ListBoxRow row;
	private Gtk.ListBox listbox;
	
	public BookmarkContextMenu(GtkBookmark _bm, Gtk.Entry _entry, Gtk.Box _label_box, Gtk.ListBoxRow _row, Gtk.ListBox _listbox){
		
		margin = 0;

		log_debug("BookmarkContextMenu()");

		bm = _bm;
		entry = _entry;
		label_box = _label_box;
		row = _row;
		listbox = _listbox;

		build_menu();
	}

	private void build_menu(){

		log_debug("BookmarkContextMenu: build_menu()");

		Gdk.RGBA gray = Gdk.RGBA();
		gray.parse("rgba(200,200,200,1)");

		this.reserve_toggle_size = false;

		sg_icon = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);
		sg_label = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);
		
		add_edit();

		add_remove();

		show_all();
	}

	private void add_edit(){

		log_debug("BookmarkContextMenu: add_edit()");

		// item ------------------

		var item = gtk_menu_add_item(
			this,
			_("Rename"),
			"",
			null,
			sg_icon,
			sg_label);

		item.activate.connect (() => {
			entry.text = bm.name;
			entry.select_region(0, entry.text.length);
			gtk_hide(label_box);
			gtk_show(entry);
		});

		item.sensitive = bm.exists();
	}

	private void add_remove(){

		log_debug("BookmarkContextMenu: add_remove()");

		// item ------------------

		var item = gtk_menu_add_item(
			this,
			_("Remove"),
			"",
			null,
			sg_icon,
			sg_label);

		item.activate.connect (() => {
			listbox.remove(row);
			GtkBookmark.remove_bookmark(bm.uri);
		});

		item.sensitive = true; // always allowed
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
}
