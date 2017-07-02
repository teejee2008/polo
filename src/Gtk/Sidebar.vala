/*
 * Sidebar.vala
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

public class Sidebar : Gtk.Box {

	private Gtk.ListBox listbox;
	private Gtk.ScrolledWindow scrolled;
	private Gtk.ListBoxRow current_row;

	private Gee.HashMap<string, bool> node_expanded = new Gee.HashMap<string, bool>();
	private Gtk.SizeGroup sg_label;
	private Gtk.SizeGroup sg_size;
	private Gtk.SizeGroup sg_mount;

	private DeviceContextMenu menu_device;

	public signal void toggled();
	public signal void row_activated(TreeView treeview, TreeIter iter, SidebarItem item);

	public Gee.ArrayList<string> collapsed_sections = new Gee.ArrayList<string>();
	
	// parents

	private FileViewList view{
		get{
			return pane.view;
		}
	}

	FileViewPane _pane;
	private FileViewPane pane {
		get{
			if (_pane != null){
				return _pane;
			}
			else{
				return App.main_window.active_pane;
			}
		}
	}

	private LayoutPanel panel {
		get{
			return pane.panel;
		}
	}

	private MainWindow window{
		get{
			return App.main_window;
		}
	}

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

		listbox.leave_notify_event.connect((event) => {
			hide_icons_current_row();
			return true;
		});

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
			pane.view.set_view_path(item.bookmark.path);

			if (popup){
				popover.hide();
				//window.sidebar.refresh(); // not needed
			}
			else{
				//refresh(); // not needed
			}

			break;

		case SidebarItemType.BOOKMARK_ACTION_ADD:

			if (pane.view.current_item != null){

				var path = pane.view.current_item.file_path;

				if (!GtkBookmark.is_bookmarked(path) && (path != "/") && (path != App.user_home)){
					GtkBookmark.add_bookmark_from_path(path);
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

				if (GtkBookmark.is_bookmarked(path) && (path != "/") && (path != App.user_home)){
					GtkBookmark.remove_bookmark_by_path(path);
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

			gtk_set_busy(true, window);
			
			log_debug("sidebar: device_activated: %s".printf(item.device.device));

			Device dev = item.device;

			if (!dev.is_mounted){

				if (dev.is_encrypted_partition){

					log_debug("prompting user to unlock encrypted partition");

					if (!dev.unlock("", "", window, false)){

						log_debug("device is null or still in locked state!");
						if (popup){
							popover.hide();
						}

						gtk_set_busy(false, window);
						return; // no message needed
					}
					else{
						dev = dev.children[0];
					}
				}

				dev.automount(window);
			}

			if (dev.is_mounted){
				var mp = dev.mount_points[0];
				pane.view.set_view_path(mp.mount_point);
			}

			if (popup){
				popover.hide();
			}

			gtk_set_busy(false, window);

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

		if (listbox == null){
			return;
		}

		if (!popup && !App.sidebar_visible){
			return;
		}

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

		log_debug("sidebar: refresh(%s): %s".printf((popup ? "popup" : ""), view.paneid));

		SidebarItem item = null;

		if (popup && (popup_mode == "bm")){
			add_bookmark_action();
		}

		if (!popup || (popup_mode == "bm")){

			if (popup || App.sidebar_places){

				item = add_header_locations(_("Places"));

				log_debug("sidebar: add_places()");
				
				if (node_expanded[item.node_key]){
					add_bookmark(new GtkBookmark("file:///", _("Filesystem")));
					add_bookmark(new GtkBookmark("file://" + App.user_dirs.user_home, _("Home")));
					add_bookmark(new GtkBookmark("file://" + App.user_dirs.user_documents, _("Documents")));
					add_bookmark(new GtkBookmark("file://" + App.user_dirs.user_downloads, _("Downloads")));
					add_bookmark(new GtkBookmark("file://" + App.user_dirs.user_pictures, _("Pictures")));
					add_bookmark(new GtkBookmark("file://" + App.user_dirs.user_music, _("Music")));
					add_bookmark(new GtkBookmark("file://" + App.user_dirs.user_videos, _("Videos")));
					add_bookmark(new GtkBookmark("file://" + App.user_dirs.user_desktop, _("Desktop")));
					add_bookmark(new GtkBookmark("file://" + App.user_dirs.user_public, _("Public")));
					add_bookmark(new GtkBookmark("trash:///", _("Trash") + " (%s)".printf(format_file_size(App.trashcan.trash_can_size))));
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
						
						if (dev.pkname.length == 0){
							
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
	}

	private void add_item(SidebarItem item, bool allow_edit = false){

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

		switch(item.type){

		case SidebarItemType.HEADER_LOCATIONS:
		case SidebarItemType.HEADER_BOOKMARKS:
		case SidebarItemType.HEADER_DEVICES:

			row.margin_left = 0;
			row.activatable = true;

			label.label = "<b>%s</b>".printf(item.name);
			label.set_use_markup(true);
			label.margin_top = 6;
			break;

		case SidebarItemType.HEADER_DISK:

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

			break;

		case SidebarItemType.BOOKMARK:

			row.activatable = true;

			var bm = item.bookmark;

			row.set_tooltip_text(item.tooltip);

			image.pixbuf = bm.get_icon();
			image.margin_left = 12;

			bool exists = bm.path_exists();
			if (!exists){
				label.sensitive = false;
				row.set_tooltip_text(_("Location not found") + ": %s".printf(bm.path));
			}
			else{
				row.set_tooltip_text("%s".printf(bm.path));
			}

			label.label = item.name;
			label.set_use_markup(false);
			label.hexpand = true;

			if (allow_edit){

				var entry = new Gtk.Entry();
				entry.xalign = (float) 0.0;
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

				if (exists){
					add_bookmark_edit_button(box, bm, label_box, entry, row, ebox);
				}

				// allow non-existing to be removed
				add_bookmark_remove_button(box, bm, row, ebox);

				const Gtk.TargetEntry[] targets = {
					{"item", Gtk.TargetFlags.SAME_APP, 1}
				};
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

			break;

		case SidebarItemType.BOOKMARK_ACTION_ADD:

			row.activatable = true;
			row.set_tooltip_text(item.tooltip);
			//row.selected = false;

			image.pixbuf = IconManager.lookup("list-add", 16, false);
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

			image.pixbuf = IconManager.lookup("list-remove", 16, false);

			label.label = item.name;
			label.set_use_markup(false);
			//label.hexpand = true;

			image.margin_top = 6;
			image.margin_bottom = 6;
			label.margin_top = 6;
			label.margin_bottom = 6;
			//label.yalign = 0.5f;
			break;

		case SidebarItemType.DEVICE:

			row.activatable = true;

			var dev = item.device;
			//row.selectable = true;

			image.pixbuf = dev.get_icon();
			image.margin_left = 12;

			label.label = item.name;
			label.set_use_markup(true);
			label.sensitive = dev.is_mounted;

			if (dev.is_mounted){
				row.set_tooltip_markup(_("Click to open in active pane"));
			}
			else{
				row.set_tooltip_markup(_("Click to mount device and open in active pane"));
			}

			if (dev.is_mounted && (dev.size_bytes > 0)){
				add_fs_bar(vbox, dev);
			}

			sg_label.add_widget(vbox);

			if (popup && (dev.type != "disk") && (dev.size_bytes > 0)){

				// size
				var lbl2 = new Gtk.Label(dev.size_formatted);
				lbl2.xalign = 1.0f;
				//lbl2.yalign = 1.0f;
				lbl2.valign = Gtk.Align.END;
				//lbl2.margin_bottom = 0;
				lbl2.margin_right = 6;
				lbl2.sensitive = dev.is_mounted;
				box.add(lbl2);
				sg_size.add_widget(lbl2);

				if (dev.is_mounted){
					// mount
					lbl2 = new Gtk.Label(dev.mount_path);
					lbl2.xalign = 0.0f;
					//lbl2.yalign = 1.0f;
					lbl2.valign = Gtk.Align.END;
					//lbl2.margin_bottom = 0;
					box.add(lbl2);
					sg_mount.add_widget(lbl2);
				}
			}

			var lbl2 = new Gtk.Label("");
			lbl2.hexpand = true;
			box.add(lbl2);

			if (dev.is_on_encrypted_partition && !dev.is_system_device && (popup || App.sidebar_lock)){
				add_lock_button(box, dev);
			}

			if (dev.is_mounted && !dev.is_system_device && (popup || App.sidebar_unmount)){
				add_unmount_button(box, dev);
			}

			/*
			// connect signal for shift+F10
			row.popup_menu.connect(() => {
				if (dev == null) { return false; }
				menu_device = new DeviceContextMenu(dev);
				return menu_device.show_menu(null);
			});

			// connect signal for right-click
			row.button_press_event.connect((w, event) => {
				if (dev == null) { return false; }
				if (event.button == 3) {
					menu_device = new DeviceContextMenu(dev);
					return menu_device.show_menu(event);
				}
				return false;
			});*/

			break;
		}

		apply_css_row(row, label);

		// label for right margin
		var lbl = new Gtk.Label("");
		lbl.margin_right = 12;
		box.add(lbl);
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

		// set hand cursor
		if (ebox.get_realized()){
			ebox.get_window().set_cursor(new Gdk.Cursor(Gdk.CursorType.HAND1));
		}
		else{
			ebox.realize.connect(()=>{
				ebox.get_window().set_cursor(new Gdk.Cursor(Gdk.CursorType.HAND1));
			});
		}

		ebox.button_press_event.connect((event)=>{
			entry.text = bm.name;
			entry.select_region(0, entry.text.length);
			gtk_hide(label_box);
			gtk_show(entry);
			return true;
		});


		if (!bm.path_exists()){
			ebox.sensitive = false;
		}

		if (!popup){
			ebox_row.enter_notify_event.connect((event) => {
				log_debug("row: edit: enter_notify_event");
				hide_icons_current_row();
				show_icons_for_row(row);
				return true;
			});
		}
	}


	private void show_icons_for_row(Gtk.ListBoxRow row){
		current_row = row;

		var ebox = (Gtk.EventBox) row.get_data<Gtk.EventBox>("ebox-bm-edit");
		gtk_show(ebox);

		ebox = (Gtk.EventBox) row.get_data<Gtk.EventBox>("ebox-bm-remove");
		gtk_show(ebox);
	}

	private void hide_icons_current_row(){
		if (current_row != null){
			var ebox_prev = (Gtk.EventBox) current_row.get_data<Gtk.EventBox>("ebox-bm-edit");
			gtk_hide(ebox_prev);
			ebox_prev = (Gtk.EventBox) current_row.get_data<Gtk.EventBox>("ebox-bm-remove");
			gtk_hide(ebox_prev);
			current_row = null;
		}
	}

	private void add_bookmark_remove_button(Gtk.Box box, GtkBookmark bm, Gtk.ListBoxRow row, Gtk.EventBox ebox_row){

		var img = new Gtk.Image.from_pixbuf(IconManager.lookup("window-close", 16, true));

		var ebox = new Gtk.EventBox();
		ebox.add(img);
		ebox.margin_right = popup ? 0 : 12;
		box.add(ebox);

		if (!popup){
			gtk_hide(ebox);
		}

		ebox.set_tooltip_text(_("Remove"));

		row.set_data<Gtk.EventBox>("ebox-bm-remove", ebox);

		// set hand cursor
		if (ebox.get_realized()){
			ebox.get_window().set_cursor(new Gdk.Cursor(Gdk.CursorType.HAND1));
		}
		else{
			ebox.realize.connect(()=>{
				ebox.get_window().set_cursor(new Gdk.Cursor(Gdk.CursorType.HAND1));
			});
		}

		ebox.button_press_event.connect((event)=>{
			listbox.remove(row);
			GtkBookmark.remove_bookmark_by_path(bm.path);
			return true;
		});
	}

	private void add_unmount_button(Gtk.Box box, Device dev){
		var icon_size = popup ? 16 : 16;
		var img = new Gtk.Image.from_pixbuf(IconManager.lookup("media-eject", icon_size, true));

		var ebox = new Gtk.EventBox();
		ebox.add(img);
		box.add(ebox);

		ebox.set_tooltip_text(_("Unmount device"));

		// set hand cursor
		if (ebox.get_realized()){
			ebox.get_window().set_cursor(new Gdk.Cursor(Gdk.CursorType.HAND1));
		}
		else{
			ebox.realize.connect(()=>{
				ebox.get_window().set_cursor(new Gdk.Cursor(Gdk.CursorType.HAND1));
			});
		}

		ebox.button_press_event.connect((event)=>{

			if (event.button != 1) { return false; }
			
			gtk_set_busy(true, window);

			log_debug("unmount_button_clicked ------------------------------");

			if (dev.is_mounted){
				if (dev.unmount(window)){
					string title =  _("Device Unmounted");
					OSDNotify.notify_send(title, "", 1000, "low", "info");
				}
			}

			gtk_set_busy(false, window);

			if (popup){
				popover.hide();
			}
			return true;
		});
	}

	private void add_lock_button(Gtk.Box box, Device dev){
		var icon_size = popup ? 16 : 16;
		var img = IconManager.lookup_image("lock", icon_size, true, true);

		var ebox = new Gtk.EventBox();
		ebox.add(img);
		box.add(ebox);

		ebox.set_tooltip_text(_("Unmount and lock device"));

		// set hand cursor
		if (ebox.get_realized()){
			ebox.get_window().set_cursor(new Gdk.Cursor(Gdk.CursorType.HAND1));
		}
		else{
			ebox.realize.connect(()=>{
				ebox.get_window().set_cursor(new Gdk.Cursor(Gdk.CursorType.HAND1));
			});
		}

		ebox.button_press_event.connect((event)=>{

			if (event.button != 1) { return false; }
			
			gtk_set_busy(true, window);

			log_debug("lock_button_clicked ------------------------------");

			bool ok = true;
			string mpath = "";

			// unmount if mounted, and save the mount path
			if (dev.is_mounted){
				mpath = dev.mount_points[0].mount_point;
				if (!dev.unmount(window)){
					log_debug("device is still mounted!");
					mpath = "";
				}
				else{
					log_debug("device was unmounted");
				}
			}
			else{
				log_debug("device is not mounted");
			}

			// lock the device's parent if device is unmounted and encrypted
			if (dev.is_on_encrypted_partition){
				log_debug("locking device...");
				ok = dev.parent.lock_device(window);

				if (ok){
					string title =  _("Device Locked");
					OSDNotify.notify_send(title, "", 1000, "low", "info");
				}
			}
			else{
				log_debug("device is not an encrypted partition");
			}

			// reset views that were displaying the mounted path
			if (mpath.length > 0){
				log_debug("resetting views for the mount path");
				//window.reset_views_with_path_prefix(mpath);
			}

			gtk_set_busy(false, window);

			if (popup){
				popover.hide();
			}

			return true;
		});
	}

	private void add_fs_bar(Gtk.Box box, Device dev){

		var hbox = new Gtk.Box(Orientation.HORIZONTAL, 0);
		box.add(hbox);

		var fs_bar = new Gtk.DrawingArea();
		fs_bar.set_size_request(100, 4);
		//fs_bar.hexpand = true;
		hbox.add(fs_bar);

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

	private void on_drag_data_get (Gdk.DragContext context, Gtk.SelectionData data, uint info, uint time) {

		log_debug("on_drag_data_get");



		/*var list = get_selected_items();

		var uris = new Gee.ArrayList<string>();
		foreach(var item in list){
			uris.add("file://" + item.file_path);
			log_debug("dnd get: %s".printf("file://" + item.file_path));
		}
		data.set_uris((string[])uris.to_array());*/

		log_debug("on_drag_data_get: exit");
	}

	private void on_drag_data_received (Gdk.DragContext drag_context, int x, int y, Gtk.SelectionData data, uint info, uint time) {

		log_debug("on_drag_data_received");


		if ((data != null) && (data.get_length() >= 0)) {
			log_debug("dnd: selection_length=%d".printf(data.get_length()));
			var text = (string) data.get_data();
			log_debug(text);
		}

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

		Gtk.drag_finish (drag_context, true, false, time);

		//paste();
    }
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




