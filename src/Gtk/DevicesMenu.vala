/*
 * DevicesMenu.vala
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

public class DevicesMenu : Gtk.Menu, IPaneActive {

	public DevicesMenu(){

		reserve_toggle_size = false;
		
		build_menu();
	}

	public void build_menu(){

		log_debug("DevicesMenu: build_menu()");

		var list = Device.get_block_devices_using_lsblk();

		for(int i=0; i < list.size; i++){
			var dev = list[i];
			if ((dev.type == "crypt") && (dev.pkname.length > 0)){

				//pi.name = "%s".printf(pi.pkname);

				// this is an unlocked device
				// find and remove the locked one
				foreach(var dev_luks in list){
					if (dev_luks.name == dev.pkname){
						if (dev_luks.type != "disk"){
							list.remove(dev_luks);
						}
						break;
					}
				}
			}
		}

		var sg_name = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);
		var sg_size = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);
		var sg_mp = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);

		foreach(var dev in list){
			
			// menu_item
			var menu_item = new Gtk.MenuItem();
			this.append(menu_item);

			var box = new Gtk.Box(Orientation.HORIZONTAL, 3);
			menu_item.add(box);

			Gtk.Image img = null;
			if ((dev.type == "crypt") && (dev.pkname.length > 0)){
				img = IconManager.lookup_image("unlocked",16);
				box.add(img);
			}
			else if (dev.fstype.contains("luks")){
				img = IconManager.lookup_image("locked",16);
				box.add(img);
			}
			else if (dev.fstype.contains("iso9660")){
				img = IconManager.lookup_image("media-cdrom",16);
				box.add(img);
			}
			else{
				img = IconManager.lookup_image("drive-harddisk-symbolic",16);
				box.add(img);
			}

			if ((dev.type == "disk") || ((dev.type == "loop") && dev.has_children)){
				img.margin_left = 0;
				box.remove(img);
			}
			else{
				img.margin_left = 12;

			}

			// name and label -------------

			string name = "";
			if ((dev.type == "disk") || ((dev.type == "loop") && dev.has_children)){
				name += "%s".printf(dev.description_simple());
			}
			else{
				name += "" + dev.name + ((dev.label.length > 0) ? " (%s)".printf(dev.label) : "");
			}

			var lbl = new Gtk.Label(name);
			lbl.xalign = 0.0f;
			lbl.margin_right = 6;
			box.add(lbl);

			if ((dev.type == "disk") || ((dev.type == "loop") && dev.has_children)){
				// skip
			}
			else{
				//lbl.margin_left = 6;
				sg_name.add_widget(lbl);
			}

			// size label ------------------

			if ((dev.type == "disk") || ((dev.type == "loop") && dev.has_children)){
				// skip
			}
			else{
				lbl = new Gtk.Label(dev.size_formatted);
				lbl.xalign = 1.0f;
				lbl.margin_right = 6;
				box.add(lbl);
				sg_size.add_widget(lbl);
			}

			// mount point label --------------------

			if (dev.mount_points.size > 0){
				var mp = dev.mount_points[0];
				lbl = new Gtk.Label(mp.mount_point);
				lbl.xalign = 0.0f;
				lbl.margin_right = 6;
				box.add(lbl);
				sg_mp.add_widget(lbl);
			}

			// navigate to mount point on click ---------

			menu_item.activate.connect (() => {

				gtk_set_busy(true, window);

				// unlock
				if (dev.fstype.contains("luks")){
					string message, details;
					var unlocked_device = Device.luks_unlock(dev, "", "", pane.window);
					if (unlocked_device == null){
						gtk_set_busy(false, pane.window);
						return;
					}
				}

				// mount if unmounted
				if (dev.mount_points.size == 0){
					bool ok = Device.automount_udisks(dev, pane.window);
					if (!ok){
						gtk_set_busy(false, pane.window);
						return;
					}
				}

				// navigate
				if (dev.mount_points.size > 0){
					var mp = dev.mount_points[0];
					view.set_view_path(mp.mount_point);
				}

				gtk_set_busy(false, window);
			});
		}

		this.show_all();
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

	public void hide_menu() {
		this.popdown();
	}
}


