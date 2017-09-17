/*
 * ViewPopover.vala
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

public class ViewPopover : Gtk.Popover, IPaneActive {

	private Gtk.ToggleButton btn_list;
	private Gtk.ToggleButton btn_icon;
	private Gtk.ToggleButton btn_tile;
	private Gtk.ToggleButton btn_media;

	private Gtk.ToggleButton btn_single;
	private Gtk.ToggleButton btn_dual;
	private Gtk.ToggleButton btn_horiz;
	private Gtk.ToggleButton btn_quad;

	private Gtk.Switch switch_hidden;
	private Gtk.Switch switch_sidebar;
	private Gtk.Switch switch_sort_desc;

	private Gtk.ComboBox cmb_sort_column;

	private Gtk.Box hbox_main;
	private ColumnSelectionBox box_columns;
	private Gtk.Box box_view_options;
	private Gtk.Button btn_columns;
	
	private Gtk.SizeGroup sg_label;
	private Gtk.SizeGroup sg_button_box;
	private Gtk.SizeGroup sg_switch_label;
	private Gtk.SizeGroup sg_switch;
	
	// contructors

	public ViewPopover(Gtk.Widget? _relative_to){
		//base(_relative_to); // issue with vala
		//Object(orientation: Gtk.Orientation.VERTICAL, spacing: 0); // work-around
		//parent_window = _parent_window;
		//margin = 6;

		this.relative_to = _relative_to;

		sg_label = new Gtk.SizeGroup(Gtk.SizeGroupMode.HORIZONTAL);
		sg_switch_label = new Gtk.SizeGroup(Gtk.SizeGroupMode.HORIZONTAL);
		sg_button_box = new Gtk.SizeGroup(Gtk.SizeGroupMode.HORIZONTAL);
		sg_switch = new Gtk.SizeGroup(Gtk.SizeGroupMode.HORIZONTAL);
		
		init_ui();
	}

	private void init_ui(){

		hbox_main = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
		hbox_main.margin = 6;
		this.add(hbox_main);

		var box = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
		box.margin = 6;
		hbox_main.add(box);
		box_view_options = box;
		
		add_view_mode(box);

		add_layout_mode(box);

		add_hidden_toggle(box);

		add_sidebar_toggle(box);

		add_sort_column_option(box);

		add_sort_order_toggle(box);

		add_column_selection_box();
		
		add_column_selection_button(box);
		//this.show_all();
	}

	private void add_view_mode(Gtk.Box box){

		var hbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
		box.add(hbox);
		
		var label = new Gtk.Label(_("View"));
		label.xalign = 0.0f;
		hbox.add(label);
		sg_label.add_widget(label);
		
		var bbox = new Gtk.ButtonBox(Gtk.Orientation.HORIZONTAL);
		bbox.set_layout(Gtk.ButtonBoxStyle.EXPAND);
		hbox.add(bbox);
		sg_button_box.add_widget(bbox);
		
		var button = new Gtk.ToggleButton();
		button.set_tooltip_text(_("List"));
		button.image = IconManager.lookup_image("view-list-details-symbolic", 16);
		button.always_show_image = true;
		bbox.add(button);
		btn_list = button;
		
		button = new Gtk.ToggleButton();
		button.set_tooltip_text(_("Icons"));
		button.image = IconManager.lookup_image("view-list-icons-symbolic", 16);
		button.always_show_image = true;
		bbox.add(button);
		btn_icon = button;

		button = new Gtk.ToggleButton();
		button.set_tooltip_text(_("Tiles"));
		button.image = IconManager.lookup_image("view-list-compact-symbolic", 16);
		button.always_show_image = true;
		bbox.add(button);
		btn_tile = button;

		button = new Gtk.ToggleButton();
		button.set_tooltip_text(_("Media"));
		button.image = IconManager.lookup_image("view-list-images-symbolic", 16);
		button.always_show_image = true;
		bbox.add(button);
		btn_media = button;
	}

	private void connect_view_mode_handlers(){
		btn_list.toggled.connect(on_view_button_toggled);
		btn_icon.toggled.connect(on_view_button_toggled);
		btn_tile.toggled.connect(on_view_button_toggled);
		btn_media.toggled.connect(on_view_button_toggled);
	}

	private void disconnect_view_mode_handlers(){
		btn_list.toggled.disconnect(on_view_button_toggled);
		btn_icon.toggled.disconnect(on_view_button_toggled);
		btn_tile.toggled.disconnect(on_view_button_toggled);
		btn_media.toggled.disconnect(on_view_button_toggled);
	}

	private void on_view_button_toggled(Gtk.ToggleButton button){

		disconnect_view_mode_handlers();
		btn_list.active = (button == btn_list);
		btn_icon.active = (button == btn_icon);
		btn_tile.active = (button == btn_tile);
		btn_media.active = (button == btn_media);
		connect_view_mode_handlers();
			
		if (btn_list.active){
			pane.view.set_view_mode(ViewMode.LIST);
		}
		else if (btn_icon.active){
			pane.view.set_view_mode(ViewMode.ICONS);
		}
		else if (btn_tile.active){
			pane.view.set_view_mode(ViewMode.TILES);
		}
		else if (btn_media.active){
			pane.view.set_view_mode(ViewMode.MEDIA);
		}

		btn_columns.sensitive = (pane.view.get_view_mode() == ViewMode.LIST);
	}


	private void add_layout_mode(Gtk.Box box){

		var hbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
		box.add(hbox);
		
		var label = new Gtk.Label(_("Panes"));
		label.xalign = 0.0f;
		hbox.add(label);
		sg_label.add_widget(label);
		
		var bbox = new Gtk.ButtonBox(Gtk.Orientation.HORIZONTAL);
		bbox.set_layout(Gtk.ButtonBoxStyle.EXPAND);
		hbox.add(bbox);
		sg_button_box.add_widget(bbox);
		
		var button = new Gtk.ToggleButton.with_label(_("1"));
		button.set_tooltip_text(_("Single"));
		bbox.add(button);
		btn_single = button;

		button = new Gtk.ToggleButton.with_label(_("2"));
		button.set_tooltip_text(_("Dual"));
		bbox.add(button);
		btn_dual = button;

		button = new Gtk.ToggleButton.with_label(_("2H"));
		button.set_tooltip_text(_("Horizontal"));
		bbox.add(button);
		btn_horiz = button;

		button = new Gtk.ToggleButton.with_label(_("4"));
		button.set_tooltip_text(_("Quad"));
		bbox.add(button);
		btn_quad = button;
	}

	private void connect_layout_mode_handlers(){
		btn_single.toggled.connect(on_layout_button_toggled);
		btn_dual.toggled.connect(on_layout_button_toggled);
		btn_horiz.toggled.connect(on_layout_button_toggled);
		btn_quad.toggled.connect(on_layout_button_toggled);
	}

	private void disconnect_layout_mode_handlers(){
		btn_single.toggled.disconnect(on_layout_button_toggled);
		btn_dual.toggled.disconnect(on_layout_button_toggled);
		btn_horiz.toggled.disconnect(on_layout_button_toggled);
		btn_quad.toggled.disconnect(on_layout_button_toggled);
	}

	private void on_layout_button_toggled(Gtk.ToggleButton button){

		disconnect_layout_mode_handlers();
		btn_single.active = (button == btn_single);
		btn_dual.active = (button == btn_dual);
		btn_horiz.active = (button == btn_horiz);
		btn_quad.active = (button == btn_quad);
		connect_layout_mode_handlers();
			
		if (btn_single.active){
			window.layout_box.set_panel_layout(PanelLayout.SINGLE);
		}
		else if (btn_dual.active){
			window.layout_box.set_panel_layout(PanelLayout.DUAL_VERTICAL);
		}
		else if (btn_horiz.active){
			window.layout_box.set_panel_layout(PanelLayout.DUAL_HORIZONTAL);
		}
		else if (btn_quad.active){
			window.layout_box.set_panel_layout(PanelLayout.QUAD);
		}
	}

	
	private void add_hidden_toggle(Gtk.Box box){

		var hbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 12);
		box.add(hbox);
		
		hbox.margin_top = 12;
		//var label = new Gtk.Label("");
		//hbox.add(label);
		
		
		var label = new Gtk.Label(_("Show Hidden"));
		label.xalign = 0.0f;
		hbox.add(label);
		
		sg_switch_label.add_widget(label);
		
		switch_hidden = new Gtk.Switch();
		switch_hidden.halign = Gtk.Align.END;
		hbox.add (switch_hidden);

		//sg_switch.add_widget(switch_hidden);
		
		//label = new Gtk.Label("");
		//label.hexpand = true;
		//hbox.add(label);
	}

	private void connect_hidden_mode_handlers(){
		switch_hidden.notify["active"].connect(on_hidden_mode_toggled);
	}

	private void disconnect_hidden_mode_handlers(){
		switch_hidden.notify["active"].disconnect(on_hidden_mode_toggled);
	}

	private void on_hidden_mode_toggled(){
		
		if (switch_hidden.active) {
			view.show_hidden_files = true;
		}
		else {
			view.show_hidden_files = false;
		}

		view.refresh_hidden();
	}

	
	private void add_sidebar_toggle(Gtk.Box box){

		var hbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 12);
		box.add(hbox);

		var label = new Gtk.Label(_("Show Sidebar"));
		label.xalign = 0.0f;
		hbox.add(label);

		sg_switch_label.add_widget(label);

		switch_sidebar = new Gtk.Switch();
		switch_sidebar.halign = Gtk.Align.END;
		hbox.add (switch_sidebar);
		
		//sg_switch.add_widget(switch_sidebar);
	}

	private void connect_sidebar_mode_handlers(){
		switch_sidebar.notify["active"].connect(on_sidebar_mode_toggled);
	}

	private void disconnect_sidebar_mode_handlers(){
		switch_sidebar.notify["active"].disconnect(on_sidebar_mode_toggled);
	}

	private void on_sidebar_mode_toggled(){
		App.sidebar_visible = switch_sidebar.active;
		window.sidebar.refresh_visibility();
	}


	private void add_sort_column_option(Gtk.Box box){

		var hbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 12);
		box.add(hbox);

		var label = new Gtk.Label(_("Sort By"));
		label.xalign = 0.0f;
		hbox.add(label);

		sg_switch_label.add_widget(label);

		// cmb_app
		var combo = new Gtk.ComboBox();
		//combo.set_tooltip_text(_("Default view mode to use for new panes"));
		hbox.add (combo);
		cmb_sort_column = combo;

		sg_switch.add_widget(combo);

		// add columns ----------------------
		
		var cell_text = new CellRendererText();
		combo.pack_start(cell_text, false);
		combo.set_cell_data_func (cell_text, (cell_text, cell, model, iter) => {
			Gtk.TreeViewColumn col;
			model.get (iter, 0, out col, -1);
			(cell as Gtk.CellRendererText).text = (col.title.length > 0) ? col.title.replace("↓","").replace("↑","").strip() : _("Indicator");
		});
	}

	private void connect_sort_column_handlers(){
		cmb_sort_column.changed.connect(on_sort_column_changed);
	}

	private void disconnect_sort_column_handlers(){
		cmb_sort_column.changed.disconnect(on_sort_column_changed);
	}

	private void on_sort_column_changed(Gtk.ComboBox combo){
		Gtk.TreeViewColumn col;
		TreeIter iter;
		combo.get_active_iter(out iter);
		combo.model.get(iter, 0, out col, -1);
		view.set_sort_column_by_treeviewcolumn(col);
	}

		
	private void add_sort_order_toggle(Gtk.Box box){

		var hbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 12);
		box.add(hbox);

		var label = new Gtk.Label(_("Sort Descending"));
		label.xalign = 0.0f;
		hbox.add(label);

		sg_switch_label.add_widget(label);

		switch_sort_desc = new Gtk.Switch();
		switch_sort_desc.halign = Gtk.Align.END;
		hbox.add (switch_sort_desc);
		
		//sg_switch.add_widget(switch_sort_desc);
	}

	private void connect_sort_desc_handlers(){
		switch_sort_desc.notify["active"].connect(on_sort_order_toggled);
	}

	private void disconnect_sort_desc_handlers(){
		switch_sort_desc.notify["active"].disconnect(on_sort_order_toggled);
	}

	private void on_sort_order_toggled(){
		view.set_sort_column_desc(switch_sort_desc.active);
	}

	private void add_column_selection_box(){
		box_columns = new ColumnSelectionBox(window, true);
		hbox_main.add(box_columns);
		gtk_hide(box_columns);
	}
	
	private void add_column_selection_button(Gtk.Box box){

		var label = new Gtk.Label("");
		label.vexpand = true;
		box.add(label);
		
		var hbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
		box.add(hbox);

		var bbox = new Gtk.ButtonBox(Gtk.Orientation.HORIZONTAL);
		bbox.set_layout(Gtk.ButtonBoxStyle.CENTER);
		bbox.hexpand = true;
		hbox.add(bbox);
		
		var button = new Gtk.Button.with_label(_("Select Columns"));
		button.set_tooltip_text(_("Select ListView Columns"));
		bbox.add(button);
		btn_columns = button;
		
		button.clicked.connect(()=>{
			gtk_hide(box_view_options);
			gtk_show(box_columns);
			//button.sensitive = false;
		});

		this.closed.connect(()=>{
			gtk_show(box_view_options);
			gtk_hide(box_columns);
			//button.sensitive = true;
		});
	}

	// refresh

	public void refresh() {

		if (pane == null){ return; }

		refresh_view_option();

		refresh_layout_option();
		
		refresh_hidden_option();

		refresh_sidebar_option();

		refresh_sort_column_option();

		refresh_sort_desc_option();

		box_columns.refresh_list_view_columns();

		this.show_all(); // set_no_show_all is already false
	}

	public void refresh_layout_option() {

		if (pane == null){ return; }

		disconnect_layout_mode_handlers();
		
		switch (window.layout_box.get_panel_layout()){
		case PanelLayout.SINGLE:
			btn_single.active = true;
			btn_dual.active = false;
			btn_horiz.active = false;
			btn_quad.active = false;
			break;
		case PanelLayout.DUAL_VERTICAL:
			btn_single.active = false;
			btn_dual.active = true;
			btn_horiz.active = false;
			btn_quad.active = false;
			break;
		case PanelLayout.DUAL_HORIZONTAL:
			btn_single.active = false;
			btn_dual.active = false;
			btn_horiz.active = true;
			btn_quad.active = false;
			break;
		case PanelLayout.QUAD:
			btn_single.active = false;
			btn_dual.active = false;
			btn_horiz.active = false;
			btn_quad.active = true;
			break;
		}

		connect_layout_mode_handlers();
	}

	public void refresh_view_option() {

		if (pane == null){ return; }

		disconnect_view_mode_handlers();
		
		switch (pane.view.get_view_mode()){
		case ViewMode.LIST:
			btn_list.active = true;
			btn_icon.active = false;
			btn_tile.active = false;
			btn_media.active = false;
			break;
		case ViewMode.ICONS:
			btn_list.active = false;
			btn_icon.active = true;
			btn_tile.active = false;
			btn_media.active = false;
			break;
		case ViewMode.TILES:
			btn_list.active = false;
			btn_icon.active = false;
			btn_tile.active = true;
			btn_media.active = false;
			break;
		case ViewMode.MEDIA:
			btn_list.active = false;
			btn_icon.active = false;
			btn_tile.active = false;
			btn_media.active = true;
			break;
		}

		btn_columns.sensitive = (pane.view.get_view_mode() == ViewMode.LIST);

		connect_view_mode_handlers();
	}

	public void refresh_hidden_option() {

		if (pane == null){ return; }

		disconnect_hidden_mode_handlers();
		
		switch_hidden.active = view.show_hidden_files;

		connect_hidden_mode_handlers();
	}

	public void refresh_sidebar_option() {

		if (pane == null){ return; }

		disconnect_sidebar_mode_handlers();
		
		switch_sidebar.active = App.sidebar_visible;

		connect_sidebar_mode_handlers();
	}

	public void refresh_sort_column_option() {

		if (pane == null){ return; }

		disconnect_sort_column_handlers();

		// add items ----------------------
		
		var store = new Gtk.ListStore(1, typeof(TreeViewColumn));

		TreeIter iter;
		int active = 0;
		int index = -1;
		foreach(var col in view.get_all_columns()){
			
			var col_index = col.get_data<FileViewColumn>("index");
			if (col_index == FileViewColumn.UNSORTABLE) { continue; }

			index++;
			
			if (view.get_sort_column_index() == col_index){
				active = index;
			}
			
			store.append(out iter);
			store.set (iter, 0, col, -1);
		}

		cmb_sort_column.set_model(store);
		cmb_sort_column.set_active(active);

		connect_sort_column_handlers();
	}

	public void refresh_sort_desc_option() {

		if (pane == null){ return; }

		disconnect_sort_desc_handlers();
		
		switch_sort_desc.active = view.get_sort_column_desc();

		connect_sort_desc_handlers();
	}
}




