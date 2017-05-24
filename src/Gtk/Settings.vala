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

public class Settings : Gtk.Box {

	private Gtk.Box header_box;
	private Gtk.StackSwitcher switcher;
	private Gtk.Stack stack;

	private Gtk.Scale scale_listview_font_scale;

	private Gtk.Scale scale_listview_icon_size;
	private Gtk.Scale scale_listview_row_spacing;

	private Gtk.Scale scale_iconview_icon_size;
	private Gtk.Scale scale_iconview_row_spacing;
	private Gtk.Scale scale_iconview_column_spacing;

	private Gtk.Scale scale_tileview_icon_size;
	private Gtk.Scale scale_tileview_row_spacing;
	private Gtk.Scale scale_tileview_padding;

	private Gtk.Scale scale_toolbar_icon;
	private Gtk.TreeView tv_columns;

	Gtk.IconSize[] toolbar_icon_sizes = new Gtk.IconSize[] { Gtk.IconSize.MENU, Gtk.IconSize.SMALL_TOOLBAR };

	private int[] ICON_SIZE_MAPPING_LIST = new int[] { 16, 24, 32, 48 };
	private int[] ICON_SIZE_MAPPING_ICONS = new int[] { 24, 32, 48, 64, 80, 96, 128, 256 };
	private int[] ICON_SIZE_MAPPING_TILES = new int[] { 48, 64, 80, 96, 128, 256 };

	private Gee.ArrayList<int> listview_icon_sizes;
	private Gee.ArrayList<int> iconview_icon_sizes;
	private Gee.ArrayList<int> tileview_icon_sizes;

	// parents
	public FileViewList view;
	public FileViewPane pane;
	public MainWindow window;
	public Gtk.Window parent_window;

	// signals
	public signal void changed();

	public Settings(Gtk.Window _parent_window){
		//base(Gtk.Orientation.VERTICAL, 6); // issue with vala
		Object(orientation: Gtk.Orientation.VERTICAL, spacing: 12); // work-around
		margin = 6;

		log_debug("Settings()");


		window = App.main_window;
		pane = window.active_pane;
		view = pane.view;

		parent_window = _parent_window;

		listview_icon_sizes = new Gee.ArrayList<int>.wrap(ICON_SIZE_MAPPING_LIST);

		iconview_icon_sizes = new Gee.ArrayList<int>.wrap(ICON_SIZE_MAPPING_ICONS);

		tileview_icon_sizes = new Gee.ArrayList<int>.wrap(ICON_SIZE_MAPPING_TILES);

		init_ui();
	}

	private void init_ui(){

		header_box = new Box(Orientation.HORIZONTAL, 6);
		add(header_box);

		switcher = new Gtk.StackSwitcher();
		switcher.margin = 6;
		header_box.add (switcher);

		stack = new Gtk.Stack();
		stack.margin = 6;
		stack.margin_top = 0;
		stack.set_transition_duration (200);
        stack.set_transition_type (Gtk.StackTransitionType.SLIDE_LEFT_RIGHT);
		add(stack);

		/*if (!global_settings && !App.statusbar_unified){
			var separator_bottom = new Gtk.Separator (Gtk.Orientation.HORIZONTAL);
			add(separator_bottom);
		}*/

		switcher.set_stack(stack);

		init_tab_zoom();

		init_tab_ui();

		//init_pathbar_options();

		init_tab_list_view();

		init_tab_defaults();

		//init_tab_terminal();

		//init_action_buttons();

		//init_values();

		header_box.margin = 0;
		header_box.get_style_context().add_class(Gtk.STYLE_CLASS_PRIMARY_TOOLBAR);
		this.margin = 0;
		//this.spacing = 0;

		show_all();
	}

	// toolbar ------------------------

	private void init_tab_ui() {

		var hbox = new Box(Orientation.HORIZONTAL, 12);
		hbox.margin_left = 6;
		stack.add_titled (hbox, _("UI"), _("UI"));

		// toolbar ---------------------------------

		var vbox = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
		vbox.homogeneous = false;
		hbox.add(vbox);

		// --------------

		var label = new Gtk.Label("<b>%s:</b>".printf(_("Toolbar")));
		label.set_use_markup(true);
		label.xalign = (float) 0.0;
		vbox.add(label);

		// items
		var vbox_items = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
		vbox_items.homogeneous = false;
		vbox.add(vbox_items);

		add_toolbar_option_visible(vbox_items);
		
		add_toolbar_option_large_icons(vbox_items);

		add_toolbar_option_dark_theme(vbox_items);

		add_toolbar_option_labels(vbox_items);

		// -------------

		label = new Gtk.Label("<i>%s:</i>".printf(_("Items")));
		label.set_use_markup(true);
		label.xalign = (float) 0.0;
		vbox.add(label);

		// items
		vbox_items = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
		vbox_items.homogeneous = false;
		vbox.add(vbox_items);

		add_toolbar_item_back(vbox_items);

		add_toolbar_item_next(vbox_items);

		add_toolbar_item_up(vbox_items);

		add_toolbar_item_reload(vbox_items);

		add_toolbar_item_home(vbox_items);

		//add_toolbar_item_dual_pane(vbox_items);

		add_toolbar_item_view(vbox_items);

		//add_toolbar_item_hidden(vbox_items);

		add_toolbar_item_bookmarks(vbox_items);

		add_toolbar_item_devices(vbox_items);

		add_toolbar_item_terminal(vbox_items);

		var separator = new Gtk.Separator(Gtk.Orientation.VERTICAL);
		separator.margin_left = 24;
		hbox.add(separator);

		// pathbar ---------------------------------

		vbox = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
		vbox.homogeneous = false;
		hbox.add(vbox);

		// --------

		label = new Gtk.Label("<b>%s:</b>".printf(_("HeaderBar")));
		label.set_use_markup(true);
		label.xalign = (float) 0.0;
		vbox.add(label);

		// items
		vbox_items = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
		vbox_items.homogeneous = false;
		vbox.add(vbox_items);
		
		add_headerbar_option_enable(vbox_items);

		// --------

		label = new Gtk.Label("<b>%s:</b>".printf(_("PathBar")));
		label.set_use_markup(true);
		label.xalign = (float) 0.0;
		vbox.add(label);

		// items
		vbox_items = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
		vbox_items.homogeneous = false;
		vbox.add(vbox_items);

		add_pathbar_option_unified(vbox_items);

		add_pathbar_option_use_buttons(vbox_items);

		// -----------------------------

		label = new Gtk.Label("<i>%s:</i>".printf(_("Items")));
		label.set_use_markup(true);
		label.xalign = (float) 0.0;
		vbox.add(label);

		// items
		vbox_items = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
		vbox_items.homogeneous = false;
		vbox.add(vbox_items);

		add_pathbar_item_bookmarks(vbox_items);

		add_pathbar_item_disk(vbox_items);

		add_pathbar_item_back(vbox_items);

		add_pathbar_item_next(vbox_items);

		add_pathbar_item_up(vbox_items);

		add_pathbar_item_swap(vbox_items);

		add_pathbar_item_other(vbox_items);

		//add_pathbar_item_close(vbox_items);

		separator = new Gtk.Separator(Gtk.Orientation.VERTICAL);
		separator.margin_left = 12;
		hbox.add(separator);

		// column 2 ---------------------------------

		vbox = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
		vbox.homogeneous = false;
		hbox.add(vbox);

		// Sidebar -------------------------------

		label = new Gtk.Label("<b>%s:</b>".printf(_("Sidebar")));
		label.set_use_markup(true);
		label.xalign = (float) 0.0;
		vbox.add(label);

		// items
		vbox_items = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
		vbox.add(vbox_items);

		add_sidebar_option_visible(vbox_items);

		add_sidebar_option_dark_theme(vbox_items);

		add_sidebar_option_places(vbox_items);

		add_sidebar_option_bookmarks(vbox_items);

		add_sidebar_option_devices(vbox_items);

		add_sidebar_option_unmount(vbox_items);

		add_sidebar_option_lock(vbox_items);

		// Statusbar -------------------------------

		label = new Gtk.Label("<b>%s:</b>".printf(_("Statusbar")));
		label.set_use_markup(true);
		label.xalign = (float) 0.0;
		vbox.add(label);

		label.margin_top = 12;

		add_statusbar_option_unified(vbox);

		// Tabs -------------------------------------

		label = new Gtk.Label("<b>%s:</b>".printf(_("Tabs")));
		label.set_use_markup(true);
		label.xalign = (float) 0.0;
		vbox.add(label);

		label.margin_top = 12;

		// items
		vbox_items = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
		vbox.add(vbox_items);

		add_tabbar_option_close(vbox_items);
		
		add_tabbar_option_below(vbox_items);

		// buffer ---------------------------------------

		label = new Gtk.Label("");
		label.hexpand = true;
		hbox.add(label);
	}

