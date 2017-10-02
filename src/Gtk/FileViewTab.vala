/*
 * FileViewTab.vala
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

public class FileViewTab : Gtk.Box {

	// reference properties ----------

	protected MainWindow window {
		get { return App.main_window; }
	}
	
	public LayoutPanel panel; // public, will be referenced by pane

	// -------------------------------
	
	private Gtk.Label tab_label;
	private Gtk.Entry tab_entry;
	private Gtk.EventBox ebox_close;
	private Gtk.Image img_active;
	private Gtk.Image img_locked;
	public FileViewPane pane;
	public bool renamed = false;
	private Gtk.Menu menu_tab;
	public string locked_path = "";

	private int TAB_NAME_MAX_LENGTH = 20;

	// parents
	public Gtk.Notebook notebook;

	public FileViewTab(LayoutPanel parent_panel, Gtk.Notebook parent_notebook){
		//base(Gtk.Orientation.VERTICAL, 6); // issue with vala
		Object(orientation: Gtk.Orientation.VERTICAL, spacing: 0); // work-around
		
		log_debug("FileViewTab: ----------------------------");

		panel = parent_panel;
		notebook = parent_notebook;

		// pane is set by init_tab()
		
		//var timer = timer_start();
		
		init_tab();

		//log_trace("tab initialized: %s".printf(timer_elapsed_string(timer)));

		log_debug("FileViewTab: created --------------------");
	}

	public FileViewList view{
		get{
			return pane.view;
		}
	}
	
	private void init_tab(){

		// add label ------------------------------------
		
		var box_label = new Gtk.Box(Orientation.HORIZONTAL, 0);
		//add_active_icon(box_label);

		add_locked_icon(box_label);
		
		var ebox_label = gtk_add_event_box(box_label);
		tab_label = new Gtk.Label(App.user_name);
		//tab_label.hexpand = true;
		ebox_label.add(tab_label);

		tab_entry = new Gtk.Entry();
		tab_entry.xalign = 0.0f;
		tab_entry.text = tab_label.label;
		box_label.add(tab_entry);
		
		tab_entry.set_no_show_all(true);
		
		tab_entry.select_region(0,tab_entry.text.length);

		tab_entry.activate.connect(()=>{
			_tab_name = tab_entry.text;
			tab_label.label = _tab_name;
			renamed = true;
			gtk_hide(tab_entry);
			gtk_show(tab_label);
			window.update_accelerators_for_active_pane();
		});

		tab_entry.focus_out_event.connect((event) => {
			//log_debug("tab_entry.focus_out_event");
			tab_entry.activate();
			window.update_accelerators_for_active_pane();
			return true;
		});

		if (App.tabs_close_visible){
			add_close_button(box_label);
		}

		box_label.show_all();
		
		// add tab content ------------------------------------

        log_debug("FileViewTab: notebook.append_page()");

		pane = new FileViewPane(this);
        pane.margin = 0;
        
        notebook.append_page(pane, box_label);
        notebook.set_tab_reorderable(pane, true);
        notebook.set_tab_detachable(pane, true);
        notebook.show_all();

        // connect mouse right-click
		ebox_label.button_press_event.connect((event) => {
			/*if (event.button == 1) {
				if (pane.tab.renamed && pane.tab.tab_name == "+"){
					panel.create_new_tab_from_pane(pane);
				}
			}
			else*/
			if (event.button == 2) {
				close_tab();
			}
			else if (event.button == 3) {
				return menu_tab_popup(null);
			}
			return false;
		});

		// connect shift+F10
        ebox_label.popup_menu.connect(() => {
			return menu_tab_popup(null);
		});

	}

	public bool is_dummy {
		get {
			return (panel.dummy_tab == this);
		}
	}

	private void add_active_icon(Gtk.Box box){
		var img = IconManager.lookup_image("item-gray",16);
		img_active = img;
		box.add(img);

		refresh_active_indicator();
	}
	
	public void refresh_active_indicator(){

		/*
		string tt = "";
		if (window.active_pane == pane){
			img_active.pixbuf = IconManager.lookup_image("item-blue",16).pixbuf;
			tt = _("This pane is active");
		}
		else{
			img_active.pixbuf = IconManager.lookup_image("item-gray",16).pixbuf;
			tt = _("This pane is inactive.\n\nClick anywhere on this pane to make it active.");
		}

		img_active.set_tooltip_text(tt);
		img_active.set_tooltip_text(tt);
		* */

		if (window.active_pane == pane){
			tab_label.set_use_markup(true);
			tab_label.label = "<b>%s</b>".printf(_tab_name);

			pane.view.set_active_indicator(true);
			pane.set_active_indicator(true);
		}
		else{
			tab_label.set_use_markup(false);
			tab_label.label = tab_name;

			pane.view.set_active_indicator(false);
			pane.set_active_indicator(false);
		}
	}

	private void add_close_button(Gtk.Box box){
		
		var img = IconManager.lookup_image("tab-close", 16, false, true);
		var ebox = new Gtk.EventBox();
		ebox.margin_left = 10;
		ebox.add(img);
		box.add(ebox);
		ebox_close = ebox;
		
		set_pointer_cursor_for_eventbox(ebox);

		// click event
		
		ebox.button_press_event.connect((event)=>{
			if (event.button == 1) {
				close_tab();
			}
			return true;
		});
	}

	private void add_locked_icon(Gtk.Box box){
		
		var img = IconManager.lookup_image("lock-symbolic", 16, false, true);
		box.add(img);
		img_locked = img;

		gtk_hide(img_locked);
	}

	private bool menu_tab_popup (Gdk.EventButton? event) {

		log_debug("FileViewTab: menu_tab_popup()");
		
		menu_tab = new Gtk.Menu();
		menu_tab.reserve_toggle_size = false;
		
		// set tab name --------------
		
		var menu_item = new Gtk.MenuItem();
		menu_tab.append(menu_item);
		
		var lbl = new Gtk.Label(_("Edit Name"));
		lbl.xalign = 0.0f;
		lbl.margin_right = 6;
		menu_item.add(lbl);

		menu_item.activate.connect (() => {
			tab_entry.text = _tab_name;
			gtk_hide(tab_label);
			gtk_show(tab_entry);
			tab_entry.grab_focus();
			window.update_accelerators_for_edit();
		});

		// reset tab name ---------------
		
		menu_item = new Gtk.MenuItem();
		menu_tab.append(menu_item);
		
		lbl = new Gtk.Label(_("Reset Name"));
		lbl.xalign = 0.0f;
		lbl.margin_right = 6;
		lbl.sensitive = renamed;
		menu_item.add(lbl);

		menu_item.activate.connect (() => {
			renamed = false;
			tab_name = pane.view.current_item.file_name;
		});

		gtk_menu_add_separator(menu_tab);

		// lock path ---------------
		
		menu_item = new Gtk.MenuItem();
		menu_tab.append(menu_item);
		
		lbl = new Gtk.Label(_("Lock Path"));
		lbl.xalign = 0.0f;
		lbl.margin_right = 6;
		lbl.sensitive = true;
		menu_item.add(lbl);

		menu_item.activate.connect (() => {
			lock_path();
		});

		// unlock path ---------------
		
		menu_item = new Gtk.MenuItem();
		menu_tab.append(menu_item);
		
		lbl = new Gtk.Label(_("Unlock Path"));
		lbl.xalign = 0.0f;
		lbl.margin_right = 6;
		lbl.sensitive = (locked_path.length > 0);
		menu_item.add(lbl);

		menu_item.activate.connect (() => {
			unlock_path();
		});

		gtk_menu_add_separator(menu_tab);

		// close tab ---------------
		
		menu_item = new Gtk.MenuItem();
		menu_tab.append(menu_item);
		
		lbl = new Gtk.Label(_("Close"));
		lbl.xalign = 0.0f;
		lbl.margin_right = 6;
		menu_item.add(lbl);

		menu_item.activate.connect (() => {
			close_tab();
		});

		menu_tab.show_all();
		
		if (event != null) {
			menu_tab.popup (null, null, null, event.button, event.time);
		}
		else {
			menu_tab.popup (null, null, null, 0, Gtk.get_current_event_time());
		}

		return true;
	}

	// helpers ------------------

	private string _tab_name;
	public string tab_name{
		owned get{
			return _tab_name;
		}
		set{
			if (value == "+"){
				ebox_close.hide();
				renamed = true;
				_tab_name = value;
				tab_label.label = _tab_name;
				tab_label.set_tooltip_text(_("New Tab"));
			}
			else if (value.length == 0){
				ebox_close.show_all();
				renamed = false;
				_tab_name = App.user_name;
				tab_label.label = _tab_name;
				tab_label.set_tooltip_text(null);
			}
			else{
				if (!renamed){
					string title = value;
					title = (title.length > TAB_NAME_MAX_LENGTH) ? title[0:TAB_NAME_MAX_LENGTH-1] : title;
					_tab_name = title;
					tab_label.label = _tab_name;
					tab_label.set_tooltip_text(null);
				}
			}
			
			refresh_active_indicator();
		}
	}

	public int tab_index{
		get {
			return notebook.page_num(pane);
		}
	}
	
	public void close_tab(){

		log_debug("FileViewTab: close_tab()");

		if (show_file_operation_warning_on_close() == Gtk.ResponseType.NO){
			return;
		}

		panel.notebook_switch_page_disconnect();

		var index = tab_index;
		panel.tabs.remove(this);
		notebook.remove_page(tab_index);

		/*if (index > 0){
			notebook.page = index - 1;
		}
		else{
			notebook.page = 0;
		}*/

		view.cancel_monitors();
		
		panel.notebook_switch_page_connect();

		window.active_pane = panel.pane;

		window.update_accelerators_for_active_pane();
	}

	public void select_tab(){
		notebook.page = tab_index;
	}

	public void lock_path(){
		
		locked_path = pane.view.current_item.display_path;
		gtk_show(img_locked);

		if (!renamed){
			tab_name = tab_name;
			renamed = true;
		}
	}

	public void unlock_path(){
		
		locked_path = "";
		gtk_hide(img_locked);
	}

	public void refresh_lock_icon(){
		
		if (locked_path.length > 0){
			gtk_show(img_locked);
		}
		else{
			gtk_hide(img_locked);
		}
	}
	
	public Gtk.ResponseType show_file_operation_warning_on_close(){
		
		var response = Gtk.ResponseType.YES;

		var list = pane.file_operations;
		
		if (list.size > 0){
			string title = _("Cancel File Operations?");
			string msg = _("Closing this pane will cancel file operations running in this pane.\nDo you want to cancel?");
			response = gtk_messagebox_yes_no(title, msg, window);

			if (response == Gtk.ResponseType.YES){
				foreach(var action in list){
					action.cancel();
				}
				sleep(1000);
			}
		}

		return response;
	}

}

