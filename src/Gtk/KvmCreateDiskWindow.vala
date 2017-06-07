/*
 * KvmCreateDiskWindow.vala.vala
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

public class KvmCreateDiskWindow : Gtk.Window {
	
	private Gtk.Box vbox_main;
	private Gtk.SizeGroup size_label;
	private Gtk.SizeGroup size_combo;
	
	private string dest_path = "";
	private string base_file_path = "";
	private string derived_file_path = "";
	private Gtk.Window window;
	
	private Gtk.Entry txt_file_name;
	private Gtk.Entry txt_base_file;
	private Gtk.ComboBox cmb_extension;
	private Gtk.SpinButton spin_size;

	private FileViewPane _pane;

	private FileViewList? view{
		get{
			return (pane == null) ? null : pane.view;
		}
	}

	private FileViewPane? pane {
		get{
			if (_pane != null){
				return _pane;
			}
			else{
				return App.main_window.active_pane;
			}
		}
	}

	private LayoutPanel? panel {
		get{
			return (pane == null) ? null : pane.panel;
		}
	}
	
	public KvmCreateDiskWindow(Gtk.Window _window, string _dest_path, string _base_file_path, string _derived_file_path) {
		
		set_transient_for(_window);
		window_position = WindowPosition.CENTER_ON_PARENT;

		dest_path = _dest_path;
		base_file_path = _base_file_path;
		derived_file_path = _derived_file_path;
		window = _window;
		
		init_window();

		show_all();
	}

	private void init_window () {

		log_debug("KvmCreateDiskWindow: init_window()");

		title = _("Create Virtual Disk");

		set_modal(true);
		set_skip_taskbar_hint(true);
		set_skip_pager_hint(true);
		icon = get_app_icon(16);
		deletable = true;
		resizable = false;
		
		vbox_main = new Gtk.Box(Orientation.VERTICAL, 6);
		vbox_main.margin = 12;
		vbox_main.set_size_request(400,300);
		this.add(vbox_main);

		init_options();

		log_debug("KvmCreateDiskWindow: init_window(): exit");
	}

	private void init_options() {

		log_debug("KvmCreateDiskWindow: init_options()");
		
		size_label = new Gtk.SizeGroup(Gtk.SizeGroupMode.HORIZONTAL);
		size_combo = new Gtk.SizeGroup(Gtk.SizeGroupMode.HORIZONTAL);

		init_name();

		init_derived();
		
		init_base();

		init_size();

		init_messages();

		init_actions();

	}
	
	private void init_name() {

		log_debug("CreateArchiveWindow: init_name()");
		
		var hbox = new Gtk.Box(Orientation.HORIZONTAL, 6);
		vbox_main.add(hbox);

		var label = new Label (_("File Name"));
		label.xalign = 1.0f;
		hbox.add(label);
		
		size_label.add_widget(label);

		var hbox2 = new Gtk.Box(Orientation.HORIZONTAL, 6);
		hbox.add(hbox2);
		
		var txt = new Gtk.Entry();
		txt.hexpand = true;
		txt.set_size_request(200,-1);
		hbox2.add(txt);
		txt_file_name = txt;

		size_combo.add_widget(hbox2);

		if (base_file_path.length > 0){
			string title = file_get_title(base_file_path);
			txt.text = "%s-derived".printf(title);
		}
		else if (derived_file_path.length > 0){
			string title = file_get_title(derived_file_path);
			txt.text = "%s-merged".printf(title);
		}
		else{
			txt.text = "hda";
		}

		//txt.focus_out_event.connect((entry, event) => {
		//	txt_archive_title.select_region(0, 0);
		//	return false;
		//});

		//cmb_archive_ext
		var combo = new Gtk.ComboBox();
		hbox2.add(combo);
		cmb_extension = combo;
		
		var cell = new CellRendererText();
		combo.pack_start(cell, false);
		combo.set_attributes(cell, "text", 0);
		combo.sensitive = false;
		
		// add items ----------------
		
		int index = -1;
		var store = new Gtk.ListStore(2, typeof(string), typeof(string));
		combo.set_model(store);
		
		TreeIter iter;
		foreach(string ext in new string[]{ ".qcow2" }){
			index++;
			store.append(out iter);
			store.set (iter, 0, ext, 1, ext, -1);
			if (ext == App.kvm_format){
				combo.active = index;
			}
		}

		combo.changed.connect(() => {
			App.kvm_format = gtk_combobox_get_value(combo, 0, App.kvm_format);
		});
	}

	private void init_derived() {
		
		var hbox = new Gtk.Box(Orientation.HORIZONTAL, 6);
		vbox_main.add(hbox);
		
		var label = new Label (_("Derived File"));
		label.xalign = 1.0f;
		hbox.add(label);
		
		size_label.add_widget(label);

		var txt = new Gtk.Entry();
		txt.hexpand = true;
		txt.sensitive = false;
		txt.set_size_request(200,-1);
		hbox.add(txt);
		txt_base_file = txt;

		size_combo.add_widget(txt);

		if (derived_file_path.length == 0){
			hbox.set_no_show_all(true);
		}
		else{
			txt.text = file_basename(derived_file_path);
		}
	}

	private void init_base() {
		
		var hbox = new Gtk.Box(Orientation.HORIZONTAL, 6);
		vbox_main.add(hbox);
		
		var label = new Label (_("Base File"));
		label.xalign = 1.0f;
		hbox.add(label);
		
		size_label.add_widget(label);

		var txt = new Gtk.Entry();
		txt.hexpand = true;
		txt.sensitive = false;
		txt.set_size_request(200,-1);
		hbox.add(txt);
		txt_base_file = txt;

		size_combo.add_widget(txt);

		if (base_file_path.length == 0){
			hbox.set_no_show_all(true);
		}
		else{
			txt.text = file_basename(base_file_path);
		}
	}
	
	private void init_size() {
		
		var hbox = new Gtk.Box(Orientation.HORIZONTAL, 6);
		vbox_main.add(hbox);
		
		var label = new Gtk.Label(_("Size (GB)"));
		label.xalign = 1.0f;
		hbox.add(label);

		size_label.add_widget(label);
		
		var adj = new Gtk.Adjustment(20.0, 0.1, 2000000.0, 1.0, 10.0, 0); //value, lower, upper, step, page_step, size
		var spin = new Gtk.SpinButton (adj, 1, 1);
		spin.xalign = (float) 0.5;
		hbox.add(spin);
		spin_size = spin;

		//size_combo.add_widget(spin);

		if ((base_file_path.length > 0) || (derived_file_path.length > 0)){
			hbox.set_no_show_all(true);
		}
	}

	private void init_messages() {

		var label = new Gtk.Label("");
		label.xalign = 0.0f;
		label.margin_top = 24;
		label.wrap = true;
		label.max_width_chars = 60;
		label.wrap_mode = Pango.WrapMode.WORD_CHAR;
		vbox_main.add(label);

		string txt = "";

		if (derived_file_path.length > 0){
			txt += "▰ %s\n".printf(_("New disk will be created by merging contents of derived and base files"));
			txt += "▰ %s\n".printf(_("Derived and base files will remain unchanged and can be deleted if not required"));
		}
		else if (base_file_path.length > 0){
			txt += "▰ %s\n".printf(_("New derived disk will be created from base disk. Boot and use the derived disk to make changes to system instead of using base disk directly."));
			txt += "▰ %s\n".printf(_("Changes can be discarded by deleting the derived file, or finalized by merging it with base"));
			txt += "▰ %s\n".printf(_("Do not rename or modify the base file as it will corrupt the derived disk. Base file will be made read-only to prevent accidental modification."));
		}
		else{
			txt += "▰ %s\n".printf(_("A dynamically allocated disk will be created with specified size. File size will increase gradually as disk is modified."));
		}

		label.label = txt;
	}

	private void init_actions() {

		var label = new Gtk.Label("");
		label.vexpand = true;
		vbox_main.add(label);
		
		var box = new Gtk.ButtonBox(Orientation.HORIZONTAL);
		box.set_layout(Gtk.ButtonBoxStyle.CENTER);
		box.set_spacing(6);
		vbox_main.add(box);
		
		var button = new Gtk.Button.with_label(_("Cancel"));
		button.clicked.connect(btn_cancel_clicked);
		box.add(button);
		
		button = new Gtk.Button.with_label(_("Create"));
		button.clicked.connect(btn_ok_clicked);
		box.add(button);

		button.grab_focus();
	}

	// properties ------------------------------------------------------

	public string file_path {
		owned get {
			return path_combine(dest_path, file_name);
		}
	}

	public string file_title {
		owned get {
			return txt_file_name.text;
		}
		set {
			txt_file_name.text = value;
		}
	}

	public string file_name {
		owned get {
			return "%s%s".printf(file_title, file_extension);
		}
	}

	public string file_extension {
		owned get {
			return gtk_combobox_get_value(cmb_extension, 1, App.kvm_format);
		}
		set {
			gtk_combobox_set_value(cmb_extension, 1, value);
		}
	}

	public string format {
		owned get {
			return file_extension.replace(".","").strip().down();
		}
	}

	public double disk_size {
		get {
			return spin_size.get_value();
		}
		set {
			spin_size.set_value(value);
		}
	}


	// selections ---------------------------------------------------

	private void btn_ok_clicked(){

		log_debug("btn_ok_clicked()");
		
		if (derived_file_path.length == 0){
			create_disk();
		}
		else{
			rebase_derived_disk();
		}
		
		this.destroy();
	}

	private void btn_cancel_clicked(){
		
		log_debug("btn_cancel_clicked()");
		
		this.destroy();
	}

	private void create_disk(){

		var task = new KvmTask();
		task.create_disk(file_path, disk_size, base_file_path, this);
	}

	private void rebase_derived_disk(){
		
		var action = new ProgressPanelKvmTask(pane, FileActionType.KVM_DISK_MERGE);
		action.set_parameters(file_path, base_file_path, derived_file_path, disk_size);
		pane.file_operations.add(action);
		action.execute();

		/*
		gtk_set_busy(true, this);
		
		string std_out, std_err;
		exec_sync(cmd, out std_out, out std_err);

		gtk_set_busy(false, this);

		if (std_err.length > 0){
			gtk_messagebox(_("Finished with errors"), std_err, window, true);
		}
		else{
			if (base_file_path.length > 0){
				chmod(base_file_path, "a-w", window);
			}
		}*/
	}
}


