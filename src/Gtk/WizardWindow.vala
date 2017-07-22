/*
 * FileConflictWindow.vala
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

public class WizardWindow : Gtk.Window {

	private Gtk.Box vbox_main;
	//private string mode = "";
	
	public WizardWindow() {

		set_transient_for(App.main_window);
		set_modal(true);
		//set_type_hint(Gdk.WindowTypeHint.DIALOG);  // Do not use; Hides close button on some window managers
		set_skip_taskbar_hint(true);
		set_skip_pager_hint(true);
		window_position = WindowPosition.CENTER_ON_PARENT;
		deletable = true;
		resizable = true;
		icon = get_app_icon(16,".svg");
		title = _("Style Wizard");

		// set content area
		vbox_main = new Gtk.Box(Gtk.Orientation.VERTICAL, 12);
		vbox_main.margin = 12;
		add(vbox_main);

		//mode = _mode;

		init_ui();
	}

	private void init_ui(){
		
		/*switch(mode){
		case "":
		case "":
		}*/
		
		init_layout_style();
	}
	
	private void init_layout_style(){

		add_label_header(vbox_main, _("Select Layout Style"), true);

		var hbox = new Gtk.Box(Orientation.HORIZONTAL, 12);
		vbox_main.add(hbox);

		// classic sidebar icons
		var ebox = add_layout_option(hbox, IconManager.lookup("polo_layout_classic_icons", 500), _("Classic Icons (Single-pane + Sidebar + IconView)"));
		ebox.button_press_event.connect((event)=>{
			App.main_window.sidebar.sidebar_show();

			App.main_window.layout_box.set_panel_layout(PanelLayout.SINGLE);
			App.main_window.layout_box.panel1.pane.view.set_view_mode(ViewMode.ICONS);
			App.save_app_config();

			//init_pathbar_style();
			this.close();
			return true;
		});

		ebox = add_layout_option(hbox, IconManager.lookup("polo_layout_classic_list", 500), _("Classic List (Single-pane + Sidebar + ListView)"));
		ebox.button_press_event.connect((event)=>{
			App.main_window.sidebar.sidebar_show();

			App.main_window.layout_box.set_panel_layout(PanelLayout.SINGLE);
			App.main_window.layout_box.panel1.pane.view.set_view_mode(ViewMode.LIST);
			App.save_app_config();

			//init_pathbar_style();
			this.close();
			return true;
		});

		hbox = new Gtk.Box(Orientation.HORIZONTAL, 12);
		vbox_main.add(hbox);

		ebox = add_layout_option(hbox, IconManager.lookup("polo_layout_commander_list", 500), _("Commander (Dual-pane + ListView)"));
		ebox.button_press_event.connect((event)=>{
			App.main_window.sidebar.sidebar_hide();
			App.main_window.layout_box.set_panel_layout(PanelLayout.DUAL_VERTICAL);
			App.main_window.layout_box.panel1.pane.view.set_view_mode(ViewMode.LIST);
			App.main_window.layout_box.panel2.pane.view.set_view_mode(ViewMode.LIST);
			App.save_app_config();

			//init_pathbar_style();
			this.close();
			return true;
		});

		ebox = add_layout_option(hbox, IconManager.lookup("polo_layout_commander_icons", 500), _("Commander Icons (Dual-pane + IconView)"));
		ebox.button_press_event.connect((event)=>{
			App.main_window.sidebar.sidebar_hide();
			App.main_window.layout_box.set_panel_layout(PanelLayout.DUAL_VERTICAL);
			App.main_window.layout_box.panel1.pane.view.set_view_mode(ViewMode.ICONS);
			App.main_window.layout_box.panel2.pane.view.set_view_mode(ViewMode.ICONS);
			App.save_app_config();

			//init_pathbar_style();
			this.close();
			return true;
		});

		this.show_all();
	}

	private Gtk.EventBox add_layout_option(Gtk.Box hbox, Gdk.Pixbuf pix, string label){

		var vbox = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
		hbox.add(vbox);

		var img = new Gtk.Image.from_pixbuf(pix);
		
		var ebox = new Gtk.EventBox();
		ebox.add(img);
		vbox.add(ebox);
		
		ebox.set_tooltip_text(_("Click to select"));

		// set hand cursor
		if (ebox.get_realized()){
			ebox.get_window().set_cursor(new Gdk.Cursor(Gdk.CursorType.HAND1));
		}
		else{
			ebox.realize.connect(()=>{
				ebox.get_window().set_cursor(new Gdk.Cursor(Gdk.CursorType.HAND1));
			});
		}

		add_label(vbox, label);

		return ebox;
	}

	private void init_pathbar_style(){

		/*gtk_container_remove_children(vbox_main);
		
		add_label_header(vbox_main, _("Select Pathbar Style"), true);

		var vbox = new Gtk.Box(Orientation.VERTICAL, 12);
		vbox_main.add(vbox);

		// classic sidebar icons
		var ebox = add_layout_option(vbox, IconManager.lookup("polo_pathbar_links", 400), _("Links"));
		ebox.button_press_event.connect((event)=>{
			
			App.pathbar_use_buttons = false;
			App.save_app_config();
			
			foreach(var pn in App.main_window.panes){
				pn.pathbar.refresh();
			}
			App.main_window.pathbar.refresh();
			
			this.close();
			return true;
		});

		ebox = add_layout_option(vbox, IconManager.lookup("polo_pathbar_buttons", 400), _("Buttons"));
		ebox.button_press_event.connect((event)=>{
			
			App.pathbar_use_buttons = true;
			App.pathbar_flat_buttons = false;
			App.save_app_config();
			
			foreach(var pn in App.main_window.panes){
				pn.pathbar.refresh();
			}
			App.main_window.pathbar.refresh();
			
			this.close();
			return true;
		});

		ebox = add_layout_option(vbox, IconManager.lookup("polo_pathbar_buttons_flat", 400), _("Flat Buttons"));
		ebox.button_press_event.connect((event)=>{
			
			App.pathbar_use_buttons = true;
			App.pathbar_flat_buttons = true;
			App.save_app_config();
			
			foreach(var pn in App.main_window.panes){
				pn.pathbar.refresh();
			}
			App.main_window.pathbar.refresh();
			
			this.close();
			return true;
		});

		this.show_all();*/
	}
}


