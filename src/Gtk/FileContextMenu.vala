/*
 * FileContextMenu.vala
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

public enum FileActionType{
	NONE,
	CUT,
	COPY,
	PASTE,
	TRASH,
	DELETE,
	DELETE_TRASHED,
	RESTORE,
	SHRED,
	PASTE_SYMLINKS_AUTO,
	PASTE_SYMLINKS_ABSOLUTE,
	PASTE_SYMLINKS_RELATIVE,
	PASTE_HARDLINKS,
	LIST_ARCHIVE,
	TEST_ARCHIVE,
	EXTRACT,
	COMPRESS,
	KVM_DISK_MERGE,
	KVM_DISK_CONVERT
}

public class FileContextMenu : Gtk.Menu {

	private Gee.ArrayList<FileItem> selected_items;
	private FileItem? selected_item = null;
	private bool is_trash = false;
	private bool is_archive = false;

	// parents
	public FileViewList view;
	public FileViewPane pane;
	public MainWindow window;

	public FileContextMenu(FileViewPane parent_pane){
		
		log_debug("FileContextMenu()");

		margin = 0;

		pane = parent_pane;
		view = pane.view;
		window = App.main_window;

		if (window.refresh_apps_pending){
			window.refresh_apps_pending = false;
			DesktopApp.query_apps();
		}

		if (view.current_item.is_trash || view.current_item.is_trashed_item){
			is_trash = true;
			build_file_menu_for_trash();
		}
		else if (view.current_item.is_archive || view.current_item.is_archived_item){
			is_archive = true;
			build_file_menu_for_archive();
		}
		else{
			build_file_menu();
		}
	}

	// file context menu

	private void build_file_menu(){

		log_debug("FileContextMenu: build_file_menu()");

		Gdk.RGBA gray = Gdk.RGBA();
		gray.parse("rgba(200,200,200,1)");

		this.reserve_toggle_size = false;

		var sg_icon = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);
		var sg_label = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);

		selected_items = view.get_selected_items();
		if (selected_items.size > 0){
			selected_item = selected_items[0];
		}

		add_open(this, sg_icon, sg_label);

		//add_file_compare();

		add_new(this, sg_icon, sg_label);

		gtk_menu_add_separator(this); //---------------------------

		add_cut(this, sg_icon, sg_label);
		
		add_copy(this, sg_icon, sg_label);

		add_paste(this, sg_icon, sg_label);

		add_rename(this, sg_icon, sg_label);

		add_trash(this, sg_icon, sg_label);

		add_delete(this, sg_icon, sg_label);

		add_actions(this, sg_icon, sg_label);

		gtk_menu_add_separator(this); //----------------------

		add_disk_usage(this, sg_icon, sg_label);
		
		add_archive_actions(this, sg_icon, sg_label);

		add_iso_actions(this, sg_icon, sg_label);

		add_pdf_actions(this, sg_icon, sg_label);

		add_kvm_actions(this, sg_icon, sg_label);

		gtk_menu_add_separator(this); // -----------------------------

		add_sort_column(this, sg_icon, sg_label);

		add_properties(this, sg_icon, sg_label);

		show_all();
	}

	private void build_file_menu_for_trash(){
		
		log_debug("FileContextMenu: build_file_menu_for_trash()");

		Gdk.RGBA gray = Gdk.RGBA();
		gray.parse("rgba(200,200,200,1)");

		this.reserve_toggle_size = false;

		var sg_icon = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);
		var sg_label = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);

		selected_items = view.get_selected_items();
		if (selected_items.size > 0){
			selected_item = selected_items[0];
		}

		add_delete(this, sg_icon, sg_label);

		add_restore(this, sg_icon, sg_label);

		add_trash_open_original_location(this, sg_icon, sg_label);

		add_trash_open_trash_directory(this, sg_icon, sg_label);

		gtk_menu_add_separator(this);

		add_copy(this, sg_icon, sg_label);

		add_copy_across(this, sg_icon, sg_label);

		add_copy_to(this, sg_icon, sg_label);

		gtk_menu_add_separator(this);

		add_properties(this, sg_icon, sg_label);

		show_all();
	}

	private void build_file_menu_for_archive(){
		
		log_debug("FileContextMenu: build_file_menu_for_archive()");

		Gdk.RGBA gray = Gdk.RGBA();
		gray.parse("rgba(200,200,200,1)");

		this.reserve_toggle_size = false;

		var sg_icon = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);
		var sg_label = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);

		selected_items = view.get_selected_items();
		if (selected_items.size > 0){
			selected_item = selected_items[0];
		}

		add_extract_to(this, sg_icon, sg_label);
		
		add_extract_across(this, sg_icon, sg_label);
	
		add_extract_here(this, sg_icon, sg_label);

		show_all();
	}


	private void add_open(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){

		log_debug("FileContextMenu: add_open()");

		var menu_item = gtk_menu_add_item(
					menu,
					_("Open"),
					"",
					IconManager.lookup_image("folder", 16),
					sg_icon,
					sg_label);

		menu_item.sensitive = (selected_items.size > 0);

		var sub_menu = new Gtk.Menu();
		sub_menu.reserve_toggle_size = false;
		menu_item.submenu = sub_menu;

		var sg_icon_sub = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);
		var sg_label_sub = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);

		add_open_with_default(sub_menu, sg_icon_sub, sg_label_sub);

		add_run_in_terminal(sub_menu, sg_icon, sg_label);

		add_open_new_tab(sub_menu, sg_icon, sg_label);

		add_open_new_window(sub_menu, sg_icon, sg_label);

		add_open_new_admin_window(sub_menu, sg_icon, sg_label);

		gtk_menu_add_separator(sub_menu);
		
		add_open_with(sub_menu, sg_icon_sub, sg_label_sub);

		add_set_default_app(sub_menu, sg_icon_sub, sg_label_sub);
	}

	private void add_open_with_default(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){

		if (selected_item == null){ return; }
		
		log_debug("FileContextMenu: add_open_with_default()");

		Gtk.MenuItem menu_item = null;

		// open with default app -------------------------

		if ((selected_item.file_type != FileType.DIRECTORY) && !selected_item.is_archive){

			var app = MimeApp.get_default_app(selected_item.content_type);

			if (app != null){

				menu_item = gtk_menu_add_item(
					menu,
					//_("Open With") + " " +
					app.name,
					_("Open with default application"),
					get_shared_icon(app.icon, "folder-open.png",16),
					sg_icon,
					sg_label);
			}
		}

		// "Open" item if default app is unknown ------------------

		if (menu_item == null){

			menu_item = gtk_menu_add_item(
				menu,
				_("Open"),
				_("Open selected item"),
				IconManager.lookup_image("folder-open", 16),
				sg_icon,
				sg_label);
		}

		menu_item.activate.connect (() => {
			view.open(selected_item, null);
		});

		menu_item.sensitive = (selected_items.size > 0);
	}
	
	private void add_open_with(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){

		log_debug("FileContextMenu: add_open_with()");

		if (selected_item == null){ return; }
		
		var menu_item = gtk_menu_add_item(
			menu,
			_("Open With"),
			_("Open with other applications"),
			null,
			sg_icon,
			sg_label);

		menu_item.sensitive = (selected_items.size > 0);

		var sub_menu = new Gtk.Menu();
		sub_menu.reserve_toggle_size = false;
		menu_item.submenu = sub_menu;

		var sg_icon_sub = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);
		var sg_label_sub = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);

		log_msg("content_type: %s".printf(selected_item.content_type));

		var supported_apps = MimeApp.get_supported_apps(selected_item.content_type);
		if (selected_item.content_type.has_prefix("text/")
			|| selected_item.content_type.contains("shellscript")){
			supported_apps = DesktopApp.text_editors;
		}

		foreach(var supported_app in supported_apps){

			//log_debug("supported_app: %s".printf(supported_app.name));

			var submenu_item = gtk_menu_add_item(
				sub_menu,
				supported_app.name,
				_("Open With") + " " + supported_app.name,
				get_shared_icon(supported_app.icon,"",16),
				sg_icon_sub,
				sg_label_sub);

			submenu_item.activate.connect(() => {
				view.open(view.get_selected_items().get(0), supported_app);
			});
		}

		sub_menu.show_all();

		menu_item.sensitive = (selected_items.size > 0);
	}

	private void add_set_default_app(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){

		log_debug("FileContextMenu: add_open_with()");

		if (selected_item == null){ return; }

		var menu_item = gtk_menu_add_item(
			menu,
			_("Set Default"),
			_("Set default application for file type"),
			null,
			sg_icon,
			sg_label);

		menu_item.sensitive = (selected_items.size > 0);

		var sub_menu = new Gtk.Menu();
		sub_menu.reserve_toggle_size = false;
		menu_item.submenu = sub_menu;

		var sg_icon_sub = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);
		var sg_label_sub = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);

		log_msg("content_type: %s".printf(selected_item.content_type));

		var supported_apps = MimeApp.get_supported_apps(selected_item.content_type);
		if (selected_item.content_type.has_prefix("text/")
			|| selected_item.content_type.contains("shellscript")){
			supported_apps = DesktopApp.text_editors;
		}
		
		foreach(var supported_app in supported_apps){

			//log_debug("supported_app: %s".printf(supported_app.name));

			var submenu_item = gtk_menu_add_item(
				sub_menu,
				supported_app.name,
				_("Set as Default and Open With") + " " + supported_app.name,
				get_shared_icon(supported_app.icon,"",16),
				sg_icon_sub,
				sg_label_sub);

			submenu_item.activate.connect(() => {
				view.set_default_app(view.get_selected_items().get(0), supported_app);
			});
		}

		sub_menu.show_all();

		menu_item.sensitive = (selected_items.size > 0);
	}


	private void add_open_new_tab(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){

		log_debug("FileContextMenu: add_open_new_tab()");

		if ((selected_items.size == 0) || (selected_items[0].file_type != FileType.DIRECTORY)){ return; }

		var menu_item = gtk_menu_add_item(
			menu,
			_("Open in New Tab"),
			_("Open folder in new tab"),
			IconManager.lookup_image("folder-open", 16),
			sg_icon,
			sg_label);

		menu_item.activate.connect (() => {
			view.open_in_new_tab();
		});

		menu_item.sensitive = true;
	}

	private void add_open_new_window(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){

		log_debug("FileContextMenu: add_open_new_window()");

		if ((selected_items.size == 0) || (selected_items[0].file_type != FileType.DIRECTORY)){ return; }

		var menu_item = gtk_menu_add_item(
			menu,
			_("Open in New Window"),
			_("Open folder in new window"),
			IconManager.lookup_image("folder-open", 16),
			sg_icon,
			sg_label);

		menu_item.activate.connect (() => {
			view.open_in_new_window();
		});

		menu_item.sensitive = true;
	}

	private void add_open_new_admin_window(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){

		log_debug("FileContextMenu: add_open_new_admin_window()");

		if ((selected_items.size == 0) || (selected_items[0].file_type != FileType.DIRECTORY)){ return; }

		var menu_item = gtk_menu_add_item(
			menu,
			_("Open as Admin"),
			_("Open folder as administrator"),
			IconManager.lookup_image("folder-open", 16),
			sg_icon,
			sg_label);

		menu_item.activate.connect (() => {
			view.open_in_admin_window();
		});

		menu_item.sensitive = true;
	}


	private void add_new(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){

		log_debug("FileContextMenu: add_new()");

		if (view.current_item == null){ return; }

		var menu_item = gtk_menu_add_item(
					menu,
					_("New"),
					"",
					IconManager.lookup_image("list-add", 16),
					sg_icon,
					sg_label);

		//menu_item.sensitive = (selected_items.size > 0);

		var sub_menu = new Gtk.Menu();
		sub_menu.reserve_toggle_size = false;
		menu_item.submenu = sub_menu;

		var sg_icon_sub = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);
		var sg_label_sub = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);

		add_new_file(sub_menu, sg_icon_sub, sg_label_sub);

		add_new_folder(sub_menu, sg_icon_sub, sg_label_sub);
		
		add_new_from_template(sub_menu, sg_icon_sub, sg_label_sub);

		gtk_menu_add_separator(sub_menu); // --------------------

		add_new_tab(sub_menu, sg_icon_sub, sg_label_sub);
		
		add_new_window(sub_menu, sg_icon_sub, sg_label_sub);
		
		add_new_admin_window(sub_menu, sg_icon_sub, sg_label_sub);
		
		add_new_terminal(sub_menu, sg_icon_sub, sg_label_sub);

		gtk_menu_add_separator(sub_menu); // --------------------

		add_open_templates_folder(sub_menu, sg_icon_sub, sg_label_sub);
	}

	private void add_new_folder(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){

		log_debug("FileContextMenu: add_new_folder()");

		var menu_item = gtk_menu_add_item(
			menu,
			_("Folder"),
			_("Create new folder in this location"),
			IconManager.lookup_image("folder", 16),
			sg_icon,
			sg_label);

		menu_item.activate.connect (() => {
			log_debug("file_context_menu.create_directory()");
			view.create_directory();
		});

		menu_item.sensitive = view.is_normal_directory && view.current_item.can_write;
	}

	private void add_new_file(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){

		log_debug("FileContextMenu: add_new_file()");

		var menu_item = gtk_menu_add_item(
			menu,
			_("File"),
			_("Create new file in this location"),
			IconManager.lookup_image("text-x-generic", 16),
			sg_icon,
			sg_label);

		menu_item.activate.connect (() => {
			log_debug("file_context_menu.create_file()");
			view.create_file();
		});

		menu_item.sensitive = view.is_normal_directory && view.current_item.can_write;
	}

	private void add_new_terminal(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){

		log_debug("FileContextMenu: add_new_terminal()");

		// open terminal

		var menu_item = gtk_menu_add_item(
			menu,
			_("Terminal"),
			_("Open a terminal window"),
			IconManager.lookup_image("list-add",16),
			sg_icon,
			sg_label);

		menu_item.activate.connect (() => {
			view.open_terminal();
		});

		// open terminal (admin)

		/*menu_item = gtk_menu_add_item(
			this,
			_("Open Terminal (Admin)"),
			_("Open an administrator terminal window"),
			get_shared_icon("terminal","",16),
			sg_icon,
			sg_label);

		menu_item.activate.connect (() => {
			view.open_terminal(true);
		});*/
	}

	private void add_new_tab(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){

		log_debug("FileContextMenu: add_new_tab()");

		// open in new tab ----------------------------

		var menu_item = gtk_menu_add_item(
			menu,
			_("Tab"),
			_("Open new tab"),
			IconManager.lookup_image("list-add",16),
			sg_icon,
			sg_label);

		menu_item.activate.connect (() => {
			view.open_tab();
		});
	}

	private void add_new_window(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){

		log_debug("FileContextMenu: add_new_window()");

		// open in new tab ----------------------------

		var menu_item = gtk_menu_add_item(
			menu,
			_("Window"),
			_("Open new window"),
			IconManager.lookup_image("list-add",16),
			sg_icon,
			sg_label);

		menu_item.activate.connect (() => {
			view.open_in_new_window();
		});
	}

	private void add_new_admin_window(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){

		log_debug("FileContextMenu: add_open_new_admin_window()");

		// open in new tab ----------------------------

		var menu_item = gtk_menu_add_item(
			menu,
			_("Admin Window"),
			_("Open window as administrator"),
			IconManager.lookup_image("list-add",16),
			sg_icon,
			sg_label);

		menu_item.activate.connect (() => {
			view.open_in_admin_window();
		});
	}

	private void add_new_from_template(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){

		log_debug("FileContextMenu: add_new_from_template()");

		var sep = gtk_menu_add_separator(menu); // --------------------
		
		string templates_path = "/usr/share/templates/.source";
		bool ok1 = add_templates_from_folder(menu, sg_icon, sg_label, templates_path);

		templates_path = App.user_dirs.user_templates;
		bool ok2 = add_templates_from_folder(menu, sg_icon, sg_label, templates_path);

		bool item_added = ok1 || ok2;
		if (!item_added){
			menu.remove(sep);
		}
	}

	private bool add_templates_from_folder(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label, string templates_folder){

		log_debug("FileContextMenu: add_templates_from_folder(): %s".printf(templates_folder));

		if (!dir_exists(templates_folder)){ return false; }

		var templates = new FileItem.from_path(templates_folder);
		templates.query_children(1);

		bool item_added = false;
		foreach(var template_file in templates.children.values){

			if (template_file.file_extension == ".desktop"){
				continue;
			}
			
			var menu_item = gtk_menu_add_item(
				menu,
				template_file.file_title,
				_("Create new file from template"),
				template_file.get_icon_image(16, false, false),
				sg_icon,
				sg_label);

			menu_item.activate.connect (() => {
				view.create_file_from_template(template_file.file_path);
			});

			menu_item.sensitive = view.is_normal_directory && view.current_item.can_write;

			item_added = true;
		}

		return item_added;
	}

	private void add_open_templates_folder(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){
		
		var menu_item = gtk_menu_add_item(
			menu,
			_("Open Templates Folder"),
			_("Open templates folder"),
			IconManager.lookup_image("folder-open",16),
			sg_icon,
			sg_label);

		menu_item.activate.connect (() => {
			view.open_in_new_tab(App.user_dirs.user_templates);
		});

	}


	private void add_cut(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){

		log_debug("FileContextMenu: add_cut()");

		// copy --------------------------------

		var menu_item = gtk_menu_add_item(
			menu,
			_("Cut"),
			_("Cut selected items"),
			IconManager.lookup_image("edit-cut",16),
			sg_icon,
			sg_label);

		menu_item.activate.connect (() => {
			log_debug("file_context_menu.cut()");
			view.cut();
		});

		menu_item.sensitive = (selected_items.size > 0) && (selected_item.can_delete);
	}
	
	private void add_copy(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){

		log_debug("FileContextMenu: add_copy()");

		// copy --------------------------------

		var menu_item = gtk_menu_add_item(
			menu,
			_("Copy"),
			_("Copy selected items"),
			IconManager.lookup_image("edit-copy",16),
			sg_icon,
			sg_label);

		menu_item.activate.connect (() => {
			log_debug("file_context_menu.copy()");
			view.copy();
		});

		menu_item.sensitive = (selected_items.size > 0);
	}
	
	private void add_paste(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){

		log_debug("FileContextMenu: add_paste()");

		// paste --------------------------------

		var menu_item = gtk_menu_add_item(
			menu,
			_("Paste Here"),
			_("Paste selected items in this directory"),
			IconManager.lookup_image("edit-paste",16),
			sg_icon,
			sg_label);

		menu_item.activate.connect (() => {
			log_debug("file_context_menu.paste()");
			view.paste();
		});

		menu_item.sensitive = (window.pending_action != null);
	}

	private void add_rename(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){

		log_debug("FileContextMenu: add_rename()");

		var menu_item = gtk_menu_add_item(
			menu,
			_("Rename"),
			_("Rename selected item"),
			IconManager.lookup_image("edit-rename",16),
			sg_icon,
			sg_label);

		menu_item.activate.connect (() => {
			log_debug("file_context_menu.rename()");
			view.rename();
		});

		menu_item.sensitive = (selected_items.size == 1) && selected_item.can_rename;
	}

	private void add_trash(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){

		log_debug("FileContextMenu: add_trash()");

		// trash -------------------------------------

		var menu_item = gtk_menu_add_item(
			menu,
			_("Trash"),
			_("Move files to recycle bin"),
			IconManager.lookup_image("list-remove",16),
			sg_icon,
			sg_label);

		menu_item.activate.connect (() => {
			log_debug("file_context_menu.trash()");
			view.trash();
		});

		menu_item.sensitive = (selected_items.size > 0) && selected_item.can_trash;
	}

	private void add_delete(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){

		log_debug("FileContextMenu: add_delete()");

		// delete ------------------------------------

		var menu_item = gtk_menu_add_item(
			menu,
			_("Delete"),
			_("Delete selected items permanently"),
			IconManager.lookup_image("list-remove",16),
			sg_icon,
			sg_label);

		menu_item.activate.connect (() => {
			log_debug("file_context_menu.delete_items()");
			view.delete_items();
		});

		menu_item.sensitive = (selected_items.size > 0) && selected_item.can_delete
			&& (!selected_item.is_trashed_item || ((selected_item.parent != null) && selected_item.parent.is_trash));
	}



	private void add_run_in_terminal(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){

		if (selected_item == null){ return; }

		if (!selected_item.content_type.contains("shellscript")
		&& !selected_item.content_type.contains("executable")){
			return;
		}

		log_debug("FileContextMenu: add_run_in_terminal()");

		var menu_item = gtk_menu_add_item(
			menu,
			_("Run in Terminal"),
			_("Run the selected script in a terminal window"),
			get_shared_icon("terminal","",16),
			sg_icon,
			sg_label);

		menu_item.activate.connect (() => {
			view.run_in_terminal();
		});
	}


	private void add_trash_open_original_location(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){

		if (selected_item == null){ return; }
		
		log_debug("FileContextMenu: add_trash_open_original_location()");

		// open in new tab ----------------------------

		var menu_item = gtk_menu_add_item(
			menu,
			_("Open Original Location"),
			_("Open the original location of trashed item in a new tab"),
			IconManager.lookup_image("folder-open",16),
			sg_icon,
			sg_label);

		menu_item.activate.connect (() => {
			view.open_original_location();
		});

		menu_item.sensitive = (selected_items.size == 1) && selected_item.can_rename && view.current_item.is_trash;
	}

	private void add_trash_open_trash_directory(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){

		if (selected_item == null){ return; }

		log_debug("FileContextMenu: add_trash_open_trash_directory()");

		// open in new tab ----------------------------

		var menu_item = gtk_menu_add_item(
			menu,
			_("Open Trash Directory"),
			_("Open the actual location of trashed item in a new tab"),
			IconManager.lookup_image("folder-open",16),
			sg_icon,
			sg_label);

		menu_item.activate.connect (() => {
			view.open_trash_dir();
		});

		menu_item.sensitive = (selected_items.size == 1) && selected_item.can_rename && view.current_item.is_trash;
	}
	
	private void add_file_compare(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){

		log_debug("FileContextMenu: add_file_compare()");

		// compare with Diffuse --------------------------

		var menu_item = gtk_menu_add_item(
			menu,
			_("Compare"),//TODO: show dialog for selecting second file
			_("Compare file with file of same name in other pane"),
			IconManager.lookup_image("folder-open",16),
			sg_icon,
			sg_label);

		menu_item.activate.connect (() => {

			//var file1 = selected_items[0];
			//if (current_tab.view2.current_item.children.has_key(file1.file_name)){
				//var file2 = current_tab.view2.current_item.children[file1.file_name];
				//Posix.system("diffuse '%s' '%s'".printf(escape_single_quote(file1.file_path), escape_single_quote(file2.file_path)));
			//}
		});
	}


	private void add_actions(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){

		log_debug("FileContextMenu: add_copy_move_advanced()");

		// ... -------------------------

		var menu_item = gtk_menu_add_item(
			menu,
			_("..."),
			_("More options"),
			null,
			sg_icon,
			sg_label);

		menu_item.sensitive = (selected_items.size > 0) || (window.pending_action != null);

		var sub_menu = new Gtk.Menu();
		sub_menu.reserve_toggle_size = false;
		menu_item.submenu = sub_menu;

		var sg_icon_sub = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);
		var sg_label_sub = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);

		// items ------------------------------

		add_copy_to(sub_menu, sg_icon_sub, sg_label_sub);
		
		add_copy_across(sub_menu, sg_icon_sub, sg_label_sub);

		gtk_menu_add_separator(sub_menu); //--------------------------------

		add_move_to(sub_menu, sg_icon_sub, sg_label_sub);
		
		add_move_across(sub_menu, sg_icon_sub, sg_label_sub);

		gtk_menu_add_separator(sub_menu); //--------------------------------

		add_paste_symlinks_auto(sub_menu, sg_icon_sub, sg_label_sub);
		
		add_paste_symlinks_relative(sub_menu, sg_icon_sub, sg_label_sub);

		add_paste_hardlinks(sub_menu, sg_icon_sub, sg_label_sub);

		gtk_menu_add_separator(sub_menu); //------------------------------

		add_hide(sub_menu, sg_icon_sub, sg_label_sub);

		add_unhide(sub_menu, sg_icon_sub, sg_label_sub);

		add_follow_symlink(sub_menu, sg_icon_sub, sg_label_sub);

		add_copy_path(sub_menu, sg_icon_sub, sg_label_sub);
	}

	private void add_copy_to(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){
		
		var menu_item = gtk_menu_add_item(
			menu,
			_("Copy To..."),
			_("Copy to another location"),
			IconManager.lookup_image("edit-copy",16),
			sg_icon,
			sg_label);

		menu_item.activate.connect (() => {
			log_debug("file_context_menu.copy_to()");
			view.copy_to();
		});

		menu_item.sensitive = (selected_items.size > 0);
	}

	private void add_move_to(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){
	
		var menu_item = gtk_menu_add_item(
			menu,
			_("Move To..."),
			_("Move to another location"),
			IconManager.lookup_image("edit-cut",16),
			sg_icon,
			sg_label);

		menu_item.activate.connect (() => {
			log_debug("file_context_menu.move_to()");
			view.move_to();
		});

		menu_item.sensitive = (selected_items.size > 0) && (selected_item.can_delete);
	}

	private void add_copy_across(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){
		
		var menu_item = gtk_menu_add_item(
			menu,
			_("Copy Across"),
			_("Copy to other pane"),
			IconManager.lookup_image("edit-copy",16),
			sg_icon,
			sg_label);

		menu_item.activate.connect (() => {
			log_debug("file_context_menu.copy_across()");
			view.copy_across();
		});

		menu_item.sensitive = (selected_items.size > 0);
	}

	private void add_move_across(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){

		var menu_item = gtk_menu_add_item(
			menu,
			_("Move Across"),
			_("Move to other pane"),
			IconManager.lookup_image("edit-cut",16),
			sg_icon,
			sg_label);

		menu_item.activate.connect (() => {
			log_debug("file_context_menu.move_across()");
			view.move_across();
		});

		menu_item.sensitive = (selected_items.size > 0) && (selected_item.can_delete);
	}

	private void add_paste_symlinks_auto(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){

		var menu_item = gtk_menu_add_item(
			menu,
			_("Paste Symlinks"),
			_("Paste symbolic links to selected items in this directory. Absolute path will be used for symlink target."),
			IconManager.lookup_image("edit-paste",16),
			sg_icon,
			sg_label);

		menu_item.activate.connect (() => {
			log_debug("file_context_menu.paste_symlinks_absolute()");
			view.paste_symlinks_absolute();
		});

		menu_item.sensitive = (window.pending_action != null);

	}

	private void add_paste_symlinks_relative(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){

		var menu_item = gtk_menu_add_item(
			menu,
			_("Paste Symlinks (relative)"),
			_("Paste symbolic links to selected items in this directory. Relative paths will be used for symlink target.\n\nThis is useful if the files are on a removable disk, since absolute paths will change if disk is mounted at another path."),
			IconManager.lookup_image("edit-paste",16),
			sg_icon,
			sg_label);

		menu_item.activate.connect (() => {
			log_debug("file_context_menu.paste_symlinks_relative()");
			view.paste_symlinks_relative();
		});

		menu_item.sensitive = (window.pending_action != null);
	}

	private void add_paste_hardlinks(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){

		var menu_item = gtk_menu_add_item(
			menu,
			_("Paste Hardlinks"),
			_("Paste hard links to selected items in this directory.\n\nHard links to a file point to the same data on disk. So the files can appear in multiple directories without taking up additional space."),
			IconManager.lookup_image("edit-paste",16),
			sg_icon,
			sg_label);

		menu_item.activate.connect (() => {
			log_debug("file_context_menu.paste_hardlinks()");
			view.paste_hardlinks();
		});

		menu_item.sensitive = (window.pending_action != null);
	}
	
	private void add_hide(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){

		if (selected_items.size == 0) { return; }
		if (!view.is_normal_directory) { return; }

		log_debug("FileContextMenu: add_hide()");

		// hide

		var menu_item = gtk_menu_add_item(
			menu,
			_("Hide"),
			_("Hide selected items"),
			null,
			sg_icon,
			sg_label);

		menu_item.activate.connect (() => {
			log_debug("file_context_menu.hide_items()");
			view.hide_selected();
		});

		menu_item.sensitive = (selected_items.size > 0);
	}

	private void add_unhide(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){

		if (selected_items.size == 0) { return; }
		if (!view.is_normal_directory) { return; }
		
		log_debug("FileContextMenu: add_unhide()");

		var menu_item = gtk_menu_add_item(
			menu,
			_("Unhide"),
			_("Unhide selected items"),
			null,
			sg_icon,
			sg_label);

		menu_item.activate.connect (() => {
			log_debug("file_context_menu.unhide_items()");
			view.unhide_selected();
		});

		menu_item.sensitive = (selected_items.size > 0);
	}

	private void add_follow_symlink(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){

		log_debug("FileContextMenu: add_follow_symlink()");

		if ((selected_item == null) || !selected_item.is_symlink){ return; }

		var menu_item = gtk_menu_add_item(
			menu,
			_("Follow Symlink Path"),
			_("Open the symbolic link's target location"),
			null,
			sg_icon,
			sg_label);

		menu_item.activate.connect (() => {
			view.follow_symlink();
		});
	}

	private void add_copy_path(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){

		log_debug("FileContextMenu: add_copy_path()");

		// cut -------------------------

		var menu_item = gtk_menu_add_item(
			menu,
			_("Copy Path(s)"),
			_("Copy file path to clipboard"),
			IconManager.lookup_image("edit-copy",16),
			sg_icon,
			sg_label);

		menu_item.activate.connect (() => {
			log_debug("file_context_menu.cut()");
			view.copy_selected_paths_to_clipboard();
		});

		menu_item.sensitive = (selected_items.size > 0);
	}

	private void add_restore(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){

		log_debug("FileContextMenu: add_restore()");

		// restore ------------------------------------

		var menu_item = gtk_menu_add_item(
			menu,
			_("Restore"),
			_("Restore item to the original location"),
			get_shared_icon("gtk-add","file-add.png",16),
			sg_icon,
			sg_label);

		menu_item.activate.connect (() => {
			log_debug("file_context_menu.restore_items()");
			view.restore_items();
		});

		menu_item.sensitive = (selected_items.size > 0) && (selected_item.can_rename) && (view.current_item.is_trash);
	}


	private void add_archive_actions(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){

		log_debug("FileContextMenu: add_archive_actions()");

		var menu_item = gtk_menu_add_item(
			menu,
			_("Archive"),
			"",
			IconManager.lookup_image("package-x-generic",16),
			sg_icon,
			sg_label);
			
		var sub_menu = new Gtk.Menu();
		//sub_menu.reserve_toggle_size = false;
		menu_item.submenu = sub_menu;

		var sg_icon_sub = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);
		var sg_label_sub = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);
		
		add_compress(sub_menu, sg_icon_sub, sg_label_sub);
		
		add_extract_to(sub_menu, sg_icon_sub, sg_label_sub);
		
		add_extract_across(sub_menu, sg_icon_sub, sg_label_sub);
		
		add_extract_here(sub_menu, sg_icon_sub, sg_label_sub);
	}
	
	private void add_compress(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){

		log_debug("FileContextMenu: add_compress()");

		var menu_item = gtk_menu_add_item(
			menu,
			_("Compress"),
			_("Compress selected items and create new archive"),
			null,//IconManager.lookup_image("package-x-generic",16),
			sg_icon,
			sg_label);

		menu_item.activate.connect (() => {
			log_debug("file_context_menu.compress()");
			view.compress_selected_items();
		});

		menu_item.sensitive = (selected_items.size > 0);
	}

	private void add_extract_to(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){

		if (!can_extract){ return; }
		
		log_debug("FileContextMenu: add_extract_to()");

		var menu_item = gtk_menu_add_item(
			menu,
			_("Extract To.."),
			_("Extract archives to another location"),
			null,//IconManager.lookup_image("package-x-generic",16),
			sg_icon,
			sg_label);

		menu_item.activate.connect (() => {
			view.extract_selected_items_to_another_location();
		});

		menu_item.sensitive = !selected_item.is_archived_item; //item.is_archive || item.is_archived_item;
	}

	private void add_extract_across(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){

		if (!can_extract){ return; }
		
		log_debug("FileContextMenu: add_extract_across()");

		var menu_item = gtk_menu_add_item(
			menu,
			_("Extract Across"),
			_("Extract archives to the opposite pane"),
			null,//IconManager.lookup_image("package-x-generic",16),
			sg_icon,
			sg_label);

		menu_item.activate.connect (() => {
			view.extract_selected_items_to_opposite_location();
		});

		menu_item.sensitive = !selected_item.is_archived_item; //item.is_archive || item.is_archived_item;
	}

	private void add_extract_here(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){

		if (!can_extract){ return; }
		
		log_debug("FileContextMenu: add_extract_here()");

		var menu_item = gtk_menu_add_item(
			menu,
			_("Extract Here"),
			_("Extract archives to new folders in this location"),
			null,//IconManager.lookup_image("package-x-generic",16),
			sg_icon,
			sg_label);

		menu_item.activate.connect (() => {
			view.extract_selected_items_to_same_location();
		});

		menu_item.sensitive = !selected_item.is_archived_item; //item.is_archive && !item.is_archived_item;
	}

	private bool can_extract {
		get {
			return selected_items_contain_archives || view.current_item.is_archive || view.current_item.is_archived_item;
		}
	}


	private void add_disk_usage(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){

		if (!view.is_normal_directory){ return; }

		log_debug("FileContextMenu: add_disk_usage()");

		var baobab = DesktopApp.get_app_by_filename("org.gnome.baobab.desktop");
		if (baobab == null){ return; }

		var menu_item = gtk_menu_add_item(
			menu,
			_("Disk Usage"),
			_("Analyze disk usage"),
			null,//get_shared_icon(baobab.icon,"",16),
			sg_icon,
			sg_label);

		menu_item.activate.connect(() => {
			view.analyze_disk_usage();
		});
	}


	private void add_iso_actions(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){

		if (selected_item == null){ return; }

		if (!selected_item.file_name.has_suffix(".iso")){ return; }
		
		log_debug("FileContextMenu: add_iso_actions()");
	
		var menu_item = gtk_menu_add_item(
			menu,
			_("ISO"),
			"",
			IconManager.lookup_image("media-cdrom",16),
			sg_icon,
			sg_label);
			
		var sub_menu = new Gtk.Menu();
		//sub_menu.reserve_toggle_size = false;
		menu_item.submenu = sub_menu;

		var sg_icon_sub = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);
		var sg_label_sub = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);
		
		add_mount_iso(sub_menu, sg_icon_sub, sg_label_sub);
		
		add_boot_iso(sub_menu, sg_icon_sub, sg_label_sub);

		//add_write_iso(sub_menu, sg_icon_sub, sg_label_sub);
	}
	
	private void add_mount_iso(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){
		
		if (selected_item == null){ return; }

		if (!selected_item.file_name.has_suffix(".iso")){ return; }

		log_debug("FileContextMenu: add_mount_iso()");

		var menu_item = gtk_menu_add_item(
			menu,
			_("Mount"),
			_("Mount the ISO file as a read-only disk"),
			null, //get_shared_icon("media-cdrom","",16),
			sg_icon,
			sg_label);

		menu_item.activate.connect (() => {
			view.mount_iso();
		});
	}

	private void add_boot_iso(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){
		
		if (selected_item == null){ return; }

		if (!selected_item.file_name.has_suffix(".iso")){ return; }

		log_debug("FileContextMenu: add_boot_iso()");

		var menu_item = gtk_menu_add_item(
			menu,
			_("Boot"),
			_("Boot ISO file in QEMU/KVM virtual machine"),
			null,//get_shared_icon("media-cdrom","",16),
			sg_icon,
			sg_label);

		menu_item.activate.connect (() => {
			view.boot_iso();
		});
	}

	private void add_write_iso(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){
		
		if (selected_item == null){ return; }

		if (!selected_item.file_name.has_suffix(".iso")){ return; }

		log_debug("FileContextMenu: add_write_iso()");

		var menu_item = gtk_menu_add_item(
			menu,
			_("Write USB"),
			_("Write ISO file to USB drive"),
			null,//get_shared_icon("media-cdrom","",16),
			sg_icon,
			sg_label);

		menu_item.activate.connect (() => {
			view.write_iso();
		});

		menu_item.sensitive = true;
	}


	private void add_kvm_actions(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){

		log_debug("FileContextMenu: add_kvm_actions()");

		if (!App.kvm_enable) { return; }
		
		var menu_item = gtk_menu_add_item(
			menu,
			_("KVM"),
			"",
			IconManager.lookup_image("kvm",16),
			sg_icon,
			sg_label);
			
		var sub_menu = new Gtk.Menu();
		//sub_menu.reserve_toggle_size = false;
		menu_item.submenu = sub_menu;

		var sg_icon_sub = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);
		var sg_label_sub = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);

		add_boot_disk(sub_menu, sg_icon_sub, sg_label_sub);

		gtk_menu_add_separator(sub_menu); //--------------------------------
		
		add_create_disk(sub_menu, sg_icon_sub, sg_label_sub);

		add_create_disk_derived(sub_menu, sg_icon_sub, sg_label_sub);

		add_create_disk_merged(sub_menu, sg_icon_sub, sg_label_sub);

		add_install_disk(sub_menu, sg_icon_sub, sg_label_sub);

		add_kvm_convert(sub_menu, sg_icon_sub, sg_label_sub);

		//add_write_iso(sub_menu, sg_icon_sub, sg_label_sub);
	}
	
	private void add_create_disk(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){
		
		log_debug("FileContextMenu: add_create_disk()");

		var menu_item = gtk_menu_add_item(
			menu,
			_("Create Disk..."),
			_("Create a virtual hard disk file"),
			null,//get_shared_icon("media-cdrom","",16),
			sg_icon,
			sg_label);

		menu_item.activate.connect (() => {
			view.kvm_create_disk();
		});
	}

	private void add_create_disk_derived(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){
		
		log_debug("FileContextMenu: add_create_disk_derived()");

		var menu_item = gtk_menu_add_item(
			menu,
			_("Create Derived Disk..."),
			_("Create a virtual hard disk file that uses selected disk as the base"),
			null,//get_shared_icon("media-cdrom","",16),
			sg_icon,
			sg_label);

		menu_item.activate.connect (() => {
			if (selected_item == null){ return; }
			view.kvm_create_derived_disk();
		});

		menu_item.sensitive = (selected_item != null) && (selected_item.file_extension == ".qcow2");
	}

	private void add_create_disk_merged(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){
		
		log_debug("FileContextMenu: add_create_disk_derived()");

		var menu_item = gtk_menu_add_item(
			menu,
			_("Create Merged Disk..."),
			_("Create a virtual hard disk file by merging selected derived disk with it's base"),
			null,//get_shared_icon("media-cdrom","",16),
			sg_icon,
			sg_label);

		menu_item.activate.connect (() => {
			if (selected_item == null){ return; }
			view.kvm_create_merged_disk();
		});

		menu_item.sensitive = (selected_item != null) && (selected_item.file_extension == ".qcow2");
	}

	private void add_boot_disk(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){
		
		log_debug("FileContextMenu: add_boot_disk()");

		var menu_item = gtk_menu_add_item(
			menu,
			_("Boot Disk"),
			_("Boot the selected disk in a virtual machine"),
			null,//get_shared_icon("media-cdrom","",16),
			sg_icon,
			sg_label);

		menu_item.activate.connect (() => {
			if (selected_item == null){ return; }
			view.kvm_boot_disk();
		});

		menu_item.sensitive = (selected_item != null) && KvmTask.is_supported_disk_format(selected_item.file_path);
	}

	private void add_install_disk(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){
		
		log_debug("FileContextMenu: add_install_disk()");

		var menu_item = gtk_menu_add_item(
			menu,
			_("Install from ISO..."),
			_("Boot from an ISO file with the selected disk attached"),
			null,//get_shared_icon("media-cdrom","",16),
			sg_icon,
			sg_label);

		menu_item.activate.connect (() => {
			if (selected_item == null){ return; }
			view.kvm_install_iso();
		});

		menu_item.sensitive = (selected_item != null) && KvmTask.is_supported_disk_format(selected_item.file_path);
	}

	private void add_kvm_convert(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){

		log_debug("FileContextMenu: add_kvm_convert()");

		if (!App.kvm_enable) { return; }
		
		var menu_item = gtk_menu_add_item(
			menu,
			_("Convert to..."),
			"",
			null,//IconManager.lookup_image("kvm",16),
			sg_icon,
			sg_label);


		menu_item.sensitive = (selected_item != null);

		if (selected_item == null){ return; }
			
		var sub_menu = new Gtk.Menu();
		//sub_menu.reserve_toggle_size = false;
		menu_item.submenu = sub_menu;

		var sg_icon_sub = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);
		var sg_label_sub = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);

		var formats = new Gee.ArrayList<string>();
		
		switch(selected_item.file_extension.down()){
		case ".vmdk":
		case ".vhd":
		case ".vhdx":
		case ".vdi":
		case ".bochs":
		case ".cloop":
		case ".dmg":
		case ".nbd":
		case ".qed":
		case ".vfat":
		case ".vvfat":
			formats.add("RAW - Raw disk format");
			formats.add("QCOW2 - QEMU disk format");
			break;
		case ".raw":
		case ".qcow2":
			formats.add("RAW - Raw disk format");
			formats.add("QCOW2 - QEMU disk format");
			formats.add("VDI - Oracle VirtualBox disk format");
			formats.add("VHDX - Microsoft Hyper-V disk format");
			formats.add("VMDK - VMware disk format");
			break;
		default:
			menu_item.sensitive = false;
			return;
		}
		
		foreach(string format in formats){
			
			var sub_menu_item = gtk_menu_add_item(
				sub_menu,
				format,
				"",
				null,//get_shared_icon("media-cdrom","",16),
				sg_icon_sub,
				sg_label_sub);

			sub_menu_item.activate.connect (() => {
				view.kvm_convert_disk(format.split("-")[0].strip());
			});
		}
	}


	private void add_pdf_actions(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){

		if (selected_item == null){ return; }

		if (!selected_item.file_extension.down().has_suffix(".pdf")){ return; }
		
		log_debug("FileContextMenu: add_pdf_actions()");

		var menu_item = gtk_menu_add_item(
			menu,
			_("PDF"),
			"",
			IconManager.lookup_image("application-pdf",16),
			sg_icon,
			sg_label);
			
		var sub_menu = new Gtk.Menu();
		//sub_menu.reserve_toggle_size = false;
		menu_item.submenu = sub_menu;

		var sg_icon_sub = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);
		var sg_label_sub = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);

		add_pdf_split(sub_menu, sg_icon_sub, sg_label_sub);

		add_pdf_merge(sub_menu, sg_icon_sub, sg_label_sub);

		gtk_menu_add_separator(sub_menu); //--------------------------------
		
		add_pdf_protect(sub_menu, sg_icon_sub, sg_label_sub);

		add_pdf_unprotect(sub_menu, sg_icon_sub, sg_label_sub);
		
		gtk_menu_add_separator(sub_menu); //--------------------------------
		
		add_pdf_grayscale(sub_menu, sg_icon_sub, sg_label_sub);

		add_pdf_uncompress(sub_menu, sg_icon_sub, sg_label_sub);

		add_pdf_rotate(sub_menu, sg_icon_sub, sg_label_sub);

		add_pdf_optimize(sub_menu, sg_icon_sub, sg_label_sub);
	}
	
	private void add_pdf_split(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){
		
		log_debug("FileContextMenu: add_pdf_split()");

		var menu_item = gtk_menu_add_item(
			menu,
			_("Split"),
			_("Split PDF document by page"),
			null,//get_shared_icon("media-cdrom","",16),
			sg_icon,
			sg_label);

		menu_item.activate.connect (() => {
			view.pdf_split();
		});
	}

	private void add_pdf_merge(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){
		
		log_debug("FileContextMenu: add_pdf_merge()");

		var menu_item = gtk_menu_add_item(
			menu,
			_("Merge"),
			_("Merge selected PDF files into one document"),
			null,//get_shared_icon("media-cdrom","",16),
			sg_icon,
			sg_label);

		menu_item.activate.connect (() => {
			view.pdf_merge();
		});
	}

	private void add_pdf_protect(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){
		
		log_debug("FileContextMenu: add_pdf_protect()");

		var menu_item = gtk_menu_add_item(
			menu,
			_("Add Password"),
			_("Protect the PDF document by adding password"),
			null,//get_shared_icon("media-cdrom","",16),
			sg_icon,
			sg_label);

		menu_item.activate.connect (() => {
			view.pdf_protect();
		});
	}

	private void add_pdf_unprotect(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){
		
		log_debug("FileContextMenu: add_pdf_unprotect()");

		var menu_item = gtk_menu_add_item(
			menu,
			_("Remove Password"),
			_("Unprotect the PDF document by removing password"),
			null,//get_shared_icon("media-cdrom","",16),
			sg_icon,
			sg_label);

		menu_item.activate.connect (() => {
			view.pdf_unprotect();
		});
	}

	private void add_pdf_grayscale(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){
		
		log_debug("FileContextMenu: add_pdf_grayscale()");

		var menu_item = gtk_menu_add_item(
			menu,
			_("Remove colors"),
			_("Remove colors from PDF document"),
			null,//get_shared_icon("media-cdrom","",16),
			sg_icon,
			sg_label);

		menu_item.activate.connect (() => {
			view.pdf_grayscale();
		});
	}

	private void add_pdf_uncompress(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){
		
		log_debug("FileContextMenu: add_pdf_uncompress()");

		var menu_item = gtk_menu_add_item(
			menu,
			_("Uncompress"),
			_("Uncompress PDF document"),
			null,//get_shared_icon("media-cdrom","",16),
			sg_icon,
			sg_label);

		menu_item.activate.connect (() => {
			view.pdf_uncompress();
		});
	}

	private void add_pdf_optimize(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){

		log_debug("FileContextMenu: add_pdf_optimize()");

		var menu_item = gtk_menu_add_item(
			menu,
			_("Optimize For"),
			"",
			null,//IconManager.lookup_image("kvm",16),
			sg_icon,
			sg_label);

		menu_item.sensitive = (selected_item != null);

		if (selected_item == null){ return; }
			
		var sub_menu = new Gtk.Menu();
		//sub_menu.reserve_toggle_size = false;
		menu_item.submenu = sub_menu;

		var sg_icon_sub = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);
		var sg_label_sub = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);

		foreach(string format in new string[] { "Default", "Screen (72 dpi images)", "EBook (150 dpi images)", "Printer (300 dpi images)", "PrePress" }){
			
			var sub_menu_item = gtk_menu_add_item(
				sub_menu,
				format,
				"",
				null,//get_shared_icon("media-cdrom","",16),
				sg_icon_sub,
				sg_label_sub);

			sub_menu_item.activate.connect (() => {
				view.pdf_optimize(format.split("(")[0].strip().down());
			});
		}
	}

	private void add_pdf_rotate(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){

		log_debug("FileContextMenu: add_pdf_rotate()");

		var menu_item = gtk_menu_add_item(
			menu,
			_("Rotate Pages"),
			"",
			null,//IconManager.lookup_image("kvm",16),
			sg_icon,
			sg_label);

		menu_item.sensitive = (selected_item != null);

		if (selected_item == null){ return; }
			
		var sub_menu = new Gtk.Menu();
		//sub_menu.reserve_toggle_size = false;
		menu_item.submenu = sub_menu;

		var sg_icon_sub = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);
		var sg_label_sub = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);

		foreach(string direction in new string[] { "Left", "Right", "Flip Upside Down" }){
			
			var sub_menu_item = gtk_menu_add_item(
				sub_menu,
				direction,
				"",
				null,//get_shared_icon("media-cdrom","",16),
				sg_icon_sub,
				sg_label_sub);

			sub_menu_item.activate.connect (() => {
				view.pdf_rotate(direction.split(" ")[0].strip().down());
			});
		}
	}


	private void add_sort_column(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){

		var menu_item = gtk_menu_add_item(
			menu,
			_("Sort By"),
			"",
			null,
			sg_icon,
			sg_label);

		var sort_menu = new SortMenu(pane);
		menu_item.set_submenu(sort_menu);
	}

	private void add_properties(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){

		log_debug("FileContextMenu: add_properties()");

		var menu_item = gtk_menu_add_item(
			menu,
			_("Properties"),
			_("View file properties"),
			IconManager.lookup_image("document-properties",16),
			sg_icon,
			sg_label);

		menu_item.activate.connect (() => {
			view.show_properties();
		});

		menu_item.sensitive = (selected_items.size > 0) || ((view.current_item != null) && !view.current_item.is_trash);
	}

	// properties

	private bool selected_items_contain_archives {
		get {
			if (selected_items.size == 0){ return false; }
			foreach(var item in selected_items){
				if (item.is_archive){
					return true;
				}
			}
			return false;
		}
	}
	
	public bool show_menu(Gdk.EventButton? event) {

		if (event != null) {
			this.popup (null, null, null, event.button, event.time);
		}
		else {
			this.popup (null, null, null, 0, Gtk.get_current_event_time());
		}

		return true;
	}
}