	private void add_toolbar_option_visible(Gtk.Container box){

		var chk = new Gtk.CheckButton.with_label(_("Show"));
		chk.set_tooltip_text(_("Show the toolbar"));
		box.add(chk);

		chk.active = App.toolbar_visible;

		chk.toggled.connect(()=>{

			if (App.toolbar_visible == chk.active){ return; }

			App.toolbar_visible = chk.active;

			//window.toolbar.refresh_style();
			window.toolbar.refresh();
		});
	}

	private void add_toolbar_option_large_icons(Gtk.Container box){

		var chk = new Gtk.CheckButton.with_label(_("Large icons"));
		box.add(chk);

		chk.active = App.toolbar_large_icons;

		chk.toggled.connect(()=>{

			if (App.toolbar_large_icons == chk.active){ return; }

			App.toolbar_large_icons = chk.active;

			window.toolbar.refresh_icons();
		});
	}

	private void add_toolbar_option_dark_theme(Gtk.Container box){

		var chk = new Gtk.CheckButton.with_label(_("Dark theme"));
		chk.set_tooltip_text(_("Requires theme support. Use the 'darker' variant of Gtk theme."));
		box.add(chk);

		chk.active = App.toolbar_dark;

		chk.toggled.connect(()=>{

			if (App.toolbar_dark == chk.active){ return; }

			App.toolbar_dark = chk.active;

			window.toolbar.refresh_style();
			//window.sidebar.refresh();
		});
	}

	/*private void add_toolbar_option_unified(Gtk.Container box){

		var chk = new Gtk.CheckButton.with_label(_("Global toolbar"));
		chk.set_tooltip_text(_("Show single toolbar for all panes"));
		box.add(chk);

		chk.active = App.toolbar_unified;

		chk.toggled.connect(()=>{

			if (App.toolbar_unified == chk.active){ return; }

			App.toolbar_unified = chk.active;

			window.toolbar.refresh_visibility();
		});
	}*/

	private void add_toolbar_option_labels(Gtk.Container box){

		var chk = new Gtk.CheckButton.with_label(_("Show labels"));
		chk.set_tooltip_text(_("Show labels for toolbar items"));
		box.add(chk);

		chk.active = App.toolbar_labels;

		chk.toggled.connect(()=>{

			if (App.toolbar_labels == chk.active){ return; }

			App.toolbar_labels = chk.active;

			window.toolbar.refresh_style();
		});

		add_toolbar_option_labels_beside(box, chk);
	}

	private void add_toolbar_option_labels_beside(Gtk.Container box, Gtk.CheckButton chk_labels){

		var chk = new Gtk.CheckButton.with_label(_("Labels beside icons"));
		chk.set_tooltip_text(_("Show labels beside icons"));
		box.add(chk);

		chk.active = App.toolbar_labels_beside_icons;

		chk.sensitive = chk_labels.active;

		chk_labels.toggled.connect(()=>{
			chk.sensitive = chk_labels.active;
		});

		chk.toggled.connect(()=>{

			if (App.toolbar_labels_beside_icons == chk.active){ return; }

			App.toolbar_labels_beside_icons = chk.active;

			window.toolbar.refresh_style();
		});
	}

	private void add_toolbar_item_back(Gtk.Container box){

		var chk = new Gtk.CheckButton.with_label(_("Back"));
		box.add(chk);

		chk.active = App.toolbar_item_back;

		chk.toggled.connect(()=>{

			if (App.toolbar_item_back == chk.active){ return; }

			App.toolbar_item_back = chk.active;

			window.toolbar.refresh_items();
		});
	}

	private void add_toolbar_item_next(Gtk.Container box){

		var chk = new Gtk.CheckButton.with_label(_("Next"));
		box.add(chk);

		chk.active = App.toolbar_item_next;

		chk.toggled.connect(()=>{

			if (App.toolbar_item_next == chk.active){ return; }

			App.toolbar_item_next = chk.active;

			window.toolbar.refresh_items();
		});
	}

	private void add_toolbar_item_up(Gtk.Container box){

		var chk = new Gtk.CheckButton.with_label(_("Up"));
		box.add(chk);

		chk.active = App.toolbar_item_up;

		chk.toggled.connect(()=>{

			if (App.toolbar_item_up == chk.active){ return; }

			App.toolbar_item_up = chk.active;

			window.toolbar.refresh_items();
		});
	}

	private void add_toolbar_item_reload(Gtk.Container box){

		var chk = new Gtk.CheckButton.with_label(_("Reload"));
		box.add(chk);

		chk.active = App.toolbar_item_reload;

		chk.toggled.connect(()=>{

			if (App.toolbar_item_reload == chk.active){ return; }

			App.toolbar_item_reload = chk.active;

			window.toolbar.refresh_items();
		});
	}

	private void add_toolbar_item_home(Gtk.Container box){

		var chk = new Gtk.CheckButton.with_label(_("Home"));
		box.add(chk);

		chk.active = App.toolbar_item_home;

		chk.toggled.connect(()=>{

			if (App.toolbar_item_home == chk.active){ return; }

			App.toolbar_item_home = chk.active;

			window.toolbar.refresh_items();
		});
	}

	private void add_toolbar_item_terminal(Gtk.Container box){

		var chk = new Gtk.CheckButton.with_label(_("Terminal"));
		box.add(chk);

		chk.active = App.toolbar_item_terminal;

		chk.toggled.connect(()=>{

			if (App.toolbar_item_terminal == chk.active){ return; }

			App.toolbar_item_terminal = chk.active;

			window.toolbar.refresh_items();
		});
	}

	private void add_toolbar_item_hidden(Gtk.Container box){

		var chk = new Gtk.CheckButton.with_label(_("Hidden"));
		box.add(chk);

		chk.active = App.toolbar_item_hidden;

		chk.toggled.connect(()=>{

			if (App.toolbar_item_hidden == chk.active){ return; }

			App.toolbar_item_hidden = chk.active;

			window.toolbar.refresh_items();
		});
	}

	private void add_toolbar_item_dual_pane(Gtk.Container box){

		var chk = new Gtk.CheckButton.with_label(_("Dual"));
		box.add(chk);

		chk.active = App.toolbar_item_dual_pane;

		chk.toggled.connect(()=>{

			if (App.toolbar_item_dual_pane == chk.active){ return; }

			App.toolbar_item_dual_pane = chk.active;

			window.toolbar.refresh_items();
		});
	}

