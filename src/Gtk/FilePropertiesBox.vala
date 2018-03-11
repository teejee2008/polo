/*
 * FilePropertiesBox.vala
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

public class FilePropertiesBox : Gtk.Box {

	private FileItem? file_item;
	private FileItem? dir_item;

	private Gtk.DrawingArea canvas;
	private MediaPlayer mpv;

	private bool file_is_remote {
		get { return (file_item != null) && file_item.file_path.has_prefix(App.rclone_mounts); }
	}

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

	private Gtk.Window window;

	private bool panel_mode = false;

	public FilePropertiesBox(Gtk.Window parent_window, bool _panel_mode){
		//base(Gtk.Orientation.VERTICAL, 6); // issue with vala
		Object(orientation: Gtk.Orientation.VERTICAL, spacing: 6); // work-around
		margin = 12;
		
		window = parent_window;

		panel_mode = _panel_mode;

		gtk_container_remove_children(this);
	}

	public Gtk.SizeGroup show_properties_for_file(FileItem _file_item){

		file_item = _file_item;
		dir_item = file_item.is_directory ? file_item : (new FileItem.from_path(file_item.file_location));

		file_item.query_file_info();
		
		init_ui_for_file();

		this.show_all();

		return group_label; // will be used by FilePropertiesPanel to align contents in FilePermissionsBox
	}

	private void init_ui_for_file(){

		gtk_container_remove_children(this);
		
		group_label = new Gtk.SizeGroup(Gtk.SizeGroupMode.HORIZONTAL);
		group1_value = new Gtk.SizeGroup(Gtk.SizeGroupMode.HORIZONTAL);
		group2_value = new Gtk.SizeGroup(Gtk.SizeGroupMode.HORIZONTAL);

		if (file_item == null){ return; }

		log_debug("FilePropertiesBox: init_ui_for_file()");

		var hbox = new Gtk.Box(Orientation.HORIZONTAL, 24);
		this.add(hbox);
		
		var vbox = new Gtk.Box(Orientation.VERTICAL, 6);
		hbox.add(vbox);

		if (panel_mode){
			init_preview_image(vbox); 
		}

		// name ----------------
		
		var txt = file_item.display_name;
		var label = add_property(vbox, _("Name"), txt);

		if (panel_mode){
			//label.set_size_request(-1, 100);
		}

		// location -----------
		
		txt = file_item.display_location;

		label = add_property(vbox, _("Location"), txt);

		if (panel_mode){
			//label.set_size_request(-1, 100);
		}

		// symlink target --------------------

		if (file_item.is_symlink){
			
			label = add_property(vbox, _("Target"), file_item.symlink_target);

			if (panel_mode){
				//label.set_size_request(-1, 100);
			}
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

		if (!panel_mode){
			init_preview_image(hbox); 
		}
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

		gtk_set_busy(true, window);
		
		string user = gtk_combobox_get_value(combo, 0, file_item.owner_user);

		string cmd = cmd_chown(file_item.file_path, user, "", false);
		
		string std_out, std_err;
		int status = App.exec_admin(cmd, out std_out, out std_err);

		gtk_set_busy(false, window);

		if (status != 0){
			
			gtk_messagebox(_("Failed to update Owner"), std_err, window, true);
			
			combo.active = combo.get_data<int>("active");
		}

		combo.changed.connect(combo_owner_changed);

		file_item.query_file_info();
	}

	private void combo_group_changed(Gtk.ComboBox combo){

		combo.changed.disconnect(combo_group_changed);

		gtk_set_busy(true, window);
		
		string group = gtk_combobox_get_value(combo, 0, file_item.owner_group);

		string cmd = cmd_chown(file_item.file_path, "", group, false);
		
		string std_out, std_err;
		int status = App.exec_admin(cmd, out std_out, out std_err);

		gtk_set_busy(false, window);

		if (status != 0){
			
			gtk_messagebox(_("Failed to update Group"), std_err, window, true);
			
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

		gtk_set_busy(true, window);
			
		string user = gtk_combobox_get_value(cmb_user, 0, file_item.owner_user);

		string cmd = cmd_chown(file_item.file_path, user, "", true);
		
		string std_out, std_err;
		int status = App.exec_admin(cmd, out std_out, out std_err);

		gtk_set_busy(false, window);

		if (status != 0){
			
			gtk_messagebox(_("Failed to update Owner"), std_err, window, true);
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

		gtk_set_busy(true, window);
			
		string group = gtk_combobox_get_value(cmb_group, 0, file_item.owner_group);

		string cmd = cmd_chown(file_item.file_path, "", group, true);
		
		string std_out, std_err;
		int status = App.exec_admin(cmd, out std_out, out std_err);

		gtk_set_busy(false, window);
		
		if (status != 0){
			
			gtk_messagebox(_("Failed to update Group"), std_err, window, true);
		}

		button.clicked.connect(btn_group_recursive);
	}

	// preview -----------------------------

	private void init_preview_image(Gtk.Box box){

		if (panel_mode){ return; } // preview will be displayed by parent panel

		var image = new Gtk.Image();
		
		if (file_item.is_image_gdk_supported){

			log_debug("is_image_gdk_supported()");
			
			try{
				var pix = new Gdk.Pixbuf.from_file_at_scale(file_item.file_path, 256, 256, true);
				pix = IconManager.resize_icon(pix, 256);
				image = new Gtk.Image.from_pixbuf(pix);
				box.add(image);
				return;
			}
			catch(Error e){
				//ignore
			}
		}

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

		box.add(image);
	}

	// helpers ---------------------------

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
		//group1_value.add_widget(label);

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
			menu_accessed = new TouchFileDateContextMenu(file_item, true, false, window, entry_accessed);
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
			menu_modified = new TouchFileDateContextMenu(file_item, false, true, window, entry_modified);
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


