/*
 * MainMenubar.vala
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

public class MainMenuBar : Gtk.MenuBar, IPaneActive {

	private Gtk.Menu? menu = null;
	private bool menu_mode = false;
	private bool refreshed_once = false;
	private Gtk.CheckMenuItem chk_hidden;

	public signal void context_term();

	public signal void context_normal();

	public signal void context_trash();

	public signal void context_archive();

	public signal void context_edit();

	public signal void context_none();

	public signal void delayed_init();

	public signal void active_pane_changed();
	
	public MainMenuBar(bool _menu_mode){
		
		this.menu_mode = _menu_mode;
		
		if (menu_mode){
			this.menu = new Gtk.Menu();
		}

		Gtk.MenuShell menu_shell = this;
		if (menu_mode){
			menu_shell = menu;
		}

		gtk_container_remove_children(menu_shell);

		add_menu_file(menu_shell);
		add_menu_edit(menu_shell);
		add_menu_view(menu_shell);
		add_menu_go(menu_shell);
		add_menu_cloud(menu_shell);
		add_menu_tools(menu_shell);
		add_menu_help(menu_shell);
		
		menu_shell.show_all();
	}
	
	public Gtk.Menu? get_menu(){
		return menu;
	}

	public void add_action_accel(Gtk.MenuItem item, string keycode){

		string data_key = "has_accel_%s".printf(keycode);
		
		uint accel_key;
		Gdk.ModifierType accel_mods;
		var accel_flags = Gtk.AccelFlags.VISIBLE;
		Gtk.accelerator_parse(keycode, out accel_key, out accel_mods);
		item.add_accelerator ("activate", Hotkeys.accel_group, accel_key, accel_mods, accel_flags);

		item.set_data<int>(data_key, 1);
	}

	public void remove_action_accel(Gtk.MenuItem item, string keycode){

		string data_key = "has_accel_%s".printf(keycode);
		
		if (item.get_data<int>(data_key) != 1) { return; }
		
		uint accel_key;
		Gdk.ModifierType accel_mods;
		var accel_flags = Gtk.AccelFlags.VISIBLE;
		Gtk.accelerator_parse(keycode, out accel_key, out accel_mods);
		item.remove_accelerator (Hotkeys.accel_group, accel_key, accel_mods);
		
		item.set_data<int>(data_key, -1);
	}
	
	private void add_menu_file(Gtk.MenuShell menu_shell){

		log_debug("MainMenuBar: add_menu_file()");

		var item = new Gtk.MenuItem.with_label(_("File"));
		menu_shell.add(item);

		var submenu = new Gtk.Menu();
		item.set_submenu(submenu);

		add_new_tab(submenu);
		
		add_new_window(submenu);

		add_admin_window(submenu);

		gtk_menu_add_separator(submenu);

		add_new_folder(submenu);

		add_new_file(submenu);

		gtk_menu_add_separator(submenu);

		add_connect_to_server(submenu);

		gtk_menu_add_separator(submenu);

		add_terminal_window(submenu);

		gtk_menu_add_separator(submenu);

		add_exit(submenu);
		
		log_debug("MainMenuBar: add_menu_file(): exit");
	}

	private void add_new_tab(Gtk.Menu submenu){
		
		var item = new Gtk.MenuItem.with_label (_("New Tab"));
		submenu.add(item);

		item.activate.connect(panel_add_tab);

		string key = "<Control>t";

		context_normal.connect(()=>{
			item.sensitive = true;
			add_action_accel(item, key);
		});

		context_trash.connect(()=>{
			item.sensitive = true;
			add_action_accel(item, key);
		});

		context_archive.connect(()=>{
			item.sensitive = true;
			add_action_accel(item, key);
		});

		context_term.connect(()=>{
			//add_action_accel(item, key);
		});
		
		context_edit.connect(()=>{
			//add_action_accel(item, key);
		});

		context_none.connect(()=>{
			item.sensitive = false;
			remove_action_accel(item, key);
		});
	}

	private void panel_add_tab(){
		panel.add_tab();
	}

	private void add_new_window(Gtk.Menu submenu){
		
		var item = new Gtk.MenuItem.with_label (_("New Window"));
		submenu.add(item);

		item.activate.connect (() => {
			view.open_in_new_window();
		});

		string key = "<Control>n";

		context_normal.connect(()=>{
			item.sensitive = true;
			add_action_accel(item, key);
		});

		context_trash.connect(()=>{
			item.sensitive = true;
			add_action_accel(item, key);
		});

		context_archive.connect(()=>{
			item.sensitive = true;
			add_action_accel(item, key);
		});

		context_term.connect(()=>{
			//add_action_accel(item, key);
		});
		
		context_edit.connect(()=>{
			//add_action_accel(item, key);
		});

		context_none.connect(()=>{
			item.sensitive = false;
			remove_action_accel(item, key);
		});
	}

	private void add_admin_window(Gtk.Menu submenu){

		var item = new Gtk.MenuItem.with_label (_("New Admin Window"));
		submenu.add(item);

		item.activate.connect (() => {
			view.open_in_admin_window();
		});

		string key = "<Super>n";

		context_normal.connect(()=>{
			item.sensitive = true;
			add_action_accel(item, key);
		});

		context_trash.connect(()=>{
			item.sensitive = true;
			add_action_accel(item, key);
		});

		context_archive.connect(()=>{
			item.sensitive = true;
			add_action_accel(item, key);
		});

		context_term.connect(()=>{
			//add_action_accel(item, key);
		});
		
		context_edit.connect(()=>{
			//add_action_accel(item, key);
		});

		context_none.connect(()=>{
			item.sensitive = false;
			remove_action_accel(item, key);
		});
	}

	private void add_new_folder(Gtk.Menu submenu){
		
		var item = new Gtk.MenuItem.with_label (_("Create New Folder"));
		submenu.add(item);

		item.activate.connect (() => {
			view.create_directory();
		});

		string key = "<Control><Shift>n";

		context_normal.connect(()=>{
			item.sensitive = true;
			add_action_accel(item, key);
		});

		context_trash.connect(()=>{
			//add_action_accel(item, key);
		});

		context_archive.connect(()=>{
			//add_action_accel(item, key);
		});

		context_term.connect(()=>{
			//add_action_accel(item, key);
		});
		
		context_edit.connect(()=>{
			//add_action_accel(item, key);
		});

		context_none.connect(()=>{
			item.sensitive = false;
			remove_action_accel(item, key);
		});
	}

	private void add_new_file(Gtk.Menu submenu){

		var item = new Gtk.MenuItem.with_label (_("Create New File"));
		submenu.add(item);

		item.activate.connect (() => {
			view.create_file();
		});

		string key = "<Control><Alt>n";

		context_normal.connect(()=>{
			item.sensitive = true;
			add_action_accel(item, key);
		});

		context_trash.connect(()=>{
			//add_action_accel(item, key);
		});

		context_archive.connect(()=>{
			//add_action_accel(item, key);
		});

		context_term.connect(()=>{
			//add_action_accel(item, key);
		});
		
		context_edit.connect(()=>{
			//add_action_accel(item, key);
		});

		context_none.connect(()=>{
			item.sensitive = false;
			remove_action_accel(item, key);
		});
	}

	private void add_connect_to_server(Gtk.Menu submenu){

		var item = new Gtk.MenuItem.with_label (_("Connect to Server..."));
		submenu.add(item);

		item.activate.connect (() => {
			var win = new ConnectServerWindow(window, "");
		});
	}

	private void add_terminal_window(Gtk.Menu submenu){

		var item = new Gtk.MenuItem.with_label (_("Toggle Terminal Pane"));
		submenu.add(item);

		item.activate.connect (() => {
			pane.terminal.toggle();
		});

		string key = "F4";

		context_normal.connect(()=>{
			item.sensitive = true;
			add_action_accel(item, key);
		});

		context_trash.connect(()=>{
			//add_action_accel(item, key);
		});

		context_archive.connect(()=>{
			//add_action_accel(item, key);
		});

		context_term.connect(()=>{
			item.sensitive = true;
			add_action_accel(item, key);
		});
		
		context_edit.connect(()=>{
			//add_action_accel(item, key);
		});

		context_none.connect(()=>{
			item.sensitive = false;
			remove_action_accel(item, key);
		});
	}

	private void add_exit(Gtk.Menu submenu){

		var item = new Gtk.MenuItem.with_label (_("Exit"));
		submenu.add(item);

		item.activate.connect (() => {
			window.destroy();
		});

		string key = "<Control>w";

		context_normal.connect(()=>{
			item.sensitive = true;
			add_action_accel(item, key);
		});

		context_trash.connect(()=>{
			item.sensitive = true;
			add_action_accel(item, key);
		});

		context_archive.connect(()=>{
			item.sensitive = true;
			add_action_accel(item, key);
		});

		context_term.connect(()=>{
			//add_action_accel(item, key);
		});
		
		context_edit.connect(()=>{
			//add_action_accel(item, key);
		});

		context_none.connect(()=>{
			item.sensitive = false;
			remove_action_accel(item, key);
		});
	}

	
	private void add_menu_edit(Gtk.MenuShell menu_shell){

		log_debug("MainMenuBar: add_menu_edit()");
		
		var menu_item = new Gtk.MenuItem.with_label(_("Edit"));
		menu_shell.add(menu_item);
	
		var submenu = new Gtk.Menu();
		menu_item.set_submenu(submenu);
		
		add_cut(submenu);
		
		add_copy(submenu);
		
		add_paste(submenu);

		gtk_menu_add_separator(submenu);
		
		add_trash(submenu);
		
		add_delete(submenu);

		gtk_menu_add_separator(submenu);
		
		add_rename(submenu);

		gtk_menu_add_separator(submenu);
		
		add_select_all(submenu);
		
		add_select_none(submenu);

		gtk_menu_add_separator(submenu);
		
		add_settings(submenu);
	}

	private void add_cut(Gtk.Menu submenu){

		var item = new Gtk.MenuItem.with_label (_("Cut"));
		submenu.add(item);

		item.activate.connect (() => {
			view.cut();
		});

		string key = "<Control>x";

		context_normal.connect(()=>{
			item.sensitive = true;
			add_action_accel(item, key);
		});

		context_trash.connect(()=>{
			//add_action_accel(item, key);
		});

		context_archive.connect(()=>{
			//add_action_accel(item, key);
		});

		context_term.connect(()=>{
			//add_action_accel(item, key);
		});
		
		context_edit.connect(()=>{
			//add_action_accel(item, key);
		});

		context_none.connect(()=>{
			item.sensitive = false;
			remove_action_accel(item, key);
		});
	}

	private void add_copy(Gtk.Menu submenu){

		var item = new Gtk.MenuItem.with_label (_("Copy"));
		submenu.add(item);

		item.activate.connect (() => {
			view.copy();
		});

		string key = "<Control>c";

		context_normal.connect(()=>{
			item.sensitive = true;
			add_action_accel(item, key);
		});

		context_trash.connect(()=>{
			item.sensitive = true;
			add_action_accel(item, key);
		});

		context_archive.connect(()=>{
			//add_action_accel(item, key);
		});

		context_term.connect(()=>{
			//add_action_accel(item, key);
		});
		
		context_edit.connect(()=>{
			//add_action_accel(item, key);
		});

		context_none.connect(()=>{
			item.sensitive = false;
			remove_action_accel(item, key);
		});
	}

	private void add_paste(Gtk.Menu submenu){

		var item = new Gtk.MenuItem.with_label (_("Paste"));
		submenu.add(item);

		item.activate.connect (() => {
			view.paste();
		});

		string key = "<Control>v";

		context_normal.connect(()=>{
			item.sensitive = true;
			add_action_accel(item, key);
		});

		context_trash.connect(()=>{
			//add_action_accel(item, key);
		});

		context_archive.connect(()=>{
			//add_action_accel(item, key);
		});

		context_term.connect(()=>{
			//add_action_accel(item, key);
		});
		
		context_edit.connect(()=>{
			//add_action_accel(item, key);
		});

		context_none.connect(()=>{
			item.sensitive = false;
			remove_action_accel(item, key);
		});
	}

	private void add_trash(Gtk.Menu submenu){

		var item = new Gtk.MenuItem.with_label (_("Trash"));
		submenu.add(item);

		item.activate.connect (() => {
			view.trash();
		});

		string key = "Delete";

		context_normal.connect(()=>{
			if ((view.current_item != null) && (view.current_item.is_remote)){
				return;
			}
			item.sensitive = true;
			add_action_accel(item, key);
		});

		context_trash.connect(()=>{
			//add_action_accel(item, key);
		});

		context_archive.connect(()=>{
			//add_action_accel(item, key);
		});

		context_term.connect(()=>{
			//add_action_accel(item, key);
		});
		
		context_edit.connect(()=>{
			//add_action_accel(item, key);
		});

		context_none.connect(()=>{
			item.sensitive = false;
			remove_action_accel(item, key);
		});
	}

	private void add_delete(Gtk.Menu submenu){

		var item = new Gtk.MenuItem.with_label (_("Delete"));
		submenu.add(item);

		item.activate.connect (() => {
			view.delete_items();
		});

		string key = "<Shift>Delete";

		context_normal.connect(()=>{
			item.sensitive = true;
			add_action_accel(item, key);

			if ((view.current_item != null) && (view.current_item.is_remote)){
				add_action_accel(item, "Delete");
			}
		});

		context_trash.connect(()=>{
			//add_action_accel(item, "Delete"); // map to Delete key
		});

		context_archive.connect(()=>{
			//add_action_accel(item, key);
		});

		context_term.connect(()=>{
			//add_action_accel(item, key);
		});
		
		context_edit.connect(()=>{
			//add_action_accel(item, key);
		});

		context_none.connect(()=>{
			item.sensitive = false;
			remove_action_accel(item, key);
			remove_action_accel(item, "Delete");
		});
	}

	private void add_rename(Gtk.Menu submenu){

		var item = new Gtk.MenuItem.with_label (_("Rename"));
		submenu.add(item);

		item.activate.connect (() => {
			view.rename();
		});

		string key = "F2";

		context_normal.connect(()=>{
			item.sensitive = true;
			add_action_accel(item, key);
		});

		context_trash.connect(()=>{
			//add_action_accel(item, key);
		});

		context_archive.connect(()=>{
			//add_action_accel(item, key);
		});

		context_term.connect(()=>{
			//add_action_accel(item, key);
		});
		
		context_edit.connect(()=>{
			//add_action_accel(item, key);
		});

		context_none.connect(()=>{
			item.sensitive = false;
			remove_action_accel(item, key);
		});
	}

	private void add_select_all(Gtk.Menu submenu){

		var item = new Gtk.MenuItem.with_label (_("Select All"));
		submenu.add(item);

		item.activate.connect (() => {
			view.select_all();
		});

		string key = "<Control>a";

		context_normal.connect(()=>{
			item.sensitive = true;
			add_action_accel(item, key);
		});

		context_trash.connect(()=>{
			item.sensitive = true;
			add_action_accel(item, key);
		});

		context_archive.connect(()=>{
			item.sensitive = true;
			add_action_accel(item, key);
		});

		context_term.connect(()=>{
			//add_action_accel(item, key);
		});
		
		context_edit.connect(()=>{
			//add_action_accel(item, key);
		});

		context_none.connect(()=>{
			item.sensitive = false;
			remove_action_accel(item, key);
		});
	}

	private void add_select_none(Gtk.Menu submenu){

		var item = new Gtk.MenuItem.with_label (_("Select None"));
		submenu.add(item);

		item.activate.connect (() => {
			view.select_none();
		});

		string key = "Escape";

		context_normal.connect(()=>{
			item.sensitive = true;
			add_action_accel(item, key);
		});

		context_trash.connect(()=>{
			item.sensitive = true;
			add_action_accel(item, key);
		});

		context_archive.connect(()=>{
			item.sensitive = true;
			add_action_accel(item, key);
		});

		context_term.connect(()=>{
			//add_action_accel(item, key);
		});
		
		context_edit.connect(()=>{
			//add_action_accel(item, key);
		});

		context_none.connect(()=>{
			item.sensitive = false;
			remove_action_accel(item, key);
		});
	}

	private void add_settings(Gtk.Menu submenu){

		var item = new Gtk.MenuItem.with_label (_("Preferences"));
		submenu.add(item);

		item.activate.connect (() => {
			window.open_settings_window();
		});
	}

	
	private void add_menu_view(Gtk.MenuShell menu_shell){

		log_debug("MainMenuBar: add_menu_view()");
		
		var menu_item = new Gtk.MenuItem.with_label(_("View"));
		menu_shell.add(menu_item);

		var submenu = new Gtk.Menu();
		menu_item.set_submenu(submenu);

		add_reload(submenu);
		
		gtk_menu_add_separator(submenu);

		add_hidden(submenu);

		add_dual_mode(submenu);

		add_fullscreen_mode(submenu);
		
		gtk_menu_add_separator(submenu);

		add_layout(submenu);

		add_view(submenu);

		add_sort_column(submenu);
		
		log_debug("MainMenuBar: add_menu_view(): exit");
	}

	private void add_reload(Gtk.Menu submenu){

		var item = new Gtk.MenuItem.with_label (_("Reload"));
		submenu.add(item);

		item.activate.connect (() => {
			if (view == null) { return; }
			view.reload();
		});

		string key = "F5";

		context_normal.connect(()=>{
			item.sensitive = true;
			add_action_accel(item, key);
		});

		context_trash.connect(()=>{
			//add_action_accel(item, key);
		});

		context_archive.connect(()=>{
			//add_action_accel(item, key);
		});

		context_term.connect(()=>{
			//add_action_accel(item, key);
		});
		
		context_edit.connect(()=>{
			//add_action_accel(item, key);
		});

		context_none.connect(()=>{
			item.sensitive = false;
			remove_action_accel(item, key);
		});
	}

	private void add_hidden(Gtk.Menu submenu){

		var item = new Gtk.CheckMenuItem.with_label (_("Show Hidden"));
		submenu.add(item);
		chk_hidden = item;

		item.activate.connect(view_toggle_hidden);

		string key = "<Control>h";

		context_normal.connect(()=>{
			item.sensitive = true;

			item.activate.disconnect(view_toggle_hidden);
			item.active = (view == null) ? false : view.show_hidden_files;
			item.activate.connect(view_toggle_hidden);
			
			add_action_accel(item, key);
		});

		context_trash.connect(()=>{
			item.sensitive = true;

			item.activate.disconnect(view_toggle_hidden);
			item.active = (view == null) ? false : view.show_hidden_files;
			item.activate.connect(view_toggle_hidden);
			
			add_action_accel(item, key);
		});

		context_archive.connect(()=>{
			item.sensitive = true;

			item.activate.disconnect(view_toggle_hidden);
			item.active = (view == null) ? false : view.show_hidden_files;
			item.activate.connect(view_toggle_hidden);
			
			add_action_accel(item, key);
		});

		context_term.connect(()=>{
			//add_action_accel(item, key);
		});
		
		context_edit.connect(()=>{
			//add_action_accel(item, key);
		});

		context_none.connect(()=>{
			item.sensitive = false;
			remove_action_accel(item, key);
		});
	}

	private void view_toggle_hidden(){
		
		if (view == null) { return; }
			
		if (chk_hidden.active){
			view.show_hidden();
		}
		else{
			view.hide_hidden();
		}
	}

	private void add_layout(Gtk.Menu submenu){

		var item = new Gtk.MenuItem.with_label (_("Layout"));
		submenu.add(item);

		delayed_init.connect(()=>{
			item.sensitive = (window.toolbar != null);
			if (window.toolbar == null){ return; }
			item.set_submenu(window.toolbar.build_layout_menu());
		});
	}

	private void add_view(Gtk.Menu submenu){

		var item = new Gtk.MenuItem.with_label (_("View"));
		submenu.add(item);

		delayed_init.connect(()=>{
			item.sensitive = (window.toolbar != null);
			if (window.toolbar == null){ return; }
			item.set_submenu(window.toolbar.build_view_menu());
		});
	}
	
	private void add_dual_mode(Gtk.Menu submenu){

		var item = new Gtk.CheckMenuItem.with_label (_("Dual Pane Mode"));
		submenu.add(item);

		item.activate.connect(view_toggle_dual);

		string key = "F3";

		context_normal.connect(()=>{
			item.sensitive = true;

			item.activate.disconnect(view_toggle_dual);
			item.active = (window.layout_box != null) && (window.layout_box.get_panel_layout() == PanelLayout.DUAL_VERTICAL);
			item.activate.connect(view_toggle_dual);
			
			add_action_accel(item, key);
		});

		context_trash.connect(()=>{
			item.sensitive = true;

			item.activate.disconnect(view_toggle_dual);
			item.active = (window.layout_box != null) && (window.layout_box.get_panel_layout() == PanelLayout.DUAL_VERTICAL);
			item.activate.connect(view_toggle_dual);
			
			add_action_accel(item, key);
		});

		context_archive.connect(()=>{
			item.sensitive = true;

			item.activate.disconnect(view_toggle_dual);
			item.active = (window.layout_box != null) && (window.layout_box.get_panel_layout() == PanelLayout.DUAL_VERTICAL);
			item.activate.connect(view_toggle_dual);
			
			add_action_accel(item, key);
		});

		context_term.connect(()=>{
			item.sensitive = true;

			item.activate.disconnect(view_toggle_dual);
			item.active = (window.layout_box != null) && (window.layout_box.get_panel_layout() == PanelLayout.DUAL_VERTICAL);
			item.activate.connect(view_toggle_dual);
			
			add_action_accel(item, key);
		});
		
		context_edit.connect(()=>{
			//add_action_accel(item, key);
		});

		context_none.connect(()=>{
			item.sensitive = false;
			remove_action_accel(item, key);
		});
	}

	private void view_toggle_dual(){
		
		if (view == null) { return; }
			
		view.toggle_dual_pane();
	}

	private void add_fullscreen_mode(Gtk.Menu submenu){
		
		var item = new Gtk.CheckMenuItem.with_label (_("Fullscreen Mode"));
		submenu.add(item);

		item.activate.connect(window.toggle_fullscreen);
		
		string key = "F11";

		context_normal.connect(()=>{
			item.sensitive = true;
			
			item.activate.disconnect(window.toggle_fullscreen);
			item.active = window.is_maximized;
			item.activate.connect(window.toggle_fullscreen);

			add_action_accel(item, key);
		});

		context_trash.connect(()=>{
			item.sensitive = true;
			
			item.activate.disconnect(window.toggle_fullscreen);
			item.active = window.is_maximized;
			item.activate.connect(window.toggle_fullscreen);
			
			add_action_accel(item, key);
		});

		context_archive.connect(()=>{
			item.sensitive = true;
			
			item.activate.disconnect(window.toggle_fullscreen);
			item.active = window.is_maximized;
			item.activate.connect(window.toggle_fullscreen);
			
			add_action_accel(item, key);
		});

		context_term.connect(()=>{
			//add_action_accel(item, key);
		});
		
		context_edit.connect(()=>{
			//add_action_accel(item, key);
		});

		context_none.connect(()=>{
			item.sensitive = false;
			remove_action_accel(item, key);
		});
	}

	private void add_sort_column(Gtk.Menu submenu){

		var item = new Gtk.MenuItem.with_label (_("Sort By"));
		submenu.add(item);

		item.activate.connect (() => {
			if (view == null) { return; }
			view.reload();
		});

		active_pane_changed.connect(()=>{
			item.sensitive = (pane != null);
			if (pane == null) { return; }
			var sort_menu = new SortMenu(pane);
			item.set_submenu(sort_menu);
		});
	}


	private void add_menu_go(Gtk.MenuShell menu_shell){

		log_debug("MainMenuBar: add_menu_go()");
		
		var menu_item = new Gtk.MenuItem.with_label(_("Go"));
		menu_shell.add(menu_item);

		var submenu = new Gtk.Menu();
		menu_item.set_submenu(submenu);

		add_open(submenu);

		gtk_menu_add_separator(submenu);
		
		add_back(submenu);
		
		add_forward(submenu);
		
		add_up(submenu);

		gtk_menu_add_separator(submenu);
		
		add_open_location(submenu);
	}

	private void add_open(Gtk.Menu submenu){

		var item = new Gtk.MenuItem.with_label (_("Open"));
		submenu.add(item);

		item.activate.connect (() => {
			view.open_selected_item();
		});

		//if (add_accel){
			//add_action_accel(item, "enter");
		//}
	}

	private void add_back(Gtk.Menu submenu){

		var item = new Gtk.MenuItem.with_label (_("Back"));
		submenu.add(item);

		item.activate.connect (() => {
			view.go_back();
		});

		string key = "<Alt>Left";

		context_normal.connect(()=>{
			item.sensitive = true;
			add_action_accel(item, key);
		});

		context_trash.connect(()=>{
			item.sensitive = true;
			add_action_accel(item, key);
		});

		context_archive.connect(()=>{
			item.sensitive = true;
			add_action_accel(item, key);
		});

		context_term.connect(()=>{
			//add_action_accel(item, key);
		});
		
		context_edit.connect(()=>{
			//add_action_accel(item, key);
		});

		context_none.connect(()=>{
			item.sensitive = false;
			remove_action_accel(item, key);
		});
	}

	private void add_forward(Gtk.Menu submenu){

		var item = new Gtk.MenuItem.with_label (_("Forward"));
		submenu.add(item);

		item.activate.connect (() => {
			view.go_forward();
		});

		string key = "<Alt>Right";

		context_normal.connect(()=>{
			item.sensitive = true;
			add_action_accel(item, key);
		});

		context_trash.connect(()=>{
			item.sensitive = true;
			add_action_accel(item, key);
		});

		context_archive.connect(()=>{
			item.sensitive = true;
			add_action_accel(item, key);
		});

		context_term.connect(()=>{
			//add_action_accel(item, key);
		});
		
		context_edit.connect(()=>{
			//add_action_accel(item, key);
		});

		context_none.connect(()=>{
			item.sensitive = false;
			remove_action_accel(item, key);
		});
	}

	private void add_up(Gtk.Menu submenu){

		var item = new Gtk.MenuItem.with_label (_("Up"));
		submenu.add(item);

		item.activate.connect (() => {
			view.go_up();
		});

		string key = "<Alt>Up";

		context_normal.connect(()=>{
			item.sensitive = true;
			add_action_accel(item, key);
		});

		context_trash.connect(()=>{
			item.sensitive = true;
			add_action_accel(item, key);
		});

		context_archive.connect(()=>{
			item.sensitive = true;
			add_action_accel(item, key);
		});

		context_term.connect(()=>{
			//add_action_accel(item, key);
		});
		
		context_edit.connect(()=>{
			//add_action_accel(item, key);
		});

		context_none.connect(()=>{
			item.sensitive = false;
			remove_action_accel(item, key);
		});
	}

	private void add_open_location(Gtk.Menu submenu){

		var item = new Gtk.MenuItem.with_label (_("Open Location..."));
		submenu.add(item);

		item.activate.connect (() => {
			pane.pathbar.edit_location();
		});

		string key = "<Control>l";

		context_normal.connect(()=>{
			item.sensitive = true;
			add_action_accel(item, key);
		});

		context_trash.connect(()=>{
			item.sensitive = true;
			add_action_accel(item, key);
		});

		context_archive.connect(()=>{
			item.sensitive = true;
			add_action_accel(item, key);
		});

		context_term.connect(()=>{
			//add_action_accel(item, key);
		});
		
		context_edit.connect(()=>{
			//add_action_accel(item, key);
		});

		context_none.connect(()=>{
			item.sensitive = false;
			remove_action_accel(item, key);
		});
	}


	private void add_menu_cloud(Gtk.MenuShell menu_shell){

		log_debug("MainMenuBar: add_menu_cloud()");
		
		var menu_item = new Gtk.MenuItem.with_label(_("Cloud"));
		menu_shell.add(menu_item);

		var submenu = new Gtk.Menu();
		submenu.reserve_toggle_size = false;
		menu_item.set_submenu(submenu);

		App.rclone.changed.connect(()=>{
			add_cloud_account_refresh(submenu);
		});

		add_cloud_account_refresh(submenu);
	}

	private void add_cloud_account_refresh(Gtk.Menu menu){
		
		log_debug("mainmenu: cloud: refresh()");

		gtk_container_remove_children(menu);
		
		add_cloud_account_add(menu);

		add_cloud_account_remove(menu);

		//add_cloud_account_unmount(menu);

		gtk_menu_add_separator(menu);

		add_cloud_account_browse(menu);

		show_all();

		menu.show_all();
	}
	
	private void add_cloud_account_add(Gtk.Menu menu){
		
		var item = new Gtk.MenuItem.with_label (_("Add Account"));
		item.set_tooltip_text(_("Login to cloud storage account"));
		menu.add(item);

		item.activate.connect (() => {
			window.add_rclone_account();
		});
	}

	private void add_cloud_account_remove(Gtk.Menu menu){
		
		var item = new Gtk.MenuItem.with_label (_("Remove Account"));
		item.set_tooltip_text(_("Logout from cloud storage account"));
		menu.add(item);

		var submenu = new Gtk.Menu();
		item.set_submenu(submenu);

		var sg_icon = new Gtk.SizeGroup(Gtk.SizeGroupMode.HORIZONTAL);
		var sg_label = new Gtk.SizeGroup(Gtk.SizeGroupMode.HORIZONTAL);
		
		foreach(var acc in App.rclone.accounts){

			Gtk.Image? image = null;

			switch(acc.type){
			case "dropbox":
				image = IconManager.lookup_image("dropbox", 16);
				break;
			case "drive":
				image = IconManager.lookup_image("web-google", 16);
				break;
			case "onedrive":
				image = IconManager.lookup_image("web-microsoft", 16);
				break;
			case "amazon cloud drive":
			case "s3":
				image = IconManager.lookup_image("web-amazon", 16);
				break;
			default:
				image = IconManager.lookup_image("goa-panel", 16);
				break;
			}

			var subitem = gtk_menu_add_item(
				submenu,
				acc.name,
				"",
				image,
				sg_icon,
				sg_label);

			subitem.activate.connect (() => {
				bool ok = window.remove_rclone_account(acc);
				if (ok){
					gtk_messagebox(_("Account Removed"), "%s".printf(acc.name), window, false);
					submenu.remove(subitem);
					window.close_tabs_for_location("%s:".printf(acc.name));
				}
				else {
					gtk_messagebox(_("Failed to Remove Account"), "%s".printf(acc.name), window, false);
				}
				App.rclone.query_accounts();
			});
		}
		
		submenu.show_all();
	}

	private void add_cloud_account_unmount(Gtk.Menu menu){
		
		var item = new Gtk.MenuItem.with_label (_("Unmount"));
		item.set_tooltip_text(_("Unmount cloud storage account"));
		menu.add(item);

		var submenu = new Gtk.Menu();
		item.set_submenu(submenu);

		var sg_icon = new Gtk.SizeGroup(Gtk.SizeGroupMode.HORIZONTAL);
		var sg_label = new Gtk.SizeGroup(Gtk.SizeGroupMode.HORIZONTAL);
		
		foreach(var acc in App.rclone.accounts){

			Gtk.Image? image = null;

			switch(acc.type){
			case "dropbox":
				image = IconManager.lookup_image("dropbox", 16);
				break;
			case "drive":
				image = IconManager.lookup_image("web-google", 16);
				break;
			case "onedrive":
				image = IconManager.lookup_image("web-microsoft", 16);
				break;
			case "amazon cloud drive":
			case "s3":
				image = IconManager.lookup_image("web-amazon", 16);
				break;
			default:
				image = IconManager.lookup_image("goa-panel", 16);
				break;
			}

			var subitem = gtk_menu_add_item(
				submenu,
				acc.name,
				"",
				image,
				sg_icon,
				sg_label);

			subitem.activate.connect (() => {
				acc.unmount();
			});

			subitem.sensitive = (App.rclone.get_mounted_path(acc.name).length > 0);
		}
	}

	private void add_cloud_account_browse(Gtk.Menu menu){

		var sg_icon = new Gtk.SizeGroup(Gtk.SizeGroupMode.HORIZONTAL);
		var sg_label = new Gtk.SizeGroup(Gtk.SizeGroupMode.HORIZONTAL);
		
		foreach(var acc in App.rclone.accounts){

			Gtk.Image? image = null;

			switch(acc.type){
			case "dropbox":
				image = IconManager.lookup_image("dropbox", 16);
				break;
			case "drive":
				image = IconManager.lookup_image("web-google", 16);
				break;
			default:
				image = IconManager.lookup_image("goa-panel", 16);
				break;
			}

			var item = gtk_menu_add_item(
				menu,
				acc.name,
				"",
				image,
				sg_icon,
				sg_label);

			item.activate.connect (() => {

				App.rclone.query_mounted_remotes();
				
				log_debug("menu_item_clicked: %s".printf(acc.name), true);

				bool delayed_load = false;

				string mpath = App.rclone.get_mounted_path(acc.name);
				
				if (mpath.length == 0){
					
					log_debug("not_mounted: %s".printf(acc.name));
					acc.mount();
					delayed_load = true;
				}
				else {
					log_debug("is_mounted: %s".printf(acc.name));
				}

				var tab = panel.add_tab(false);

				//tab.view.query_items_delay = 3000;

				//tab.view.set_view_path(acc.mount_path);

				tab.view.set_view_item(acc.fs_root);

				//tab.pane.view.set_overlay_on_loading();

				/*log_debug("waiting for 3000ms -------------------");
				int count = 3000;
				while (count > 0){
					sleep(100);
					count -= 100;
					gtk_do_events();
				}
				log_debug("waiting for 3000ms: done -------------");

				tab.pane.view.set_view_path(acc.mount_path);*/
			});
		}
	}


	private void add_menu_tools(Gtk.MenuShell menu_shell){

		log_debug("MainMenuBar: add_menu_tools()");
		
		var menu_item = new Gtk.MenuItem.with_label(_("Tools"));
		menu_shell.add(menu_item);

		var submenu = new Gtk.Menu();
		menu_item.set_submenu(submenu);

		add_clear_thumbnail_cache(submenu);

		add_rebuild_font_cache(submenu);

		add_calculate_dir_sizes(submenu);

		add_external_tools(submenu);

		add_wizard(submenu);

		add_reset_session(submenu);

		add_test_action(submenu);

		add_test_action2(submenu);
		
		add_test_action3(submenu);
	}

	private void add_clear_thumbnail_cache(Gtk.Menu menu){

		var item = new Gtk.MenuItem.with_label (_("Clean thumbnail cache"));
		item.set_tooltip_text(_("Clear the thumbnails in system cache. New thumbnails will be generated when folders are browsed using any file manager."));
		menu.add(item);

		item.activate.connect (() => {
			window.clear_thumbnail_cache();
		});
	}

	private void add_rebuild_font_cache(Gtk.Menu menu){

		var item = new Gtk.MenuItem.with_label(_("Rebuild font cache"));
		item.set_tooltip_text(_("Rebuilds the system font cache, so that newly installed fonts become visible to applications"));
		menu.add(item);

		item.activate.connect (() => {
			window.rebuild_font_cache();
		});
	}

	private void add_calculate_dir_sizes(Gtk.Menu menu){

		var item = new Gtk.MenuItem.with_label (_("Calculate directory sizes"));
		//item.set_tooltip_text("");
		menu.add(item);

		item.activate.connect (() => {
			view.calculate_directory_sizes();
		});

		string key = "<Control>e";

		context_normal.connect(()=>{
			item.sensitive = true;
			add_action_accel(item, key);
		});

		context_trash.connect(()=>{
			//add_action_accel(item, key);
		});

		context_archive.connect(()=>{
			//add_action_accel(item, key);
		});

		context_term.connect(()=>{
			//add_action_accel(item, key);
		});
		
		context_edit.connect(()=>{
			//add_action_accel(item, key);
		});

		context_none.connect(()=>{
			item.sensitive = false;
			remove_action_accel(item, key);
		});
	}
	
	private void add_wizard(Gtk.Menu menu){

		var item = new Gtk.MenuItem.with_label (_("Open style wizard"));
		item.set_tooltip_text(_("Select layout and style"));
		menu.add(item);

		item.activate.connect (() => {
			window.open_wizard_window();
		});
	}

	private void add_reset_session(Gtk.Menu menu){

		if (!App.session_lock.lock_acquired){ return; }

		var item = new Gtk.MenuItem.with_label (_("Reset session and restart"));
		item.set_tooltip_text(_("Polo will be restarted with a fresh session"));
		menu.add(item);

		item.activate.connect (() => {
			file_delete(App.app_conf_session);
			exit(0); // exit immediately
		});
	}

	private void add_external_tools(Gtk.Menu menu){

		var item = new Gtk.MenuItem.with_label (_("External tools"));
		item.set_tooltip_text(_("Check external tools"));
		menu.add(item);

		item.activate.connect (() => {
			var win = new ToolsWindow(window);
		});
	}

	private void add_test_action(Gtk.Menu menu){

		if (!LOG_DEBUG){ return; }

		var item = new Gtk.MenuItem.with_label (_("Debug: List FileItem Objects"));
		item.set_tooltip_text("");
		menu.add(item);

		item.activate.connect (() => {
			gtk_messagebox("Objects=%lld, Map=%d".printf(FileItem.object_count, FileItem.cache.keys.size),"", window, false);
		});
	}

	private void add_test_action2(Gtk.Menu menu){

		if (!LOG_DEBUG){ return; }

		var item = new Gtk.MenuItem.with_label (_("Debug: List Devices"));
		item.set_tooltip_text("");
		menu.add(item);

		item.activate.connect (() => {
			Device.print_device_list(Device.get_devices());
		});
	}

	private void add_test_action3(Gtk.Menu menu){

		if (!LOG_DEBUG){ return; }

		var item = new Gtk.MenuItem.with_label (_("Debug: Monitors"));
		item.set_tooltip_text("");
		menu.add(item);

		item.activate.connect (() => {
			gtk_messagebox("Objects=%lld".printf(pane.view.monitors.size),"", window, false);
		});
	}


	private void add_menu_help(Gtk.MenuShell menu_shell){

		log_debug("MainMenuBar: add_menu_help()");
		
		var menu_item = new Gtk.MenuItem.with_label(_("Help"));
		menu_shell.add(menu_item);

		var submenu = new Gtk.Menu();
		menu_item.set_submenu(submenu);

		add_homepage(submenu);

		add_issue_tracker(submenu);

		add_wiki(submenu);

		add_shortcuts(submenu);
		
		add_donate(submenu);

		add_about(submenu);

	}

	private void add_homepage(Gtk.Menu menu){

		var item = new Gtk.MenuItem.with_label (_("Homepage"));
		menu.add(item);

		item.activate.connect (() => {
			xdg_open("http://teejeetech.in");
		});
	}

	private void add_issue_tracker(Gtk.Menu menu){

		var item = new Gtk.MenuItem.with_label (_("Issue Tracker"));
		menu.add(item);

		item.activate.connect (() => {
			xdg_open("https://github.com/teejee2008/polo/issues");
		});
	}

	private void add_wiki(Gtk.Menu menu){

		var item = new Gtk.MenuItem.with_label (_("Wiki"));
		menu.add(item);

		item.activate.connect (() => {
			xdg_open("https://github.com/teejee2008/polo/wiki");
		});
	}

	private void add_shortcuts(Gtk.Menu menu){

		var item = new Gtk.MenuItem.with_label (_("Keyboard Shortcuts"));
		menu.add(item);

		item.activate.connect (() => {
			//window.open_shortcuts_window();
		});
	}
	
	private void add_donate(Gtk.Menu menu){

		var item = new Gtk.MenuItem.with_label (_("Donate"));
		menu.add(item);

		item.activate.connect (() => {
			window.open_donate_window();
		});
	}

	private void add_about(Gtk.Menu menu){

		var item = new Gtk.MenuItem.with_label (_("About"));
		menu.add(item);

		item.activate.connect (() => {
			window.open_about_window();
		});
	}
}




