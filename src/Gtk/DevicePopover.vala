/*
 * DevicePopover.vala
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

public class DevicePopover : Gtk.Popover {

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

	private Gtk.TreeView treeview;

	private Gtk.Box vbox_main;
	private Gtk.Box bbox_manage;
	private Gtk.Box bbox_actions;

	private Gtk.TreeViewColumn col_name;
	private Gtk.CellRendererText cell_name;

	private Gtk.TreeViewColumn col_size;
	private Gtk.TreeViewColumn col_fs;
	private Gtk.TreeViewColumn col_mp;

	private Gtk.Button btn_mount;
	private Gtk.Button btn_unmount;
	private Gtk.Button btn_lock;
	private Gtk.Button btn_unlock;
	private Gtk.Button btn_eject;
	private Gtk.Button btn_format;
	private Gtk.Button btn_backup;
	private Gtk.Button btn_restore;
	private Gtk.Button btn_manage;
	private Gtk.Button btn_properties;

	private bool manage_mode = false;

	public DevicePopover(Gtk.Widget? _relative_to, FileViewPane? parent_pane){
		
		this.relative_to = _relative_to;

		this._pane = parent_pane;

		init_ui();

		this.closed.connect(on_closed);
	}
	
	private void init_ui(){

		log_debug("DevicePopover(): init_ui()");
		
		//vbox_main
		vbox_main = new Gtk.Box(Orientation.VERTICAL, 0);
		vbox_main.margin = 0;
		vbox_main.set_size_request(App.dm_width, App.dm_height);
		add(vbox_main);

		init_devices();

		init_actions();

		DeviceMonitor.get_monitor().changed.connect(()=>{
			this.refresh();
		});

		on_settings_changed();
	}

	private void on_closed(){

		gtk_hide(bbox_actions);
		gtk_show(bbox_manage);
	}

	private void init_devices() {

		log_debug("DevicePopover(): init_bookmarks()");
		
		// treeview
		treeview = new Gtk.TreeView();
		treeview.get_selection().mode = Gtk.SelectionMode.SINGLE;
		treeview.headers_visible = true;
		treeview.headers_clickable = false;
		treeview.rubber_banding = false;
		treeview.enable_search = false;
		treeview.set_rules_hint(false);
		treeview.activate_on_single_click = true;
		treeview.expand = true;

		// scrolled
		var scrolled = new Gtk.ScrolledWindow(null, null);
		scrolled.set_shadow_type (ShadowType.ETCHED_IN);
		scrolled.hscrollbar_policy = PolicyType.AUTOMATIC;
		scrolled.vscrollbar_policy = PolicyType.AUTOMATIC;
		//scrolled.hexpand = true;
		//scrolled.vexpand = true;

		scrolled.add(treeview);
		
		vbox_main.add(scrolled);

		// name ---------------------------------------------
		
		var col = new TreeViewColumn();
		col.title = _("Device");
		col.clickable = false;
		col.resizable = false;
		//col.expand = true;
		treeview.append_column(col);
		col_name = col;
		
		// icon --------------------------------------
		
		var cell_pix = new Gtk.CellRendererPixbuf();
		cell_pix.xpad = 3;
		//cell_pix.ypad = 3;
		col.pack_start(cell_pix, false);

		// render
		col.set_cell_data_func (cell_pix, (cell_layout, cell, model, iter) => {

			var pixcell = cell as Gtk.CellRendererPixbuf;

			Device dev;
			model.get (iter, 0, out dev, -1);

			//if (dev.pkname.length == 0){
				//pixcell.pixbuf = null;
			//}
			//else{
				pixcell.pixbuf = dev.get_icon(22);
			//}
		});

		// text ---------------------------------------
		
		var cell_text = new CellRendererText ();
		col.pack_start (cell_text, false);
		cell_name = cell_text;
		
		// render
		col.set_cell_data_func (cell_text, (cell_layout, cell, model, iter) => {
			
			var crt = cell as Gtk.CellRendererText;

			Device dev;
			model.get (iter, 0, out dev, -1);

			string name = "";
			
			if (dev.pkname.length == 0){
			
				name = dev.description_simple(false, true);
			}
			else{
				name = dev.kname;

				if (dev.is_on_encrypted_partition){
					//name = "%s%s".printf(dev.pkname, _(" (unlocked)"));

					if (manage_mode){
						name = "%s → %s".printf(dev.pkname, dev.kname);
					}
					else{
						name = "%s".printf(dev.pkname);
					}
				}
				else if (dev.is_encrypted_partition){
					name = "%s%s".printf(dev.kname, _(" (locked)"));
					//name = "%s".printf(dev.kname);
				}

				if (dev.label.length > 0){
					name += " (%s)".printf(dev.label);
				}
				else if (dev.partlabel.length > 0){
					name += " (%s)".printf(dev.partlabel);
				}
				else if (dev.has_parent() && (dev.parent.partlabel.length > 0)){
					name += " (%s)".printf(dev.parent.partlabel);
				}
			}
		
			crt.text = name;
		});

		// size ---------------------------------------------
		
		col = new TreeViewColumn();
		col.title = _("Size");
		col.clickable = false;
		col.resizable = false;
		treeview.append_column(col);
		col_size = col;
		
		// text
		cell_text = new CellRendererText();
		//cell_text.width = 50;
		cell_text.xalign = 1.0f;
		col.pack_start (cell_text, false);

		// render
		col.set_cell_data_func (cell_text, (cell_layout, cell, model, iter) => {
			
			var crt = cell as Gtk.CellRendererText;

			Device dev;
			model.get (iter, 0, out dev, -1);

			crt.text = format_file_size(dev.size_bytes, false, "", true, 0) + " ";
		});

		// prg
		var cell_prg = new CellRendererProgress2();
		cell_prg.height = 15;
		cell_prg.width = 50;
		col.pack_start(cell_prg, false);

		// render
		col.set_cell_data_func (cell_prg, (cell_layout, cell, model, iter) => {
			
			var crt = cell as CellRendererProgress2;

			Device dev;
			model.get (iter, 0, out dev, -1);

			//crt.text = dev.size_formatted;

			if (dev.size_bytes > 0){
				crt.value = (int)(((dev.used_bytes * 1.0) / dev.size_bytes) * 100.0);
			}
			else{
				crt.value = 0;
			}

			crt.text = "";
		});
		
		// text --------------------------------------
		
		/*cell_text = new CellRendererText();
		cell_text.xalign = 1.0f;
		col.pack_start (cell_text, false);
		cell_name = cell_text;
		
		// render
		col.set_cell_data_func (cell_text, (cell_layout, cell, model, iter) => {
			
			var crt = cell as Gtk.CellRendererText;

			Device dev;
			model.get (iter, 0, out dev, -1);

			crt.text = dev.size_formatted;
		});*/

		// fs ---------------------------------------------
		
		col = new TreeViewColumn();
		col.title = _("FS");
		col.clickable = false;
		col.resizable = false;
		treeview.append_column(col);
		col_fs = col;
		
		// icon --------------------------------------
		
		cell_pix = new Gtk.CellRendererPixbuf();
		cell_pix.xpad = 3;
		//cell_pix.ypad = 3;
		col.pack_start(cell_pix, false);

		col.set_attributes(cell_pix, "pixbuf", 2);
		
		// text --------------------------------
		
		cell_text = new CellRendererText();
		cell_text.xalign = 0.0f;
		col.pack_start (cell_text, false);
		cell_name = cell_text;
		
		// render
		col.set_cell_data_func (cell_text, (cell_layout, cell, model, iter) => {
			
			var crt = cell as Gtk.CellRendererText;

			Device dev;
			model.get (iter, 0, out dev, -1);

			crt.text = dev.fstype;
		});

		// mount ---------------------------------------------
		
		col = new TreeViewColumn();
		col.title = _("Mount Path");
		col.clickable = false;
		col.resizable = false;
		treeview.append_column(col);
		col_mp = col;
		
		// text --------------------------------
		
		cell_text = new CellRendererText();
		cell_text.xalign = 0.0f;
		col.pack_start (cell_text, false);
		cell_name = cell_text;
		
		// render
		col.set_cell_data_func (cell_text, (cell_layout, cell, model, iter) => {
			
			var crt = cell as Gtk.CellRendererText;

			Device dev;
			model.get (iter, 0, out dev, -1);

			crt.text = dev.mount_path;
		});

		//  --------------------------------------------------

		// tooltip
		treeview.has_tooltip = false;
		// tooltips are not displayed properly inside Gtk.Popover (GTK Issue)
		//treeview.set_tooltip_column(1);
		//treeview.query_tooltip.connect(treeview_query_tooltip);

		// cursor
		var cursor = new Gdk.Cursor.from_name(Gdk.Display.get_default(), "pointer");
		scrolled.get_window().set_cursor(cursor);

		treeview.row_activated.connect(treeview_row_activated); 

		/*
		// connect signal for shift+F10
		treeview.popup_menu.connect(() => {
			return show_context_menu();
		});

		// connect signal for right-click menu
		treeview.button_press_event.connect((w,e) => {
			if (e.button == 3) {
				return show_context_menu();
			}
			return false;
		});
		*/
	}

	/*private bool show_context_menu(){
		
		var selected = get_selected();
		
		if (selected.size != 1){ return false; }
		
		context_menu = new DeviceContextMenu(selected[0], this);
		
		return context_menu.show_menu(null);
	}*/

	public Gee.ArrayList<Device> get_selected(){
		
		var list = new Gee.ArrayList<Device>();

		TreeIter iter;
		var store = (Gtk.TreeStore) treeview.model;
		var sel = treeview.get_selection();
		bool iterExists = store.get_iter_first (out iter);
		while (iterExists) {
			if (sel.iter_is_selected (iter)){
				Device item;
				store.get (iter, 0, out item);
				list.add(item);
			}
			iterExists = store.iter_next (ref iter);
		}

		return list;
	}


	private void treeview_row_activated(TreePath path, TreeViewColumn? column){

		log_debug("DevicePopover(): treeview_row_activated()");

		if (!manage_mode){

			btn_open_clicked();

			this.hide();
		}
		else{
			refresh_actions();
		}
	}

	// actions ----------------------------------
	
	private void init_actions(){

		log_debug("DevicePopover(): init_actions()");
		
		var hbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
		vbox_main.add(hbox);

		hbox.margin_top = 6;
		hbox.margin_left = 6;
		hbox.margin_right = 6;
		hbox.margin_bottom = 6;

		hbox.hexpand = true;

		// spacer -----------------------------------
		
		var dummy = new Gtk.Label("");
		dummy.hexpand = true;
		hbox.add(dummy);
		
		// actions ---------------------------------------

		var box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
		hbox.add(box);

		bbox_actions = box;
		
		var bbox = new Gtk.ButtonBox(Gtk.Orientation.VERTICAL);
		bbox.set_layout(Gtk.ButtonBoxStyle.CENTER);
		bbox.spacing = 3;
		box.add(bbox);

		// open -----------------------

		//var button = new Gtk.Button.with_label(_("Open"));
		//bbox.add(button);

		//button.clicked.connect(btn_open_clicked);

		// mount -----------------------

		var button = new Gtk.Button.with_label(_("Mount"));
		button.set_image(IconManager.lookup_image("drive-harddisk", 16, false, false));
		button.always_show_image = true;
		bbox.add(button);
		btn_mount = button;
		
		button.clicked.connect(btn_mount_clicked);

		// unmount -----------------------

		button = new Gtk.Button.with_label(_("Unmount"));
		button.set_image(IconManager.lookup_image("drive-harddisk", 16, false, false));
		button.always_show_image = true;
		bbox.add(button);
		btn_unmount = button;
		
		button.clicked.connect(btn_unmount_clicked);


		bbox = new Gtk.ButtonBox(Gtk.Orientation.VERTICAL);
		bbox.set_layout(Gtk.ButtonBoxStyle.CENTER);
		bbox.spacing = 3;
		box.add(bbox);

		// lock -----------------------

		button = new Gtk.Button.with_label(_("Lock"));
		button.set_image(IconManager.lookup_image("locked", 16, false, false));
		button.always_show_image = true;
		bbox.add(button);
		btn_lock = button;
		
		button.clicked.connect(btn_lock_clicked);

		// unlock -----------------------

		button = new Gtk.Button.with_label(_("Unlock"));
		button.set_image(IconManager.lookup_image("unlocked", 16, false, false));
		button.always_show_image = true;
		bbox.add(button);
		btn_unlock = button;
		
		button.clicked.connect(btn_unlock_clicked);


		bbox = new Gtk.ButtonBox(Gtk.Orientation.VERTICAL);
		bbox.set_layout(Gtk.ButtonBoxStyle.CENTER);
		bbox.spacing = 3;
		box.add(bbox);
		
		// lock -----------------------

		button = new Gtk.Button.with_label(_("Backup"));
		bbox.add(button);
		btn_backup = button;
		
		button.clicked.connect(btn_backup_clicked);

		// unlock -----------------------

		button = new Gtk.Button.with_label(_("Restore"));
		bbox.add(button);
		btn_restore = button;
		
		button.clicked.connect(btn_restore_clicked);

		bbox = new Gtk.ButtonBox(Gtk.Orientation.VERTICAL);
		bbox.set_layout(Gtk.ButtonBoxStyle.CENTER);
		bbox.spacing = 3;
		box.add(bbox);

		// format -----------------------

		var menu_format = new DiskFormatContextMenu();
		menu_format.device_formatting_complete.connect(()=>{
			Device.get_block_devices();
			refresh();
		});
		
		button = new Gtk.Button.with_label(" " + _("Reformat") + " ↓");
		//button.set_image(null);
		button.always_show_image = true;
		//button.set_tooltip_text(_("Reformat"));
		bbox.add(button);
		btn_format = button;
		
		button.clicked.connect(()=>{
			var dev = get_selected_device();
			if (dev != null){
				menu_format.show_menu(dev, null);
			}
		});
		
		// manage -----------------------

		button = new Gtk.Button.with_label(_("Partition"));
		button.set_image(IconManager.lookup_image("partitionmanager", 16, false, false));
		button.always_show_image = true;
		//button.set_tooltip_text(_("Partition Manager"));
		bbox.add(button);
		btn_manage = button;
		
		button.clicked.connect(btn_manage_clicked);

		bbox = new Gtk.ButtonBox(Gtk.Orientation.VERTICAL);
		bbox.set_layout(Gtk.ButtonBoxStyle.CENTER);
		bbox.spacing = 3;
		box.add(bbox);

		// eject -----------------------

		button = new Gtk.Button.with_label(_("Eject"));
		button.set_image(IconManager.lookup_image("media-eject", 16, false, false));
		button.always_show_image = true;
		//button.set_tooltip_text(_("Eject"));
		bbox.add(button);
		btn_eject = button;
		
		button.clicked.connect(btn_eject_clicked);

		// properties -----------------------

		button = new Gtk.Button.with_label(_("Properties"));
		button.set_image(IconManager.lookup_image("preferences-system-symbolic", 16, false, false));
		button.always_show_image = true;
		//button.set_tooltip_text(_("Properties"));
		bbox.add(button);
		btn_properties = button;

		//gtk_apply_css( { button }, "padding-top: 0px; padding-bottom: 0px; margin-top: 0px; margin-bottom: 0px;");
		
		button.clicked.connect(btn_properties_clicked);

		// close -----------------------

		//button = new Gtk.Button.with_label(_("Close"));
		//bbox.add(button);

		//button.clicked.connect(btn_close_clicked);

		// bbox -----------------------------------------------------

		bbox = new Gtk.ButtonBox(Gtk.Orientation.HORIZONTAL);
		bbox.set_layout(Gtk.ButtonBoxStyle.EXPAND);
		//bbox.spacing = 6;
		hbox.add(bbox);
		bbox_manage = bbox;
		
		//bbox.hexpand = true;

		// customize -----------------------

		button = new Gtk.Button.with_label(_("Customize"));
		bbox.add(button);

		button.clicked.connect(()=>{
			
			var win = new DevicePopoverSettingsWindow(App.main_window);

			win.settings_changed.connect(on_settings_changed);
			
			win.show_all();
		});

		bbox_actions.set_no_show_all(true);

		// edit -----------------------

		button = new Gtk.Button.with_label(_("Actions"));
		bbox.add(button);

		button.clicked.connect(()=>{
			
			manage_mode = true;

			gtk_hide(bbox_manage);
			gtk_show(bbox_actions);

			refresh();
		});

		bbox_actions.set_no_show_all(true);

		// spacer -----------------------------------
		
		dummy = new Gtk.Label("");
		dummy.hexpand = true;
		hbox.add(dummy);
	}

	private void on_settings_changed(){

		refresh_devices();

		this.set_size_request(App.dm_width, App.dm_height);
	}

	private Device? get_selected_device(){

		Gtk.TreeModel model;
		var paths = treeview.get_selection().get_selected_rows(out model);

		foreach(var treepath in paths){
			
			TreeIter iter;
			
			if (model.get_iter(out iter, treepath)){
				Device dev;
				model.get (iter, 0, out dev, -1);
				return dev;
			}
		}

		return null;
	}

	private void btn_open_clicked(){

		var device = get_selected_device();
		
		if (device != null){ 
			DeviceContextMenu.browse_device(device, pane, window);
			this.hide();
		}
	}

	private void btn_mount_clicked(){

		var device = get_selected_device();
		
		if (device != null){ 
			DeviceContextMenu.mount_device(device, pane, window);
			//refresh_devices();
		}
	}

	private void btn_unmount_clicked(){

		var device = get_selected_device();
		
		if (device != null){ 
			DeviceContextMenu.unmount_device(device, pane, window);
			//refresh_devices();
		}
	}

	private void btn_lock_clicked(){

		var device = get_selected_device();
		
		if (device != null){ 
			DeviceContextMenu.lock_device(device, pane, window);
			//refresh_devices();
		}
	}

	private void btn_unlock_clicked(){

		var device = get_selected_device();
		
		if (device != null){ 
			DeviceContextMenu.unlock_device(device, pane, window);
			//refresh_devices();
		}
	}

	private void btn_backup_clicked(){

		var device = get_selected_device();
		
		if ((device != null) && (view != null)){
			
			backup_device(device);
		}
	}

	private void btn_restore_clicked(){

		var device = get_selected_device();
		
		if ((device != null) && (view != null)){ 

			restore_device(device);
		}
	}


	private void btn_eject_clicked(){

		var device = get_selected_device();
		
		if (device != null){
			//DeviceContextMenu.browse_device(device, pane, window);
		}
	}

	private void btn_manage_clicked(){

		var device = get_selected_device();
		
		if (device != null){ 
			DeviceContextMenu.manage_disk(device, pane, window);
		}
	}

	private void btn_properties_clicked(){

		var device = get_selected_device();
		
		if (device != null){
			var win = new PropertiesWindow.for_device(device);
			win.show_all();
		}
	}

	// refresh ----------------------------
	
	public void show_popup(){

		log_debug("DevicePopover(): show_popup()");

		manage_mode = false;

		Device.get_block_devices();

		refresh();
		
		gtk_show(this);
	}
	
	private void refresh(){

		log_debug("DevicePopover(): refresh()");
		
		//refresh_places();
		
		refresh_devices();

		refresh_actions();
	}

	private void refresh_devices(){

		log_debug("DevicePopover(): refresh_devices()");
		
		var model = new Gtk.TreeStore(3, typeof(Device), typeof(string), typeof(Gdk.Pixbuf));
		treeview.set_model(model);

		var list = Main.get_devices();

		list.sort();
		
		foreach(var dev in list){
			
			if (dev.pkname.length == 0){ // type = disk, loop
				
				var iter0 = add_device(model, dev, null);

				foreach(var child1 in dev.children){
					if (child1.has_children){
						foreach(var child2 in child1.children){
							add_device(model, child2, iter0);
						}
					}
					else{
						add_device(model, child1, iter0);
					}
				}

				if (dev.children.size == 0){
					var dev2 = dev.copy();
					dev2.type = "part";
					dev2.pkname = dev.device.replace("/dev/","");
					dev2.parent = dev;
					add_device(model, dev2, null);
				}
			}
		}

		treeview.expand_all();

		col_size.visible = !App.dm_hide_size;
		col_fs.visible = !App.dm_hide_fs;
		col_mp.visible = !App.dm_hide_mp;

		//Device.print_logical_children();
	}

	private Gtk.TreeIter add_device(Gtk.TreeStore model, Device dev, Gtk.TreeIter? iter_parent){
		
		TreeIter iter;
		model.append(out iter, iter_parent);
		model.set(iter, 0, dev);
		model.set(iter, 1, dev.tooltip_text());
		model.set(iter, 2, dev.get_icon_fstype(16));
		return iter;
	}
	
	private void refresh_actions(){

		var dev = get_selected_device();

		/// note: unmount, backup, restore, format, manage is always visible. disable if not applicable.
		
		if (dev != null){

			btn_mount.sensitive = !dev.is_mounted && (dev.fstype.length > 0) && (dev.pkname.length > 0);

			btn_unmount.sensitive = dev.is_mounted && !dev.is_system_device;
			
			btn_lock.sensitive = dev.is_on_encrypted_partition && !dev.is_system_device;
			
			btn_unlock.sensitive = dev.is_encrypted_partition;

			btn_backup.sensitive = !dev.is_system_device; // cannot be unmounted

			btn_restore.sensitive = !dev.is_system_device; // cannot be unmounted

			btn_eject.sensitive = dev.removable && !dev.is_system_device;

			btn_format.sensitive = (dev.fstype.length > 0) && !dev.is_system_device; // cannot be unmounted

			var pix = dev.get_icon_fstype(16);
			if (pix != null){
				btn_format.set_image(new Gtk.Image.from_pixbuf(pix));
			}
			else{
				//btn_format.set_image(null);
			}

			btn_manage.sensitive = true;

			btn_properties.sensitive = true;
		}
		else{

			btn_mount.sensitive = false;
			
			btn_unmount.sensitive = false;

			btn_lock.sensitive = false;
			
			btn_unlock.sensitive = false;
;
			btn_backup.sensitive = false;
			
			btn_restore.sensitive = false;

			btn_format.sensitive = false;

			btn_manage.sensitive = false;

			btn_eject.sensitive = false;

			btn_properties.sensitive = false;
		}
	}

	// actions ------------------------------------

	public void backup_device(Device dev){

		if (!view.check_tool("polo-disk")){ return; }

		string image_file = choose_disk_image_file(dev, true);

		if (image_file.length == 0){ return; }

		string format = "";
		
		if (image_file.down().has_suffix(".gz")){
			format = "gz";
		}
		else if (image_file.down().has_suffix(".bz2")){
			format = "bz2";
		}
		else if (image_file.down().has_suffix(".img")){
			format = "img";
		}

		if (dev.is_mounted){
			bool ok = dev.unmount();
			log_debug("unmounted: %s".printf(ok.to_string()));
			
		}

		if (dev.is_mounted){
			string txt = "%s".printf(_("Failed to unmount device"));
			string msg = "%s:\n\n▰ %s".printf(_("Device is in use by the system"), dev.description_friendly());
			gtk_messagebox(txt, msg, window, true);
			return;
		}

		var action = new ProgressPanelDeviceWriterTask(pane);
		action.set_parameters(DiskAction.BACKUP, image_file, dev, format);
		pane.file_operations.add(action);
		action.execute();
	}

	public void restore_device(Device dev){

		if (!view.check_tool("polo-disk")){ return; }

		string image_file = choose_disk_image_file(dev, false);

		if (image_file.length == 0){ return; }

		string txt = "%s".printf(_("Restore device?"));
		string msg = "%s:\n\n▰ %s".printf(_("Existing data on device will be destroyed"), dev.description_friendly());
		var resp = gtk_messagebox_yes_no(txt, msg, window, true);
		if (resp != Gtk.ResponseType.YES){
			return;
		}

		if (dev.is_mounted){
			bool ok = dev.unmount();
			log_debug("unmounted: %s".printf(ok.to_string()));
		}

		if (dev.is_mounted){
			txt = "%s".printf(_("Failed to unmount device"));
			msg = "%s:\n\n▰ %s".printf(_("Device is in use by the system"), dev.description_friendly());
			gtk_messagebox(txt, msg, window, true);
			return;
		}
		
		var action = new ProgressPanelDeviceWriterTask(pane);
		action.set_parameters(DiskAction.RESTORE, image_file, dev, "");
		pane.file_operations.add(action);
		action.execute();
	}

	private string choose_disk_image_file(Device dev, bool save){

		var chooser = new Gtk.FileChooserDialog(
			(save ? _("Save As") : _("Select Disk Image")),
			window,
			(save ? FileChooserAction.SAVE : FileChooserAction.OPEN),
			"_Cancel",
			Gtk.ResponseType.CANCEL,
			(save ? "_Save" : "_Open"),
			Gtk.ResponseType.ACCEPT
		);

		chooser.local_only = true;
 		chooser.set_modal(true);
		chooser.select_multiple = false;

		//chooser.set_current_folder(pane.current_location);
		chooser.set_current_name(dev.kname);

		var filter = create_file_filter(_("GZip Compressed Disk Image"), { "*.gz" });
		chooser.add_filter(filter);
		var filter_gz = filter;

		filter = create_file_filter(_("BZip2 Compressed Disk Image"), { "*.bz2" });
		chooser.add_filter(filter);
		var filter_bz2 = filter;

		filter = create_file_filter(_("Raw Disk Image"), { "*.img" });
		chooser.add_filter(filter);
		var filter_img = filter;
		
		if (chooser.run() != Gtk.ResponseType.ACCEPT) {
			chooser.destroy();
			return "";
		}

		string fname = chooser.get_filename();

		var fltr = chooser.get_filter();

		string extension = "";
		
		if (fltr == filter_gz){
			extension = ".gz";
		}
		else if (fltr == filter_bz2){
			extension = ".bz2";
		}
		else if (fltr == filter_img){
			extension = ".img";
		}

		if (!fname.down().has_suffix(extension)){
			fname += extension;
		}

		chooser.destroy();

		return fname;
	}
}




