/*
 * DeviceContextMenu.vala
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

public class DeviceContextMenu : Gtk.Menu, IPaneActive {

	private Gtk.SizeGroup sg_icon;
	private Gtk.SizeGroup sg_label;

	public Device device;
	public Gtk.Popover? parent_popup;
	
	public DeviceContextMenu(Device _device, Gtk.Popover? _parent_popup){
		
		margin = 0;

		log_debug("DeviceContextMenu()");

		device = _device;
		parent_popup = _parent_popup;
		
		if (device.pkname.length == 0){
			build_menu_for_drive();
		}
		else{
			build_menu();
		}
	}

	private void build_menu(){

		log_debug("DeviceContextMenu: build_menu()");

		Gdk.RGBA gray = Gdk.RGBA();
		gray.parse("rgba(200,200,200,1)");

		this.reserve_toggle_size = false;

		sg_icon = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);
		sg_label = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);

		add_header();

		add_open();

		add_mount();

		add_unmount();
		
		gtk_menu_add_separator(this);
		
		if (App.tool_exists("gnome-disks")) {
			
			add_manage();
		
			//add_format();
		}

		add_lock();

		//add_sync();

		//add_flush();

		gtk_menu_add_separator(this);

		add_properties();

		show_all();
	}

	private void build_menu_for_drive(){
		
		log_debug("DeviceContextMenu: build_menu_for_drive()");

		Gdk.RGBA gray = Gdk.RGBA();
		gray.parse("rgba(200,200,200,1)");

		this.reserve_toggle_size = false;

		//add_eject();
		
		if (App.tool_exists("gnome-disks")) {
			
			add_manage();
		
			//add_format();
		}

		show_all();
	}

	private void add_header(){

		log_debug("DeviceContextMenu: add_header()");

		// item ------------------

		var item = gtk_menu_add_item(
			this,
			"<b>%s</b>".printf(device.device),
			"",
			null,
			sg_icon,
			sg_label);

		item.sensitive = false;

		gtk_menu_add_separator(this);
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
			if (parent_popup != null){
				parent_popup.hide();
			}
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

	/*private void add_eject(){

		log_debug("DeviceContextMenu: add_eject()");

		if (device.type != "disk"){ return; }

		// item  ------------------

		var item = gtk_menu_add_item(
			this,
			_("Eject"),
			_("Eject the device so that it can be removed safely"),
			null,
			sg_icon,
			sg_label);

		item.activate.connect (() => {
			eject_disk(device, pane, window);
		});

		item.sensitive = (device.type == "disk");
	}*/
	
	private void add_manage(){

		log_debug("DeviceContextMenu: add_manage()");

		// item  ------------------

		var item = gtk_menu_add_item(
			this,
			_("Manage..."),
			_("Manage device using GNOME disk utility"),
			null,
			sg_icon,
			sg_label);

		item.activate.connect (() => {
			manage_disk(device, pane, window);
			if (parent_popup != null){
				parent_popup.hide();
			}
		});

		item.sensitive = (device.type != "loop");
	}
	
	private void add_properties(){

		log_debug("DeviceContextMenu: add_properties()");

		// item  ------------------

		var item = gtk_menu_add_item(
			this,
			_("Properties"),
			_("Show device properties"),
			null,
			sg_icon,
			sg_label);

		item.activate.connect (() => {
			var win = new FilePropertiesWindow.for_device(device);
			//log_msg("111");
			win.show_all();
		});

		item.sensitive = (device.type != "loop");
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
			pane.view.set_view_path(dev.mount_path);
		}

		gtk_set_busy(false, window);

		return mounted;
	}

	public static bool unmount_device(Device _device, FileViewPane pane, MainWindow window){

		log_debug("DeviceContextMenu: unmount_device()");

		Device dev = _device;
		
		if (dev.is_system_device){
			string txt = _("System Device");
			string msg = _("System devices cannot be changed while system is running");
			msg += "\n\n▰ %s".printf(dev.description_friendly());
			gtk_messagebox(txt, msg, window, true);
			return false;
		}

		gtk_set_busy(true, window);

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

	public static bool eject_device(Device _device, FileViewPane pane, MainWindow window){

		log_debug("DeviceContextMenu: unmount_device()");

		Device dev = _device;
		
		if (dev.is_system_device){
			string txt = _("System Device");
			string msg = _("System devices cannot be changed while system is running");
			gtk_messagebox(txt, msg, window, true);
			msg += "\n\n▰ %s".printf(dev.description_friendly());
			return false;
		}
		
		gtk_set_busy(true, window);

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

	public static bool unlock_device(Device _device, FileViewPane pane, MainWindow window){

		log_debug("DeviceContextMenu: unlock_device(): %s".printf(_device.device));

		gtk_set_busy(true, window);

		Device dev = _device;

		if (dev.is_mounted){
			return true;
		}
		else if (dev.is_on_encrypted_partition){
			return true;
		}
		else if (dev.is_encrypted_partition){

			log_debug("prompting user to unlock encrypted partition");

			if (!dev.unlock("", "", window, false)){
				log_debug("device is null or still in locked state!");
				gtk_set_busy(false, window);
				return false; // no message needed
			}
			else{
				dev = dev.children[0];
			}
			
			dev.automount(window);
			DeviceMonitor.notify_change(); // workaround for GLib.VolumeMonitor not detecting some mount events
		}
		else{
			// ignore
		}

		gtk_set_busy(false, window);

		return true;
	}

	public static bool lock_device(Device _device, FileViewPane pane, MainWindow window){

		log_debug("DeviceContextMenu: lock_device(): %s".printf(_device.device));

		Device dev = _device;
		
		if (dev.is_system_device){
			string txt = _("System Device");
			string msg = _("System devices cannot be changed while system is running");
			msg += "\n\n▰ %s".printf(dev.description_friendly());
			gtk_messagebox(txt, msg, window, true);
			return false;
		}
		
		gtk_set_busy(true, window);

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

	public static void manage_disk(Device _device, FileViewPane pane, MainWindow window){
	
		log_debug("DeviceContextMenu: manage_disk(): %s".printf(_device.device));

		if (App.tool_exists("gnome-disks")){
			
			string cmd = "gnome-disks --block-device %s".printf(_device.device);
			
			exec_process_new_session(cmd);
		}
		else{
			string txt = _("Missing Dependency");
			string msg = _("GNOME Disk Uitility (gnome-disks) is not installed");
			gtk_messagebox(txt, msg, window, true);
		}
	}
}




