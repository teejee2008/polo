/*
 * PropertiesWindow.vala
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

public class PropertiesWindow : Gtk.Window {

	//private Gtk.Box vbox_main;
	private Gtk.DrawingArea area_archive;
	private Gtk.DrawingArea area_fs;
	private FileItem? file_item;
	private FileItem? dir_item;
	private Device? device;
	private MediaFile mfile;

	private bool file_is_remote {
		get { return (file_item != null) && file_item.file_path.has_prefix(App.rclone_mounts); }
	}

	private Gtk.Box header_box;
	private Gtk.StackSwitcher switcher;
	private Gtk.Stack stack;

	private Gtk.SizeGroup group_label;
	private Gtk.SizeGroup group1_value;
	private Gtk.SizeGroup group2_value;

	private Gtk.Entry entry_created; 
	private Gtk.Entry entry_modified; 
	private Gtk.Entry entry_changed; 
	private Gtk.Entry entry_accessed;

	private Gtk.ComboBox cmb_user;
	private Gtk.ComboBox cmb_group;

	private TouchFileDateContextMenu menu_accessed;
	private TouchFileDateContextMenu menu_modified;

	private signal void file_touched();

	public PropertiesWindow.for_file(FileItem _file_item) {

		file_item = _file_item;
		dir_item = file_item.is_directory ? file_item : (new FileItem.from_path(file_item.file_location));

		file_item.query_file_info();
		
		init_window();
	}

	public PropertiesWindow.for_device(Device _device) {
		
		device = _device;

		init_window();
	}

	public void init_window () {

		set_transient_for(App.main_window);
		set_modal(true);
		//set_type_hint(Gdk.WindowTypeHint.DIALOG); // Do not use; Hides close button on some window managers
		set_skip_taskbar_hint(true);
		set_skip_pager_hint(true);
		window_position = WindowPosition.CENTER_ON_PARENT;
		deletable = true;
		resizable = true;
		icon = get_app_icon(16,".svg");
		title = _("Properties");
		
		// vbox_main
		var vbox_main = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
		vbox_main.set_size_request(600, 400);
		add(vbox_main);

		header_box = new Gtk.Box(Orientation.HORIZONTAL, 6);
		header_box.margin = 0;
		header_box.get_style_context().add_class(Gtk.STYLE_CLASS_PRIMARY_TOOLBAR);
		vbox_main.add(header_box);

		switcher = new Gtk.StackSwitcher();
		switcher.margin = 6;
		header_box.add (switcher);

		var label = new Gtk.Label("");
		label.hexpand = true;
		header_box.add(label);

		stack = new Gtk.Stack();
		stack.set_transition_duration (200);
        stack.set_transition_type (Gtk.StackTransitionType.SLIDE_LEFT_RIGHT);
		vbox_main.add(stack);

		switcher.set_stack(stack);

		// hide tabs when showing only device properties
		bool show_tabs = (device == null);
		switcher.set_no_show_all(!show_tabs);
		header_box.set_no_show_all(!show_tabs);

		group_label = new Gtk.SizeGroup(Gtk.SizeGroupMode.HORIZONTAL);
		group1_value = new Gtk.SizeGroup(Gtk.SizeGroupMode.HORIZONTAL);
		group2_value = new Gtk.SizeGroup(Gtk.SizeGroupMode.HORIZONTAL);
		
		init_tab_properties();

		init_tab_fs();

		init_tab_permissions();

		init_tab_mediainfo();
	}

	// properties tab

	private void init_tab_properties(){

		if (file_item == null){ return; }

		log_debug("PropertiesWindow: init_tab_properties()");
		
		var hbox = new Gtk.Box(Orientation.HORIZONTAL, 24);
		hbox.margin = 12;
		//hbox.margin_left = 24;
		//hbox.margin_bottom = 24;
		//hbox.margin_right = 24;
		stack.add_titled (hbox, _("General"), _("General"));

		if (file_item is FileItemArchive){

			//ratio bar
			var area = new Gtk.DrawingArea();
			area.set_size_request(30, 40);
			area.vexpand = true;
			hbox.add(area);
			area_archive = area;

			area.draw.connect(area_archive_draw);
		}

		var vbox = new Gtk.Box(Orientation.VERTICAL, 6);
		hbox.add(vbox);

		//Label label;

		// name ----------------
		
		var txt = file_item.display_name;
		add_property(vbox, _("Name"), txt);

		// location -----------
		
		txt = file_item.display_location;

		add_property(vbox, _("Location"), txt);

		if (file_item.is_symlink){
			add_property(vbox, _("Link Target"), file_item.symlink_target);
		}

		// size -------------
		
		if (file_item.file_size > -1){

			txt = "%s (%'ld bytes)".printf(
				format_file_size(file_item.file_size),
				file_item.file_size
			);

			add_property(vbox, _("Size"), txt);
		}

		// contents ----------
		
		if ((file_item.file_count > 0)||(file_item.dir_count > 0)){

			txt = "%'ld items (%'ld files, %'ld dirs)".printf(
				file_item.file_count + file_item.dir_count,
				file_item.file_count,
				file_item.dir_count
			);

			add_property(vbox, _("Contents"), txt);
		}

		// archive ----------
		
		if (file_item is FileItemArchive){

			var archive = (FileItemArchive) file_item;
			
			add_separator(vbox);

			// type ----------
			
			if (archive.archive_type.length > 0){
				txt = archive.archive_type;
				add_property(vbox, _("Type"), txt);
			}

			// method ----------
			
			if (archive.archive_method.length > 0){
				txt = archive.archive_method;
				add_property(vbox, _("Method"), txt);
			}

			// encrypted ----------
			
			txt = archive.archive_is_encrypted ? _("Yes") : _("No");
			add_property(vbox, _("Encrypted"), txt);

			// solid ----------
			
			txt = archive.archive_is_solid ? _("Yes") : _("No");
			add_property(vbox, _("Solid"), txt);

			// blocks ----------
			
			if (archive.archive_blocks > 0){
				txt = "%'d".printf(archive.archive_blocks);
				add_property(vbox, _("Blocks"), txt);
			}

			// packed ----------

			if (archive.archive_size > 0){
				
				txt = "%s (%'ld bytes)".printf(
					format_file_size(archive.archive_size),
					archive.archive_size
				);
				
				add_property(vbox, _("Packed"), txt);
			}

			// unpacked ----------
			
			if (archive.file_size > 0){

				txt = "%s (%'ld bytes)".printf(
					format_file_size(archive.file_size),
					archive.file_size
				);

				add_property(vbox, _("Unpacked"), txt);
			}

			// headers ----------
			
			if (archive.archive_header_size > 0){

				txt = "%s (%'ld bytes)".printf(
					format_file_size(archive.archive_header_size),
					archive.archive_header_size
				);

				add_property(vbox, _("Headers"), txt);
			}
		}

		add_separator(vbox);

		// type ------------------
		
		add_property(vbox, _("Type"), file_item.content_type_desc);

		// mime -----------------
		
		add_property(vbox, _("Mime"), file_item.content_type);

		add_separator(vbox);

		// created ---------------------------
		
		string date_string = "";
		if (file_item.created != null){
			date_string = file_item.created.format("%Y-%m-%d %H:%M");
		}
		else{
			date_string = "N/A";
		}

		entry_created = add_property_created(vbox, _("Created"), date_string);

		// modified ---------------------------

		entry_modified = add_property_modified(vbox, _("Modified"), "");

		file_touched.connect(() => {
			if (file_item.modified != null){
				date_string = file_item.modified.format("%Y-%m-%d %H:%M:%S");
			}
			else{
				date_string = "N/A";
			}
			entry_modified.text = date_string;
		});

		// accessed ---------------------------
		
		entry_accessed = add_property_accessed (vbox, _("Accessed"), "");

		file_touched.connect(() => {
			if (file_item.accessed != null){
				date_string = file_item.accessed.format("%Y-%m-%d %H:%M:%S");
			}
			else{
				date_string = "N/A";
			}
			entry_accessed.text = date_string;
		});
		
		// changed ---------------------------
	
		entry_changed = add_property_changed (vbox, _("Changed"), "");

		file_touched.connect(() => {
			if (file_item.changed != null){
				date_string = file_item.changed.format("%Y-%m-%d %H:%M:%S");
			}
			else{
				date_string = "N/A";
			}
			entry_changed.text = date_string;
		});

		file_touched();

		add_separator(vbox);

		// user ---------------------------

		add_user_combo(vbox);

		// group ---------------------------

		add_group_combo(vbox);

		// preview ---------------------
		
		init_preview_image(hbox); 
	} 
 
	private void init_preview_image(Gtk.Box hbox){
	  
		var image = new Gtk.Image();
		hbox.add(image);

		ThumbTask task;
		var thumb = file_item.get_image(256, true, false, false, out task);

		if (task != null){
			while (!task.completed){
				sleep(100);
				gtk_do_events();
			}
			thumb = file_item.get_image(256, true, false, false, out task);
		}
		
		if (thumb != null) {
			image.pixbuf = thumb;
			log_debug("setting from file_item.get_image()");
		}
		else if (file_item.icon != null) {
			image.gicon = file_item.icon;
			log_debug("setting from file_item.gicon");
		}
		else{
			if (file_item.file_type == FileType.DIRECTORY) {
				image.pixbuf = IconManager.generic_icon_directory(256);
			}
			else{
				image.pixbuf = IconManager.generic_icon_file(256);
			}
		}
	}

	private bool area_archive_draw(Cairo.Context context) {

		if (file_item is FileItemArchive == false){ return true; }
		
		var arch = (FileItemArchive) file_item;
		double ratio = (arch.archive_size * 1.0) / arch.file_size;

		var color_blue_100 = Gdk.RGBA();
		color_blue_100.parse("#BBDEFB");
		color_blue_100.alpha = 1.0;

		var color_grey_700 = Gdk.RGBA();
		color_grey_700.parse("#616161");
		color_grey_700.alpha = 1.0;

		var color_white = Gdk.RGBA();
		color_white.parse("white");
		color_white.alpha = 1.0;

		var area = area_archive;

		int w = area.get_allocated_width();
		int h = area.get_allocated_height();

		//------ BEGIN CONTEXT -------------------------------------------------
		context.set_line_width (1);
		Gdk.cairo_set_source_rgba (context, color_blue_100);
		context.rectangle(0, 0, w, h);
		context.fill();
		//------ END CONTEXT ---------------------------------------------------

		//------ BEGIN CONTEXT -------------------------------------------------
		context.set_line_width (1);
		Gdk.cairo_set_source_rgba (context, color_grey_700);
		context.rectangle(0, h * (1.0 - ratio), w, (h * ratio));
		context.fill();
		//------ END CONTEXT ---------------------------------------------------

		//------ BEGIN CONTEXT -------------------------------------------------
		context.set_line_width (1);
		Gdk.cairo_set_source_rgba (context, color_grey_700);
		context.rectangle(0, 0, w, h);
		context.stroke();
		//------ END CONTEXT ---------------------------------------------------

		//------ BEGIN CONTEXT -------------------------------------------------
		context.set_line_width (1);
		Gdk.cairo_set_source_rgba (context, color_white);
		context.move_to (3, h-6);
		context.show_text("%.0f%%".printf(ratio * 100.00));
		context.stroke();
		//------ END CONTEXT ---------------------------------------------------

		return true;
	}

	// filesystem tab

	private void init_tab_fs(){

		if ((file_item != null) && ((file_item is FileItemArchive) || (file_item is FileItemCloud) || file_is_remote)){ return; }

		log_debug("PropertiesWindow: init_tab_fs()");
		
		var hbox = new Gtk.Box(Orientation.VERTICAL, 12);
		hbox.margin = 12;
		stack.add_titled (hbox, _("Filesystem"), _("Filesystem"));

		// get device for file_item ---------------------------
		
		if ((device == null) && (file_item != null)){
			
			device = Device.get_device_by_path(dir_item.file_path);
			
			if (device != null){
				device = Device.get_device_by_name(device.device);
			}
			else{
				log_error("device is NULL: Device.get_device_by_path(%s)".printf(dir_item.file_path));
			}
		}

		// create ui ---------------------------------------------

		var vbox = new Gtk.Box(Orientation.VERTICAL, 6);
		hbox.add(vbox);

		group_label = new Gtk.SizeGroup(Gtk.SizeGroupMode.HORIZONTAL);
		group1_value = new Gtk.SizeGroup(Gtk.SizeGroupMode.HORIZONTAL);

		if (device != null){

			add_property(vbox, _("Device"), device.device);

			if (device.mapped_name.length > 0){
				add_property(vbox, _("Mapped"), "/dev/mapper/%s".printf(device.mapped_name));
			}

			add_property(vbox, _("UUID"), device.uuid);

			add_property(vbox, _("Label"), ((device.label.length > 0) ? device.label : _("(empty)")));

			add_property(vbox, _("PartLabel"), ((device.partlabel.length > 0) ? device.partlabel : _("(empty)")));

			add_property(vbox, _("Filesystem"), device.fstype);

			if (device.is_mounted){
				add_property(vbox, _("Mount"), device.mount_points[0].mount_point);
			}

			add_property(vbox, _("ReadOnly"), ((device.read_only ? "Yes" : "No")));

			var sep = new Gtk.Separator(Gtk.Orientation.HORIZONTAL);
			vbox.add(sep);
		}

		// create tooltip ---------------------------

		string txt = "%s (%'ld bytes)".printf(format_file_size(device.size_bytes), device.size_bytes);

		add_property(vbox, _("Size"), txt);

		txt = "%s (%'ld bytes) (%.0f%%)".printf(
			format_file_size(device.used_bytes),
			device.used_bytes,
			(device.used_bytes * 100.0) / device.size_bytes);

		add_property(vbox, _("Used"), txt);

		txt = "%s (%'ld bytes) (%.0f%%)".printf(
			format_file_size(device.free_bytes),
			device.free_bytes,
			(device.free_bytes * 100.0) / device.size_bytes);

		add_property(vbox, _("Available"), txt);

		var dummy = new Gtk.Label("");
		dummy.vexpand = true;
		vbox.add(dummy);

		// ratio bar ------------------------------------------
		
		var area = new Gtk.DrawingArea();
		area.set_size_request(-1, 30);
		area.hexpand = true;
		area.margin_top = 6;
		area.margin_left = 6;
		area.margin_right = 6;
		vbox.add(area);
		area_fs = area;

		area.draw.connect(area_fs_draw);
	}

	private bool area_fs_draw(Cairo.Context context) {

		if (device == null) { return true; }

		double used = (device.used_bytes * 1.0) / device.size_bytes;

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

		int line_width = 2;

		var area = area_fs;

		int w = area.get_allocated_width();
		int h = area.get_allocated_height();

		if (used >= 0.75){
			color_bar = color_red_300;
		}
		else if (used >= 0.50){
			color_bar = color_yellow_300;
		}
		else{
			color_bar = color_green_300;
		}

		int x_level = (int) (w * used);

		Gdk.cairo_set_source_rgba (context, color_black);
		context.set_line_width (line_width);
		context.rectangle(0, 0, w, h);
		context.stroke();

		Gdk.cairo_set_source_rgba (context, color_bar);
		context.set_line_width (line_width);
		context.rectangle(line_width, line_width, x_level, h - (line_width * 2));
		context.fill();

		return true;
	}

	// permissions tab

	private void init_tab_permissions(){

		if ((file_item == null) || (file_item.perms.length == 0)){ return; }
			
		if ((file_item is FileItemArchive) || (file_item is FileItemCloud)){ return; }
		
		log_debug("PropertiesWindow: init_tab_permissions()");
		
		var vbox = new Gtk.Box(Orientation.VERTICAL, 6);
		vbox.margin = 12;
		stack.add_titled (vbox, _("Permissions"), _("Permissions"));

		var label = new Gtk.Label("<b>%s:</b>".printf(_("Permissions")));
		label.set_use_markup(true);
		label.xalign = 0.0f;
		label.margin_bottom = 6;
		vbox.add(label);

		//grid
		var grid = new Gtk.Grid();
		grid.set_column_spacing(12);
		grid.set_row_spacing(6);
		grid.margin_left = 6;
		grid.margin_right = 12;
		vbox.add(grid);

		label = new Gtk.Label(_("User"));
		label.xalign =  1.0f;
		grid.attach(label, 0, 1, 1, 1);

		label = new Gtk.Label(_("Group"));
		label.xalign =  1.0f;
		grid.attach(label, 0, 2, 1, 1);

		label = new Gtk.Label(_("Others"));
		label.xalign =  1.0f;
		grid.attach(label, 0, 3, 1, 1);

		add_option(grid, 1, 1, "u", "r", _("Read"));

		add_option(grid, 2, 1, "u", "w", _("Write"));

		add_option(grid, 3, 1, "u", "x", _("Execute"));

		add_option(grid, 1, 2, "g", "r", _("Read"));

		add_option(grid, 2, 2, "g", "w", _("Write"));

		add_option(grid, 3, 2, "g", "x", _("Execute"));

		add_option(grid, 1, 3, "o", "r", _("Read"));

		add_option(grid, 2, 3, "o", "w", _("Write"));

		add_option(grid, 3, 3, "o", "x", _("Execute"));

		var sep = new Gtk.Separator(Gtk.Orientation.HORIZONTAL);
		grid.attach(sep, 0, 4, 5, 1);

		label = new Gtk.Label(_("Special bits"));
		label.xalign =  1.0f;
		grid.attach(label, 0, 5, 1, 1);

		add_option(grid, 1, 5, "u", "s", "SUID");

		add_option(grid, 2, 5, "g", "s", "SGID");

		add_option(grid, 3, 5, "", "t", "Sticky");
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
			if (!chmod(file_item.file_path, user + "+" + mode, this)){
				chk.toggled.disconnect(chk_permission_toggled);
				chk.active = !chk.active;
				chk.toggled.connect(chk_permission_toggled);
			}
		}
		else{
			if (!chmod(file_item.file_path, user + "-" + mode, this)){
				chk.toggled.disconnect(chk_permission_toggled);
				chk.active = !chk.active;
				chk.toggled.connect(chk_permission_toggled);
			}
		}

		file_item.query_file_info();
	}

	private void add_user_combo(Gtk.Box box){

		var hbox = new Gtk.Box(Orientation.HORIZONTAL, 6);
		box.add(hbox);

		var label = new Gtk.Label(_("Owner") + ":");
		label.xalign = 1.0f;
		//label.yalign = 0.0f;
		label.use_markup = true;
		label.label = "<b>%s</b>".printf(label.label);
		hbox.add(label);
		group_label.add_widget(label);

		// cmb_app
		var combo = new Gtk.ComboBox();
		hbox.add (combo);
		group2_value.add_widget(combo);

		cmb_user = combo;

		// render text
		var cell_text = new Gtk.CellRendererText();
		combo.pack_start(cell_text, false);
		combo.set_cell_data_func (cell_text, (cell_text, cell, model, iter) => {
			string user_login, user_name;
			model.get (iter, 0, out user_login, 1, out user_name, -1);
			(cell as Gtk.CellRendererText).text = user_login;// + ((user_name.length > 0) ? " - %s".printf(user_name) : "");
		});

		// add items
		var store = new Gtk.ListStore(2,
			typeof(string),
			typeof(string));

		TreeIter iter;
		int index = -1;
		int active = -1;
		foreach(var user in SystemUser.all_users_sorted){
			index++;
			store.append(out iter);
			store.set (iter, 0, user.name, 1, user.full_name, -1);
			if (user.name == file_item.owner_user){
				active = index;
			}
		}

		combo.set_model (store);

		combo.active = active;
		combo.set_data<int>("active", active);

		combo.changed.connect(combo_owner_changed);

		combo.sensitive = true; //(get_user_id_effective() == 0) && file_item.is_local;

		if (file_item.is_directory){// && (get_user_id_effective() == 0)){
			add_button_user_recursive(hbox);
		}
	}

	private void add_group_combo(Gtk.Box box){

		var hbox = new Gtk.Box(Orientation.HORIZONTAL, 6);
		box.add(hbox);

		var label = new Gtk.Label(_("Group") + ":");
		label.xalign = 1.0f;
		//label.yalign = 0.0f;
		label.use_markup = true;
		label.label = "<b>%s</b>".printf(label.label);
		hbox.add(label);
		group_label.add_widget(label);

		// cmb_app
		var combo = new Gtk.ComboBox();
		hbox.add (combo);
		group2_value.add_widget(combo);
		cmb_group = combo;

		// render text
		var cell_text = new Gtk.CellRendererText();
		combo.pack_start(cell_text, false);
		combo.set_cell_data_func (cell_text, (cell_text, cell, model, iter) => {
			string group_name;
			model.get (iter, 0, out group_name, -1);
			(cell as Gtk.CellRendererText).text = group_name;
		});

		// add items
		var store = new Gtk.ListStore(1,
			typeof(string));

		TreeIter iter;
		int index = -1;
		int active = -1;
		foreach(var group in SystemGroup.all_groups_sorted){
			index++;
			store.append(out iter);
			store.set (iter, 0, group.name, -1);
			if (group.name == file_item.owner_group){
				active = index;
			}
		}

		combo.set_model (store);

		combo.active = active;
		combo.set_data<int>("active", active);

		combo.changed.connect(combo_group_changed);

		combo.sensitive = true; //(get_user_id_effective() == 0) && file_item.is_local;

		if (file_item.is_directory){// && (get_user_id_effective() == 0)){
			add_button_group_recursive(hbox);
		}
	}

	private void combo_owner_changed(Gtk.ComboBox combo){

		combo.changed.disconnect(combo_owner_changed);

		gtk_set_busy(true, this);
		
		string user = gtk_combobox_get_value(combo, 0, file_item.owner_user);

		string cmd = cmd_chown(file_item.file_path, user, "", false);
		
		string msg = App.exec_admin(cmd);

		gtk_set_busy(false, this);

		if (msg.length > 0){
			
			gtk_messagebox(_("Operation Failed"), msg, this, true);

			combo.active = combo.get_data<int>("active");
		}

		combo.changed.connect(combo_owner_changed);

		file_item.query_file_info();
	}

	private void combo_group_changed(Gtk.ComboBox combo){

		combo.changed.disconnect(combo_group_changed);

		gtk_set_busy(true, this);
		
		string group = gtk_combobox_get_value(combo, 0, file_item.owner_group);

		string cmd = cmd_chown(file_item.file_path, "", group, false);
		
		string msg = App.exec_admin(cmd);

		gtk_set_busy(false, this);

		if (msg.length > 0){
			
			gtk_messagebox(_("Operation Failed"), msg, this, true);

			combo.active = combo.get_data<int>("active");
		}

		combo.changed.connect(combo_group_changed);

		file_item.query_file_info();
	}

	private void add_button_user_recursive(Gtk.Box hbox) {

		var button = new Gtk.Button();
		button.image = new Gtk.Image.from_pixbuf(IconManager.lookup("view-refresh", 16, false));
		button.set_tooltip_text(_("Apply recursively to directory contents"));
		hbox.add(button);

		//gtk_apply_css(new Gtk.Widget[] { button }, "padding-left: 1px; padding-right: 1px; padding-top: 0px; padding-bottom: 0px;");

		button.sensitive = file_item.is_directory && file_item.is_local;// && (get_user_id_effective() == 0) ;

		button.clicked.connect(btn_user_recursive);
	}

	private void btn_user_recursive(Gtk.Button button){

		button.clicked.disconnect(btn_user_recursive);

		gtk_set_busy(true, this);
			
		string user = gtk_combobox_get_value(cmb_user, 0, file_item.owner_user);

		string cmd = cmd_chown(file_item.file_path, user, "", true);
		
		string msg = App.exec_admin(cmd);

		gtk_set_busy(false, this);

		if (msg.length > 0){
			gtk_messagebox(_("Operation Failed"), msg, this, true);
		}

		button.clicked.connect(btn_user_recursive);
	}

	private void add_button_group_recursive(Gtk.Box hbox) {

		var button = new Gtk.Button();
		button.image = new Gtk.Image.from_pixbuf(IconManager.lookup("view-refresh", 16, false));
		button.set_tooltip_text(_("Apply recursively to directory contents"));
		hbox.add(button);

		//gtk_apply_css(new Gtk.Widget[] { button }, "padding-left: 1px; padding-right: 1px; padding-top: 0px; padding-bottom: 0px;");

		button.sensitive = file_item.is_directory && file_item.is_local;// && (get_user_id_effective() == 0) ;

		button.clicked.connect(btn_group_recursive);
	}

	private void btn_group_recursive(Gtk.Button button){

		button.clicked.disconnect(btn_group_recursive);

		gtk_set_busy(true, this);
			
		string group = gtk_combobox_get_value(cmb_group, 0, file_item.owner_group);

		string cmd = cmd_chown(file_item.file_path, "", group, true);
		
		string msg = App.exec_admin(cmd);

		gtk_set_busy(false, this);
		
		if (msg.length > 0){
			gtk_messagebox(_("Operation Failed"), msg, this, true);
		}

		button.clicked.connect(btn_group_recursive);
	}	

	/*private void add_info_bar(Gtk.Box box){

		var hbox = new Gtk.Box(Orientation.HORIZONTAL, 6);
		hbox.margin_top = 6;
		box.add(hbox);

		var label = new Gtk.Label(_("You don't have permission to change some permissions"));
		label.xalign = 0.5f;
		label.hexpand = true;
		label.margin = 6;
		hbox.add(label);

		string css = " background-color: #FFC107; ";
		gtk_apply_css(new Gtk.Widget[] { hbox }, css);

		css = " color: #000000; ";
		gtk_apply_css(new Gtk.Widget[] { label }, css);
	}*/

	// mediainfo tab

	private void init_tab_mediainfo(){

		if ((file_item == null) || file_item.is_directory || file_is_remote){ return; }

		if ((file_item is FileItemArchive) || (file_item is FileItemCloud)){ return; }

		log_debug("PropertiesWindow: init_tab_mediainfo()");
		
		mfile = new MediaFile(file_item.file_path);
		mfile.query_mediainfo_formatted();

		var vbox = new Gtk.Box(Orientation.VERTICAL, 12);
		stack.add_titled (vbox, _("MediaInfo"), _("MediaInfo"));

		//tv_info
		var treeview = new Gtk.TreeView();
		treeview.get_selection().mode = SelectionMode.SINGLE;
		treeview.headers_visible = false;
		treeview.expand = true;
		treeview.insert_column_with_attributes (-1, _("Key"), new CellRendererText(), "text", 0);
		treeview.insert_column_with_attributes (-1, _("Value"), new CellRendererText(), "text", 1);

		var scrolled = new Gtk.ScrolledWindow(null, null);
		scrolled.set_shadow_type (ShadowType.ETCHED_IN);
		scrolled.hscrollbar_policy = PolicyType.AUTOMATIC;
		scrolled.vscrollbar_policy = PolicyType.AUTOMATIC;
		scrolled.expand = true;
		scrolled.add(treeview);
		vbox.add(scrolled);

		var store = new Gtk.TreeStore (2, typeof (string), typeof (string));

		TreeIter? iter0 = null;
		TreeIter? iter1 = null;
		int index = -1;
		//store.append (out iter0, null);

		//log_debug(mfile.InfoTextFormatted);

		foreach (string line in mfile.InfoTextFormatted.split ("\n")){
			if (line.strip() == "") { continue; }

			index = line.index_of (":");

			if (index == -1){
				store.append (out iter0, null);
				store.set (iter0, 0, line.strip());
			}
			else{
				store.append (out iter1, iter0);
				store.set (iter1, 0, line[0:index-1].strip());
				store.set (iter1, 1, line[index+1:line.length].strip());
			}
		}
		treeview.set_model(store);
		treeview.expand_all();
	}

	// helpers

	private Gtk.Label add_property(Gtk.Box box, string property_name, string property_value){

		var hbox = new Gtk.Box(Orientation.HORIZONTAL, 6);
		box.add(hbox);

		var label = new Gtk.Label(property_name + ":");
		label.xalign = 1.0f;
		label.yalign = 0.0f; // align top if value is multi-line
		label.use_markup = true;
		label.label = "<b>%s</b>".printf(label.label);
		hbox.add(label);
		group_label.add_widget(label);

		// value
		label = new Gtk.Label(property_value);
		label.xalign = 0.0f;
		label.yalign = 0.0f;
		label.selectable = true;
		hbox.add(label);
		group1_value.add_widget(label);

		label.max_width_chars = 40;
		label.wrap = true;
		label.wrap_mode = Pango.WrapMode.WORD_CHAR;

		return label;
	}


	private Gtk.Entry add_property_accessed(Gtk.Box box, string property_name, string property_value){

		var hbox = new Gtk.Box(Orientation.HORIZONTAL, 6);
		box.add(hbox);

		var label = new Gtk.Label(property_name + ":");
		label.xalign = 1.0f;
		label.yalign = 0.5f;
		label.use_markup = true;
		label.label = "<b>%s</b>".printf(label.label);
		hbox.add(label);
		group_label.add_widget(label);

		// value
		var entry = new Gtk.Entry();
		entry.xalign = 0.0f;
		entry.set_size_request(200,-1);
		entry.editable = false;
		hbox.add(entry);
		group2_value.add_widget(entry);

		entry.text = property_value;
		
		if (file_item is FileItemCloud){ return entry; }

		if ((file_item is FileItemArchive) && (file_item.parent != null) && (file_item.parent is FileItemArchive)){ return entry; }

		if ((file_item.accessed == null) || !file_item.can_write){ return entry; }

		var img = new Gtk.Image.from_pixbuf(IconManager.lookup("preferences-desktop", 16, true, true));
		var ebox = new Gtk.EventBox();
		ebox.add(img);
		hbox.add(ebox);
		ebox.set_tooltip_text(_("Actions"));

		set_pointer_cursor_for_eventbox(ebox);

		ebox.button_press_event.connect((event)=>{
			menu_accessed = new TouchFileDateContextMenu(file_item, true, false, this, entry_accessed);
			menu_accessed.file_touched.connect(()=> { file_touched(); });
			return menu_accessed.show_menu(null);
		});

		return entry;
	}

	private Gtk.Entry add_property_modified(Gtk.Box box, string property_name, string property_value){

		var hbox = new Gtk.Box(Orientation.HORIZONTAL, 6);
		box.add(hbox);

		var label = new Gtk.Label(property_name + ":");
		label.xalign = 1.0f;
		label.yalign = 0.5f;
		label.use_markup = true;
		label.label = "<b>%s</b>".printf(label.label);
		hbox.add(label);
		group_label.add_widget(label);

		// value
		var entry = new Gtk.Entry();
		entry.xalign = 0.0f;
		entry.set_size_request(200,-1);
		entry.editable = false;
		hbox.add(entry);
		group2_value.add_widget(entry);

		entry.text = property_value;

		if (file_item is FileItemCloud){ return entry; }

		if ((file_item is FileItemArchive) && (file_item.parent != null) && (file_item.parent is FileItemArchive)){ return entry; }

		if ((file_item.accessed == null) || !file_item.can_write){ return entry; }

		var img = new Gtk.Image.from_pixbuf(IconManager.lookup("preferences-desktop", 16, true, true));
		var ebox = new Gtk.EventBox();
		ebox.add(img);
		hbox.add(ebox);
		ebox.set_tooltip_text(_("Actions"));

		set_pointer_cursor_for_eventbox(ebox);

		ebox.button_press_event.connect((event)=>{
			menu_modified = new TouchFileDateContextMenu(file_item, false, true, this, entry_modified);
			menu_modified.file_touched.connect(()=> { file_touched(); });
			return menu_modified.show_menu(null);
		});

		return entry;
	}

	private Gtk.Entry add_property_changed(Gtk.Box box, string property_name, string property_value){

		var hbox = new Gtk.Box(Orientation.HORIZONTAL, 6);
		box.add(hbox);

		var label = new Gtk.Label(property_name + ":");
		label.xalign = 1.0f;
		label.yalign = 0.5f;
		label.use_markup = true;
		label.label = "<b>%s</b>".printf(label.label);
		hbox.add(label);
		group_label.add_widget(label);

		// value
		var entry = new Gtk.Entry();
		entry.xalign = 0.0f;
		entry.set_size_request(200,-1);
		entry.editable = false;
		hbox.add(entry);
		group2_value.add_widget(entry);

		entry.text = property_value;

		return entry;
	}

	private Gtk.Entry add_property_created(Gtk.Box box, string property_name, string property_value){

		var hbox = new Gtk.Box(Orientation.HORIZONTAL, 6);
		box.add(hbox);

		var label = new Gtk.Label(property_name + ":");
		label.xalign = 1.0f;
		label.yalign = 0.5f;
		label.use_markup = true;
		label.label = "<b>%s</b>".printf(label.label);
		hbox.add(label);
		group_label.add_widget(label);

		// value
		var entry = new Gtk.Entry();
		entry.xalign = 0.0f;
		entry.set_size_request(200,-1);
		entry.editable = false;
		hbox.add(entry);
		group2_value.add_widget(entry);

		entry.text = property_value;

		return entry;
	}

	private void add_separator(Gtk.Box box){
		var separator = new Gtk.Separator(Gtk.Orientation.HORIZONTAL);
		separator.margin_left = 12;
		box.add(separator);
	}
}


