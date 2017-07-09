/*
 * SelectionBar.vala
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

public class SelectionBar : Gtk.Box {

	private FileViewPane pane;
	private FileViewList view;
	private MainWindow window;

	private Gtk.Entry txt_pattern;
	private Gtk.RadioButton opt_select;
	private Gtk.RadioButton opt_filter;

	private Gtk.Box hbox;

	public string text {
		owned get {
			return txt_pattern.text;
		}
	}

	public SelectionBar(FileViewPane parent_pane){
		//base(Gtk.Orientation.VERTICAL, 6); // issue with vala
		Object(orientation: Gtk.Orientation.VERTICAL, spacing: 6); // work-around
		margin = 6;
		log_debug("SelectionBar()");

		pane = parent_pane;
		view = parent_pane.view;
		window = App.main_window;

		init_ui();

		gtk_hide(this);
	}

	private void init_ui(){

		hbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
		add(hbox);

		//var label = new Gtk.Label(_("Pattern:"));
		//label.xalign = (float) 0.0;
		//hbox.add(label);
		
		add_entry();

		add_toggle_buttons();

		add_close_button();

		var separator = new Gtk.Separator(Gtk.Orientation.HORIZONTAL);
		//separator.margin_left = 24;
		add(separator);
	}

	private void add_entry(){

		var txt = new Gtk.Entry();
		txt.xalign = 0.0f;
		txt.hexpand = true;
		txt.margin = 0;
		hbox.add(txt);

		txt.placeholder_text = _("Enter pattern for selecting or filtering items in view");

		txt_pattern = txt;

		txt.activate.connect(()=>{
			execute_action();
		});

		txt.focus_out_event.connect((event) => {
			txt.activate();
			return false;
		});

		// connect signal for shift+F10
        txt.popup_menu.connect(() => {
			return true; // suppress right-click menu
		});

        // connect signal for right-click
		txt.button_press_event.connect((w, event) => {
			if (event.button == 3) { return true; } // suppress right-click menu
			return false;
		});

		txt.key_press_event.connect((event) => {
			add_action_delayed();
			return false;
		});
		
		//txt.set_no_show_all(true);
	}

	private void add_toggle_buttons(){

		var button = new Gtk.RadioButton.with_label_from_widget (null, _("Select"));
		hbox.add(button);
		opt_select = button;

		button.toggled.connect(()=>{
			if (opt_select.active){
				view.clear_filter(); // clear filter if any before selection
				execute_action();
			}
		});
		
		button = new Gtk.RadioButton.with_label_from_widget (button, _("Filter"));
		hbox.add(button);
		opt_filter = button;

		button.toggled.connect(()=>{
			if (opt_filter.active){
				execute_action();
			}
		});
	}

	private void add_close_button(){

		var button = new Gtk.Button.with_label(_("Close"));
		hbox.add(button);
		
		button.clicked.connect((event) => {
			close_panel(true);
		});
	}

	public void toggle(bool filter_mode){
		
		if (this.visible){
			close_panel(true);
		}
		else{
			open_panel("", filter_mode);
		}
	}
	
	public void open_panel(string initial_text, bool filter_mode){

		if (this.visible) { return; }

		log_debug("SelectionBar: show_panel()");
		
		txt_pattern.text = initial_text;
		txt_pattern.grab_focus_without_selecting();
		txt_pattern.move_cursor(Gtk.MovementStep.BUFFER_ENDS, 1, false);

		if (filter_mode){
			opt_filter.active = true;
		}
		else{
			opt_select.active = true;
		}
		
		execute_action();
		
		gtk_show(this);
	}

	public void close_panel(bool force){

		if (!this.visible) { return; }
		
		log_debug("SelectionBar: hide_panel()");

		if (opt_filter.active){
			if (force){
				view.clear_filter();
			}
			else{
				return;
			}
		}
			
		txt_pattern.text = "";
		view.clear_filter(); // always clear
		gtk_hide(this);
	}

	private uint tmr_action = 0;
	
	private void add_action_delayed(){
		clear_action_delayed();
		tmr_action = Timeout.add(200, execute_action);
	}

	private void clear_action_delayed(){
		if (tmr_action > 0){
			Source.remove(tmr_action);
			tmr_action = 0;
		}
	}

	private bool execute_action(){

		clear_action_delayed();
		
		if (opt_select.active){
			select_items_by_pattern();
		}
		else{
			filter_items_by_pattern();
		}

		return false;
	}
	
	private void select_items_by_pattern(){

		if (view.current_item == null) { return; }
		if (!view.current_item.is_local) { return; }

		log_debug("SelectionBar: select_items_by_pattern()");

		view.clear_selections();

		if (txt_pattern.text.length == 0){ return; }
			
		var list = new Gee.ArrayList<string>();
		foreach(var item in view.current_item.children.values){
			if (item.file_name.down().contains(txt_pattern.text)){
				list.add(item.file_path);
			}
		}

		if (list.size == 0){ return; }

		view.select_items_by_file_path(list);

		view.scroll_to_item_by_file_path(list[0]);
	}

	private void filter_items_by_pattern(){

		clear_action_delayed();

		if (view.current_item == null) { return; }
		if (!view.current_item.is_local) { return; }

		log_debug("SelectionBar: filter_items_by_pattern()");

		view.filter(txt_pattern.text);
	}

}

