/*
 * FileViewList.vala
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

public interface IFileViewList{
	
}

public class FileViewList : Gtk.Box, IFileViewList {

	private Gtk.Box contents;
	private Gtk.Overlay overlay;
	private Gtk.Label? lbl_overlay;
	private Gtk.Box? box_overlay;
	 
	private Gtk.Box active_indicator_top;
	//private Gtk.Box active_indicator_bottom;
	
	public ExtendedTreeView treeview;
	private Gtk.ScrolledWindow scrolled_treeview;
	private TreeViewColumnManager tv_manager;
	public int sort_column_index = FileViewColumn.NAME;
	public bool sort_column_desc = false;
	private Gtk.TreeStore store;
	private Gtk.TreeModelFilter treefilter;

	public Gtk.IconView iconview;
	private Gtk.ScrolledWindow scrolled_iconview;

	// columns
	public Gtk.TreeViewColumn col_dir;
	public Gtk.TreeViewColumn col_name;
	public Gtk.TreeViewColumn col_indicator;
	public Gtk.TreeViewColumn col_size;
	public Gtk.TreeViewColumn col_compressed;
	public Gtk.TreeViewColumn col_modified;
	public Gtk.TreeViewColumn col_permissions;
	public Gtk.TreeViewColumn col_access;
	public Gtk.TreeViewColumn col_mimetype;
	public Gtk.TreeViewColumn col_filetype;
	public Gtk.TreeViewColumn col_symlink_target;
	public Gtk.TreeViewColumn col_owner;
	public Gtk.TreeViewColumn col_group;
	public Gtk.TreeViewColumn col_md5;
	public Gtk.TreeViewColumn col_original_path;
	public Gtk.TreeViewColumn col_deletion_date;
	public Gtk.TreeViewColumn col_spacer;
	public Gtk.CellRendererText cell_name;

	private bool thumbnail_update_is_required = false;
	private bool thumbnail_updater_is_running = false;
	private bool thumbnail_update_cancelled = false;
	private int thumbnail_pending = 0;
	public static Mutex thumbnail_mutex = Mutex();

	// history
	public Gee.ArrayList<string> visited_locations = new Gee.ArrayList<string>();
	private int history_index = -1;

	// items
	public FileItem current_item;
	public string current_location = "";
	public bool current_location_is_virtual = false;
	public FileContextMenu menu_file;
	public bool view_initialized = false;

	public string filter_pattern = "";
	public int query_items_delay = 0;
	
	public Gee.ArrayList<FileItemMonitor> monitors = new Gee.ArrayList<FileItemMonitor>();

	// parents
	public LayoutPanel panel;
	public FileViewPane pane;
	public MainWindow window;

	// theme
	public double listview_font_scale;
	public int listview_icon_size;
	public int listview_row_spacing;

	public int iconview_icon_size;
	public int iconview_row_spacing;
	public int iconview_column_spacing;

	public int tileview_icon_size;
	public int tileview_row_spacing;
	public int tileview_padding;

	private ViewMode view_mode; // auto
	private ViewMode view_mode_user;
	//private bool media_mode = false;

	public bool show_hidden_files;
	public bool dual_mode = true;

	public bool media_view_exited = false;
	public bool show_folders_in_media_view = true;
	public bool show_other_files_in_media_view = true;

	// signals
	public signal void changed();

	// helper
	//private Gtk.Image video_image;
	//private FileItem video_item;
	//private bool video_thumb_cycling_in_progress = false;

	// contructor ------------------

	public FileViewList(FileViewPane parent_pane){
		//base(Gtk.Orientation.VERTICAL, 6); // issue with vala
		Object(orientation: Gtk.Orientation.VERTICAL, spacing: 0); // work-around

		margin = 0;

		log_debug("FileViewList()");

		pane = parent_pane;
		panel = pane.panel;
		window = App.main_window;

		show_hidden_files = App.show_hidden_files;

		set_zoom_from_global();

		view_mode = App.view_mode;
		view_mode_user = App.view_mode;

		log_debug("view_mode = App.view_mode; %s".printf(view_mode.to_string()));

		init_active_indicator_top();
		
		init_overlay();

		init_treeview();

		init_iconview();

		//init_active_indicator_bottom();

		connect_key_press_handler();

		connect_file_context_menu();
		
		show_all();
	}

	private void init_overlay(){

		/*
		FileViewList (Box) > Overlay > add(contents) (Box)      |--> IconView
		                                                        |--> TreeView
		                             > add_overlay(hbox) (Box)
		*/
		
		overlay = new Gtk.Overlay(); 
		this.add(overlay);
    
		contents = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
		overlay.add(contents);
	}

	private void connect_file_context_menu(){
		
		/*// connect signal for shift+F10
        contents.popup_menu.connect(() => {
			if (current_item == null) {
				log_debug("current_item is NULL");
				return false;
			}
			menu_file = new FileContextMenu(pane);
			return menu_file.show_menu(null);
		});

        // connect signal for right-click
		contents.button_press_event.connect(treeview_button_press_event);
		* */

		// connect signal for shift+F10
        treeview.popup_menu.connect(() => {
			if (current_item == null) {
				log_debug("current_item is NULL");
				return false;
			}
			menu_file = new FileContextMenu(pane);
			return menu_file.show_menu(null);
		});

        // connect signal for right-click
		treeview.button_press_event.connect(treeview_button_press_event);

	}
	
	// treeview -----------------------------------
	
	private void init_treeview() {

		// treeview
		treeview = new ExtendedTreeView();
		treeview.get_selection().mode = Gtk.SelectionMode.MULTIPLE;
		treeview.headers_clickable = true;
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
		contents.add(scrolled);
		scrolled_treeview = scrolled;

		gtk_hide(scrolled);

		add_col_name();

		add_col_indicator();

		add_col_size();

		add_col_modified();

		add_col_compressed();

		add_col_md5();

		add_col_permissions();

		add_col_owner();

		add_col_group();

		add_col_access();

		add_col_filetype();

		add_col_mimetype();

		add_col_symlink_target();

		add_col_original_path();

		add_col_deleted_date();

		add_col_spacer();

		init_column_manager();

		// events -------------------------------

		treeview.row_activated.connect(treeview_row_activated);

		treeview.row_expanded.connect(treeview_row_expanded);

		treeview.row_collapsed.connect(treeview_row_collapsed);

		treeview.get_selection().changed.connect(on_selection_changed);

		// context menu will be connected in connect_file_context_menu()
		
		// tooltip
		treeview.has_tooltip = true;
		treeview.query_tooltip.connect(treeview_query_tooltip);

		// setup DND

        treeview.drag_data_received.connect(on_drag_data_received);
		treeview.drag_data_get.connect(on_drag_data_get);

		treeview.enable_search = false;
		
		//treeview.button_press_event.connect(on_button_press_event);
		//treeview.button_release_event.connect(on_button_release_event);

		//treeview.enter_notify_event.connect((event) => {
		//	log_debug("enter_notify_event");
		//	App.current_view = this;
		//	return true;
		//});

		//view.col_name.clicked.connect(()=>{
		//	treeview_refresh(view);
		//	log_msg("clicked");
		//});
	}

	private bool treeview_query_tooltip(int x, int y, bool keyboard_tooltip, Tooltip tooltip) {

		TreeModel model;
		TreePath path;
		TreeIter iter;
		TreeViewColumn column;

		if (treeview.get_tooltip_context (ref x, ref y, keyboard_tooltip, out model, out path, out iter)){
			int bx, by;
			treeview.convert_widget_to_bin_window_coords(x, y, out bx, out by);
			if (treeview.get_path_at_pos (bx, by, null, out column, null, null)){

				FileItem item;
				model.get (iter, 0, out item, -1);

				string tt = treeview_get_tooltip(item, column);
				if (tt.length > 0){
					tooltip.set_markup(tt);
					return true;
				}
				else{
					tooltip.set_markup(null);
					return true;
				}
			}
		}

		return false;
	}

	private bool iconview_query_tooltip(int x, int y, bool keyboard_tooltip, Tooltip tooltip) {

		//log_debug("iconview_query_tooltip()");

		TreeModel model;
		TreePath path;
		TreeIter iter;

		if (iconview.get_tooltip_context (ref x, ref y, keyboard_tooltip, out model, out path, out iter)){

			//log_debug("iconview.get_tooltip_context()");

			FileItem item;
			model.get (iter, 0, out item, -1);

			string tt = item.tile_tooltip;
			if (tt.length > 0){
				tooltip.set_markup(tt);
				return true;
			}
			else{
				tooltip.set_markup(null);
				return true;
			}
		}

		return false;
	}

	private string treeview_get_tooltip(FileItem item, TreeViewColumn column){

		if (column == col_indicator){
			if (item.is_symlink){
				if (item.is_symlink_broken){
					return "(%s) %s: %s".printf(_("Broken"), _("Link to"), item.symlink_target);
				}
				else{
					return "%s: %s".printf(_("Link to"), item.symlink_target);
				}
			}
			else{
				return _("Item is not a symbolic link");
			}
		}
		else if (column == col_access){
			return "%s\n\n%s\n%s".printf(
				_("Effective permissions for current user"),
				_("RWX = Read Write Execute"), _("NTD = Rename Trash Delete"));
		}
		else if (column == col_modified){
			return "%s".printf(_("Last modified date"));
		}
		else if (column == col_filetype){
			return "%s".printf(_("File type"));
		}
		else if (column == col_mimetype){
			return "%s".printf(_("Mime type"));
		}
		else if (column == col_name){
			return item.tile_tooltip;
		}
		else if (column == col_owner){
			return "%s".printf(_("User"));
		}
		else if (column == col_group){
			return "%s".printf(_("Group"));
		}
		else if (column == col_permissions){
			return "%s".printf(_("Permissions"));
		}

		return "";
	}

	private bool treeview_button_press_event(Gtk.Widget w, Gdk.EventButton event){

		log_debug("FileViewList: treeview_button_press_event()");
		
		window.active_pane = pane;
		window.update_accelerators_for_active_pane();
		
		pane.selection_bar.close_panel(false);

		pane.pathbar.finish_editing();
		window.pathbar.finish_editing();

		if (event.button == 3) {
			if (current_item == null) { return false; }

			//log_debug("FileViewList: treeview_button_press_event(): right_click_select");
			
			TreePath? path;
			TreeViewColumn? column;
			int cell_x, cell_y;
			treeview.get_path_at_pos((int) event.x, (int) event.y, out path, out column, out cell_x, out cell_y);
			
			var sel = treeview.get_selection();
			if (!sel.path_is_selected(path)){
				clear_selections();
				sel.select_path(path);
			}

			//log_debug("FileViewList: treeview_button_press_event(): right_click_select: exit");
			
			menu_file = new FileContextMenu(pane);
			return menu_file.show_menu(event);
		}

		//log_debug("FileViewList: treeview_button_press_event(): exit");

		return false;
	}

	private void treeview_row_activated(TreePath path, TreeViewColumn? column){

		log_debug("FileViewList: treeview_row_activated()");

		TreeIter iter;
		treefilter.get_iter_from_string(out iter, path.to_string());

		TreeIter iter0;
		treefilter.convert_iter_to_child_iter(out iter0, iter);
		
		FileItem item;
		store.get (iter0, FileViewColumn.ITEM, out item, -1);

		if (!item.is_directory && !(item is FileItemCloud)
			&& FileItem.is_archive_by_extension(item.file_path) && !FileItem.is_package_by_extension(item.file_path)){

			if (item is FileItemArchive == false){
				
				FileItemArchive? arch = FileItemArchive.convert_file_item(item);
				
				if (arch != null){
					item = arch;
					FileItem.add_to_cache(item); // add archive as directory to cache
					store.set(iter, FileViewColumn.ITEM, item);
				}
			}
		}

		//log_debug("query_children_running: %s".printf(item.query_children_running.to_string()));

		open(item, null);
	}

	private void treeview_row_expanded(TreeIter iter, TreePath path){

		log_debug("FileViewList: treeview_row_expanded()");
		
		gtk_set_busy(true, window);

		treeview.row_expanded.disconnect(treeview_row_expanded);
		
		TreeIter iter0;
		treefilter.convert_iter_to_child_iter(out iter0, iter);
		
		FileItem item0, item1;
		store.get (iter0, 0, out item0, -1);

		log_debug("expanded: %s".printf(item0.file_path));

		// re-query and re-populate the expanded node (iter0)

		item0.query_children(1, false);
		set_iter_from_item(iter0, item0, true, true);
		remove_iter_children(ref iter0);
		append_item_children_to_iter(ref iter0, item0, true, true);

		treeview.expand_row(path, false);
		treeview.queue_draw();
		gtk_do_events();
		
		TreeIter iter1;
		bool iterExists = store.iter_children (out iter1, iter0);
		while (iterExists) {
			store.get (iter1, 0, out item1, -1);

			// re-query and re-populate child nodes

			item1.query_children(1, false);
			//set_iter_from_item(iter1, item1); // not needed
			remove_iter_children(ref iter1);
			append_item_children_to_iter(ref iter1, item1, false, false);

			iterExists = store.iter_next (ref iter1);
		}

		treeview.queue_draw();
		gtk_do_events();
		
		treeview.row_expanded.connect(treeview_row_expanded);
	
		add_monitor(item0);

		gtk_set_busy(false, window);
	}

	private void treeview_row_collapsed(TreeIter iter, TreePath path){

		log_debug("FileViewList: treeview_row_collapsed()");
		
		treeview.row_collapsed.disconnect(treeview_row_collapsed);

		TreeIter iter0;
		treefilter.convert_iter_to_child_iter(out iter0, iter);
		
		FileItem item0;
		store.get (iter0, 0, out item0, -1);
		
		remove_monitor(item0);
		
		treeview.row_collapsed.connect(treeview_row_collapsed);
	}

	private string propbar_last_folder_path = "";
	
	private void on_selection_changed(){
		
		pane.statusbar.refresh_selection_counts();
		
		if (App.main_window.propbar.visible){
			
			var selected_items = get_selected_items();
			if (selected_items.size == 0){ return; }

			bool query_size = true;
			if (propbar_last_folder_path != current_location){
				propbar_last_folder_path = current_location;
				query_size = false;
			}
			
			Timeout.add(10, ()=>{
				App.main_window.propbar.show_properties_for_file(selected_items[0], query_size);
				return false;
			});
		}
	}
	
	// iconview -----------------------------------
	
	public void init_iconview(){

		// iconview
		iconview = new Gtk.IconView();
		iconview.set_pixbuf_column(FileViewColumn.ICON);
		iconview.set_text_column(FileViewColumn.NAME);
		iconview.selection_mode = Gtk.SelectionMode.MULTIPLE;
		iconview.reorderable = false;
		//iconview.enable_search = true;
		iconview.spacing = 0;

		// scrolled
		var scrolled = new Gtk.ScrolledWindow(null, null);
		scrolled.set_shadow_type (ShadowType.ETCHED_IN);
		scrolled.hscrollbar_policy = PolicyType.AUTOMATIC;
		scrolled.vscrollbar_policy = PolicyType.AUTOMATIC;
		scrolled.add (iconview);
		scrolled.expand = true;
		contents.add(scrolled);
		scrolled_iconview = scrolled;

		gtk_hide(scrolled);

		iconview.item_activated.connect((path) =>{
			treeview_row_activated(path, null);
		});

		// connect signal for shift+F10
        iconview.popup_menu.connect(() => {
			if (current_item == null) { return false; }
			menu_file = new FileContextMenu(pane);
			return menu_file.show_menu(null);
		});

        // connect signal for right-click
		iconview.button_press_event.connect(iconview_button_press_event);

		iconview.selection_changed.connect(on_selection_changed);
		
		// tooltip
		iconview.has_tooltip = true;
		iconview.query_tooltip.connect(iconview_query_tooltip);
	}

	private bool iconview_button_press_event(Gtk.Widget w, Gdk.EventButton event){

		window.active_pane = pane;
		window.update_accelerators_for_active_pane();

		pane.selection_bar.close_panel(false);

		pane.pathbar.finish_editing();
		window.pathbar.finish_editing();

		if (event.button == 3) {
			if (current_item == null) { return false; }

			TreePath? path;
			//TreeViewColumn? column;
			//int cell_x, cell_y;
			path = iconview.get_path_at_pos((int) event.x, (int) event.y);
			
			if (!iconview.path_is_selected(path)){
				clear_selections();
				iconview.select_path(path);
			}
			
			menu_file = new FileContextMenu(pane);
			return menu_file.show_menu(event);
		}

		return false;
	}

	// treeview columns -----------------------------------
	
	private void add_col_name() {

		// column
		var col = new Gtk.TreeViewColumn();
		col.title = _("Name");
		col.clickable = true;
		col.resizable = true;
		col.expand = true;
		treeview.append_column(col);
		col_name = col;

		//col.sort_column_id = FileViewColumn.NAME;
		col.clicked.connect(tv_header_clicked);

		// cell icon
		var cell_pix = new Gtk.CellRendererPixbuf ();
		col.pack_start(cell_pix, false);

		// cell text
		var cell_text = new Gtk.CellRendererText ();
		cell_text.ellipsize = Pango.EllipsizeMode.END;
		//cell_text.hxpand = true;
		col.pack_start (cell_text, true);
		cell_name = cell_text;

		//cell_text.editable = true;
		cell_text.edited.connect ((path, new_name)=>{
			FileItem item;
			TreeIter iter;
			var model = (Gtk.TreeModel) treefilter;
			model.get_iter_from_string (out iter, path);
			model.get (iter, 0, out item, -1);

			try_rename_item(item, new_name);

			cell_name.editable = false;

			window.update_accelerators_for_active_pane();
		});

		// render icon
		col.set_cell_data_func (cell_pix, (cell_layout, cell, model, iter) => {

			var pixcell = cell as Gtk.CellRendererPixbuf;

			FileItem item;
			model.get (iter, FileViewColumn.ITEM, out item, -1);

			Gdk.Pixbuf pixbuf;
			model.get (iter, FileViewColumn.ICON, out pixbuf, -1);

			pixcell.pixbuf = pixbuf;
			pixcell.ypad = listview_row_spacing;
		});

		// render text
		col.set_cell_data_func (cell_text, (cell_layout, cell, model, iter) => {

			var crt = cell as Gtk.CellRendererText;

			FileItem item;
			model.get (iter, FileViewColumn.ITEM, out item, -1);

			crt.text = item.display_name;

			crt.scale = listview_font_scale;
		});
	}

	private void add_col_indicator() {

		// column
		var col = new Gtk.TreeViewColumn();
		col.title = "";//_("Ind");
		treeview.append_column(col);
		col_indicator = col;

		// cell icon
		var cell_pix = new Gtk.CellRendererPixbuf();
		cell_pix.xpad = 3;
		col.pack_start(cell_pix, false);

		// render link indicator icon
		col.set_cell_data_func (cell_pix, (cell_layout, cell, model, iter) => {

			var pixcell = cell as Gtk.CellRendererPixbuf;

			FileItem item;
			model.get (iter, 0, out item, -1);

			if (item.is_symlink && !item.is_symlink_broken){
				pixcell.pixbuf = IconManager.lookup("symbolic-link", 16, false, true); //emblem-symbolic-link
			}
			else if (item.is_symlink && item.is_symlink_broken){
				pixcell.pixbuf = IconManager.lookup("error", 16, false, true); //emblem-symbolic-link
			}
			else{
				pixcell.pixbuf = null;
			}
		});
	}

	private void add_col_size() {

		// column
		var col = new TreeViewColumn();
		col.title = _("Size");
		col.clickable = true;
		col.resizable = true;
		col.reorderable = true;
		col.spacing = 1;
		col.min_width = 100;
		treeview.append_column(col);
		col_size = col;

		//col.sort_column_id = FileViewColumn.SIZE;
		col.clicked.connect(tv_header_clicked);

		// cell_spinner -------------------------------------

		/*
		var cell_spinner = new Gtk.CellRendererSpinner();
		cell_spinner.pulse = 2;
		col.pack_start (cell_spinner, false);

		col.set_cell_data_func (cell_spinner, (cell_layout, cell, model, iter) => {

			var cspin = cell as Gtk.CellRendererSpinner;

			FileItem item;
			model.get (iter, FileViewColumn.ITEM, out item, -1);
			
			cspin.visible = item.is_directory && item.query_children_pending;
			cspin.active = cspin.visible;
			cspin.pulse = cspin.pulse + 1;
		});
		*/
		
		// cell_text -------------------------------------
		
		var cell_text = new CellRendererText ();
		cell_text.xalign = 1.0f;
		col.pack_start (cell_text, false);

		// render text
		col.set_cell_data_func (cell_text, (cell_layout, cell, model, iter) => {

			var crt = cell as Gtk.CellRendererText;

			string lv_size;
			model.get (iter, FileViewColumn.LV_SIZE, out lv_size, -1);

			crt.text = lv_size;
	
			crt.scale = listview_font_scale;
		});
	}

	private void add_col_modified() {

		// column
		var col = new TreeViewColumn();
		col.title = _("Modified");
		col.clickable = true;
		col.resizable = true;
		col.reorderable = true;
		col.spacing = 1;
		//col.min_width = 100;
		treeview.append_column(col);
		col_modified = col;

		//col.sort_column_id = FileViewColumn.MODIFIED;
		col.clicked.connect(tv_header_clicked);

		// cell text
		var cell_text = new CellRendererText ();
		col.pack_start (cell_text, false);

		// render text
		col.set_cell_data_func (cell_text, (cell_layout, cell, model, iter) => {

			var crt = cell as Gtk.CellRendererText;

			FileItem item;
			model.get (iter, FileViewColumn.ITEM, out item, -1);

			if (item.is_dummy){
				crt.text = "";
			}
			else if (item.modified == null) {
				crt.text = "--";
			}
			else{
				crt.text = item.modified.format ("%Y-%m-%d %H:%M");
			}
			
			crt.scale = listview_font_scale;
		});

	}

	private void add_col_compressed() {

		// column
		var col = new TreeViewColumn();
		col.title = _("Packed");
		col.clickable = true;
		col.resizable = true;
		col.reorderable = true;
		col.spacing = 1;
		//col.min_width = 100;
		treeview.append_column(col);
		col_compressed = col;

		//col.sort_column_id = FileViewColumn.PACKED_SIZE;
		col.clicked.connect(tv_header_clicked);

		// cell text
		var cell_text = new CellRendererText();
		cell_text.xalign = 1.0f;
		col.pack_start (cell_text, false);

		//render text
		col.set_cell_data_func (cell_text, (cell_layout, cell, model, iter) => {

			var crt = cell as Gtk.CellRendererText;

			FileItem item;
			model.get (iter, FileViewColumn.ITEM, out item, -1);

			if (item.is_dummy){
				crt.text = "";
			}
			else if (item.size_compressed == 0) {
				crt.text = "--";
			}
			else{
				crt.text = format_file_size(item.size_compressed);
			}

			crt.scale = listview_font_scale;
		});
	}

	private void add_col_owner() {

		// column
		var col = new TreeViewColumn();
		col.title = _("Owner");
		col.clickable = true;
		col.resizable = true;
		col.reorderable = true;
		col.spacing = 1;
		//col.min_width = 100;
		treeview.append_column(col);
		col_owner = col;

		//col.sort_column_id = FileViewColumn.OWNER;
		col.clicked.connect(tv_header_clicked);

		// cell text
		var cell_text = new CellRendererText ();
		col.pack_start (cell_text, false);

		// render text
		col.set_cell_data_func (cell_text, (cell_layout, cell, model, iter) => {

			var crt = cell as Gtk.CellRendererText;

			FileItem item;
			model.get (iter, FileViewColumn.ITEM, out item, -1);

			if (item.is_dummy){
				crt.text = "";
			}
			else if (item.owner_user.length == 0) {
				crt.text = "--";
			}
			else{
				crt.text = item.owner_user;
			}
			
			crt.scale = listview_font_scale;
		});

	}

	private void add_col_group() {

		// column
		var col = new TreeViewColumn();
		col.title = _("Group");
		col.clickable = true;
		col.resizable = true;
		col.reorderable = true;
		col.spacing = 1;
		//col.min_width = 100;
		treeview.append_column(col);
		col_group = col;

		//col.sort_column_id = FileViewColumn.GROUP;
		col.clicked.connect(tv_header_clicked);

		// cell text
		var cell_text = new CellRendererText ();
		col.pack_start (cell_text, false);

		// render text
		col.set_cell_data_func (cell_text, (cell_layout, cell, model, iter) => {

			var crt = cell as Gtk.CellRendererText;

			FileItem item;
			model.get (iter, FileViewColumn.ITEM, out item, -1);

			if (item.is_dummy){
				crt.text = "";
			}
			else if (item.owner_group.length == 0) {
				crt.text = "--";
			}
			else{
				crt.text = item.owner_group;
			}

			crt.scale = listview_font_scale;
		});

	}

	private void add_col_permissions() {

		// column
		var col = new TreeViewColumn();
		col.title = _("Permissions");
		col.clickable = true;
		col.resizable = true;
		col.reorderable = true;
		col.spacing = 1;
		//col.min_width = 100;
		treeview.append_column(col);
		col_permissions = col;

		//col.sort_column_id = FileViewColumn.PERMISSIONS;
		col.clicked.connect(tv_header_clicked);

		// cell text
		var cell_text = new CellRendererText ();
		col.pack_start (cell_text, false);

		// render text
		col.set_cell_data_func (cell_text, (cell_layout, cell, model, iter) => {

			var crt = cell as Gtk.CellRendererText;

			FileItem item;
			model.get (iter, FileViewColumn.ITEM, out item, -1);

			if (item.is_dummy){
				crt.text = "";
			}
			else if (item.permissions.length == 0) {
				crt.text = "--";
			}
			else{
				crt.text = item.permissions;
			}

			crt.scale = listview_font_scale;
		});

	}

	private void add_col_access() {

		// column
		var col = new TreeViewColumn();
		col.title = _("Access");
		col.clickable = true;
		col.resizable = true;
		col.reorderable = true;
		col.spacing = 1;
		//col.min_width = 100;
		treeview.append_column(col);
		col_access = col;

		//col.sort_column_id = FileViewColumn.GROUP;
		col.clicked.connect(tv_header_clicked);

		// cell text
		var cell_text = new CellRendererText ();
		col.pack_start (cell_text, false);

		// render text
		col.set_cell_data_func (cell_text, (cell_layout, cell, model, iter) => {

			var crt = cell as Gtk.CellRendererText;

			FileItem item;
			model.get (iter, FileViewColumn.ITEM, out item, -1);

			if (item.is_dummy){
				crt.text = "";
			}
			else if (item.access_flags.length == 0) {
				crt.text = "--";
			}
			else{
				crt.text = item.access_flags;
			}
			
			crt.scale = listview_font_scale;
		});

	}

	private void add_col_mimetype() {

		// column
		var col = new TreeViewColumn();
		col.title = _("Content Type");
		col.clickable = true;
		col.resizable = true;
		col.reorderable = true;
		col.spacing = 1;
		//col.min_width = 100;
		treeview.append_column(col);
		col_mimetype = col;

		//col.sort_column_id = FileViewColumn.GROUP;
		col.clicked.connect(tv_header_clicked);

		// cell text
		var cell_text = new CellRendererText ();
		col.pack_start (cell_text, false);

		// render text
		col.set_cell_data_func (cell_text, (cell_layout, cell, model, iter) => {

			var crt = cell as Gtk.CellRendererText;

			FileItem item;
			model.get (iter, FileViewColumn.ITEM, out item, -1);

			if (item.is_dummy){
				crt.text = "";
			}
			else if (item.content_type.length == 0) {
				crt.text = "--";
			}
			else{
				crt.text = item.content_type;
			}

			crt.scale = listview_font_scale;
		});

	}

	private void add_col_filetype() {

		// column
		var col = new TreeViewColumn();
		col.title = _("Type");
		col.clickable = true;
		col.resizable = true;
		col.reorderable = true;
		col.spacing = 1;
		//col.min_width = 100;
		treeview.append_column(col);
		col_filetype = col;

		//col.sort_column_id = FileViewColumn.GROUP;
		col.clicked.connect(tv_header_clicked);

		// cell text
		var cell_text = new CellRendererText ();
		col.pack_start (cell_text, false);

		// render text
		col.set_cell_data_func (cell_text, (cell_layout, cell, model, iter) => {

			var crt = cell as Gtk.CellRendererText;

			FileItem item;
			model.get (iter, FileViewColumn.ITEM, out item, -1);

			if (item.is_dummy){
				crt.text = "";
			}
			else if (item.content_type_desc.length == 0) {
				crt.text = "--";
			}
			else{
				crt.text = item.content_type_desc;
			}

			crt.scale = listview_font_scale;
		});

	}

	private void add_col_md5() {

		// column
		var col = new TreeViewColumn();
		col.title = _("MD5");
		col.clickable = true;
		col.resizable = true;
		col.reorderable = true;
		col.spacing = 1;
		//col.min_width = 100;
		treeview.append_column(col);
		col_md5 = col;

		//col.sort_column_id = FileViewColumn.GROUP;
		col.clicked.connect(tv_header_clicked);

		// cell text
		var cell_text = new CellRendererText ();
		col.pack_start (cell_text, false);

		// render text
		col.set_cell_data_func (cell_text, (cell_layout, cell, model, iter) => {

			var crt = cell as Gtk.CellRendererText;

			FileItem item;
			model.get (iter, FileViewColumn.ITEM, out item, -1);

			if (item.is_dummy){
				crt.text = "";
			}
			else if (item.checksum_md5.length == 0) {
				crt.text = "--";
			}
			else{
				crt.text = item.checksum_md5;
			}
			
			crt.scale = listview_font_scale;
		});

	}

	private void add_col_symlink_target() {

		// column
		var col = new TreeViewColumn();
		col.title = _("Symlink Target");
		col.clickable = true;
		col.resizable = true;
		col.reorderable = true;
		col.spacing = 1;
		//col.min_width = 100;
		treeview.append_column(col);
		col_symlink_target = col;

		//col.sort_column_id = FileViewColumn.GROUP;
		col.clicked.connect(tv_header_clicked);

		// cell text
		var cell_text = new CellRendererText ();
		col.pack_start (cell_text, false);

		// render text
		col.set_cell_data_func (cell_text, (cell_layout, cell, model, iter) => {

			var crt = cell as Gtk.CellRendererText;

			FileItem item;
			model.get (iter, FileViewColumn.ITEM, out item, -1);

			if (item.is_dummy){
				crt.text = "";
			}
			else if (item.symlink_target.length == 0) {
				crt.text = "--";
			}
			else{
				crt.text = item.symlink_target;
			}
			
			crt.scale = listview_font_scale;
		});

	}

	private void add_col_original_path() {

		// column
		var col = new TreeViewColumn();
		col.title = _("Original Location");
		col.clickable = true;
		col.resizable = true;
		col.reorderable = true;
		col.spacing = 1;
		//col.min_width = 100;
		treeview.append_column(col);
		col_original_path = col;

		//col.sort_column_id = FileViewColumn.GROUP;
		col.clicked.connect(tv_header_clicked);

		// cell text
		var cell_text = new CellRendererText ();
		col.pack_start (cell_text, false);

		// render text
		col.set_cell_data_func (cell_text, (cell_layout, cell, model, iter) => {

			var crt = cell as Gtk.CellRendererText;

			FileItem item;
			model.get (iter, FileViewColumn.ITEM, out item, -1);

			if (item.is_dummy){
				crt.text = "";
			}
			else if (item.trash_original_path.length == 0) {
				crt.text = "--";
			}
			else{
				crt.text = item.trash_original_path;
			}
			
			crt.scale = listview_font_scale;
		});

	}

	private void add_col_deleted_date() {

		// column
		var col = new TreeViewColumn();
		col.title = _("Trashed On");
		col.clickable = true;
		col.resizable = true;
		col.reorderable = true;
		col.spacing = 1;
		//col.min_width = 100;
		treeview.append_column(col);
		col_deletion_date = col;

		//col.sort_column_id = FileViewColumn.GROUP;
		col.clicked.connect(tv_header_clicked);

		// cell text
		var cell_text = new CellRendererText ();
		col.pack_start (cell_text, false);

		// render text
		col.set_cell_data_func (cell_text, (cell_layout, cell, model, iter) => {

			var crt = cell as Gtk.CellRendererText;

			FileItem item;
			model.get (iter, FileViewColumn.ITEM, out item, -1);

			if (item.is_dummy){
				crt.text = "";
			}
			else if (item.trash_deletion_date == null) {
				crt.text = "--";
			}
			else{
				crt.text = item.trash_deletion_date.format ("%Y-%m-%d %H:%M");
			}
			
			crt.scale = listview_font_scale;
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
		col_spacer = col;

		// cell text
		var cell_text = new CellRendererText ();
		col.pack_start (cell_text, false);

		//render text
		col.set_cell_data_func (cell_text, (cell_layout, cell, model, iter) => {

			var crt = cell as Gtk.CellRendererText;

			FileItem item;
			model.get (iter, FileViewColumn.ITEM, out item, -1);

			crt.text = "";
		});
	}

	private void init_column_manager(){

		// set column names
		col_name.set_data<string>("name", "name");
		col_name.set_data<FileViewColumn>("index", FileViewColumn.NAME);
		
		col_indicator.set_data<string>("name", "indicator");
		col_indicator.set_data<FileViewColumn>("index", FileViewColumn.UNSORTABLE);
		
		col_size.set_data<string>("name", "size");
		col_size.set_data<FileViewColumn>("index", FileViewColumn.SIZE);
		
		col_modified.set_data<string>("name", "modified");
		col_modified.set_data<FileViewColumn>("index", FileViewColumn.MODIFIED);
		
		col_compressed.set_data<string>("name", "compressed");
		col_compressed.set_data<FileViewColumn>("index", FileViewColumn.PACKED_SIZE);
		
		col_permissions.set_data<string>("name", "permissions");
		col_permissions.set_data<FileViewColumn>("index", FileViewColumn.PERMISSIONS);
		
		col_owner.set_data<string>("name", "user");
		col_owner.set_data<FileViewColumn>("index", FileViewColumn.OWNER);
		
		col_group.set_data<string>("name", "group");
		col_group.set_data<FileViewColumn>("index", FileViewColumn.GROUP);
		
		col_access.set_data<string>("name", "access");
		col_access.set_data<FileViewColumn>("index", FileViewColumn.ACCESS);
		
		col_mimetype.set_data<string>("name", "mimetype");
		col_mimetype.set_data<FileViewColumn>("index", FileViewColumn.MIMETYPE);
		
		col_filetype.set_data<string>("name", "filetype");
		col_filetype.set_data<FileViewColumn>("index", FileViewColumn.FILETYPE);
		
		col_md5.set_data<string>("name", "md5");
		col_md5.set_data<FileViewColumn>("index", FileViewColumn.HASH_MD5);
		
		col_symlink_target.set_data<string>("name", "symlink_target");
		col_symlink_target.set_data<FileViewColumn>("index", FileViewColumn.SYMLINK_TARGET);
		
		col_original_path.set_data<string>("name", "original_path");
		col_original_path.set_data<FileViewColumn>("index", FileViewColumn.ORIGINAL_PATH);
		
		col_deletion_date.set_data<string>("name", "deletion_date");
		col_deletion_date.set_data<FileViewColumn>("index", FileViewColumn.DELETION_DATE);
		
		col_spacer.set_data<string>("name", "spacer");
		col_spacer.set_data<FileViewColumn>("index", FileViewColumn.UNSORTABLE); 
		
		// load default columns
		tv_manager = new TreeViewColumnManager((Gtk.TreeView) treeview, Main.REQUIRED_COLUMNS, Main.REQUIRED_COLUMNS_END, Main.DEFAULT_COLUMNS, Main.DEFAULT_COLUMN_ORDER);

		tv_manager.set_columns(App.selected_columns);

		update_column_headers();
	}

	private Gee.ArrayList<FileItem> treeview_set_sort_func(Gee.ArrayList<FileItem> list){

		switch (sort_column_index) {
		case FileViewColumn.NAME:
			list.sort((a, b) => {
				
				if (a.file_type != b.file_type){
					if (a.file_type == FileType.DIRECTORY) {
						return -1;
					}
					else {
						return +1;
					}
				}
				
				if (sort_column_desc) {
					return -1 * a.compare_to(b);
				}
				else{
					return a.compare_to(b);
				}
			});
			break;

		case FileViewColumn.SIZE:
			list.sort((a, b) => {

				if (a.file_type != b.file_type){
					if (a.file_type == FileType.DIRECTORY) {
						return -1;
					}
					else {
						return +1;
					}
				}
				
				if (sort_column_desc) {
					return -1 * ((int)(a.file_size - b.file_size));
				}
				else {
					return ((int)(a.file_size - b.file_size));
				}
			});
			break;

		case FileViewColumn.PACKED_SIZE:
			list.sort((a, b) => {

				if (a.file_type != b.file_type){
					if (a.file_type == FileType.DIRECTORY) {
						return -1;
					}
					else {
						return +1;
					}
				}
				
				if (sort_column_desc) {
					return -1 * ((int)(a.size_compressed - b.size_compressed));
				}
				else {
					return ((int)(a.size_compressed - b.size_compressed));
				}
			});
			break;

		case FileViewColumn.MODIFIED:
			list.sort((a, b) => {

				if (a.file_type != b.file_type){
					if (a.file_type == FileType.DIRECTORY) {
						return -1;
					}
					else {
						return +1;
					}
				}
				
				if (sort_column_desc) {
					return -1 * a.modified.compare(b.modified);
				}
				else {
					return a.modified.compare(b.modified);
				}
			});
			break;

		case FileViewColumn.PERMISSIONS:
			list.sort((a, b) => {

				if (a.file_type != b.file_type){
					if (a.file_type == FileType.DIRECTORY) {
						return -1;
					}
					else {
						return +1;
					}
				}

				if (a.permissions == b.permissions){
					if (sort_column_desc) {
						return -1 * a.compare_to(b);
					}
					else{
						return a.compare_to(b);
					}
				}
				
				if (sort_column_desc) {
					return -1 * strcmp(a.permissions, b.permissions);
				}
				else {
					return strcmp(a.permissions, b.permissions);
				}
			});
			break;

		case FileViewColumn.OWNER:
			list.sort((a, b) => {

				if (a.file_type != b.file_type){
					if (a.file_type == FileType.DIRECTORY) {
						return -1;
					}
					else {
						return +1;
					}
				}

				if (a.owner_user == b.owner_user){
					if (sort_column_desc) {
						return -1 * a.compare_to(b);
					}
					else{
						return a.compare_to(b);
					}
				}
				
				if (sort_column_desc) {
					return -1 * strcmp(a.owner_user, b.owner_user);
				}
				else {
					return strcmp(a.owner_user, b.owner_user);
				}
			});
			break;

		case FileViewColumn.GROUP:
			list.sort((a, b) => {

				if (a.file_type != b.file_type){
					if (a.file_type == FileType.DIRECTORY) {
						return -1;
					}
					else {
						return +1;
					}
				}

				if (a.owner_group == b.owner_group){
					if (sort_column_desc) {
						return -1 * a.compare_to(b);
					}
					else{
						return a.compare_to(b);
					}
				}
				
				if (sort_column_desc) {
					return -1 * strcmp(a.owner_group, b.owner_group);
				}
				else {
					return strcmp(a.owner_group, b.owner_group);
				}
			});
			break;

		case FileViewColumn.ACCESS:
			list.sort((a, b) => {

				if (a.file_type != b.file_type){
					if (a.file_type == FileType.DIRECTORY) {
						return -1;
					}
					else {
						return +1;
					}
				}

				if (a.access_flags == b.access_flags){
					if (sort_column_desc) {
						return -1 * a.compare_to(b);
					}
					else{
						return a.compare_to(b);
					}
				}
				
				if (sort_column_desc) {
					return -1 * strcmp(a.access_flags, b.access_flags);
				}
				else {
					return strcmp(a.access_flags, b.access_flags);
				}
			});
			break;

		case FileViewColumn.MIMETYPE:
			list.sort((a, b) => {

				if (a.file_type != b.file_type){
					if (a.file_type == FileType.DIRECTORY) {
						return -1;
					}
					else {
						return +1;
					}
				}

				if (a.content_type == b.content_type){
					if (sort_column_desc) {
						return -1 * a.compare_to(b);
					}
					else{
						return a.compare_to(b);
					}
				}
				
				if (sort_column_desc) {
					return -1 * strcmp(a.content_type, b.content_type);
				}
				else {
					return strcmp(a.content_type, b.content_type);
				}
			});
			break;

		case FileViewColumn.FILETYPE:
			list.sort((a, b) => {

				if (a.file_type != b.file_type){
					if (a.file_type == FileType.DIRECTORY) {
						return -1;
					}
					else {
						return +1;
					}
				}
				
				if (a.content_type_desc == b.content_type_desc){
					if (sort_column_desc) {
						return -1 * a.compare_to(b);
					}
					else{
						return a.compare_to(b);
					}
				}
				
				if (sort_column_desc) {
					return -1 * strcmp(a.content_type_desc.down(), b.content_type_desc.down());
				}
				else {
					return strcmp(a.content_type_desc.down(), b.content_type_desc.down());
				}
			});
			break;

		case FileViewColumn.SYMLINK_TARGET:
			list.sort((a, b) => {
				
				if (a.file_type != b.file_type){
					if (a.file_type == FileType.DIRECTORY) {
						return -1;
					}
					else {
						return +1;
					}
				}
				
				if (sort_column_desc) {
					return -1 * strcmp(a.symlink_target, b.symlink_target);
				}
				else {
					return strcmp(a.symlink_target, b.symlink_target);
				}
			});
			break;

		case FileViewColumn.ORIGINAL_PATH:
			list.sort((a, b) => {
				
				if (a.file_type != b.file_type){
					if (a.file_type == FileType.DIRECTORY) {
						return -1;
					}
					else {
						return +1;
					}
				}
				
				if (sort_column_desc) {
					return -1 * strcmp(a.trash_original_path, b.trash_original_path);
				}
				else {
					return strcmp(a.trash_original_path, b.trash_original_path);
				}
			});
			break;

		case FileViewColumn.DELETION_DATE:
			list.sort((a, b) => {

				if (a.file_type != b.file_type){
					if (a.file_type == FileType.DIRECTORY) {
						return -1;
					}
					else {
						return +1;
					}
				}
				
				if (sort_column_desc) {
					return -1 * a.trash_deletion_date.compare(b.trash_deletion_date);
				}
				else {
					return a.trash_deletion_date.compare(b.trash_deletion_date);
				}
			});
			break;
		}

		return list;
	}

	private void sort(){
		update_column_headers();
		refresh(false, false);
	}
	
	private void tv_header_clicked(Gtk.TreeViewColumn tv_column){

		var col_index = tv_column.get_data<FileViewColumn>("index");

		log_debug("sort_column_previous: %d".printf(sort_column_index));
		log_debug("sort_column_order: %s".printf(sort_column_desc ? "desc" : "asc"));
		
		if (sort_column_index == col_index) {
			sort_column_desc = !sort_column_desc;
		}
		else {
			sort_column_index = col_index;
			sort_column_desc = false;
		}

		log_debug("sort_column_new: %d".printf(sort_column_index));
		log_debug("sort_column_order: %s".printf(sort_column_desc ? "desc" : "asc"));

		sort();
	}

	public FileViewColumn get_sort_column_index(){
		return (FileViewColumn) sort_column_index;
	}

	public bool get_sort_column_desc(){
		return sort_column_desc;
	}

	public void set_sort_column_by_index(FileViewColumn col_index){
		log_debug("set_sort_column_by_index(): %s".printf(col_index.to_string()));
		sort_column_index = col_index;
		sort();
	}

	public void set_sort_column_by_treeviewcolumn(Gtk.TreeViewColumn tv_column){
		log_debug("set_sort_column_by_treeviewcolumn(): %s".printf(tv_column.title));
		var col_index = tv_column.get_data<FileViewColumn>("index");
		sort_column_index = col_index;
		sort();
	}

	public void set_sort_column_desc(bool active){
		log_debug("set_sort_column_desc(): %s".printf(active.to_string()));
		sort_column_desc = active;
		sort();
	}

	private void update_column_headers(){

		foreach(var col in tv_manager.get_all_columns()){

			var col_index = col.get_data<FileViewColumn>("index");
			
			if (col_index == sort_column_index) {
				var txt = col.title.replace("↓","").replace("↑","").strip();
				if (sort_column_desc){
					txt = txt + " ↑";
				}
				else{
					txt = txt + " ↓";
				}
				col.title = txt;
			}
			else {
				col.title = col.title.replace("↓","").replace("↑","").strip();
			}
		}
	}

	public string get_columns(){
		return tv_manager.get_columns();
	}

	public Gee.ArrayList<TreeViewColumn> get_all_columns(){
		return tv_manager.get_all_columns();
	}

	public void set_columns(string columns){
		tv_manager.set_columns(columns);
	}

	public void add_column(string name){
		log_debug("add_column: %s".printf(name));
		tv_manager.add_column(name);
	}

	public void remove_column(string name){
		log_debug("remove_column: %s".printf(name));
		tv_manager.remove_column(name);
	}

	public void reset_columns(){
		tv_manager.reset_columns();
	}

	// active pane indicators ------------------------
	
	private void init_active_indicator_top(){

		active_indicator_top = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
		active_indicator_top.set_size_request(-1,2);
		add(active_indicator_top);
		
		string css = " background-color: #2196F3; ";
		gtk_apply_css(new Gtk.Widget[] { active_indicator_top }, css);

		//css = " color: #ffffff; ";
		//gtk_apply_css(new Gtk.Widget[] { label }, css);
	}

	public void set_active_indicator(bool is_active){
		string css = " background-color: @content_view_bg; ";
		if (is_active && (App.main_window.layout_box.get_panel_layout() != PanelLayout.SINGLE)){
			css = " background-color: #2196F3;"; //#C0C0C0
		}
		gtk_apply_css(new Gtk.Widget[] { active_indicator_top }, css);
	}

	// key press -------------------------

	private void connect_key_press_handler(){
		treeview.key_press_event.connect(on_key_press_event);
		iconview.key_press_event.connect(on_key_press_event);
	}

	/*private void disconnect_key_press_handler(){
		treeview.key_press_event.disconnect(on_key_press_event);
		iconview.key_press_event.disconnect(on_key_press_event);
	}*/
	
	private bool on_key_press_event(Gdk.EventKey event){

		log_debug("key_name: %s, state: %s".printf(Gdk.keyval_name(event.keyval), event.state.to_string()));

        if (event.is_modifier == 1){ return false; }

        switch(event.state){
		case Gdk.ModifierType.CONTROL_MASK:
		case Gdk.ModifierType.SHIFT_MASK:
		//case Gdk.ModifierType.LOCK_MASK: // caps lock and shift lock
		case Gdk.ModifierType.SUPER_MASK:
		case Gdk.ModifierType.HYPER_MASK:
		case Gdk.ModifierType.META_MASK:
			return false;
		}

		string key_name = Gdk.keyval_name(event.keyval);
		string key_string = event.str;
		
		log_debug("key_string: %s, key_name: %s".printf(key_string, key_name));
		
		switch(key_name.down()){
		case "up":
		case "down":
		case "left":
		case "right":
		case "tab":
			return false;
		case "enter":
		case "return":
			pane.pathbar.finish_editing();
			window.pathbar.finish_editing();
			return false;
		}

		if ((current_item != null) && (current_item.is_local) && !pane.selection_bar.visible){
			pane.selection_bar.open_panel(key_string, false);
			return true;
		}
		
		return false;
	}

	// DND ------------------------------------

	//private bool on_drag_data_get (TreePath path, SelectionData selection_data){
	private void on_drag_data_get (Gdk.DragContext context, Gtk.SelectionData data, uint info, uint time) {

		log_debug("on_drag_data_get");

		var list = get_selected_items();

		var uris = new Gee.ArrayList<string>();
		foreach(var item in list){
			uris.add("file://" + item.file_path);
			log_debug("dnd get: %s".printf("file://" + item.file_path));
		}
		data.set_uris((string[]) uris.to_array());

		log_debug("on_drag_data_get: exit");
	}

	private void on_drag_data_received (Gdk.DragContext drag_context, int x, int y, Gtk.SelectionData data, uint info, uint time) {

		log_debug("on_drag_data_received");

		// get selected_items
		var selected_items = new Gee.ArrayList<FileItem>();
		foreach (string uri in data.get_uris()){
			string item_path = uri.replace("file://","").replace("file:/","");
			item_path = Uri.unescape_string (item_path);
			selected_items.add(new FileItem.from_path(item_path));
		}

		if (selected_items.size == 0){ return; }

		log_debug("action.dropped()");

		// save
		var action = new ProgressPanelFileTask(pane, selected_items, FileActionType.COPY);
		action.set_source(new FileItem.from_path(selected_items[0].file_location));
		window.pending_action = action;

		Gtk.drag_finish (drag_context, true, false, time);

		paste();
    }

	/*private void set_as_drag_source(bool set_dnd){
		if (set_dnd){
			Gtk.drag_source_set(treeview, Gdk.ModifierType.BUTTON1_MASK, MainWindow.drop_target_types, Gdk.DragAction.COPY);
		}
		else{
			Gtk.drag_source_unset(treeview);
		}
	}

	private void set_as_drag_destination(bool set_dnd){
		if (set_dnd){
			Gtk.drag_dest_set(treeview, Gtk.DestDefaults.ALL, MainWindow.drop_target_types, Gdk.DragAction.COPY);
		}
		else{
			Gtk.drag_dest_unset(treeview);
		}
	}*/

	// properties -----------------------------

	public bool has_media {
		get {
			return (current_item != null) && current_item.is_media_directory;
		}
	}

	public bool mediaview_exclude {
		get {
			return (current_item != null) && App.mediaview_exclude.contains(current_item.file_path);
		}
	}

	public bool mediaview_include {
		get {
			return (current_item != null) && App.mediaview_include.contains(current_item.file_path);
		}
	}

	public int listview_icon_size_stock{
		get {
			return gtk_width_to_icon_size(listview_icon_size);
		}
	}

	public int iconview_icon_size_stock{
		get {
			return gtk_width_to_icon_size(iconview_icon_size);
		}
	}

	public int tileview_icon_size_stock{
		get {
			return gtk_width_to_icon_size(tileview_icon_size);
		}
	}

	public bool use_emblems{
		get {
			switch(view_mode){
			case ViewMode.LIST:
			default:
				return App.listview_emblems;
			case ViewMode.ICONS:
				return App.iconview_emblems;
			case ViewMode.TILES:
				return App.tileview_emblems;
			case ViewMode.MEDIA:
				return false;
			}
		}
	}

	public bool use_thumbs{
		get {
			switch(view_mode){
			case ViewMode.LIST:
			default:
				return App.listview_thumbs;
			case ViewMode.ICONS:
				return App.iconview_thumbs;
			case ViewMode.TILES:
				return App.tileview_thumbs;
			case ViewMode.MEDIA:
				return true;
			}
		}
	}

	public bool use_transparency{
		get {
			switch(view_mode){
			case ViewMode.LIST:
			default:
				return App.listview_transparency;
			case ViewMode.ICONS:
				return App.iconview_transparency;
			case ViewMode.TILES:
				return App.tileview_transparency;
			case ViewMode.MEDIA:
				return false;
			}
		}
	}

	private int treemodel_icon_size{
		get {
			int icon_size;

			switch(view_mode){
			case ViewMode.LIST:
			default:
				icon_size = listview_icon_size;
				break;
			case ViewMode.ICONS:
				icon_size = iconview_icon_size;
				break;
			case ViewMode.TILES:
				icon_size = tileview_icon_size;
				break;
			case ViewMode.MEDIA:
				icon_size = 256;
				break;
			}

			return icon_size;
		}
	}

	public string paneid {
		owned get {
			return "[%d:%d] ".printf(panel.number, pane.tab.tab_index + 1);
		}
	}

	public void set_zoom_from_global(){

		listview_font_scale = App.listview_font_scale;
		listview_icon_size = App.listview_icon_size;
		listview_row_spacing = App.listview_row_spacing;

		iconview_icon_size = App.iconview_icon_size;
		iconview_row_spacing = App.iconview_row_spacing;
		iconview_column_spacing  = App.iconview_column_spacing;

		tileview_icon_size = App.tileview_icon_size;
		tileview_row_spacing = App.tileview_row_spacing;
		tileview_padding  = App.tileview_padding;
	}

	public void save_zoom_as_global(){

		App.listview_font_scale = listview_font_scale;
		App.listview_icon_size = listview_icon_size;
		App.listview_row_spacing = listview_row_spacing;

		App.iconview_icon_size = iconview_icon_size;
		App.iconview_row_spacing = iconview_row_spacing;
		App.iconview_column_spacing  = iconview_column_spacing;

		App.tileview_icon_size = tileview_icon_size;
		App.tileview_row_spacing = tileview_row_spacing;
		App.tileview_padding  = tileview_padding;
	}

	// view mode ------------------------------------------

	public ViewMode get_view_mode(){
		return view_mode;
	}

	public ViewMode get_view_mode_user(){
		return view_mode_user;
	}

	public void set_view_mode(ViewMode _view_mode, bool set_by_user = true){

		//if (view_mode == _view_mode) { return; }

		if (current_item != null){
			if (mediaview_include && (view_mode == ViewMode.MEDIA) && (_view_mode != ViewMode.MEDIA)){
				App.mediaview_include.remove(current_item.file_path);
				App.save_folder_selections();
			}

			if (mediaview_exclude && (view_mode != ViewMode.MEDIA) && (_view_mode == ViewMode.MEDIA)){
				App.mediaview_exclude.remove(current_item.file_path);
				App.save_folder_selections();
			}
		}

		view_mode = _view_mode;

		if (set_by_user){
			view_mode_user = _view_mode;
		}

		refresh(false, false);
	}

	public void set_view_mode_user(){
		
		view_mode = view_mode_user;
		media_view_exited = true;
		log_debug("set_view_mode_user(): %s".printf(view_mode.to_string()));
		refresh(false, false);
	}
	
	private void set_view_mode_for_location(){

		if (current_item == null){ return; }
		
		log_debug("media=%s, photos=%d, videos=%d".printf(
			current_item.is_media_directory.to_string(), current_item.count_photos, current_item.count_videos));

		//if (has_media && !mediaview_exclude && !media_view_exited){
			//view_mode = ViewMode.MEDIA;
			//show_folders_in_media_view = true;
			//show_other_files_in_media_view = false;
			//log_debug("changed view mode: %s".printf(view_mode.to_string()), true);
		//}
		//else{
			//view_mode = view_mode_user;
			//log_debug("changed view mode: %s".printf(view_mode.to_string()));
		//}

		pane.mediabar.refresh();

		//log_debug("view_mode: %s, %s".printf(view_mode.to_string(), view_mode_user.to_string()));
	}

	
	// change current directory ----------------------------------

	public FileItem? set_view_path(string path, bool update_history = true){

		log_debug(string.nfill(80,'-'));
		log_debug("FileViewList: set_view_path(): %s".printf(path));

		if (path.strip().length == 0){
			clear_views();
			//gtk_messagebox(_("Path is Empty!"), "Path: (empty)", window, true);
			return null;
		}

		if (pane.tab.locked_path.length > 0){
			
			if (!path.has_prefix(pane.tab.locked_path)){
				
				open_in_new_tab(path);

				return null;
			}
		}

		current_location = "";
		if (path.contains("://")){
			log_debug("path is uri");
			var file = File.new_for_uri(path);
			if (file.query_exists() && (file.get_path() != null)){
				current_location = file.get_path();
				log_debug("resolved uri to path: %s".printf(current_location));
			}
			else{
				current_location = path; // some uri don't have a file_path
				log_debug("failed to resolve uri to path: file does not exist");
			}
		}
		else {
			log_debug("path is local");
			current_location = path; // non-empty path - display in pathbar
		}

		log_debug("current_location: %s".printf(current_location));
		
		FileItem item = FileItem.find_in_cache(current_location);
		
		if (item != null){
			log_debug("cache: found: %s".printf(current_location), true);
		}
		else{
			log_debug("cache: not found: %s".printf(current_location), true);
			
			if (current_location.down().has_prefix("trash://")){
				//App.trash.query_items(); //will be queried by set_view_item()
				item = App.trashcan;
			}
			else if (dir_exists(current_location)){
				item = new FileItem.from_path_and_type(current_location, FileType.DIRECTORY, true);
				log_debug("created file item: %s".printf(current_location));
			}
			else if (uri_exists(current_location)){
				item = new FileItem.from_path_and_type(current_location, FileType.DIRECTORY, true);
				log_debug("created file item: %s".printf(current_location));
			}
			else{
				log_debug("uri does not exist");
				pane.refresh_pathbars();
				set_overlay_on_invalid_path();
				return null;
			}
		}

		return set_view_item(item, update_history);
	}

	public FileItem set_view_item(FileItem item, bool update_history = true){

		log_debug(string.nfill(80,'-'));
		log_debug("FileViewList: set_view_item(%s): %d".printf(item.file_path, item.children.size));

		log_trace("view_changed: %s".printf(item.file_path));

		FileItem.add_to_cache(item);
		
		//var previous_item = current_item;
		current_item = item;
		current_location = current_item.display_path;

		if ((current_item is FileItemCloud) || (current_item is FileItemArchive) || current_item.is_remote){
			current_location_is_virtual = true;
		}
		else{
			current_location_is_virtual = false;
		}

		clear_filter();
		pane.selection_bar.close_panel(true); // force

		if (update_history){
			history_add(item);
			history_reset();
		}

		pane.messages.clear();
		
		pane.pathbar.refresh(); // update pathbar before starting async query

		media_view_exited = false;
		
		//query_items();
		
		//log_debug("FileViewList: set_view_item(): query_items(): done");

		//set_view_mode_for_location();

		//view_refresher_cancelled = true;

		refresh(true, true); // requery

		set_columns_for_special_locations();

		window.save_session();

		view_initialized = true;

		log_debug("FileViewList: set_view_item(): done");
		log_debug(string.nfill(80,'-'));
		
		return current_item;
	}

	private void set_columns_for_special_locations(){
		
		if (current_item.is_trash){
			set_columns("name,size,deletion_date,original_path");
		}
		else{
			set_columns(App.selected_columns);
		}
	}
	
	// refresh  ---------------------------------------
	
	public void refresh(bool requery, bool requery_subfolders) {

		log_debug("FileViewList: refresh(): %s".printf(requery.to_string()));

		cancel_monitors();

		if (requery && (current_item != null)){
			query_items();
		}

		if (current_item != null){
			remove_overlay();
		}

		set_view_mode_for_location();

		refresh_treeview(); // will refresh icon_view also

		refresh_view_mode();

		refresh_single_click();

		pane.mediabar.refresh();

		if (current_item == null){ return; }
		
		add_monitor(current_item);

		// add overlay --------------------------------------
		
		if (current_item is FileItemCloud){
			
			var cloud_item = (FileItemCloud) current_item;
			
			// check error
			if ((cloud_item.children.keys.size == 0) && (cloud_item.error_msg.length > 0)){
				//et_overlay_on_error(cloud_item.error_msg);
				
				string txt = _("Error Connecting to Server");
				string msg = cloud_item.error_msg + "\n\n" + _("Check if internet connection is active");
				gtk_messagebox(txt, msg, window, true);
				
				//string title =  _("Error");
				//OSDNotify.notify_send("Error", std_err, 1000, "low", "warning");
			}
		}

		// check empty
		if (current_item.children.size == 0){
			if (!current_item.can_read && current_item.permission_denied){
				set_overlay_on_not_readable();
			}
			else{
				set_overlay_on_empty();
			}
		}

		changed(); //informs FileViewPane to update other components like statusbar, etc

		if (requery_subfolders){ 
			query_subfolders();
		}
	}

	public void refresh_treeview() {

		log_debug("FileViewList: treeview_refresh()");

		init_thumbnail_updater();

		window.layout_box.save_pane_positions();

		var selections = get_selected_file_paths();

		// set model
		
		store = new Gtk.TreeStore(6,
			typeof(FileItem),
			typeof(Gdk.Pixbuf), // ICON
			typeof(string), // NAME
			typeof(string), // TILE_MARKUP
			typeof(ThumbTask?), // THUMBKEY
			typeof(string) // size
		);
		
		if (current_item == null){
			treeview.set_model(store);
			treeview.columns_autosize();
			log_debug("current_item is NULL");
			return;
		}

		var timer = timer_start();

		var cached = TreeModelCache.find_model(current_item.file_path, treemodel_icon_size);
		if (cached != null){
			store = cached;
		}
		else{

			var list = new ArrayList<FileItem>();
			foreach(string key in current_item.children.keys) {
				list.add(current_item.children[key]);
			}
			list = treeview_set_sort_func(list);

			//log_debug("list sorted");

			/*if (view.current_item.parent != null) {
				var dummy = new FileItem.dummy(FileType.DIRECTORY);
				//dummy.tag = view.current_item.tag;
				dummy.file_name = "..";
				dummy.parent = view.current_item.parent;

				//add row for parent dir
				//model.append(out iter0, null);
				//model.set (iter0, 0, dummy);
			}*/

			foreach(var item in list) {

				var iter0 = append_item_to_treeview(item);

				if (item.file_type == FileType.DIRECTORY){

					/* performance hack: append the item itself as it's child iter
					 * this will make the node display expanders in treeview
					 * we will repopulate this node correctly when user tries to expand it
					 * */
					append_item_to_treeview_item(ref iter0, item, false, false);
				}
			}

			TreeModelCache.add(current_item, store, treemodel_icon_size);
		}

		log_trace("model created: %s, %s".printf(current_item.file_name, timer_elapsed_string(timer)));
		timer_restart(timer);

		treefilter = new Gtk.TreeModelFilter(store, null);
		treefilter.set_visible_func(filter_view);
		treeview.set_model(treefilter);
		treeview.columns_autosize();

		if ((view_mode == ViewMode.ICONS) || (view_mode == ViewMode.TILES) || (view_mode == ViewMode.MEDIA)){
			refresh_iconview();
		}
  
		window.layout_box.restore_pane_positions();

		if (thumbnail_update_is_required && window.window_is_ready){
			thumbnail_update_is_required = false;
			start_thumbnail_updater();
		}

		select_items_by_file_path(selections);

		log_trace("tree refreshed: %s, %s".printf(current_item.file_name, timer_elapsed_string(timer)));

		log_debug("FileViewList: treeview_refresh(): exit");
	}

	public void refresh_iconview(){

		iconview.set_model(treefilter); // use listview model

		if (view_mode == ViewMode.ICONS){
			iconview.row_spacing = iconview_row_spacing;
			iconview.item_padding = 0;
			iconview.item_width = iconview_column_spacing;
			iconview.spacing = 0;
		}
		else if (view_mode == ViewMode.MEDIA){
			iconview.row_spacing = 0;
			iconview.item_padding = 0;
			iconview.item_width = 0;
			iconview.spacing = 0;
		}
		else if (view_mode == ViewMode.TILES){
			iconview.row_spacing = tileview_row_spacing;
			iconview.item_padding = tileview_padding;
			iconview.item_width = get_adjusted_column_width_for_tileview();
			iconview.spacing = 0;
		}
	}

	public void refresh_view_mode(){

		log_debug("FileViewList: refresh_view_mode(): %s, %s".printf(view_mode.to_string(), view_mode_user.to_string()));

		switch (view_mode){
		case ViewMode.ICONS:
		case ViewMode.MEDIA:
			gtk_hide(scrolled_treeview);
			gtk_show(scrolled_iconview);

			iconview.item_orientation = Gtk.Orientation.VERTICAL;
			iconview.set_text_column(FileViewColumn.NAME);
			iconview.set_markup_column(-1);
			break;

		case ViewMode.TILES:
			gtk_hide(scrolled_treeview);
			gtk_show(scrolled_iconview);

			iconview.item_orientation = Gtk.Orientation.HORIZONTAL;
			iconview.set_text_column(-1);
			iconview.set_markup_column(FileViewColumn.TILE_MARKUP);
			break;

		case ViewMode.LIST:
			gtk_show(scrolled_treeview);
			gtk_hide(scrolled_iconview);
			break;
		}
	}

	public void refresh_single_click(){
		treeview.activate_on_single_click = App.single_click_activate;
		treeview.hover_selection = App.single_click_activate;
		//treeview.enable_grid_lines = Gtk.TreeViewGridLines.BOTH;

		if (App.single_click_activate){
			treeview.get_selection().mode = Gtk.SelectionMode.SINGLE;
		}
		else {
			treeview.get_selection().mode = Gtk.SelectionMode.MULTIPLE;
		}

		iconview.activate_on_single_click = App.single_click_activate;
		//iconview.hover_selection = App.single_click_activate;
	}

	public void refresh_hidden(){
		log_debug("action.refresh_hidden()");
		pane.statusbar.refresh_summary();
		window.statusbar.refresh_summary();
		refresh(false, false);
	}

	// ------------------------------------------
	
	private bool query_items_thread_running = false;
	
	private void query_items(){

		log_debug("FileViewList: query_items(): enter");

		if (current_item == null){
			log_debug("FileViewList: query_items(): current_item is NULL");
			return;
		}
		
		try {
			//log_debug("FileViewList: query_items(): create thread");
			query_items_thread_running = true;
			Thread.create<void> (query_items_thread, true);
		}
		catch (Error e) {
			log_error("FileViewList: query_items_thread()");
			query_items_thread_running = false;
			log_error (e.message);
		}

		sleep(100);

		int elapsed = 0;
		bool overlay_added = false;
		while (query_items_thread_running){
			//log_debug("loop");
			sleep(100);
			elapsed += 100;
			if (elapsed == 500){
				set_overlay_on_loading();
				overlay_added = true;
			}
			gtk_do_events();
		}

		if (overlay_added){
			remove_overlay();
		}

		log_debug("FileViewList: query_items(): exit");
	}
	
	private void query_items_thread(){
		
		log_debug("FileViewList: query_items_thread(): enter");

		if (current_item == null){
			//log_debug("FileViewList: query_items_thread(): current_item is NULL");
			query_items_thread_running = false;
			return;
		}

		sleep(query_items_delay);
		query_items_delay = 0;
		
		//var cached = TreeModelCache.find_file_item(current_item.file_path);

		//if (cached == null){

			var timer = timer_start();

			if (current_item.is_trash){
				log_debug("FileViewList: query_items_thread(): current_item.is_trash");
				App.trashcan.query_items(true);
				current_item = App.trashcan;
			}
			else if (current_item is FileItemArchive){

				var arch = (FileItemArchive) current_item;

				//query_items_thread_list_archive();
				
				if (!arch.is_archived_item){
					log_debug("FileViewList: query_items_thread(): FileItemArchive");
					arch.query_children(-1, true); // TODO:2: skip if file date not changed
					log_debug("FileViewList: query_items_thread(): FileItemArchive: exit");
				}
				else{
					// children are already queried
				}
			}
			else{
				log_debug("FileViewList: query_items_thread(): current_item is FileItem");
				//log_debug("FileViewList: query_items_thread(): current_item.query_children(1)");
				current_item.query_children(1, false);
			}

			log_trace("FileViewList: query_items_thread(): %s".printf(timer_elapsed_string(timer)));

			log_debug("FileViewList: query_items_thread(): %d".printf(current_item.children.size));
		//}

		log_debug("FileViewList: query_items_thread(): exit");
		query_items_thread_running = false;
	}

	// ------------------------------------------
	
	private bool query_subfolders_thread_running = false;
	private bool query_subfolders_thread_cancelled = false;
	
	private void query_subfolders(){

		//return;
		
		if (current_item == null){ return; }
		if (pane.file_operations.size > 0){ return; }

		if (!App.query_subfolders) { return; }

		log_debug("FileViewList: query_subfolders(): enter");
		
		// cancel running thread
		if (query_subfolders_thread_running){
			log_debug("FileViewList: query_subfolders(): cancel_running_thread");
			query_subfolders_thread_cancelled = true;
		}

		// wait for thread to exit
		while (query_subfolders_thread_running){
			sleep(200);
			gtk_do_events();
		}

		try {
			//log_debug("FileViewList: query_items(): create thread");
			query_subfolders_thread_running = true;
			query_subfolders_thread_cancelled = false;
			Thread.create<void> (query_subfolders_thread, true);
		}
		catch (Error e) {
			log_error("FileViewList: query_subfolders_thread()");
			query_subfolders_thread_running = false;
			log_error (e.message);
		}
	}
	
	private void query_subfolders_thread(){
		
		log_debug("FileViewList: query_subfolders_thread()");

		//var timer = timer_start();

		bool count_changed = false;
		
		if ((current_item != null) && !current_item.is_trash && (current_item is FileItemArchive == false)){

			Timeout.add (1000, () => {
				return refresh_listview_size_column();
			});
			
			// statusbar  -----------------------
		
			string msg = _("Counting items...");
			pane.statusbar.show_spinner(msg);
			window.statusbar.show_spinner(msg);

			// query subfolders --------------------

			var list = current_item.children.values;
			
			foreach(var subitem in list){
				
				if (query_subfolders_thread_cancelled) { break; }
				
				if (subitem.is_directory){

					if ((subitem is FileItemCloud) && (subitem.children.size > 0)){ continue; } // performance hack for cloud folders
					
					int count_before = subitem.children.size;
					subitem.query_children(1, false);
					int count_after = subitem.children.size;
					if (count_before != count_after){
						count_changed = true;
					}
				}
			}

			pane.statusbar.hide_spinner();
			window.statusbar.hide_spinner();	
		}

		//log_trace("FileViewList: query_subfolders_thread(): %s".printf(timer_elapsed_string(timer)));

		log_debug("FileViewList: query_subfolders_thread(): exit");

		query_subfolders_thread_running = false;
	}

	private bool refresh_listview_size_column(){
		if (!query_subfolders_thread_cancelled){
			refresh_size_column();
		}
		return query_subfolders_thread_running;
	}

	private int get_adjusted_column_width_for_tileview(){
		int base_width = 150;
		return (base_width + (tileview_icon_size - 48));
	}

	// ------------------------------------------
	
	// used by select_none() to cancel task
	private bool calculate_dirsize_running = false;
	private FileTask calculate_dirsize_task = null;
	
	public void calculate_directory_sizes(){

		if ((current_item == null) || current_item.is_trash || (current_item is FileItemArchive)){ return; } // (current_item is FileItemCloud);
		
		var selected_items = get_selected_items().to_array();

		bool some_folders_selected = false;
		foreach(var item in selected_items){
			if (item.is_directory){
				some_folders_selected = true;
				break;
			}
		}
		
		if ((selected_items.length == 0) || !some_folders_selected){
			selected_items = current_item.children.values.to_array();
		}

		log_debug("FileViewList: calculate_directory_sizes()");

		// statusbar  -----------------------
		
		string msg = _("Calculating dir size...");
		pane.statusbar.show_spinner(msg);
		window.statusbar.show_spinner(msg);

		// start task ------------------------
		
		var task = new FileTask();
		
		task.complete.connect(()=>{
			
			calculate_dirsize_running = false;
			
			pane.statusbar.hide_spinner();
			window.statusbar.hide_spinner();

			refresh_size_column();
		});
		
		calculate_dirsize_task = task;
		
		// execute
		task.calculate_dirsize_async(selected_items);

		Timeout.add (500, () => {
			refresh_size_column();
			return task.is_running;
		});
	}

	private void refresh_size_column(){

		switch (view_mode){
		case ViewMode.LIST:
			store.foreach ((model, path, iter) => {
				FileItem item;
				store.get(iter, FileViewColumn.ITEM, out item, -1);
				store.set(iter, FileViewColumn.LV_SIZE, item.file_size_formatted); // update
				return false;
			});
			break;
		
		case ViewMode.TILES:
			store.foreach ((model, path, iter) => {
				FileItem item;
				store.get(iter, FileViewColumn.ITEM, out item, -1);
				store.set(iter, FileViewColumn.TILE_MARKUP, item.tile_markup); // update
				return false;
			});
			break;
			
		case ViewMode.ICONS:
		case ViewMode.MEDIA:
			// not needed
			break;
		}
	}

	// refresh treeview ------------------------

	private TreeIter? append_item_to_treeview(FileItem item) {

		TreeIter iter1;
		store.append (out iter1, null);
		set_iter_from_item(iter1, item, true, true);

		//log_debug("Append iter: %s".printf(item.file_path));

		return iter1;
	}

	private TreeIter? append_item_to_treeview_by_file_path(string file_path){

		if (current_item == null) { return null; }

		var item = current_item.add_child_from_disk(file_path, 1);

		//log_debug("Append iter: %s".printf(file_path));

		return append_item_to_treeview(item);
	}

	private TreeIter set_iter_from_item(TreeIter iter1, FileItem item, bool load_icon, bool load_thumb) {

		//log_debug("set_iter_from_item: %s".printf(item.file_path));

		//log_debug("%s, %s, %s".printf(item.file_path,item.file_title, item.file_extension), true);
		
		Gdk.Pixbuf pixbuf = null;
		ThumbTask task = null;
		
		if (load_icon){
			
			pixbuf = item.get_image(treemodel_icon_size,
				load_thumb && use_thumbs && !current_location_is_virtual,
				use_transparency, use_emblems, out task);

			if (use_thumbs && (task != null)){
				thumbnail_update_is_required = true;
				thumbnail_pending++;
			}
		}

		string name = item.display_name;
		if (App.iconview_trim_names && (name.length > 30)){
			name = name[0:29] + "...";
		}

		store.set (iter1, FileViewColumn.ITEM, item); // used by list view
		store.set (iter1, FileViewColumn.ICON, pixbuf); // used by all views
		store.set (iter1, FileViewColumn.NAME, name); // only used by icon view
		store.set (iter1, FileViewColumn.TILE_MARKUP, item.tile_markup); // only used by tile view
		store.set (iter1, FileViewColumn.THUMBKEY, task); // used by thumbnail updater
		store.set (iter1, FileViewColumn.LV_SIZE, item.file_size_formatted); // used by Size column in ListView

		//log_debug("set_iter_from_item: %s: ok".printf(item.file_path));

		return iter1;
	}

	private void append_item_children_to_iter(ref TreeIter iter0, FileItem item, bool load_icon, bool load_thumb) {

		// get list of children ------------------

		var list = new ArrayList<FileItem>();
		foreach(string key in item.children.keys) {
			var child = item.children[key];
			list.add(child);
		}

		// sort ------------------

		list.sort((a, b) => {
			if ((a.file_type == FileType.DIRECTORY) && (b.file_type != FileType.DIRECTORY)){
				return -1;
			}
			else if ((a.file_type != FileType.DIRECTORY) && (b.file_type == FileType.DIRECTORY)){
				return 1;
			}
			else{
				return strcmp(a.file_name.down(), b.file_name.down());
			}
		});

		// add new child iters -------------------------

		foreach(var child in list) {
			append_item_to_treeview_item(ref iter0, child, load_icon, load_thumb);
		}
	}

	private TreeIter append_item_to_treeview_item(ref TreeIter iter0, FileItem item, bool load_icon, bool load_thumb) {

		TreeIter iter1;

		store.append (out iter1, iter0);
		set_iter_from_item(iter1, item, load_icon, load_thumb);

		return iter1;
	}

	private void remove_iter_children(ref TreeIter iter0){
		TreeIter iter1;
		var list = new Gee.ArrayList<TreeIter?>();
		bool iterExists = store.iter_children (out iter1, iter0);
		while (iterExists) {
			list.add(iter1);
			iterExists = store.iter_next (ref iter1);
		}

		foreach(var iter in list){
			FileItem item;
			store.get (iter, 0, out item, -1);
			//log_debug("remove:%s".printf(item.file_path));

			store.remove(ref iter);
		}
	}

	private bool remove_iter_by_file_path(string file_path, TreeIter? iter0 = null){

		if (store == null){ return true; }

		bool found = false;
		
		TreeIter iter1;
		bool iterExists = store.iter_children(out iter1, iter0);
		while (iterExists) {

			FileItem item;
			store.get (iter1, 0, out item, -1);

			if (item.file_path == file_path){
				found = true;
				store.remove(ref iter1);
				log_debug("Removed iter: %s".printf(file_path));
				break;
			}

			found = remove_iter_by_file_path(file_path, iter1);
			if (found) { break; }
		
			iterExists = store.iter_next (ref iter1);
		}

		return found;
	}

	public void refresh_iter_by_file_path(string file_path){

		if (store == null){ return; }

		TreeIter iter0;
		bool iterExists = store.iter_children(out iter0, null);
		while (iterExists) {

			FileItem item;
			store.get (iter0, 0, out item, -1);

			if (item.file_path == file_path){
				item.query_file_info();
				set_iter_from_item(iter0, item, true, false);
				//log_debug("Refreshed iter: %s".printf(file_path));
				return;
			}

			iterExists = store.iter_next (ref iter0);
		}

		return;
	}

	private bool filter_view (Gtk.TreeModel model, Gtk.TreeIter iter) {

		// filter_view() may be called even for empty rows, so check if file_item is null

		bool display = true;
		FileItem? item;
		model.get (iter, 0, out item, -1);

		if (item == null){
			display = false;
		}
		else{
			if (!show_hidden_files && item.is_backup_or_hidden){
				display = false;
			}
		}

		if (filter_pattern.length > 0){
			if (item.file_name.down().contains(filter_pattern) && display){
				display = true;
			}
			else{
				display = false;
			}
		}

		if (view_mode == ViewMode.MEDIA){
			
			if (item.is_directory){
				if (!show_folders_in_media_view){
					display = false;
				}
			}
			else if (!item.is_image && !item.is_video && !show_other_files_in_media_view){
				display = false;
			}
		}
		
		return display;
	}

	public void refilter(){
		if (treefilter == null){ return; }
		var list = get_selected_items();
		treefilter.refilter();
		select_items(list);
	}

	public void filter(string pattern){
		filter_pattern = pattern;
		refilter();
	}

	public void clear_filter(){
		filter_pattern = "";
		refilter();
	}

	// monitor directory ------------

	private void add_monitor(FileItem item){

		if (monitors == null){
			monitors = new Gee.ArrayList<FileItemMonitor>();
		}

		if (item == null) { return; }
		if (item.file_uri_scheme != "file") { return; }
		if (item is FileItemCloud){ return; }

		foreach(var mon in monitors){
			if (mon.file_item.file_path == item.file_path){
				log_debug("monitor exists: %s".printf(item.file_path));
				return;
			}
		}
		
		var mon = new FileItemMonitor();
		monitors.add(mon);

		log_debug("monitor added: %s".printf(item.file_path));
		
		mon.file_item = item;
		mon.monitor = mon.file_item.monitor_for_changes(out mon.cancellable);
		mon.monitor.changed.connect(directory_changed);
		log_debug("monitor connected: %s".printf(item.file_path));
	}

	private void remove_monitor(FileItem item){

		if (item == null) { return; }
		
		FileItemMonitor obj = null;
		foreach (var mon in monitors){
			if (mon.file_item.file_path == item.file_path){
				obj = mon;
				mon.cancellable.cancel();
				mon.monitor.changed.disconnect(directory_changed);
				log_debug("monitor disconnected: %s".printf(item.file_path));
			}
		}

		if (obj != null){
			monitors.remove(obj);
			log_debug("monitor removed: %s".printf(item.file_path));
		}
	}

	public void cancel_monitors(){

		if (monitors == null){
			monitors = new Gee.ArrayList<FileItemMonitor>();
			return;
		}
		
		foreach (var mon in monitors){
			if (mon.cancellable != null){
				mon.cancellable.cancel();
			}
			mon.monitor.changed.disconnect(directory_changed);
			log_debug("monitor disconnected: %s".printf(mon.file_item.file_path));
			log_debug("monitor removed: %s".printf(mon.file_item.file_path));
		}
		
		monitors.clear();
	}

	private void directory_changed(File src, File? dest, FileMonitorEvent event){

		if (dest != null) {
			log_msg("[MONITOR] %s: %s, %s".printf(event.to_string(), src.get_path(), dest.get_path()));
		} else {
			log_msg("[MONITOR] %s: %s".printf(event.to_string(), src.get_path()));
		}

		switch (event){
		case FileMonitorEvent.RENAMED:
			current_item.rename_child(file_basename(src.get_path()), file_basename(dest.get_path()));
			refresh_iter_by_file_path(dest.get_path());
			break;
		case FileMonitorEvent.CHANGES_DONE_HINT:
			refresh_delayed_add(true, false);
			break;
		case FileMonitorEvent.DELETED:
		case FileMonitorEvent.MOVED_OUT:
			current_item.remove_child(file_basename(src.get_path()));
			remove_iter_by_file_path(src.get_path());
			if (current_item.children.size == 0){
				set_overlay_on_empty();
			}
			break;
		case FileMonitorEvent.UNMOUNTED:
			set_overlay_on_unmount();
			break;
		case FileMonitorEvent.CREATED:
		case FileMonitorEvent.MOVED_IN:
			if(!current_item.has_child(file_basename(src.get_path()))){
				append_item_to_treeview_by_file_path(src.get_path());
				remove_overlay();
			}
			remove_overlay();
			break;
		case FileMonitorEvent.CHANGED:
			//if(!current_item.has_child(file_basename(src.get_path()))){
				refresh_iter_by_file_path(src.get_path());
			//}
			break;
		/*
		case FileMonitorEvent.RENAMED:
			string new_name = file_basename(dest.get_path());
			string old_name = file_basename(src.get_path());

			if (current_item.has_child(new_name)){
				current_item.remove_child(new_name);
				remove_iter_by_file_path(dest.get_path());
			}

			if (old_name != new_name){
				current_item.rename_child(old_name, new_name);
			}
			refresh_iter_by_file_path(dest.get_path()); // use dest
			break;
		*/
		}
	}

	private uint tmr_refresh_delayed = 0;
	private bool refresh_delayed_requery = true;
	private bool refresh_delayed_requery_subfolders = true;
	
	private void refresh_delayed_add(bool requery = true, bool requery_subfolders = true){
		refresh_delayed_clear();
		refresh_delayed_requery = requery;
		refresh_delayed_requery_subfolders = requery_subfolders;
		tmr_refresh_delayed = Timeout.add(500, refresh_delayed_execute);
	}

	private void refresh_delayed_clear(){
		if (tmr_refresh_delayed > 0){
			Source.remove(tmr_refresh_delayed);
			tmr_refresh_delayed = 0;
		}
	}
	
	private bool refresh_delayed_execute(){

		refresh_delayed_clear();

		log_debug("refresh_delayed()");

		refresh(refresh_delayed_requery, refresh_delayed_requery_subfolders);
		
		return false;
	}

	// overlay messages ------------
	
	private void clear_views(){
		store = null;
		treeview.set_model(null);
		iconview.set_model(null);
	}
	
	private void add_overlay(string msg, bool clear_view, bool show_spinner = false){

		remove_overlay(); // remove existing

		if ((treeview == null) || (iconview == null)){ return; }

		log_debug("add_overlay()");
		
		//cancel_monitors();
		
		if (clear_view){
			store = null;
			//current_item = null;
			treeview.set_model(null);
			//treeview.headers_visible = false;
			iconview.set_model(null);
		}

		var hbox = new Gtk.Box(Orientation.HORIZONTAL, 6);
		hbox.margin_left = 24;
		hbox.margin_top = 48;
		box_overlay = hbox;
		
		if (show_spinner){
			var spinner = new Gtk.Spinner();
			spinner.halign = Gtk.Align.START;
			spinner.valign = Gtk.Align.START;
			spinner.start();
			hbox.add(spinner);
		}

		var label = new Gtk.Label("<span size=\"large\">%s</span>".printf(msg)); //
		label.halign = Gtk.Align.START;
		label.valign = Gtk.Align.START;
		label.sensitive = false;
		label.set_use_markup(true);
		//label.max_width_chars = 100;
		label.wrap = true;
		label.wrap_mode = Pango.WrapMode.WORD_CHAR;
		hbox.add(label);
		lbl_overlay = label;
		
		overlay.add_overlay(hbox);
		overlay.set_overlay_pass_through(hbox, true);
		overlay.set_overlay_pass_through(label, true);
		//overlay.set_overlay_pass_through(hbox, true);
		
		hbox.show_all();

		//changed();
	}

	private void remove_overlay(){
		
		if ((overlay != null) && (box_overlay != null)){

			log_debug("remove_overlay()");
			
			overlay.remove(box_overlay);
			box_overlay = null;
			treeview.headers_visible = true;
		}
	}

	public void set_overlay_on_unmount(){
		log_debug("set_overlay_on_unmount()");
		current_item = null;
		add_overlay(_("Device was unmounted"), true);
		pane.statusbar.refresh();
		cancel_monitors();
	}

	public void set_overlay_on_invalid_path(){
		log_debug("set_overlay_on_invalid_path()");
		current_item = null;
		add_overlay(_("Could not find path") + " '%s'".printf(current_location), true);
		pane.statusbar.refresh();
		cancel_monitors();
	}

	public void set_overlay_on_empty(){
		log_debug("set_overlay_on_empty()");
		//current_item = null;
		add_overlay(_("Folder is empty"), false);
		//pane.statusbar.refresh(); // not needed
		//cancel_monitors();// do not cancel
	}

	public void set_overlay_on_not_readable(){
		log_debug("set_overlay_on_not_readable()");
		//current_item = null;
		string msg = "%s\n\n%s\n\n%s\n\n%s".printf(
			_("Error opening directory: Permission denied"),
			_("Open an admin window to browse this folder"),
			_("Menubar: File > New Admin Window"),
			_("Shortcut: [Super] + N")
			);
		add_overlay(msg, true);
		pane.statusbar.refresh();
		cancel_monitors();
	}

	public void set_overlay_on_loading(){
		log_debug("set_overlay_on_loading()");
		//current_item = null;
		add_overlay(_("Loading..."), true, true);
		//pane.statusbar.refresh(); // not needed
		//cancel_monitors();// do not cancel
	}
	
	public void set_overlay_on_error(string msg){
		log_debug("set_overlay_on_error()");
		add_overlay(msg, false);
		//pane.statusbar.refresh(); // not needed
		//cancel_monitors();// do not cancel
	}

	// update thumbnails ------------

	private void init_thumbnail_updater(){

		cancel_thumbnail_updater();

		thumbnail_update_is_required = false;
		thumbnail_update_cancelled = false;
		thumbnail_pending = 0;
	}

	public void start_thumbnail_updater(){

		cancel_thumbnail_updater();

		if ((current_item != null) && current_item.file_path.has_prefix(App.rclone_mounts)){
			return;
		}

		if (thumbnail_pending == 0){
			return;
		}

		try {
			//start thread for thumbnail updation
			Thread.create<void> (thumbnail_updater_thread, true);
		} catch (Error e) {
			log_error ("FileViewList: run_thumbnail_updater()");
			log_error (e.message);
		}
	}

	private void cancel_thumbnail_updater(){

		thumbnail_update_cancelled = true;
		while (thumbnail_updater_is_running){
			sleep(100); // wait for thread to exit
			gtk_do_events();
		}

		thumbnail_update_cancelled = false;
	}

	private void thumbnail_updater_thread(){

		log_debug(paneid + "started thumbnail_updater_thread: %d pending".printf(thumbnail_pending));

		thumbnail_updater_is_running = true;

		string msg = _("Generating thumbnails...");
		pane.statusbar.show_spinner(msg);
		window.statusbar.show_spinner(msg);

		int timeout_counter = 0;
		int timeout_counter_max = 20; // timeout = counter x 2 sec
		int batch_limit = 20;

		var list_completed = new Gee.ArrayList<TreeIter?>();

		while (true){

			if (thumbnail_update_cancelled) { break; }

			ThumbTask task;
			TreeIter iter0;
			bool found_one_pending = false;

			bool iterExists = store.iter_children(out iter0, null);
			while (iterExists) {
				if (thumbnail_update_cancelled) { break; }

				store.get (iter0, FileViewColumn.THUMBKEY, out task, -1);

				if (task != null){
					found_one_pending = true;

					if (task.completed){
						list_completed.add(iter0);
						//Thumbnailer.remove_from_queue(task);
					}
				}

				if (list_completed.size > batch_limit) { break; }

				iterExists = store.iter_next (ref iter0);
			}

			// check if all are completed
			if ((thumbnail_pending == 0) || (found_one_pending == false)){
				break;
			}

			// check if timeout is exceeded
			if (timeout_counter > timeout_counter_max){
				log_debug(paneid + "thumbnail_updater_thread: timeout_counter exceeded");
				break;
			}

			// update counters
			if (list_completed.size > 0){
				timeout_counter = 0;
			}
			else{
				timeout_counter++;
			}

			// process the completed items -------------

			foreach(var iter in list_completed){
				if (thumbnail_update_cancelled) { break; }

				FileItem file_item = null;
				store.get (iter, FileViewColumn.ITEM, out file_item, -1);
				var pixbuf = file_item.get_image(treemodel_icon_size, use_thumbs, use_transparency, use_emblems, out task);
				if (store != null){
					store.set (iter, FileViewColumn.ICON, pixbuf); // set icon
					store.set (iter, FileViewColumn.THUMBKEY, null); // reset thumbkey
					thumbnail_pending--;
				}
			}
			log_debug(paneid + "updater: updated %d".printf(list_completed.size));
			list_completed.clear();

			// update spinner (may have been hidden by count_subitems thread)
			pane.statusbar.show_spinner(msg);
			window.statusbar.show_spinner(msg);

			// sleep 2 seconds -------

			gtk_do_events();
			//log_debug(paneid + "updater: wait 2000ms");
			sleep(2000);
			//log_debug(paneid + "updater: awake");
			gtk_do_events();
		}

		//log_debug(paneid + "updater: exit");

		pane.statusbar.hide_spinner();
		window.statusbar.hide_spinner();

		thumbnail_updater_is_running = false;

		//log_debug("finished thumbnail_updater_thread");
	}

	public Gtk.TreeIter? get_iter_from_file_path(string file_path){

		Gtk.TreeIter iter;
		var model = (Gtk.TreeModel) treefilter;
		bool iter_exists = model.get_iter_first(out iter);
		while (iter_exists) {
			FileItem item;
			model.get (iter, 0, out item, -1);
			if (!item.is_dummy && (item.file_path == file_path)){
				return iter;
			}
			iter_exists = model.iter_next(ref iter);
		}

		return null;
	}

	// cycle video thumbnails --------------------

	/*private void start_thumbnail_cycler(){
		return;
		if (!video_thumb_cycling_in_progress){
			try {
				//start thread for thumbnail updation
				Thread.create<void> (cycle_thumbnail_images_thread, true);
			}
			catch (Error e) {
				log_error ("FileViewList: cycle_thumbnail_images()");
				log_error (e.message);
			}
		}
	}

	private void cycle_thumbnail_images(Gtk.Image? image, FileItem? item){

		log_debug("cycle_thumbnail_images: set file item");

		video_image = image;
		video_item = item;
	}

	private void cycle_thumbnail_images_thread(){

		log_debug("started cycle_thumbnail_images_thread");

		video_thumb_cycling_in_progress = true;

		int slide_index = 1;
		int cycle_interval = 800;

		while (true){

			if ((video_item != null) && (video_image != null) && (video_item.get_animation(256).size > 0)){

				if (slide_index < video_item.get_animation(256).size){

					log_debug("changed thumbnail: %d".printf(slide_index));

					video_image.pixbuf = video_item.get_animation(256)[slide_index];

					int buffer = 256 - video_image.pixbuf.height;
					video_image.margin_top = (int) (buffer / 2.0);
					video_image.margin_bottom = (int) (buffer / 2.0);

					slide_index++;
				}
				else{
					slide_index = 1;
				}
			}

			gtk_do_events();
			sleep(cycle_interval);
		}

		video_thumb_cycling_in_progress = false;

		log_debug("finished cycle_thumbnail_images_thread");
	}*/

	// history ------------------------------

	public bool history_can_go_back() {
		var index = history_index - 1;
		return (index >= 0) && (index < visited_locations.size);
	}

	public string history_go_back(){

		log_debug("history_go_back(): index: %d".printf(history_index));
		print_history_list();
		
		var index = history_index - 1;

		if ((index >= 0) && (index < visited_locations.size)){
			history_index = index;
			log_debug("previous: %s".printf(visited_locations[history_index]));
			return visited_locations[history_index];
		}
		else{
			return "";
		}
	}
	
	private void print_history_list(){
		int index = 0;
		foreach(var path in visited_locations){
			log_debug("%d: %s".printf(index++, path));
		}
	}

	public bool history_can_go_forward() {
		var index = history_index + 1;
		return (index >= 0) && (index < visited_locations.size);
	}

	public string history_go_forward() {

		log_debug("history_go_forward(): index: %d".printf(history_index));
		print_history_list();
		
		var index = history_index + 1;

		if ((index >= 0) && (index < visited_locations.size)){
			history_index = index;
			log_debug("next: %s".printf(visited_locations[history_index]));
			return visited_locations[history_index];
		}
		else{
			return "";
		}
	}
	
	public void history_add(FileItem item){
		
		string path = item.display_path;

		if (path.length > 0){
			visited_locations.add(path);
		}
	}

	public void history_reset(){
		history_index = visited_locations.size - 1;
	}

	public void history_clear(){
		history_index = -1;
		visited_locations.clear();
	}

	public bool location_can_go_up() {
		return (get_location_up().length > 0);
	}

	public string get_location_up(){
		
		//log_debug("get_location_up(): %s".printf(current_item.file_path));
		
		if (current_item != null){
			var path = file_parent(current_item.file_path);
			//log_debug("file_parent: %s".printf(path));
			if (dir_exists(path)){
				return path;
			}
		}

		return "";
	}

	public Gtk.Menu build_history_menu(){

		// menu_history
		var menu_history = new Gtk.Menu();
		menu_history.reserve_toggle_size = false;

		var sg_icon = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);
		var sg_label = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);

		var history_list = new Gee.ArrayList<string>();
		var added_list = new Gee.ArrayList<string>();

		for(int i = visited_locations.size - 1; i >= 0; i--){
			history_list.add(visited_locations[i]);
		}

		foreach(var path in history_list){
			if (added_list.contains(path)){
				continue;
			}

			added_list.add(path);

			var mi_history = gtk_menu_add_item(
						menu_history,
						path,
						_("Go to location"),
						null,
						sg_icon,
						sg_label);

			mi_history.activate.connect (() => {
				set_view_path(path, true); // update_history = true
			});
		}

		menu_history.show_all();

		return menu_history;
	}

	// selection helpers -----------------------------------

	public Gee.ArrayList<FileItem> get_selected_items(){

		log_debug("FileViewList: get_selected_items()");

		var selected_items = new Gee.ArrayList<FileItem>();

		Gtk.TreeModel model;
		GLib.List<TreePath> paths;

		if (view_mode == ViewMode.LIST){
			paths = treeview.get_selection().get_selected_rows(out model);
		}
		else{
			model = (Gtk.TreeModel) treefilter; // use model from treeview
			paths = iconview.get_selected_items();
		}

		//log_debug("treeview.get_selection() = %d".printf(sel.count_selected_rows()));

		//log_debug("selected: %s ==============================".printf(paths.nth_data(0).to_string()));

		foreach(var treepath in paths){
			TreeIter iter;
			if (model.get_iter(out iter, treepath)){
				FileItem item;
				model.get (iter, 0, out item, -1);
				selected_items.add(item);
			}
		}

		log_debug("FileViewList: get_selected_items(): exit");

		return selected_items;
	}

	public Gee.ArrayList<string> get_selected_file_paths(){
		var list = new Gee.ArrayList<string>();
		foreach(var item in get_selected_items()){
			list.add(item.file_path);
		}
		return list;
	}
	

	public void get_selected_counts(out int files, out int dirs){

		log_debug("FileViewList: get_selected_counts()");

		files = 0;
		dirs = 0;

		Gtk.TreeModel model;
		GLib.List<TreePath> paths;

		if (view_mode == ViewMode.LIST){
			paths = treeview.get_selection().get_selected_rows(out model);
		}
		else{
			model = (Gtk.TreeModel) treefilter; // use model from treeview
			paths = iconview.get_selected_items();
		}

		//log_debug("treeview.get_selection() = %d".printf(sel.count_selected_rows()));

		//log_debug("selected: %s ==============================".printf(paths.nth_data(0).to_string()));

		foreach(var treepath in paths){
			TreeIter iter;
			if (model.get_iter(out iter, treepath)){
				FileItem item;
				model.get (iter, 0, out item, -1);
				if (item.is_directory){
					dirs++;
				}
				else{
					files++;
				}
			}
		}

		//log_debug("FileViewList: get_selected_counts(): exit")
	}

	public Gee.ArrayList<FileItem> get_all_items(){

		log_debug("FileViewList: get_all_items()");

		var list = new Gee.ArrayList<FileItem>();

		if (current_item == null){ return list; }

		foreach(var child in current_item.children.values){
			list.add(child);
		}

		return list;
	}

	public void select_items(Gee.ArrayList<FileItem> items){

		var list = new Gee.ArrayList<string>();

		foreach(var x in items){
			list.add(x.file_path);
		}

		select_items_by_file_path(list);
	}
	
	public void select_items_by_file_path(Gee.ArrayList<string> items){

		Gtk.TreeModel model;
		model = (Gtk.TreeModel) treefilter;

		TreeIter iter;
		bool iterExists = model.get_iter_first (out iter);
		while (iterExists){
			FileItem item;
			model.get (iter, 0, out item, -1);
			if (items.contains(item.file_path)){
				if (view_mode == ViewMode.LIST){
					treeview.get_selection().select_iter(iter);
				}
				else{
					iconview.select_path(model.get_path(iter));
				}
			}
			else {
				if (view_mode == ViewMode.LIST){
					treeview.get_selection().unselect_iter(iter);
				}
				else{
					iconview.unselect_path(model.get_path(iter));
				}
			}
			iterExists = model.iter_next (ref iter);
		}
	}

	public void clear_selections(){
		
		if (view_mode == ViewMode.LIST){
			treeview.get_selection().unselect_all();
		}
		else{
			iconview.unselect_all();
		}
	}

	public void scroll_to_item_by_file_path(string item_path){

		Gtk.TreeModel model;
		model = (Gtk.TreeModel) treefilter;

		TreeIter iter;
		bool iterExists = model.get_iter_first (out iter);
		while (iterExists){
			FileItem item;
			model.get (iter, 0, out item, -1);
			if (item.file_path == item_path){
				if (view_mode == ViewMode.LIST){
					treeview.scroll_to_cell(model.get_path(iter), col_name, false, 0.0f, 0.0f);
				}
				else{
					iconview.scroll_to_path(model.get_path(iter), false, 0.0f, 0.0f);
				}
			}
			iterExists = model.iter_next (ref iter);
		}
	}
	
	// context actions -----------------------------------------

	public void open(FileItem _item, DesktopApp? app){

		log_debug("action.open(): %s".printf(_item.display_path), true);

		FileItem item = _item;

		if ((item is FileItemCloud) && !item.is_directory){
			
			var cloud_item = (FileItemCloud) item;
			
			if (cloud_item.local_path.length > 0){
				item = new FileItem.from_path_and_type(cloud_item.local_path, FileType.REGULAR, true);
				// continue
			}
			else{
				open_cloud_item(cloud_item, app);
				return;
			}
		}

		if ((item is FileItemArchive) && (current_item is FileItemArchive) && !item.is_directory){

			if (!FileItem.is_archive_by_extension(item.file_path)){ return; }

			var arch = (FileItemArchive) item;
			
			if (arch.children.size == 0){

				open_archive_item(arch);
				return;
			}
			else{
				// continue
			}
		}
		
		if (app != null){
			app.execute(item.file_path);
			return;
		}

		if (item.file_type == FileType.DIRECTORY){
				
			set_view_item(item);
		}
		else if (item.content_type.contains("executable") || item.content_type.contains("sharedlib")){
			
			run_in_terminal();
		}
		else if (item.is_file_hash){
			
			verify_checksums();
		}
		else {
			xdg_open(item.file_path);
		}
	}

	private void open_cloud_item(FileItemCloud item, DesktopApp? app){

		log_debug("action.open_cloud_item()");

		var list = new Gee.ArrayList<FileItem>();
		list.add(item);

		var tempdir = get_temp_file_path();
		dir_create(tempdir);
		var dest_dir = new FileItem.from_path_and_type(tempdir, FileType.DIRECTORY, false);

		var action = new ProgressPanelFileTask(pane, list, FileActionType.COPY);
		action.set_source(current_item);
		action.set_destination(dest_dir);
		pane.file_operations.add(action);

		action.task_complete.connect(()=>{
			
			//gtk_set_busy(false, window);
			string dest_file = path_combine(tempdir, item.file_name);
			
			if (file_exists(dest_file)){
				
				item.local_path = dest_file;
				var dest_item = new FileItem.from_path_and_type(dest_file, FileType.REGULAR, true);
				open(dest_item, app);
			}
		});

		// execute
		action.execute();

		//gtk_set_busy(true, window);
	}

	private void open_archive_item(FileItemArchive item){

		string outpath;
		var action = extract_selected_item_to_temp_location(item.archive_base_item, out outpath);

		//action.task_complete.connect(() => { open_archive_item_finish(item); });
		action.task_complete.connect(()=>{
			
			//string outpath = item.extraction_path; 
			log_debug("outpath: %s".printf(outpath));
			
			string extracted_item_path = path_combine(outpath, item.file_path);
			log_debug("extracted_item_path: %s".printf(extracted_item_path));

			if (file_exists(extracted_item_path)){

				// set the display_path and change file_path to point to extracted_item_path 
				item.display_path = item.display_path;
				log_debug("item.display_pat: %s".printf(item.display_path));
				
				item.file_path = extracted_item_path; 
				log_debug("item.file_path: %s".printf(item.file_path));
				
				//item.archive_base_item = item; 
				// list the item 
				//if (list_archive(item)){

				item.file_type = FileType.DIRECTORY;
				
				set_view_item(item); 
				//} 
			}
		});
	}

	/*private void open_archive_item_finish(FileItemArchive item){
		
		string outpath = item.extraction_path; 
		log_debug("outpath: %s".printf(outpath));
		
		string extracted_item_path = path_combine(outpath, item.file_path);
		log_debug("extracted_item_path: %s".printf(extracted_item_path));

		if (file_exists(extracted_item_path)){

			// set the display_path and change file_path to point to extracted_item_path 
			item.display_path = item.display_path;
			log_debug("item.display_pat: %s".printf(item.display_path));
			
			item.file_path = extracted_item_path; 
			log_debug("item.file_path: %s".printf(item.file_path));
			
			//item.archive_base_item = item; 
			// list the item 
			//if (list_archive(item)){ 
			set_view_item(item); 
			//} 
		}
	}*/
	
	public void set_default_app(FileItem item, DesktopApp? app){

		log_debug("FileViewList: set_default_app(): %s ----------".printf(item.display_path), true);

		if (app != null){
			MimeApp.set_default(item.content_type, app);
			log_debug("setting default app: %s, mimetype: %s".printf(app.name, item.content_type));
		}
	}
	
	public void open_selected_item(){

		var selected_items = get_selected_items();
		if (selected_items.size == 0){ return; }

		log_debug("action.open_selected_item()");
		
		open(selected_items[0], null);
	}

	public void cut(){

		if (!can_cut){ return; }
		
		var selected_items = get_selected_items();
		if (selected_items.size == 0){ return; }

		log_debug("action.cut()");

		// save
		var action = new ProgressPanelFileTask(pane, selected_items, FileActionType.CUT);
		action.set_source(current_item);
		window.pending_action = action;
	}

	public void copy(){

		if (!can_copy){ return; }
		
		var selected_items = get_selected_items();
		if (selected_items.size == 0){ return; }

		log_debug("action.copy()");

		// save
		var action = new ProgressPanelFileTask(pane, selected_items, FileActionType.COPY);
		action.set_source(current_item);
		window.pending_action = action;

		copy_selected_paths_to_clipboard();
	}

	public void copy_selected_paths_to_clipboard(){
		Gdk.Display display = window.get_display();
		Gtk.Clipboard clipboard = Gtk.Clipboard.get_for_display(display, Gdk.SELECTION_CLIPBOARD);
		string txt = "";
		foreach(var item in get_selected_items()){
			txt += "%s\n".printf(item.file_path);
		}
		clipboard.set_text(txt, -1);
	}

	public void paste(){

		if (!can_paste){ return; }
		
		if (window.pending_action == null) { return; }

		log_debug("action.paste()");

		// pickup
		var action = window.pending_action;

		// clear
		window.pending_action = null;

		// update
		action.set_destination(current_item);

		if (action.source.file_path == action.destination.file_path){
			if (action.action_type == FileActionType.CUT){
				show_msg_for_same_source_and_dest();
				return;
			}
			else if (confirm_copy_for_same_source_and_dest() == Gtk.ResponseType.NO){
				return;
			}
		}

		// link
		action.set_pane(pane);
		pane.file_operations.add(action);

		// execute
		action.execute();
	}

	public void paste_into_folder(){

		if (!can_paste){ return; }
		
		if (window.pending_action == null) { return; }

		var selected_items = get_selected_items();
		if (selected_items.size != 1){ return; }
		if (!selected_items[0].is_directory){ return; }

		log_debug("action.paste_into_folder()");

		// pickup
		var action = window.pending_action;

		// clear
		window.pending_action = null;

		// update
		action.set_destination(selected_items[0]);

		if (action.source.file_path == action.destination.file_path){
			if (action.action_type == FileActionType.CUT){
				show_msg_for_same_source_and_dest();
				return;
			}
			else if (confirm_copy_for_same_source_and_dest() == Gtk.ResponseType.NO){
				return;
			}
		}

		// link
		action.set_pane(pane);
		pane.file_operations.add(action);

		// execute
		action.execute();
	}

	public void paste_url(string url){

		if (!can_paste){ return; }
		
		if (url.length == 0) { return; }
		
		if (!check_youtube_dl()){ return; }

		if (!check_plugin("yt")){ return; }
		
		log_debug("action.paste_url()");

		// create
		var action = new ProgressPanelVideoDownloadTask(pane, url);
		action.set_source(current_item);
		action.set_destination(current_item);
		pane.file_operations.add(action);

		// execute
		action.execute();
	}

	public void paste_url_into_folder(string url){

		if (!can_paste){ return; }
		
		if (url.length == 0) { return; }

		var selected_items = get_selected_items();
		if (selected_items.size != 1){ return; }
		if (!selected_items[0].is_directory){ return; }
		
		if (!check_youtube_dl()){ return; }

		if (!check_plugin("yt")){ return; }

		log_debug("action.paste_url_into_folder()");

		// create
		var action = new ProgressPanelVideoDownloadTask(pane, url);
		action.set_source(current_item);
		action.set_destination(selected_items[0]);
		pane.file_operations.add(action);

		// execute
		action.execute();
	}

	public void copy_across(bool move = false){
		var selected_items = get_selected_items();
		if (selected_items.size == 0){ return; }

		log_debug("action.copy_across()");

		// create
		var action_type = move ? FileActionType.CUT : FileActionType.COPY;
		var action = new ProgressPanelFileTask(pane, selected_items, action_type);
		action.set_source(current_item);

		var opp_pane = panel.opposite_pane;
		if (opp_pane != null){
			// update
			action.set_destination(opp_pane.view.current_item);

			if (action.source.file_path == action.destination.file_path){
				if (move){
					show_msg_for_same_source_and_dest();
					return;
				}
				else if (confirm_copy_for_same_source_and_dest() == Gtk.ResponseType.NO){
					return;
				}
			}

			// link
			pane.file_operations.add(action);

			// execute
			action.execute();
		}
		else{
			gtk_messagebox(_("Internal Error"),_("Could not find the opposite pane!"), window, true);
		}
	}

	public void move_across(){
		log_debug("action.move_across()");
		copy_across(true);
	}

	public void copy_to(bool move = false){
		var selected_items = get_selected_items();
		if (selected_items.size == 0){ return; }

		log_debug("action.copy_to()");

		string message = move ? _("Select Move Destination") : _("Select Copy Destination");
		var list = gtk_select_files(window, false, false, null, null, message);
		if (list.size == 0){ return; }

		// create
		var action_type = move ? FileActionType.CUT : FileActionType.COPY;
		var action = new ProgressPanelFileTask(pane, selected_items, action_type);

		// update
		action.set_source(current_item);
		action.set_destination(new FileItem.from_path(list[0]));

		if (action.source.file_path == action.destination.file_path){
			if (move){
				show_msg_for_same_source_and_dest();
				return;
			}
			else if (confirm_copy_for_same_source_and_dest() == Gtk.ResponseType.NO){
				return;
			}
		}

		// link
		pane.file_operations.add(action);

		// execute
		action.execute();
	}

	public void move_to(){
		log_debug("action.move_to()");
		copy_to(true);
	}

	private void paste_symlinks(FileActionType action_type = FileActionType.PASTE_SYMLINKS_ABSOLUTE){
		if (window.pending_action == null){ return; }

		log_debug("action.paste_symlinks()");

		// pickup
		var action = window.pending_action;

		// update
		action.set_destination(current_item);
		action.set_action(action_type);

		// source and dest can be same
		/*if (action.source.file_path == action.destination.file_path){
			show_msg_for_same_source_and_dest();
			return;
		}*/

		// clear after the check
		window.pending_action = null;

		// link
		action.set_pane(pane);
		pane.file_operations.add(action);

		// execute
		action.execute();
	}

	public void paste_symlinks_absolute(){
		log_debug("action.paste_symlinks_absolute()");
		paste_symlinks(FileActionType.PASTE_SYMLINKS_ABSOLUTE);
	}

	public void paste_symlinks_relative(){
		log_debug("action.paste_symlinks_relative()");
		paste_symlinks(FileActionType.PASTE_SYMLINKS_RELATIVE);
	}

	public void paste_hardlinks(){
		if (window.pending_action == null){ return; }

		log_debug("action.paste_hardlinks()");

		// pickup
		var action = window.pending_action;

		// update
		action.set_destination(current_item);
		action.set_action(FileActionType.PASTE_HARDLINKS);

		// source and dest can be same
		/*
		if (action.source.file_path == action.destination.file_path){
			show_msg_for_same_source_and_dest();
			return;
		}
		*/

		// clear after the check
		window.pending_action = null;

		// link
		action.set_pane(pane);
		pane.file_operations.add(action);

		// execute
		action.execute();
	}

	private void show_msg_for_same_source_and_dest(){
		string title = _("Source and destination are same");
		string msg = _("Requested operation is not possible");
		gtk_messagebox(title, msg, window, true);
	}

	private Gtk.ResponseType confirm_copy_for_same_source_and_dest(){
		string title = _("Source and destination are same");
		string msg = _("Create copies of selected items?");
		return gtk_messagebox_yes_no(title, msg, window, true);
	}

	public void trash(){

		if (!can_trash){ return; }
		
		var selected_items = get_selected_items();
		if (selected_items.size == 0){ return; }

		if (App.confirm_trash){
			string txt = _("Trash selected items?");
			string msg = "%ld %s".printf(selected_items.size, _("selected item(s) will be moved to trash"));
			if (gtk_messagebox_yes_no(txt, msg, window) != Gtk.ResponseType.YES){
				return;
			}
		}

		log_debug("action.trash()");

		var action = new ProgressPanelFileTask(pane, selected_items, FileActionType.TRASH);
		action.set_source(current_item);
		pane.file_operations.add(action);
		action.execute();
	}

	public void delete_items(bool delete_all = false){

		if (!can_delete){ return; }
		
		log_debug("action.delete_items()");

		var list = new Gee.ArrayList<FileItem>();

		var action_type = FileActionType.DELETE;

		int selected_count = 0;
		
		if (current_item.is_trash){

			action_type = FileActionType.DELETE_TRASHED;

			var selected = new Gee.ArrayList<FileItem>();

			if (delete_all){
				selected = get_all_items();
			}
			else{
				selected = get_selected_items();
			}

			selected_count = selected.size;
			
			foreach(var item in selected){

				if (file_exists(item.trash_info_file)){
					var file_info = new FileItem.from_path(item.trash_info_file);
					if (file_info.can_delete){
						list.add(file_info);
					}
				}
				
				var file_data = new FileItem.from_path(item.trash_data_file);
				if (file_data.can_delete){
					list.add(file_data);
				}
			}
		}
		else{
			list = get_selected_items();
			selected_count = list.size;
		}

		if (list.size == 0){ return; }

		if (App.confirm_delete){
			string txt = _("Delete selected items?");
			string msg = "%ld %s".printf(selected_count, _("selected item(s) will be deleted permanently"));
			if (gtk_messagebox_yes_no(txt, msg, window) != Gtk.ResponseType.YES){
				return;
			}
		}

		if (current_item.is_trash && delete_all){
			action_type = FileActionType.TRASH_EMPTY;
		}

		var action = new ProgressPanelFileTask(pane, list, action_type);
		action.set_source(current_item);
		pane.file_operations.add(action);
		action.execute();
	}

	public void restore_items(){

		var selected_items = get_selected_items();
		if (selected_items.size == 0){ return; }
		if (!current_item.is_trash){ return; }

		log_debug("action.restore_items()");

		var action = new ProgressPanelFileTask(pane, selected_items, FileActionType.RESTORE);
		action.set_source(current_item);
		pane.file_operations.add(action);
		action.execute();
	}

	public void rename(){

		if (!can_rename){ return; }
		
		var selected_items = get_selected_items();
		if (selected_items.size != 1){ return; }

		log_debug("action.rename()");

		if (view_mode == ViewMode.LIST){

			window.update_accelerators_for_edit();

			cell_name.editable = true;
			TreeModel model;
			var list = treeview.get_selection().get_selected_rows(out model);
			treeview.set_cursor_on_cell(list.nth_data(0), col_name, cell_name, true);
		}
		else{
			var item = selected_items[0];
			string new_name = gtk_inputbox(_("Rename"),_("Enter new name"), window, false, item.file_name);

			if (try_rename_item(item, new_name)){
				refresh(false, false);
			}
		}
	}

	private bool try_rename_item(FileItem item, string new_name){

		string file_path_new = path_combine(item.file_location, new_name);

		if (item.file_name == new_name){
			return true;
		}
		else if (!item.can_rename){
			gtk_messagebox(_("No Permission"), _("You do not have permission to rename this item"), window, true);
		}
		else if (file_or_dir_exists(file_path_new)){
			gtk_messagebox(_("Another file exists with this name"), _("Enter unique name for selected file"), window, true);
		}
		else{
			if (item is FileItemCloud){
				cloud_rename((FileItemCloud) item, new_name);
				// async, no waiting
			}
			else{
				bool ok = file_rename(item.file_path, new_name, window);
				if (ok){
					item.file_path = file_path_new;
					return true;
				}
			}
		}

		return false;
	}

	public void cloud_rename(FileItemCloud item, string new_name){

		log_debug("action.cloud_rename()");

		var list = new Gee.ArrayList<FileItem>();
		list.add(item);

		var action = new ProgressPanelFileTask(pane, list, FileActionType.CLOUD_RENAME);
		action.set_source(current_item);
		action.source_file = item.file_path;
		action.new_name = new_name;
		pane.file_operations.add(action);

		// execute
		action.execute();
	}

	public void create_directory(){

		log_debug("action.create_directory()");

		string? new_name = _("New Folder");
		string file_path_new = file_generate_unique_name(path_combine(current_item.file_path, new_name));
		new_name = file_basename(file_path_new);
		
		do {
			new_name = gtk_inputbox(_("Create Directory"),_("Enter directory name"), window, false, new_name);
			if ((new_name == null) || (new_name.length == 0)){
				return;
			}

			file_path_new = path_combine(current_item.file_path, new_name);

			if (file_or_dir_exists(file_path_new)){
				gtk_messagebox(_("Directory exists"), _("Enter another name"), window, true);
			}
			else{
				break;
			}
		}
		while(current_item.children.has_key(new_name));

		dir_create(path_combine(current_item.file_path, new_name), false, window);

		refresh(true, false);

		var list = new Gee.ArrayList<string>();
		list.add(path_combine(current_item.file_path, new_name));
		select_items_by_file_path(list);
	}

	public void create_file(){

		log_debug("action.create_file()");

		string? new_name = _("New File");
		string file_path_new = file_generate_unique_name(path_combine(current_item.file_path, new_name));
		new_name = file_basename(file_path_new);
		
		do {
			new_name = gtk_inputbox(_("Create File"),_("Enter file name"), window, false, new_name);
			if ((new_name == null) || (new_name.length == 0)){
				return;
			}

			file_path_new = path_combine(current_item.file_path, new_name);

			if (file_or_dir_exists(file_path_new)){
				gtk_messagebox(_("File exists"), _("Enter another name"), window, true);
			}
			else{
				break;
			}
		}
		while(current_item.children.has_key(new_name));

		file_write(path_combine(current_item.file_path, new_name), "", window);

		refresh(true, false);

		var list = new Gee.ArrayList<string>();
		list.add(path_combine(current_item.file_path, new_name));
		select_items_by_file_path(list);
	}

	public void create_file_from_template(string template_path){

		log_debug("action.create_file_from_template()");

		FileItem template = new FileItem.from_path(template_path);
		
		string? new_name = "New %s".printf(template.file_name);
		string  new_file_path = file_generate_unique_name(path_combine(current_item.file_path, new_name));
		new_name = file_basename(new_file_path);
		
		do {
			new_name = gtk_inputbox(_("Create File"),_("Enter file name"), window, false, new_name);
			if ((new_name == null) || (new_name.length == 0)){
				return;
			}

			if (!new_name.has_suffix(template.file_extension)){
				new_name += template.file_extension;
			}
			
			new_file_path = path_combine(current_item.file_path, new_name);
			
			if (file_or_dir_exists(new_file_path)){
				gtk_messagebox(_("File exists"), _("Enter another name"), window, true);
			}
			else{
				break;
			}
		}
		while (current_item.children.has_key(new_name));

		file_copy(template_path, new_file_path);

		refresh(true, false);

		var list = new Gee.ArrayList<string>();
		list.add(path_combine(current_item.file_path, new_name));
		select_items_by_file_path(list);
	}

	public void open_tab(){
		var tab = panel.add_tab();
		//tab.pane.view.set_view_path(path_to_open);
		tab.select_tab();
	}

	public void open_terminal(bool sudo_mode = false){
		log_debug("action.open_terminal()");
		open_terminal_window("", current_item.file_path, "", sudo_mode);
	}

	public void run_in_terminal(){
		
		var selected = get_selected_items()[0];

		log_debug("action.run_in_terminal()");

		if (!pane.terminal.visible){
			pane.terminal.toggle();
		}

		pane.terminal.feed_command("'%s'".printf(escape_single_quote(selected.file_path)));
		
		//open_terminal_window("", current_item.file_path, selected_items[0].file_path, false);
	}

	public void analyze_disk_usage(){

		log_debug("action.analyze_disk_usage()");

		var baobab = DesktopApp.get_app_by_filename("org.gnome.baobab.desktop");
		if (baobab == null){ return; }

		var selected_items = get_selected_items();
		if ((selected_items.size > 0) && (selected_items[0].is_directory)){
			open(selected_items[0], baobab);
		}
		else{
			open(current_item, baobab);
		}
	}

	public FileViewTab? open_in_new_tab(string folder_path = "", bool use_existing = true, bool init_views = false){
		
		var selected_items = get_selected_items();
		if ((folder_path.length == 0) && (selected_items.size != 1)){ return null; }

		log_debug("action.open_in_new_tab()");

		string path_to_open = folder_path;
		if (path_to_open.length == 0){
			path_to_open = selected_items[0].file_path;
		}

		if (use_existing){
			// focus an existing tab with the requested path, if any
			foreach(var tab in panel.tabs){
				if ((tab.view.current_item != null) && (tab.view.current_item.file_path == path_to_open)){
					tab.select_tab();
					log_debug("selected existing tab");
					return tab;
				}
			}
		}
		
		var tab = panel.add_tab(init_views);
		tab.pane.view.set_view_path(path_to_open);
		return tab;
	}

	public void open_in_new_window(bool admin_mode = false){
		log_debug("action.open_in_new_window()");

		var selected_items = get_selected_items();

		string path_to_open = "";

		if ((selected_items.size == 1) && (dir_exists(selected_items[0].file_path))){
			path_to_open = selected_items[0].file_path;
		}
		else{
			path_to_open = current_item.file_path;
		}

		string cmd = "polo-gtk --new-window '%s'".printf(escape_single_quote(path_to_open));
		exec_script_async(cmd, admin_mode);
	}

	public void open_in_admin_window(){
		log_debug("action.open_in_admin_window()");

		open_in_new_window(true);
	}

	public void select_all(){
		log_debug("action.select_all()");

		if (view_mode == ViewMode.LIST){
			treeview.get_selection().select_all();
		}
		else{
			iconview.select_all();
		}
	}

	public void select_none(){
		
		log_debug("action.select_none()");
		treeview.get_selection().unselect_all();

		if (calculate_dirsize_task != null){
			calculate_dirsize_task.stop();
		}
	}

	public void reload(){
		log_debug("action.reload()");
		
		if ((current_item != null) && (current_item is FileItemCloud)){
			var cloud_item = (FileItemCloud) current_item;
			cloud_item.remove_cached_file();
		}

		clear_selections();
		
		refresh(true, true);
	}

	public void toggle_dual_pane(){
		log_debug("action.toggle_dual_pane()");

		if (!window.layout_box.show_file_operation_warning_on_layout_change()) {
			return;
		}

		if (window.layout_box.get_visible_pane_count() < 2){
			window.layout_box.set_panel_layout(PanelLayout.DUAL_VERTICAL);
		}
		else {
			window.layout_box.set_panel_layout(PanelLayout.SINGLE);
		}
		
		window.layout_box.reset_pane_positions();
	}

	public void toggle_view(bool? show_treeview = null){

		log_debug("action.toggle_view()");

		if (show_treeview == null){
			show_treeview = !scrolled_treeview.visible;
		}

		if (show_treeview == true){
			set_view_mode(ViewMode.LIST);
			gtk_hide(scrolled_iconview);
			gtk_show(scrolled_treeview);
		}
		else {
			set_view_mode(ViewMode.ICONS);
			gtk_hide(scrolled_treeview);
			gtk_show(scrolled_iconview);
		}
	}

	public void show_properties(){
		FileItem item = current_item;
		if (get_selected_items().size > 0){
			item = get_selected_items()[0];
		}
		var win = new FilePropertiesWindow.for_file(item);
		win.show_all();
	}

	public void swap_location_with_opposite_pane(){

		string path1 = (this.current_item == null) ? "" : this.current_item.file_path;

		var opp_pane = panel.opposite_pane;
		string path2 = (opp_pane.view.current_item == null) ? "" : opp_pane.view.current_item.file_path;

		if (path1 != path2){
			this.set_view_path(path2);
			opp_pane.view.set_view_path(path1);
		}

		window.active_pane = pane;
		window.update_accelerators_for_active_pane();
	}

	public void open_location_in_opposite_pane(){

		if (this.current_item == null) { return; }

		panel.opposite_pane.view.set_view_path(this.current_item.file_path);

		if (!panel.opposite_panel.visible){
			gtk_show(panel.opposite_panel);

			panel.pane.pathbar.refresh_icon_visibility();
			panel.opposite_pane.pathbar.refresh_icon_visibility();

			if ((panel.number == 1) && !window.layout_box.panel3.visible){
				window.layout_box.set_panel_layout(PanelLayout.DUAL_VERTICAL);
				//window.layout_box.reset_pane_positions();
			}
			else if ((panel.number == 1) || (panel.number == 3)){
				window.layout_box.set_panel_layout(PanelLayout.QUAD);
				//window.layout_box.reset_pane_positions();
			}

			window.layout_box.reset_pane_positions();
		}

		window.active_pane = pane;
		window.update_accelerators_for_active_pane();
	}

	public void follow_symlink(){
		var selected_items = get_selected_items();
		if (selected_items.size == 0){ return; }
		var item = selected_items[0];
		
		string target_path = item.resolve_symlink_target();
		log_debug("resolved target path: %s".printf(target_path));
		set_view_path(file_parent(target_path));

		if (current_item.children.has_key(file_basename(item.symlink_target))){
			TreeIter? iter = get_iter_from_file_path(target_path);
			if (iter != null){
				treeview.get_selection().select_iter((TreeIter) iter);
			}
		}
	}
	
	public void open_original_location(){
		var selected_items = get_selected_items();
		if (selected_items.size == 0){ return; }
		var item = selected_items[0];

		if (item.is_trashed_item){
			var tab = panel.add_tab(false);
			tab.pane.view.set_view_path(file_parent(item.trash_original_path));
			tab.select_tab();
		}
	}

	public void open_trash_dir(){

		log_debug("FileViewList: open_trash_dir()");
		
		var selected_items = get_selected_items();
		log_debug("count: %d".printf(selected_items.size));
		if (selected_items.size == 0){ return; }
		var item = selected_items[0];

		if (item.is_trashed_item){
			var tab = panel.add_tab(false);
			log_debug("trash_basepath=%s".printf(file_parent(item.trash_basepath)));
			tab.pane.view.set_view_path(file_parent(item.trash_basepath));
			tab.select_tab();
		}
		else{
			log_debug("is_trashed_item=false");
		}
	}

	public void compare_files_opposite(){

		log_debug("FileViewList: compare_files_opposite()");
		
		var selected_items = get_selected_items();
		if (selected_items.size == 0){ return; }

		err_log_clear();

		var view2 = panel.opposite_pane.view;
		
		var file1 = selected_items[0];

		if (view2.current_item.children.has_key(file1.file_name)){
			
			var file2 = view2.current_item.children[file1.file_name];

			compare_files(file1, file2);
		}
		else{
			string txt = _("File Not Found");
			string msg = "%s:\n\n%s".printf(_("Could not find file in opposite pane"), file1.file_name);
			gtk_messagebox(txt, msg, window, true);
			return;
		}
	}

	public void compare_files_select_second(){

		log_debug("FileViewList: compare_files_select_second()");
		
		var selected_items = get_selected_items();
		if (selected_items.size == 0){ return; }

		err_log_clear();

		var file1 = selected_items[0];

		var list = gtk_select_files(window, true, false, null, null, "", "");
		if (list.size == 0){ return; }

		var file2 = new FileItem.from_path(list[0]);
		
		compare_files(file1, file2);
	}
	
	public void compare_files(FileItem file1, FileItem file2){

		log_debug("FileViewList: compare_files()");
		
		string txt, msg, cmd;
		
		if (!file_is_regular(file1.file_path)){
			
			txt = _("Not Supported");
			msg = "%s:\n\n> %s".printf(_("Selected item is not a text file"), file1.file_name);
			gtk_messagebox(txt, msg, window, true);
			return;
		}

		if (!file_is_regular(file2.file_path)){
			txt = _("Not Supported");
			msg = "%s:\n\n> %s".printf(_("Selected item is not a text file"), file2.file_name);
			gtk_messagebox(txt, msg, window, true);
			return;
		}

		if ((App.compare_default == "bcompare") && cmd_exists("bcompare")){
			cmd = "bcompare '%s' '%s'".printf(escape_single_quote(file1.file_path), escape_single_quote(file2.file_path));
			log_debug(cmd);
			exec_script_async(cmd);
			return;
		}

		if (cmd_exists("diffuse")){
			cmd = "diffuse '%s' '%s'".printf(escape_single_quote(file1.file_path), escape_single_quote(file2.file_path));
			log_debug(cmd);
			exec_script_async(cmd);
			return;
		}

		check_diffuse(); // show message for installing diffuse
	}
	
	// ISO ---------------------------------------
	
	public void mount_iso(){
		
		err_log_clear();

		var selected_items = get_selected_items();
		if (selected_items.size == 0){ return; }
		var item = selected_items[0];
		
		var loop_dev = Device.automount_udisks_iso(item.file_path, window);

		if (err_log.length > 0){
			gtk_messagebox("", err_log, window, true);
			err_log_disable();
			return;
		}

		err_log_disable();

		if (loop_dev == null){ return; }

		// notify
		string title = "%s".printf(_("Mounted ISO"));
		string msg = "%s".printf(loop_dev.device);
		OSDNotify.notify_send(title, msg, 2000, "normal", "info");

		if (loop_dev.has_children){
			
			// get first iso9660 partition ------------------------
			
			var list = Device.get_block_devices_using_lsblk();
			
			foreach(var dev in list){
				
				if ((dev.pkname == loop_dev.device.replace("/dev/","")) && (dev.fstype == "iso9660")){
					
					loop_dev = dev;
					break;
				}
			}
		}
			
		// browse --------------------
		
		if (loop_dev.mount_points.size > 0){
			
			var mp = loop_dev.mount_points[0];
			set_view_path(mp.mount_point);
		}
		else{
			log_error("There are no mount points for the loop device");
		}
	}

	public void boot_iso(){
		
		var selected_items = get_selected_items();
		if (selected_items.size == 0){ return; }
		var item = selected_items[0];

		var task = new KvmTask();
		task.boot_iso(item.file_path, App.get_kvm_config());
	}

	public void write_iso(Device dev){
		
		var selected_items = get_selected_items();
		if (selected_items.size == 0){ return; }
		var item = selected_items[0];

		if (!check_plugin("iso")){ return; }

		string txt = "%s".printf(_("Flash ISO to device?"));
		string msg = "%s:\n\n▰ %s".printf(_("Existing data on device will be destroyed"), dev.description_simple());
		var resp = gtk_messagebox_yes_no(txt, msg, window, true);
		if (resp != Gtk.ResponseType.YES){
			return;
		}

		var action = new ProgressPanelDeviceWriterTask(pane);
		action.set_parameters(DiskAction.WRITE_ISO, item.file_path, dev, "");
		pane.file_operations.add(action);
		action.execute();
	}

	// KVM ---------------------------------------
	
	public void kvm_create_disk(){
		
		err_log_clear();

		new KvmCreateDiskWindow(KvmTaskType.CREATE_DISK, window, current_item.file_path, "", "", "");
	}

	public void kvm_create_derived_disk(){
		
		err_log_clear();

		var selected_items = get_selected_items();
		if (selected_items.size == 0){ return; }
		var item = selected_items[0];

		new KvmCreateDiskWindow(KvmTaskType.CREATE_DISK_DERIVED, window, current_item.file_path, item.file_path, "", "");
	}

	public void kvm_create_merged_disk(){
		
		err_log_clear();

		var selected_items = get_selected_items();
		if (selected_items.size == 0){ return; }
		var item = selected_items[0];

		new KvmCreateDiskWindow(KvmTaskType.CONVERT_MERGE, window, current_item.file_path, "", item.file_path, "");
	}

	public void kvm_convert_disk(string disk_format){
		
		err_log_clear();

		var selected_items = get_selected_items();
		if (selected_items.size == 0){ return; }
		var item = selected_items[0];
		
		new KvmCreateDiskWindow(KvmTaskType.CONVERT_DISK, window, current_item.file_path, item.file_path, "", disk_format);
	}
	
	public void kvm_boot_disk(){
		
		err_log_clear();

		var selected_items = get_selected_items();
		if (selected_items.size == 0){ return; }
		var item = selected_items[0];

		if (!item.can_write){
			gtk_messagebox(_("Disk is Read-Only"),_("Read-only disks cannot be booted.\n\nTo boot this disk, make it writable by setting write permissions from the file properties dialog.\n\nIf this disk is modified, any disks derived from it will become corrupt.\n\nTo avoid corrupting derived disks, create a new derived disk from this file and boot from it, instead of booting this disk directly."), window, true);
			return;
		}

		var task = new KvmTask();
		task.boot_disk(item.file_path, App.get_kvm_config());
	}

	public void kvm_mount_disk(){
		
		err_log_clear();

		var selected_items = get_selected_items();
		if (selected_items.size == 0){ return; }
		var item = selected_items[0];

		var task = new KvmTask();
		task.mount_disk(item.file_path);
	}

	public void kvm_install_iso(){
		
		err_log_clear();

		var selected_items = get_selected_items();
		if (selected_items.size == 0){ return; }
		var item = selected_items[0];

		string message = _("Select ISO File");

		var filters = new Gee.ArrayList<Gtk.FileFilter>();
		var filter = create_file_filter("All Files", { "*" });
		filters.add(filter);
		filter = create_file_filter("ISO Image File (*.iso)", { "*.iso" });
		filters.add(filter);
		var default_filter = filter;

		var selected_files = gtk_select_files(window, true, false, filters, default_filter, message);
		if (selected_files.size == 0){ return; }
		string iso_file = selected_files[0];

		var task = new KvmTask();
		task.boot_iso_attach_disk(iso_file, item.file_path, App.get_kvm_config());
	}

	// PDF ---------------------------------------

	public Gee.ArrayList<string> selected_pdfs(){

		var files = new Gee.ArrayList<string>();
		
		var selected_items = get_selected_items();
		
		if (selected_items.size == 0){
			return files;
		}

		foreach(var file in selected_items){
			if (file.is_pdf){
				files.add(file.file_path);
			}
		}
		
		files.sort((a,b)=> {
			return strcmp(a,b);
		});

		return files;
	}

	public void pdf_split(){

		var files = selected_pdfs();
		if (files.size == 0){ return; }

		if (!check_pdftk()){ return; }

		if (!check_plugin("pdf")){ return; }
		
		err_log_clear();

		var task = new PdfTask();
		task.split(files, App.overwrite_pdf_split);
		
		var action = new ProgressPanelPdfTask(pane, task);
		pane.file_operations.add(action);
		action.execute();
	}

	public void pdf_merge(){
		
		var files = selected_pdfs();
		if (files.size == 0){ return; }

		if (!check_pdftk()){ return; }

		if (!check_plugin("pdf")){ return; }
		
		err_log_clear();

		var task = new PdfTask();
		task.merge(files, App.overwrite_pdf_merge);

		var action = new ProgressPanelPdfTask(pane, task);
		pane.file_operations.add(action);
		action.execute();
	}

	public void pdf_protect(){
		
		var files = selected_pdfs();
		if (files.size == 0){ return; }

		if (!check_pdftk()){ return; }

		if (!check_plugin("pdf")){ return; }

		string pass = prompt_for_pdf_password(false);
		if (pass.length == 0) { return; }
		
		err_log_clear();

		var task = new PdfTask();
		task.protect(files, pass, App.overwrite_pdf_protect);

		var action = new ProgressPanelPdfTask(pane, task);
		pane.file_operations.add(action);
		action.execute();
	}

	public void pdf_unprotect(){
		
		var files = selected_pdfs();
		if (files.size == 0){ return; }

		if (!check_pdftk()){ return; }

		if (!check_plugin("pdf")){ return; }

		string pass = prompt_for_pdf_password(false);
		if (pass.length == 0) { return; }
		
		err_log_clear();

		var task = new PdfTask();
		task.unprotect(files, pass, App.overwrite_pdf_unprotect);

		var action = new ProgressPanelPdfTask(pane, task);
		pane.file_operations.add(action);
		action.execute();
	}

	public void pdf_compress(){

		var files = selected_pdfs();
		if (files.size == 0){ return; }

		if (!check_ghostscript()){ return; }

		if (!check_plugin("pdf")){ return; }
		
		err_log_clear();

		var task = new PdfTask();
		task.compress(files, App.overwrite_pdf_compress);

		var action = new ProgressPanelPdfTask(pane, task);
		pane.file_operations.add(action);
		action.execute();
	}

	public void pdf_uncompress(){

		var files = selected_pdfs();
		if (files.size == 0){ return; }

		if (!check_pdftk()){ return; }

		if (!check_plugin("pdf")){ return; }
		
		err_log_clear();

		var task = new PdfTask();
		task.uncompress(files, App.overwrite_pdf_uncompress);

		var action = new ProgressPanelPdfTask(pane, task);
		pane.file_operations.add(action);
		action.execute();
	}
	
	public void pdf_grayscale(){

		var files = selected_pdfs();
		if (files.size == 0){ return; }

		if (!check_ghostscript()){ return; }

		if (!check_plugin("pdf")){ return; }
		
		err_log_clear();

		var task = new PdfTask();
		task.decolor(files, App.overwrite_pdf_decolor);

		var action = new ProgressPanelPdfTask(pane, task);
		pane.file_operations.add(action);
		action.execute();
	}

	public void pdf_optimize(string target){

		var files = selected_pdfs();
		if (files.size == 0){ return; }

		if (!check_ghostscript()){ return; }

		if (!check_plugin("pdf")){ return; }
		
		err_log_clear();

		var task = new PdfTask();
		task.optimize(files, target, App.overwrite_pdf_optimize);

		var action = new ProgressPanelPdfTask(pane, task);
		pane.file_operations.add(action);
		action.execute();
	}

	public void pdf_rotate(string direction){

		var files = selected_pdfs();
		if (files.size == 0){ return; }

		if (!check_pdftk()){ return; }

		if (!check_plugin("pdf")){ return; }
		
		err_log_clear();

		var task = new PdfTask();
		task.rotate(files, direction, App.overwrite_pdf_rotate);

		var action = new ProgressPanelPdfTask(pane, task);
		pane.file_operations.add(action);
		action.execute();
	}
	
	public static string prompt_for_pdf_password(bool confirm){

		log_debug("FileViewList: prompt_for_pdf_password()");

		string msg = "";

		msg += _("Enter password for PDF document") + ":";
		
		string password = PasswordDialog.prompt_user((Gtk.Window) App.main_window, confirm, "", msg);

		return password;
	}

	// Image Actions ------------------------

	public Gee.ArrayList<string> selected_pngs(){

		var files = new Gee.ArrayList<string>();
		
		var selected_items = get_selected_items();
		
		if (selected_items.size == 0){
			return files;
		}

		foreach(var file in selected_items){
			if (file.is_png){
				files.add(file.file_path);
			}
		}
		
		files.sort((a,b)=> {
			return strcmp(a,b);
		});

		return files;
	}

	public Gee.ArrayList<string> selected_jpegs(){

		var files = new Gee.ArrayList<string>();
		
		var selected_items = get_selected_items();
		
		if (selected_items.size == 0){
			return files;
		}

		foreach(var file in selected_items){
			if (file.is_jpeg){
				files.add(file.file_path);
			}
		}
		
		files.sort((a,b)=> {
			return strcmp(a,b);
		});

		return files;
	}

	public Gee.ArrayList<string> selected_images(){

		var files = new Gee.ArrayList<string>();
		
		var selected_items = get_selected_items();
		
		if (selected_items.size == 0){
			return files;
		}

		foreach(var file in selected_items){
			if (file.is_image){
				files.add(file.file_path);
			}
		}
		
		files.sort((a,b)=> {
			return strcmp(a,b);
		});

		return files;
	}

	public void image_optimize_png(){

		var files = selected_pngs();
		if (files.size == 0){
			gtk_messagebox(_("No PNGs Selected"),_("Select the PNG image files to convert"), window, true);
			return;
		}

		if (!check_pngcrush()){ return; }

		if (!check_plugin("image")){ return; }
		
		err_log_clear();

		var task = new ImageTask();
		task.optimize_png(files, App.overwrite_image_optimize_png);
		
		var action = new ProgressPanelImageTask(pane, task);
		pane.file_operations.add(action);
		action.execute();
	}

	public void image_reduce_jpeg(){

		var files = selected_jpegs();
		if (files.size == 0){
			gtk_messagebox(_("No JPEGs Selected"),_("Select the JPEG image files to convert"), window, true);
			return;
		}

		if (!check_plugin("image")){ return; }
		
		err_log_clear();

		var task = new ImageTask();
		task.reduce_jpeg(files, App.overwrite_image_reduce_jpeg);
		
		var action = new ProgressPanelImageTask(pane, task);
		pane.file_operations.add(action);
		action.execute();
	}

	public void image_decolor(){

		var files = selected_images();
		if (files.size == 0){
			gtk_messagebox(_("No Images Selected"),_("Select the image files to convert"), window, true);
			return;
		}

		if (!check_plugin("image")){ return; }
		
		err_log_clear();

		var task = new ImageTask();
		task.decolor(files, App.overwrite_image_decolor);
		
		var action = new ProgressPanelImageTask(pane, task);
		pane.file_operations.add(action);
		action.execute();
	}

	public void image_boost_color(string level){

		var files = selected_images();
		if (files.size == 0){
			gtk_messagebox(_("No Images Selected"),_("Select the image files to convert"), window, true);
			return;
		}

		if (!check_plugin("image")){ return; }
		
		err_log_clear();

		var task = new ImageTask();
		task.boost_color(files, level, App.overwrite_image_boost_color);
		
		var action = new ProgressPanelImageTask(pane, task);
		pane.file_operations.add(action);
		action.execute();
	}

	public void image_reduce_color(string level){

		var files = selected_images();
		if (files.size == 0){
			gtk_messagebox(_("No Images Selected"),_("Select the image files to convert"), window, true);
			return;
		}

		if (!check_plugin("image")){ return; }
		
		err_log_clear();

		var task = new ImageTask();
		task.reduce_color(files, level, App.overwrite_image_reduce_color);
		
		var action = new ProgressPanelImageTask(pane, task);
		pane.file_operations.add(action);
		action.execute();
	}

	public void image_resize(int width, int height){

		var files = selected_images();
		if (files.size == 0){
			gtk_messagebox(_("No Images Selected"),_("Select the image files to convert"), window, true);
			return;
		}

		if (!check_plugin("image")){ return; }
		
		err_log_clear();

		var task = new ImageTask();
		task.resize(files, width, height, App.overwrite_image_resize);
		
		var action = new ProgressPanelImageTask(pane, task);
		pane.file_operations.add(action);
		action.execute();
	}

	public void image_rotate(string direction){

		var files = selected_images();
		if (files.size == 0){
			gtk_messagebox(_("No Images Selected"),_("Select the image files to convert"), window, true);
			return;
		}

		if (!check_plugin("image")){ return; }
		
		err_log_clear();

		var task = new ImageTask();
		task.rotate(files, direction, App.overwrite_image_rotate);
		
		var action = new ProgressPanelImageTask(pane, task);
		pane.file_operations.add(action);
		action.execute();
	}

	public void image_convert(string format){

		var files = selected_images();
		if (files.size == 0){
			gtk_messagebox(_("No Images Selected"),_("Select the image files to convert"), window, true);
			return;
		}

		if (!check_plugin("image")){ return; }
		
		err_log_clear();

		var task = new ImageTask();
		task.convert(files, format, 90, App.overwrite_image_convert);
		
		var action = new ProgressPanelImageTask(pane, task);
		pane.file_operations.add(action);
		action.execute();
	}


	public void verify_checksums(){

		var selected = get_selected_items()[0];

		if (!selected.is_file_hash){ return; }
		
		var tab = panel.add_tab();
		tab.select_tab();
		tab.pane.show_checksum_view();
	
		tab.pane.view_checksum.verify(selected);
	}
	
	// common

	private bool check_pngcrush(){
		return check_tool("pngcrush");
	}
	
	private bool check_pdftk(){
		return check_tool("pdftk");
	}

	private bool check_diffuse(){
		return check_tool("diffuse");
	}

	/*private bool check_bcompare(){
		return check_tool("bcompare");
	}*/

	private bool check_ghostscript(){
		return check_tool("gs");
	}
	
	/*private bool check_imagemagick(){
		return check_tool("convert");
	}*/

	private bool check_youtube_dl(){
		return check_tool("youtube-dl");
	}
	
	public bool check_tool(string tool_cmd){
		
		var tool = App.tools[tool_cmd];
		
		if (!tool.available){
			
			string txt = _("Missing Dependency") + ": %s".printf(tool.name);
			string msg = _("Install required packages and try again") + "\n\n▰ %s".printf(tool.name);
			gtk_messagebox(txt, msg, window, true);
			
			return false;
		}
		
		return true;
	}

	public bool check_plugin(string name){
		
		var plug = App.plugins[name];

		if (!plug.check_version()){
			
			plug.check_availablity(); // check again
		}
		
		if (!plug.available){
			
			string txt = _("Missing Plugin");
			string msg = _("Install required packages and try again") + ":\n\n▰ %s %s".printf(plug.name, "(polo-donation-plugins)");
			gtk_messagebox(txt, msg, window, true);
			
			return false;
		}
		else if (!plug.check_version()){
			
			string txt = _("Outdated Plugin");
			string msg = _("Update required packages and try again") + ":\n\n▰ %s %s".printf(plug.name, "(polo-donation-plugins)");
			gtk_messagebox(txt, msg, window, true);
			
			return false;
		}
		
		return true;
	}

	// hidden --------------------------------
	
	public void hide_selected(){

		if (!is_normal_directory){ return; }
		
		var selected_items = get_selected_items();
		if (selected_items.size == 0){ return; }

		foreach(var item in selected_items){
			if (item.is_hidden) { continue; }
			item.hide_item();	
		}

		refilter();
		refresh_treeview(); // refresh model (and icon transparency)
	}

	public void unhide_selected(){

		if (!is_normal_directory){ return; }
		
		var selected_items = get_selected_items();
		if (selected_items.size == 0){ return; }

		foreach(var item in selected_items){
			if (!item.is_hidden) { continue; }
			if (item.file_name.has_prefix(".")) { continue; }
			item.unhide_item();	
		}

		refilter();
		refresh_treeview(); // refresh model (and icon transparency)
	}

	public void show_hidden(){
		if (show_hidden_files) { return; }
		show_hidden_files = true;
		refresh_hidden();
	}

	public void hide_hidden(){
		if (!show_hidden_files) { return; }
		show_hidden_files = false;
		refresh_hidden();
	}

	// allowed actions

	public bool is_normal_directory {
		get {
			return  (current_item != null)
				&& !current_item.is_trash
				&& !(current_item is FileItemArchive)
				&& !(current_item is FileItemCloud);
		}
	}

	public bool can_cut {
		get {
			return is_normal_directory;
		}
	}
	
	public bool can_copy {
		get {
			return  (current_item != null) && !(current_item is FileItemArchive);
		}
	}

	public bool can_paste {
		get {
			return (current_item != null)
				&& !current_item.is_trash
				&& !(current_item is FileItemArchive);
				//&& !(current_item is FileItemCloud); // allow paste
		}
	}
		
	public bool can_rename {
		get {
			return (current_item != null)
				&& !current_item.is_trash
				&& !(current_item is FileItemArchive);
				//&& !(current_item is FileItemCloud); // allow rename
		}
	}

	public bool can_trash {
		get {
			return is_normal_directory;
		}
	}
	
	public bool can_delete {
		get {
			return  (current_item != null)
				//&& !current_item.is_trash // allow delete
				&& !current_item.is_trashed_item // don't allow trashed subitems to be deleted, not used
				&& !(current_item is FileItemArchive);
				//&& !(current_item is FileItemCloud); // allow delete
		}
	}
	
	// go

	public void go_back(){
		var path = history_go_back();
		if (path.length > 0){
			set_view_path(path, false); // update_history = false
		}
	}

	public void go_forward(){
		var path = history_go_forward();
		if (path.length > 0){
			set_view_path(path, false); // update_history = false
		}
	}

	public void go_up(){

		if ((current_item != null) && (current_item.parent != null)){
			set_view_item(current_item.parent, true);
		}
		else{
			var path = get_location_up();
			if (path.length > 0){
				set_view_path(path, true); // update_history = true
			}
		}
	}

	public void edit_location(){
		pane.pathbar.edit_location();
	}

	// archives - open

	public void browse_archive(){

		log_debug("FileViewList: extract_selected_items_to_same_location()");
		
		var selected = get_selected_items();
		if (selected.size == 0) { return; }


		if (FileItem.is_archive_by_extension(selected[0].file_path)){

			FileItemArchive? arch = FileItemArchive.convert_file_item(selected[0]);

			if (arch == null){
				string txt = _("Not Supported");
				string msg = _("Could not open file as archive");
				gtk_messagebox(txt, msg, window, true);
			}
			else{
				set_view_item(arch);
			}
		} 
	}

	public void extract_selected_items_to_same_location(){

		log_debug("FileViewList: extract_selected_items_to_same_location()");

		// check destination ----------------
		
		if ((current_item is FileItemArchive) || ((current_item is FileItemCloud))){
			log_debug("Cannot extract inside archive or cloud location");
			return;
		}

		// set destination path ----------------------
		
		string outpath = current_item.file_path;

		// --------------------
		
		extract_selected_items_to_selected_location(outpath, true);
	}

	public void extract_selected_items_to_another_location(){

		log_debug("FileViewList: extract_selected_items_to_another_location()");

		// set destination path ----------------------
		
		string default_path = App.user_home;
		if (current_item != null){
			default_path = current_item.file_path;
		}

		string message = _("Select Destination");
		var file_list = gtk_select_files(window, false, false, null, null, message, default_path);
		if (file_list.size == 0){ return; }

		string outpath = file_list[0];

		if ((outpath.length == 0) || !dir_exists(outpath)){
			gtk_messagebox(_("Cannot extract to this location"),_("Destination directory does not exist") + ":\n\n%s".printf(outpath), window, false);
			return;
		}

		// --------------------
		
		extract_selected_items_to_selected_location(outpath, false);
	}

	public void extract_selected_items_to_opposite_location(){

		log_debug("FileViewList: extract_selected_items_to_opposite_location()");
		
		// set destination path ----------------------
		
		var opp_item = panel.opposite_pane.view.current_item;
		string outpath = "";
		if ((opp_item != null) && (dir_exists(opp_item.file_path))){
			outpath = opp_item.file_path;
		}

		if ((outpath.length == 0) || !dir_exists(outpath)){
			gtk_messagebox(_("Invalid Path"),_("Destination directory does not exist") + ":\n\n%s".printf(outpath), window, false);
			return;
		}

		// --------------------
		
		extract_selected_items_to_selected_location(outpath, false);
	}

	public void extract_selected_items_to_selected_location(string outpath, bool new_folder){

		var selected = get_selected_items();
		if (selected.size == 0) { return; }
		
		var list = new Gee.ArrayList<FileItem>();
		
		if (current_item is FileItemArchive){

			var arch = ((FileItemArchive) current_item).archive_base_item;
			
			if (!file_exists(arch.file_path)) {
				log_error("FileViewList: base_archive file_not_found");
				return;
			}

			if (arch.archive_is_solid){
				string txt = _("Not Supported");
				string msg = _("Partial extraction not supported for solid archives");
				gtk_messagebox(txt, msg, window, true);
				return;
			}
			
			arch.extraction_path = path_combine(outpath, "." + random_string());
			
			arch.extract_list.clear();
			foreach(var item in selected){
				arch.extract_list.add(item.file_path);
			}

			list.add(arch);
		}
		else{
			foreach(var item in selected){
				
				if (FileItem.is_archive_by_extension(item.file_path)){
					
					FileItemArchive? arch = FileItemArchive.convert_file_item(item);
					if (arch == null) {
						log_error("extract_selected_items_to_selected_location(): selected_item_not_archive");
						continue;
					}
			
					arch.extract_list.clear();
					// unique path will be generated before execution in FileTask()
					arch.extraction_path = path_combine(outpath, arch.file_title);
					list.add(arch);
				}
			}
		}

		if (list.size == 0) { return; }

		// create action
		var action = new ProgressPanelArchiveTask(pane, list, FileActionType.EXTRACT, new_folder);
		pane.file_operations.add(action);
		action.set_source(current_item);
		action.execute();

		if (current_item is FileItemArchive){

			action.task_complete.connect(()=>{

				//var arch = ((FileItemArchive) current_item).archive_base_item;

				//string src_path = path_combine(arch.extraction_path, current_item.file_path);
				
			});
		}
	}

	public ProgressPanelArchiveTask? extract_selected_item_to_temp_location(FileItemArchive item, out string outpath){
		
		outpath = get_temp_file_path();

		var arch = item;
		arch.extract_list.clear();

		outpath = path_combine(outpath, arch.file_title);
		arch.extraction_path = outpath;

		var list = new Gee.ArrayList<FileItem>();
		list.add(arch);
		
		// create action
		var action = new ProgressPanelArchiveTask(pane, list, FileActionType.EXTRACT, true);
		pane.file_operations.add(action);
		action.set_source(current_item);
		action.execute();

		return action;
	}

	public ProgressPanelArchiveTask? extract_selected_items_to_selected_location_temp(Gee.ArrayList<FileItem> items, out string outpath){
		
		outpath = get_temp_file_path();

		var arch = ((FileItemArchive) current_item).archive_base_item;
		arch.extract_list.clear();

		outpath = path_combine(outpath, arch.file_title);
		arch.extraction_path = outpath;

		var list = new Gee.ArrayList<FileItem>();
		list.add(arch);

		foreach(var item in items){
			arch.extract_list.add(item.file_path);
		}
		
		// create action
		var action = new ProgressPanelArchiveTask(pane, list, FileActionType.EXTRACT, true);
		pane.file_operations.add(action);
		action.set_source(current_item);
		action.execute();

		return action;
	}

	public void compress_selected_items(){

		var selected = get_selected_items();

		if (selected.size == 0) {
			gtk_messagebox(_("No Files Selected"), _("There are no files selected for compression"), window, true);
			return;
		}
		
		if (current_item is FileItemArchive){
			gtk_messagebox(_("Cannot create archive in this location"),_("Destination path is inside an archive (!)"), window, false);
			return;
		}

		var dlg = new CreateArchiveWindow(window, selected, current_item);
		var response = dlg.run();

		if (response == Gtk.ResponseType.ACCEPT){
		
			// create action
			var action = new ProgressPanelArchiveTask(pane, selected, FileActionType.COMPRESS, true);
			pane.file_operations.add(action);
			action.set_source(current_item);
			action.set_task(dlg.get_task());
			action.set_archive(dlg.get_archive());
			action.execute();
		}
	}

	// columns menu

	/*private bool menu_columns_popup (Gdk.EventButton? event) {

		var menu_columns = build_menu_columns();

		if (event != null) {
			menu_columns.popup (null, null, null, event.button, event.time);
		} else {
			menu_columns.popup (null, null, null, 0, Gtk.get_current_event_time());
		}

		return true;
	}*/

	//private Gtk.Menu build_menu_columns(){
		//var menu = new Gtk.Menu();
		//menu.reserve_toggle_size = false;
		//menu_columns = menu;

		/*foreach(var col in column_list){

			if (col.name == "spacer"){
				continue;
			}

			col.selected = false;
			foreach(var tvcol in treeview.get_columns()){
				if (col.col_ref == tvcol){
					col.selected = true;
					break;
				}
			}

			// menu_item
			var menu_item = new Gtk.CheckMenuItem.with_label(col.title);
			menu_item.active = col.selected || col.required;
			menu_item.sensitive = !col.required;
			menu.add(menu_item);

			menu_item.toggled.connect (() => {
				col.selected = menu_item.active;

				App.selected_columns = TreeViewListColumn.get_selected_column_string(column_list);

				TreeViewListColumn.load_columns(ref treeview, column_list, App.selected_columns);

			});
		}*/

		//menu.show_all();

		//return menu;
		//menu_item_columns.set_submenu(menu);
	//}

}

public enum FileViewColumn{
	ITEM = 0,
	ICON = 1,
	NAME = 2,
	TILE_MARKUP = 3,
	THUMBKEY = 4,
	LV_SIZE = 5,
	UNSORTABLE = 9,
	SIZE = 10,
	MODIFIED = 11,
	PERMISSIONS = 12,
	OWNER = 13,
	GROUP = 14,
	PACKED_SIZE = 15,
	ROW_HEIGHT = 16,
	HASH_MD5 = 17,
	ACCESS = 18,
	MIMETYPE = 19,
	FILETYPE = 20,
	SYMLINK_TARGET = 21,
	ORIGINAL_PATH = 22,
	DELETION_DATE = 23
}
