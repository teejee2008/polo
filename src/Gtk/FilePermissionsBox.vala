/*
 * FilePermissionsBox.vala
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

public class FilePermissionsBox : Gtk.Box {

	private FileItem? file_item;
	private FileItem? dir_item;

	private bool file_is_remote {
		get { return (file_item != null) && file_item.file_path.has_prefix(App.rclone_mounts); }
	}

	private Gtk.Window window;

	private bool panel_mode = false;

	private Gtk.SizeGroup? group_label;

	public FilePermissionsBox(Gtk.Window parent_window, bool _panel_mode){
		//base(Gtk.Orientation.VERTICAL, 6); // issue with vala
		Object(orientation: Gtk.Orientation.VERTICAL, spacing: 6); // work-around
		margin = 12;
		
		window = parent_window;

		panel_mode = _panel_mode;
	}

	public void show_properties_for_file(FileItem _file_item, Gtk.SizeGroup? _group_label){

		file_item = _file_item;
		dir_item = file_item.is_directory ? file_item : (new FileItem.from_path(file_item.file_location));

		file_item.query_file_info();

		group_label = _group_label;
		
		init_ui_for_file();

		this.show_all();
	}

	private void init_ui_for_file(){

		gtk_container_remove_children(this);
		
		if ((file_item == null) || (file_item.perms.length == 0)){ return; }
			
		if ((file_item is FileItemArchive) || (file_item is FileItemCloud)){ return; }
		
		log_debug("FilePermissionsBox: init_ui_for_file()");
		
		var vbox = new Gtk.Box(Orientation.VERTICAL, 6);
		this.add(vbox);

		var label = new Gtk.Label("<b>%s:</b>".printf(_("Permissions")));
		label.set_use_markup(true);
		label.xalign = 0.0f;
		label.margin_bottom = 6;
		vbox.add(label);

		//if (panel_mode){
			//label.xalign = 0.5f;
		//}

		//if (group_label != null){
		//	group_label.add_widget(label);;
		//}

		//grid
		var grid = new Gtk.Grid();
		grid.set_column_spacing(6);
		grid.set_row_spacing(6);
		vbox.add(grid);

		if (!panel_mode){
			grid.set_column_spacing(12);
			grid.margin_left = 6;
			grid.margin_right = 12;
		}

		label = new Gtk.Label(_("User"));
		label.xalign =  1.0f;
		grid.attach(label, 0, 1, 1, 1);

		if (group_label != null){
			group_label.add_widget(label);;
		}

		label = new Gtk.Label(_("Group"));
		label.xalign =  1.0f;
		grid.attach(label, 0, 2, 1, 1);

		if (group_label != null){
			group_label.add_widget(label);;
		}

		label = new Gtk.Label(_("Others"));
		label.xalign =  1.0f;
		grid.attach(label, 0, 3, 1, 1);

		if (group_label != null){
			group_label.add_widget(label);;
		}

		add_option(grid, 1, 1, "u", "r", panel_mode ? "r" : _("Read"));

		add_option(grid, 2, 1, "u", "w", panel_mode ? "w" : _("Write"));

		add_option(grid, 3, 1, "u", "x", panel_mode ? "x" : _("Execute"));

		add_option(grid, 1, 2, "g", "r", panel_mode ? "r" : _("Read"));

		add_option(grid, 2, 2, "g", "w", panel_mode ? "w" : _("Write"));

		add_option(grid, 3, 2, "g", "x", panel_mode ? "x" : _("Execute"));

		add_option(grid, 1, 3, "o", "r", panel_mode ? "r" : _("Read"));

		add_option(grid, 2, 3, "o", "w", panel_mode ? "w" : _("Write"));

		add_option(grid, 3, 3, "o", "x", panel_mode ? "x" : _("Execute"));

		var sep = new Gtk.Separator(Gtk.Orientation.HORIZONTAL);
		grid.attach(sep, 0, 4, 5, 1);

		label = new Gtk.Label(_("Special"));
		label.xalign =  1.0f;
		grid.attach(label, 0, 5, 1, 1);

		add_option(grid, 1, 5, "u", "s", "SUID");

		add_option(grid, 2, 5, "g", "s", "SGID");

		add_option(grid, 3, 5, "", "t", "Sticky");

		var spacer = new Gtk.Label("");
		spacer.margin_bottom = 12;
		grid.attach(spacer, 1, 6, 1, 1);

		log_debug("FilePermissionsBox: init_ui_for_file(): done");
	}

	private void add_option(Gtk.Grid grid, int col,  int row, string user, string mode_bit, string? text = null){

		var chk = new Gtk.CheckButton.with_label(text);
		//chk.margin_left = 6;
		grid.attach(chk, col, row, 1, 1);

		chk.set_data<string>("user",user);
		chk.set_data<string>("mode",mode_bit);

		if (mode_bit == "t"){
			chk.set_tooltip_text(_("Protects files in shared directory from being deleted by other users. Only the owner of the file, owner of the directory or root user will be able to rename or delete the file.\n\nThis is useful for shared directories. Only the owners of files will be able to rename or delete files created by them. They will not be able to modify files created by other users."));
		}
		else if ((mode_bit == "s") && (user == "u")){
			chk.set_tooltip_text(_("File will be executed with the priviledges of the file's owner instead of priviledges of user who is executing the file.\n\nUseful for executable files. Allows anybody who has permission to execute the file, to run it with the owner's priviledges."));
		}
		else if ((mode_bit == "s") && (user == "g")){
			chk.set_tooltip_text(_("File will be executed with the priviledges of the file's group instead of priviledges of user who is executing the file.\n\nUseful for executable files. Allows anybody who has permission to execute the file, to run it with the group's priviledges."));
		}

		switch(user){
		case "u":
			switch(mode_bit){
			case "r":
				chk.active = (file_item.perms[1] == "r");
				break;
			case "w":
				chk.active = (file_item.perms[2] == "w");
				break;
			case "x":
				chk.active = (file_item.perms[3] == "x") || (file_item.perms[3] == "s");
				break;
			case "s":
				chk.active = (file_item.perms[3] == "s");
				break;
			}
			break;
		case "g":
			switch(mode_bit){
			case "r":
				chk.active = (file_item.perms[4] == "r");
				break;
			case "w":
				chk.active = (file_item.perms[5] == "w");
				break;
			case "x":
				chk.active = (file_item.perms[6] == "x") || (file_item.perms[6] == "s");
				break;
			case "s":
				chk.active = (file_item.perms[6] == "s");
				break;
			}
			break;
		case "o":
			switch(mode_bit){
			case "r":
				chk.active = (file_item.perms[7] == "r");
				break;
			case "w":
				chk.active = (file_item.perms[8] == "w");
				break;
			case "x":
				chk.active = (file_item.perms[9] == "x") || (file_item.perms[9] == "t");
				break;
			}
			break;
		case "":
			switch(mode_bit){
			case "t":
				chk.active = (file_item.perms[9] == "t");
				break;
			}
			break;
		}

		chk.toggled.connect(chk_permission_toggled);

		chk.sensitive = file_item.is_local;
	}

	private void chk_permission_toggled(Gtk.ToggleButton chk){

		string user = chk.get_data<string>("user");
		string mode = chk.get_data<string>("mode");

		if (chk.active){
			if (!chmod(file_item.file_path, user + "+" + mode, window)){
				chk.toggled.disconnect(chk_permission_toggled);
				chk.active = !chk.active;
				chk.toggled.connect(chk_permission_toggled);
			}
		}
		else{
			if (!chmod(file_item.file_path, user + "-" + mode, window)){
				chk.toggled.disconnect(chk_permission_toggled);
				chk.active = !chk.active;
				chk.toggled.connect(chk_permission_toggled);
			}
		}

		file_item.query_file_info();
	}
}


