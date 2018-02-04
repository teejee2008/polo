/*
 * Sidebar.vala
 *
 * Copyright 2012-18 Tony George <teejeetech@gmail.com>
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

public class Sidebar : Gtk.Box {

	// reference properties ----------

	private MainWindow window{
		get { return App.main_window; }
	}

	FileViewPane _pane;
	private FileViewPane? pane {
		get{
			if (_pane != null){ return _pane; }
			else { return window.active_pane; }
		}
	}

	private FileViewList? view{
		get{ return (pane == null) ? null : pane.view; }
	}

	private LayoutPanel? panel {
		get { return (pane == null) ? null : pane.panel; }
	}

	// -------------------------------

	private Gtk.ListBox listbox;
	private Gtk.ScrolledWindow scrolled;
	//private Gtk.ListBoxRow current_row;

	private Gee.HashMap<string, bool> node_expanded = new Gee.HashMap<string, bool>();
	private Gtk.SizeGroup sg_label;
	private Gtk.SizeGroup sg_size;
	private Gtk.SizeGroup sg_mount;

	private DeviceContextMenu menu_device;
	private BookmarkContextMenu menu_bookmark;

	public signal void toggled();
	public signal void row_activated(TreeView treeview, TreeIter iter, SidebarItem item);

	public Gee.ArrayList<string> collapsed_sections = new Gee.ArrayList<string>();

	private Gtk.Popover? popover;
	private string popup_mode;

	public bool popup {
		get{
			return (popover != null);
		}
	}

	public bool is_bm_popup {
		get{
			return (popover != null) && (popup_mode == "bm");
		}
	}

	public bool is_device_popup {
		get{
			return (popover != null) && (popup_mode == "device");
		}
	}

	// contructors

	public Sidebar(Gtk.Popover? _popover, string? mode, FileViewPane? parent_pane){
		//base(Gtk.Orientation.VERTICAL, 6); // issue with vala
		Object(orientation: Gtk.Orientation.VERTICAL, spacing: 0); // work-around
		//parent_window = _parent_window;
		margin = 0;

		_pane = parent_pane;

		popover = _popover;
		if (mode != null){
			popup_mode = mode;
		}

		sg_label = new Gtk.SizeGroup(Gtk.SizeGroupMode.HORIZONTAL);
		sg_size = new Gtk.SizeGroup(Gtk.SizeGroupMode.HORIZONTAL);
		sg_mount = new Gtk.SizeGroup(Gtk.SizeGroupMode.HORIZONTAL);

		listbox = new Gtk.ListBox ();
		listbox.selection_mode = Gtk.SelectionMode.SINGLE;
		listbox.vexpand = true;

		//listbox.drag_data_received.connect(on_drag_data_received);
		//listbox.drag_data_get.connect(on_drag_data_get);

		listbox.row_activated.connect(on_listbox_row_activated);

		if (popup){
			add(listbox);
		}
		else {
			//scrolled
			scrolled = new Gtk.ScrolledWindow(null, null);
			scrolled.vexpand = true;
			scrolled.set_shadow_type(ShadowType.ETCHED_IN);
			scrolled.hscrollbar_policy = popup ? PolicyType.NEVER : PolicyType.AUTOMATIC;
			scrolled.vscrollbar_policy = PolicyType.AUTOMATIC;
			//scrolled.margin_right = 3;
			add(scrolled);

			scrolled.add(listbox);

			//refresh_visibility();
		}

		if (!popup){
			if (!App.sidebar_visible){
				this.set_no_show_all(true);
			}
		}

		collapsed_sections = new Gee.ArrayList<string>();
		foreach(var item in App.sidebar_collapsed_sections.split(",")){
			if (!collapsed_sections.contains(item)){
				collapsed_sections.add(item);
			}
		}

		DeviceMonitor.get_monitor().changed.connect(()=>{
			this.refresh();
		});
	}

	private void on_listbox_row_activated(Gtk.ListBoxRow row){

		var item = (SidebarItem) row.get_data<SidebarItem>("item");

		if (item.node_key.length > 0){

			log_debug("sidebar: header_activated");
			node_expanded[item.node_key] = !node_expanded[item.node_key];

			if (node_expanded[item.node_key]){
				if (collapsed_sections.contains(item.node_key)){
					collapsed_sections.remove(item.node_key);
				}
			}
			else{
				if (!collapsed_sections.contains(item.node_key)){
					collapsed_sections.add(item.node_key);
				}
			}

			add_refresh_delayed();
			return;
		}

		switch(item.type){
		case SidebarItemType.BOOKMARK:

			log_debug("sidebar: bookmark_activated: %s".printf(item.bookmark.path));

			if (popup){
				popover.hide();
				//window.sidebar.refresh(); // not needed
			}
			else{
				//refresh(); // not needed
			}

			if (item.bookmark.path.length > 0){
				pane.view.set_view_path(item.bookmark.path);
			}
			else{
				pane.view.set_view_path(item.bookmark.uri);
			}

			break;

		case SidebarItemType.BOOKMARK_ACTION_ADD:

			if (pane.view.current_item != null){

				var path = pane.view.current_item.file_path;
				var uri = pane.view.current_item.file_uri;

				if (!GtkBookmark.is_bookmarked(uri) && (path != "/") && (path != App.user_home)){
					GtkBookmark.add_bookmark(uri);
				}
			}

			if (popup){
				popover.hide();
				window.sidebar.refresh();
				pane.pathbar.refresh_icon_state();
			}
			else{
				refresh();
			}

			break;

		case SidebarItemType.BOOKMARK_ACTION_REMOVE:

			if (pane.view.current_item != null){

				var path = pane.view.current_item.file_path;
				var uri = pane.view.current_item.file_uri;

				if (GtkBookmark.is_bookmarked(uri) && (path != "/") && (path != App.user_home)){
					GtkBookmark.remove_bookmark(uri);
				}
			}

			if (popup){
				popover.hide();
				window.sidebar.refresh();
				pane.pathbar.refresh_icon_state();
			}
			else{
				refresh();
			}
			break;

		case SidebarItemType.DEVICE:

			DeviceContextMenu.browse_device(item.device, pane, window);

			if (popup){
				popover.hide();
			}

			break;
		}
	}

	private uint tmr_refresh_delayed = 0;

	private void add_refresh_delayed(){

		clear_refresh_delayed();

		tmr_refresh_delayed = Timeout.add(100, refresh_delayed);
	}

	private void clear_refresh_delayed(){
		if (tmr_refresh_delayed > 0){
			Source.remove(tmr_refresh_delayed);
			tmr_refresh_delayed = 0;
		}
		gtk_set_busy(false, window);
	}

	private bool refresh_delayed(){

		clear_refresh_delayed();

		log_debug("refresh_delayed()");

		refresh();

		return false;
	}

	// refresh

	public void refresh() {

		Device.print_device_list();

		if (listbox == null){ return; }

		if (!window.window_is_ready) { return; }

		if (!popup && !App.sidebar_visible){ return; }

		if (popup && !visible){ return; }

		log_debug("sidebar: refresh(%s): %s".printf((popup ? "popup" : ""), view.paneid));

		apply_css_listbox();

		listbox.forall ((x) => listbox.remove(x));

		string txt = "";
		foreach(string item in collapsed_sections){
			if (txt.length > 0){
				txt += ",";
			}
			txt += item;
		}
		App.sidebar_collapsed_sections = txt;

		SidebarItem item = null;

		if (popup && (popup_mode == "bm")){
			add_bookmark_action();
		}

		if (!popup || (popup_mode == "bm")){

			if (popup || App.sidebar_places){

				item = add_header_locations(_("Places"));

				log_debug("sidebar: add_places()");

				if (node_expanded[item.node_key]){

                                        for(int i = 0; i < App.places_labels.length; i++) {

                                                string label = _(App.places_labels[i]);

                                                if (App.places_labels[i] == "Trash") {
                                                        label = _(App.places_labels[i]) + " (%s)".printf(format_file_size(App.trashcan.trash_can_size));
                                                }

                                                add_bookmark(new GtkBookmark(App.places_paths[i], label));
                                        }

					foreach(var mount in GvfsMounts.get_mounts(App.user_id)){
						var bm = new GtkBookmark(mount.file_uri, mount.display_name);
						add_bookmark(bm);
					}

					//var bm = new GtkBookmark("network:///", _("Network"));
					//add_bookmark(bm);
				}
			}

			if (popup || App.sidebar_bookmarks){

				item = add_header_bookmarks(_("Bookmarks"));

				log_debug("sidebar: add_bookmarks()");

				if (node_expanded[item.node_key]){
					foreach(var bm in GtkBookmark.bookmarks){
						add_bookmark(bm, true);
					}
				}
			}
		}

		log_debug("sidebar: add_devices()");

		if (!popup || (popup_mode == "device")){

			if (popup || App.sidebar_devices){

				if (!popup){
					item = add_header_devices(_("Devices"));
				}

				if (popup || node_expanded[item.node_key]){

					var list = Main.get_devices();

					foreach(var dev in list){

						if (dev.pkname.length == 0){ // type = disk, loop

							item = add_device(dev);

							if (!node_expanded.has_key(item.node_key) || node_expanded[item.node_key]){

								foreach(var child1 in dev.children){
									if (child1.has_children){
										foreach(var child2 in child1.children){
											add_device(child2);
										}
									}
									else{
										add_device(child1);
									}
								}

								if (dev.children.size == 0){
									var dev2 = dev.copy();
									dev2.type = "part";
									dev2.pkname = dev.device.replace("/dev/","");
									dev2.parent = dev;
									add_device(dev2);
								}
							}
						}
					}
				}
			}
		}

		log_debug("sidebar: add_buffer()");

		// buffer
		var row = new Gtk.ListBoxRow();
		row.activatable = false;
		row.selectable = false;
		row.vexpand = true;
		listbox.add(row);

		// label is required to fix am issue with Greybird theme
		var label = new Gtk.Label("");
		label.vexpand = true;
		row.add(label);

		apply_css_row(row, label);

		if (!popup){
			label.margin_bottom = 6;
		}

		this.show_all(); // set_no_show_all is already false
	}

	public void refresh_visibility(){

		if (App.sidebar_visible){
			sidebar_show();
		}
		else{
			sidebar_hide();
		}
	}

	public void sidebar_show(){

		log_debug("sidebar_show");

		App.sidebar_visible = true;

		this.set_no_show_all(false);

		refresh(); // calls show_all()

		App.sidebar_position = 250;
		window.restore_sidebar_position();
	}

	public void sidebar_hide(){

		log_debug("sidebar_hide");

		window.save_sidebar_position();

		App.sidebar_visible = false;

		this.set_no_show_all(true);
		this.hide();
	}


	private SidebarItem add_header_locations(string name){
		var item = new SidebarItem.for_header(name, SidebarItemType.HEADER_LOCATIONS);
		add_missing_node_key(item);
		add_item(item);
		return item;
	}

	private SidebarItem add_header_bookmarks(string name){
		var item = new SidebarItem.for_header(name, SidebarItemType.HEADER_BOOKMARKS);
		add_missing_node_key(item);
		add_item(item);
		return item;
	}

	private SidebarItem add_header_devices(string name){
		var item = new SidebarItem.for_header(name, SidebarItemType.HEADER_DEVICES);
		add_missing_node_key(item);
		add_item(item);
		return item;
	}


	private void add_missing_node_key(SidebarItem item){
		if ((item.node_key.length > 0) && !node_expanded.has_key(item.node_key)){
			bool expanded = !collapsed_sections.contains(item.node_key);
			node_expanded[item.node_key] = expanded;
		}
	}

	private void add_bookmark(GtkBookmark bm, bool allow_edit = false){
		var item = new SidebarItem.from_bookmark(bm);
		add_item(item, allow_edit);
	}

	private void add_bookmark_action(){

		SidebarItemType sbtype = SidebarItemType.BOOKMARK_ACTION_ADD;
		string sbname = "";
		string tt = "";

		if (pane.view.current_item != null){

			var path = pane.view.current_item.file_path;

			if (GtkBookmark.is_bookmarked(path)){

				sbtype = SidebarItemType.BOOKMARK_ACTION_REMOVE;
				sbname = _("Remove bookmark");
				tt = _("Remove bookmark for this location");
			}
			else{
				sbtype = SidebarItemType.BOOKMARK_ACTION_ADD;
				sbname = _("Add bookmark");
				tt = _("Add bookmark for this location");
			}

			var item = new SidebarItem.bookmark_action(sbname, sbtype);
			item.tooltip = tt;
			add_item(item);
		}
	}

	private SidebarItem? add_device(Device dev){

		if (dev.is_snap_volume || dev.is_swap_volume){
			return null;
		}

		if (dev.size_bytes < 100 * KB){
			return null;
		}

		var item = new SidebarItem.from_device(dev, popup);

		if (popup){
			item.node_key = "";
		}

		add_missing_node_key(item);
		add_item(item);

		return item;
	}


	private void apply_css_row(Gtk.ListBoxRow row, Gtk.Label label){

		if (App.sidebar_dark && !popup){

			gtk_apply_css({ row }, "background-color: @wm_bg;"); //#353945

			if (label.sensitive){
				gtk_apply_css({ label }, " color: #D3DAE3; "); // sensitive
			}
			else{
				gtk_apply_css({ label }, " color: alpha(#D3DAE3, 0.5); "); // insensitive
			}
		}
		else{
			//gtk_apply_css({ row }, "background-color: #FFFFFF;"); //#353945
			//no need to apply default colors as row and labels are created again on refresh
		}
	}

	private void apply_css_listbox(){

		if (scrolled == null) { return; }

		if (App.sidebar_dark && !popup){
			gtk_apply_css({ listbox }, "background-color: @wm_bg;"); //#353945
			scrolled.set_shadow_type(ShadowType.NONE);
		}
		else{
			gtk_apply_css({ listbox }, "background-color: @content_view_bg;"); //#FFFFFF
			scrolled.set_shadow_type(ShadowType.NONE);
		}

		listbox.get_style_context().add_class("sidebar");
	}


	private void add_item(SidebarItem item, bool allow_edit = false){

		switch(item.type){

		case SidebarItemType.HEADER_LOCATIONS:
		case SidebarItemType.HEADER_BOOKMARKS:
		case SidebarItemType.HEADER_DEVICES:

			add_item_header(item, allow_edit);
			break;

		case SidebarItemType.BOOKMARK:

			add_item_bookmark(item, allow_edit);
			break;

		case SidebarItemType.BOOKMARK_ACTION_ADD:
		case SidebarItemType.BOOKMARK_ACTION_REMOVE:

			add_item_bookmark_action(item, allow_edit);
			break;

		case SidebarItemType.HEADER_DISK:

			add_item_device_header(item, allow_edit);
			break;

		case SidebarItemType.DEVICE:

			add_item_device(item, allow_edit);
			break;
		}
	}

	private void add_item_header(SidebarItem item, bool allow_edit = false){

		var row = new Gtk.ListBoxRow();
		row.activatable = false;
		row.selectable = false;
		listbox.add(row);

		row.set_data<SidebarItem>("item", item);

		var box = new Gtk.Box(Orientation.HORIZONTAL, 3);
		row.add(box);

		// icon
		var image = new Gtk.Image();
		box.add(image);

		var vbox = new Gtk.Box(Orientation.VERTICAL, 0);
		vbox.margin_right = 12;
		box.add(vbox);
		//var label_box = vbox;

		// name
		var label = new Gtk.Label("");
		label.xalign = 0.0f;
		//label.margin_right = 3;
		label.ellipsize = Pango.EllipsizeMode.END;
		vbox.add(label);

		if (item.node_key.length > 0){
			if (node_expanded[item.node_key]){
				image.pixbuf = IconManager.lookup("collapse-menu-symbolic", 16, false);
			}
			else{
				image.pixbuf = IconManager.lookup("expand-menu-symbolic", 16, false);
			}
		}

		// -----------------------------------

		row.margin_left = 0;
		row.activatable = true;

		label.label = "<b>%s</b>".printf(item.name);
		label.set_use_markup(true);
		label.margin_top = 6;

		// -----------------------------------

		apply_css_row(row, label);

		// label for right margin
		var lbl = new Gtk.Label("");
		lbl.margin_right = 12;
		box.add(lbl);
	}

	private void add_item_device(SidebarItem item, bool allow_edit = false){

		var row = new Gtk.ListBoxRow();
		row.activatable = true;
		row.selectable = false;
		listbox.add(row);

		row.set_data<SidebarItem>("item", item);

		var dev = item.device;

		// create tooltip -----------------------------------------

		string tt = "";

		tt += "%s: %s\n".printf(_("Device"), dev.device);

		if (dev.mapped_name.length > 0){
			tt += "%s: %s\n".printf(_("Mapped"), "/dev/mapper/%s".printf(dev.mapped_name));
		}

		tt += "%s: %s\n".printf(_("UUID"), dev.uuid);

		tt += "%s: %s\n".printf(_("Label"), ((dev.label.length > 0) ? dev.label : _("(empty)")));

		tt += "%s: %s\n".printf(_("PartLabel"), ((dev.partlabel.length > 0) ? dev.partlabel : _("(empty)")));

		tt += "%s: %s\n".printf(_("Filesystem"), dev.fstype);

		if (dev.is_mounted){
			tt += "%s: %s\n".printf(_("Mount"), dev.mount_points[0].mount_point);
		}

		tt += "%s: %s".printf(_("ReadOnly"), (dev.read_only ? "Yes" : "No"));

		row.set_tooltip_markup(tt);

		// create widgets ------------------------------------

		var ebox = new Gtk.EventBox();
		row.add(ebox);

		var box = new Gtk.Box(Orientation.HORIZONTAL, 3);
		ebox.add(box);

		// icon
		var image = new Gtk.Image();
		box.add(image);

		var vbox = new Gtk.Box(Orientation.VERTICAL, 0);
		vbox.margin_right = 12;
		box.add(vbox);
		//var label_box = vbox;

		// name
		var label = new Gtk.Label("");
		label.xalign = 0.0f;
		label.yalign = 1.0f;
		label.ellipsize = Pango.EllipsizeMode.END;
		vbox.add(label);

		// -----------------------------------

		image.pixbuf = dev.get_icon();
		image.margin_left = 12;

		label.label = item.name;
		label.set_use_markup(true);
		label.sensitive = dev.is_mounted;

		//if (dev.is_mounted){
		//	row.set_tooltip_markup(_("Click to open in active pane"));
		//}
		//else{
		//	row.set_tooltip_markup(_("Click to mount device and open in active pane"));
		//}

		add_fs_bar(vbox, dev);

		sg_label.add_widget(vbox);

		if (popup && (dev.type != "disk") && (dev.size_bytes > 0)){

			// size
			var lbl2 = new Gtk.Label(dev.size_formatted);
			lbl2.xalign = 1.0f;
			lbl2.yalign = 1.0f;
			lbl2.valign = Gtk.Align.END;
			lbl2.margin_right = 6;
			lbl2.sensitive = dev.is_mounted;
			box.add(lbl2);
			sg_size.add_widget(lbl2);

			if (dev.is_mounted){
				// mount
				string mpath = ellipsize(dev.mount_path, 40);
				lbl2 = new Gtk.Label(mpath);
				lbl2.xalign = 0.0f;
				lbl2.yalign = 1.0f;
				lbl2.valign = Gtk.Align.END;
				box.add(lbl2);
				sg_mount.add_widget(lbl2);
			}
		}

		var lbl2 = new Gtk.Label("");
		lbl2.hexpand = true;
		box.add(lbl2);

		if (popup){
			add_device_actions_button(box, dev);
		}

		// connect signal for shift+F10
		row.popup_menu.connect(() => { return row_device_button_press_event(null, dev); });

		// connect signal for right-click menu
		row.button_press_event.connect((w,e) => { return row_device_button_press_event(e, dev); });

		// -----------------------------------

		apply_css_row(row, label);

		// label for right margin
		var lbl = new Gtk.Label("");
		lbl.margin_right = 12;
		box.add(lbl);
	}

	private void add_item_device_header(SidebarItem item, bool allow_edit = false){

		var row = new Gtk.ListBoxRow();
		row.activatable = false;
		row.selectable = false;
		listbox.add(row);

		row.set_data<SidebarItem>("item", item);

		var ebox = new Gtk.EventBox();
		row.add(ebox);

		var box = new Gtk.Box(Orientation.HORIZONTAL, 3);
		ebox.add(box);

		// icon
		var image = new Gtk.Image();
		box.add(image);

		var vbox = new Gtk.Box(Orientation.VERTICAL, 0);
		vbox.margin_right = 12;
		box.add(vbox);
		//var label_box = vbox;

		// name
		var label = new Gtk.Label("");
		label.xalign = 0.0f;
		//label.margin_right = 3;
		label.ellipsize = Pango.EllipsizeMode.END;
		vbox.add(label);

		if (item.node_key.length > 0){
			if (node_expanded[item.node_key]){
				image.pixbuf = IconManager.lookup("collapse-menu-symbolic", 16, false);
			}
			else{
				image.pixbuf = IconManager.lookup("expand-menu-symbolic", 16, false);
			}
		}

		// -----------------------------------

		var dev = item.device;

		row.margin_left = 0;
		row.activatable = true;

		label.label = "<i>%s</i>".printf(item.name);
		label.set_use_markup(true);

		label.margin_left = 0;
		label.margin_top = 6;
		label.margin_bottom = 6;

		if (popup){
			gtk_hide(image);
		}

		var lbl2 = new Gtk.Label("");
		lbl2.hexpand = true;
		box.add(lbl2);

		if (popup){
			add_device_actions_button(box, dev);
		}

		// connect signal for shift+F10
		row.popup_menu.connect(() => { return row_device_button_press_event(null, dev); });

		// connect signal for right-click menu
		row.button_press_event.connect((w,e) => { return row_device_button_press_event(e, dev); });


		// -----------------------------------

		apply_css_row(row, label);

		// label for right margin
		var lbl = new Gtk.Label("");
		lbl.margin_right = 12;
		box.add(lbl);
	}

	private void add_item_bookmark(SidebarItem item, bool allow_edit = false){

		var row = new Gtk.ListBoxRow();
		row.activatable = false;
		row.selectable = false;
		listbox.add(row);

		row.set_data<SidebarItem>("item", item);

		var ebox = new Gtk.EventBox();
		row.add(ebox);

		var box = new Gtk.Box(Orientation.HORIZONTAL, 3);
		ebox.add(box);

		// icon
		var image = new Gtk.Image();
		box.add(image);

		var vbox = new Gtk.Box(Orientation.VERTICAL, 0);
		vbox.margin_right = 12;
		box.add(vbox);
		var label_box = vbox;

		// name
		var label = new Gtk.Label("");
		label.xalign = 0.0f;
		//label.margin_right = 3;
		label.ellipsize = Pango.EllipsizeMode.END;
		vbox.add(label);

		if (item.node_key.length > 0){
			if (node_expanded[item.node_key]){
				image.pixbuf = IconManager.lookup("collapse-menu-symbolic", 16, false);
			}
			else{
				image.pixbuf = IconManager.lookup("expand-menu-symbolic", 16, false);
			}
		}

		// -----------------------------------

		row.activatable = true;

		var bm = item.bookmark;

		row.set_tooltip_text(item.tooltip);

		image.pixbuf = bm.get_icon();
		image.margin_left = 12;

		bool exists = bm.exists();
		if (!exists){
			label.sensitive = false;
			row.set_tooltip_text(_("Location not found") + ": %s".printf(bm.uri));
		}
		else{
			label.sensitive = true;
			row.set_tooltip_text("%s".printf(bm.uri));
		}

		label.label = item.name;
		label.set_use_markup(false);
		label.hexpand = true;

		if (allow_edit){

			var entry = new Gtk.Entry();
			entry.xalign = 0.0f;
			entry.hexpand = true;
			box.add(entry);
			entry.set_no_show_all(true);

			entry.activate.connect(()=>{
				if ((bm.name != entry.text) && (entry.text.length > 0)){
					bm.name = entry.text;
					label.label = entry.text;
					GtkBookmark.save_bookmarks();
				}

				gtk_hide(entry);
				gtk_show(label_box);
			});

			entry.focus_out_event.connect((event) => {
				entry.activate();
				return true;
			});

			if (popup || App.sidebar_action_button){
				add_bookmark_edit_button(box, bm, label_box, entry, row, ebox);
			}

			// connect signal for shift+F10
			row.popup_menu.connect(() => { return row_bookmark_button_press_event(null, bm, label_box, entry, row); });

			// connect signal for right-click menu
			row.button_press_event.connect((w,e) => { return row_bookmark_button_press_event(e, bm, label_box, entry, row); });

			//const Gtk.TargetEntry[] targets = {
			//	{"item", Gtk.TargetFlags.SAME_APP, 1}
			//};
			//Gtk.drag_source_set(row, Gdk.ModifierType.BUTTON1_MASK, targets, Gdk.DragAction.MOVE);
			//Gtk.drag_dest_set(row, Gtk.DestDefaults.ALL, targets, Gdk.DragAction.MOVE);

			row.drag_data_get.connect((context, data, info, time) => {
				log_debug("on_drag_data_get");
				string index = row.get_index().to_string();
				data.set_text(index, index.length);
			});

			row.drag_data_received.connect((context, x, y, data, info, time) => {
				log_debug("on_drag_data_received");
				int dst_index = row.get_index();
				int src_index = (int) data.get_text();
				var src_row = listbox.get_row_at_index(src_index);
				listbox.insert(src_row, dst_index);
				Gtk.drag_finish(context, true, false, time);
			});
		}

		// -----------------------------------

		apply_css_row(row, label);

		// label for right margin
		var lbl = new Gtk.Label("");
		lbl.margin_right = 12;
		box.add(lbl);
	}

	private void add_item_bookmark_action(SidebarItem item, bool allow_edit = false){

		var row = new Gtk.ListBoxRow();
		row.activatable = false;
		row.selectable = false;
		listbox.add(row);

		row.set_data<SidebarItem>("item", item);

		var ebox = new Gtk.EventBox();
		row.add(ebox);

		var box = new Gtk.Box(Orientation.HORIZONTAL, 3);
		ebox.add(box);

		// icon
		var image = new Gtk.Image();
		box.add(image);

		var vbox = new Gtk.Box(Orientation.VERTICAL, 0);
		vbox.margin_right = 12;
		box.add(vbox);
		//var label_box = vbox;

		// name
		var label = new Gtk.Label("");
		label.xalign = 0.0f;
		//label.margin_right = 3;
		label.ellipsize = Pango.EllipsizeMode.END;
		vbox.add(label);

		if (item.node_key.length > 0){
			if (node_expanded[item.node_key]){
				image.pixbuf = IconManager.lookup("collapse-menu-symbolic", 16, false);
			}
			else{
				image.pixbuf = IconManager.lookup("expand-menu-symbolic", 16, false);
			}
		}

		// -----------------------------------

		switch(item.type){
		case SidebarItemType.BOOKMARK_ACTION_ADD:

			row.activatable = true;
			row.set_tooltip_text(item.tooltip);
			//row.selected = false;

			image.pixbuf = IconManager.lookup("list-add-symbolic", 16, false);
			image.margin_left = 12;

			label.label = item.name;
			label.set_use_markup(false);
			label.hexpand = true;

			image.margin_top = 6;
			image.margin_bottom = 6;
			label.margin_top = 6;
			label.margin_bottom = 6;
			//label.yalign = 0.5f;
			break;

		case SidebarItemType.BOOKMARK_ACTION_REMOVE:

			row.activatable = true;
			row.set_tooltip_text(item.tooltip);
			//row.selected = false;

			image.pixbuf = IconManager.lookup("list-remove-symbolic", 16, false);

			label.label = item.name;
			label.set_use_markup(false);
			//label.hexpand = true;

			image.margin_top = 6;
			image.margin_bottom = 6;
			label.margin_top = 6;
			label.margin_bottom = 6;
			//label.yalign = 0.5f;
			break;
		}

		// -----------------------------------

		apply_css_row(row, label);

		// label for right margin
		var lbl = new Gtk.Label("");
		lbl.margin_right = 12;
		box.add(lbl);
	}


	private bool row_device_button_press_event(Gdk.EventButton? event, Device? dev){

		log_debug("Sidebar: row_device_button_press_event()");

		if (dev == null) { return false; }

		if ((event != null) && (event.button != 3)){
			return false;
		}

		menu_device = new DeviceContextMenu(dev, popover);
		return menu_device.show_menu(event);
	}

	private bool row_bookmark_button_press_event(Gdk.EventButton? event, GtkBookmark? bm, Gtk.Box label_box, Gtk.Entry entry, Gtk.ListBoxRow row){

		log_debug("Sidebar: row_bookmark_button_press_event()");

		if (bm == null) { return false; }

		if ((event != null) && (event.button != 3)){
			return false;
		}

		menu_bookmark = new BookmarkContextMenu(bm, entry, label_box, row, listbox);
		return menu_bookmark.show_menu(event);
	}

	private void add_bookmark_edit_button(Gtk.Box box, GtkBookmark bm, Gtk.Box label_box, Gtk.Entry entry, Gtk.ListBoxRow row, Gtk.EventBox ebox_row){

		var img = IconManager.lookup_image("edit-rename", 12, true);

		var ebox = new Gtk.EventBox();
		ebox.add(img);
		ebox.margin_left = popup ? 24 : 0;
		box.add(ebox);

		if (!popup){
			gtk_hide(ebox);
		}

		row.set_data<Gtk.EventBox>("ebox-bm-edit", ebox);

		ebox.set_tooltip_text(_("Rename"));

		set_pointer_cursor_for_eventbox(ebox);

		ebox.button_press_event.connect((event)=>{
			menu_bookmark = new BookmarkContextMenu(bm, entry, label_box, row, listbox);
			return menu_bookmark.show_menu(event);
		});

		if (!bm.exists()){
			ebox.sensitive = false;
		}
	}

	private void add_device_actions_button(Gtk.Box box, Device dev){

		var img = new Gtk.Image.from_pixbuf(IconManager.lookup("preferences-desktop", 12, false, true));

		var ebox = new Gtk.EventBox();
		ebox.add(img);
		box.add(ebox);

		ebox.set_tooltip_text(_("Actions"));

		set_pointer_cursor_for_eventbox(ebox);

		ebox.button_press_event.connect((event)=>{
			menu_device = new DeviceContextMenu(dev, popover);
			return menu_device.show_menu(event);
		});
	}

	/*private void add_disk_eject_button(Gtk.Box box, Device dev){

		var icon_size = popup ? 16 : 16;
		var img = new Gtk.Image.from_pixbuf(IconManager.lookup("media-eject", icon_size, true));

		var ebox = new Gtk.EventBox();
		ebox.add(img);
		box.add(ebox);

		ebox.set_tooltip_text(_("Eject Device"));

		set_pointer_cursor_for_eventbox(ebox);

		ebox.button_press_event.connect((event)=>{
			DeviceContextMenu.eject_disk(dev, pane, window);
			return true;
		});
	}*/

	private void add_fs_bar(Gtk.Box box, Device dev){

		var hbox = new Gtk.Box(Orientation.HORIZONTAL, 0);
		box.add(hbox);

		var fs_bar = new Gtk.DrawingArea();
		fs_bar.set_size_request(100, 4);
		//fs_bar.hexpand = true;
		hbox.add(fs_bar);

		if (!dev.is_mounted || (dev.size_bytes == 0)){
			return;
		}

		//var dummy = new Gtk.DrawingArea();
		//dummy.hexpand = true;
		//hbox.add(dummy);

		var color_white = Gdk.RGBA();
		color_white.parse("white");
		color_white.alpha = 1.0;

		var color_black = Gdk.RGBA();
		color_black.parse("#606060");
		color_black.alpha = 1.0;

		var color_red = Gdk.RGBA();
		color_red.parse("red");
		color_red.alpha = 1.0;

		var color_blue_200 = Gdk.RGBA();
		color_blue_200.parse("#90CAF9");
		color_blue_200.alpha = 1.0;

		var color_green_300 = Gdk.RGBA();
		color_green_300.parse("#81C784");
		color_green_300.alpha = 1.0;

		var color_yellow_300 = Gdk.RGBA();
		color_yellow_300.parse("#FFA500");
		color_yellow_300.alpha = 1.0;

		var color_red_300 = Gdk.RGBA();
		color_red_300.parse("#E57373");
		color_red_300.alpha = 1.0;

		Gdk.RGBA color_bar = color_green_300;

		int line_width = 1;

		fs_bar.draw.connect ((context) => {
			int w = fs_bar.get_allocated_width();
			int h = fs_bar.get_allocated_height();

			double percent = (dev.used_bytes * 100.0) / dev.size_bytes;
			int x_level = (int) ((w * percent) / 100.00);

			string tt = "%8s: %10s".printf(_("Size"), format_file_size(dev.size_bytes));

			tt += "\n%8s: %10s (%.0f%%)".printf(_("Used"),
				format_file_size(dev.used_bytes),
				(dev.used_bytes * 100.0) / dev.size_bytes
				);

			tt += "\n%8s: %10s (%.0f%%)".printf(_("Free"),
				format_file_size(dev.free_bytes),
				(dev.free_bytes * 100.0) / dev.size_bytes
				);

			fs_bar.set_tooltip_markup("<tt>%s</tt>".printf(tt));

			if (percent >= 75){
				color_bar = color_red_300;
			}
			else if (percent >= 50){
				color_bar = color_yellow_300;
			}
			else{
				color_bar = color_green_300;
			}

			// origin is top_left

			//context.set_line_width (1); // 1
			//context.move_to (x_level + line_width + 2, 0);
			//context.line_to (x_level + line_width + 2, h);
			//context.stroke();

			Gdk.cairo_set_source_rgba (context, color_bar);
			context.set_line_width (line_width);

			context.rectangle(line_width, line_width, x_level, h - (line_width * 2));
			context.fill();

			Gdk.cairo_set_source_rgba (context, color_white);
			context.set_line_width (line_width);

			context.rectangle(x_level + line_width, line_width, w - x_level - (line_width * 2), h - (line_width * 2));
			context.fill();

			Gdk.cairo_set_source_rgba (context, color_black);
			context.set_line_width(line_width);

			context.rectangle(0, 0, w, h);
			context.stroke();

			return true;
		});
	}

	//private void on_drag_data_get (Gdk.DragContext context, Gtk.SelectionData data, uint info, uint time) {

		//log_debug("on_drag_data_get");



		/*var list = get_selected_items();

		var uris = new Gee.ArrayList<string>();
		foreach(var item in list){
			uris.add("file://" + item.file_path);
			log_debug("dnd get: %s".printf("file://" + item.file_path));
		}
		data.set_uris((string[])uris.to_array());*/

		//log_debug("on_drag_data_get: exit");
	//}

	//private void on_drag_data_received (Gdk.DragContext drag_context, int x, int y, Gtk.SelectionData data, uint info, uint time) {

		//log_debug("on_drag_data_received");


		//if ((data != null) && (data.get_length() >= 0)) {
		//	log_debug("dnd: selection_length=%d".printf(data.get_length()));
		//	var text = (string) data.get_data();
		//	log_debug(text);
		//}

		/*// get selected_items
		var selected_items = new Gee.ArrayList<FileItem>();
		foreach (string uri in data.get_uris()){
			string item_path = uri.replace("file://","").replace("file:/","");
			item_path = Uri.unescape_string (item_path);
			selected_items.add(new FileItem.from_path(item_path));
		}

		if (selected_items.size == 0){ return; }

		log_debug("action.dropped()");

		// save
		var action = new ProgressPanel(pane, selected_items, FileActionType.COPY);
		action.set_source(new FileItem.from_path(selected_items[0].file_location));
		window.pending_action = action;
		*/

		//Gtk.drag_finish (drag_context, true, false, time);

		//paste();
    //}
/*
	private void set_as_drag_source(bool set_dnd, Gtk.ListBoxRow row){
		if (set_dnd){
			Gtk.drag_source_set(row, Gdk.ModifierType.BUTTON1_MASK, MainWindow.drop_target_types, Gdk.DragAction.COPY);


		}
		else{
			Gtk.drag_source_unset(row);
		}
	}

	private void set_as_drag_destination(bool set_dnd, Gtk.ListBoxRow row){
		if (set_dnd){
			Gtk.drag_dest_set(row, Gtk.DestDefaults.ALL, MainWindow.drop_target_types, Gdk.DragAction.COPY);
		}
		else{
			Gtk.drag_dest_unset(row);
		}
	}

*/
}




