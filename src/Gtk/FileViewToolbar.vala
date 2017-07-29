
/*
 * FileViewToolbar.vala
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

public enum ToolbarItem{
	BACK,
	NEXT,
	UP,
	HOME,
	TERMINAL,
	HIDDEN,
	DUAL_PANE,
	NEW_TAB
}

public class FileViewToolbar : Gtk.Toolbar, IPaneActive {

	private int icon_size_actual = 16;
	private Gtk.Menu menu_history;
	private Gtk.Menu menu_disk;
	private Gtk.Menu menu_bookmark;
	private Gtk.Menu menu_layout;
	private ViewPopover view_popover;
	public bool is_global = true;

	private Gtk.ToolButton btn_back;
	private Gtk.ToolButton btn_up;
	private Gtk.ToolButton btn_next;
	private Gtk.ToolButton btn_reload;
	private Gtk.SeparatorToolItem separator_nav;
	private Gtk.ToolButton btn_home;
	//private Gtk.ToolButton btn_hidden;
	private Gtk.ToolButton btn_terminal;
	//private Gtk.MenuToolButton btn_dual_pane;
	private Gtk.ToolButton btn_view;
	private Gtk.ToolButton btn_bookmarks;
	private Gtk.ToolButton btn_devices;
	private Gtk.SeparatorToolItem separator_spacer;
	//private Gtk.ToolButton btn_test;
	private Gtk.ToolButton btn_settings;
	//private Gtk.ToolButton btn_wizard;
	private Gtk.ToolButton btn_about;
	private Gtk.ToolButton btn_donate;

	private Gtk.Image img_back;
	private Gtk.Image img_up;
	private Gtk.Image img_next;
	private Gtk.Image img_reload;
	private Gtk.Image img_home;
	//private Gtk.Image img_hidden;
	private Gtk.Image img_terminal;
	//private Gtk.Image img_dual_pane;
	private Gtk.Image img_view;
	private Gtk.Image img_bookmarks;
	private Gtk.Image img_devices;
	//private Gtk.Image img_new_tab;
	//private Gtk.Image img_test;
	private Gtk.Image img_settings;
	//private Gtk.Image img_wizard;
	private Gtk.Image img_about;
	private Gtk.Image img_donate;

	// contruct

	public FileViewToolbar(){
		//base(); // issue with vala
		//Object(orientation: Gtk.Orientation.HORIZONTAL, spacing: 0); // work-around

		log_debug("FileViewToolbar()");

		margin = 0;

		init_toolbar();

		this.set_no_show_all(true);

        log_debug("FileViewToolbar():exit");
	}

	private void init_toolbar() {

		add_toolbar_button_for_go_back();

		add_toolbar_button_for_go_forward();

		add_toolbar_button_for_go_up();

		add_toolbar_button_for_go_home();

		add_toolbar_button_for_reload();

		add_toolbar_separator_nav();

		//add_toolbar_button_for_layout_dual();

		add_toolbar_button_for_view();

		add_toolbar_button_for_bookmarks();

		add_toolbar_button_for_devices();

		//add_toolbar_button_for_show_hidden();

		add_toolbar_button_for_open_terminal();

		add_toolbar_separator_spacer();

		//add_toolbar_button_for_test();

		add_toolbar_button_for_settings();

		//add_toolbar_button_for_wizard();

		add_toolbar_button_for_donate();

		add_toolbar_button_for_about();

	}

	// init toolbar items

	private void add_toolbar_button_for_go_back(){

		var button = new Gtk.ToolButton(null,null);
		button.label = _("Back");
		button.set_tooltip_text (_("Open the previous visited location"));
		button.is_important = true;
		add(button);
		btn_back = button;

		img_back = new Gtk.Image();
		button.set_icon_widget(img_back);

		gtk_apply_css({ button }, "padding-left: 2px; padding-right: 2px;");

		button.clicked.connect(() => {
			if (view == null) { return; };
			view.go_back();
			//log_debug("size=%d, prev: %s".printf(current_view.visited_locations.size, path));
		});
	}

	private void add_toolbar_button_for_go_forward(){

		var button = new Gtk.ToolButton(null,null);
		button.label = _("Forward");
		button.set_tooltip_text (_("Open the next visited location"));
		button.is_important = true;
		add(button);
		btn_next = button;

		img_next = new Gtk.Image();
		button.set_icon_widget(img_next);

		gtk_apply_css({ button }, "padding-left: 2px; padding-right: 2px;");

		button.clicked.connect(() => {
			if (view == null) { return; };
			view.go_forward();
			//log_debug("size=%d, next: %s".printf(current_view.visited_locations.size, path));
		});
	}

	private void add_toolbar_button_for_go_up(){

		var button = new Gtk.ToolButton(null,null);
		button.label = _("Up");
		button.set_tooltip_text (_("Open the parent location"));
		button.is_important = true;
		add(button);
		btn_up = button;

		img_up = new Gtk.Image();
		button.set_icon_widget(img_up);

		gtk_apply_css({ button }, "padding-left: 2px; padding-right: 2px;");

		button.clicked.connect(() => {
			if (view == null) { return; };
			view.go_up();
		});
	}

	private void add_toolbar_button_for_go_home(){

		var button = new Gtk.ToolButton(null,null);
		button.label = _("Home");
		button.set_tooltip_text (_("Open personal folder"));
		button.is_important = true;
		add(button);
		btn_home = button;

		img_home = new Gtk.Image();
		button.set_icon_widget(img_home);

		gtk_apply_css({ button }, " padding-left: 2px; padding-right: 2px; ");

		button.clicked.connect(() => {
			if (view == null) { return; };
			view.set_view_path(App.user_home);
		});
	}

	private void add_toolbar_button_for_reload(){

		var button = new Gtk.ToolButton(null,null);
		button.label = _("Reload");
		button.set_tooltip_text (_("Reload current location"));
		button.is_important = true;
		add(button);
		btn_reload = button;

		img_reload = new Gtk.Image();
		button.set_icon_widget(img_reload);

		gtk_apply_css({ button }, " padding-left: 2px; padding-right: 2px; ");

		button.clicked.connect(() => {
			view.reload();
		});
	}

	private void add_toolbar_separator_nav(){
		separator_nav = new Gtk.SeparatorToolItem();
		add(separator_nav);
		gtk_apply_css({ separator_nav }, " padding-left: 2px; padding-right: 2px; ");
	}

	private void add_toolbar_button_for_view(){

		var button = new Gtk.ToolButton(null,null);
		button.label = _("View");
		//button.set_tooltip_text (_("Toggle view mode"));
		button.is_important = true;
		add(button);
		btn_view = button;

		img_view = new Gtk.Image();
		button.set_icon_widget(img_view);

		gtk_apply_css({ button }, "padding-left: 2px; padding-right: 2px;");

		view_popover = new ViewPopover(button);
		button.clicked.connect(() => {
			view_popover.refresh();
			gtk_show(view_popover);
		});

		//button.set_menu(build_view_menu());
	}

	private Gtk.Popover popup_bm;
	private Sidebar sidebar_bm;
	
	private void add_toolbar_button_for_bookmarks(){

		var button = new Gtk.ToolButton(null,null);
		button.label = _("Bookmarks");
		button.is_important = true;
		add(button);
		btn_bookmarks = button;

		img_bookmarks = new Gtk.Image();
		button.set_icon_widget(img_bookmarks);

		gtk_apply_css({ button }, "padding-left: 2px; padding-right: 2px;");

		popup_bm = new Gtk.Popover(btn_bookmarks);
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

	private void add_toolbar_button_for_devices(){

		var button = new Gtk.ToolButton(null,null);
		button.label = _("Devices");
		button.is_important = true;
		add(button);
		btn_devices = button;

		img_devices = new Gtk.Image();
		button.set_icon_widget(img_devices);

		gtk_apply_css({ button }, "padding-left: 2px; padding-right: 2px;");

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

	// common: used by menubar
	public Gtk.Menu build_layout_menu(){

		var menu = new Gtk.Menu();
		menu.reserve_toggle_size = false;

		var item = new Gtk.MenuItem.with_label(_("Single Pane"));
		menu.add(item);

		item.activate.connect (() => {
			if (!window.layout_box.show_file_operation_warning_on_layout_change()) {
				return;
			}
			window.layout_box.set_panel_layout(PanelLayout.SINGLE);
		});

		item = new Gtk.MenuItem.with_label(_("Dual Vertical"));
		menu.add(item);

		item.activate.connect (() => {
			if (!window.layout_box.show_file_operation_warning_on_layout_change()) {
				return;
			}
			window.layout_box.set_panel_layout(PanelLayout.DUAL_VERTICAL);
		});

		item = new Gtk.MenuItem.with_label(_("Dual Horizontal"));
		menu.add(item);

		item.activate.connect (() => {
			if (!window.layout_box.show_file_operation_warning_on_layout_change()) {
				return;
			}
			window.layout_box.set_panel_layout(PanelLayout.DUAL_HORIZONTAL);
		});

		item = new Gtk.MenuItem.with_label(_("Quad Pane"));
		menu.add(item);

		item.activate.connect (() => {
			if (!window.layout_box.show_file_operation_warning_on_layout_change()) {
				return;
			}
			window.layout_box.set_panel_layout(PanelLayout.QUAD);
		});

		menu.show_all();

		return menu;
	}

	// common: used by menubar
	public Gtk.Menu build_view_menu(){

		var menu = new Gtk.Menu();
		menu.reserve_toggle_size = false;

		var item = new Gtk.MenuItem.with_label(_("List"));
		menu.add(item);

		item.activate.connect (() => {
			window.active_pane.view.set_view_mode(ViewMode.LIST);
		});

		item = new Gtk.MenuItem.with_label(_("Icons"));
		menu.add(item);

		item.activate.connect (() => {
			window.active_pane.view.set_view_mode(ViewMode.ICONS);
		});

		item = new Gtk.MenuItem.with_label(_("Tiles"));
		menu.add(item);

		item.activate.connect (() => {
			window.active_pane.view.set_view_mode(ViewMode.TILES);
		});

		item = new Gtk.MenuItem.with_label(_("Media"));
		menu.add(item);

		item.activate.connect (() => {
			window.active_pane.view.set_view_mode(ViewMode.MEDIA);
		});

		menu.show_all();

		return menu;
	}


	private void add_toolbar_button_for_open_terminal(){

		var button = new Gtk.ToolButton(null,null);
		button.label = _("Terminal");
		button.set_tooltip_text (_("Toggle terminal panel"));
		button.is_important = true;
		add(button);
		btn_terminal = button;

		img_terminal = new Gtk.Image();
		button.set_icon_widget(img_terminal);

		gtk_apply_css({ button }, "padding-left: 2px; padding-right: 2px;");

		button.clicked.connect(() => {
			//open_terminal_window("", view.current_item.file_path, "", false);
			pane.terminal.toggle();
		});
	}

	private void add_toolbar_separator_spacer(){
		separator_spacer = new Gtk.SeparatorToolItem();
		separator_spacer.set_draw (false);
		separator_spacer.set_expand (true);
		add(separator_spacer);
		gtk_apply_css({ separator_spacer }, " padding-left: 2px; padding-right: 2px; ");
	}

	private void add_toolbar_button_for_settings(){

		// btn_settings
		var button = new Gtk.ToolButton(null,null);
		button.is_important = true;
		button.label = _("Settings");
		button.set_tooltip_text (_("Change Application Settings"));
		add(button);
		btn_settings = button;

		img_settings = new Gtk.Image();
		button.set_icon_widget(img_settings);

		gtk_apply_css({ button }, "padding-left: 2px; padding-right: 2px;");

		button.clicked.connect(() => {
			window.open_settings_window();
		});
	}

	private void add_toolbar_button_for_donate(){

		// btn_donate
		var button = new Gtk.ToolButton(null, null);
		button.is_important = true;
		button.label = _("Donate");
		button.set_tooltip_text (_("Make a donation"));
		add(button);
		btn_donate = button;

		img_donate = new Gtk.Image();
		button.set_icon_widget(img_donate);

		gtk_apply_css({ button }, "padding-left: 2px; padding-right: 2px;");

		button.clicked.connect(() => {
			window.open_donate_window();
		});
	}

	private void add_toolbar_button_for_about(){

		// btn_about
		var button = new Gtk.ToolButton(null,null);
		button.is_important = true;
		button.label = _("About");
		button.set_tooltip_text (_("Application Info"));
		add(button);
		btn_about = button;

		img_about = new Gtk.Image();
		button.set_icon_widget(img_about);

		gtk_apply_css({ button }, "padding-left: 2px; padding-right: 2px;");

		button.clicked.connect(() => {
			window.open_about_window();
		});
	}

	// refresh

	public void refresh(){

		log_debug("FileViewToolbar: refresh()");

		refresh_visibility();

		if (!this.visible){
			return;
		}

		refresh_items();

		refresh_icons();

		refresh_style();
	}

	private void refresh_visibility(){

		if (!App.headerbar_enabled && App.toolbar_visible){
			this.set_no_show_all(false);
			this.show_all();
		}
		else{
			this.set_no_show_all(true);
			this.hide();
		}
	}

	public void refresh_items(){

		log_debug("FileViewToolbar: refresh_items()");

		this.foreach((x) => { this.remove(x); });

		if (App.toolbar_item_back){
			this.add(btn_back);
		}

		if (App.toolbar_item_next){
			this.add(btn_next);
		}

		if (App.toolbar_item_up){
			this.add(btn_up);
		}

		if (App.toolbar_item_reload){
			this.add(btn_reload);
		}

		this.add(separator_nav);

		if (App.toolbar_item_home){
			this.add(btn_home);
		}

		if (App.toolbar_item_view){
			this.add(btn_view);
		}

		if (App.toolbar_item_bookmarks){
			this.add(btn_bookmarks);
		}

		if (App.toolbar_item_devices){
			this.add(btn_devices);
		}

		if (App.toolbar_item_terminal){
			this.add(btn_terminal);
		}

		if (is_global){
			this.add(separator_spacer);
			this.add(btn_settings);
			this.add(btn_donate);
			this.add(btn_about);
		}

		refresh_for_active_pane();
	}

	public void refresh_icons(){

		log_debug("FileViewToolbar: refresh_icons()");

		if (App.toolbar_large_icons){
			icon_size_actual = 24;
			this.icon_size = Gtk.IconSize.LARGE_TOOLBAR;
		}
		else{
			icon_size_actual = 16;
			this.icon_size = Gtk.IconSize.SMALL_TOOLBAR;
		}

		img_back.pixbuf = IconManager.lookup("go-previous", icon_size_actual);
		img_next.pixbuf = IconManager.lookup("go-next", icon_size_actual);
		img_up.pixbuf = IconManager.lookup("go-up", icon_size_actual);
		img_home.pixbuf = IconManager.lookup("go-home", icon_size_actual);
		img_reload.pixbuf = IconManager.lookup("view-refresh", icon_size_actual);
		img_view.pixbuf = IconManager.lookup("view-grid", icon_size_actual);
		img_bookmarks.pixbuf = IconManager.lookup("user-bookmarks", icon_size_actual);
		img_devices.pixbuf = IconManager.lookup("drive-harddisk", icon_size_actual);
		img_terminal.pixbuf = IconManager.lookup("terminal", icon_size_actual);

		img_settings.pixbuf = IconManager.lookup("preferences-system", icon_size_actual);
		img_donate.pixbuf = IconManager.lookup("donate", icon_size_actual);
		img_about.pixbuf = IconManager.lookup("help-about", icon_size_actual);
	}

	public void refresh_style(){

		log_debug("FileViewToolbar: refresh_style()");

		this.icon_size_set = true;

		if (App.toolbar_dark){
			this.get_style_context().add_class(Gtk.STYLE_CLASS_PRIMARY_TOOLBAR);
		}
		else{
			this.get_style_context().remove_class(Gtk.STYLE_CLASS_PRIMARY_TOOLBAR);
		}

		if (App.toolbar_labels){
			if (App.toolbar_labels_beside_icons){
				set_style(ToolbarStyle.BOTH_HORIZ);
			}
			else{
				set_style(ToolbarStyle.BOTH);
			}
		}
		else{
			set_style(ToolbarStyle.ICONS);
		}

	}

	public void refresh_for_active_pane(){
		//log_debug("FileViewToolbar: refresh_for_active_pane()");
		//btn_next.sensitive = (view != null) && view.history_can_go_forward();
		//btn_back.sensitive = (view != null) && view.history_can_go_back();
		//btn_up.sensitive = (view != null) && view.location_can_go_up();
		//log_debug("FileViewToolbar: refresh_for_active_pane(): ok");
	}

	public void set_icon_size_actual(int _icon_size){
		if ((_icon_size >= 16) && (_icon_size <= 64)){
			icon_size_actual = _icon_size;
			refresh();
		}
	}

	public int get_icon_size_actual(){
		return icon_size_actual;
	}
}
