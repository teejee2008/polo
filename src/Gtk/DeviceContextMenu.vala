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

public class DeviceContextMenu : Gtk.Menu, IPaneActive {

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

		add_lock();

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

		add_eject();

		show_all();
	}
	
	private void add_open(){

		log_debug("DeviceContextMenu: add_open()");

		if (device.type == "disk"){ return; }

		// item ------------------

		var item = gtk_menu_add_item(
			this,
			_("Open"),
			_("Open in active pane"),
			null,
			sg_icon,
			sg_label);

		item.activate.connect (() => {
			browse_device(device, pane, window);
		});

		//mi_open.sensitive = (selected_items.size > 0);
	}

	private void add_mount(){

		log_debug("DeviceContextMenu: add_mount()");

		if (device.type == "disk"){ return; }

		// item ------------------

		var item = gtk_menu_add_item(
			this,
			_("Mount"),
			_("Mount this volume"),
			null,
			sg_icon,
			sg_label);

		item.activate.connect (() => {
			mount_device(device, pane, window);
		});

		item.sensitive = !device.is_mounted;
	}

	private void add_unmount(){

		log_debug("DeviceContextMenu: add_unmount()");

		if (device.type == "disk"){ return; }

		// item ------------------

		var item = gtk_menu_add_item(
			this,
			_("Unmount"),
			_("Unmount this volume"),
			null,
			sg_icon,
			sg_label);

		item.activate.connect (() => {
			unmount_device(device, pane, window);
		});

		item.sensitive = device.is_mounted && !device.is_system_device;
	}

	private void add_lock(){

		log_debug("DeviceContextMenu: add_lock()");

		if (device.type == "disk"){ return; }

		// item  ------------------

		var item = gtk_menu_add_item(
			this,
			_("Lock"),
			_("Unmount and lock encrypted volume"),
			null,
			sg_icon,
			sg_label);

		item.activate.connect (() => {
			lock_device(device, pane, window);
		});

		item.sensitive = device.is_on_encrypted_partition;
	}

	private void add_eject(){

		log_debug("DeviceContextMenu: add_eject()");

		if (device.type != "disk"){ return; }

		// item  ------------------

		var item = gtk_menu_add_item(
			this,
			_("Eject device"),
			_("Eject the device so that it can be removed safely"),
			null,
			sg_icon,
			sg_label);

		item.activate.connect (() => {
			eject_disk(device, pane, window);
		});

		item.sensitive = (device.type == "disk");
		
		//new Gtk.Image.from_pixbuf(IconManager.lookup("media-eject", 16, true))
	}

	private void add_unlock(){

		log_debug("DeviceContextMenu: add_lock()");

		if (device.type == "disk"){ return; }

		// item  ------------------

		var item = gtk_menu_add_item(
			this,
			_("Mount"),
			_("Mount this volume"),
			null,
			sg_icon,
			sg_label);

		item.activate.connect (() => {
			lock_device(device, pane, window);
		});

		item.sensitive = !device.is_mounted;
	}


	private void add_sync(){

		log_debug("DeviceContextMenu: add_sync()");

		if (device.type == "disk"){ return; }

		// item ------------------

		var item = gtk_menu_add_item(
			this,
			_("Sync Pending Writes"),
			_("Write any data waiting to be written to the device"),
			null,
			sg_icon,
			sg_label);

		item.activate.connect (() => {
			//view.open(item, null);
		});

		item.sensitive = device.is_mounted;
	}

	private void add_flush(){

		log_debug("DeviceContextMenu: add_flush()");

		if (device.type != "disk"){ return; }

		// item ------------------

		var item = gtk_menu_add_item(
			this,
			_("Flush Read Buffer"),
			_("Flushes the read buffer for device"),
			null,
			sg_icon,
			sg_label);

		item.activate.connect (() => {
			device.flush_buffers();
		});

		item.sensitive = device.is_mounted;
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

	// public static actions

	public static bool browse_device(Device _device, FileViewPane pane, MainWindow window){

		log_debug("DeviceContextMenu: browse_device(): %s".printf(_device.device));

		gtk_set_busy(true, window);

		Device dev = _device;

		if (!dev.is_mounted){

			if (dev.is_encrypted_partition){

				log_debug("prompting user to unlock encrypted partition");

				if (!dev.unlock("", "", window, false)){
					log_debug("device is null or still in locked state!");
					gtk_set_busy(false, window);
					return false; // no message needed
				}
				else{
					dev = dev.children[0];
				}
			}

			dev.automount(window);
			DeviceMonitor.notify_change(); // workaround for GLib.VolumeMonitor not detecting some mount events
		}

		bool mounted = dev.is_mounted;

		if (mounted){
			var mp = dev.mount_points[0];
			pane.view.set_view_path(mp.mount_point);
		}

		gtk_set_busy(false, window);

		return mounted;
	}

	public static bool unmount_device(Device _device, FileViewPane pane, MainWindow window){

		log_debug("DeviceContextMenu: unmount_device()");

		gtk_set_busy(true, window);

		Device dev = _device;
		
		if (dev.is_mounted){
			if (dev.unmount(window)){
				string title =  _("Device Unmounted");
				OSDNotify.notify_send(title, "", 1000, "low", "info");
			}
			DeviceMonitor.notify_change(); // workaround for GLib.VolumeMonitor not detecting some mount events
		}

		bool mounted = dev.is_mounted;

		gtk_set_busy(false, window);

		return mounted;
	}

	public static bool mount_device(Device _device, FileViewPane pane, MainWindow window){

		log_debug("DeviceContextMenu: mount_device(): %s".printf(_device.device));

		gtk_set_busy(true, window);

		Device dev = _device;

		if (!dev.is_mounted){

			if (dev.is_encrypted_partition){

				log_debug("prompting user to unlock encrypted partition");

				if (!dev.unlock("", "", window, false)){
					log_debug("device is null or still in locked state!");
					gtk_set_busy(false, window);
					return false; // no message needed
				}
				else{
					dev = dev.children[0];
				}
			}

			dev.automount(window);
			DeviceMonitor.notify_change(); // workaround for GLib.VolumeMonitor not detecting some mount events
		}

		bool mounted = dev.is_mounted;

		gtk_set_busy(false, window);

		return mounted;
	}

	public static bool lock_device(Device _device, FileViewPane pane, MainWindow window){

		log_debug("DeviceContextMenu: lock_device(): %s".printf(_device.device));

		gtk_set_busy(true, window);

		Device dev = _device;
		
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

		return ok;
	}

	public static bool eject_disk(Device _device, FileViewPane pane, MainWindow window){
	
		log_debug("DeviceContextMenu: eject_device(): %s".printf(_device.device));

		string txt = _("Eject Disk ?");
		string msg = _("Partitions on following device will be unmounted and device will be ejected:");
		msg += "\n\n%s".printf(_device.description_simple(true));
		if (gtk_messagebox_yes_no(txt, msg, window, false) != Gtk.ResponseType.YES){
			return false;
		}
		
		gtk_set_busy(true, window);

		Device dev = _device;
		
		bool ok = true;
		
		gtk_set_busy(false, window);

		return ok;
	}


}




