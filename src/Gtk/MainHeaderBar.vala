/*
 * PoloHeaderBar.vala
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

public class MainHeaderBar : Gtk.HeaderBar {

	// parents

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

	private Gtk.Box crumbs;
	private Gtk.ScrolledWindow scrolled;
	private ViewPopover view_popover;
	private Gtk.MenuButton btn_menu;
	
	private int BUTTON_PADDING = 6;
	
	// contruct

	public MainHeaderBar(){
		//base(Gtk.Orientation.VERTICAL, 6); // issue with vala
		//Object(orientation: Gtk.Orientation.HORIZONTAL, spacing: 6); // work-around

		this.spacing = 3;

		this.show_close_button = true;

		this.set_decoration_layout(":"); //minimize,maximize,close
		
		//log_debug("Statusbar()");

		//_pane = parent_pane;

		//init_statusbar();

		//this.set_no_show_all(true);

		init_ui();
	}

	private void init_ui() {

		add_back();

		add_next();

		add_up();

		add_home();

		add_bookmarks();

		add_devices();
		
		add_crumbs();

		// pack_end(), add remaining items in reverse order

		add_close();

		add_minimize();

		add_menu();
		
		add_settings();

		add_view();
	}

	private void add_back(){
		
		var button = new Gtk.Button();
		button.always_show_image = true;
		button.image = IconManager.lookup_image("go-previous", 20);
		button.set_tooltip_text (_("Open the previous visited location"));
		this.pack_start(button);

		gtk_apply_css({ button }, "padding-left: %dpx; padding-right: %dpx;".printf(BUTTON_PADDING, BUTTON_PADDING));

		button.clicked.connect(() => {
			if (view == null) { return; };
			view.go_back();
		});
	}

	private void add_next(){
		
		var button = new Gtk.Button();
		button.always_show_image = true;
		button.image = IconManager.lookup_image("go-next", 20);
		button.set_tooltip_text (_("Open the next visited location"));
		this.pack_start(button);

		gtk_apply_css({ button }, "padding-left: %dpx; padding-right: %dpx;".printf(BUTTON_PADDING, BUTTON_PADDING));

		button.clicked.connect(() => {
			if (view == null) { return; };
			view.go_forward();
		});
	}

	private void add_up(){
		
		var button = new Gtk.Button();
		button.always_show_image = true;
		button.image = IconManager.lookup_image("go-up", 20);
		button.set_tooltip_text (_("Open the parent location"));
		this.pack_start(button);

		gtk_apply_css({ button }, "padding-left: %dpx; padding-right: %dpx;".printf(BUTTON_PADDING, BUTTON_PADDING));

		button.clicked.connect(() => {
			if (view == null) { return; };
			view.go_up();
		});
	}

	private void add_home(){
		
		var button = new Gtk.Button();
		button.always_show_image = true;
		button.image = IconManager.lookup_image("go-home", 20);
		button.set_tooltip_text (_("Open Home folder"));
		this.pack_start(button);
		
		gtk_apply_css({ button }, "padding-left: %dpx; padding-right: %dpx;".printf(BUTTON_PADDING, BUTTON_PADDING));

		button.clicked.connect(() => {
			if (view == null) { return; };
			view.set_view_path(App.user_home);
		});
	}

	private Gtk.Popover popup_bm;
	private Sidebar sidebar_bm;
	
	private void add_bookmarks(){

		var button = new Gtk.Button();
		button.always_show_image = true;
		button.image = IconManager.lookup_image("user-bookmarks", 20);
		//button.set_tooltip_text (_("Bookmarks"));
		this.pack_start(button);
		
		gtk_apply_css({ button }, "padding-left: %dpx; padding-right: %dpx;".printf(BUTTON_PADDING, BUTTON_PADDING));

		popup_bm = new Gtk.Popover(button);
		sidebar_bm = new Sidebar(popup_bm, "bm", pane);
		popup_bm.add(sidebar_bm);

		button.clicked.connect(() => {
			if (view == null) { return; };
			sidebar_bm.show();
			sidebar_bm.refresh();
			gtk_show(popup_bm);
		});
	}

	private Gtk.Popover popup_dev;
	private Sidebar sidebar_dev;
	
	private void add_devices(){

		var button = new Gtk.Button();
		button.always_show_image = true;
		button.image = IconManager.lookup_image("drive-harddisk", 20);
		//button.set_tooltip_text (_("Bookmarks"));
		this.pack_start(button);
		
		gtk_apply_css({ button }, "padding-left: %dpx; padding-right: %dpx;".printf(BUTTON_PADDING, BUTTON_PADDING));

		popup_dev = new Gtk.Popover(button);
		sidebar_dev = new Sidebar(popup_dev, "device", pane);
		popup_dev.add(sidebar_dev);

		button.clicked.connect(() => {
			if (view == null) { return; };
			sidebar_dev.show();
			sidebar_dev.refresh();
			gtk_show(popup_dev);
		});
	}

	private void add_crumbs(){
		
		// scrolled
		scrolled = new Gtk.ScrolledWindow(null, null);
		//scrolled.hexpand = true;
		scrolled.hscrollbar_policy = PolicyType.NEVER; // clips child without showing scrollbar
		scrolled.vscrollbar_policy = PolicyType.NEVER;
		//scrolled.set_shadow_type(ShadowType.ETCHED_IN);
		this.pack_start(scrolled);
		
		crumbs = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 3);
		//crumbs.set_layout(Gtk.ButtonBoxStyle.START);
		//crumbs.spacing = 0;
		crumbs.margin = 0;
		scrolled.add(crumbs);

		//gtk_apply_css({ scrolled }, "border-top-color: black;");
	}

	private void add_view(){
		
		var button = new Gtk.Button();
		button.always_show_image = true;
		button.image = IconManager.lookup_image("view-grid", 20);
		//button.set_tooltip_text (_("Change Application Settings"));
		this.pack_end(button);
		
		gtk_apply_css({ button }, "padding-left: %dpx; padding-right: %dpx;".printf(BUTTON_PADDING, BUTTON_PADDING));

		view_popover = new ViewPopover(button);
		button.clicked.connect(() => {
			view_popover.refresh();
			gtk_show(view_popover);
		});
	}

	private void add_settings(){
		
		var button = new Gtk.Button();
		button.always_show_image = true;
		button.image = IconManager.lookup_image("preferences-system", 20);
		button.set_tooltip_text (_("Change Application Settings"));
		this.pack_end(button);
		
		gtk_apply_css({ button }, "padding-left: %dpx; padding-right: %dpx;".printf(BUTTON_PADDING, BUTTON_PADDING));

		button.clicked.connect(() => {
			window.open_settings_window();
		});
	}

	private void add_menu(){
		
		var button = new Gtk.MenuButton();
		button.always_show_image = true;
		button.image = IconManager.lookup_image("window-menu", 20);
		button.set_tooltip_text (_("Open menu"));
		this.pack_end(button);
		btn_menu = button;
		
		gtk_apply_css({ button }, "padding-left: %dpx; padding-right: %dpx;".printf(BUTTON_PADDING, BUTTON_PADDING));
	}

	private void add_minimize(){
		
		var button = new Gtk.Button();
		button.always_show_image = true;
		button.image = IconManager.lookup_image("window-minimize", 20); // use symbolic
		button.set_tooltip_text (_("Minimize"));
		this.pack_end(button);

		gtk_apply_css({ button }, "padding-left: %dpx; padding-right: %dpx;".printf(BUTTON_PADDING, BUTTON_PADDING));
		
		button.clicked.connect(() => {
			window.iconify();
		});
	}

	private void add_close(){
		
		var button = new Gtk.Button();
		button.always_show_image = true;
		button.image = IconManager.lookup_image("window-close", 20);
		button.set_tooltip_text (_("Close this window"));
		this.pack_end(button);
		
		gtk_apply_css({ button }, "padding-left: %dpx; padding-right: %dpx;".printf(BUTTON_PADDING, BUTTON_PADDING));

		button.clicked.connect(() => {
			window.close();
		});
	}

	public void refresh(){
		
		refresh_visibility();
		
		if (!this.visible){
			//window.decorated = true;
			//window.set_titlebar(null);
			return;
		}

		refresh_crumbs();

		btn_menu.popup = window.menubar.get_menu();
	}
	
	public void refresh_visibility(){

		if (App.headerbar_enabled){
			this.set_no_show_all(false);
			this.show_all();
		}
		else{
			this.set_no_show_all(true);
			this.hide();
		}
	}

	public void refresh_for_active_pane(){
		refresh_crumbs();
	}

	public void refresh_crumbs(){

		/*log_debug("update_crumb_labels()", true);
		log_debug("file_path: %s".printf(view.current_item.file_path));
		log_debug("file_path_prefix: %s".printf(view.current_item.file_path_prefix));
		log_debug("display_path: %s".printf(view.current_item.display_path));
		log_debug("current_path_saved: %s".printf(view.current_path_saved));*/

		gtk_container_remove_children(crumbs);

		if (view == null) { return; }

		//if (view.current_item == null) { return; }
		
		string link_path = "";
		//string prefix = view.current_item.file_path_prefix;
		bool is_trash = false;
		
		if ((view.current_item != null) && (view.current_item.is_trash || view.current_item.is_trashed_item)){

			is_trash = true;

			link_path = "trash://";
			
			add_crumb(crumbs, "trash://", link_path);
		}
		else { //if (view.current_item.is_local){

			link_path = "/";

			add_crumb(crumbs, "/", link_path);
		}

		var parts = view.current_path_saved.replace("trash://","").split("/");

		int index = -1;

		foreach(var part in parts){
			index++;
			if (part.length == 0){ continue; }

			if (link_path.contains("://")){
				link_path = link_path + "/" + part; // don't use path_combine()
			}
			else{
				link_path = path_combine(link_path, part); // don't use simple concatenation
			}

			add_crumb(crumbs, part, link_path);
	
			//if (index < parts.length - 1){
				//var lbl3 = new Gtk.Label(">");
				//lbl3.margin_bottom = 1;
				//crumbs.add(lbl3);
				//gtk_apply_css( { lbl3 }, "padding-top: 0px; padding-bottom: 0px; margin-top: 0px; margin-bottom: 0px;");
			//}
		}

		crumbs.show_all();
	}

	private void add_crumb(Gtk.Box box, string text, string link_path){

		//var button = new Gtk.Button.with_label(text);
		var button = new Gtk.Button();
		button.set_tooltip_text(link_path);
		button.set_data<string>("link", link_path);
		box.add(button);

		var label = new Gtk.Label(text);
		label.margin = 0;
		label.margin_left = label.margin_right = 0;
		button.add(label);

		//button.relief = Gtk.ReliefStyle.NORMAL;

		//button.get_style_context().remove_class("flat");

		//gtk_apply_css({ button }, "border: 1px solid; border-color: #cfd6e6"); //border: 1px solid; border-color: #cfd6e6;
		
		//gtk_apply_css({ button }, "padding-left: %dpx; padding-right: %dpx;".printf(3, 3));

		button.clicked.connect(() => {
			if (view == null) { return; };
			view.set_view_path(button.get_data<string>("link"));
			return;
		});
	}
	
}




