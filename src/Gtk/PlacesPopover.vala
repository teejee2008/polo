/*
 * PlacesPopover.vala
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

public class PlacesPopover : Gtk.Popover {

	// reference properties ----------

	private MainWindow window{
		get { return App.main_window; }
	}
	
	FileViewPane _pane;
	private FileViewPane? pane {
		get{
			if (_pane != null){ return _pane; }
			else { return window.active_pane; }
		}
	}

	private FileViewList? view{
		get{ return (pane == null) ? null : pane.view; }
	}

	private LayoutPanel? panel {
		get { return (pane == null) ? null : pane.panel; }
	}

	// -------------------------------

	private Gtk.TreeView treeview_places;
	private Gtk.TreeView treeview_bm;
	private Gtk.Paned paned;

	private int def_width = 600;
	private int def_height = 500;
	
	private Gtk.Box vbox_main;
	private Gtk.Box vbox_right;
	private Gtk.Box vbox_left;

	private Gtk.Button btn_bookmark;
	private Gtk.Button btn_edit;

	private Gtk.TreeViewColumn col_name;
	private Gtk.CellRendererText cell_name;
	private Gtk.TreeViewColumn col_delete;
	private Gtk.TreeViewColumn col_reorder;

	private bool edit_mode = false;
	
	public PlacesPopover(Gtk.Widget? _relative_to, FileViewPane? parent_pane){
		
		this.relative_to = _relative_to;

		this._pane = parent_pane;

		init_ui();

		this.closed.connect(on_closed);
	}

	private void init_ui(){

		log_debug("PlacesPopover(): init_ui()");
		
		//vbox_main
		vbox_main = new Gtk.Box(Orientation.VERTICAL, 0);
		vbox_main.margin = 0;
		vbox_main.set_size_request(def_width, def_height);
		add(vbox_main);

		paned = new Gtk.Paned(Gtk.Orientation.HORIZONTAL);
		vbox_main.add(paned);
		
		init_places();

		init_bookmarks();

		init_actions();
	}

	private void on_closed(){

		save_bookmarks();

		App.bookmarks_position = paned.position;
	}
	
	// places ---------------------------------------
	
	private void init_places() {

		var vbox = new Gtk.Box(Orientation.VERTICAL, 0);
		vbox.margin = 0;
		paned.pack1(vbox, true, true); // resize, shrink
		vbox_left = vbox;
		
		// treeview
		var treeview = new Gtk.TreeView();
		treeview.get_selection().mode = Gtk.SelectionMode.MULTIPLE;
		treeview.headers_visible = false;
		treeview.headers_clickable = false;
		treeview.rubber_banding = false;
		treeview.has_tooltip = true;
		treeview.enable_search = false;
		treeview.set_rules_hint(false);
		treeview.activate_on_single_click = true;
		treeview.expand = true;
		treeview_places = treeview;
		
		// scrolled
		var scrolled = new Gtk.ScrolledWindow(null, null);
		scrolled.set_shadow_type (ShadowType.ETCHED_IN);
		scrolled.hscrollbar_policy = PolicyType.AUTOMATIC;
		scrolled.vscrollbar_policy = PolicyType.AUTOMATIC;
		//scrolled.add (treeview);
		//scrolled.hexpand = true;
		//scrolled.vexpand = true;
		//paned.pack1(scrolled, true, true); // resize, shrink

		scrolled.add(treeview);
		
		vbox.add(scrolled);
		
		//paned.pack1(vbox, true, true);
		
		// columns -------------------------------

		var col = new TreeViewColumn();
		col.expand = true;
		treeview.append_column(col);

		// cell icon
		var cell_pix = new Gtk.CellRendererPixbuf();
		cell_pix.xpad = 3;
		col.pack_start(cell_pix, false);

		// render icon
		col.set_cell_data_func (cell_pix, (cell_layout, cell, model, iter) => {

			var pixcell = cell as Gtk.CellRendererPixbuf;

			Gdk.Pixbuf pix;
			model.get (iter, ColumnItem.ICON, out pix, -1);

			pixcell.pixbuf = pix;

			bool enabled;
			model.get (iter, ColumnItem.ENABLED, out enabled, -1);

			pixcell.sensitive = enabled;
		});

		// text
		var cell_text = new CellRendererText ();
		col.pack_start (cell_text, false);

		// render text
		col.set_cell_data_func (cell_text, (cell_layout, cell, model, iter) => {
			
			var crt = cell as Gtk.CellRendererText;
			
			string name;
			model.get (iter, ColumnItem.NAME, out name, -1);
			
			crt.text = name;

			bool enabled;
			model.get (iter, ColumnItem.ENABLED, out enabled, -1);

			crt.sensitive = enabled;
		});

		treeview.set_tooltip_column(ColumnItem.TOOLTIP);

		var cursor = new Gdk.Cursor.from_name(Gdk.Display.get_default(), "pointer");
		scrolled.get_window().set_cursor(cursor);
		
		// events -------------------------------

		treeview.row_activated.connect(treeview_places_row_activated);
	}

	private void treeview_places_row_activated(TreePath path, TreeViewColumn? column){

		log_debug("FileViewList: treeview_places_row_activated()");

		var model = (Gtk.ListStore) treeview_places.model;
		
		TreeIter iter;
		model.get_iter_from_string(out iter, path.to_string());

		GtkBookmark bm;
		model.get (iter, ColumnItem.BOOKMARK, out bm, -1);

		this.hide();
		
		if (bm.path.length > 0){
			pane.view.set_view_path(bm.path);
		}
		else{
			pane.view.set_view_path(bm.uri);
		}
	}

	// bookmarks -----------------------------
	
	private void init_bookmarks() {

		var vbox = new Gtk.Box(Orientation.VERTICAL, 0);
		vbox.margin = 0;
		paned.pack2(vbox, true, true); // resize, shrink
		vbox_right = vbox;
		
		// treeview
		var treeview = new Gtk.TreeView();
		treeview.get_selection().mode = Gtk.SelectionMode.MULTIPLE;
		treeview.headers_visible = false;
		treeview.headers_clickable = false;
		treeview.rubber_banding = false;
		treeview.enable_search = false;
		treeview.set_rules_hint(false);
		treeview.activate_on_single_click = true;
		treeview.expand = true;
		treeview_bm = treeview;
		
		// scrolled
		var scrolled = new Gtk.ScrolledWindow(null, null);
		scrolled.set_shadow_type (ShadowType.ETCHED_IN);
		scrolled.hscrollbar_policy = PolicyType.AUTOMATIC;
		scrolled.vscrollbar_policy = PolicyType.AUTOMATIC;
		//scrolled.hexpand = true;
		//scrolled.vexpand = true;
		//paned.pack2(scrolled, true, true); // resize, shrink

		scrolled.add(treeview);
		
		vbox.add(scrolled);

		// grip --------------------------------------------

		var col = new TreeViewColumn();
		col.clickable = false;
		col.resizable = false;
		treeview.append_column(col);
		col_reorder = col;
		
		// cell icon
		var cell_pix = new Gtk.CellRendererPixbuf();
		col.pack_start(cell_pix, false);

		// render icon
		col.set_cell_data_func (cell_pix, (cell_layout, cell, model, iter) => {
			
			var pixcell = cell as Gtk.CellRendererPixbuf;
			
			pixcell.pixbuf = IconManager.lookup("view-list-details-symbolic", 16, false, true);
		});

		col_reorder.visible = false;

		// name ---------------------------------------------
		
		col = new TreeViewColumn();
		col.clickable = false;
		col.resizable = false;
		col.expand = true;
		treeview.append_column(col);
		col_name = col;
		
		// cell icon --------------------------------------
		
		cell_pix = new Gtk.CellRendererPixbuf();
		cell_pix.xpad = 3;
		col.pack_start(cell_pix, false);

		// render icon
		col.set_cell_data_func (cell_pix, (cell_layout, cell, model, iter) => {

			var pixcell = cell as Gtk.CellRendererPixbuf;

			Gdk.Pixbuf pix;
			model.get (iter, ColumnItem.ICON, out pix, -1);

			pixcell.pixbuf = pix;

			bool enabled;
			model.get (iter, ColumnItem.ENABLED, out enabled, -1);

			pixcell.sensitive = enabled;
		});

		// text -------------------------------------------
		
		var cell_text = new CellRendererText ();
		col.pack_start (cell_text, false);
		cell_name = cell_text;
		
		// render text
		col.set_cell_data_func (cell_text, (cell_layout, cell, model, iter) => {
			
			var crt = cell as Gtk.CellRendererText;
			
			string name;
			model.get (iter, ColumnItem.NAME, out name, -1);
			
			crt.text = name;

			bool enabled;
			model.get (iter, ColumnItem.ENABLED, out enabled, -1);

			crt.sensitive = enabled;
		});

		//cell_text.editable = true;
		cell_text.edited.connect((path, new_name)=>{
			
			TreeIter iter;
			var model = (Gtk.ListStore) treeview_bm.model;

			model.get_iter_from_string(out iter, path);

			GtkBookmark bm;
			model.get(iter, ColumnItem.BOOKMARK, out bm, -1);

			model.set(iter, ColumnItem.NAME, new_name, -1);

			bm.name = new_name;
			GtkBookmark.save_bookmarks();
		});

		// delete action --------------------------------------------

		col = new TreeViewColumn();
		col.clickable = false;
		col.resizable = false;
		treeview.append_column(col);
		col_delete = col;
		
		// cell icon
		cell_pix = new Gtk.CellRendererPixbuf();
		col.pack_start(cell_pix, false);

		// render icon
		col.set_cell_data_func (cell_pix, (cell_layout, cell, model, iter) => {
			
			var pixcell = cell as Gtk.CellRendererPixbuf;
			
			pixcell.pixbuf = IconManager.lookup("tab-close", 16, false, true);
		});

		col_delete.visible = false;

		//  --------------------------------------------------

		// tooltip
		treeview.has_tooltip = true;
		treeview.query_tooltip.connect(treeview_query_tooltip);

		// cursor
		var cursor = new Gdk.Cursor.from_name(Gdk.Display.get_default(), "pointer");
		scrolled.get_window().set_cursor(cursor);

		treeview.row_activated.connect(treeview_bookmarks_row_activated);
	}

	private bool treeview_query_tooltip(int x, int y, bool keyboard_tooltip, Tooltip tooltip) {

		TreeModel model;
		TreePath path;
		TreeIter iter;
		TreeViewColumn column;

		if (treeview_bm.get_tooltip_context (ref x, ref y, keyboard_tooltip, out model, out path, out iter)){
			
			int bx, by;
			treeview_bm.convert_widget_to_bin_window_coords(x, y, out bx, out by);
			
			if (treeview_bm.get_path_at_pos(bx, by, null, out column, null, null)){

				GtkBookmark bm;
				model.get(iter, 0, out bm, -1);

				string tt = "";

				if (column == col_reorder){
					tt = _("Drag to Re-order");
				}
				else if (column == col_delete){
					tt = _("Click to Remove");
				}
				else{
					if (edit_mode){
						tt = _("Click to Rename");
					}
					else{
						tt = bm.path;
					}
				}
					
				tooltip.set_markup(tt);
				return true;
			}
		}

		return false;
	}

	
	private void treeview_bookmarks_row_activated(TreePath path, TreeViewColumn? column){

		log_debug("FileViewList: treeview_bookmarks_row_activated()");

		if (edit_mode){

			if (column == col_delete){

				var model = (Gtk.ListStore) treeview_bm.model;
			
				TreeIter iter;
				model.get_iter_from_string(out iter, path.to_string());

				GtkBookmark bm;
				model.get (iter, ColumnItem.BOOKMARK, out bm, -1);

				GtkBookmark.remove_bookmark(bm.uri);
				model.remove(ref iter);
			}
		}
		else{
		
			this.hide();
			
			var model = (Gtk.ListStore) treeview_bm.model;
			
			TreeIter iter;
			model.get_iter_from_string(out iter, path.to_string());

			GtkBookmark bm;
			model.get (iter, ColumnItem.BOOKMARK, out bm, -1);

			if (!bm.exists()){
				
				string txt = _("Path Not Found");
				
				string msg = "%s. %s.\n\n%s".printf(
					_("Could not find bookmarked path"),
					_("Folder may have been deleted or renamed, or device may have been unmounted"),
					bm.path);
					
				gtk_messagebox(txt, msg, window, true);
				
				return;
			}

			if (bm.path.length > 0){
				pane.view.set_view_path(bm.path);
			}
			else{
				pane.view.set_view_path(bm.uri);
			}
		}
	}

	// actions ----------------------------------
	
	private void init_actions(){

		var hbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
		vbox_right.add(hbox);

		hbox.margin_top = 5;
		hbox.margin_left = 3;
		hbox.margin_right = 3;
		hbox.margin_bottom = 3;

		// spacer -----------------------------------
		
		//var dummy = new Gtk.Label("");
		//dummy.hexpand = true;
		//hbox.add(dummy);
		
		// bookmark ---------------------------------------
		
		var bbox = new Gtk.ButtonBox(Gtk.Orientation.HORIZONTAL);
		bbox.set_layout(Gtk.ButtonBoxStyle.CENTER);
		bbox.spacing = 6;
		hbox.add(bbox);

		bbox.hexpand = true;

		var button = new Gtk.Button.with_label(_("Bookmark"));
		button.set_image(IconManager.lookup_image("user-bookmarks", 16, false, true));
		button.always_show_image = true;
		bbox.add(button);
		btn_bookmark = button;
		
		button.clicked.connect(btn_bookmark_clicked);

		// edit -----------------------------------------------------

		button = new Gtk.Button.with_label(_("Edit"));
		button.set_image(IconManager.lookup_image("item-gray", 16, false, true));
		button.always_show_image = true;
		bbox.add(button);
		btn_edit = button;
		
		button.clicked.connect(btn_edit_clicked);
	}

	private void btn_bookmark_clicked(){

		log_debug("btn_bookmark_clicked()");
		
		if (pane.view.current_item != null){

			//var path = pane.view.current_item.file_path;
			var uri = pane.view.current_item.file_uri;

			if (!GtkBookmark.is_bookmarked(uri)){
				GtkBookmark.add_bookmark(uri);
				log_debug("bookmark added: %s".printf(uri));
			}
			else if (GtkBookmark.is_bookmarked(uri)){
				GtkBookmark.remove_bookmark(uri);
				log_debug("bookmark removed: %s".printf(uri));
			}
		}
		else{
			log_debug("pane.view.current_item = null");
		}

		refresh_bookmarks();
		
		refresh_actions();

		this.hide();
	}

	private void btn_edit_clicked(){

		log_debug("btn_edit_clicked()");
		
		edit_mode = !edit_mode;

		cell_name.editable = edit_mode;
		col_delete.visible = edit_mode;
		col_reorder.visible = edit_mode;
		treeview_bm.reorderable = edit_mode;

		if (!edit_mode){
			save_bookmarks();
		}
		
		refresh_bookmarks();
		
		refresh_actions();
	}

	// refresh ----------------------------
	
	public void show_popup(){

		edit_mode = false;
		
		refresh();
		
		gtk_show(this);
	}
	
	private void refresh(){

		refresh_places();

		refresh_bookmarks();

		refresh_actions();

		this.show_all();

		if ((App.bookmarks_position < 10) || (App.bookmarks_position > (def_width - 10))){
			App.bookmarks_position = (int) (def_width * 0.4);
		}

		paned.set_position(App.bookmarks_position);
	}

	private void refresh_places(){

		log_debug("refresh_places()");
		
		var model = new Gtk.ListStore(6, typeof(GtkBookmark), typeof(string), typeof(string), typeof(Gdk.Pixbuf?), typeof(bool), typeof(string));
		
		treeview_places.set_model(model);
		
		add_bookmark(model, new GtkBookmark("file:///", _("Filesystem")));
		add_bookmark(model, new GtkBookmark("file://" + App.user_dirs.user_home, _("Home")));
		add_bookmark(model, new GtkBookmark("file://" + App.user_dirs.user_documents, _("Documents")));
		add_bookmark(model, new GtkBookmark("file://" + App.user_dirs.user_downloads, _("Downloads")));
		add_bookmark(model, new GtkBookmark("file://" + App.user_dirs.user_pictures, _("Pictures")));
		add_bookmark(model, new GtkBookmark("file://" + App.user_dirs.user_music, _("Music")));
		add_bookmark(model, new GtkBookmark("file://" + App.user_dirs.user_videos, _("Videos")));
		add_bookmark(model, new GtkBookmark("file://" + App.user_dirs.user_desktop, _("Desktop")));
		add_bookmark(model, new GtkBookmark("file://" + App.user_dirs.user_public, _("Public")));
		add_bookmark(model, new GtkBookmark("trash:///", _("Trash") + " (%s)".printf(format_file_size(App.trashcan.trash_can_size))));
	
		foreach(var mount in GvfsMounts.get_mounts(App.user_id)){
			
			var bm = new GtkBookmark(mount.file_uri, mount.display_name);
			
			add_bookmark(model, bm);
		}

		treeview_places.expand_all();
	}

	private void refresh_bookmarks(){

		var model = new Gtk.ListStore(6, typeof(GtkBookmark), typeof(string), typeof(string), typeof(Gdk.Pixbuf?), typeof(bool), typeof(string));
		
		treeview_bm.set_model(model);

		foreach(var bm in GtkBookmark.bookmarks){

			add_bookmark(model, bm);
		}

		treeview_bm.expand_all();

		cell_name.editable = edit_mode;
		col_delete.visible = edit_mode;
		col_reorder.visible = edit_mode;
		treeview_bm.reorderable = edit_mode;
	}

	private void add_bookmark(Gtk.ListStore model, GtkBookmark bm){
		
		TreeIter iter;
		model.append(out iter);
		model.set(iter, ColumnItem.BOOKMARK, bm);
		model.set(iter, ColumnItem.NAME, bm.name);
		model.set(iter, ColumnItem.PATH, bm.uri);
		model.set(iter, ColumnItem.ICON, bm.get_icon(22));
		model.set(iter, ColumnItem.ENABLED, bm.exists());
		model.set(iter, ColumnItem.TOOLTIP, bm.path);
	}
	
	private void refresh_actions(){

		if (pane.view.current_item != null){

			//var path = pane.view.current_item.file_path;
			var uri = pane.view.current_item.file_uri;
			
			if (GtkBookmark.is_bookmarked(uri)){
				btn_bookmark.set_image(IconManager.lookup_image("user-bookmarks", 16, false, true));
			}
			else{
				btn_bookmark.set_image(IconManager.lookup_image("bookmark-missing", 16, false, true));
			}
		}

		if (edit_mode){
			btn_edit.set_image(IconManager.lookup_image("item-green", 16, false, true));
		}
		else{
			btn_edit.set_image(IconManager.lookup_image("item-gray", 16, false, true));
		}
	}

	private enum ColumnItem {
		BOOKMARK = 0,
		NAME = 1,
		PATH = 2,
		ICON = 3,
		ENABLED = 4,
		TOOLTIP = 5
	}

	// save

	private void save_bookmarks(){

		var list = new Gee.ArrayList<GtkBookmark>();

		var model = (Gtk.ListStore) treeview_bm.model;

		TreeIter iter;
		bool iterExists = model.get_iter_first (out iter);
		
		while (iterExists){

			GtkBookmark bm;
			model.get (iter, ColumnItem.BOOKMARK, out bm, -1);
			list.add(bm);
			
			iterExists = model.iter_next(ref iter);
		}

		GtkBookmark.bookmarks = list;
		GtkBookmark.save_bookmarks();
	}
}




