/*
 * ChecksumBox.vala
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

public class ChecksumBox : Gtk.Box {

	public Gtk.TreeView treeview;
	private Gtk.ScrolledWindow scrolled_treeview;
	
	private Gtk.ListStore store;
	private Gtk.TreeModelFilter filter;

	// columns
	public Gtk.TreeViewColumn col_name;
	public Gtk.TreeViewColumn col_status;
	public Gtk.TreeViewColumn col_checksum_compare;
	public Gtk.TreeViewColumn col_checksum;
	
	public Gee.ArrayList<FileItem> items;
	public Gee.ArrayList<FileItem> source_items;
	public string basepath = "";
	
	public ChecksumType checksum_type;

	private Gtk.ComboBox cmb_filter;
	private bool filter_active = false;

	public FileItem? hash_file;
	
	public bool verify_mode {
		get { return (hash_file != null); }
	}

	private bool enumerate_running = false;
	private bool enumerate_cancelled = false;

	private bool generate_running = false;
	private bool generate_cancelled = false;

	private bool save_running = false;
	private bool save_cancelled = false;

	private int64 count_ok = 0;
	private int64 count_changed = 0;
	private int64 count_missing = 0;
	private int64 count_symlink = 0;
	private int64 count_error = 0;
	private int64 count_unknown = 0;

	// parents
	public FileViewTab tab;
	public LayoutPanel panel;
	public MainWindow window;

	public Gtk.Frame frame_progress;
	public Gtk.Label lbl_status;
	public Gtk.Label lbl_stats;
	public Gtk.ProgressBar progressbar;

	public Gtk.Frame frame_results;
	public Gtk.Label lbl_results;

	public Gtk.Frame frame_verify;
	public Gtk.Label lbl_verify;

	private double completed_count = 0.0;
	private string current_file_name = "";

	//temp
	private Gdk.Pixbuf icon_ok;
	private Gdk.Pixbuf icon_changed;
	private Gdk.Pixbuf icon_missing;
	private Gdk.Pixbuf icon_symlink;
	private Gdk.Pixbuf icon_error;
	private Gdk.Pixbuf icon_unknown;
	
	// contructor ------------------

	public ChecksumBox(FileViewTab parent_tab){
		//base(Gtk.Orientation.VERTICAL, 6); // issue with vala
		Object(orientation: Gtk.Orientation.VERTICAL, spacing: 0); // work-around

		margin = 0;

		log_debug("ChecksumBox: ChecksumBox()");

		tab = parent_tab;
		panel = tab.panel;
		window = App.main_window;

		icon_ok = IconManager.lookup("item-green", 16);
		icon_changed = IconManager.lookup("item-red", 16);
		icon_missing = IconManager.lookup("item-gray", 16);
		icon_symlink = IconManager.lookup("item-gray", 16);
		icon_error = IconManager.lookup("item-gray", 16);
		icon_unknown = IconManager.lookup("item-gray", 16);

		init_ui();

		log_debug("ChecksumBox: ChecksumBox(): exit");
	}

	private void init_ui(){

		init_treeview();

		init_progress_panel();

		init_results_panel();

		init_verify_panel();

		gtk_hide(frame_progress);
		gtk_hide(frame_results);
		gtk_hide(frame_verify);
	}

	// progress panel ------------------------------
	
	private void init_progress_panel(){

		var frame = new Gtk.Frame(null);
		frame.margin = 3;
		add(frame);
		frame_progress = frame;
		
		var contents = new Gtk.Box(Orientation.VERTICAL, 6);
		contents.margin = 6;
		frame.add(contents);
		
		var hbox_outer = new Gtk.Box(Orientation.HORIZONTAL, 6);
		contents.add(hbox_outer);

		var vbox_outer = new Gtk.Box(Orientation.VERTICAL, 6);
		hbox_outer.add(vbox_outer);

		var hbox = new Gtk.Box(Orientation.HORIZONTAL, 6);
		vbox_outer.add(hbox);

		// spinner --------------------

		var spinner = new Gtk.Spinner();
		spinner.start();
		hbox.add(spinner);

		// status message ------------------

		var label = new Gtk.Label("");
		label.xalign = 0.0f;
		label.ellipsize = Pango.EllipsizeMode.END;
		label.max_width_chars = 100;
		hbox.add(label);
		lbl_status = label;

		// progressbar ----------------------------

		progressbar = new Gtk.ProgressBar();
		progressbar.fraction = 0;
		progressbar.hexpand = true;
		//progressbar.set_size_request(-1, 25);
		//progressbar.pulse_step = 0.1;
		vbox_outer.add(progressbar);

		// stats label ----------------

		label = new Gtk.Label("...");
		//label.set_use_markup(true);
		label.xalign = 0.0f;
		//label.margin_bottom = 12;
		//label.ellipsize = Pango.EllipsizeMode.END;
		//label.max_width_chars = 100;
		vbox_outer.add(label);
		lbl_stats = label;

		// cancel button

		var button = new Gtk.Button.with_label("");
		button.label = "";
		button.image = IconManager.lookup_image("process-stop", 32);
		button.always_show_image = true;
		button.set_tooltip_text(_("Cancel"));
		hbox_outer.add(button);

		button.clicked.connect(()=>{
			enumerate_cancelled = true;
			generate_cancelled = true;
			save_cancelled = true;
		});
	}

	private void init_results_panel(){

		var frame = new Gtk.Frame(null);
		add(frame);
		frame_results = frame;
		
		var contents = new Gtk.Box(Orientation.VERTICAL, 6);
		contents.margin = 6;
		frame.add(contents);
		
		var hbox = new Gtk.Box(Orientation.HORIZONTAL, 6);
		contents.add(hbox);

		// status message ------------------

		var icon = IconManager.lookup_image("info", 24);
		hbox.add(icon);

		var label = new Gtk.Label("Copy checksums by selecting files, or save to file");
		label.xalign = 0.0f;
		label.ellipsize = Pango.EllipsizeMode.END;
		label.max_width_chars = 100;
		hbox.add(label);
		lbl_results = label;

		label = new Gtk.Label("");
		label.hexpand = true;
		hbox.add(label);
		
		// actions -------------------

		var button = new Gtk.Button.with_label(_("Save"));
		button.image = IconManager.lookup_image("document-save", 16);
		button.always_show_image = true;
		button.set_tooltip_text(_("Save"));
		hbox.add(button);

		button.clicked.connect(btn_save_generate_results);
	}

	private void init_verify_panel(){

		var frame = new Gtk.Frame(null);
		add(frame);
		frame_verify = frame;
		
		var contents = new Gtk.Box(Orientation.VERTICAL, 6);
		contents.margin = 6;
		frame.add(contents);
		
		var hbox = new Gtk.Box(Orientation.HORIZONTAL, 6);
		contents.add(hbox);

		// status message ------------------

		var icon = IconManager.lookup_image("info", 24);
		hbox.add(icon);

		var label = new Gtk.Label("");
		label.xalign = 0.0f;
		label.ellipsize = Pango.EllipsizeMode.END;
		label.max_width_chars = 100;
		hbox.add(label);
		lbl_verify = label;

		label = new Gtk.Label("");
		label.hexpand = true;
		hbox.add(label);

		// filter -------------------------------

		add_combo_filter(hbox);
		
		// actions -------------------

		var button = new Gtk.Button.with_label(_("Export CSV"));
		button.image = IconManager.lookup_image("document-save", 16);
		button.always_show_image = true;
		button.set_tooltip_text(_("Save"));
		hbox.add(button);

		button.clicked.connect(btn_export_verified_results);
	}

	private void add_combo_filter(Gtk.Box hbox){

		var combo = new Gtk.ComboBox();
		hbox.add(combo);
		cmb_filter = combo;

		var cell_pix = new Gtk.CellRendererPixbuf();
		cell_pix.xpad = 3;
		combo.pack_start(cell_pix, false);

		var cell_text = new Gtk.CellRendererText();
		combo.pack_start(cell_text, false);

		combo.set_cell_data_func (cell_pix, (cell_pix, cell, model, iter) => {

			Gdk.Pixbuf pixbuf;
			model.get(iter, 1, out pixbuf, -1);

			var pixcell = cell as Gtk.CellRendererPixbuf;
			pixcell.pixbuf = pixbuf;
		});

		combo.set_cell_data_func (cell_text, (cell_text, cell, model, iter) => {
			
			string text;
			model.get (iter, 2, out text, -1);

			var txtcell = cell as Gtk.CellRendererText;
			txtcell.text = text;
		});

		refresh_cmb_filter();
		
		combo.changed.connect(refilter_list);
	}

	private void refresh_cmb_filter(){
		
		var cmb_store = new Gtk.ListStore(3, typeof(ChecksumCompareResult), typeof(Gdk.Pixbuf), typeof(string));

		TreeIter iter;
		cmb_store.append(out iter);
		cmb_store.set (iter, 0, ChecksumCompareResult.OK, -1);
		cmb_store.set (iter, 1, icon_ok, -1);
		cmb_store.set (iter, 2, "%s (%'lld)".printf(_("OK"), count_ok), -1);
		
		cmb_store.append(out iter);
		cmb_store.set (iter, 0, ChecksumCompareResult.CHANGED, -1);
		cmb_store.set (iter, 1, icon_changed, -1);
		cmb_store.set (iter, 2, "%s (%'lld)".printf(_("CHANGED"), count_changed), -1);

		cmb_store.append(out iter);
		cmb_store.set (iter, 0, ChecksumCompareResult.MISSING, -1);
		cmb_store.set (iter, 1, icon_missing, -1);
		cmb_store.set (iter, 2, "%s (%'lld)".printf(_("MISSING"), count_missing), -1);

		cmb_store.append(out iter);
		cmb_store.set (iter, 0, ChecksumCompareResult.SYMLINK, -1);
		cmb_store.set (iter, 1, icon_symlink, -1);
		cmb_store.set (iter, 2, "%s (%'lld)".printf(_("SYMLINK"), count_symlink), -1);

		cmb_store.append(out iter);
		cmb_store.set (iter, 0, ChecksumCompareResult.ERROR, -1);
		cmb_store.set (iter, 1, icon_error, -1);
		cmb_store.set (iter, 2, "%s (%'lld)".printf(_("ERROR"), count_error), -1);

		cmb_store.append(out iter);
		cmb_store.set (iter, 0, ChecksumCompareResult.UNKNOWN, -1);
		cmb_store.set (iter, 1, icon_unknown, -1);
		cmb_store.set (iter, 2, "%s (%'lld)".printf(_("UNKNOWN"), count_unknown), -1);

		cmb_filter.model = cmb_store;

		cmb_filter.active = 0;
	}
	
	// treeview -----------------------------------
	
	private void init_treeview() {

		// treeview
		treeview = new Gtk.TreeView();
		treeview.get_selection().mode = Gtk.SelectionMode.MULTIPLE;
		//treeview.headers_clickable = true;
		treeview.rubber_banding = true;
		treeview.has_tooltip = true;
		treeview.enable_search = true;
		treeview.set_rules_hint(true);
		//treeview.activate_on_single_click = true;

		// scrolled
		var scrolled = new Gtk.ScrolledWindow(null, null);
		scrolled.set_shadow_type (ShadowType.ETCHED_IN);
		scrolled.hscrollbar_policy = PolicyType.AUTOMATIC;
		scrolled.vscrollbar_policy = PolicyType.AUTOMATIC;
		scrolled.add (treeview);
		scrolled.expand = true;
		this.add(scrolled);
		scrolled_treeview = scrolled;

		treeview.set_tooltip_text(_("Click to copy checksum to clipboard"));

		treeview.get_selection().changed.connect(treeview_selection_changed_event);

		add_col_name();

		add_col_status();

		add_col_checksum();

		add_col_checksum_compare();

		add_col_spacer();
	}

	private void treeview_selection_changed_event(){

		Gdk.Display display = window.get_display();
		Gtk.Clipboard clipboard = Gtk.Clipboard.get_for_display(display, Gdk.SELECTION_CLIPBOARD);
		
		string txt = "";

		var selected = get_selected_items();

		bool append_paths = (selected.size > 1);
		
		foreach(var item in get_selected_items()){

			string checksum = "";
			
			switch(checksum_type){
			case ChecksumType.MD5:
				checksum = item.checksum_md5;
				break;
			case ChecksumType.SHA1:
				checksum = item.checksum_sha1;
				break;
			case ChecksumType.SHA256:
				checksum = item.checksum_sha256;
				break;
			case ChecksumType.SHA512:
				checksum = item.checksum_sha512;
				break;
			}

			if (txt.length > 0){ txt += "\n"; }

			if (append_paths){
				txt += "%s\t%s".printf(checksum, item.file_path[basepath.length : item.file_path.length]);
			}
			else{
				txt += "%s".printf(checksum);
			}
		}
		
		clipboard.set_text(txt, -1);
	}

	public Gee.ArrayList<FileItem> get_selected_items(){

		var selected_items = new Gee.ArrayList<FileItem>();

		Gtk.TreeModel model;
		var paths = treeview.get_selection().get_selected_rows(out model);

		foreach(var treepath in paths){
			TreeIter iter;
			if (model.get_iter(out iter, treepath)){
				FileItem item;
				model.get (iter, 0, out item, -1);
				selected_items.add(item);
			}
		}

		return selected_items;
	}

	public Gee.ArrayList<string> get_selected_file_paths(){
		var list = new Gee.ArrayList<string>();
		foreach(var item in get_selected_items()){
			list.add(item.file_path);
		}
		return list;
	}

	private void add_col_name() {

		// column
		var col = new Gtk.TreeViewColumn();
		col.title = _("File");
		col.clickable = true;
		col.resizable = true;
		col.expand = true;
		treeview.append_column(col);
		col_name = col;

		// cell icon
		var cell_pix = new Gtk.CellRendererPixbuf ();
		col.pack_start(cell_pix, false);

		// cell text
		var cell_text = new Gtk.CellRendererText ();
		cell_text.ellipsize = Pango.EllipsizeMode.END;
		col.pack_start (cell_text, true);

		// render icon
		col.set_cell_data_func (cell_pix, (cell_layout, cell, model, iter) => {

			var pixcell = cell as Gtk.CellRendererPixbuf;

			Gdk.Pixbuf pixbuf;
			model.get(iter, 1, out pixbuf, -1);

			pixcell.pixbuf = pixbuf;
			
			pixcell.ypad = App.listview_row_spacing;
		});

		// render text
		col.set_cell_data_func (cell_text, (cell_layout, cell, model, iter) => {

			var crt = cell as Gtk.CellRendererText;

			FileItem item;
			model.get (iter, 0, out item, -1);

			if (basepath.length > 0){
				crt.text = item.file_path[basepath.length : item.file_path.length];
			}
			else {
				crt.text = item.display_name;
			}
			
			crt.scale = App.listview_font_scale;
		});
	}

	private void add_col_status() {

		// column
		var col = new Gtk.TreeViewColumn();
		col.title = "";
		//col.clickable = true;
		//col.resizable = true;
		//col.expand = true;
		col.max_width = 30;
		treeview.append_column(col);
		col_status = col;

		// cell icon
		var cell_pix = new Gtk.CellRendererPixbuf ();
		cell_pix.xpad = 5;
		col.pack_start(cell_pix, false);

		// cell text
		//var cell_text = new Gtk.CellRendererText ();
		//cell_text.ellipsize = Pango.EllipsizeMode.END;
		//col.pack_start (cell_text, true);
		
		// render icon
		col.set_cell_data_func (cell_pix, (cell_layout, cell, model, iter) => {

			var pixcell = cell as Gtk.CellRendererPixbuf;

			Gdk.Pixbuf icon;
			model.get (iter, 2, out icon, -1);

			pixcell.pixbuf = icon;

			pixcell.ypad = App.listview_row_spacing;
		});

		// render text
		/*col.set_cell_data_func (cell_text, (cell_layout, cell, model, iter) => {

			var crt = cell as Gtk.CellRendererText;

			FileItem item;
			model.get (iter, 0, out item, -1);

			string checksum = "";
			
			switch(checksum_type){
			case ChecksumType.MD5:
				checksum = item.checksum_md5;
				break;
			case ChecksumType.SHA1:
				checksum = item.checksum_sha1;
				break;
			case ChecksumType.SHA256:
				checksum = item.checksum_sha256;
				break;
			case ChecksumType.SHA512:
				checksum = item.checksum_sha512;
				break;
			}

			if ((checksum.length > 0) && (item.checksum_compare.length > 0)){

				if (checksum == item.checksum_compare){
					crt.text = _("OK");
				}
				else {
					crt.text = _("Mismatch");
				}
			}
			else{
				crt.text = "";
			}

			//crt.text = item.display_name;

			//crt.scale = App.listview_font_scale;
		});*/
	}
	
	private void add_col_checksum() {

		// column
		var col = new Gtk.TreeViewColumn();
		col.title = _("Checksum");
		col.clickable = true;
		col.resizable = true;
		col.expand = true;
		treeview.append_column(col);
		col_checksum = col;

		// cell text
		var cell_text = new Gtk.CellRendererText ();
		cell_text.ellipsize = Pango.EllipsizeMode.END;
		col.pack_start (cell_text, true);

		// render text
		col.set_cell_data_func (cell_text, (cell_layout, cell, model, iter) => {

			var crt = cell as Gtk.CellRendererText;

			FileItem item;
			model.get (iter, 0, out item, -1);

			string checksum = "";
			
			switch(checksum_type){
			case ChecksumType.MD5:
				checksum = item.checksum_md5;
				break;
			case ChecksumType.SHA1:
				checksum = item.checksum_sha1;
				break;
			case ChecksumType.SHA256:
				checksum = item.checksum_sha256;
				break;
			case ChecksumType.SHA512:
				checksum = item.checksum_sha512;
				break;
			}

			if ((checksum == "SYMLINK") || (checksum == "MISSING")){
				checksum = "";
			}

			crt.text = checksum;
		});
	}

	private void add_col_checksum_compare() {

		// column
		var col = new Gtk.TreeViewColumn();
		col.title = _("Original Checksum");
		col.clickable = true;
		col.resizable = true;
		col.expand = true;
		treeview.append_column(col);
		col_checksum_compare = col;

		// cell text
		var cell_text = new Gtk.CellRendererText ();
		cell_text.ellipsize = Pango.EllipsizeMode.END;
		col.pack_start (cell_text, true);

		// render text
		col.set_cell_data_func (cell_text, (cell_layout, cell, model, iter) => {

			var crt = cell as Gtk.CellRendererText;

			FileItem item;
			model.get (iter, 0, out item, -1);

			string checksum = item.checksum_compare;
			
			if ((checksum == "SYMLINK") || (checksum == "MISSING")){
				checksum = "";
			}

			crt.text = checksum;
		});
	}

	private void add_col_spacer() {

		var col = new TreeViewColumn();
		col.title = "";
		col.clickable = false;
		col.resizable = false;
		//col.expand = true;
		col.reorderable = false;
		col.min_width = 20;
		treeview.append_column(col);

		// cell text
		var cell_text = new CellRendererText ();
		col.pack_start (cell_text, false);

		//render text
		col.set_cell_data_func (cell_text, (cell_layout, cell, model, iter) => {
			
			var crt = cell as Gtk.CellRendererText;
			crt.text = "";
		});
	}

	private void refilter_list(){
		filter.refilter();
	}

	private bool item_filter(Gtk.TreeModel model, Gtk.TreeIter iter) {
		
		FileItem item;
		model.get (iter, 0, out item, -1);

		TreeIter iter2;
		cmb_filter.get_active_iter(out iter2);
		
		var combo_model = (TreeModel) cmb_filter.model;
		ChecksumCompareResult val;
		combo_model.get(iter2, 0, out val);

		return (item.checksum_compare_result == val);
	}
	
	public void refresh(){

		log_debug("ChecksumBox: refresh()");

		treeview.model = null;
		
		store = new Gtk.ListStore(3,
			typeof(FileItem),
			typeof(Gdk.Pixbuf),
			typeof(Gdk.Pixbuf)
		);

		filter = new TreeModelFilter(store, null);
		
		//ChecksumCompareResult filter = get_cmb_filter_selected();

		foreach(var item in items){

			/*if (filter_active){
				if (item.checksum_compare_result != filter){
					continue;
				}
			}*/
			
			treeview_append(item);
		}

		//treeview.model = store;

		filter.set_visible_func(item_filter);
		
		treeview.set_model(filter);
		treeview.columns_autosize();
		
		log_debug("ChecksumBox: refresh(): end");
	}

	public ChecksumCompareResult get_cmb_filter_selected(){
		
		TreeIter iter2;
		cmb_filter.get_active_iter(out iter2);
		
		var combo_model = (Gtk.ListStore) cmb_filter.model;
		ChecksumCompareResult val;
		combo_model.get(iter2, 0, out val);

		return val;
	}

	public void treeview_append(FileItem item){

		var file_icon = item.get_image(22, false, false, false, null);

		TreeIter iter;
		store.append(out iter);
		store.set(iter, 0, item);
		store.set(iter, 1, file_icon);
		store.set(iter, 2, item.checksum_compare_icon);
	}

	// actions ----------------------------------------------------
	
	public void generate(Gee.ArrayList<FileItem> _source_items, ChecksumType type){

		log_debug("ChecksumBox: generate()");

		source_items = _source_items;

		basepath = source_items[0].file_location + "/";
		
		items = new Gee.ArrayList<FileItem>();

		checksum_type = type;

		col_checksum.title = "%s".printf(get_checksum_type_name());
		col_checksum_compare.visible = false;
		col_status.visible = false;

		tab.tab_name = get_checksum_type_name();

		lbl_status.label = "";
		progressbar.fraction = 0.0;
		lbl_stats.label = "";
		
		gtk_show(frame_progress);
		gtk_hide(frame_results);
		
		refresh(); // create empty store

		try {
			Thread.create<void> (enumerate_source_items_thread, true);
		}
		catch (Error e) {
			log_error("ChecksumBox: enumerate_source_items_thread()");
			log_error (e.message);
		}

		log_debug("ChecksumBox: generate(): end");
	}

	private void enumerate_source_items_thread(){

		log_debug("ChecksumBox: enumerate_source_items_thread()");
		
		lbl_status.label = _("Listing files...");
		progressbar.fraction = 0.0;
		lbl_stats.label = "";
		
		enumerate_running = true;
		enumerate_cancelled = false;

		Timeout.add(1000, () => {

			treeview.model = null;
			treeview.model = filter;

			string msg = "%s: %'d".printf(_("Found"), items.size);
			lbl_stats.label = msg;
			log_debug(msg);
			
			if ((progressbar.fraction + 0.01) < 1.0){
				progressbar.fraction += 0.01;
			}

			if (!enumerate_running){
				refresh();
			}

			if (enumerate_cancelled){
				gtk_hide(frame_progress);
			}

			gtk_do_events();
			
			return enumerate_running;
		});

		foreach(var item in source_items){
			add_item(item);
		}

		enumerate_running = false;

		if (enumerate_cancelled){ return; }

		log_debug("ChecksumBox: enumerate_source_items_thread(): end");
		
		generate_thread();
	}

	private void generate_thread(){

		log_debug("ChecksumBox: generate_thread()");
		
		generate_running = true;
		generate_cancelled = false;
		
		Timeout.add(1000, () => {

			log_debug("ChecksumBox: generate_thread(): timeout_start");
			
			treeview.model = null;
			treeview.model = filter;

			lbl_stats.label = "%'.0f of %'d: %s".printf(completed_count, items.size, current_file_name);
			progressbar.fraction = completed_count / items.size;

			if (generate_cancelled){
				gtk_hide(frame_progress);
			}

			log_debug("ChecksumBox: generate_thread(): timeout_end");
			
			return generate_running;
		});

		lbl_status.label = _("Generating checksums...");

		completed_count = 0;
		
		foreach(var item in items){
			
			if (generate_cancelled) { break; }
			
			completed_count++;
			current_file_name = item.file_name;
			
			item.generate_checksum(checksum_type);
		}
		
		generate_running = false;

		log_debug("ChecksumBox: generate_thread(): end");

		if (verify_mode){

			verify_thread();
			
			Timeout.add(100, () => {
				
				refresh();

				show_verification_summary();
				
				gtk_hide(frame_progress);
				gtk_show(frame_verify);

				if (count_changed == 0){

					if (count_missing == items.size){

						string ttl = _("Files Missing");
						
						string msg = "%s - %lld / %d".printf(
							_("Files referenced in checksum file are missing on disk"),
							count_missing, items.size);
							
						gtk_messagebox(ttl, msg, window, true);
					}
					else{

						string ttl = _("Verified Successfully");
						
						string msg = "%s - %lld / %d".printf(
							_("Files verified"), count_ok, items.size);

						if (count_missing > 0){
							
							msg += "\n\n%s - %lld / %d".printf(
								_("Files missing on disk"),
								count_missing, items.size);
						}
						
						gtk_messagebox(ttl, msg, window, false);
					}
				}
				else{

					string ttl = _("Verification Failed");

					string msg = "";
					
					if (count_ok > 0){

						msg += "%s - %lld / %d".printf(
							_("Files verified"), count_ok, items.size);
					}
					
					msg += "\n\n<b>%s - %lld / %d</b>".printf(
						_("Files changed"), count_changed, items.size);

					if (count_missing > 0){
						
						msg += "\n\n%s - %lld / %d".printf(
							_("Files missing on disk"),
							count_missing, items.size);
					}
					
					gtk_messagebox(ttl, msg, window, true);
				}

				return false;
			});
		}
		else{
			Timeout.add(100, () => {

				refresh();
				
				gtk_hide(frame_progress);
				gtk_show(frame_results);
				return false;
			});
		}
	}

	public void add_item(FileItem item){

		if (!item.is_directory){
			
			items.add(item);

			if (items.size < 100){
				Timeout.add(100, () => {
					//treeview_append(item);
					return false;
				});
			}
		}
		else {
			item.query_children(-1, false);
			
			foreach(var child in item.children.values){
				add_item(child);
			}
		}
	}

	public string get_checksum_type_name(){
		
		string txt = "";
		
		switch(checksum_type){
		case ChecksumType.MD5:
			txt = "MD5";
			break;
		case ChecksumType.SHA1:
			txt = "SHA1";
			break;
		case ChecksumType.SHA256:
			txt = "SHA2-256";
			break;
		case ChecksumType.SHA512:
			txt = "SHA2-512";
			break;
		}
		
		return txt;
	}

	public string get_checksum_extension(){
		
		string txt = "";
		
		switch(checksum_type){
		case ChecksumType.MD5:
			txt = ".md5";
			break;
		case ChecksumType.SHA1:
			txt = ".sha1";
			break;
		case ChecksumType.SHA256:
			txt = ".sha256";
			break;
		case ChecksumType.SHA512:
			txt = ".sha512";
			break;
		default:
			txt = ".hash";
			break;
		}
		
		return txt;
	}

	private void btn_save_generate_results(){

		var chooser = new Gtk.FileChooserDialog(
			_("Save As"),
			window,
			FileChooserAction.SAVE,
			"_Cancel",
			Gtk.ResponseType.CANCEL,
			"_Save",
			Gtk.ResponseType.ACCEPT
		);

		chooser.local_only = true;
 		chooser.set_modal(true);
		chooser.select_multiple = false;

		string ext = get_checksum_extension();
		string typename = get_checksum_type_name();

		chooser.set_current_folder(source_items[0].file_location);
		chooser.set_current_name(source_items[0].file_name + ext);

		var filter = create_file_filter("%s %s (*%s)".printf(typename, _("Checksum File"), ext), { "*%s".printf(ext) });
		chooser.add_filter(filter);
		
		if (chooser.run() != Gtk.ResponseType.ACCEPT) {
			chooser.destroy();
			return;
		}

		string fname = chooser.get_filename();

		if (!fname.has_suffix(ext)){
			fname += ext;
		}

		chooser.destroy();

		Timeout.add(100, ()=>{
			save_generate_results(fname);
			return false;
		});
	}

	private void save_generate_results(string file_path){

		log_debug("save_generate_results: %s".printf(file_path));
		
		save_running = true;
		save_cancelled = false;
		
		lbl_status.label = _("Saving checksums...");
		progressbar.fraction = 0;
		lbl_stats.label = "";
		completed_count = 0;
		
		gtk_hide(frame_results);
		gtk_show(frame_progress);
		gtk_do_events();
				
		Timeout.add(1000, () => {

			lbl_stats.label = "%'.0f of %'d: %s".printf(completed_count, items.size, current_file_name);
			progressbar.fraction = completed_count / items.size;
			gtk_do_events();
			
			if (save_cancelled || !save_running){
				gtk_hide(frame_progress);
				gtk_show(frame_results);
			}

			return save_running;
		});

		var builder = new StringBuilder ();

		foreach(var item in items){
				
			string checksum = "";
		
			switch(checksum_type){
			case ChecksumType.MD5:
				checksum = item.checksum_md5;
				break;
			case ChecksumType.SHA1:
				checksum = item.checksum_sha1;
				break;
			case ChecksumType.SHA256:
				checksum = item.checksum_sha256;
				break;
			case ChecksumType.SHA512:
				checksum = item.checksum_sha512;
				break;
			}

			if ((checksum == "SYMLINK") || (checksum == "MISSING")){
				checksum = "";
			}

			builder.append("%s\t%s\n".printf(checksum, item.file_path[basepath.length : item.file_path.length]));

			completed_count++;
			
			if ((completed_count % 2000) == 0){
				gtk_do_events();
			}
		}
			
		string msg = "%s: %s".printf(_("Saved"), file_path);
		log_msg(msg, true);
		lbl_results.label = msg;

		file_write(file_path, builder.str, window, null, true);

		save_running = false;
	}
	
	// verify -------------------------------

	public void verify(FileItem _hash_file){

		hash_file = _hash_file;
		
		log_debug("ChecksumBox: verify()");

		basepath = hash_file.file_location + "/";
		
		items = new Gee.ArrayList<FileItem>();

		if (!check_hash_file_type(hash_file.file_path)){
			string title = _("Unknown File Format");
			string msg = "%s:\n\n%s".printf(_("File has a non-standard format or is not a checksum file"), hash_file.file_path);
			gtk_messagebox(title, msg, window, true);
			return;
		}

		log_msg("%s: %s".printf(_("Checksum Type"), get_checksum_type_name()));

		col_checksum.title = "%s: %s".printf(_("Checksum"), get_checksum_type_name());//.replace("CHECKSUMTYPE_");
		col_checksum_compare.visible = true;
		col_status.visible = true;

		tab.tab_name = get_checksum_type_name();

		gtk_show(frame_progress);
		gtk_hide(frame_results);
		
		refresh(); // create empty store
		
		try {
			Thread.create<void> (enumerate_from_hash_file_thread, true);
		}
		catch (Error e) {
			log_error("ChecksumBox: enumerate_source_items_thread()");
			log_error (e.message);
		}

		log_debug("ChecksumBox: verify(): end");
	}

	private bool check_hash_file_type(string file_path){

		string txt = file_read(file_path);

		string line = txt.split("\n")[0];

		string hash = "";
		if (line.contains("\t")){
			hash = line.split("\t", 2)[0];
		}
		else if (line.contains("  ")){
			hash = line.split("  ", 2)[0];
		}
		else if (line.contains(" *")){
			hash = line.split(" *", 2)[0];
		}
		else{
			return false;
		}

		var match = regex_match("""[a-f0-9]{128}""", hash);
		if (match != null){
			checksum_type = ChecksumType.SHA512;
			return true;
		}

		match = regex_match("""[a-f0-9]{64}""", hash);
		if (match != null){
			checksum_type = ChecksumType.SHA256;
			return true;
		}
		
		match = regex_match("""[a-f0-9]{40}""", hash);
		if (match != null){
			checksum_type = ChecksumType.SHA1;
			return true;
		}
		
		match = regex_match("""[a-f0-9]{32}""", hash);
		if (match != null){
			checksum_type = ChecksumType.MD5;
			return true;
		}

		return false;
	}

	private void enumerate_from_hash_file_thread(){

		log_debug("ChecksumBox: enumerate_from_hash_file_thread()");
		
		enumerate_running = true;
		enumerate_cancelled = false;

		Timeout.add(1000, () => {

			treeview.model = null;
			treeview.model = filter;

			lbl_stats.label = "%s: %'d".printf(_("Found"), items.size);

			if ((progressbar.fraction + 0.01) < 1.0){
				progressbar.fraction += 0.01;
			}

			if (!enumerate_running){
				refresh();
			}

			if (enumerate_cancelled){
				gtk_hide(frame_progress);
			}
			
			return enumerate_running;
		});

		lbl_status.label = _("Listing files...");

		string txt = file_read(hash_file.file_path);

		string[] lines = txt.split("\n");
		
		foreach(string line in lines){

			string hash = "";
			string file_path = "";
			string[] arr;
			
			if (line.contains("\t")){
				arr = line.split("\t", 2);
				hash = arr[0];
				file_path = arr[1];
			}
			else if (line.contains("  ")){
				arr = line.split("  ", 2);
				hash = arr[0];
				file_path = arr[1];
			}
			else if (line.contains(" *")){
				arr = line.split(" *", 2);
				hash = arr[0];
				file_path = arr[1];
			}
			else{
				continue;
			}
		
			file_path = basepath + file_path;

			var item = new FileItem.from_path(file_path);
			items.add(item);

			item.checksum_compare = hash;
			
			if (items.size < 100){
				Timeout.add(100, () => {
					//treeview_append(item);
					return false;
				});
			}
		}

		log_msg("%s: %d".printf(_("Found"), items.size));

		enumerate_running = false;

		if (enumerate_cancelled){ return; }

		log_debug("ChecksumBox: enumerate_from_hash_file_thread(): end");
		
		generate_thread();
	}

	private void verify_thread(){

		count_ok = 0;
		count_changed = 0;
		count_missing = 0;
		count_symlink = 0;
		count_error = 0;
		count_unknown = 0;
		
		foreach(var item in items){
			
			string checksum = "";
				
			switch(checksum_type){
			case ChecksumType.MD5:
				checksum = item.checksum_md5;
				break;
			case ChecksumType.SHA1:
				checksum = item.checksum_sha1;
				break;
			case ChecksumType.SHA256:
				checksum = item.checksum_sha256;
				break;
			case ChecksumType.SHA512:
				checksum = item.checksum_sha512;
				break;
			}

			if ((checksum != null) && (checksum.length > 10) && (item.checksum_compare.length > 10)){
				// error message will be < 10 chars

				if (checksum == item.checksum_compare){
					
					item.checksum_compare_result = ChecksumCompareResult.OK;
					item.checksum_compare_message = _("OK");
					item.checksum_compare_icon = icon_ok;
					count_ok++;
				}
				else {
					item.checksum_compare_result = ChecksumCompareResult.CHANGED;
					item.checksum_compare_message = _("CHANGED");
					item.checksum_compare_icon = icon_changed;
					count_changed++;
				}
			}
			else{
				if ((checksum == null) || (checksum.length == 0)){
					
					item.checksum_compare_result = ChecksumCompareResult.ERROR;
					item.checksum_compare_message = "ERROR";
					item.checksum_compare_icon = icon_error;
					count_error++;
				}
				else if (checksum == "MISSING"){
					item.checksum_compare_result = ChecksumCompareResult.MISSING;
					item.checksum_compare_message = _("MISSING");
					item.checksum_compare_icon = icon_missing;
					count_missing++;
				}
				else if (checksum == "SYMLINK"){
					item.checksum_compare_result = ChecksumCompareResult.SYMLINK;
					item.checksum_compare_message = _("SYMLINK");
					item.checksum_compare_icon = icon_symlink;
					count_symlink++;
				}
				else {
					item.checksum_compare_result = ChecksumCompareResult.UNKNOWN;
					item.checksum_compare_message = "";
					item.checksum_compare_icon = icon_unknown;
					count_unknown++;
				}
			}
		}

		filter_active = true;

		Timeout.add(100, ()=>{
			refresh_cmb_filter();
			return false;
		});
	}
	
	private void show_verification_summary(){

		string txt = "";

		if (items.size == 0){
			txt += "<b>%s</b>".printf(_("No files found"));
		}
		else if (count_ok == items.size){
			txt += "<b>%s</b>".printf(_("All files verified successfully"));
		}
		else{
			txt += "<b>%lld</b> %s".printf(count_ok, _("OK"));

			txt += ", <b>%lld</b> %s".printf(count_changed, _("CHANGED"));

			if (count_missing > 0){
				txt += ", <b>%lld</b> %s".printf(count_missing, _("MISSING"));
			}

			if (count_symlink > 0){
				txt += ", <b>%lld</b> %s".printf(count_symlink, _("SYMLINK"));
			}

			if (count_error > 0){
				txt += ", <b>%lld</b> %s".printf(count_error, _("ERROR"));
			}
		}
		
		lbl_verify.label = txt;
		lbl_verify.set_use_markup(true);
	}
	
	private void btn_export_verified_results(){

		var chooser = new Gtk.FileChooserDialog(
			_("Save As"),
			window,
			FileChooserAction.SAVE,
			"_Cancel",
			Gtk.ResponseType.CANCEL,
			"_Save",
			Gtk.ResponseType.ACCEPT
		);

		chooser.local_only = true;
 		chooser.set_modal(true);
		chooser.select_multiple = false;

		chooser.set_current_folder(hash_file.file_location);
		chooser.set_current_name(hash_file.file_name + "_Results.csv");

		var filter = create_file_filter(_("Comma-Separated File (CSV)"), { "*.csv" });
		chooser.add_filter(filter);
		
		if (chooser.run() != Gtk.ResponseType.ACCEPT) {
			chooser.destroy();
			return;
		}

		string fname = chooser.get_filename();

		if (!fname.has_suffix(".csv")){
			fname += ".csv";
		}

		chooser.destroy();

		Timeout.add(100, ()=>{
			save_verified_results(fname);
			return false;
		});
	}

	private void save_verified_results(string file_path){

		log_debug("save_verify_results: %s".printf(file_path));
		
		save_running = true;
		save_cancelled = false;
		
		lbl_status.label = _("Saving results...");
		progressbar.fraction = 0;
		lbl_stats.label = "";
		completed_count = 0;
		
		gtk_hide(frame_verify);
		gtk_show(frame_progress);
		gtk_do_events();
				
		Timeout.add(1000, () => {

			lbl_stats.label = "%'.0f of %'d: %s".printf(completed_count, items.size, current_file_name);
			progressbar.fraction = completed_count / items.size;
			gtk_do_events();
			
			if (save_cancelled || !save_running){
				gtk_hide(frame_progress);
				gtk_show(frame_verify);
			}

			return save_running;
		});

		var builder = new StringBuilder ();

		builder.append("\"%s\", \"%s\", \"%s\", \"%s\"\n".printf(
			_("File"),
			_("Checksum (Actual)"),
			_("Checksum (Provided)"),
			_("Status")
		));
			
		foreach(var item in items){
				
			string checksum = "";
		
			switch(checksum_type){
			case ChecksumType.MD5:
				checksum = item.checksum_md5;
				break;
			case ChecksumType.SHA1:
				checksum = item.checksum_sha1;
				break;
			case ChecksumType.SHA256:
				checksum = item.checksum_sha256;
				break;
			case ChecksumType.SHA512:
				checksum = item.checksum_sha512;
				break;
			}

			if ((checksum == "SYMLINK") || (checksum == "MISSING")){
				checksum = "";
			}

			builder.append("\"%s\", \"%s\", \"%s\", \"%s\"\n".printf(
				item.file_path.replace("\"","\"\""),
				checksum,
				item.checksum_compare,
				item.checksum_compare_message
			));

			completed_count++;
			
			if ((completed_count % 2000) == 0){
				gtk_do_events();
			}
		}
			
		string msg = "%s: %s".printf(_("Saved"), file_path);
		log_msg(msg, true);
		lbl_verify.label = msg;

		file_write(file_path, builder.str, window, null, true);

		save_running = false;
	}
	
}