	private void add_toolbar_item_view(Gtk.Container box){

		var chk = new Gtk.CheckButton.with_label(_("View"));
		box.add(chk);

		chk.active = App.toolbar_item_view;

		chk.toggled.connect(()=>{

			if (App.toolbar_item_view == chk.active){ return; }

			App.toolbar_item_view = chk.active;

			window.toolbar.refresh_items();
		});
	}

	private void add_toolbar_item_bookmarks(Gtk.Container box){

		var chk = new Gtk.CheckButton.with_label(_("Bookmarks"));
		box.add(chk);

		chk.active = App.toolbar_item_bookmarks;

		chk.toggled.connect(()=>{

			if (App.toolbar_item_bookmarks == chk.active){ return; }

			App.toolbar_item_bookmarks = chk.active;

			window.toolbar.refresh_items();
		});
	}


	private void add_toolbar_item_devices(Gtk.Container box){

		var chk = new Gtk.CheckButton.with_label(_("Devices"));
		box.add(chk);

		chk.active = App.toolbar_item_devices;

		chk.toggled.connect(()=>{

			if (App.toolbar_item_devices == chk.active){ return; }

			App.toolbar_item_devices = chk.active;

			window.toolbar.refresh_items();
		});
	}


	private void add_headerbar_option_enable(Gtk.Container box){

		var chk = new Gtk.CheckButton.with_label(_("Enabled (R)"));
		chk.set_tooltip_text(_("Show combined HeaderBar instead of Toolbar and Pathbars [Restart Required]"));
		box.add(chk);
 
		chk.active = App.headerbar_enabled_temp;

		chk.toggled.connect(()=>{

			if (App.headerbar_enabled_temp == chk.active){ return; }

			App.headerbar_enabled_temp = chk.active;
			
			restart_app();
		});
	}

	private void restart_app(){
		
		var res = gtk_messagebox_yes_no(_("Restart Application ?"),
			_("Changes will take effect after application is restarted.\nYour session will be maintained.\n\nRestart now?"),window,false);

		if (res == Gtk.ResponseType.YES){
			App.save_app_config();
			window.save_session();
			App.session_lock.remove();
			exec_process_new_session("polo-gtk");
			exit(0);
		} 
	}
	
	private void add_pathbar_option_unified(Gtk.Container box){

		var chk = new Gtk.CheckButton.with_label(_("Global"));
		chk.set_tooltip_text(_("Show single pathbar for active pane"));
		box.add(chk);

		chk.active = App.pathbar_unified;

		chk.toggled.connect(()=>{

			if (App.pathbar_unified == chk.active){ return; }

			App.pathbar_unified = chk.active;

			foreach(var pn in window.panes){
				pn.pathbar.refresh();
			}

			window.pathbar.refresh();
		});
	}

	private void add_pathbar_option_use_buttons(Gtk.Container box){

		var chk = new Gtk.CheckButton.with_label(_("Use Buttons"));
		chk.set_tooltip_text(_("Use buttons for path instead of links"));
		box.add(chk);

		chk.active = App.pathbar_use_buttons;

		chk.toggled.connect(()=>{

			if (App.pathbar_use_buttons == chk.active){ return; }

			App.pathbar_use_buttons = chk.active;

			foreach(var pn in window.panes){
				pn.pathbar.refresh();
			}

			window.pathbar.refresh();
		});

		add_pathbar_option_flat_buttons(box, chk);
	}

	private void add_pathbar_option_flat_buttons(Gtk.Container box, Gtk.CheckButton chk_use_buttons){

		var chk = new Gtk.CheckButton.with_label(_("Flat Buttons"));
		chk.set_tooltip_text(_("Use flat buttons (without borders) for path"));
		box.add(chk);

		chk.active = App.pathbar_flat_buttons;

		chk_use_buttons.toggled.connect(()=>{
			chk.sensitive = chk_use_buttons.active;
		});

		chk_use_buttons.toggled();

		chk.toggled.connect(()=>{

			if (App.pathbar_flat_buttons == chk.active){ return; }

			App.pathbar_flat_buttons = chk.active;

			foreach(var pn in window.panes){
				pn.pathbar.refresh();
			}

			window.pathbar.refresh();
		});
	}
	
	private void add_pathbar_item_bookmarks(Gtk.Container box){

		var chk = new Gtk.CheckButton.with_label(_("Bookmarks"));
		box.add(chk);

		chk.active = App.pathbar_show_bookmarks;

		chk.toggled.connect(()=>{

			if (App.pathbar_show_bookmarks == chk.active){ return; }

			App.pathbar_show_bookmarks = chk.active;

			foreach(var pn in window.panes){
				pn.pathbar.refresh_icon_visibility();
			}
			window.pathbar.refresh_icon_visibility();
		});
	}

	private void add_pathbar_item_disk(Gtk.Container box){

		var chk = new Gtk.CheckButton.with_label(_("Devices"));
		box.add(chk);

		chk.active = App.pathbar_show_disks;

		chk.toggled.connect(()=>{

			if (App.pathbar_show_disks == chk.active){ return; }

			App.pathbar_show_disks = chk.active;

			foreach(var pn in window.panes){
				pn.pathbar.refresh_icon_visibility();
			}
			window.pathbar.refresh_icon_visibility();
		});
	}

	private void add_pathbar_item_back(Gtk.Container box){

		var chk = new Gtk.CheckButton.with_label(_("Back"));
		box.add(chk);

		chk.active = App.pathbar_show_back;

		chk.toggled.connect(()=>{

			if (App.pathbar_show_back == chk.active){ return; }

			App.pathbar_show_back = chk.active;

			foreach(var pn in window.panes){
				pn.pathbar.refresh_icon_visibility();
			}
			window.pathbar.refresh_icon_visibility();
		});
	}

	private void add_pathbar_item_next(Gtk.Container box){

		var chk = new Gtk.CheckButton.with_label(_("Next"));
		box.add(chk);

		chk.active = App.pathbar_show_next;

		chk.toggled.connect(()=>{

			if (App.pathbar_show_next == chk.active){ return; }

			App.pathbar_show_next = chk.active;

			foreach(var pn in window.panes){
				pn.pathbar.refresh_icon_visibility();
			}
			window.pathbar.refresh_icon_visibility();
		});
	}

	private void add_pathbar_item_up(Gtk.Container box){

		var chk = new Gtk.CheckButton.with_label(_("Up"));
		box.add(chk);

		chk.active = App.pathbar_show_up;

		chk.toggled.connect(()=>{

			if (App.pathbar_show_up == chk.active){ return; }

			App.pathbar_show_up = chk.active;

			foreach(var pn in window.panes){
				pn.pathbar.refresh_icon_visibility();
			}
			window.pathbar.refresh_icon_visibility();
		});
	}

	private void add_pathbar_item_swap(Gtk.Container box){

		var chk = new Gtk.CheckButton.with_label(_("Swap"));
		box.add(chk);

		chk.active = App.pathbar_show_swap;

		chk.toggled.connect(()=>{

			if (App.pathbar_show_swap == chk.active){ return; }

			App.pathbar_show_swap = chk.active;

			foreach(var pn in window.panes){
				pn.pathbar.refresh_icon_visibility();
			}
			window.pathbar.refresh_icon_visibility();
		});
	}

	private void add_pathbar_item_other(Gtk.Container box){

		var chk = new Gtk.CheckButton.with_label(_("Open Opposite"));
		box.add(chk);

		chk.active = App.pathbar_show_other;

		chk.toggled.connect(()=>{

			if (App.pathbar_show_other == chk.active){ return; }

			App.pathbar_show_other = chk.active;

			foreach(var pn in window.panes){
				pn.pathbar.refresh_icon_visibility();
			}
			window.pathbar.refresh_icon_visibility();
		});
	}

