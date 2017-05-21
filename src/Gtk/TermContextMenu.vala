/*
 * TermContextMenu.vala
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

public class TermContextMenu : Gtk.Menu {

	private Gee.ArrayList<FileItem> selected_items;
	private FileItem? selected_item = null;
	private bool is_trash = false;
	private bool is_archive = false;

	// parents
	public FileViewList view;
	public FileViewPane pane;
	public MainWindow window;

	public TermContextMenu(FileViewPane parent_pane){
		
		log_debug("TermContextMenu()");

		margin = 0;

		pane = parent_pane;
		view = pane.view;
		window = App.main_window;

		build_menu();
	}

	// file context menu

	private void build_menu(){

		log_debug("TermContextMenu: build_menu()");

		this.reserve_toggle_size = false;

		var sg_icon = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);
		var sg_label = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);

		selected_items = view.get_selected_items();
		if (selected_items.size > 0){
			selected_item = selected_items[0];
		}

		add_change_directory(this, sg_icon, sg_label);

		add_clear_output(this, sg_icon, sg_label);

		gtk_menu_add_separator(this); //---------------------------

		add_maximize(this, sg_icon, sg_label);

		add_minimize(this, sg_icon, sg_label);
				
		show_all();
	}

	private void add_change_directory(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){

		log_debug("TermContextMenu: add_change_directory()");

		if (!view.is_normal_directory || (view.current_item == null)) { return; }
		
		var menu_item = gtk_menu_add_item(
			menu,
			_("Change Directory"),
			_("Change directory to current path"),
			IconManager.lookup_image("folder", 16),
			sg_icon,
			sg_label);

		menu_item.activate.connect (() => {
			pane.terminal.change_directory(view.current_item.file_path);
		});

		menu_item.sensitive = view.is_normal_directory;
	}
	
	private void add_clear_output(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){

		log_debug("TermContextMenu: add_clear_output()");

		var menu_item = gtk_menu_add_item(
			menu,
			_("Clear"),
			_("Clear the terminal output"),
			IconManager.lookup_image("edit-clear", 16),
			sg_icon,
			sg_label);

		menu_item.activate.connect (() => {
			pane.terminal.clear_output();
		});

		menu_item.sensitive = true;
	}

	
	private void add_maximize(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){

		log_debug("TermContextMenu: add_maximize()");

		var menu_item = gtk_menu_add_item(
			menu,
			_("Maximize"),
			_("Maximize the terminal to fill tab"),
			null,//IconManager.lookup_image("", 16),
			sg_icon,
			sg_label);

		menu_item.activate.connect (() => {
			pane.maximize_terminal();
		});

		menu_item.sensitive = true;
	}

	private void add_minimize(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){

		log_debug("TermContextMenu: add_maximize()");

		var menu_item = gtk_menu_add_item(
			menu,
			_("UnMaximize"),
			_("UnMaximize the terminal"),
			null,//IconManager.lookup_image("edit-clear", 16),
			sg_icon,
			sg_label);

		menu_item.activate.connect (() => {
			pane.unmaximize_terminal();
		});

		menu_item.sensitive = true;
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
