/*
 * ClamScanBox.vala
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

public class ClamScanBox : Gtk.Box {

	public Gtk.TreeView treeview;
	private Gtk.ScrolledWindow scrolled_treeview;
	
	private Gtk.ListStore store;
	private Gtk.TreeModelFilter filter;

	// columns
	public Gtk.TreeViewColumn col_name;
	public Gtk.TreeViewColumn col_status;
	public Gtk.TreeViewColumn col_checksum_compare;
	public Gtk.TreeViewColumn col_checksum;
	
	public Gee.ArrayList<string> scan_list;
	
	private bool scan_running = false;
	private bool scan_cancelled = false;

	private int64 count_ok = 0;
	private int64 count_found = 0;

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
	public Gtk.Label lbl_results_found;

	public string ui_mode = "scan";

	public ClamScanTask clamav;
	
	// contructor ------------------

	public ClamScanBox(FileViewTab parent_tab, string _ui_mode){
		//base(Gtk.Orientation.VERTICAL, 6); // issue with vala
		Object(orientation: Gtk.Orientation.VERTICAL, spacing: 0); // work-around

		margin = 0;

		log_debug("ClamScanBox: ClamScanBox()");

		tab = parent_tab;
		panel = tab.panel;
		window = App.main_window;

		clamav = new ClamScanTask();

		ui_mode = _ui_mode;

		init_ui();

		log_debug("ClamScanBox: ClamScanBox(): exit");
	}

	private void init_ui(){

		init_treeview();

		init_progress_panel();

		init_results_panel();

		gtk_hide(frame_progress);
		gtk_hide(frame_results);
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
		label.ellipsize = Pango.EllipsizeMode.END;
		label.max_width_chars = 100;
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
			scan_cancelled = true;
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

		// count -----------------
		
		var label = new Gtk.Label("");
		label.set_use_markup(true);
		label.xalign = 0.0f;
		hbox.add(label);

		lbl_results_found = label;
		
		label.hexpand = true;

		// actions -------------------

		var button = new Gtk.Button.with_label(_("Move to Quarantine"));
		button.image = IconManager.lookup_image("dialog-apply", 16);
		button.always_show_image = true;
		hbox.add(button);

		button.clicked.connect(()=>{

			string tmp_file = get_temp_file_path(false);

			var list = new Gee.ArrayList<ClamScanResult>();
			
			string txt = "";
			foreach(var res in clamav.results){
				if (res.selected){
					list.add(res);
					log_debug("Selected: " + res.file_path);
					txt += "%s\n".printf(res.file_path);
				}
			}
			file_write(tmp_file, txt);

			string cmd = "pkexec polo-clamav --scripted --quarantine-from '%s'".printf(escape_single_quote(tmp_file));

			log_debug(cmd);
			
			Posix.system(cmd);

			int count = 0;
			foreach(var res in list){
				if (!file_exists(res.file_path)){
					count++;
					clamav.results.remove(res);
				}
			}

			refresh();
			
			string ttl = _("Files Moved");
			string msg = "%d %s".printf(count, _(" files moved to quarantine"));
			gtk_messagebox(ttl, msg, window, false);
		});

		// close

		button = new Gtk.Button.with_label(_("Close"));
		button.image = IconManager.lookup_image("process-stop", 16);
		button.always_show_image = true;
		hbox.add(button);

		button.clicked.connect(()=>{
			tab.close_tab();
		});
	}

	// treeview -----------------------------------
	
	private void init_treeview() {

		// treeview
		treeview = new Gtk.TreeView();
		treeview.get_selection().mode = Gtk.SelectionMode.SINGLE;
		treeview.headers_clickable = true;

		// scrolled
		var scrolled = new Gtk.ScrolledWindow(null, null);
		scrolled.set_shadow_type (ShadowType.ETCHED_IN);
		scrolled.hscrollbar_policy = PolicyType.AUTOMATIC;
		scrolled.vscrollbar_policy = PolicyType.AUTOMATIC;
		scrolled.add (treeview);
		scrolled.expand = true;
		this.add(scrolled);
		scrolled_treeview = scrolled;

		add_col_name();

		add_col_signature();

		add_col_size();

		//add_col_quarantined();

		add_col_modified();

		add_col_spacer();
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

		if (ui_mode == "manage"){
			col.title = _("Original Path");
		}

		// cell toggle
		var cell_toggle = new Gtk.CellRendererToggle();
		cell_toggle.activatable = true;
		col.pack_start (cell_toggle, false);
		
		// cell icon
		var cell_pix = new Gtk.CellRendererPixbuf();
		col.pack_start(cell_pix, false);

		// cell text
		var cell_text = new Gtk.CellRendererText();
		cell_text.ellipsize = Pango.EllipsizeMode.END;
		col.pack_start (cell_text, true);

		// toggle handler
		cell_toggle.toggled.connect((path) => {
			
			TreeIter iter;
			var model = (Gtk.ListStore) treeview.model;
			model.get_iter_from_string (out iter, path);

			ClamScanResult res;
			model.get (iter, 1, out res, -1);
			
			bool selected;
			model.get (iter, 0, out selected, -1);
			
			selected = !selected;
			model.set (iter, 0, selected);

			res.selected = selected;
		});

		// render toggle
		col.set_cell_data_func (cell_toggle, (cell_layout, cell, model, iter) => {

			bool selected;
			model.get (iter, 0, out selected, -1);
			
			cell_toggle.active = selected;
		});
		
		// render icon
		col.set_cell_data_func (cell_pix, (cell_layout, cell, model, iter) => {

			var pixcell = cell as Gtk.CellRendererPixbuf;

			pixcell.pixbuf = IconManager.lookup("dialog-warning", 16);
		});

		// render text
		col.set_cell_data_func (cell_text, (cell_layout, cell, model, iter) => {

			var crt = cell as Gtk.CellRendererText;

			ClamScanResult res;
			model.get (iter, 1, out res, -1);

			crt.text = res.file_path;

			crt.scale = App.listview_font_scale;
		});
	}

	private void add_col_signature() {

		// column
		var col = new Gtk.TreeViewColumn();
		col.title = _("Signature");
		//col.clickable = true;
		col.resizable = true;
		//col.expand = true;
		col.min_width = 200;
		treeview.append_column(col);
		col_status = col;

		// cell icon
		var cell_pix = new Gtk.CellRendererPixbuf ();
		cell_pix.xpad = 5;
		col.pack_start(cell_pix, false);

		// cell text
		var cell_text = new Gtk.CellRendererText ();
		cell_text.ellipsize = Pango.EllipsizeMode.END;
		col.pack_start (cell_text, true);
		
		// render text
		col.set_cell_data_func (cell_text, (cell_layout, cell, model, iter) => {

			var crt = cell as Gtk.CellRendererText;

			ClamScanResult res;
			model.get (iter, 1, out res, -1);

			crt.text = res.signature;

			crt.scale = App.listview_font_scale;
		});
	}

	private void add_col_size() {

		// column
		var col = new Gtk.TreeViewColumn();
		col.title = _("Size");
		//col.clickable = true;
		col.resizable = true;
		//col.expand = true;
		col.min_width = 50;
		treeview.append_column(col);
		col_status = col;

		// cell text
		var cell_text = new Gtk.CellRendererText();
		cell_text.ellipsize = Pango.EllipsizeMode.END;
		col.pack_start (cell_text, true);
		
		// render text
		col.set_cell_data_func(cell_text, (cell_layout, cell, model, iter) => {

			var crt = cell as Gtk.CellRendererText;

			ClamScanResult res;
			model.get (iter, 1, out res, -1);

			crt.text = res.size;

			crt.scale = App.listview_font_scale;
		});
	}

	private void add_col_modified() {

		// column
		var col = new Gtk.TreeViewColumn();
		col.title = _("Modified");
		//col.clickable = true;
		col.resizable = true;
		//col.expand = true;
		col.min_width = 150;
		treeview.append_column(col);
		col_status = col;

		// cell icon
		var cell_pix = new Gtk.CellRendererPixbuf ();
		cell_pix.xpad = 5;
		col.pack_start(cell_pix, false);

		// cell text
		var cell_text = new Gtk.CellRendererText ();
		cell_text.ellipsize = Pango.EllipsizeMode.END;
		col.pack_start (cell_text, true);
		
		// render text
		col.set_cell_data_func (cell_text, (cell_layout, cell, model, iter) => {

			var crt = cell as Gtk.CellRendererText;

			ClamScanResult res;
			model.get (iter, 1, out res, -1);

			crt.text = res.modified;

			crt.scale = App.listview_font_scale;
		});
	}
	
	private void add_col_spacer() {

		var col = new TreeViewColumn();
		col.title = "";
		col.clickable = false;
		col.resizable = true;
		col.expand = true;
		col.reorderable = false;
		//col.min_width = 20;
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

	public void refresh(){

		log_debug("ClamScanBox: refresh()");

		treeview.model = null;
		
		store = new Gtk.ListStore(2,
			typeof(bool),
			typeof(ClamScanResult)
		);

		foreach(var res in clamav.results){

			treeview_append(res);
		}

		treeview.set_model(store);
		treeview.columns_autosize();

		string txt = "%d %s".printf(clamav.results.size, _("Found"));
		lbl_results_found.label = format_text(txt, true, false, true);
		
		log_debug("ClamScanBox: refresh(): end");
	}

	public void treeview_append(ClamScanResult res){

		TreeIter iter;
		store.append(out iter);
		store.set(iter, 0, true);
		store.set(iter, 1, res);

		treeview.columns_autosize();
	}

	// actions ----------------------------------------------------
	
	public void scan(Gee.ArrayList<string> _scan_list, string _scan_mode){

		log_debug("ClamScanBox: scan()");

		scan_list = _scan_list;

		clamav.scan_mode = _scan_mode;

		if (scan_list.size == 1){
			tab.tab_name = "Scan: %s".printf(file_basename(scan_list[0]));
		}
		else{
			tab.tab_name = "Scan: %d items".printf(scan_list.size);
		}

		lbl_status.label = "";
		progressbar.fraction = 0.0;
		lbl_stats.label = "";
		
		gtk_show(frame_progress);
		gtk_hide(frame_results);
		
		refresh(); // create empty store

		lbl_status.label = _("Initializing...");
		progressbar.fraction = 0.0;
		lbl_stats.label = "";
		
		scan_running = true;
		scan_cancelled = false;

		// add status timer ----------------------
		
		Timeout.add(500, () => {

			if (clamav.found != "0"){
				lbl_status.label = _("Scanning files...");
			}
			
			lbl_stats.label = clamav.status_line;

			if ((progressbar.fraction + 0.01) < 1.0){
				progressbar.fraction += 0.01;
			}

			if (scan_cancelled){
				gtk_hide(frame_progress);
			}

			gtk_do_events();
			
			return clamav.is_running;
		});

		clamav.task_complete.connect(()=>{

			log_debug("clamav.task_complete.connect();");
			
			Timeout.add(10, () => {

				log_debug("clamav.task_complete.connect(): timeout");
				
				gtk_hide(frame_progress);
				
				gtk_show(frame_results);

				string txt = "%d %s".printf(clamav.results.size, _("Found"));
				lbl_results_found.label = format_text(txt, true, false, true);

				log_debug("clamav.task_complete.connect(): timeout: exit");

				string title = _("Scan Summary");
				string msg = clamav.scan_summary;
				gtk_messagebox(title, msg, window, true);
				
				return false;
			});

			log_debug("clamav.task_complete.connect(): exit");
		});

		clamav.file_found.connect((res)=>{
			
			Timeout.add(10, () => {
				
				treeview_append(res);
				return false;
			});
		});

		// start ---------------
		
		clamav.scan(scan_list);
	}
}