	private void add_pathbar_item_close(Gtk.Container box){

		var chk = new Gtk.CheckButton.with_label(_("Close"));
		box.add(chk);

		chk.active = App.pathbar_show_close;

		chk.toggled.connect(()=>{

			if (App.pathbar_show_close == chk.active){ return; }

			App.pathbar_show_close = chk.active;

			foreach(var pn in window.panes){
				pn.pathbar.refresh_icon_visibility();
			}
			window.pathbar.refresh_icon_visibility();
		});
	}


	private void add_sidebar_option_visible(Gtk.Container box){

		var chk = new Gtk.CheckButton.with_label(_("Show"));
		chk.set_tooltip_text(_("Show the sidebar panel"));
		box.add(chk);

		chk.active = App.sidebar_visible;

		chk.toggled.connect(()=>{

			if (App.sidebar_visible == chk.active){ return; }

			App.sidebar_visible = chk.active;

			//window.toolbar.refresh_style();
			window.sidebar.refresh_visibility();
		});
	}

	private void add_sidebar_option_dark_theme(Gtk.Container box){

		var chk = new Gtk.CheckButton.with_label(_("Dark theme"));
		chk.set_tooltip_text(_("Requires theme support. Use the 'darker' variant of Gtk theme."));
		box.add(chk);

		chk.active = App.sidebar_dark;

		chk.toggled.connect(()=>{

			if (App.sidebar_dark == chk.active){ return; }

			App.sidebar_dark = chk.active;

			//window.toolbar.refresh_style();
			window.sidebar.refresh();
		});
	}

	private void add_sidebar_option_places(Gtk.Container box){

		var chk = new Gtk.CheckButton.with_label(_("Places"));
		chk.set_tooltip_text(_("Show 'Places' section in sidebar"));
		box.add(chk);

		chk.active = App.sidebar_places;

		chk.toggled.connect(()=>{

			if (App.sidebar_places == chk.active){ return; }

			App.sidebar_places = chk.active;

			window.sidebar.refresh();
		});
	}

	private void add_sidebar_option_bookmarks(Gtk.Container box){

		var chk = new Gtk.CheckButton.with_label(_("Bookmarks"));
		chk.set_tooltip_text(_("Show 'Bookmarks' section in sidebar"));
		box.add(chk);

		chk.active = App.sidebar_bookmarks;

		chk.toggled.connect(()=>{

			if (App.sidebar_bookmarks == chk.active){ return; }

			App.sidebar_bookmarks = chk.active;

			window.sidebar.refresh();
		});
	}

	private void add_sidebar_option_devices(Gtk.Container box){

		var chk = new Gtk.CheckButton.with_label(_("Devices"));
		chk.set_tooltip_text(_("Show 'Devices' section in sidebar"));
		box.add(chk);

		chk.active = App.sidebar_devices;

		chk.toggled.connect(()=>{

			if (App.sidebar_devices == chk.active){ return; }

			App.sidebar_devices = chk.active;

			window.sidebar.refresh();
		});
	}

	private void add_sidebar_option_unmount(Gtk.Container box){

		var chk = new Gtk.CheckButton.with_label(_("Unmount button"));
		chk.set_tooltip_text(_("Show Unmount button for mounted devices"));
		box.add(chk);

		chk.active = App.sidebar_unmount;

		chk.toggled.connect(()=>{

			if (App.sidebar_unmount == chk.active){ return; }

			App.sidebar_unmount = chk.active;

			window.sidebar.refresh();
		});
	}


	private void add_sidebar_option_lock(Gtk.Container box){

		var chk = new Gtk.CheckButton.with_label(_("Lock button"));
		chk.set_tooltip_text(_("Show Lock button for encrypted devices"));
		box.add(chk);

		chk.active = App.sidebar_lock;

		chk.toggled.connect(()=>{

			if (App.sidebar_lock == chk.active){ return; }

			App.sidebar_lock = chk.active;

			window.sidebar.refresh();
		});
	}


	private void add_statusbar_option_unified(Gtk.Container box){

		var chk = new Gtk.CheckButton.with_label(_("Global"));
		chk.set_tooltip_text(_("Show single statusbar for active pane"));
		box.add(chk);

		chk.active = App.statusbar_unified;

		chk.toggled.connect(()=>{

			if (App.statusbar_unified == chk.active){ return; }

			App.statusbar_unified = chk.active;

			foreach(var pn in window.panes){
				pn.statusbar.refresh_visibility();
			}

			window.statusbar.refresh_visibility();
		});
	}


	private void add_tabbar_option_below(Gtk.Container box){

		var chk = new Gtk.CheckButton.with_label(_("Tabs at bottom"));
		chk.set_tooltip_text(_("Show tabs at the bottom of the window"));
		box.add(chk);

		chk.active = App.tabs_bottom;

		chk.toggled.connect(()=>{

			if (App.tabs_bottom == chk.active){ return; }

			App.tabs_bottom = chk.active;

			foreach(var panel in window.layout_box.panels){
				panel.refresh_tab_style();
			}
		});
	}

	private void add_tabbar_option_close(Gtk.Container box){

		var chk = new Gtk.CheckButton.with_label(_("Close button"));
		chk.set_tooltip_text(_("Show tab close button (requires application restart)"));
		box.add(chk);

		chk.active = App.tabs_close_visible;

		chk.toggled.connect(()=>{

			if (App.tabs_close_visible == chk.active){ return; }

			App.tabs_close_visible = chk.active;

			foreach(var panel in window.layout_box.panels){
				panel.refresh_tab_style();
			}
		});
	}

	// Defaults ------------------------

