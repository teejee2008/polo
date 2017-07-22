/*
 * SortMenu.vala
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

public class SortMenu : Gtk.Menu {

	// reference properties ----------

	protected MainWindow window {
		get { return App.main_window; }
	}
	
	protected FileViewPane pane;

	protected FileViewList view {
		get{ return pane.view; }
	}

	protected LayoutPanel panel {
		get { return pane.panel; }
	}

	// -------------------------------

	public SortMenu(FileViewPane parent_pane){

		log_debug("SortMenu()");

		pane = parent_pane;

		build_menu();

		log_debug("SortMenu(): exit");
	}

	public void build_menu(){
		
		Gtk.RadioMenuItem item_prev = null;
		
		foreach(var col in view.get_all_columns()){
			
			var col_index = col.get_data<FileViewColumn>("index");
			if (col_index == FileViewColumn.UNSORTABLE) { continue; }

			bool _active = (view.get_sort_column_index() == col_index);
			var submenu_item = add_sort_column_item(this, item_prev, col, _active);
			item_prev = submenu_item;
		}

		gtk_menu_add_separator(this);

		add_sort_desc_item(this);

		this.show_all();
	}
	
	private Gtk.RadioMenuItem add_sort_column_item(Gtk.Menu sub_menu, Gtk.RadioMenuItem? item_prev, Gtk.TreeViewColumn col, bool _active){

		string txt = (col.title.length > 0) ? col.title.replace("↓","").replace("↑","").strip() : _("Indicator");

		//log_debug("FileContextMenu: add option: %s".printf(txt));
			
		var submenu_item = gtk_menu_add_radio_item(
				sub_menu,
				txt,
				"",
				item_prev);

		var col_index = col.get_data<FileViewColumn>("index");
		submenu_item.set_data<FileViewColumn>("index", col_index);

		submenu_item.active = _active;
		
		submenu_item.toggled.connect(on_sort_column_menu_item_toggled);

		return submenu_item;
	}

	private Gtk.CheckMenuItem add_sort_desc_item(Gtk.Menu sub_menu){

		var menu_item = gtk_menu_add_check_item(
					sub_menu,
					_("Sort Descending"),
					"");

		menu_item.active = view.get_sort_column_desc();

		menu_item.toggled.connect(on_sort_desc_menu_item_toggled);

		return menu_item;
	}

	private void on_sort_column_menu_item_toggled(Gtk.CheckMenuItem menu_item){
		if (!menu_item.active){ return; }
		log_debug("FileContextMenu: sort column: %s".printf(menu_item.label));
		var col_index = menu_item.get_data<FileViewColumn>("index");
		view.set_sort_column_by_index(col_index);
	}

	private void on_sort_desc_menu_item_toggled(Gtk.CheckMenuItem menu_item){
		log_debug("FileContextMenu: sort desc: %s".printf(menu_item.active.to_string()));
		view.set_sort_column_desc(menu_item.active);
	}
}


