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
	private Gtk.Box vbox_layout_option;
	private LayoutStyle current_layout_option = LayoutStyle.SINGLE_ICONS;
	//private string mode = "";

	enum LayoutStyle {
		SINGLE_ICONS = 1,
		SINGLE_LIST = 2,
		DUAL_ICONS = 3,
		DUAL_LIST = 4,
		QUAD = 5
	}
	
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

		var hbox = new Gtk.Box(Orientation.HORIZONTAL, 6);
		hbox.margin_bottom = 12;
		vbox_main.add(hbox);
		
		var label = add_label_header(hbox, _("Select Layout Style"), true);
		label.yalign = 0.5f;
		label.margin_right = 12;

		var bbox = new Gtk.ButtonBox(Orientation.HORIZONTAL);
		bbox.set_layout(Gtk.ButtonBoxStyle.EXPAND);
		bbox.set_homogeneous(true);
		hbox.add(bbox);

		var button = new Gtk.Button.with_label(_("Previous"));
		button.image = IconManager.lookup_image("go-previous", 16);
		button.always_show_image = true;
		bbox.add(button);
		
		button.clicked.connect(()=>{
			if (current_layout_option == 1){
				current_layout_option = (LayoutStyle) 5;
			}
			else{
				current_layout_option = (LayoutStyle) (current_layout_option - 1);
			}
			show_layout(current_layout_option);
		});

		button = new Gtk.Button.with_label(_("Next"));
		button.image = IconManager.lookup_image("go-next", 16);
		button.always_show_image = true;
		bbox.add(button);
		
		button.clicked.connect(()=>{
			if (current_layout_option == 5){
				current_layout_option = (LayoutStyle) 1;
			}
			else{
				current_layout_option = (LayoutStyle) (current_layout_option + 1);
			}
			show_layout(current_layout_option);
		});

		button = new Gtk.Button.with_label(_("Apply"));
		button.image = IconManager.lookup_image("gtk-ok", 16);
		button.always_show_image = true;
		bbox.add(button);
		
		button.clicked.connect(()=>{
			apply_layout(current_layout_option);
			//this.close();
		});

		label = new Gtk.Label("");
		label.hexpand = true;
		hbox.add(label);

		button = new Gtk.Button.with_label(_("Close"));
		button.image = IconManager.lookup_image("window-close", 16);
		button.always_show_image = true;
		hbox.add(button);
		
		button.clicked.connect(()=>{
			this.close();
		});

		var vbox = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
		vbox_main.add(vbox);
		vbox_layout_option = vbox;

		show_layout(current_layout_option);
		
		this.show_all();
	}

	private void show_layout(LayoutStyle layout_style){

		string image_name = "polo_layout_single_icons";
		string desc = _("Classic Icons (Single-Pane + SideBar + IconView)");
		
		switch(layout_style){
		case LayoutStyle.SINGLE_ICONS:
			image_name = "polo_layout_single_icons";
			desc = _("Classic Icons (Single-Pane + SideBar + IconView)");
			break;
			
		case LayoutStyle.SINGLE_LIST:
			image_name = "polo_layout_single_list";
			desc = _("Classic List (Single-Pane + SideBar + ListView)");
			break;
			
		case LayoutStyle.DUAL_ICONS:
			image_name = "polo_layout_dual_icons";
			desc = _("Commander Icons (Dual-Pane + IconView)");
			break;
			
		case LayoutStyle.DUAL_LIST:
			image_name = "polo_layout_dual_list";
			desc = _("Commander List (Dual-Pane + ListView)");
			break;
			
		case LayoutStyle.QUAD:
			image_name = "polo_layout_quad";
			desc = _("Extreme (Quad-Pane + ListView + Global Pathbar + Global Statusbar)");
			break;
		}

		var vbox = vbox_layout_option;

		gtk_container_remove_children(vbox);

		var label = add_label(vbox, desc, true, true);
		label.xalign = 0.5f;

		var img = new Gtk.Image.from_pixbuf(IconManager.lookup(image_name, 800));
		
		var ebox = new Gtk.EventBox();
		ebox.add(img);
		vbox.add(ebox);
		
		// set hand cursor
		if (ebox.get_realized()){
			ebox.get_window().set_cursor(new Gdk.Cursor(Gdk.CursorType.HAND1));
		}
		else{
			ebox.realize.connect(()=>{
				ebox.get_window().set_cursor(new Gdk.Cursor(Gdk.CursorType.HAND1));
			});
		}

		this.show_all();
	}

	private void apply_layout(LayoutStyle layout_style){

		switch(layout_style){
		case LayoutStyle.SINGLE_ICONS:
			App.statusbar_unified = false;
			App.pathbar_unified = false;
			App.sidebar_position = Main.DEFAULT_SIDEBAR_POSITION;
			App.main_window.sidebar.sidebar_show();

			App.view_mode = ViewMode.ICONS;
			App.main_window.layout_box.set_panel_layout(PanelLayout.SINGLE);
			App.main_window.layout_box.panel1.pane.view.set_view_mode(ViewMode.ICONS);
			break;
			
		case LayoutStyle.SINGLE_LIST:
			App.statusbar_unified = false;
			App.pathbar_unified = false;
			App.sidebar_position = Main.DEFAULT_SIDEBAR_POSITION;
			App.main_window.sidebar.sidebar_show();
			App.main_window.layout_box.set_panel_layout(PanelLayout.SINGLE);

			App.view_mode = ViewMode.LIST;
			App.main_window.layout_box.panel1.pane.view.set_view_mode(ViewMode.LIST);
			break;
			
		case LayoutStyle.DUAL_ICONS:
			App.statusbar_unified = false;
			App.pathbar_unified = false;
			App.main_window.sidebar.sidebar_hide();
			App.main_window.layout_box.set_panel_layout(PanelLayout.DUAL_VERTICAL);

			App.view_mode = ViewMode.ICONS;
			App.main_window.layout_box.panel1.pane.view.set_view_mode(ViewMode.ICONS);
			App.main_window.layout_box.panel2.pane.view.set_view_mode(ViewMode.ICONS);
			break;
			
		case LayoutStyle.DUAL_LIST:
			App.statusbar_unified = false;
			App.pathbar_unified = false;
			App.main_window.sidebar.sidebar_hide();
			App.main_window.layout_box.set_panel_layout(PanelLayout.DUAL_VERTICAL);

			App.view_mode = ViewMode.LIST;
			App.main_window.layout_box.panel1.pane.view.set_view_mode(ViewMode.LIST);
			App.main_window.layout_box.panel2.pane.view.set_view_mode(ViewMode.LIST);
			break;
			
		case LayoutStyle.QUAD:
			App.statusbar_unified = true;
			App.pathbar_unified = true;
			App.main_window.sidebar.sidebar_hide();
			App.main_window.layout_box.set_panel_layout(PanelLayout.QUAD);

			App.view_mode = ViewMode.LIST;
			App.main_window.layout_box.panel1.pane.view.set_view_mode(ViewMode.LIST);
			App.main_window.layout_box.panel2.pane.view.set_view_mode(ViewMode.LIST);
			break;
		}

		App.main_window.reset_view_size_defaults();

		App.main_window.refresh_pathbars();
		App.main_window.refresh_statusbars();

		App.toolbar_dark = true;
		App.main_window.toolbar.refresh_style();

		App.sidebar_dark = true;
		App.main_window.sidebar.refresh();

		GtkTheme.set_gtk_theme_preferred();

		App.save_app_config();
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