	private void init_tab_defaults() {

		var box = new Box(Orientation.HORIZONTAL, 24);
		box.margin_left = 6;
		stack.add_titled (box, _("Defaults"), _("Defaults"));

		// options ---------------------------------

		var vbox_options = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
		vbox_options.homogeneous = false;
		box.add(vbox_options);

		var label = new Gtk.Label("<b>%s:</b>".printf(_("Options")));
		label.set_use_markup(true);
		label.xalign = (float) 0.0;
		label.margin_bottom = 12;
		vbox_options.add(label);

		var sg_label = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);
		var sg_combo = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);

		add_option_folder_handler(vbox_options, sg_label, sg_combo);
		
		add_option_view_mode(vbox_options, sg_label, sg_combo);

		//add_option_single_click_browse(vbox_options);

		add_option_restore_last_session(vbox_options);

		add_option_confirm_delete(vbox_options);

		add_option_confirm_trash(vbox_options);

		// ---------------------------------------------------------------
		
		vbox_options = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
		vbox_options.homogeneous = false;
		box.add(vbox_options);

		label = new Gtk.Label("<b>%s:</b>".printf(_("Startup & Windows")));
		label.set_use_markup(true);
		label.xalign = (float) 0.0;
		label.margin_bottom = 12;
		vbox_options.add(label);

		sg_label = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);
		sg_combo = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);

		add_option_maximize_on_startup(vbox_options);
		
		add_option_single_instance_mode(vbox_options);
		
		add_option_minimize_to_tray(vbox_options);

		add_option_autostart(vbox_options);
	}

	private void add_option_maximize_on_startup(Gtk.Box box){

		var chk = new Gtk.CheckButton.with_label(_("Maximize on startup"));
		box.add(chk);

		chk.active = App.maximise_on_startup;

		chk.toggled.connect(()=>{
			App.maximise_on_startup = chk.active;
		});
	}

	private void add_option_view_mode(Gtk.Box box, Gtk.SizeGroup sg_label, Gtk.SizeGroup sg_combo){

		var hbox = new Box(Orientation.HORIZONTAL,6);
		box.add(hbox);

		// label
		var label = new Label(_("Default View"));
		label.xalign = (float) 0.0;
		label.margin_left = 6;
		label.margin_right = 6;
		label.margin_bottom = 6;
		hbox.add(label);
		sg_label.add_widget(label);

		// cmb_app
		var combo = new ComboBox();
		combo.set_tooltip_text(_("Default view mode to use for new panes"));
		hbox.add (combo);
		sg_combo.add_widget(combo);

		// render text
		var cell_text = new CellRendererText();
		combo.pack_start(cell_text, false);
		combo.set_cell_data_func (cell_text, (cell_text, cell, model, iter) => {
			string text;
			model.get (iter, 1, out text, -1);
			(cell as Gtk.CellRendererText).text = text;
		});

		// add items
		var store = new Gtk.ListStore(2,
			typeof(PanelLayout),
			typeof(string));

		TreeIter iter;
		store.append(out iter);
		store.set (iter, 0, ViewMode.LIST, 1, _("List"), -1);
		store.append(out iter);
		store.set (iter, 0, ViewMode.ICONS, 1, _("Icons"), -1);
		store.append(out iter);
		store.set (iter, 0, ViewMode.TILES, 1, _("Tiles"), -1);
		store.append(out iter);
		store.set (iter, 0, ViewMode.MEDIA, 1, _("Media"), -1);

		combo.set_model (store);

		switch(App.view_mode){
		case ViewMode.LIST:
			combo.active = 0;
			break;
		case ViewMode.ICONS:
		default:
			combo.active = 1;
			break;
		case ViewMode.TILES:
			combo.active = 2;
			break;
		case ViewMode.MEDIA:
			combo.active = 3;
			break;
		}

		combo.changed.connect(() => {
			App.view_mode = (ViewMode) gtk_combobox_get_value_enum(combo, 0, App.view_mode);
		});
	}

	private void add_option_folder_handler(Gtk.Box box, Gtk.SizeGroup sg_label, Gtk.SizeGroup sg_combo){

		var hbox = new Box(Orientation.HORIZONTAL,6);
		box.add(hbox);

		// label
		var label = new Label(_("Default File Manager"));
		label.xalign = (float) 0.0;
		label.margin_left = 6;
		label.margin_right = 6;
		label.margin_bottom = 6;
		hbox.add(label);
		sg_label.add_widget(label);

		// cmb_app
		var combo = new ComboBox();
		combo.set_tooltip_text(_("Sets the default application for opening folders"));
		hbox.add (combo);
		sg_combo.add_widget(combo);

		// app icon --------
		
		var cell_pix = new Gtk.CellRendererPixbuf();
		cell_pix.xpad = 3;
		combo.pack_start(cell_pix, false);

		combo.set_cell_data_func (cell_pix, (cell_layout, cell, model, iter) => {

			var pixcell = cell as Gtk.CellRendererPixbuf;

			DesktopApp app;
			model.get (iter, 0, out app, -1);

			pixcell.pixbuf = IconManager.lookup(app.icon,16);
		});
		
		// app name -----------------
		
		var cell_text = new CellRendererText();
		combo.pack_start(cell_text, false);
		
		combo.set_cell_data_func (cell_text, (cell_text, cell, model, iter) => {
			DesktopApp app;
			model.get (iter, 0, out app, -1);
			(cell as Gtk.CellRendererText).text = app.name;
		});

		// model ----------------------
		
		// add items
		var store = new Gtk.ListStore(1, typeof(DesktopApp));

		TreeIter iter;

		var supported_apps = MimeApp.get_supported_apps("inode/directory");
		var default_app = MimeApp.get_default_app("inode/directory");

		int active = -1;
		int index = -1;
		foreach(var supported_app in supported_apps){
			store.append(out iter);
			store.set (iter, 0, supported_app, -1);
			index++;
			if ((default_app != null) && (default_app.name == supported_app.name)){
				active = index;
			}
		}

		combo.active = active;

		combo.set_model (store);

		combo.changed.connect(() => {
			
			if ((combo.model == null) || (combo.active < 0)) { return; }

			TreeIter iter0;
			combo.get_active_iter (out iter0);
			DesktopApp app;
			store.get(iter0, 0, out app);

			MimeApp.set_default("inode/directory", app);
		});
	}

	private void add_option_single_click_browse(Gtk.Box box){

		var chk = new Gtk.CheckButton.with_label(_("Single click to activate"));
		box.add(chk);

		chk.active = App.single_click_activate;

		chk.toggled.connect(()=>{

			App.single_click_activate = chk.active;

			//foreach(var v in window.views){
			//	v.refresh_single_click();
			//}
		});
	}

	private void add_option_single_instance_mode(Gtk.Box box){

		var chk = new Gtk.CheckButton.with_label(_("Single window mode"));
		box.add(chk);

		chk.active = App.single_instance_mode;

		chk.toggled.connect(()=>{

			App.single_instance_mode = chk.active;

			//foreach(var v in window.views){
			//	v.refresh_single_click();
			//}
		});
	}

	private void add_option_restore_last_session(Gtk.Box box){

		var chk = new Gtk.CheckButton.with_label(_("Remember last session"));
		box.add(chk);

		chk.active = App.restore_last_session;

		chk.toggled.connect(()=>{
			App.restore_last_session = chk.active;
		});
	}

	private void add_option_minimize_to_tray(Gtk.Box box){

		var chk = new Gtk.CheckButton.with_label(_("Minimize to tray"));
		box.add(chk);

		chk.set_tooltip_text(_("Minimize to system tray when window is closed instead of exiting the application. Opening another folder will be much faster, as the application would already be running in the background."));

		chk.active = App.minimize_to_tray;

		chk.toggled.connect(()=>{
			App.minimize_to_tray = chk.active;
		});
	}


	private void add_option_autostart(Gtk.Box box){

		var chk = new Gtk.CheckButton.with_label(_("Run at startup"));
		box.add(chk);

		chk.set_tooltip_text(_("Application will be started during system startup and will run minimized in system tray."));
		
		chk.active = App.autostart;

		chk.toggled.connect(()=>{
			App.autostart = chk.active;
		});
	}


	private void add_option_confirm_delete(Gtk.Box box){

		var chk = new Gtk.CheckButton.with_label(_("Confirm before deleting files"));
		box.add(chk);

		chk.active = App.confirm_delete;

		chk.toggled.connect(()=>{
			App.confirm_delete = chk.active;
		});
	}

	private void add_option_confirm_trash(Gtk.Box box){

		var chk = new Gtk.CheckButton.with_label(_("Confirm before trashing files"));
		box.add(chk);

		chk.active = App.confirm_trash;

		chk.toggled.connect(()=>{
			App.confirm_trash = chk.active;
		});
	}

	// zoom options -----------------------------------

	private void init_tab_zoom() {

		var box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 12);
		box.margin_left = 6;
		stack.add_titled (box, _("Zoom"), _("Zoom"));

		var sg_label = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);
		var sg_scale = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);

		// list view ------------------------

		var vbox = new Gtk.Box(Gtk.Orientation.VERTICAL, 12);
		box.add(vbox);

		var label = new Gtk.Label("<b>%s:</b>".printf(_("List View")));
		label.set_use_markup(true);
		label.xalign = 0.0f;
		//label.margin_bottom = 12;
		vbox.add(label);

		add_scale_listview_icon_size(vbox, sg_label, sg_scale);

		add_scale_listview_row_spacing(vbox, sg_label, sg_scale);

		add_scale_font_scale(vbox, sg_label, sg_scale);

		add_button_listview_reset(vbox, sg_label, sg_scale);

		add_options_listview_icons(vbox);

		var separator = new Gtk.Separator(Gtk.Orientation.VERTICAL);
		separator.margin_left = 12;
		box.add(separator);

		// icon view ------------------------

		vbox = new Gtk.Box(Gtk.Orientation.VERTICAL, 12);
		box.add(vbox);

		label = new Gtk.Label("<b>%s:</b>".printf(_("Icon View")));
		label.set_use_markup(true);
		label.xalign = 0.0f;
		//label.margin_bottom = 12;
		vbox.add(label);

		add_scale_iconview_icon_size(vbox, sg_label, sg_scale);

		add_scale_iconview_row_spacing(vbox, sg_label, sg_scale);

		add_scale_iconview_column_spacing(vbox, sg_label, sg_scale);

		add_button_iconview_reset(vbox, sg_label, sg_scale);

		add_options_iconview_icons(vbox);

		separator = new Gtk.Separator(Gtk.Orientation.VERTICAL);
		separator.margin_left = 12;
		box.add(separator);

		// tile view ------------------------

		vbox = new Gtk.Box(Gtk.Orientation.VERTICAL, 12);
		box.add(vbox);

		label = new Gtk.Label("<b>%s:</b>".printf(_("Tile View")));
		label.set_use_markup(true);
		label.xalign = 0.0f;
		//label.margin_bottom = 12;
		vbox.add(label);

		add_scale_tileview_icon_size(vbox, sg_label, sg_scale);

		add_scale_tileview_row_spacing(vbox, sg_label, sg_scale);

		add_scale_tileview_padding(vbox, sg_label, sg_scale);

		add_button_tileview_reset(vbox, sg_label, sg_scale);

		add_options_tileview_icons(vbox);
	}

	private Gtk.Scale add_scale(Gtk.Box box, double min_val, double max_val, double step, double val){

		var scale = new Gtk.Scale.with_range (Gtk.Orientation.HORIZONTAL, min_val, max_val, step);
		scale.has_origin = false;
		scale.draw_value = true;
		scale.value_pos = PositionType.RIGHT;
		scale.set_size_request(200, -1);
		scale.hexpand = false;
		scale.margin_left = 6;
		box.add(scale);

		scale.adjustment.value = val;

		return scale;
	}

	private void add_scale_font_scale(Gtk.Box box, Gtk.SizeGroup sg_label, Gtk.SizeGroup sg_scale) {

		var hbox = new Box(Orientation.VERTICAL, 6);
		box.add(hbox);

		var label = new Label(_("Font scale"));
		label.xalign = 0.0f;
		//label.margin_left = 6;
		hbox.add(label);
		sg_label.add_widget(label);

		var scale = add_scale(hbox, 0.8, 2.0, 0.1, App.listview_font_scale);
		scale.set_tooltip_text(_("Change font size"));
		sg_scale.add_widget(scale);
		scale_listview_font_scale = scale;

		scale.value_changed.connect(() => {
			if (App.listview_font_scale == scale.get_value()){
				return;
			}

			App.listview_font_scale = scale.get_value();

			foreach(var v in window.views){
				v.listview_font_scale = App.listview_font_scale;
				v.refresh();
			}
		});

		scale.format_value.connect((val) => {
			return "%.0f %%".printf(val * 100);
		});
	}

	private void add_scale_listview_icon_size(Gtk.Box box, Gtk.SizeGroup sg_label, Gtk.SizeGroup sg_scale) {

		var hbox = new Box(Orientation.VERTICAL, 6);
		box.add(hbox);

		var label = new Label(_("Icon size"));
		label.xalign = 0.0f;
		//label.margin_left = 6;
		hbox.add(label);
		sg_label.add_widget(label);

		var scale = add_scale(hbox, 0, listview_icon_sizes.size - 1, 1, listview_icon_sizes.index_of(App.listview_icon_size));
		scale.set_tooltip_text(_("Change icon size"));
		sg_scale.add_widget(scale);
		scale_listview_icon_size = scale;

		scale.value_changed.connect(() => {

			var index = (int) scale.get_value();

			log_debug("index=%d".printf(index));

			if (App.listview_icon_size == listview_icon_sizes[index]){
				return;
			}

			App.listview_icon_size = listview_icon_sizes[index];

			foreach(var v in window.views){
				v.listview_icon_size = App.listview_icon_size;
				v.refresh();
			}
		});

		scale.format_value.connect((val)=>{
			var index = (int) val;
			return "%.0f px".printf(listview_icon_sizes[index]);
		});

	}

	private void add_scale_listview_row_spacing(Gtk.Box box, Gtk.SizeGroup sg_label, Gtk.SizeGroup sg_scale) {

		var hbox = new Box(Orientation.VERTICAL, 6);
		box.add(hbox);

		var label = new Label(_("Row spacing"));
		label.xalign = 0.0f;
		//label.margin_left = 6;
		hbox.add(label);
		sg_label.add_widget(label);

		var scale = add_scale(hbox, 0, 10, 2, App.listview_row_spacing);
		scale.set_tooltip_text(_("Change row spacing"));
		sg_scale.add_widget(scale);
		scale_listview_row_spacing = scale;

		scale.value_changed.connect(() => {

			if (App.listview_row_spacing == (int) scale.get_value()){
				return;
			}

			App.listview_row_spacing = (int) scale.get_value();

			foreach(var v in window.views){
				v.listview_row_spacing = App.listview_row_spacing;
				v.refresh();
			}
		});

		scale.format_value.connect((val) => {
			return "%.0f px".printf(val);
		});
	}

	private void add_button_listview_reset(Gtk.Box box, Gtk.SizeGroup sg_label, Gtk.SizeGroup sg_scale) {

		var hbox = new Gtk.Box(Orientation.HORIZONTAL, 6);
		hbox.margin_top = 12;
		box.add(hbox);

		// reset

		var button = new Gtk.Button.with_label(_("Reset"));
		button.set_tooltip_text(_("Set default values"));
		hbox.add(button);

		button.clicked.connect(() => {
			scale_listview_icon_size.set_value(listview_icon_sizes.index_of(Main.LV_ICON_SIZE));
			scale_listview_row_spacing.set_value(Main.LV_ROW_SPACING);
			scale_listview_font_scale.set_value(Main.LV_FONT_SCALE);
		});
	}

	private void add_options_listview_icons(Gtk.Box box) {

		var hbox = new Box(Orientation.VERTICAL, 6);
		hbox.margin_bottom = 12;
		box.add(hbox);

		var label = new Gtk.Label("<b>%s:</b>".printf(_("Icons")));
		label.set_use_markup(true);
		label.xalign = 0.0f;
		//label.margin_bottom = 12;
		hbox.add(label);

		add_option_listview_emblems(hbox);
		add_option_listview_thumbs(hbox);
		add_option_listview_transparency(hbox);
	}

	private void add_option_listview_emblems(Gtk.Box box){

		var chk = new Gtk.CheckButton.with_label(_("Emblems"));
		box.add(chk);

		chk.set_tooltip_text(_("Draw tiny emblems on the icon or thumbnail image to indicate folder contents, symlinks and read-only permissions.\n\nDisable this for faster loading of directories."));

		chk.active = App.listview_emblems;

		chk.toggled.connect(()=>{
			App.listview_emblems = chk.active;
			window.refresh_treemodels();
		});
	}

	private void add_option_listview_thumbs(Gtk.Box box){

		var chk = new Gtk.CheckButton.with_label(_("Thumbnails"));
		box.add(chk);

		chk.set_tooltip_text(_("Show thumbnail previews in place of icons.\n\nDisable this for faster loading of directories."));

		chk.active = App.listview_thumbs;

		chk.toggled.connect(()=>{
			App.listview_thumbs = chk.active;
			window.refresh_treemodels();
		});
	}

	private void add_option_listview_transparency(Gtk.Box box){

		var chk = new Gtk.CheckButton.with_label(_("Transparency"));
		box.add(chk);

		chk.set_tooltip_text(_("Draw semi-transparent icons and thumbnails for hidden items"));

		chk.active = App.listview_transparency;

		chk.toggled.connect(()=>{
			App.listview_transparency = chk.active;
			window.refresh_treemodels();
		});
	}

	private void add_scale_iconview_icon_size(Gtk.Box box, Gtk.SizeGroup sg_label, Gtk.SizeGroup sg_scale) {

		var hbox = new Box(Orientation.VERTICAL, 6);
		box.add(hbox);

		var label = new Label(_("Icon size"));
		label.xalign = 0.0f;
		//label.margin_left = 6;
		hbox.add(label);
		sg_label.add_widget(label);

		var scale = add_scale(hbox, 0, iconview_icon_sizes.size - 1, 1, iconview_icon_sizes.index_of(App.iconview_icon_size));
		scale.set_tooltip_text(_("Change icon size"));
		sg_scale.add_widget(scale);
		scale_iconview_icon_size = scale;

		scale.value_changed.connect(() => {

			var index = (int) scale.get_value();

			if (App.iconview_icon_size == iconview_icon_sizes[index]){
				return;
			}

			App.iconview_icon_size = iconview_icon_sizes[index];

			foreach(var v in window.views){
				v.iconview_icon_size = App.iconview_icon_size;
				v.refresh();
			}
		});

		scale.format_value.connect((val)=>{
			var index = (int) val;
			return "%.0f px".printf(iconview_icon_sizes[index]);
		});
	}

	private void add_scale_iconview_row_spacing(Gtk.Box box, Gtk.SizeGroup sg_label, Gtk.SizeGroup sg_scale) {

		var hbox = new Box(Orientation.VERTICAL, 6);
		box.add(hbox);

		var label = new Label(_("Row spacing"));
		label.xalign = 0.0f;
		//label.margin_left = 6;
		hbox.add(label);
		sg_label.add_widget(label);

		var scale = add_scale(hbox, 0, 30, 2, App.iconview_row_spacing);
		scale.set_tooltip_text(_("Change row spacing"));
		sg_scale.add_widget(scale);
		scale_iconview_row_spacing = scale;

		scale.value_changed.connect(() => {

			if (App.iconview_row_spacing == (int) scale.get_value()){
				return;
			}

			App.iconview_row_spacing = (int) scale.get_value();

			foreach(var v in window.views){
				v.iconview_row_spacing = App.iconview_row_spacing;
				v.refresh_iconview();
			}
		});

		scale.format_value.connect((val) => {
			return "%.0f px".printf(val);
		});
	}

	private void add_scale_iconview_column_spacing(Gtk.Box box, Gtk.SizeGroup sg_label, Gtk.SizeGroup sg_scale) {

		var hbox = new Box(Orientation.VERTICAL, 6);
		box.add(hbox);

		var label = new Label(_("Col spacing"));
		label.xalign = 0.0f;
		//label.margin_left = 6;
		hbox.add(label);
		sg_label.add_widget(label);

		var scale = add_scale(hbox, 0, 60, 2, App.iconview_column_spacing);
		scale.set_tooltip_text(_("Change column spacing"));
		sg_scale.add_widget(scale);
		scale_iconview_column_spacing = scale;

		scale.value_changed.connect(() => {
			if (App.iconview_column_spacing == (int) scale.get_value()){
				return;
			}

			App.iconview_column_spacing = (int) scale.get_value();

			foreach(var v in window.views){
				v.iconview_column_spacing = App.iconview_column_spacing;
				v.refresh_iconview();
			}
		});

		scale.format_value.connect((val) => {
			return "%.0f px".printf(val);
		});
	}

	private void add_button_iconview_reset(Gtk.Box box, Gtk.SizeGroup sg_label, Gtk.SizeGroup sg_scale) {

		var hbox = new Gtk.Box(Orientation.HORIZONTAL, 6);
		hbox.margin_top = 12;
		box.add(hbox);

		// reset

		var button = new Gtk.Button.with_label(_("Reset"));
		button.set_tooltip_text(_("Set default values"));
		hbox.add(button);

		button.clicked.connect(() => {
			scale_iconview_icon_size.set_value(iconview_icon_sizes.index_of(Main.IV_ICON_SIZE));
			scale_iconview_row_spacing.set_value(Main.IV_ROW_SPACING);
			scale_iconview_column_spacing.set_value(Main.IV_COLUMN_SPACING);
		});
	}

	private void add_options_iconview_icons(Gtk.Box box) {

		var hbox = new Box(Orientation.VERTICAL, 6);
		hbox.margin_bottom = 12;
		box.add(hbox);

		var label = new Gtk.Label("<b>%s:</b>".printf(_("Icons")));
		label.set_use_markup(true);
		label.xalign = 0.0f;
		//label.margin_bottom = 12;
		hbox.add(label);

		add_option_iconview_emblems(hbox);
		add_option_iconview_thumbs(hbox);
		add_option_iconview_transparency(hbox);
	}

	private void add_option_iconview_emblems(Gtk.Box box){

		var chk = new Gtk.CheckButton.with_label(_("Emblems"));
		box.add(chk);

		chk.set_tooltip_text(_("Draw tiny emblems on the icon or thumbnail image to indicate folder contents, symlinks and read-only permissions.\n\nDisable this for faster loading of directories."));

		chk.active = App.iconview_emblems;

		chk.toggled.connect(()=>{
			App.iconview_emblems = chk.active;
			window.refresh_treemodels();
		});
	}

	private void add_option_iconview_thumbs(Gtk.Box box){

		var chk = new Gtk.CheckButton.with_label(_("Thumbnails"));
		box.add(chk);

		chk.set_tooltip_text(_("Show thumbnail previews in place of icons.\n\nDisable this for faster loading of directories."));

		chk.active = App.iconview_thumbs;

		chk.toggled.connect(()=>{
			App.iconview_thumbs = chk.active;
			window.refresh_treemodels();
		});
	}

	private void add_option_iconview_transparency(Gtk.Box box){

		var chk = new Gtk.CheckButton.with_label(_("Transparency"));
		box.add(chk);

		chk.set_tooltip_text(_("Draw semi-transparent icons and thumbnails for hidden items"));

		chk.active = App.iconview_transparency;

		chk.toggled.connect(()=>{
			App.iconview_transparency = chk.active;
			window.refresh_treemodels();
		});
	}

	private void add_scale_tileview_icon_size(Gtk.Box box, Gtk.SizeGroup sg_label, Gtk.SizeGroup sg_scale) {

		var hbox = new Box(Orientation.VERTICAL, 6);
		box.add(hbox);

		var label = new Label(_("Icon size"));
		label.xalign = 0.0f;
		//label.margin_left = 6;
		hbox.add(label);
		sg_label.add_widget(label);

		var scale = add_scale(hbox, 0, tileview_icon_sizes.size - 1, 1, tileview_icon_sizes.index_of(App.tileview_icon_size));
		scale.set_tooltip_text(_("Change icon size"));
		sg_scale.add_widget(scale);
		scale_tileview_icon_size = scale;

		scale.value_changed.connect(() => {

			var index = (int) scale.get_value();

			if (App.tileview_icon_size == tileview_icon_sizes[index]){
				return;
			}

			App.tileview_icon_size = tileview_icon_sizes[index];

			foreach(var v in window.views){
				v.tileview_icon_size = App.tileview_icon_size;
				v.refresh();
			}
		});

		scale.format_value.connect((val)=>{
			var index = (int) val;
			return "%.0f px".printf(tileview_icon_sizes[index]);
		});
	}

	private void add_scale_tileview_row_spacing(Gtk.Box box, Gtk.SizeGroup sg_label, Gtk.SizeGroup sg_scale) {

		var hbox = new Box(Orientation.VERTICAL, 6);
		box.add(hbox);

		var label = new Label(_("Row spacing"));
		label.xalign = 0.0f;
		//label.margin_left = 6;
		hbox.add(label);
		sg_label.add_widget(label);

		var scale = add_scale(hbox, 0, 30, 2, App.tileview_row_spacing);
		scale.set_tooltip_text(_("Change row spacing"));
		sg_scale.add_widget(scale);
		scale_tileview_row_spacing = scale;

		scale.value_changed.connect(() => {

			if (App.tileview_row_spacing == (int) scale.get_value()){
				return;
			}

			App.tileview_row_spacing = (int) scale.get_value();

			foreach(var v in window.views){
				v.tileview_row_spacing = App.tileview_row_spacing;
				v.refresh_iconview();
			}
		});

		scale.format_value.connect((val) => {
			return "%.0f px".printf(val);
		});
	}

	private void add_scale_tileview_padding(Gtk.Box box, Gtk.SizeGroup sg_label, Gtk.SizeGroup sg_scale) {

		var hbox = new Box(Orientation.VERTICAL, 6);
		box.add(hbox);

		var label = new Label(_("Padding"));
		label.xalign = 0.0f;
		//label.margin_left = 6;
		hbox.add(label);
		sg_label.add_widget(label);

		var scale = add_scale(hbox, 0, 20, 2, App.tileview_padding);
		scale.set_tooltip_text(_("Change column spacing"));
		sg_scale.add_widget(scale);
		scale_tileview_padding = scale;

		scale_tileview_padding.sensitive = false;

		scale.value_changed.connect(() => {
			if (App.tileview_padding == (int) scale.get_value()){
				return;
			}

			App.tileview_padding = (int) scale.get_value();

			foreach(var v in window.views){
				v.tileview_padding = App.tileview_padding;
				v.refresh_iconview();
			}
		});

		scale.format_value.connect((val) => {
			return "%.0f px".printf(val);
		});
	}

	private void add_button_tileview_reset(Gtk.Box box, Gtk.SizeGroup sg_label, Gtk.SizeGroup sg_scale) {

		var hbox = new Gtk.Box(Orientation.HORIZONTAL, 6);
		hbox.margin_top = 12;
		box.add(hbox);

		// reset

		var button = new Gtk.Button.with_label(_("Reset"));
		button.set_tooltip_text(_("Set default values"));
		hbox.add(button);

		button.clicked.connect(() => {
			scale_tileview_icon_size.set_value(tileview_icon_sizes.index_of(Main.TV_ICON_SIZE));
			scale_tileview_row_spacing.set_value(Main.TV_ROW_SPACING);
			scale_tileview_padding.set_value(Main.TV_PADDING);
		});
	}

	private void add_options_tileview_icons(Gtk.Box box) {

		var hbox = new Box(Orientation.VERTICAL, 6);
		hbox.margin_bottom = 12;
		box.add(hbox);

		var label = new Gtk.Label("<b>%s:</b>".printf(_("Icons")));
		label.set_use_markup(true);
		label.xalign = 0.0f;
		hbox.add(label);

		add_option_tileview_emblems(hbox);
		add_option_tileview_thumbs(hbox);
		add_option_tileview_transparency(hbox);
	}

	private void add_option_tileview_emblems(Gtk.Box box){

		var chk = new Gtk.CheckButton.with_label(_("Emblems"));
		box.add(chk);

		chk.set_tooltip_text(_("Draw tiny emblems on the icon or thumbnail image to indicate folder contents, symlinks and read-only permissions.\n\nDisable this for faster loading of directories."));

		chk.active = App.tileview_emblems;

		chk.toggled.connect(()=>{
			App.tileview_emblems = chk.active;
			window.refresh_treemodels();
		});
	}

	private void add_option_tileview_thumbs(Gtk.Box box){

		var chk = new Gtk.CheckButton.with_label(_("Thumbnails"));
		box.add(chk);

		chk.set_tooltip_text(_("Show thumbnail previews in place of icons.\n\nDisable this for faster loading of directories."));

		chk.active = App.tileview_thumbs;

		chk.toggled.connect(()=>{
			App.tileview_thumbs = chk.active;
			window.refresh_treemodels();
		});
	}

	private void add_option_tileview_transparency(Gtk.Box box){

		var chk = new Gtk.CheckButton.with_label(_("Transparency"));
		box.add(chk);

		chk.set_tooltip_text(_("Draw semi-transparent icons and thumbnails for hidden items"));

		chk.active = App.tileview_transparency;

		chk.toggled.connect(()=>{
			App.tileview_transparency = chk.active;
			window.refresh_treemodels();
		});
	}

	private int listview_icon_size{
		get{
			int index = (int) scale_listview_icon_size.get_value();
			return listview_icon_sizes[index];
		}
		set{
			scale_listview_icon_size.set_value(listview_icon_sizes.index_of(value));
		}
	}

	private int iconview_icon_size{
		get{
			int index = (int) scale_iconview_icon_size.get_value();
			return iconview_icon_sizes[index];
		}
		set{
			scale_iconview_icon_size.set_value(iconview_icon_sizes.index_of(value));
		}
	}

	// list view options -----------------------------------

	private void init_tab_list_view() {
		
		var box = new ColumnSelectionBox(parent_window, false);
		box.refresh_list_view_columns();
		box.margin_left = 6;
		
		stack.add_titled (box, _("List View"), _("List View"));
	}

	private void add_option_tree_navigation(Gtk.Container box){

		var chk = new Gtk.CheckButton.with_label(_("Tree navigation"));
		//chk.active = App.list_view_tree_nav;
		box.add(chk);

		chk.toggled.connect(()=>{
			//App.list_view_tree_nav = chk.active;

			//if (pane == null){ return; }

			//foreach(var v in window.layout_box.panels){
			//	v.pane.refresh();
			//}
		});
	}

	public void refresh(){

		this.forall ((element) => this.remove (element));

		init_ui();
	}

	// Defaults ------------------------

	private void init_tab_terminal() {

		var box = new Box(Orientation.HORIZONTAL, 24);
		box.margin_left = 6;
		stack.add_titled (box, _("Terminal"), _("Terminal"));

		// options ---------------------------------

		var vbox_options = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
		vbox_options.homogeneous = false;
		box.add(vbox_options);

		var label = new Gtk.Label("<b>%s:</b>".printf(_("Options")));
		label.set_use_markup(true);
		label.xalign = (float) 0.0;
		label.margin_bottom = 12;
		vbox_options.add(label);

		add_option_network(vbox_options);
		
		add_option_gui(vbox_options);
	}

	private void add_option_network(Gtk.Box box){

		var chk = new Gtk.CheckButton.with_label(_("Chroot: Enable network"));
		box.add(chk);

		chk.set_tooltip_text(_("Allows network connection to be used inside the chroot environment"));

		chk.active = App.term_enable_network;

		chk.toggled.connect(()=>{
			App.term_enable_network = chk.active;
		});
	}

	private void add_option_gui(Gtk.Box box){

		var chk = new Gtk.CheckButton.with_label(_("Chroot: Enable GUI Apps"));
		box.add(chk);

		chk.set_tooltip_text(_("Allows X-window apps running inside the chroot environment to use the host display"));

		chk.active = App.term_enable_gui;

		chk.toggled.connect(()=>{
			App.term_enable_gui = chk.active;
		});
	}
}




