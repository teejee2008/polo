/*
 * LayoutPanel.vala
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

public class LayoutPanel : Gtk.Box {

	public MiddleToolbar middlebar;
	public Gtk.Notebook notebook;
	
	// children
	public Gee.ArrayList<FileViewTab> tabs = new Gee.ArrayList<FileViewTab>();
	public FileViewTab dummy_tab = null;
	
	// parents
	private MainWindow window;
	private LayoutBox layout_box;
	
	public LayoutPanel(LayoutBox parent_layout_box, bool add_middle_toolbar = false){
		//base(Gtk.Orientation.VERTICAL, 6); // issue with vala
		Object(orientation: Gtk.Orientation.HORIZONTAL, spacing: 0); // work-around
		
		log_debug("LayoutPanel(): ----------------------------");
		
		layout_box = parent_layout_box;
		window = App.main_window;
		//tab_count++;

		if (add_middle_toolbar){
			add_middlebar();
		}
		
		//var vbox = new Gtk.Box(Orientation.VERTICAL, 6);
		//action_bar.margin = 6;
		//add(vbox);
		
		add_notebook();

		//add_tab();
		
		notebook.switch_page.connect(on_notebook_switch_page);
		
		//add_new_tab_button();

		//var timer = timer_start();
		
		//init_tab();

		//log_trace("tab initialized: %s".printf(timer_elapsed_string(timer)));

		log_debug("LayoutPanel(): created --------------------");
	}

	private void add_middlebar(){
		middlebar = new MiddleToolbar();
		add(middlebar);
		layout_box.middlebar = middlebar;
	}
	
	private void add_notebook(){
		
		notebook = new Gtk.Notebook();
		notebook.show_border = true;
		notebook.scrollable = true;
		add(notebook);

		notebook.group_name = "polo-pane"; // allows tabs to be detached and dropped to another notebook with same group_name

		refresh_tab_style();

		//notebook.page_added.connect((page, page_num) => {
			// show or hide tab bar
			//notebook.show_tabs = (notebook.get_n_pages() > 1);
		//});
		
		//notebook.page_removed.connect((page, page_num) => {
			// show or hide tab bar
			//notebook.show_tabs = (notebook.get_n_pages() > 1);
		//});

		notebook.page_removed.connect((page, page_num) => {
			
			log_debug("notebook_page_removed: %ld".printf(page_num));
			log_debug("pages: %ld".printf(notebook.get_n_pages()));

			// switch to another page
			if (page_num > 0){
				notebook.page = (int) page_num - 1;
			}
			else if ((page_num == 0) && (notebook.get_n_pages() >= page_num + 2)){ // == 0
				notebook.page = (int) page_num;
			}
			else if (!window.window_is_closing){
				var tab = add_tab();
				window.active_pane = tab.pane;
			}
		});
	}

	public void notebook_switch_page_connect(){
		notebook.switch_page.connect(on_notebook_switch_page);
	}

	public void notebook_switch_page_disconnect(){
		notebook.switch_page.disconnect(on_notebook_switch_page);
	}

	private void on_notebook_switch_page(Gtk.Widget page, uint page_num){

		log_debug("notebook_switch_page: %ld".printf(page_num));

		if (!App.main_window.window_is_ready){
			return;
		}
		
		FileViewPane? selected_pane = (FileViewPane?) notebook.get_nth_page((int)page_num);
		
		if ((selected_pane != null) && (dummy_tab != null) && (selected_pane == dummy_tab.pane)){
			
			notebook.switch_page.disconnect(on_notebook_switch_page);

			var tab = add_tab();
			window.active_pane = tab.pane;
			
			notebook.switch_page.connect(on_notebook_switch_page);
		}
		else {
			var tab = tabs[(int) page_num];
			window.active_pane = tab.pane;
		}
	}

	// refresh

	public void refresh_tab_style(){
		
		if (App.tabs_bottom){
			notebook.tab_pos = PositionType.BOTTOM;
		}
		else{
			notebook.tab_pos = PositionType.TOP;
		}
	}
	
	// helpers
	
	public FileViewTab add_tab(bool init_view = true){

		log_debug("FileViewTab: add_tab()");
		
		if (dummy_tab == null){
			add_dummy_tab();
		}

		// convert dummy tab to new tab
		var tab = dummy_tab;
		tab.tab_name = "";
		if (init_view){
			tab.pane.view.set_view_path(App.user_home);
		}

		// add another dummy tab
		add_dummy_tab();

		tab.select_tab();

		return tab;
	}

	public FileViewTab add_dummy_tab(){
		var tab = new FileViewTab(this, notebook);
		tabs.add(tab);
		tab.renamed = true;
		tab.tab_name = "+";
		dummy_tab = tab;
		return tab;
	}

	
	public void run_script_in_new_terminal_tab(string command, string desc){
		
		var tab = add_tab();
		tab.select_tab();
		tab.pane.terminal.toggle();
		tab.pane.maximize_terminal();

		string cmd = "";
		cmd += "reset\n";
		cmd += "echo ''\n";
		cmd += "echo '====================================================='\n";
		cmd += "echo '%s'\n".printf(desc);
		cmd += "echo '====================================================='\n";
		cmd += "echo ''\n";
		cmd += "%s\n".printf(command);
		cmd += "echo ''\n";
		cmd += "echo '====================================================='\n";
		cmd += "echo 'Finished ~ Close Tab to exit'\n";
		cmd += "echo '====================================================='\n";
		cmd += "echo ''\n";
		
		var sh = save_bash_script_temp(cmd);
		cmd = "sh '%s'".printf(sh);
		tab.pane.terminal.feed_command(cmd);
	}
	
	// properties
	
	public Gee.ArrayList<ProgressPanel> file_operations {
		owned get {
			var list = new Gee.ArrayList<ProgressPanel>();
			foreach(var tab in tabs){
				foreach(var item in tab.pane.file_operations){
					list.add(item);
				}
			}
			return list;
		}
	}

	public int index {
		get {
			return (number - 1);
		}
	}
	
	public int number {
		get {
			if (layout_box.panel1 == this){
				return 1;
			}
			else if (layout_box.panel2 == this){
				return 2;
			}
			else if (layout_box.panel3 == this){
				return 3;
			}
			else if (layout_box.panel4 == this){
				return 4;
			}
			else{
				return 0;
			}
		}
	}
	
	public FileViewPane pane {
		get {
			return (FileViewPane) notebook.get_nth_page(notebook.page);
		}
	}

	public FileViewList view {
		get {
			return pane.view;
		}
	}

	public LayoutPanel opposite_panel {
		owned get {
			if (this == layout_box.panel1){
				return layout_box.panel2;
			}
			else if (this == layout_box.panel2){
				return layout_box.panel1;
			}
			else if (this == layout_box.panel3){
				return layout_box.panel4;
			}
			else {// if (this == layout_box.panel4){
				return layout_box.panel3;
			}
		}
	}
	
	public FileViewPane opposite_pane {
		owned get {
			return opposite_panel.pane;
		}
	}

	public bool is_left_panel {
		get {
			return (number == 1) || (number == 3);
		}
	}

	public bool is_right_panel {
		get {
			return (number == 2) || (number == 4);
		}
	}

	public bool is_top_panel {
		get {
			return (number == 1) || (number == 2);
		}
	}

	public bool is_bottom_panel {
		get {
			return (number == 3) || (number == 4);
		}
	}
}

