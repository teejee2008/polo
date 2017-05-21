/*
 * LayoutBox.vala
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

public class LayoutBox : Gtk.Box {

	public Gtk.Paned paned_quad;
	public Gtk.Paned paned_dual_top;
	public Gtk.Paned paned_dual_bottom;
	public MiddleToolbar middlebar;

	public Gee.ArrayList<LayoutPanel> panels = new Gee.ArrayList<LayoutPanel>();

	private PanelLayout panel_layout;
	private PanelLayout panel_layout_saved;

	// parents
	public MainWindow window;

	// temp
	private int paned_quad_position;
	private int paned_dual_top_position;
	private int paned_dual_bottom_position;

	// signals
	public signal void panel1_changed();
	public signal void panel2_changed();
	public signal void panel3_changed();
	public signal void panel4_changed();

	public LayoutBox(){
		//base(Gtk.Orientation.VERTICAL, 6); // issue with vala
		Object(orientation: Gtk.Orientation.VERTICAL, spacing: 0); // work-around

		log_debug("LayoutBox(): ----------------------------");

		window = App.main_window;

		//var timer = timer_start();

		init_panels();

		//log_trace("tab initialized: %s".printf(timer_elapsed_string(timer)));

		log_debug("LayoutBox(): created --------------------");
	}

	private void init_panels(){

		log_debug("LayoutBox(): init_panels()");

		// add a vertical pane (paned_quad) to the tab

		var paned = new Gtk.Paned (Gtk.Orientation.VERTICAL);
		add(paned);
		paned_quad = paned;

		// add 2 horizontal panes to the upper and lower panes of paned_quad

		var pane = new Gtk.Paned (Gtk.Orientation.HORIZONTAL);
		paned_dual_top = pane;

		pane = new Gtk.Paned (Gtk.Orientation.HORIZONTAL);
		paned_dual_bottom = pane;

		paned_quad.pack1(paned_dual_top, true, true); // resize, shrink
		paned_quad.pack2(paned_dual_bottom, true, true); // resize, shrink

		// add views to all the 4 panes

		var panel = new LayoutPanel(this);
		paned_dual_top.pack1(panel, true, true); // resize, shrink
		panels.add(panel);

		panel = new LayoutPanel(this, true);
		paned_dual_top.pack2(panel, true, true); // resize, shrink
		panels.add(panel);

		panel = new LayoutPanel(this);
		paned_dual_bottom.pack1(panel, true, true); // resize, shrink
		panels.add(panel);

		panel = new LayoutPanel(this);
		paned_dual_bottom.pack2(panel, true, true); // resize, shrink
		panels.add(panel);

		panel_layout = App.panel_layout;

		middlebar.refresh();

	}

	public LayoutPanel panel1 {
		owned get {
			return panels[0];
		}
	}

	public LayoutPanel panel2 {
		owned get {
			return panels[1];
		}
	}

	public LayoutPanel panel3 {
		owned get {
			return panels[2];
		}
	}

	public LayoutPanel panel4 {
		owned get {
			return panels[3];
		}
	}


	public PanelLayout get_panel_layout(){
		return panel_layout;
	}

	public void apply_panel_layout(){
		set_panel_layout(panel_layout);
	}

	public void set_panel_layout(PanelLayout layout, bool set_default = true){

		gtk_do_events();

		panel_layout = layout;

		log_debug("LayoutBox: set_panel_layout(): %s".printf(layout.to_string()));

		bool reset_positions = false;

		if (layout == PanelLayout.SINGLE){

			if (panel1.visible){
				gtk_hide(panel2);
				gtk_hide(panel3);
				gtk_hide(panel4);
				reset_positions = true;
			}
			else if (panel2.visible){
				gtk_hide(panel1);
				gtk_hide(panel3);
				gtk_hide(panel4);
				reset_positions = true;
			}
			else if (panel3.visible){
				gtk_hide(panel1);
				gtk_hide(panel2);
				gtk_hide(panel4);
				reset_positions = true;
			}
			else if (panel4.visible){
				gtk_hide(panel1);
				gtk_hide(panel2);
				gtk_hide(panel3);
				reset_positions = true;
			}
			else{
				// all panes closed?
				gtk_show(panel1);
				reset_positions = true;
			}
		}
		else if (layout == PanelLayout.DUAL_VERTICAL){

			if (panel1.visible || panel2.visible){

				if (!panel1.visible){
					gtk_show(panel1);
					reset_positions = true;
				}

				if (!panel2.visible){
					gtk_show(panel2);
					reset_positions = true;
				}

				if (panel3.visible){
					gtk_hide(panel3);
					reset_positions = true;
				}

				if (panel4.visible){
					gtk_hide(panel4);
					reset_positions = true;
				}
			}
			else if (panel3.visible || panel4.visible){

				if (panel1.visible){
					gtk_hide(panel1);
					reset_positions = true;
				}

				if (panel2.visible){
					gtk_hide(panel2);
					reset_positions = true;
				}

				if (!panel3.visible){
					gtk_show(panel3);
					reset_positions = true;
				}

				if (!panel4.visible){
					gtk_show(panel4);
					reset_positions = true;
				}
			}
			else{
				// all panes closed?
				gtk_show(panel1);
				gtk_show(panel2);
				reset_positions = true;
			}
		}
		else if (layout == PanelLayout.DUAL_HORIZONTAL){

			if (panel1.visible || panel3.visible){

				if (!panel1.visible){
					gtk_show(panel1);
					reset_positions = true;
				}

				if (!panel3.visible){
					gtk_show(panel3);
					reset_positions = true;
				}

				if (panel2.visible){
					gtk_hide(panel2);
					reset_positions = true;
				}

				if (panel4.visible){
					gtk_hide(panel4);
					reset_positions = true;
				}
			}
			else if (panel2.visible || panel4.visible){

				if (!panel2.visible){
					gtk_show(panel2);
					reset_positions = true;
				}

				if (!panel4.visible){
					gtk_show(panel4);
					reset_positions = true;
				}

				if (panel1.visible){
					gtk_hide(panel1);
					reset_positions = true;
				}

				if (panel3.visible){
					gtk_hide(panel3);
					reset_positions = true;
				}
			}
			else{
				// all panes closed?
				gtk_show(panel1);
				gtk_show(panel3);
				reset_positions = true;
			}
		}
		else if (layout == PanelLayout.QUAD){

			if (!panel1.visible){
				gtk_show(panel1);
				reset_positions = true;
			}

			if (!panel2.visible){
				gtk_show(panel2);
				reset_positions = true;
			}

			if (!panel3.visible){
				gtk_show(panel3);
				reset_positions = true;
			}

			if (!panel4.visible){
				gtk_show(panel4);
				reset_positions = true;
			}
		}
		else{ // PanelLayout.CUSTOM
			//reset_positions = true;
		}

		//if (reset_positions){
		reset_pane_positions();
		//}

		if (set_default){
			App.panel_layout = panel_layout;
		}

		foreach(var pane in App.main_window.panes){
			pane.pathbar.refresh_icon_visibility();
			pane.statusbar.refresh_for_layout_change();
		}

		if ((window.active_pane != null) && !window.active_pane.panel.visible){
			
			if (window.layout_box.panel1.visible){
				window.active_pane = window.layout_box.panel1.pane;
			}
			else if (window.layout_box.panel2.visible){
				window.active_pane = window.layout_box.panel2.pane;
			}
			else if (window.layout_box.panel3.visible){
				window.active_pane = window.layout_box.panel3.pane;
			}
			else if (window.layout_box.panel4.visible){
				window.active_pane = window.layout_box.panel4.pane;
			}
		}

		window.layout_box.middlebar.refresh_visibility();
		window.statusbar.refresh_for_layout_change();
		//refresh_pathbars();

		/*
		log_debug("paned_quad.get_allocated_width()=%d".printf(paned_quad.get_allocated_width()));
		log_debug("paned_quad.get_allocated_height()=%d".printf(paned_quad.get_allocated_height()));
		log_debug("paned_quad.position=%d".printf(paned_quad.position));
		log_debug("paned_dual_top.position=%d".printf(paned_dual_top.position));
		log_debug("paned_dual_bottom.position=%d".printf(paned_dual_bottom.position));
		log_debug("paned_dual_bottom.get_allocated_width()=%d".printf(paned_dual_bottom.get_allocated_width()));
		log_debug("paned_dual_bottom.get_allocated_height()=%d".printf(paned_dual_bottom.get_allocated_height()));
		*/
	}

	public void save_panel_layout(){
		log_debug("LayoutBox: save_panel_layout()");
		gtk_do_events();
		panel_layout_saved = panel_layout;
		gtk_do_events();
	}

	public void restore_panel_layout(){
		log_debug("LayoutBox: restore_panel_layout()");
		gtk_do_events();
		set_panel_layout(panel_layout_saved);
		gtk_do_events();
	}

	public void save_pane_positions(){

		log_debug("LayoutBox: save_pane_positions()");

		gtk_do_events();

		paned_quad_position = paned_quad.position;
		paned_dual_top_position = paned_dual_top.position;
		paned_dual_bottom_position = paned_dual_bottom.position;

		gtk_do_events();
	}

	public void restore_pane_positions(){

		log_debug("LayoutBox: restore_pane_positions()");

		gtk_do_events();

		if ((paned_quad_position == 0) && (paned_dual_top_position == 0) && (paned_dual_bottom_position == 0)){
			return;
		}

		paned_quad.set_position(paned_quad_position);
		paned_dual_top.set_position(paned_dual_top_position);
		paned_dual_bottom.set_position(paned_dual_bottom_position);

		paned_quad_position = 0;
		paned_dual_top_position = 0;
		paned_dual_bottom_position = 0;

		gtk_do_events();
	}

	public void reset_pane_positions(){

		log_debug("LayoutBox: reset_pane_positions()");

		gtk_do_events();

		int pos_width = paned_quad.get_allocated_width();
		int pos_height = paned_quad.get_allocated_height();

		int pos_width_half = (int) (pos_width / 2);
		int pos_height_half = (int) (pos_height / 2);

		if ((panel1.visible || panel2.visible) && (panel3.visible || panel4.visible)){
			paned_quad.set_position(pos_height_half);
		}
		else {
			paned_quad.set_position(pos_height);
		}

		if (panel1.visible && panel2.visible){
			paned_dual_top.set_position(pos_width_half);
		}
		else {
			paned_dual_top.set_position(pos_width);
		}

		if (panel3.visible && panel4.visible){
			paned_dual_bottom.set_position(pos_width_half);
		}
		else {
			paned_dual_bottom.set_position(pos_width);
		}

		gtk_do_events();
	}

	public int get_visible_pane_count(){
		int count = 0;
		if (panel1.visible){ count++; }
		if (panel2.visible){ count++; }
		if (panel3.visible){ count++; }
		if (panel4.visible){ count++; }
		return count;
	}

	public bool layout_is_vertical(){
		return (panel1.visible || panel2.visible) && (panel3.visible || panel4.visible);
	}

	public Gee.ArrayList<ProgressPanel> file_operations {
		owned get {
			var list = new Gee.ArrayList<ProgressPanel>();
			foreach(var panel in panels){
				foreach(var item in panel.file_operations){
					list.add(item);
				}
			}
			return list;
		}
	}

	public Gtk.ResponseType show_file_operation_warning_on_close(){

		var response = Gtk.ResponseType.YES;

		var list = file_operations;

		if (list.size > 0){
			string title = _("Cancel File Operations?");
			string msg = _("Closing this tab will cancel file operations running in this tab.\nDo you want to cancel?");
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

	public bool show_file_operation_warning_on_layout_change(){

		if (file_operations.size > 0){
			string title = _("Layout Cannot be Changed");
			string msg = _("Layout cannot be changed while file operations are running");
			gtk_messagebox(title, msg, window, true);
			return false;
		}

		return true;
	}

	// actions

	public void open_panel1_location_in_panel2(){
		panel1.view.open_location_in_opposite_pane();
	}

	public void open_panel2_location_in_panel1(){
		panel2.view.open_location_in_opposite_pane();
	}

	// refresh

	public void refresh(){

		log_debug("LayoutBox: refresh()");

		refresh_layout();

		//refresh_panes();
	}

	public void refresh_layout(){
		set_panel_layout(panel_layout);
	}

	public void refresh_pathbar(){
		foreach(var panel in panels){
			foreach(var tab in panel.tabs){
				tab.pane.pathbar.refresh();
			}
		}
	}

	public void refresh_for_active_pane(){
		
		foreach(var panel in panels){
			foreach(var tab in panel.tabs){
				tab.refresh_active_indicator();
			}
		}
		
		middlebar.refresh_for_active_pane();
	}
}

