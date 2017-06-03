/*
 * Settings.vala
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

public class ColumnSelectionBox : Gtk.Box {

	private Gtk.TreeView treeview;
	private bool popup = false;
	
	// parents
	private FileViewPane _pane;

	private FileViewList? view{
		get{
			return (pane == null) ? null : pane.view;
		}
	}

	private FileViewPane? pane {
		get{
			if (_pane != null){
				return _pane;
			}
			else{
				return App.main_window.active_pane;
			}
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
	
	public Gtk.Window parent_window;

	// signals
	public signal void changed();

	public ColumnSelectionBox(Gtk.Window _parent_window, bool _popup){
		//base(Gtk.Orientation.VERTICAL, 6); // issue with vala
		Object(orientation: Gtk.Orientation.VERTICAL, spacing: 12); // work-around
		margin = 6;

		log_debug("ColumnSelectionBox()");
		
		parent_window = _parent_window;

		popup = _popup;
		
		init_ui();
	}
	
	// list view options -----------------------------------

	private void init_ui() {

		Gtk.Box box;
		if (popup){
			box = new Gtk.Box(Orientation.VERTICAL, 0);
		}
		else{
			box = new Gtk.Box(Orientation.HORIZONTAL, 6);
		}
		this.add(box);

		init_treeview_columns(box);

		init_column_buttons(box);
	}

	private void init_treeview_columns(Gtk.Box box) {

		log_debug("ColumnSelectionBox: init_treeview_columns()");
		
		// treeview
		treeview = new Gtk.TreeView();
		treeview.get_selection().mode = SelectionMode.SINGLE;
		treeview.headers_clickable = false;
		treeview.rubber_banding = false;
		treeview.has_tooltip = false;
		//treeview.reorderable = true;
		treeview.activate_on_single_click = true;
		treeview.headers_visible = false;

		// scrolled
		var scrolled = new Gtk.ScrolledWindow(null, null);
		scrolled.set_shadow_type (ShadowType.ETCHED_IN);
		scrolled.hscrollbar_policy = PolicyType.AUTOMATIC;
		scrolled.vscrollbar_policy = PolicyType.AUTOMATIC;
		scrolled.add (treeview);
		box.add(scrolled);

		//if (true){
			scrolled.set_size_request(250,400);
		//}
		//else{
		//	scrolled.set_size_request(250,250);
		//}

		// name ----------------------------------------------

		// column
		var col = new TreeViewColumn();
		col.title = _("Name");
		col.clickable = true;
		col.resizable = true;
		col.expand = true;
		treeview.append_column(col);

		// toggle
		var cell_toggle = new CellRendererToggle ();
		cell_toggle.activatable = true;
		col.pack_start (cell_toggle, false);

		// text
		var cell_text = new CellRendererText ();
		col.pack_start (cell_text, false);

		// render text
		col.set_cell_data_func (cell_text, (cell_layout, cell, model, iter) => {
			var crt = cell as Gtk.CellRendererText;
			string name, title;
			model.get (iter, 0, out name, 1, out title, -1);
			crt.text = (title.length > 0) ? title.replace("↓","").replace("↑","").strip() : _("Indicator");
		});

		// render toggle
		col.set_cell_data_func (cell_toggle, (cell_layout, cell, model, iter) => {
			var crt = cell as Gtk.CellRendererToggle;
			string name, title;
			bool selected, enabled;
			model.get (iter, 0, out name, 1, out title, 2, out selected, 3, out enabled, -1);
			crt.active = selected;
			crt.sensitive = enabled;
		});

		// toggle handler
		cell_toggle.toggled.connect((path) => {

			TreeIter iter;
			var model = (Gtk.ListStore) treeview.model;
			model.get_iter_from_string (out iter, path);

			string name, title;
			bool selected, enabled;
			model.get (iter, 0, out name, 1, out title, 2, out selected, 3, out enabled, -1);

			selected = !selected;
			model.set (iter, 2, selected);

			apply_column_changes(!popup);
		});
	}

	private void init_column_buttons(Gtk.Box box) {

		log_debug("ColumnSelectionBox: init_column_buttons()");

		Gtk.ButtonBox bbox;
		if (popup){
			bbox = new Gtk.ButtonBox(Orientation.HORIZONTAL);
			bbox.set_layout(Gtk.ButtonBoxStyle.EXPAND);
		}
		else{
			bbox = new Gtk.ButtonBox(Orientation.VERTICAL);
			bbox.set_spacing (6);
			bbox.set_layout(Gtk.ButtonBoxStyle.START);
		}
		
		box.add(bbox);

		// reset

		var button = new Gtk.Button.with_label(_("Reset"));
		button.set_tooltip_text(_("Reset to default columns"));
		bbox.add(button);

		if (popup){
			button.label = "";
			button.image = IconManager.lookup_image("view-refresh", 16);
			button.always_show_image = true;
		}

		button.clicked.connect(()=>{
			reset_column_changes(!popup);
		});

		// set default

		/*if (!global_settings){

			button = new Gtk.Button.with_label(_("Set Default"));
			button.set_tooltip_text(_("Set selected columns as default for all panes"));
			bbox.add(button);

			button.clicked.connect(()=>{
				apply_column_changes(true);
			});
		}*/

		// move up

		button = new Gtk.Button.with_label(_("Move Up"));
		button.set_tooltip_text(_("Move selected item up"));
		bbox.add(button);

		if (popup){
			button.label = "";
			button.image = IconManager.lookup_image("up", 16);
			button.always_show_image = true;
		}

		button.clicked.connect(()=>{
			move_selected_up();
			apply_column_changes(!popup);
		});

		// move down

		button = new Gtk.Button.with_label(_("Move Down"));
		button.set_tooltip_text(_("Move selected item down"));
		bbox.add(button);

		if (popup){
			button.label = "";
			button.image = IconManager.lookup_image("down", 16);
			button.always_show_image = true;
		}

		button.clicked.connect(()=>{
			move_selected_down();
			apply_column_changes(!popup);
		});
	}

	private void reset_column_changes(bool apply_all_views){

		log_debug("ColumnSelectionBox: reset_column_changes(): all=%s".printf(apply_all_views.to_string()));
		
		if (apply_all_views){

			App.selected_columns = Main.DEFAULT_COLUMNS;

			foreach(var v in window.views){
				v.reset_columns();
			}
		}
		else{
			pane.view.reset_columns();
		}

		refresh_list_view_columns();
	}

	private void apply_column_changes(bool apply_all_views){

		log_debug("ColumnSelectionBox: apply_column_changes(): all=%s".printf(apply_all_views.to_string()));
		
		if (apply_all_views){

			App.selected_columns = get_selected_columns();

			foreach(var v in window.views){
				v.set_columns(get_selected_columns());
			}
		}
		else{
			pane.view.set_columns(get_selected_columns());
		}
	}

	private void move_selected_up(){

		log_debug("ColumnSelectionBox: move_selected_up()");
		
		var sel = treeview.get_selection();
		if (sel.count_selected_rows() > 1){
			gtk_messagebox(_("Multiple items selected"),_("Select single item to move"), window, true);
			return;
		}
		else if (sel.count_selected_rows() == 0){
			log_debug("no items selected");
			return;
		}

		Gtk.TreeModel model;
		TreeIter iter_current;
		treeview.get_selection().get_selected(out model, out iter_current);

		var iter_prev = gtk_get_iter_prev(model, iter_current);

		bool current_enabled;
		model.get (iter_current, 3, out current_enabled, -1);

		bool prev_enabled;
		model.get (iter_prev, 3, out prev_enabled, -1);

		if (!prev_enabled || !current_enabled){
			gtk_messagebox(_("Fixed Column"),_("Position of fixed columns cannot be changed"), window, true);
		}
		else{
			((Gtk.ListStore) model).move_before(ref iter_current, iter_prev);
			pane.view.set_columns(get_selected_columns());
		}
	}

	private void move_selected_down(){

		log_debug("ColumnSelectionBox: move_selected_down()");
		
		var sel = treeview.get_selection();
		if (sel.count_selected_rows() > 1){
			gtk_messagebox(_("Multiple items selected"),_("Select single item to move"), window, true);
			return;
		}
		else if (sel.count_selected_rows() == 0){
			log_debug("no items selected");
			return;
		}

		Gtk.TreeModel model;
		TreeIter iter_current;
		treeview.get_selection().get_selected(out model, out iter_current);

		var iter_next = gtk_get_iter_next(model, iter_current);

		bool current_enabled;
		model.get (iter_current, 3, out current_enabled, -1);

		bool next_enabled;
		model.get (iter_next, 3, out next_enabled, -1);

		if (!next_enabled || !current_enabled){
			gtk_messagebox(_("Fixed Column"),_("Position of fixed columns cannot be changed"), window, true);
		}
		else{
			((Gtk.ListStore) model).move_after(ref iter_current, iter_next);
			pane.view.set_columns(get_selected_columns());
		}
	}

	private string get_selected_columns(){

		string s = "";
		TreeIter iter;
		Gtk.ListStore model = (Gtk.ListStore) treeview.model;
		bool iterExists = model.get_iter_first (out iter);

		while (iterExists){

			string name;
			model.get (iter, 0, out name, -1);

			bool selected;
			model.get (iter, 2, out selected, -1);

			if (selected){
				if (s.length > 0){
					s += ",";
				}
				s += name;
			}

			iterExists = model.iter_next (ref iter);
		}

		return s;
	}

	public void refresh_list_view_columns(){

		log_debug("ColumnSelectionBox: refresh_list_view_columns()");
		
		var model = new Gtk.ListStore(4,
			typeof(string),
			typeof(string),
			typeof(bool),
			typeof(bool)
		);

		string selected_columns = App.selected_columns; //: pane.view.get_columns();

		foreach(var col in pane.view.get_all_columns()){

			string name = col.get_data<string>("name");

			if (selected_columns.contains(name)){
				append_to_list_view_columns(model, col, selected_columns);
			}
		}

		foreach(var col in pane.view.get_all_columns()){

			string name = col.get_data<string>("name");

			if (!selected_columns.contains(name)){
				append_to_list_view_columns(model, col, selected_columns);
			}
		}

		treeview.set_model(model);
		treeview.columns_autosize();

		log_debug("ColumnSelectionBox: refresh_list_view_columns(): exit");
	}

	private void append_to_list_view_columns(Gtk.ListStore model, Gtk.TreeViewColumn col, string selected_columns){

		string name = col.get_data<string>("name");

		var list_req_end = new Gee.ArrayList<string>();
		foreach(var item in Main.REQUIRED_COLUMNS_END.split(",")){
			list_req_end.add(item);
		}
		
		// skip ending columns
		if (list_req_end.contains(name)){ return; }

		TreeIter iter0;
		model.append(out iter0);
		model.set (iter0, 0, name, -1);
		model.set (iter0, 1, col.title, -1);
		model.set (iter0, 2, selected_columns.contains(name) || Main.REQUIRED_COLUMNS.contains(name), -1);
		model.set (iter0, 3, !Main.REQUIRED_COLUMNS.contains(name), -1);
	}
}




