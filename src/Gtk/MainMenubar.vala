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

public class MainMenuBar : Gtk.MenuBar {

	private FileViewList? view{
		get{
			return (pane == null) ? null : pane.view;
		}
	}

	private FileViewPane? pane {
		get{
			return App.main_window.active_pane;
		}
	}

	private LayoutPanel? panel {
		get{
			return (pane == null) ? null : pane.panel;
		}
	}

	private MainWindow window{
		get{
			return App.main_window;
		}
	}

	private Gtk.Menu? menu = null;
	private bool menu_mode = false;
	private bool add_accel = true;
	
	public MainMenuBar(bool _menu_mode){
		
		this.menu_mode = _menu_mode;
		
		if (menu_mode){
			this.menu = new Gtk.Menu();
		}
	}

	public void enable_accelerators(){
		add_accel = true;
		refresh();
	}

	public void disable_accelerators(){
		add_accel = false;
		refresh();
	}

	public Gtk.Menu? get_menu(){
		return menu;
	}

	public void add_action_accel(Gtk.MenuItem item, string keycode){
		uint accel_key;
		Gdk.ModifierType accel_mods;
		var accel_flags = Gtk.AccelFlags.VISIBLE;
		Gtk.accelerator_parse(keycode, out accel_key, out accel_mods);
		item.add_accelerator ("activate", Hotkeys.accel_group, accel_key, accel_mods, accel_flags);
	}
	
	public void refresh(){

		Gtk.MenuShell menu_shell = this;
		if (menu_mode){
			menu_shell = menu;
		}

		gtk_container_remove_children(menu_shell);

		add_menu_file(menu_shell);
		add_menu_edit(menu_shell);
		add_menu_view(menu_shell);
		add_menu_go(menu_shell);
		add_menu_tools(menu_shell);
		
		menu_shell.show_all();
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

		add_terminal_window(submenu);

		gtk_menu_add_separator(submenu);

		add_exit(submenu);
		
		log_debug("MainMenuBar: add_menu_file(): exit");
	}

	private void add_new_tab(Gtk.Menu submenu){
		
		var item = new Gtk.MenuItem.with_label (_("New Tab"));
		submenu.add(item);

		item.activate.connect (() => {
			panel.add_tab();
		});

		if (add_accel){
			add_action_accel(item, "<Control>t");
		}
	}

	private void add_new_window(Gtk.Menu submenu){
		
		var item = new Gtk.MenuItem.with_label (_("New Window"));
		submenu.add(item);

		item.activate.connect (() => {
			view.open_in_new_window();
		});

		if (add_accel){
			add_action_accel(item, "<Control>n");
		}
	}

	private void add_admin_window(Gtk.Menu submenu){

		var item = new Gtk.MenuItem.with_label (_("New Admin Window"));
		submenu.add(item);

		item.activate.connect (() => {
			view.open_in_admin_window();
		});

		if (add_accel){
			add_action_accel(item, "<Super>n");
		}
	}

	private void add_new_folder(Gtk.Menu submenu){
		
		var item = new Gtk.MenuItem.with_label (_("Create New Folder"));
		submenu.add(item);

		item.activate.connect (() => {
			view.create_directory();
		});

		if (add_accel){
			add_action_accel(item, "<Control><Shift>n");
		}
	}

	private void add_new_file(Gtk.Menu submenu){

		var item = new Gtk.MenuItem.with_label (_("Create New File"));
		submenu.add(item);

		item.activate.connect (() => {
			view.create_file();
		});

		if (add_accel){
			add_action_accel(item, "<Control><Alt>n");
		}
	}

	private void add_terminal_window(Gtk.Menu submenu){

		var item = new Gtk.MenuItem.with_label (_("Toggle Terminal Pane"));
		submenu.add(item);

		item.activate.connect (() => {
			pane.terminal.toggle();
		});

		if (add_accel){
			add_action_accel(item, "F4");
		}
	}

	private void add_exit(Gtk.Menu submenu){

		var item = new Gtk.MenuItem.with_label (_("Exit"));
		submenu.add(item);

		item.activate.connect (() => {
			window.destroy();
		});

		if (add_accel){
			add_action_accel(item, "<Control>w");
		}
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

		if (add_accel){
			add_action_accel(item, "<Control>x");
		}
	}

	private void add_copy(Gtk.Menu submenu){

		var item = new Gtk.MenuItem.with_label (_("Copy"));
		submenu.add(item);

		item.activate.connect (() => {
			view.copy();
		});

		if (add_accel){
			add_action_accel(item, "<Control>c");
		}
	}

	private void add_paste(Gtk.Menu submenu){

		var item = new Gtk.MenuItem.with_label (_("Paste"));
		submenu.add(item);

		item.activate.connect (() => {
			view.paste();
		});

		if (add_accel){
			add_action_accel(item, "<Control>v");
		}
	}

	private void add_trash(Gtk.Menu submenu){

		var item = new Gtk.MenuItem.with_label (_("Trash"));
		submenu.add(item);

		item.activate.connect (() => {
			view.trash();
		});

		if (add_accel){
			add_action_accel(item, "Delete");
		}
	}