public class SortMenu : Gtk.Menu {

	private Gtk.SizeGroup sg_icon;
	private Gtk.SizeGroup sg_label;
	private bool is_trash = false;
	private bool is_archive = false;

	// parents
	public FileViewList view;
	public FileViewPane pane;
	public MainWindow window;

	public SortMenu(FileViewPane parent_pane){

		log_debug("SortMenu()");

		pane = parent_pane;
		view = pane.view;
		window = App.main_window;

		build_menu();
	}

	public void build_menu(){
		
		Gtk.RadioMenuItem item_prev = null;
		
		foreach(var col in view.get_all_columns()){
			
			var col_index = col.get_data<FileViewColumn>("index");
			if (col_index == FileViewColumn.UNSORTABLE) { continue; }

			bool _active = (view.get_sort_column_index() == col_index);
			var submenu_item = add_sort_column_item(this, item_prev, col, _active);
			item_prev = submenu_item;
		}

		gtk_menu_add_separator(this);

		add_sort_desc_item(this);

		this.show_all();
	}
	
	private Gtk.RadioMenuItem add_sort_column_item(Gtk.Menu sub_menu, Gtk.RadioMenuItem? item_prev, Gtk.TreeViewColumn col, bool _active){

		string txt = (col.title.length > 0) ? col.title.replace("↓","").replace("↑","").strip() : _("Indicator");

		//log_debug("FileContextMenu: add option: %s".printf(txt));
			
		var submenu_item = gtk_menu_add_radio_item(
				sub_menu,
				txt,
				"",
				item_prev);

		var col_index = col.get_data<FileViewColumn>("index");
		submenu_item.set_data<FileViewColumn>("index", col_index);

		submenu_item.active = _active;
		
		submenu_item.toggled.connect(on_sort_column_menu_item_toggled);

		return submenu_item;
	}

	private Gtk.CheckMenuItem add_sort_desc_item(Gtk.Menu sub_menu){

		var menu_item = gtk_menu_add_check_item(
					sub_menu,
					_("Sort Descending"),
					"");

		menu_item.active = view.get_sort_column_desc();

		menu_item.toggled.connect(on_sort_desc_menu_item_toggled);

		return menu_item;
	}

	private void on_sort_column_menu_item_toggled(Gtk.CheckMenuItem menu_item){
		if (!menu_item.active){ return; }
		log_debug("FileContextMenu: sort column: %s".printf(menu_item.label));
		var col_index = menu_item.get_data<FileViewColumn>("index");
		view.set_sort_column_by_index(col_index);
	}

	private void on_sort_desc_menu_item_toggled(Gtk.CheckMenuItem menu_item){
		log_debug("FileContextMenu: sort desc: %s".printf(menu_item.active.to_string()));
		view.set_sort_column_desc(menu_item.active);
	}
}


