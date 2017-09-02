/*
 * CreateArchiveWindow.vala
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

public class CreateArchiveWindow : Gtk.Dialog {
	
	private Gtk.Box vbox_main;

	//options tab - archive
	private Gtk.Entry txt_archive_title;
	private Gtk.ComboBox cmb_archive_ext;
	private Gtk.Entry txt_archive_location;

	private Gtk.SizeGroup size_label;
	private Gtk.SizeGroup size_combo;

	private Gtk.ComboBox cmb_format;
	private Gtk.ComboBox cmb_level;
	private Gtk.ComboBox cmb_method;
	private Gtk.ComboBox cmb_dict_size;
	private Gtk.ComboBox cmb_word_size;
	private Gtk.ComboBox cmb_block_size;
	private Gtk.SpinButton spin_passes;
	private Gtk.Button btn_level_advanced;
	
	private Gtk.Entry txt_password;
	//private Gtk.Entry txt_password_confirm;
	private Gtk.ComboBox cmb_encrypt_method;
	private Gtk.CheckButton chk_encrypt_header;
	private Gtk.SpinButton spin_split;
	
	private bool show_comp_advanced = false;
	private bool show_enc_advanced = false;
	private bool add_files_thread_is_running = false;
	private bool add_files_thread_cancelled = false;
	
	//option tab actions
	private Gtk.Button btn_commands;
	private Gtk.Button btn_compress;
	private Gtk.Button btn_cancel;

	private bool window_is_ready = false;
	//private uint tmr_init = 0;

	private ArchiveTask task;
	private FileItem archive;
	private Gee.ArrayList<FileItem> items = new Gee.ArrayList<FileItem>();
	private FileItem dest_directory = null;
	
	public CreateArchiveWindow(Window parent, Gee.ArrayList<FileItem> _items, FileItem _dest_directory) {
		
		set_transient_for(parent);
		window_position = WindowPosition.CENTER_ON_PARENT;

		this.delete_event.connect(on_delete_event);
		
		items = _items;
		dest_directory = _dest_directory;

		task = new ArchiveTask(this);
		task.action = ArchiveAction.CREATE;

		archive = new FileItem();
		//task.archive = archive;
		
		init_window();

		add_files();
	}

	private bool on_delete_event(Gdk.EventAny event){
		btn_cancel_clicked();
		return false; // close window
	}	
	
	private void init_window () {

		log_debug("CreateArchiveWindow: init_window()");
		
		//archive = new FileItem();
		
		//add_files();

		title = _("Compress");

		set_modal(true);
		set_skip_taskbar_hint(true);
		set_skip_pager_hint(true);
		icon = get_app_icon(16);
		deletable = true;
		resizable = false;
		
		// vbox_main
		var vbox_content = get_content_area();
		vbox_content.margin = 12;
		vbox_content.margin_right = 24;
		vbox_content.spacing = 6;
		//vbox_content.set_size_request(250,-1);

		vbox_main = new Gtk.Box(Orientation.VERTICAL, 6);
		vbox_main.margin_bottom = 48;
		vbox_content.add(vbox_main);

		init_options();

		//init_set_bold_font_for_buttons();

		show_all();

		show_comp_advanced = true;
		comp_advanced_toggle();

		show_enc_advanced = true;
		enc_advanced_toggle();

		//show_commands = true;
		//show_commands_toggle();

		if (!LOG_DEBUG){
			btn_commands.visible = false;
		}
		
		load_selections();

		set_default_archive_title_and_location();
		
		//init_command_area_update();

		window_is_ready = true;

		log_debug("CreateArchiveWindow: init_window(): exit");
	}

	private void init_options() {

		log_debug("CreateArchiveWindow: init_options()");
		
		size_label = new Gtk.SizeGroup(Gtk.SizeGroupMode.HORIZONTAL);
		size_combo = new Gtk.SizeGroup(Gtk.SizeGroupMode.HORIZONTAL);

		init_archive_name();
		init_archive_location();

		init_format();
		init_method();
		init_level();
		init_dict_size();
		init_word_size();
		init_block_size();
		init_passes();

		init_encryption();

		init_split();

		//init_command_area();
		
		init_action_area();

		//init_tooltip_messages();

		//init_info();
	}

	// add files ----------------------
	
	private void add_files(){

		log_debug("CreateArchiveWindow: add_files()");
		
		add_files_thread_cancelled = false;

		try {
			add_files_thread_is_running = true;
			Thread.create<void> (add_files_thread, true);
		} catch (ThreadError e) {
			add_files_thread_is_running = false;
			log_error (e.message);
		}

		/*dlg.pulse_start();
		dlg.update_status_line(true);
		
		while (task_is_running) {
			App.status_line = _("Building file list...") + " %'ld files (%s)".printf(
								archive.file_count_total,
								format_file_size(archive.size));
								
			dlg.update_message(App.status_line);
			dlg.sleep(100);
			gtk_do_events();
		}
		
		dlg.destroy();
		gtk_do_events();*/
	}

	private void add_files_thread() {

		foreach(var item in items){
			if (add_files_thread_cancelled) { break; }
			item.query_children(-1);
		}

		//archive.add_items_to_archive(items);

		archive.update_size_from_children();

		log_debug("archive.size=%s".printf(archive.file_size_formatted));
		
		add_files_thread_is_running = false;
		
		log_debug("CreateArchiveWindow: add_files(): finished");
	}


	// archive options -----------------------------------------------

	private void init_archive_name() {

		log_debug("CreateArchiveWindow: init_archive_name()");
		
		var hbox = new Gtk.Box(Orientation.HORIZONTAL, 6);
		vbox_main.add(hbox);

		// name
		var label = new Gtk.Label (_("Name"));
		label.xalign = 1.0f;
		hbox.add(label);
		
		size_label.add_widget(label);

		//txt_archive_title
		var txt = new Gtk.Entry();
		txt.hexpand = true;
		txt.set_size_request(200,-1);
		hbox.add(txt);
		txt_archive_title = txt;

		size_combo.add_widget(txt);
		
		//remove text highlight
		txt.focus_out_event.connect((entry, event) => {
			txt_archive_title.select_region(0, 0);
			return false;
		});

		//cmb_archive_ext
		var combo = new Gtk.ComboBox();
		hbox.add(combo);
		cmb_archive_ext = combo;
		
		var cell = new CellRendererText();
		combo.pack_start(cell, false);
		combo.set_attributes(cell, "text", 0);
	}

	private void archive_extension_populate() {

		log_debug("CreateArchiveWindow: archive_extension_populate()");
		
		TreeIter iter;
		var model = new Gtk.ListStore (2, typeof (string), typeof (string));

		int active = 0;

		switch (format) {
		case "7z":
			model.append (out iter);
			model.set (iter, 0, ".7z", 1, ".7z");
			break;
			
		case "tar_7z":
			model.append (out iter);
			model.set (iter, 0, ".tar.7z", 1, ".tar.7z");
			break;

		case "bz2":
			model.append (out iter);
			model.set (iter, 0, ".bz2", 1, ".bz2");
			break;
			
		case "tar_bz2":
			model.append (out iter);
			model.set (iter, 0, ".tbz", 1, ".tbz");

			model.append (out iter);
			model.set (iter, 0, ".tbz2", 1, ".tbz2");

			model.append (out iter);
			model.set (iter, 0, ".tb2", 1, ".tb2");

			model.append (out iter);
			model.set (iter, 0, ".tar.bz2", 1, ".tar.bz2");

			active = 3;
			break;
			
		case "gz":
			model.append (out iter);
			model.set (iter, 0, ".gz", 1, ".gz");
			break;

		case "tar_gz":
			model.append (out iter);
			model.set (iter, 0, ".tgz", 1, ".tgz");

			model.append (out iter);
			model.set (iter, 0, ".tar.gz", 1, ".tar.gz");

			active = 1;
			break;

		case "lzo":
			model.append (out iter);
			model.set (iter, 0, ".lzo", 1, ".lzo");
			break;

		case "tar_lzo":
			model.append (out iter);
			model.set (iter, 0, ".tlz", 1, ".tlz");

			model.append (out iter);
			model.set (iter, 0, ".tar.lzo", 1, ".tar.lzo");

			active = 1;
			break;
			
		case "xz":
			model.append (out iter);
			model.set (iter, 0, ".xz", 1, ".xz");
			break;
			
		case "tar_xz":
			model.append (out iter);
			model.set (iter, 0, ".txz", 1, ".txz");

			model.append (out iter);
			model.set (iter, 0, ".tar.xz", 1, ".tar.xz");

			active = 1;
			break;
			
		case "zip":
			model.append (out iter);
			model.set (iter, 0, ".zip", 1, ".zip");
			break;

		case "tar_zip":
			model.append (out iter);
			model.set (iter, 0, ".tar.zip", 1, ".tar.zip");
			break;

		case "tar":
			model.append (out iter);
			model.set (iter, 0, ".tar", 1, ".tar");
			break;
		}

		cmb_archive_ext.model = model;
		cmb_archive_ext.active = active;
	}

	private void init_archive_location() {

		log_debug("CreateArchiveWindow: init_archive_location()");
		
		var hbox = new Gtk.Box(Orientation.HORIZONTAL, 6);
		vbox_main.add(hbox);
		
		//lbl_location
		var label = new Gtk.Label (_("Location"));
		label.xalign = 1.0f;
		hbox.add(label);

		size_label.add_widget(label);
		
		//txt_archive_location
		var txt = new Gtk.Entry();
		txt.hexpand = true;
		txt.secondary_icon_stock = "folder-open";
		hbox.add(txt);
		txt_archive_location = txt;

		size_combo.add_widget(txt);
		
		//remove text highlight
		txt.focus_out_event.connect((entry, event) => {
			txt_archive_location.select_region(0, 0);
			return false;
		});

		txt.icon_release.connect((p0, p1) => {
			//chooser
			var chooser = new Gtk.FileChooserDialog(
			    _("Select Archive Location"),
			    this,
			    FileChooserAction.SELECT_FOLDER,
			    "_Cancel",
			    Gtk.ResponseType.CANCEL,
			    "_Open",
			    Gtk.ResponseType.ACCEPT
			);

			chooser.select_multiple = false;
			chooser.set_filename(archive_location);

			if (chooser.run() == Gtk.ResponseType.ACCEPT) {
				txt_archive_location.text = chooser.get_filename();
			}

			chooser.destroy();
		});
	}

	private void set_default_archive_title_and_location() {

		log_debug("CreateArchiveWindow: set_default_archive_title_and_location()");

		if (items.size == 1){
			txt_archive_title.text = items[0].file_name;
		}
		else{
			txt_archive_title.text = "archive";
		}
		
		if (dest_directory.can_write) {
			txt_archive_location.text = dest_directory.file_path;
		}
		else {
			txt_archive_location.text = App.user_home;
		}

		// set unique name so that existing file is not overwritten
		int count = 0;
		while (file_exists(archive_path)){
			txt_archive_title.text += " (%d)".printf(++count);
		}
	}

	/*private void set_default_input_files() {
		txt_input_files.text = "Selected %ld files, %ld dirs, %s".printf(archive.file_count_total, archive.dir_count_total, format_file_size(archive.size));
	}*/

	// compression options -------------------------------------------

	private void init_format() {

		log_debug("CreateArchiveWindow: init_format()");
		
		var hbox = new Gtk.Box(Orientation.HORIZONTAL, 6);
		vbox_main.add(hbox);
		
		// label
		var label = new Gtk.Label(_("Format"));
		label.xalign = 1.0f;
		hbox.add(label);

		size_label.add_widget(label);
		
		// cmb_format
		
		var combo = new Gtk.ComboBox();
		hbox.add(combo);
		cmb_format = combo;

		size_combo.add_widget(combo);
		
		var cell = new CellRendererText();
		combo.pack_start(cell, false);
		combo.set_attributes(cell, "text", 0);

		// render text
		combo.set_cell_data_func (cell, (cell_layout, cell, model, iter) => {
			string txt, fmt;
			bool sensitive;
			model.get (iter, 0, out txt, 1, out fmt, 2, out sensitive, -1);

			(cell as Gtk.CellRendererText).text = txt;
			(cell as Gtk.CellRendererText).sensitive = sensitive;
		});

		combo.changed.connect(format_changed);

		combo.notify["sensitive"].connect(()=>{
			label.sensitive = combo.sensitive;
		});

		combo.notify["visible"].connect(()=>{
			label.visible = combo.visible;
			hbox.visible = combo.visible;
		});
		
		format_populate();
	}

	private void format_populate() {
		TreeIter iter;
		var model = new Gtk.ListStore (3, typeof (string), typeof (string), typeof(bool));
		
		model.append (out iter);
		model.set (iter, 0, "7-Zip", 1, "7z", 2, allow_format("7z"));

		model.append (out iter);
		model.set (iter, 0, "BZip2", 1, "bz2", 2, allow_format("bz2"));

		model.append (out iter);
		model.set (iter, 0, "GZip", 1, "gz", 2, allow_format("gz"));

		model.append (out iter);
		model.set (iter, 0, "LZO", 1, "lzo", 2, allow_format("lzo"));
		
		model.append (out iter);
		model.set (iter, 0, "XZ", 1, "xz", 2, allow_format("xz"));

		model.append (out iter);
		model.set (iter, 0, "Zip", 1, "zip", 2, allow_format("zip"));

		//model.append (out iter);
		//model.set (iter, 0, "ZPAQ", 1, "zpaq", 2, allow_format("zpaq"));
		
		model.append (out iter);
		model.set (iter, 0, "TAR", 1, "tar", 2, allow_format("tar"));
		
		model.append (out iter);
		model.set (iter, 0, "TAR + 7-Zip", 1, "tar_7z", 2, allow_format("tar_7z"));

		model.append (out iter);
		model.set (iter, 0, "TAR + BZip2", 1, "tar_bz2", 2, allow_format("tar_bz2"));

		model.append (out iter);
		model.set (iter, 0, "TAR + GZip", 1, "tar_gz", 2, allow_format("tar_gz"));

		model.append (out iter);
		model.set (iter, 0, "TAR + LZOP", 1, "tar_lzo", 2, allow_format("tar_lzo"));
		
		model.append (out iter);
		model.set (iter, 0, "TAR + XZ", 1, "tar_xz", 2, allow_format("tar_xz"));

		model.append (out iter);
		model.set (iter, 0, "TAR + Zip", 1, "tar_zip", 2, allow_format("tar_zip"));

		//model.append (out iter);
		//model.set (iter, 0, "TAR + ZPAQ", 1, "tar_zpaq", 2, allow_format("tar_zpaq"));

		cmb_format.model = model;

		//don't select default format here
	}

	private void format_changed() {
		method_populate();
		encryption_populate();
		archive_extension_populate();
	}

	private bool allow_format(string fmt){
		bool is_single_file_format = false;
		foreach(var val in Main.formats_single_file){
			if (val == fmt){
				is_single_file_format = true;
				break;
			}
		}
		
		bool is_single_file = (archive.file_count_total == 1);

		if (is_single_file_format){
			return (is_single_file);
		}
		else{
			return true;
		}
	}


	private void init_method() {
		var hbox = new Gtk.Box(Orientation.HORIZONTAL, 6);
		vbox_main.add(hbox);
		
		// label
		var label = new Gtk.Label(_("Method"));
		label.xalign = 1.0f;
		hbox.add(label);

		size_label.add_widget(label);
		
		// cmb_method

		var combo = new Gtk.ComboBox();
		hbox.add(combo);
		cmb_method = combo;

		size_combo.add_widget(combo);
		
		var cell = new CellRendererText();
		combo.pack_start(cell, false);
		combo.set_attributes(cell, "text", 0);

		combo.changed.connect(method_changed);

		combo.notify["sensitive"].connect(()=>{
			label.sensitive = combo.sensitive;
		});

		combo.notify["visible"].connect(()=>{
			label.visible = combo.visible;
			hbox.visible = combo.visible;
		});
		
		//method_populate();
	}

	private void method_populate() {
		TreeIter iter;
		var model = new Gtk.ListStore (2, typeof (string), typeof (string));

		switch (format) {
		case "7z":
		case "tar_7z":
			model.append (out iter);
			model.set (iter, 0, _("Copy"), 1, "copy");

			model.append (out iter);
			model.set (iter, 0, "LZMA", 1, "lzma");

			model.append (out iter);
			model.set (iter, 0, "LZMA2", 1, "lzma2");

			model.append (out iter);
			model.set (iter, 0, "PPMd", 1, "ppmd");

			model.append (out iter);
			model.set (iter, 0, "BZip2", 1, "bzip2");

			model.append (out iter);
			model.set (iter, 0, "Deflate", 1, "deflate");
			break;

		case "bz2":
		case "tar_bz2":
			model.append (out iter);
			model.set (iter, 0, "BZip2", 1, "bzip2");
			break;

		case "gz":
		case "tar_gz":
			model.append (out iter);
			model.set (iter, 0, "Deflate", 1, "deflate");
			break;

		case "lzo":
		case "tar_lzo":
			model.append (out iter);
			model.set (iter, 0, "LZO", 1, "lzo");
			break;

		case "zpaq":
		case "tar_zpaq":
			model.append (out iter);
			model.set (iter, 0, "ZPAQ", 1, "zpaq");
			break;

		case "xz":
		case "tar_xz":
			model.append (out iter);
			model.set (iter, 0, "LZMA2", 1, "lzma2");
			break;

		case "zip":
		case "tar_zip":
			model.append (out iter);
			model.set (iter, 0, _("Copy"), 1, "copy");
			model.append (out iter);
			model.set (iter, 0, "Deflate", 1, "deflate");
			model.append (out iter);
			model.set (iter, 0, "Deflate64", 1, "deflate64");
			model.append (out iter);
			model.set (iter, 0, "BZip2", 1, "bzip2");
			model.append (out iter);
			model.set (iter, 0, "LZMA", 1, "lzma");
			model.append (out iter);
			model.set (iter, 0, "PPMd", 1, "ppmd");
			break;

		case "tar":
			model.append (out iter);
			model.set (iter, 0, _("Copy"), 1, "copy");
			break;
		}

		cmb_method.model = model;

		switch (format) {
		case "7z":
		case "tar_7z":
			method = "lzma";
			break;
		case "bz2":
		case "tar_bz2":
			method = "bzip2";
			break;
		case "gz":
		case "tar_gz":
		case "zip":
		case "tar_zip":
			method = "deflate";
			break;
		case "xz":
		case "tar_xz":
			method = "lzma2";
			break;
		case "tar":
			method = "copy";
			break;
		case "lzo":
		case "tar_lzo":
			method = "lzo";
			break;
		case "zpaq":
		case "tar_zpaq":
			method = "zpaq";
			break;
		}
	}

	private void method_changed() {
		cmb_method.sensitive = (((TreeModel) cmb_method.model).iter_n_children(null) > 1);

		level_populate();
	}


	private void init_level() {
		var hbox = new Gtk.Box(Orientation.HORIZONTAL, 6);
		vbox_main.add(hbox);
		
		// label
		var label = new Gtk.Label(_("Level"));
		label.xalign = 1.0f;
		hbox.add(label);

		size_label.add_widget(label);
		
		// cmb_level
		
		var combo = new Gtk.ComboBox();
		hbox.add(combo);
		cmb_level = combo;

		size_combo.add_widget(combo);
		
		var cell = new CellRendererText();
		combo.pack_start(cell, false);
		combo.set_attributes(cell, "text", 0);

		combo.changed.connect(level_changed);

		// button
		var button = new Gtk.Button.with_label("");
		button.always_show_image = true;
		button.image = IconManager.lookup_image("config", 18);
		button.set_tooltip_text (_("Advanced options"));
		hbox.add(button);
		btn_level_advanced = button;
		
		button.clicked.connect(comp_advanced_toggle);

		combo.notify["sensitive"].connect(()=>{
			label.sensitive = combo.sensitive;
			button.sensitive = combo.sensitive;
		});

		combo.notify["visible"].connect(()=>{
			label.visible = combo.visible;
			button.visible = combo.visible;
			hbox.visible = combo.visible;
		});
		
		//level_populate();
	}

	private void comp_advanced_toggle(){
		show_comp_advanced = !show_comp_advanced;

		dict_size_changed();
		word_size_changed();
		block_size_changed();
		passes_changed();
	}
	
	private void level_populate() {
		TreeIter iter;
		var model = new Gtk.ListStore (2, typeof (string), typeof (string));

		switch (method) {
		case "copy":
		case "lzma":
		case "lzma2":
			model.append (out iter);
			model.set (iter, 0, _("Store"), 1, "0");
			break;
		}

		switch (method) {
		case "bzip2":
		case "lzma":
		case "lzma2":
		case "lzo":
		case "ppmd":
		case "deflate":
		case "deflate64":
			model.append (out iter);
			model.set (iter, 0, _("Fastest"), 1, "1");

			model.append (out iter);
			model.set (iter, 0, _("Fast"), 1, "3");

			model.append (out iter);
			model.set (iter, 0, _("Normal"), 1, "5");

			model.append (out iter);
			model.set (iter, 0, _("Maximum"), 1, "7");

			model.append (out iter);
			model.set (iter, 0, _("Ultra"), 1, "9");
			break;
		case "zpaq":
			model.append (out iter);
			model.set (iter, 0, _("Store"), 1, "0");
			
			model.append (out iter);
			model.set (iter, 0, _("Fastest"), 1, "1");

			model.append (out iter);
			model.set (iter, 0, _("Fast"), 1, "2");

			model.append (out iter);
			model.set (iter, 0, _("Normal"), 1, "3");

			model.append (out iter);
			model.set (iter, 0, _("Maximum"), 1, "4");

			model.append (out iter);
			model.set (iter, 0, _("Ultra"), 1, "5");

			model.append (out iter);
			model.set (iter, 0, _("Insane"), 1, "6");
			break;
		}

		cmb_level.model = model;

		switch (method) {
		case "copy":
			level = "0";
			break;

		case "bzip2":
		case "lzma":
		case "lzma2":
		case "lzo":
		case "ppmd":
		case "deflate":
		case "deflate64":
			level = "5";
			break;

		case "zpaq":
			level = "1";
			break;
		}
	}

	private void level_changed() {
		cmb_level.sensitive = (((TreeModel) cmb_level.model).iter_n_children(null) > 1);

		dict_size_populate();
		word_size_populate();
		block_size_populate();
		passes_populate();

		btn_level_advanced.sensitive = (dict_size.length > 0)
			|| (word_size.length > 0) || (block_size.length > 0);

		/*
		dict_size = "100k";
		word_size = "";
		block_size = "8m";
		passes = "1";

		switch(method){
			case "copy":
			case "lzma":
			case "lzma2":
				switch(level){
					case "0": //copy
						dict_size = "";
						word_size = "";
						block_size = "";
						passes = "";
						break;

					case "1": //fastest
						dict_size = "64k";
						word_size = "32";
						block_size = "16m";
						passes = "";
						break;

					case "3": //fast
						dict_size = "1m";
						word_size = "32";
						block_size = "128m";
						passes = "";
						break;

					case "5": //normal
						dict_size = "16m";
						word_size = "32";
						block_size = "2g";
						passes = "";
						break;

					case "7": //maximum
						dict_size = "32m";
						word_size = "64";
						block_size = "4g";
						passes = "";
						break;

					case "9": //ultra
						dict_size = "64m";
						word_size = "64";
						block_size = "4g";
						passes = "";
						break;
				}
				break;

			case "ppmd":
				switch(level){
					case "1": //fastest
						dict_size = "4m";
						word_size = "4";
						block_size = "512m";
						passes = "";
						break;

					case "3": //fast
						dict_size = "4m";
						word_size = "4";
						block_size = "1g";
						passes = "";
						break;

					case "5": //normal
						dict_size = "16m";
						word_size = "6";
						block_size = "2g";
						passes = "";
						break;

					case "7": //maximum
						dict_size = "64m";
						word_size = "16";
						block_size = "2g";
						passes = "";
						break;

					case "9": //ultra
						dict_size = "192m";
						word_size = "32";
						block_size = "4g";
						passes = "";
						break;
				}
				break;

			case "bzip2":
				switch(level){
					case "1": //fastest
						dict_size = "100k";
						word_size = "";
						block_size = "8m";
						passes = "1";
						break;

					case "3": //fast
						dict_size = "500k";
						word_size = "";
						block_size = "32m";
						passes = "1";
						break;

					case "5": //normal
						dict_size = "900k";
						word_size = "";
						block_size = "64m";
						passes = "1";
						break;

					case "7": //maximum
						dict_size = "900k";
						word_size = "";
						block_size = "64m";
						passes = "2";
						break;

					case "9": //ultra
						dict_size = "900k";
						word_size = "";
						block_size = "64m";
						passes = "7";
						break;
				}
				break;

			case "deflate":
			case "deflate64":
				switch(level){
					case "1": //fastest
						word_size = "32";
						passes = "1";
						break;

					case "3": //fast
						word_size = "32";
						passes = "1";
						break;

					case "5": //normal
						word_size = "32";
						passes = "1";
						break;

					case "7": //maximum
						word_size = "64";
						passes = "3";
						break;

					case "9": //ultra
						word_size = "128";
						passes = "10";
						break;
				}
				break;
		}

		if ((method == "bzip2") && (format != "7z")){
			block_size = "";
		}

		string[] arr;

		arr = { "bzip2","deflate","deflate64" };
		if (!(method in arr)){
			passes = "";
		}

		arr = { "deflate","deflate64" };
		if (method in arr){
			dict_size = "";
			block_size = "";
		}
		* */
	}


	private void init_dict_size() {
		var hbox = new Gtk.Box(Orientation.HORIZONTAL, 6);
		vbox_main.add(hbox);
		
		// label
		var label = new Gtk.Label(_("Dictionary"));
		label.xalign = 1.0f;
		hbox.add(label);
	
		size_label.add_widget(label);
		
		// cmb_dict_size
		
		var combo = new Gtk.ComboBox();
		hbox.add(combo);
		cmb_dict_size = combo;

		size_combo.add_widget(combo);
		
		var cell = new CellRendererText();
		combo.pack_start(cell, false);
		combo.set_attributes(cell, "text", 0);

		combo.changed.connect(dict_size_changed);

		combo.notify["sensitive"].connect(()=>{
			label.sensitive = combo.sensitive;
		});

		combo.notify["visible"].connect(()=>{
			label.visible = combo.visible;
			hbox.visible = combo.visible;
		});
		
		//dict_size_populate();
	}

	private void dict_size_populate() {
		TreeIter iter;
		var model = new Gtk.ListStore (2, typeof (string), typeof (string));

		if ((level == "0") || (method == "copy") || (method == "deflate") || (method == "deflate64") || (method == "lzo") || (method == "zpaq")) {
			model.append (out iter);
			model.set (iter, 0, " --- ", 1, "");
		}
		else {
			switch (method) {
			case "lzma":
			case "lzma2":
				foreach(var val in new string[] { "64k", "1m", "2m", "3m", "4m", "6m", "8m",
				                                  "12m", "16m", "24m", "32m", "48m", "64m", "96m", "128m"
				                                }) {
					model.append (out iter);
					model.set (iter, 0, val.replace("k", " KB").replace("m", " MB"), 1, val);
				}
				break;

			case "ppmd":
				foreach(var val in new string[] { "64k", "1m", "2m", "3m", "4m", "6m", "8m",
				                                  "12m", "16m", "24m", "32m", "48m", "64m", "96m", "128m"
				                                }) {
					model.append (out iter);
					model.set (iter, 0, val.replace("k", " KB").replace("m", " MB"), 1, val);
				}
				break;

			case "bzip2":
				foreach(var val in new string[] { "100k", "500k", "900k" }) {
					model.append (out iter);
					model.set (iter, 0, val.replace("k", " KB").replace("m", " MB"), 1, val);
				}
				break;
			}
		}

		cmb_dict_size.model = model;

		switch (method) {
		case "copy":
		case "deflate":
		case "deflate64":
		case "lzo":
		case "zpaq":
			dict_size = "";
			break;

		case "lzma":
		case "lzma2":
			switch (level) {
			case "0": //copy
				dict_size = "";
				break;

			case "1": //fastest
				dict_size = "64k";
				break;

			case "3": //fast
				dict_size = "1m";
				break;

			case "5": //normal
				dict_size = "16m";
				break;

			case "7": //maximum
				dict_size = "32m";
				break;

			case "9": //ultra
				dict_size = "64m";
				break;
			}
			break;

		case "ppmd":
			switch (level) {
			case "1": //fastest
				dict_size = "4m";
				break;

			case "3": //fast
				dict_size = "4m";
				break;

			case "5": //normal
				dict_size = "16m";
				break;

			case "7": //maximum
				dict_size = "64m";
				break;

			case "9": //ultra
				dict_size = "192m";
				break;
			}
			break;

		case "bzip2":
			switch (level) {
			case "1": //fastest
				dict_size = "100k";
				break;

			case "3": //fast
				dict_size = "500k";
				break;

			case "5": //normal
				dict_size = "900k";
				break;

			case "7": //maximum
				dict_size = "900k";
				break;

			case "9": //ultra
				dict_size = "900k";
				break;
			}
			break;
		}
	}

	private void dict_size_changed() {
		cmb_dict_size.sensitive = (((TreeModel) cmb_dict_size.model).iter_n_children(null) > 1);
		cmb_dict_size.visible = (dict_size.length > 0) && show_comp_advanced;
	}


	private void init_word_size() {
		var hbox = new Gtk.Box(Orientation.HORIZONTAL, 6);
		vbox_main.add(hbox);
		
		// label
		var label = new Gtk.Label(_("Word Size"));
		label.xalign = 1.0f;
		hbox.add(label);

		size_label.add_widget(label);
		
		// cmb_word_size
		
		var combo = new Gtk.ComboBox();
		hbox.add(combo);
		cmb_word_size = combo;

		size_combo.add_widget(combo);
		
		var cell = new CellRendererText();
		combo.pack_start(cell, false);
		combo.set_attributes(cell, "text", 0);
		
		combo.changed.connect(word_size_changed);

		combo.notify["sensitive"].connect(()=>{
			label.sensitive = combo.sensitive;
		});

		combo.notify["visible"].connect(()=>{
			label.visible = combo.visible;
			hbox.visible = combo.visible;
		});
		
		//word_size_populate();
	}

	private void word_size_populate() {
		TreeIter iter;
		var model = new Gtk.ListStore (2, typeof (string), typeof (string));

		if ((level == "0") || (method == "copy") || (method == "bzip2") || (method == "lzo") || (method == "zpaq")) {
			model.append (out iter);
			model.set (iter, 0, " --- ", 1, "");
		}
		else {
			switch (method) {
			case "lzma":
			case "lzma2":
				foreach(var val in new string[] { "8", "12", "16", "24", "32", "48", "64", "96", "128", "192", "256", "273" }) {
					model.append (out iter);
					model.set (iter, 0, val, 1, val);
				}
				break;
			case "ppmd":
				for (int k = 2; k <= 32; k++) {
					model.append (out iter);
					model.set (iter, 0, k.to_string(), 1, k.to_string());
				}
				break;
			case "deflate":
			case "deflate64":
				foreach(var val in new string[] { "4", "8", "12", "16", "24", "32", "48", "64", "96", "128", "192", "256"}) {
					model.append (out iter);
					model.set (iter, 0, val, 1, val);
				}
				break;
			}
		}

		cmb_word_size.model = model;

		switch (method) {
		case "copy":
		case "bzip2":
		case "lzo":
		case "zpaq":
			word_size = "";
			break;

		case "lzma":
		case "lzma2":
			switch (level) {
			case "0": //copy
				word_size = "";
				break;

			case "1": //fastest
				word_size = "32";
				break;

			case "3": //fast
				word_size = "32";
				break;

			case "5": //normal
				word_size = "32";
				break;

			case "7": //maximum
				word_size = "64";
				break;

			case "9": //ultra
				word_size = "64";
				break;
			}
			break;

		case "ppmd":
			switch (level) {
			case "1": //fastest
				word_size = "4";
				break;

			case "3": //fast
				word_size = "4";
				break;

			case "5": //normal
				word_size = "6";
				break;

			case "7": //maximum
				word_size = "16";
				break;

			case "9": //ultra
				word_size = "32";
				break;
			}
			break;

		case "deflate":
		case "deflate64":
			switch (level) {
			case "1": //fastest
				word_size = "32";
				break;

			case "3": //fast
				word_size = "32";
				break;

			case "5": //normal
				word_size = "32";
				break;

			case "7": //maximum
				word_size = "64";
				break;

			case "9": //ultra
				word_size = "128";
				break;
			}
			break;
		}
	}

	private void word_size_changed() {
		cmb_word_size.sensitive = (((TreeModel) cmb_word_size.model).iter_n_children(null) > 1);
		cmb_word_size.visible = (word_size.length > 0) && show_comp_advanced;
	}


	private void init_block_size() {
		var hbox = new Gtk.Box(Orientation.HORIZONTAL, 6);
		vbox_main.add(hbox);
		
		// label
		var label = new Gtk.Label(_("Block Size"));
		label.xalign = 1.0f;
		hbox.add(label);

		size_label.add_widget(label);
		
		// cmb_block_size
		
		var combo = new Gtk.ComboBox();
		hbox.add(combo);
		cmb_block_size = combo;

		size_combo.add_widget(combo);
		
		var cell = new CellRendererText();
		combo.pack_start(cell, false);
		combo.set_attributes(cell, "text", 0);

		combo.changed.connect(block_size_changed);

		combo.notify["sensitive"].connect(()=>{
			label.sensitive = combo.sensitive;
		});

		combo.notify["visible"].connect(()=>{
			label.visible = combo.visible;
			hbox.visible = combo.visible;
		});
		
		//block_size_populate();
	}

	private void block_size_populate() {
		TreeIter iter;
		var model = new Gtk.ListStore (2, typeof (string), typeof (string));

		if ((format == "7z")||(format == "tar_7z")) {
			switch (method) {
			case "lzma":
			case "lzma2":
			case "ppmd":
			case "bzip2":
				foreach(var val in new string[] { "non-solid", "1m", "2m", "4m", "8m", "16m", "32m", "64m", "128m", "256m", "512m", "1g", "2g", "4g", "8g", "16g", "32g", "64g" }) {
					model.append (out iter);
					model.set (iter, 0, val.replace("k", " KB").replace("m", " MB").replace("g", " GB").replace("non-solid", "Non-Solid"), 1, val);
				}
				break;
			case "copy":
			case "deflate":
			case "deflate64":
				model.append (out iter);
				model.set (iter, 0, " --- ", 1, "");
				break;

			}
		}
		else {
			model.append (out iter);
			model.set (iter, 0, " --- ", 1, "");
		}

		cmb_block_size.model = model;

		Gee.HashMap<string, string> map;

		if ((format == "7z")||(format == "tar_7z")) {
			switch (method) {
			case "lzma":
			case "lzma2":
				map = new Gee.HashMap<string, string>();
				map["0"] = "";
				map["1"] = "16m";
				map["3"] = "128m";
				map["5"] = "2g";
				map["7"] = "4g";
				map["9"] = "4g";
				block_size = map[level];
				break;

			case "ppmd":
				map = new Gee.HashMap<string, string>();
				map["1"] = "512m";
				map["3"] = "1g";
				map["5"] = "2g";
				map["7"] = "2g";
				map["9"] = "4g";
				block_size = map[level];
				break;

			case "bzip2":
				map = new Gee.HashMap<string, string>();
				map["1"] = "8m";
				map["3"] = "32m";
				map["5"] = "64m";
				map["7"] = "64m";
				map["9"] = "64m";
				block_size = map[level];
				break;

			case "copy":
			case "deflate":
			case "deflate64":
				block_size = "";
				break;
			}
		}
		else {
			block_size = "";
		}
	}

	private void block_size_changed() {
		cmb_block_size.sensitive = (((TreeModel) cmb_block_size.model).iter_n_children(null) > 1);
		cmb_block_size.visible = (block_size.length > 0) && show_comp_advanced;
	}


	private void init_passes() {
		var hbox = new Gtk.Box(Orientation.HORIZONTAL, 6);
		vbox_main.add(hbox);
		
		// label
		var label = new Gtk.Label(_("Passes"));
		label.xalign = 1.0f;
		hbox.add(label);

		size_label.add_widget(label);
		
		// cmb_block_size

		var adj = new Gtk.Adjustment(1, 1, 10, 1, 1, 0); //value, lower, upper, step, page_step, size
		var spin = new Gtk.SpinButton (adj, 1, 0);
		spin.xalign = 0.5f;
		hbox.add(spin);
		spin_passes = spin;

		size_combo.add_widget(spin);
		
		spin.changed.connect(passes_changed);

		spin.notify["sensitive"].connect(()=>{
			label.sensitive = spin.sensitive;
		});

		spin.notify["visible"].connect(()=>{
			label.visible = spin.visible;
			hbox.visible = spin.visible;
		});
		
		//init_passes_populate();
	}

	private void passes_populate() {
		switch (method) {
		case "copy":
		case "lzma":
		case "lzma2":
		case "ppmd":
		case "lzo":
		case "zpaq":
			spin_passes.adjustment.configure(0, 0, 0, 1, 1, 0); //value, lower, upper, step, page_step, size
			passes = "0";
			break;

		case "bzip2":
			spin_passes.adjustment.configure(1, 1, 10, 1, 1, 0); //value, lower, upper, step, page_step, size
			switch (level) {
			case "1": //fastest
				passes = "1";
				break;

			case "3": //fast
				passes = "1";
				break;

			case "5": //normal
				passes = "1";
				break;

			case "7": //maximum
				passes = "2";
				break;

			case "9": //ultra
				passes = "7";
				break;
			}
			break;

		case "deflate":
		case "deflate64":
			spin_passes.adjustment.configure(1, 1, 15, 1, 1, 0); //value, lower, upper, step, page_step, size
			switch (level) {
			case "1": //fastest
				passes = "1";
				break;

			case "3": //fast
				passes = "1";
				break;

			case "5": //normal
				passes = "1";
				break;

			case "7": //maximum
				passes = "3";
				break;

			case "9": //ultra
				passes = "10";
				break;
			}
			break;
		}
	}

	private void passes_changed() {
		spin_passes.visible = (passes != "0") && show_comp_advanced;
	}

	// encryption options ---------------------------------------------

	private void init_encryption() {

		log_debug("CreateArchiveWindow: init_encryption()");
		
		//init_encrypt(ref row);
		init_password();
		//init_encrypt_keyfile();
		init_encrypt_method();
		init_encrypt_header();
		
		//cmb_encrypt.active = 0;
	}

	private void init_password() {

		log_debug("CreateArchiveWindow: init_password()");
		
		var hbox = new Gtk.Box(Orientation.HORIZONTAL, 6);
		vbox_main.add(hbox);
		
		//lbl_passes
		var label = new Gtk.Label(_("Encrypt"));
		label.xalign = 1.0f;
		hbox.add(label);

		size_label.add_widget(label);
		
		//txt_password
		var txt = new Gtk.Entry();
		txt.placeholder_text = _("Enter Password");
		//txt.hexpand = true;		
		txt.set_visibility(false);
		hbox.add(txt);
		txt_password = txt;
		
		size_combo.add_widget(txt);

		/*
		//txt_password_confirm
		txt_password_confirm = new Gtk.Entry();
		txt_password_confirm.placeholder_text = _("Confirm Password");
		txt_password_confirm.hexpand = true;		
		txt_password_confirm.set_visibility(false);
		//grid.attach(txt_password_confirm, 0, ++row, 2, 1);
		*/
		
		// icon left
		var img = IconManager.lookup_image("config",16);
		if (img != null){
			//txt_password.primary_icon_pixbuf = img.pixbuf;
		}
		//txt.set_icon_tooltip_text(EntryIconPosition.PRIMARY, _("Generate Random Password"));

		// icon right
		img = IconManager.lookup_image("lock",16);
		if (img != null){
			txt_password.secondary_icon_pixbuf = img.pixbuf;
		}
		txt.set_icon_tooltip_text(EntryIconPosition.SECONDARY, _("Show"));
		
		// icon click
		txt.icon_press.connect((pos, event) => {
			if (pos == Gtk.EntryIconPosition.PRIMARY) {
				txt_password.text = get_random_password();
				//txt_password_confirm.text = txt_password.text;

				if (txt_password.get_visibility() == false){
					password_visibility_toggle();
				}
			}
			else if (pos == Gtk.EntryIconPosition.SECONDARY) {
				password_visibility_toggle();
			}
		});

		// button
		var button = new Gtk.Button.with_label("");
		button.always_show_image = true;
		button.image = IconManager.lookup_image("config", 18);
		button.set_tooltip_text (_("Advanced options"));
		hbox.add(button);

		button.clicked.connect(enc_advanced_toggle);

		txt.notify["sensitive"].connect(()=>{
			label.sensitive = txt.sensitive;
			button.sensitive = txt.sensitive;
		});

		txt.notify["visible"].connect(()=>{
			label.visible = txt.visible;
			button.visible = txt.visible;
			hbox.visible = txt.visible;
		});

		
		/*
		//hbox_password_actions
		hbox_password_actions = new Gtk.Box(Orientation.HORIZONTAL, 6);
		hbox_password_actions.homogeneous = true;
		hbox_password_actions.margin_bottom = 12;
		//grid.attach(hbox_password_actions, 0, ++row, 2, 1);

		//btn_password_create
		btn_password_create = new Gtk.Button.with_label(_("Generate"));
		btn_password_create.set_tooltip_text (_("Generate random password"));
		hbox_password_actions.add(btn_password_create);

		btn_password_create.clicked.connect(() => {
			txt_password.text = App.get_random_password();
			txt_password_confirm.text = txt_password.text;

			if (txt_password.get_visibility() == false){
				password_visibility_toggle();
			}
		});

		//btn_password_copy
		btn_password_copy = new Gtk.Button.with_label(_("Copy"));
		btn_password_copy.set_tooltip_text (_("Copy to clipboard"));
		hbox_password_actions.add(btn_password_copy);
		
		btn_password_copy.clicked.connect(() => {
			Gdk.Display display = this.get_display ();
			Gtk.Clipboard clipboard = Gtk.Clipboard.get_for_display (display, Gdk.SELECTION_CLIPBOARD);
			clipboard.set_text (txt_password.text, -1);
		});
		* */
	}

	private void password_visibility_toggle(){
		txt_password.set_visibility(!txt_password.get_visibility());
		//txt_password_confirm.set_visibility(txt_password.get_visibility());

		if (txt_password.get_visibility()){
			txt_password.set_icon_tooltip_text(EntryIconPosition.SECONDARY, _("Hide"));
		}
		else{	
			txt_password.set_icon_tooltip_text(EntryIconPosition.SECONDARY, _("Show"));
		}
	}

	private void init_encrypt_method() {
		var hbox = new Gtk.Box(Orientation.HORIZONTAL, 6);
		vbox_main.add(hbox);
		
		// label
		var label = new Gtk.Label(_("Cipher"));
		label.xalign = 1.0f;
		hbox.add(label);

		size_label.add_widget(label);
		
		// cmb_encrypt_method
		var combo = new Gtk.ComboBox();
		hbox.add(combo);
		cmb_encrypt_method = combo;

		size_combo.add_widget(combo);
		
		var cell = new CellRendererText();
		combo.pack_start(cell, false);
		combo.set_attributes(cell, "text", 0);

		combo.notify["sensitive"].connect(()=>{
			label.sensitive = combo.sensitive;
		});

		combo.notify["visible"].connect(()=>{
			label.visible = combo.visible;
			hbox.visible = combo.visible;
		});

		combo.changed.connect(encrypt_method_changed);

		encrypt_method_populate();
	}

	private void init_encrypt_header() {
		
		var hbox = new Gtk.Box(Orientation.HORIZONTAL, 6);
		vbox_main.add(hbox);

		var label = new Gtk.Label("");
		label.xalign = 0.0f;
		hbox.add(label);

		size_label.add_widget(label);
		
		//chk_encrypt_header
		chk_encrypt_header = new Gtk.CheckButton.with_label(_("Encrypt file names"));
		chk_encrypt_header.set_tooltip_text(_("Encrypt file names"));
		chk_encrypt_header.active = false;
		hbox.add(chk_encrypt_header);

		chk_encrypt_header.notify["sensitive"].connect(()=>{
			label.sensitive = chk_encrypt_header.sensitive;
		});

		chk_encrypt_header.notify["visible"].connect(()=>{
			label.visible = chk_encrypt_header.visible;
			hbox.visible = chk_encrypt_header.visible;
		});
	}

	private void encrypt_header_changed() {
		chk_encrypt_header.visible = show_enc_advanced;
	}
	
	private void enc_advanced_toggle(){
		show_enc_advanced = !show_enc_advanced;

		encrypt_method_changed();
		encrypt_header_changed();
	}
	
	private void encryption_populate() {
		encrypt_method_populate();

		switch (format) {
		case "7z":
		case "tar_7z":
		case "bz2":
		case "tar_bz2":
		case "zip":
		case "tar_zip":
			txt_password.sensitive = true;
			cmb_encrypt_method.sensitive = true;
			chk_encrypt_header.sensitive = true;
			break;
		default:
			txt_password.sensitive = false;
			cmb_encrypt_method.sensitive = false;
			chk_encrypt_header.sensitive = false;
			//Only 7z, bzip2, zip support encryption
			break;
		}
	}
	
	private void encrypt_method_populate() {
		TreeIter iter;
		var model = new Gtk.ListStore (2, typeof (string), typeof (string));

		int active = 0;

		switch (format) {
		case "7z":
		case "tar_7z":
		case "bz2":
		case "tar_bz2":
			model.append (out iter);
			model.set (iter, 0, "AES256", 1, "AES256");
			break;
		case "zip":
		case "tar_zip":
			model.append (out iter);
			model.set (iter, 0, "ZipCrypto", 1, "ZipCrypto");
			model.append (out iter);
			model.set (iter, 0, "AES128", 1, "AES128");
			model.append (out iter);
			model.set (iter, 0, "AES192", 1, "AES192");
			model.append (out iter);
			model.set (iter, 0, "AES256", 1, "AES256");
			active = 0; //ZipCrypto
			break;
		default:
			//model.append (out iter);
			//model.set (iter, 0, " --- ", 1, "");
			//Only 7z, bzip2, zip support encryption
			break;
		}

		cmb_encrypt_method.model = model;
		cmb_encrypt_method.active = active;
	}

	private void encrypt_method_changed(){
		cmb_encrypt_method.sensitive = (((TreeModel) cmb_encrypt_method.model).iter_n_children(null) > 1);
		
		cmb_encrypt_method.visible = show_enc_advanced
			&& (((TreeModel) cmb_encrypt_method.model).iter_n_children(null) > 0);
	}

	// split -------------------------------
	
	private void init_split() {

		log_debug("CreateArchiveWindow: init_split()");
		
		var hbox = new Gtk.Box(Orientation.HORIZONTAL, 6);
		vbox_main.add(hbox);
		
		// label
		var label = new Gtk.Label(_("Split"));
		label.xalign = 1.0f;
		hbox.add(label);

		size_label.add_widget(label);
		
		// cmb_block_size

		var adj = new Gtk.Adjustment(0, 0, 100000, 1, 1, 0); //value, lower, upper, step, page_step, size
		var spin = new Gtk.SpinButton (adj, 1, 0);
		spin.xalign = 0.5f;
		hbox.add(spin);
		spin_split = spin;
		
		size_combo.add_widget(spin);

		var tt = _("Split archive into volumes of specified size (in MB)");
		label.set_tooltip_text(tt);
		spin.set_tooltip_text(tt);
		
		//spin.changed.connect(passes_changed);

		spin.notify["sensitive"].connect(()=>{
			label.sensitive = spin.sensitive;
		});

		spin.notify["visible"].connect(()=>{
			label.visible = spin.visible;
			hbox.visible = spin.visible;
		});
		
		//init_passes_populate();
	}

	// action buttons --------------------------------------------------

	private void init_tooltip_messages() {
		/*string tt_method = _("<b>Compression Method</b>\n\n<b>Store</b> - Store files without compression\n\n<b>LZMA</b> - Good compression and very fast decompression\n\n<b>LZMA2</b> - Modified version of LZMA with better compression ratio for partially-compressible data, and better multi-threading support\n\n<b>PPMd</b> - Very good compression for text files (better than LZMA)\n\n<b>Deflate</b> - Very fast compression and decompression");
		//lbl_method.set_tooltip_markup(tt_method);
		//cmb_method.set_tooltip_markup(tt_method);

		string tt_tar = _("Archive files with TAR before compression (recommended)\n\n§ TAR is a very versatile file format which can store file permissions, group information, symlinks, and other meta-data on Linux filesystems. This information will be lost if you compress directly to file formats such as 7-Zip which was designed for Windows.\n\n§ Formats such as GZip, BZip2 and XZ are designed to compress single files. TAR can merge multiple files and directories into a single TAR file which can then be compressed by GZip, BZip2 and XZ.");
		//chk_tar_before.set_tooltip_markup(tt_tar);

		string tt_encrypt_headers = _("Archive header will be also encrypted (if supported by format)");
		//chk_encrypt_header.set_tooltip_markup(tt_encrypt_headers);
		* */
	}

	private void init_action_area() {

		log_debug("CreateArchiveWindow: init_action_area()");
		
		// btn_commands // TODO: Remove before release

		/*if (LOG_DEBUG){
			btn_commands = (Gtk.Button) add_button(_("Commands"), Gtk.ResponseType.NONE);
			//btn_commands.set_tooltip_text (_("Commands"));
			
			btn_commands.enter_notify_event.connect((event) => {
				btn_commands.set_tooltip_text (get_commands());
				return false;
			});

			btn_commands.clicked.connect(show_commands_toggle);
		}*/

		// btn_cancel

		btn_cancel = (Gtk.Button) add_button(_("Cancel"), Gtk.ResponseType.CANCEL);
		//btn_cancel.set_tooltip_text (_("Cancel"));
		
		btn_cancel.clicked.connect(btn_cancel_clicked);
		
		// btn_compress

		btn_compress = (Gtk.Button) add_button(_("Compress"), Gtk.ResponseType.ACCEPT);
		//btn_compress.set_tooltip_text (_("Compress"));
		
		btn_compress.clicked.connect(btn_compress_clicked);
	}

	/*private void show_commands_toggle(){
		show_commands = !show_commands;
			
		sw_commands.visible = show_commands;
		txtview_commands.visible = show_commands;
		update_txtview_commands();
		
		if (show_commands){
			//vbox_main.set_size_request(vbox_main.get_allocated_width(),
			//vbox_main.get_allocated_height() + 100);
		}
		else{
			//vbox_main.set_size_request(vbox_main.get_allocated_width(),
			//vbox_main.get_allocated_height() - 100);
		}
	}
	
	private void init_command_area() {

		log_debug("CreateArchiveWindow: init_command_area()");
		
		//txtview_commands
		txtview_commands = new Gtk.TextView();
		TextBuffer buff = new TextBuffer(null);
		txtview_commands.buffer = buff;
		txtview_commands.editable = false;
		txtview_commands.buffer.text = "";
		//txtview_commands.set_size_request(-1, 100);
		txtview_commands.expand = true;
		txtview_commands.set_wrap_mode (Gtk.WrapMode.WORD_CHAR);
		//txtview_commands.visible = false;
		//txtview_commands.no_show_all = true;
		//txtview_commands.set_monospace(true);
		//txtview_commands.border_width = 1;

		//sw_commands
		sw_commands = new Gtk.ScrolledWindow (null, null);
		sw_commands.set_shadow_type (ShadowType.ETCHED_IN);
		sw_commands.hscrollbar_policy = PolicyType.NEVER;
		sw_commands.vscrollbar_policy = PolicyType.ALWAYS;
		sw_commands.set_size_request(-1, 100);
		//sw_commands.expand = true;

		sw_commands.add (txtview_commands);
		vbox_main.add(sw_commands);
	}

	private void init_command_area_update() {
		foreach(Gtk.Entry entry in new Gtk.Entry[] {txt_archive_title, txt_archive_location, txt_password}) {
			entry.changed.connect(() => {
				update_txtview_commands();
			});
		}

		foreach(Gtk.ComboBox cmb in new Gtk.ComboBox[] {
			cmb_format, cmb_method, cmb_level, cmb_dict_size, cmb_word_size, cmb_block_size, cmb_encrypt_method
		}) {

			cmb.changed.connect(() => {
				update_txtview_commands();
			});
		}

		foreach(Gtk.SpinButton spin in new Gtk.SpinButton[] { spin_passes, spin_split }) {

			spin.changed.connect(() => {
				update_txtview_commands();
			});
		}

		foreach(Gtk.CheckButton gtk_chk in new Gtk.CheckButton[] { chk_encrypt_header }) {
			gtk_chk.notify["active"].connect(() => {
				update_txtview_commands();
			});
		}
	}

	private void init_set_bold_font_for_buttons() {
		//set bold font for some buttons
		foreach(Button btn in new Button[] { btn_compress }) {
			foreach(Widget widget in btn.get_children()) {
				if (widget is Label) {
					Label lbl = (Label)widget;
					lbl.set_markup(lbl.label);
				}
			}
		}
	}*/

	//properties ------------------------------------------------------

	public string archive_path {
		owned get {
			return "%s/%s".printf(archive_location, archive_name);
		}
	}

	public string archive_location {
		owned get {
			return txt_archive_location.text;
		}
		set {
			txt_archive_location.text = value;
		}
	}

	public string archive_name {
		owned get {
			return "%s%s".printf(archive_title, archive_extension);
		}
	}

	public string archive_title {
		owned get {
			return txt_archive_title.text;
		}
		set {
			txt_archive_title.text = value;
		}
	}

	public string archive_extension {
		owned get {
			return gtk_combobox_get_value(cmb_archive_ext, 1, ".7z");
		}
		set {
			gtk_combobox_set_value(cmb_archive_ext, 1, value);
		}
	}

	public string format {
		owned get {
			return gtk_combobox_get_value(cmb_format, 1, task.format);
		}
		set{
			gtk_combobox_set_value(cmb_format, 1, value);
		}
	}

	public string level {
		owned get {
			return gtk_combobox_get_value(cmb_level, 1, task.level);
		}
		set {
			gtk_combobox_set_value(cmb_level, 1, value);
		}
	}

	public string method {
		owned get {
			return gtk_combobox_get_value(cmb_method, 1, task.method);
		}
		set {
			gtk_combobox_set_value(cmb_method, 1, value);
		}
	}

	public string dict_size {
		owned get {
			return gtk_combobox_get_value(cmb_dict_size, 1, task.dict_size);
		}
		set {
			gtk_combobox_set_value(cmb_dict_size, 1, value);
		}
	}

	public string word_size {
		owned get {
			return gtk_combobox_get_value(cmb_word_size, 1, task.word_size);
		}
		set {
			gtk_combobox_set_value(cmb_word_size, 1, value);
		}
	}

	public string block_size {
		owned get {
			return gtk_combobox_get_value(cmb_block_size, 1, task.block_size);
		}
		set {
			gtk_combobox_set_value(cmb_block_size, 1, value);
		}
	}

	public string passes {
		owned get {
			return spin_passes.get_value().to_string();
		}
		set {
			spin_passes.set_value(double.parse(value));
		}
	}

	public bool encrypt_archive {
		get {
			return (txt_password.text.length > 0);
			//return ((txt_password.text.length > 0) || (txt_password_confirm.text.length > 0));
		}
	}

	public bool encrypt_header {
		get {
			return chk_encrypt_header.active;
		}
		set {
			chk_encrypt_header.set_active((bool) value);
		}
	}

	public string encrypt_method {
		owned get {
			return gtk_combobox_get_value(cmb_encrypt_method, 1, task.encrypt_method);
		}
		set {
			gtk_combobox_set_value(cmb_encrypt_method, 1, value);
		}
	}

	public string password {
		owned get {
			return txt_password.text;
		}
		set {
			txt_password.text = value;
		}
	}

	public string split_mb {
		owned get {
			return spin_split.get_value().to_string();
		}
		set {
			spin_split.set_value(double.parse(value));
		}
	}

	/*public string password_confirm {
		owned get {
			return txt_password_confirm.text;
		}
		set {
			txt_password_confirm.text = value;
		}
	}*/

	public FileItem get_archive() {
		return archive;
	}

	public ArchiveTask get_task() {
		return task;
	}

	// selections ---------------------------------------------------

	private void save_selections() {

		log_debug("CreateArchiveWindow: save_selections()");
		
		task.format = format;
		task.method = method;
		task.level = level;
		task.dict_size = dict_size;
		task.word_size = word_size;
		task.block_size = block_size;
		task.passes = passes;

		task.encrypt_method = encrypt_method;
		task.encrypt_header = encrypt_header;
		task.password = password;

		task.split_mb = split_mb;
		
		archive.file_path = archive_path;

		App.save_archive_selections(task);

		log_debug("CreateArchiveWindow: save_selections(): exit");
	}

	private void load_selections() {

		log_debug("CreateArchiveWindow: load_selections()");

		App.load_archive_selections(task);
		
		format = task.format;
		method = task.method;
		level = task.level;
		dict_size = task.dict_size;
		word_size = task.word_size;
		block_size = task.block_size;
		passes = task.passes;

		encrypt_method = task.encrypt_method;
		encrypt_header = task.encrypt_header;
		
		split_mb = task.split_mb;

		log_debug("CreateArchiveWindow: load_selections(): exit");
	}
	
	private void btn_compress_clicked(){

		log_debug("btn_compress_clicked()");
		
		btn_compress.sensitive = false;
		
		save_selections();

		if (add_files_thread_is_running){
			
			log_msg("waiting for thread to exit: query_children()");
			
			try {
				Thread.create<void> (wait_for_add_files_thread, true);
			}
			catch (ThreadError e) {
				log_error (e.message);
			}
		}
		else{
			this.close();
		}
	}

	private void wait_for_add_files_thread(){
		
		gtk_set_busy(true, this);

		while (add_files_thread_is_running){
			sleep(100);
			gtk_do_events();
		}
		gtk_set_busy(false, this);

		this.close();
	}

	private void btn_cancel_clicked(){

		log_debug("btn_cancel_clicked()");
	
		if (add_files_thread_is_running){
			log_msg("cancelling thread: query_children()");
			foreach(var item in items){
				item.query_children_aborted = true;
			}
		}

		log_msg("thread was cancelled");
		
		this.close();
	}

	//actions ----------------------------------------------------

	/*private string get_commands() {
		log_debug("CreateArchiveWindow: get_commands()");
		save_selections();
		return task.get_commands_compress();
	}

	private void update_txtview_commands() {
		log_debug("CreateArchiveWindow: update_txtview_commands()");
		if (window_is_ready){
			txtview_commands.buffer.text = get_commands();
		}
	}*/
}


