/*
 * DiskFormatContextMenu.vala
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

public class DiskFormatContextMenu : Gtk.Menu, IPaneActive {

	private Device? device;
	
	private Gtk.SizeGroup sg_icon;
	private Gtk.SizeGroup sg_label;

	public signal void device_formatting_complete();

	public DiskFormatContextMenu(){
		
		margin = 0;

		log_debug("DiskFormatContextMenu()");

		build_menu();
	}

	private void build_menu(){

		log_debug("DiskFormatContextMenu: build_menu()");

		Gdk.RGBA gray = Gdk.RGBA();
		gray.parse("rgba(200,200,200,1)");

		this.reserve_toggle_size = false;

		sg_icon = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);
		sg_label = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);

		foreach(string fmt in new string[]{ "btrfs", "exfat", "ext2", "ext3", "ext4", "f2fs", "fat16", "fat32", "hfs", "hfs+", "jfs", "nilfs2", "ntfs", "reiser4", "reiserfs", "ufs", "xfs" }){

			var item = gtk_menu_add_item(
				this,
				fmt,
				"",
				IconManager.lookup_image("fs-" + fmt, 16),
				sg_icon,
				sg_label);

			item.activate.connect (() => {
				execute(fmt);
			});

			item.sensitive = format_available(fmt);
		}
		
		show_all();
	}

	private void execute(string fmt){

		if (device == null){
			log_error("DiskFormatContextMenu: execute(): Device is null");
			return;
		}

		if (device.is_system_device){
			string txt = _("System Device");
			string msg = _("System devices cannot be changed while system is running");
			msg += "\n\n▰ %s".printf(device.description_friendly());
			gtk_messagebox(txt, msg, window, true);
			return;
		}

		string txt = "%s".printf(_("Format device?"));
		
		string msg = "%s:\n\n▰ %s".printf(_("Existing data on device will be destroyed"), device.description_friendly());

		msg += "\n\nDevice will be formatted with '%s' file system".printf(fmt);
		
		var resp = gtk_messagebox_yes_no(txt, msg, window, true);
		
		if (resp != Gtk.ResponseType.YES){
			return;
		}
		
		string cmd = "polo-disk format --device %s --fstype %s --user %s".printf(device.device, fmt, App.user_name);
				
		log_debug(cmd);
		
		this.sensitive = false;

		gtk_set_busy(true, App.main_window);

		string std_out, std_err;
		int status = App.exec_admin(cmd, out std_out, out std_err);

		gtk_set_busy(false, App.main_window);

		device_formatting_complete();

		if (status == 0){
			//gtk_messagebox(_("Formatting Complete"), std_out, App.main_window, true);
		}
		else if (std_err.strip().length > 0){
			gtk_messagebox(_("Formatting Failed"), std_err, App.main_window, true);
		}

		this.sensitive = true;
	}

	public bool format_available(string fmt){

		string cmd = "";
				
		switch(fmt){
		case "btrfs":
		case "ext2":
		case "ext3":
		case "ext4":
		case "f2fs":
		case "jfs":
		case "nilfs2":
		case "ntfs":
		case "ufs":
		case "xfs":
			cmd += "mkfs.%s".printf(fmt);
			break;

		case "exfat":
			cmd += "mkfs.exfat";
			break;
			
		case "fat16":
			cmd += "mkfs.fat";
			break;

		case "fat32":
			cmd += "mkfs.fat";
			break;

		case "hfs":
			cmd += "hformat";
			break;

		case "hfs+":
			cmd += "mkfs.hfsplus";
			break;

		case "reiser4":
			cmd += "mkfs.reiser4";
			break;
		
		case "reiserfs":
			cmd += "mkreiserfs";
			break;
		}

		return cmd_exists(cmd);
	}

	public bool show_menu(Device _device, Gdk.EventButton? event) {

		this.device = _device;
		
		if (event != null) {
			this.popup (null, null, null, event.button, event.time);
		}
		else {
			this.popup (null, null, null, 0, Gtk.get_current_event_time());
		}

		return true;
	}
}
