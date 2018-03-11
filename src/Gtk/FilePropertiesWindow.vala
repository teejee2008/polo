/*
 * FilePropertiesWindow.vala
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

public class FilePropertiesWindow : Gtk.Window {

	private FilePropertiesBox box_props;
	private FilePermissionsBox box_perms;
	
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

	private signal void file_touched();

	public FilePropertiesWindow.for_file(FileItem _file_item) {

		file_item = _file_item;
		dir_item = file_item.is_directory ? file_item : (new FileItem.from_path(file_item.file_location));

		file_item.query_file_info();
		
		init_window();
	}

	public FilePropertiesWindow.for_device(Device _device) {
		
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

	// properties tab --------------------------------------------------------

	private void init_tab_properties(){

		if (file_item == null){ return; }

		log_debug("FilePropertiesWindow: init_tab_properties()");
		
		box_props = new FilePropertiesBox(this, false);
		stack.add_titled (box_props, _("General"), _("General"));

		box_props.show_properties_for_file(file_item);
	} 
 
	// filesystem tab ------------------------------------------------------

	private void init_tab_fs(){

		if ((file_item != null) && ((file_item is FileItemArchive) || (file_item is FileItemCloud) || file_is_remote)){ return; }

		log_debug("FilePropertiesWindow: init_tab_fs()");
		
		var hbox = new Gtk.Box(Orientation.VERTICAL, 12);
		hbox.margin = 12;
		stack.add_titled (hbox, _("Filesystem"), _("Filesystem"));

		// create ui ---------------------------------------------

		var vbox = new Gtk.Box(Orientation.VERTICAL, 6);
		hbox.add(vbox);

		group_label = new Gtk.SizeGroup(Gtk.SizeGroupMode.HORIZONTAL);
		group1_value = new Gtk.SizeGroup(Gtk.SizeGroupMode.HORIZONTAL);

		// get device for file_item ---------------------------
		
		if (dir_item == null){
			add_property(vbox, _("Device"), _("Unknown"));
			return;
		}

		device = Device.get_device_by_path(dir_item.file_path);
		
		if (device != null){
			device = Device.get_device_by_name(device.device);
		}
		else{
			add_property(vbox, _("Device"), _("Unknown"));
			log_error("device is NULL: Device.get_device_by_path(%s)".printf(dir_item.file_path));
			return;
		}

		add_property(vbox, _("Device"), device.device);

		if (device.mapped_name.length > 0){
			add_property(vbox, _("Mapped"), "/dev/mapper/%s".printf(device.mapped_name));
		}

		add_property(vbox, _("UUID"), device.uuid);

		add_property(vbox, _("Label"), ((device.label.length > 0) ? device.label : _("(empty)")));

		add_property(vbox, _("PartLabel"), ((device.partlabel.length > 0) ? device.partlabel : _("(empty)")));

		add_property(vbox, _("FileSystem"), device.fstype);

		if (device.is_mounted){
			add_property(vbox, _("MountPath"), device.mount_points[0].mount_point);
		}

		add_property(vbox, _("ReadOnly"), ((device.read_only ? "Yes" : "No")));

		add_property(vbox, _("Removable"), ((device.removable ? "Yes" : "No")));

		var sep = new Gtk.Separator(Gtk.Orientation.HORIZONTAL);
		vbox.add(sep);

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

	// permissions tab --------------------------------------------------

	private void init_tab_permissions(){

		if ((file_item == null) || (file_item.perms.length == 0)){ return; }
			
		if ((file_item is FileItemArchive) || (file_item is FileItemCloud)){ return; }
		
		log_debug("FilePropertiesWindow: init_tab_permissions()");

		box_perms = new FilePermissionsBox(this, false);
		stack.add_titled(box_perms, _("Permissions"), _("Permissions"));
		
		box_perms.show_properties_for_file(file_item, null);
	}

	// mediainfo tab --------------------------------------------------------------

	private void init_tab_mediainfo(){

		if ((file_item == null) || file_item.is_directory || file_is_remote){ return; }

		if ((file_item is FileItemArchive) || (file_item is FileItemCloud)){ return; }

		log_debug("FilePropertiesWindow: init_tab_mediainfo()");
		
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

		var store = new Gtk.TreeStore(2, typeof(string), typeof(string));

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

	// helpers -----------------------------------------------

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
}


