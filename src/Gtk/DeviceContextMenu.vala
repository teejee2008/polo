/*
 * DeviceContextMenu.vala
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

public class DeviceContextMenu : Gtk.Menu {

	private Gtk.MenuItem mi_open;
	private Gtk.MenuItem mi_mount;
	private Gtk.MenuItem mi_unmount;
	//private Gtk.MenuItem mi_lock;
	//private Gtk.MenuItem mi_unlock;
	private Gtk.MenuItem mi_sync;
	private Gtk.MenuItem mi_flush;

	private Gtk.SizeGroup sg_icon;
	private Gtk.SizeGroup sg_label;

	public Device device;

	public DeviceContextMenu(Device _device){
		
		margin = 0;

		log_debug("DeviceContextMenu()");

		device = _device;

		if (device.has_parent()){
			build_menu();
		}
		else{
			build_menu_for_drive();
		}
	}

	// file context menu

	private void build_menu(){

		log_debug("DeviceContextMenu: build_menu()");

		Gdk.RGBA gray = Gdk.RGBA();
		gray.parse("rgba(200,200,200,1)");

		this.reserve_toggle_size = false;

		sg_icon = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);
		sg_label = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);

		add_open();

		add_mount();

		add_unmount();

		//add_sync();

		//add_flush();


		//gtk_menu_add_separator(this);

		show_all();
	}

	private void build_menu_for_drive(){
		
		log_debug("DeviceContextMenu: build_menu_for_drive()");

		Gdk.RGBA gray = Gdk.RGBA();
		gray.parse("rgba(200,200,200,1)");

		this.reserve_toggle_size = false;


		show_all();
	}
	
	private void add_open(){

		log_debug("DeviceContextMenu: add_open()");

		if (device.type == "disk"){ return; }

		// open ------------------

		mi_open = gtk_menu_add_item(
			this,
			_("Open"),
			_("Open in active pane"),
			null,
			sg_icon,
			sg_label);

		mi_open.activate.connect (() => {
			//view.open(item, null);
		});

		//mi_open.sensitive = (selected_items.size > 0);
	}

	private void add_mount(){

		log_debug("DeviceContextMenu: add_mount()");

		if (device.type == "disk"){ return; }

		// mount ------------------

		mi_mount = gtk_menu_add_item(
			this,
			_("Mount"),
			_("Mount this volume"),
			null,
			sg_icon,
			sg_label);

		mi_mount.activate.connect (() => {
			//view.open(item, null);
		});

		mi_mount.sensitive = !device.is_mounted;
	}

	private void add_unmount(){

		log_debug("DeviceContextMenu: add_unmount()");

		if (device.type == "disk"){ return; }

		// unmount ------------------

		mi_unmount = gtk_menu_add_item(
			this,
			_("Unmount"),
			_("Unmount this volume"),
			new Gtk.Image.from_pixbuf(IconManager.lookup("media-eject", 16, true)),
			sg_icon,
			sg_label);

		mi_unmount.activate.connect (() => {
			//view.open(item, null);
		});

		mi_unmount.sensitive = device.is_mounted;
	}

	private void add_sync(){

		log_debug("DeviceContextMenu: add_sync()");

		if (device.type == "disk"){ return; }

		// sync ------------------

		mi_sync = gtk_menu_add_item(
			this,
			_("Sync Pending Writes"),
			_("Write any data waiting to be written to the device"),
			null,
			sg_icon,
			sg_label);

		mi_sync.activate.connect (() => {
			//view.open(item, null);
		});

		mi_sync.sensitive = device.is_mounted;
	}

	private void add_flush(){

		log_debug("DeviceContextMenu: add_flush()");

		if (device.type != "disk"){ return; }

		// flush ------------------

		mi_flush = gtk_menu_add_item(
			this,
			_("Flush Read Buffer"),
			_("Flushes the read buffer for device"),
			null,
			sg_icon,
			sg_label);

		mi_flush.activate.connect (() => {
			device.flush_buffers();
		});

		mi_flush.sensitive = device.is_mounted;
	}

	public bool show_menu(Gdk.EventButton? event) {

		if (event != null) {
			this.popup (null, null, null, event.button, event.time);
		}
		else {
			this.popup (null, null, null, 0, Gtk.get_current_event_time());
		}

		return true;
	}
}