	private void add_delete(Gtk.Menu submenu){

		var item = new Gtk.MenuItem.with_label (_("Delete"));
		submenu.add(item);

		item.activate.connect (() => {
			view.delete_items();
		});

		if (add_accel){
			add_action_accel(item, "<Shift>Delete");
		}
	}

	private void add_rename(Gtk.Menu submenu){

		var item = new Gtk.MenuItem.with_label (_("Rename"));
		submenu.add(item);

		item.activate.connect (() => {
			view.rename();
		});

		if (add_accel){
			add_action_accel(item, "F2");
		}
	}

	private void add_select_all(Gtk.Menu submenu){

		var item = new Gtk.MenuItem.with_label (_("Select All"));
		submenu.add(item);

		item.activate.connect (() => {
			view.select_all();
		});

		if (add_accel){
			add_action_accel(item, "<Control>a");
		}
	}

	private void add_select_none(Gtk.Menu submenu){

		var item = new Gtk.MenuItem.with_label (_("Select None"));
		submenu.add(item);

		item.activate.connect (() => {
			view.select_none();
		});

		if (add_accel){
			add_action_accel(item, "Escape");
		}
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

		if (add_accel){
			add_action_accel(item, "F5");
		}
	}

	private void add_hidden(Gtk.Menu submenu){

		var chk = new Gtk.CheckMenuItem.with_label (_("Show Hidden"));
		chk.active = (view == null) ? false : pane.view.show_hidden_files;
		submenu.add(chk);
		var chk_hidden = chk;

		chk.activate.connect (() => {
			if (view == null) { return; }
			
			if (chk_hidden.active){
				view.show_hidden();
			}
			else{
				view.hide_hidden();
			}
		});

		if (add_accel){
			add_action_accel(chk, "<Control>h");
		}
	}

	private void add_layout(Gtk.Menu submenu){

		var item = new Gtk.MenuItem.with_label (_("Layout"));
		submenu.add(item);

		item.set_submenu(window.toolbar.build_layout_menu());
	}

	private void add_view(Gtk.Menu submenu){

		var item = new Gtk.MenuItem.with_label (_("View"));
		submenu.add(item);

		item.set_submenu(window.toolbar.build_view_menu());
	}
	
	private void add_dual_mode(Gtk.Menu submenu){
		
		var chk = new Gtk.CheckMenuItem.with_label (_("Dual Pane Mode"));
		chk.active = (window.layout_box.get_panel_layout() == PanelLayout.DUAL_VERTICAL);
		submenu.add(chk);

		chk.activate.connect (() => {
			if (view == null) { return; }
			view.toggle_dual_pane();
		});

		if (add_accel){
			add_action_accel(chk, "F3");
		}
	}

	private void add_fullscreen_mode(Gtk.Menu submenu){
		
		var chk = new Gtk.CheckMenuItem.with_label (_("Fullscreen Mode"));
		chk.active = window.is_maximized;
		submenu.add(chk);

		chk.activate.connect (() => {
			window.toggle_fullscreen();
		});
		
		if (add_accel){
			add_action_accel(chk, "F11");
		}
	}

	private void add_sort_column(Gtk.Menu submenu){

		var item = new Gtk.MenuItem.with_label (_("Sort By"));
		submenu.add(item);

		item.activate.connect (() => {
			if (view == null) { return; }
			view.reload();
		});

		var sort_menu = new SortMenu(pane);
		item.set_submenu(sort_menu);
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

		if (add_accel){
			//add_action_accel(item, "enter");
		}
	}

	private void add_back(Gtk.Menu submenu){

		var item = new Gtk.MenuItem.with_label (_("Back"));
		submenu.add(item);

		item.activate.connect (() => {
			view.go_back();
		});

		if (add_accel){
			add_action_accel(item, "<Alt>Left");
		}
	}

	private void add_forward(Gtk.Menu submenu){

		var item = new Gtk.MenuItem.with_label (_("Forward"));
		submenu.add(item);

		item.activate.connect (() => {
			view.go_forward();
		});

		if (add_accel){
			add_action_accel(item, "<Alt>Right");
		}
	}

	private void add_up(Gtk.Menu submenu){

		var item = new Gtk.MenuItem.with_label (_("Up"));
		submenu.add(item);

		item.activate.connect (() => {
			view.go_up();
		});

		if (add_accel){
			add_action_accel(item, "<Alt>Up");
		}
	}

	private void add_open_location(Gtk.Menu submenu){

		var item = new Gtk.MenuItem.with_label (_("Open Location..."));
		submenu.add(item);

		item.activate.connect (() => {
			pane.pathbar.edit_location();
		});

		if (add_accel){
			add_action_accel(item, "<Control>l");
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

	private void add_wizard(Gtk.Menu menu){

		var item = new Gtk.MenuItem.with_label (_("Open style wizard"));
		item.set_tooltip_text(_("Select layout and style"));
		menu.add(item);

		item.activate.connect (() => {
			window.open_wizard_window();
		});
	}

	private void add_reset_session(Gtk.Menu menu){

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

	private void add_calculate_dir_sizes(Gtk.Menu menu){

		var item = new Gtk.MenuItem.with_label (_("Calculate directory sizes"));
		//item.set_tooltip_text("");
		menu.add(item);

		item.activate.connect (() => {
			view.calculate_directory_sizes();
		});

		if (add_accel){
			add_action_accel(item, "<Control>e");
		}
	}
}




