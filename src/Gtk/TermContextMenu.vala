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
	
	private Gee.ArrayList<FileItem> selected_items;
	private FileItem? selected_item = null;
	private bool is_trash = false;
	private bool is_archive = false;

	public TermContextMenu(FileViewPane parent_pane){
		
		log_debug("TermContextMenu()");

		margin = 0;

		pane = parent_pane;

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

		add_copy(this, sg_icon, sg_label);

		add_paste(this, sg_icon, sg_label);

		gtk_menu_add_separator(this); //---------------------------

		add_change_directory(this, sg_icon, sg_label);
		
		add_clear_output(this, sg_icon, sg_label);

		add_chroot(this, sg_icon, sg_label);

		gtk_menu_add_separator(this); //---------------------------

		add_maximize(this, sg_icon, sg_label);

		add_minimize(this, sg_icon, sg_label);

		gtk_menu_add_separator(this); //---------------------------

		add_settings(this, sg_icon, sg_label);
				
		show_all();
	}

	private void add_copy(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){

		log_debug("TermContextMenu: add_copy()");

		var menu_item = gtk_menu_add_item(
			menu,
			_("Copy"),
			_("Copy selected text to clipboard"),
			IconManager.lookup_image("edit-copy", 16),
			sg_icon,
			sg_label);

		menu_item.activate.connect (() => {
			pane.terminal.copy();
		});

		menu_item.sensitive = true;
	}

	private void add_paste(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){

		log_debug("TermContextMenu: add_change_directory()");

		if (!view.is_normal_directory || (view.current_item == null)) { return; }
		
		var menu_item = gtk_menu_add_item(
			menu,
			_("Paste"),
			_("Paste clipboard contents"),
			IconManager.lookup_image("edit-paste", 16),
			sg_icon,
			sg_label);

		menu_item.activate.connect (() => {
			pane.terminal.paste();
		});

		menu_item.sensitive = true;
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
			_("Reset and clear"),
			_("Clear the terminal output"),
			IconManager.lookup_image("edit-clear", 16),
			sg_icon,
			sg_label);

		menu_item.activate.connect (() => {
			pane.terminal.reset();
		});

		menu_item.sensitive = true;
	}

	private void add_chroot(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){

		log_debug("TermContextMenu: add_chroot()");

		var menu_item = gtk_menu_add_item(
			menu,
			_("Chroot"),
			"",
			null,
			sg_icon,
			sg_label);

		menu_item.sensitive = view.is_normal_directory && (view.current_item != null) && view.current_item.is_sys_root;

		if (!view.is_normal_directory || (view.current_item == null)) { return; }
		
		menu_item.activate.connect(()=>{
			pane.terminal.chroot(view.current_item.file_path);
		});
	}

	//-------------
	
	private void add_settings(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){

		log_debug("TermContextMenu: add_settings()");

		var menu_item = gtk_menu_add_item(
			menu,
			_("Settings"),
			"",
			null,
			sg_icon,
			sg_label);

		var sub_menu = new Gtk.Menu();
		menu_item.set_submenu(sub_menu);

		sub_menu.reserve_toggle_size = false;

		var sg_icon_sub = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);
		var sg_label_sub = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);

		add_font(sub_menu, sg_icon_sub, sg_label_sub);
		
		add_foreground_color(sub_menu, sg_icon_sub, sg_label_sub);
		
		add_background_color(sub_menu, sg_icon_sub, sg_label_sub);

		gtk_menu_add_separator(sub_menu); //---------------------------
		
		add_set_defaults(sub_menu, sg_icon_sub, sg_label_sub);

		add_fish_config(sub_menu, sg_icon_sub, sg_label_sub);
	}
	
	private void add_font(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){

		log_debug("TermContextMenu: add_font()");

		var menu_item = gtk_menu_add_item(
			menu,
			_("Font"),
			"",
			IconManager.lookup_image("font-x-generic",16),
			sg_icon,
			sg_label);
			
		menu_item.activate.connect(()=>{

			var dlg = new Gtk.FontChooserDialog(_("Select Font"), window);

			dlg.set_filter_func ((family, face)=>{
				return family.is_monospace()
				&& (face.describe().get_style() == Pango.Style.NORMAL)
				&& (face.describe().get_weight() == Pango.Weight.NORMAL);
			});

			dlg.set_font_desc(App.term_font);
			
			if (dlg.run() == Gtk.ResponseType.OK){
				
				App.term_font = dlg.get_font_desc();
				foreach(var term in window.terminals){
					term.set_font_desc(App.term_font);
				}
			}

			dlg.destroy();
		});
	}

	private void add_foreground_color(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){

		log_debug("TermContextMenu: add_foreground_color()");

		var menu_item = gtk_menu_add_item(
			menu,
			_("Foreground Color"),
			"",
			IconManager.lookup_image("preferences-color",16),
			sg_icon,
			sg_label);

		menu_item.activate.connect(()=>{

			var color = choose_color(App.term_fg_color);

			if (color.length == 0){ return; }
			
			App.term_fg_color = color;

			foreach(var term in window.terminals){
				term.set_color_foreground(App.term_fg_color);
			}
		});
	}

	private void add_background_color(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){

		log_debug("TermContextMenu: add_background_color()");

		var menu_item = gtk_menu_add_item(
			menu,
			_("Background Color"),
			"",
			IconManager.lookup_image("preferences-color",16),
			sg_icon,
			sg_label);

		menu_item.activate.connect(()=>{

			var color = choose_color(App.term_bg_color);

			if (color.length == 0){ return; }
			
			App.term_bg_color = color;

			foreach(var term in window.terminals){
				term.set_color_background(App.term_bg_color);
			}
			
		});
	}

	private string choose_color(string default_color){
		
		var dlg = new Gtk.ColorChooserDialog ("Select Color", window);

		var default_rgba = Gdk.RGBA();
		default_rgba.parse(default_color);
		dlg.set_rgba(default_rgba);

		string color_hex = "";
		
		if (dlg.run() == Gtk.ResponseType.OK) {
			
			string alpha = dlg.use_alpha.to_string();
			string col = dlg.rgba.to_string();
			
			color_hex = rgba_to_hex(dlg.rgba, false, true);

			log_debug("selected: %s".printf(color_hex));
		}
		
		dlg.close();

		return color_hex;
	}

	private void add_set_defaults(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){

		log_debug("TermContextMenu: add_foreground_color()");

		var menu_item = gtk_menu_add_item(
			menu,
			_("Reset"),
			"",
			IconManager.lookup_image("edit-undo",16),
			sg_icon,
			sg_label);

		menu_item.activate.connect(()=>{

			App.term_font = Pango.FontDescription.from_string(Main.TERM_FONT_DESC);
			App.term_fg_color = TermBox.DEF_COLOR_FG;
			App.term_bg_color = TermBox.DEF_COLOR_BG;

			foreach(var term in window.terminals){
				term.set_defaults();
			}
		});
	}

	private void add_fish_config(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){

		log_debug("TermContextMenu: add_fish_config()");

		var menu_item = gtk_menu_add_item(
			menu,
			_("Fish Config"),
			"",
			IconManager.lookup_image("preferences-system", 16),
			sg_icon,
			sg_label);

		menu_item.activate.connect (() => {
			pane.terminal.open_settings();
		});
	}

	// ---------------
	
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
