/*
 * FileConflictWindow.vala
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

public class FileConflictDialog : Gtk.Dialog {

	private FileTask task;
	private Gtk.Box vbox_main;

	private Gtk.TreeView treeview;
	private Gtk.ScrolledWindow scrolled;

	private Gtk.Button btn_replace;
	private Gtk.Button btn_replace_older;
	private Gtk.Button btn_skip;

	private Gtk.Box preview_box;

	private Gtk.Image img_src;
	private Gtk.Label lbl_size_src;
	private Gtk.Label lbl_modified_src;
	private Gtk.Label lbl_type_src;

	private Gtk.Image img_dest;
	private Gtk.Label lbl_size_dest;
	private Gtk.Label lbl_modified_dest;
	private Gtk.Label lbl_type_dest;

	private static int thumb_size = 128;

	private bool custom_mode = false;
	public FileReplaceMode replace_mode = FileReplaceMode.NONE;

	public FileConflictDialog.with_parent(Window parent, FileTask _task) {

		set_transient_for(parent);
		set_modal(true);
		set_skip_taskbar_hint(true);
		set_skip_pager_hint(true);
		window_position = WindowPosition.CENTER_ON_PARENT;
		deletable = false;
		resizable = true;
		icon = get_app_icon(16,".svg");
		title = _("File Conflict");

		task = _task;

		// get content area
		vbox_main = get_content_area();
		vbox_main.set_size_request(400,-1);
		vbox_main.margin = 6;
		vbox_main.spacing = 6;
		//add(vbox_main);

		init_ui();

        show_all();
	}

	private void init_ui(){

		var label = new Gtk.Label(format_text(_("Replace Existing Files?"), true, false, true));
		label.set_use_markup(true);
		label.xalign = 0.0f;
		label.margin_bottom = 12;
		vbox_main.add(label);

		label = new Gtk.Label("%'ld %s".printf(task.conflicts.keys.size, _("file(s) exist at the destination")));
		label.set_use_markup(true);
		label.xalign = 0.0f;
		label.margin_bottom = 12;
		label.margin_left = 6;
		vbox_main.add(label);

		add_actions(vbox_main);

		init_treeview(vbox_main);

		init_preview_area(vbox_main);

		gtk_hide(preview_box);
	}

	private void add_actions(Gtk.Box box) {

		var bbox = new Gtk.ButtonBox(Orientation.HORIZONTAL);
		bbox.set_spacing (6);
		bbox.set_layout(Gtk.ButtonBoxStyle.START);
		bbox.hexpand = true;
		//bbox.margin_bottom = 12;
		box.add(bbox);

		// replace all

		var button = new Gtk.Button.with_label(_("Replace All"));
		button.set_tooltip_text(_("Replace all existing files"));
		bbox.add(button);
		btn_replace = button;
		//bbox.set_child_non_homogeneous(button, true);

		button.clicked.connect(()=>{

			if (custom_mode){

				TreeIter iter;
				var store = (Gtk.ListStore) treeview.model;
				bool iterExists = store.get_iter_first (out iter);
				while (iterExists) {

					FileConflictItem conflict;
					store.get (iter, 0, out conflict, -1);

					conflict.replace = true;
					store.set (iter, 1, conflict.replace);

					iterExists = store.iter_next (ref iter);
				}
			}
			else{
				replace_mode = FileReplaceMode.REPLACE;
				this.response(Gtk.ResponseType.OK);
			}
		});

		// replace older

		button = new Gtk.Button.with_label(_("Replace Older"));
		button.set_tooltip_text(_("Replace older files only"));
		bbox.add(button);
		btn_replace_older = button;
		//bbox.set_child_non_homogeneous(button, true);

		button.clicked.connect(()=>{

			if (custom_mode){

				TreeIter iter;
				var store = (Gtk.ListStore) treeview.model;
				bool iterExists = store.get_iter_first (out iter);

				while (iterExists) {

					FileConflictItem conflict;
					store.get (iter, 0, out conflict, -1);

					if (conflict.source_item.modified.compare(conflict.dest_item.modified) > 0){
						conflict.replace = true;
					}
					else{
						conflict.replace = false;
					}

					store.set (iter, 1, conflict.replace);

					iterExists = store.iter_next (ref iter);
				}
			}
			else{
				replace_mode = FileReplaceMode.REPLACE_OLDER;
				this.response(Gtk.ResponseType.OK);
			}
		});

		// skip all

		button = new Gtk.Button.with_label(_("Skip All"));
		button.set_tooltip_text(_("Skip existing files"));
		bbox.add(button);
		btn_skip = button;
		//bbox.set_child_non_homogeneous(button, true);

		button.clicked.connect(()=>{

			if (custom_mode){

				TreeIter iter;
				var store = (Gtk.ListStore) treeview.model;
				bool iterExists = store.get_iter_first (out iter);
				while (iterExists) {

					FileConflictItem conflict;
					store.get (iter, 0, out conflict, -1);

					conflict.replace = false;
					store.set (iter, 1, conflict.replace);

					iterExists = store.iter_next (ref iter);
				}
			}
			else{
				replace_mode = FileReplaceMode.SKIP;
				this.response(Gtk.ResponseType.OK);
			}
		});

		// details

		button = new Gtk.Button.with_label(_("Details"));
		button.set_tooltip_text(_("Show the list of files"));
		bbox.add(button);
		//bbox.set_child_non_homogeneous(button, true);
		var btn_custom = button;

		button.clicked.connect(()=>{

			if (custom_mode){
				this.response(Gtk.ResponseType.OK);
			}
			else{
				replace_mode = FileReplaceMode.CUSTOM;
				gtk_show(scrolled);
				refresh_treeview();

				btn_custom.label = _("OK");
				btn_custom.set_tooltip_text(_("Replace the selected files"));

				btn_replace.label = _("Select All");
				btn_replace.set_tooltip_text(_("Select all files in list"));

				btn_replace_older.label = _("Select Older");
				btn_replace_older.set_tooltip_text(_("Select older files in list"));

				btn_skip.label = _("Select None");
				btn_skip.set_tooltip_text(_("Un-select all files in list"));

				treeview.get_selection().select_path(new Gtk.TreePath.from_indices (0));

				custom_mode = true;
			}
		});

		// cancel

		button = new Gtk.Button.with_label(_("Cancel"));
		button.set_tooltip_text(_("Cancel this file operation"));
		bbox.add(button);

		button.clicked.connect(()=>{
			replace_mode = FileReplaceMode.NONE;
			this.response(Gtk.ResponseType.CANCEL);
		});
	}

	private void init_treeview(Gtk.Box box){

		var label = new Gtk.Label(format_text(_("Select files to replace:"), false, false, false));
		label.set_use_markup(true);
		label.xalign = 0.0f;
		label.margin_top = 12;
		box.add(label);

		label.set_no_show_all(true);

		// treeview
		treeview = new Gtk.TreeView();
		treeview.get_selection().mode = SelectionMode.SINGLE;
		treeview.headers_clickable = false;
		treeview.rubber_banding = false;
		treeview.has_tooltip = false;
		treeview.reorderable = false;
		treeview.activate_on_single_click = true;
		treeview.headers_visible = true;

		// scrolled
		scrolled = new Gtk.ScrolledWindow(null, null);
		scrolled.set_shadow_type (ShadowType.ETCHED_IN);
		scrolled.hscrollbar_policy = PolicyType.AUTOMATIC;
		scrolled.vscrollbar_policy = PolicyType.AUTOMATIC;
		scrolled.add (treeview);
		scrolled.set_size_request(500,300);
		box.add(scrolled);

		scrolled.set_no_show_all(true);

		scrolled.notify["visible"].connect(()=>{
			label.no_show_all = scrolled.no_show_all;
			label.visible = scrolled.visible;
		});

		// toggle -----------------------------

		// column
		var col = new TreeViewColumn();
		col.title = "(R)";
		col.clickable = true;
		col.resizable = true;
		//col.expand = true;
		treeview.append_column(col);

		// toggle
		var cell_toggle = new CellRendererToggle ();
		cell_toggle.activatable = true;
		col.pack_start (cell_toggle, false);

		// render toggle
		col.set_cell_data_func (cell_toggle, (cell_layout, cell, model, iter) => {
			var crt = cell as Gtk.CellRendererToggle;
			FileConflictItem conflict;
			bool replace;
			model.get (iter, 0, out conflict, 1, out replace, -1);
			crt.active = replace;
		});

		// toggle handler
		cell_toggle.toggled.connect((path) => {
			TreeIter iter;
			var model = (Gtk.ListStore) treeview.model;
			model.get_iter_from_string (out iter, path);

			FileConflictItem conflict;
			bool replace;
			model.get (iter, 0, out conflict, 1, out replace, -1);
			replace = !replace;
			model.set (iter, 1, replace);
			conflict.replace = replace;
		});

		// name ------------------------

		// column
		col = new TreeViewColumn();
		col.title = _("Item Name");
		col.clickable = false;
		col.resizable = true;
		//col.expand = true;
		treeview.append_column(col);

		// cell icon
		var cell_pix = new CellRendererPixbuf ();
		col.pack_start(cell_pix, false);

		// text
		var cell_text = new CellRendererText ();
		col.pack_start (cell_text, false);

		// render text
		col.set_cell_data_func (cell_text, (cell_layout, cell, model, iter) => {
			var crt = cell as Gtk.CellRendererText;
			FileConflictItem conflict;
			model.get (iter, 0, out conflict, -1);
			crt.text = conflict.source_item.file_name;
		});

		// render icon
		col.set_cell_data_func (cell_pix, (cell_layout, cell, model, iter) => {

			var pixcell = cell as Gtk.CellRendererPixbuf;

			FileConflictItem conflict;
			model.get (iter, 0, out conflict, -1);

			FileItem item = conflict.source_item;

			if (item.icon != null) {
				pixcell.gicon = item.icon;
			}
			else{
				log_error("gicon is null: %s".printf(item.file_name));

				if (item.file_type == FileType.DIRECTORY) {
					pixcell.stock_id = "gtk-directory";
				}
				else{
					pixcell.stock_id = "gtk-file";
				}
			}

			pixcell.stock_size = 16;
		});


		// location ------------------------

		// column
		col = new TreeViewColumn();
		col.title = _("Path");
		col.clickable = false;
		col.resizable = true;
		//col.expand = true;
		treeview.append_column(col);

		// text
		cell_text = new CellRendererText ();
		col.pack_start (cell_text, false);

		// render text
		col.set_cell_data_func (cell_text, (cell_layout, cell, model, iter) => {
			var crt = cell as Gtk.CellRendererText;
			FileConflictItem conflict;
			model.get (iter, 0, out conflict, -1);
			crt.text = conflict.source_item.file_location[conflict.source_base_dir.file_path.length + 1: conflict.source_item.file_location.length];
		});

		treeview.get_selection().changed.connect(on_treeview_selection_changed);
	}

	private void on_treeview_selection_changed(){

		var sel = treeview.get_selection();
		var store = (Gtk.ListStore) treeview.model;
		TreeIter iter;
		bool iterExists = store.get_iter_first (out iter);

		while (iterExists) {

			if (sel.iter_is_selected (iter)){

				FileConflictItem conflict;
				store.get (iter, 0, out conflict);

				refresh_preview(conflict);
				break;
			}

			iterExists = store.iter_next (ref iter);
		}
	}

	private void refresh_treeview(){

		var model = new Gtk.ListStore(2,
			typeof(FileConflictItem),
			typeof(bool)
		);

		foreach(var conflict in task.conflicts.values){
			TreeIter iter0;
			model.append(out iter0);
			model.set (iter0, 0, conflict);
			model.set (iter0, 1, true);
		}

		treeview.set_model(model);
		treeview.columns_autosize();
	}

	private void init_preview_area(Gtk.Box box){

		//preview_box = new Gtk.Frame(null);
		//box.add(preview_box);

		preview_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
		box.add(preview_box);

		// src -----------------

		var hbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
		preview_box.add(hbox);

		img_src = new Gtk.Image();
		hbox.add(img_src);

		var vbox = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
		hbox.add(vbox);

		var label = new Gtk.Label("");
		label.xalign = 0.0f;
		vbox.add(label);
		lbl_type_src = label;

		label = new Gtk.Label("");
		label.xalign = 0.0f;
		vbox.add(label);
		lbl_size_src = label;

		label = new Gtk.Label("");
		label.xalign = 0.0f;
		vbox.add(label);
		lbl_modified_src = label;

		var separator = new Gtk.Separator (Gtk.Orientation.HORIZONTAL);
		preview_box.add(separator);

		// dest -----------------

		hbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
		preview_box.add(hbox);

		img_dest = new Gtk.Image();
		hbox.add(img_dest);

		vbox = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
		hbox.add(vbox);

		label = new Gtk.Label("");
		label.xalign = 0.0f;
		vbox.add(label);
		lbl_type_dest = label;

		label = new Gtk.Label("");
		label.xalign = 0.0f;
		vbox.add(label);
		lbl_size_dest = label;

		label = new Gtk.Label("");
		label.xalign = 0.0f;
		vbox.add(label);
		lbl_modified_dest = label;
	}

	private void refresh_preview(FileConflictItem conflict){

		// src ---------------------------

		var item = conflict.source_item;
		var image = img_src;
		set_image_for_item(item, image);

		//img_src.set_size_request(32, 32);

		lbl_type_src.label = "%s: %s".printf(_("Type"), item.content_type_desc);
		lbl_size_src.label = "%s: %s".printf(_("Size"), format_file_size(item.size));
		lbl_modified_src.label = "%s: %s".printf(_("Modified"), item.modified.format ("%Y-%m-%d %H:%M"));

		// dest -------------------------

		item = conflict.dest_item;
		image = img_dest;
		set_image_for_item(item, image);

		//img_dest.set_size_request(32, 32);

		lbl_type_dest.label = "%s: %s".printf(_("Type"), item.content_type_desc);
		lbl_size_dest.label = "%s: %s".printf(_("Size"), format_file_size(item.size));
		lbl_modified_dest.label = "%s: %s".printf(_("Modified"), item.modified.format ("%Y-%m-%d %H:%M"));

		gtk_show(preview_box);
	}

	private void set_image_for_item(FileItem item, Gtk.Image image){
		
		ThumbTask task;
		var thumb = item.get_image(thumb_size, true, false, false, out task);

		if (thumb != null) {
			image.pixbuf = thumb;
		}
		else if (item.icon != null) {
			image.gicon = item.icon;
		}
		else{
			if (item.file_type == FileType.DIRECTORY) {
				image.icon_name = "gtk-directory";
			}
			else{
				image.icon_name = "gtk-file";
			}
		}
	}
}


