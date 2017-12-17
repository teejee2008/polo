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

public class FileContextMenu : Gtk.Menu {

	// reference properties ----------

	protected MainWindow window {
		get { return App.main_window; }
	}
	
	protected FileViewPane pane;

	protected FileViewList view {
		get{ return pane.view; }
	}

	protected LayoutPanel panel {
		get { return pane.panel; }
	}

	// -------------------------------
	
	private Gee.ArrayList<FileItem> selected_items;
	private FileItem? selected_item = null;
	private bool is_trash = false;
	private bool is_archive = false;

	public FileContextMenu(FileViewPane parent_pane){
		
		log_debug("FileContextMenu()");

		margin = 0;

		pane = parent_pane;

		if (window.refresh_apps_pending){
			window.refresh_apps_pending = false;
			DesktopApp.query_apps();
		}

		if (view.current_item.is_trash){ //|| view.current_item.is_trashed_item
			is_trash = true;
			build_file_menu_for_trash();
		}
		else if (view.current_item is FileItemArchive){
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

		log_trace("build_file_menu()");
		var timer = timer_start();
		var subtimer = timer_start();
		
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

		log_trace("context menu created: open: %s".printf(timer_elapsed_string(subtimer)));
		timer_restart(subtimer);
		
		add_new(this, sg_icon, sg_label);

		log_trace("context menu created: new: %s".printf(timer_elapsed_string(subtimer)));
		timer_restart(subtimer);

		gtk_menu_add_separator(this); //---------------------------

		add_cut(this, sg_icon, sg_label);
		
		add_copy(this, sg_icon, sg_label);

		add_paste_into_folder(this, sg_icon, sg_label);

		add_paste(this, sg_icon, sg_label);

		add_rename(this, sg_icon, sg_label);

		add_trash(this, sg_icon, sg_label);

		add_delete(this, sg_icon, sg_label);

		add_actions(this, sg_icon, sg_label);

		gtk_menu_add_separator(this); //----------------------

		add_disk_usage(this, sg_icon, sg_label);

		add_file_compare(this, sg_icon, sg_label);
		
		add_archive_actions(this, sg_icon, sg_label);
		
		add_image_actions(this, sg_icon, sg_label);

		add_iso_actions(this, sg_icon, sg_label);

		add_pdf_actions(this, sg_icon, sg_label);

		add_kvm_actions(this, sg_icon, sg_label);

		gtk_menu_add_separator(this); // -----------------------------

		add_sort_column(this, sg_icon, sg_label);

		add_properties(this, sg_icon, sg_label);

		log_trace("context menu created: %s".printf(timer_elapsed_string(timer)));
		 
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

		//if (view.current_item is FileItemCloud){
		//	menu_item.sensitive = false;
		//}

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

		if ((selected_item.file_type != FileType.DIRECTORY) && (selected_item is FileItemArchive == false)){

			var app = MimeApp.get_default_app(selected_item.content_type);

			if (app != null){

				menu_item = gtk_menu_add_item(
					menu,
					//_("Open With") + " " +
					app.name,
					_("Open with default application"),
					IconManager.lookup_image(app.icon,16),
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

		// sub menu ------------------------------------------
		
		var sub_menu = new Gtk.Menu();
		sub_menu.reserve_toggle_size = false;
		menu_item.submenu = sub_menu;

		var sg_icon_sub = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);
		var sg_label_sub = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);

		log_msg("content_type: %s".printf(selected_item.content_type));

		var supported_apps = MimeApp.get_supported_apps(selected_item.content_type);
		if (selected_item.content_type.has_prefix("text/")
			|| selected_item.content_type.contains("shellscript")
			|| selected_item.content_type.contains("application/x-desktop")){
				
			supported_apps = DesktopApp.text_editors;
		}

		foreach(var supported_app in supported_apps){

			//log_debug("supported_app: %s".printf(supported_app.name));

			var submenu_item = gtk_menu_add_item(
				sub_menu,
				supported_app.name,
				_("Open With") + " " + supported_app.name,
				IconManager.lookup_image(supported_app.icon,16),
				sg_icon_sub,
				sg_label_sub);

			submenu_item.activate.connect(() => {
				view.open(selected_item, supported_app);
			});
		}

		sub_menu.show_all();

		gtk_menu_add_separator(sub_menu);

		add_open_with_others(sub_menu, sg_icon_sub, sg_label_sub);
	}

	private void add_open_with_others(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){

		log_debug("FileContextMenu: add_open_with_others()");

		if (selected_item == null){ return; }
		
		var menu_item = gtk_menu_add_item(
			menu,
			_("Other"),
			_("Open with other applications"),
			null,
			sg_icon,
			sg_label);

		menu_item.sensitive = (selected_items.size > 0);

		menu_item.activate.connect(() => {
			var file = selected_item;
			DesktopApp? app = choose_app(file);
			if (app != null){
				view.open(file, app);
			}
		});
	}

	private DesktopApp? choose_app(FileItem file_item){

		var file = File.new_for_path(file_item.file_path);
		
		var dialog = new Gtk.AppChooserDialog(window, Gtk.DialogFlags.MODAL, file);

		string desktop_file_name = "";
		
		if (dialog.run() == Gtk.ResponseType.OK) {
			
			var info = dialog.get_app_info();
			
			if (info != null) {
				desktop_file_name = info.get_id();
			}
		}
		
		dialog.close();

		if (DesktopApp.applist.has_key(desktop_file_name)){
			return DesktopApp.applist[desktop_file_name];
		}
		
		return null;
	}


	private void add_set_default_app(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){

		log_debug("FileContextMenu: add_open_with()");

		if (selected_item == null){ return; }

		if (view.current_item is FileItemCloud){ return; }

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
				IconManager.lookup_image(supported_app.icon,16),
				sg_icon_sub,
				sg_label_sub);

			submenu_item.activate.connect(() => {
				view.set_default_app(selected_item, supported_app);
			});
		}

		sub_menu.show_all();

		gtk_menu_add_separator(sub_menu);

		add_set_default_app_others(sub_menu, sg_icon_sub, sg_label_sub);
	}

	private void add_set_default_app_others(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){

		log_debug("FileContextMenu: add_set_default_app_others()");

		if (selected_item == null){ return; }

		var menu_item = gtk_menu_add_item(
			menu,
			_("Others"),
			_("Set default application for file type"),
			null,
			sg_icon,
			sg_label);

		menu_item.sensitive = (selected_items.size > 0);

		menu_item.activate.connect(() => {
			var file = selected_item;
			DesktopApp? app = choose_app(file);
			if (app != null){
				view.set_default_app(file, app);
			}
		});
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
					IconManager.lookup_image("list-add-symbolic", 16),
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
			IconManager.lookup_image("list-add-symbolic",16),
			sg_icon,
			sg_label);

		menu_item.activate.connect (() => {
			view.open_terminal();
		});
	}

	private void add_new_tab(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){

		log_debug("FileContextMenu: add_new_tab()");

		// open in new tab ----------------------------

		var menu_item = gtk_menu_add_item(
			menu,
			_("Tab"),
			_("Open new tab"),
			IconManager.lookup_image("list-add-symbolic",16),
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
			IconManager.lookup_image("list-add-symbolic",16),
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
			IconManager.lookup_image("list-add-symbolic",16),
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
		templates.query_children(1, false);

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
			IconManager.lookup_image("edit-cut-symbolic",16),
			sg_icon,
			sg_label);

		menu_item.activate.connect (() => {
			log_debug("file_context_menu.cut()");
			view.cut();
		});

		menu_item.sensitive = (selected_items.size > 0) && (selected_item.can_delete);

		if (view.current_item is FileItemCloud){
			menu_item.sensitive = false;
		}
	}
	
	private void add_copy(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){

		log_debug("FileContextMenu: add_copy()");

		// copy --------------------------------

		var menu_item = gtk_menu_add_item(
			menu,
			_("Copy"),
			_("Copy selected items"),
			IconManager.lookup_image("edit-copy-symbolic",16),
			sg_icon,
			sg_label);

		menu_item.activate.connect (() => {
			log_debug("file_context_menu.copy()");
			view.copy();
		});

		menu_item.sensitive = (selected_items.size > 0);
	}

	private void add_paste_into_folder(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){

		log_debug("FileContextMenu: add_paste_into_folder()");

		string txt = get_clipboard_text();
		string url = txt.has_prefix("http") ? txt : "";

		if ((window.pending_action == null) || (selected_items.size != 1) || !selected_items[0].is_directory || (url.length == 0)){
			return;
		}
		
		// paste --------------------------------

		var menu_item = gtk_menu_add_item(
			menu,
			_("Paste Into Folder"),
			_("Paste items into selected directory"),
			IconManager.lookup_image("edit-paste-symbolic",16),
			sg_icon,
			sg_label);

		menu_item.activate.connect (() => {
			log_debug("file_context_menu.paste()");
			if (window.pending_action != null){
				view.paste_into_folder();
			}
			else if (url.length > 0){
				view.paste_url_into_folder(url);
			}
		});

		menu_item.sensitive = ((window.pending_action != null) || (url.length > 0)) && (selected_items.size == 1) && selected_items[0].is_directory;
	}
	
	private void add_paste(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){

		log_debug("FileContextMenu: add_paste()");

		string txt = get_clipboard_text();
		string url = txt.has_prefix("http") ? txt : "";
		
		// paste --------------------------------

		var menu_item = gtk_menu_add_item(
			menu,
			_("Paste Here"),
			_("Paste items in current directory"),
			IconManager.lookup_image("edit-paste-symbolic",16),
			sg_icon,
			sg_label);

		menu_item.activate.connect (() => {
			log_debug("file_context_menu.paste()");
			if (window.pending_action != null){
				view.paste();
			}
			else if (url.length > 0){
				view.paste_url(url);
			}
		});

		menu_item.sensitive = (window.pending_action != null) || (url.length > 0);
	}

	private string get_clipboard_text(){
		Gdk.Display display = this.get_display();
		Gtk.Clipboard clipboard = Gtk.Clipboard.get_for_display(display, Gdk.SELECTION_CLIPBOARD);
		string txt = clipboard.wait_for_text();
		if ((txt != null) && (txt.has_prefix("http"))){
			return txt;
		}
		return "";
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
			IconManager.lookup_image("user-trash-symbolic",16),
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
			IconManager.lookup_image("edit-delete-symbolic",16),
			sg_icon,
			sg_label);

		menu_item.activate.connect (() => {
			log_debug("file_context_menu.delete_items()");
			view.delete_items();
		});

		menu_item.sensitive = (selected_items.size > 0)
			&& (selected_item.can_delete || selected_item.is_remote)
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
			IconManager.lookup_image("terminal-symbolic",16),
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

		log_debug("FileContextMenu: add_compare()");

		if (selected_item == null){ return; }

		if (selected_items.size > 1){ return; }

		if (!file_is_regular(selected_item.file_path)){ return; }

		// ... -------------------------

		var menu_item = gtk_menu_add_item(
			menu,
			_("Compare"),
			_("Compare text files side-by-side"),
			IconManager.lookup_image("compare",16),
			sg_icon,
			sg_label);

		menu_item.sensitive = (selected_items.size > 0) || (window.pending_action != null);

		var sub_menu = new Gtk.Menu();
		sub_menu.reserve_toggle_size = false;
		menu_item.submenu = sub_menu;

		var sg_icon_sub = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);
		var sg_label_sub = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);

		// items ------------------------------

		add_file_compare_opposite(sub_menu, sg_icon_sub, sg_label_sub);

		add_file_compare_select_second(sub_menu, sg_icon_sub, sg_label_sub);
	}
	
	private void add_file_compare_opposite(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){

		log_debug("FileContextMenu: add_file_compare_opposite()");

		// compare with Diffuse --------------------------

		var menu_item = gtk_menu_add_item(
			menu,
			_("To '%s' in Opposite Pane").printf(selected_item.file_name_ellipsized),//TODO: show dialog for selecting second file
			_("Compare text file with file in opposite pane"),
			null,
			sg_icon,
			sg_label);

		menu_item.activate.connect (() => {
			view.compare_files_opposite();
		});
	}

	private void add_file_compare_select_second(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){

		log_debug("FileContextMenu: add_file_compare_select_second()");

		// compare with Diffuse --------------------------

		var menu_item = gtk_menu_add_item(
			menu,
			_("Select Second File..."),
			_("Select second file for compare"),
			null,
			sg_icon,
			sg_label);

		menu_item.activate.connect (() => {
			view.compare_files_select_second();
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
			IconManager.lookup_image("edit-copy-symbolic",16),
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
			IconManager.lookup_image("edit-cut-symbolic",16),
			sg_icon,
			sg_label);

		menu_item.activate.connect (() => {
			log_debug("file_context_menu.move_to()");
			view.move_to();
		});

		menu_item.sensitive = (selected_items.size > 0) && (selected_item.can_delete);

		if (view.current_item is FileItemCloud){
			menu_item.sensitive = false;
		}
	}

	private void add_copy_across(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){
		
		var menu_item = gtk_menu_add_item(
			menu,
			_("Copy Across"),
			_("Copy to other pane"),
			IconManager.lookup_image("edit-copy-symbolic",16),
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
			IconManager.lookup_image("edit-cut-symbolic",16),
			sg_icon,
			sg_label);

		menu_item.activate.connect (() => {
			log_debug("file_context_menu.move_across()");
			view.move_across();
		});

		menu_item.sensitive = (selected_items.size > 0) && (selected_item.can_delete);

		if (view.current_item is FileItemCloud){
			menu_item.sensitive = false;
		}
	}

	private void add_paste_symlinks_auto(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){

		var menu_item = gtk_menu_add_item(
			menu,
			_("Paste Symlinks"),
			_("Paste symbolic links to selected items in this directory. Absolute path will be used for symlink target."),
			IconManager.lookup_image("edit-paste-symbolic",16),
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
			IconManager.lookup_image("edit-paste-symbolic",16),
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
			IconManager.lookup_image("edit-paste-symbolic",16),
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
			IconManager.lookup_image("edit-copy-symbolic",16),
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
			IconManager.lookup_image("list-add-symbolic",16),
			sg_icon,
			sg_label);

		menu_item.activate.connect (() => {
			log_debug("file_context_menu.restore_items()");
			view.restore_items();
		});

		menu_item.sensitive = (selected_items.size > 0) && (selected_item.can_rename) && (view.current_item.is_trash);
	}


	private void add_archive_actions(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){

		if (view.current_item is FileItemCloud){ return; }

		if (selected_items.size == 0){ return; }
		
		log_debug("FileContextMenu: add_archive_actions()");

		var menu_item = gtk_menu_add_item(
			menu,
			_("Archive"),
			"",
			IconManager.lookup_image("package-x-generic",16),
			sg_icon,
			sg_label);
			
		var sub_menu = new Gtk.Menu();
		sub_menu.reserve_toggle_size = false;
		menu_item.submenu = sub_menu;

		var sg_icon_sub = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);
		var sg_label_sub = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);
		
		add_compress(sub_menu, sg_icon_sub, sg_label_sub);

		add_browse_archive(sub_menu, sg_icon_sub, sg_label_sub);
		
		add_extract_to(sub_menu, sg_icon_sub, sg_label_sub);
		
		add_extract_across(sub_menu, sg_icon_sub, sg_label_sub);
		
		add_extract_here(sub_menu, sg_icon_sub, sg_label_sub);
	}
	
	private void add_compress(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){

		if (view.current_item is FileItemCloud){ return; }
		
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

	private void add_browse_archive(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){

		//if (!can_extract){ return; }
		
		log_debug("FileContextMenu: add_browse_archive()");

		var menu_item = gtk_menu_add_item(
			menu,
			_("Open"),
			_("Open archive"),
			null,//IconManager.lookup_image("package-x-generic",16),
			sg_icon,
			sg_label);

		menu_item.activate.connect (() => {
			view.browse_archive();
		});

		menu_item.sensitive = (selected_items.size > 0)
			&& FileItem.is_archive_by_extension(selected_item.file_path) // check file
			; // check destination
	}
	
	private void add_extract_to(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){

		//if (!can_extract){ return; }
		
		log_debug("FileContextMenu: add_extract_to()");

		var menu_item = gtk_menu_add_item(
			menu,
			_("Extract To.."),
			_("Extract archives to another location. Existing files will be overwritten."),
			null,//IconManager.lookup_image("package-x-generic",16),
			sg_icon,
			sg_label);

		menu_item.activate.connect (() => {
			view.extract_selected_items_to_another_location();
		});

		menu_item.sensitive = (selected_items.size > 0)
			&& ((view.current_item is FileItemArchive) || FileItem.is_archive_by_extension(selected_item.file_path)) // check file
			; // check destination
	}

	private void add_extract_across(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){

		//if (!can_extract){ return; }
		
		log_debug("FileContextMenu: add_extract_across()");

		var menu_item = gtk_menu_add_item(
			menu,
			_("Extract Across"),
			_("Extract archives to the opposite pane. Existing files will be overwritten."),
			null,//IconManager.lookup_image("package-x-generic",16),
			sg_icon,
			sg_label);

		menu_item.activate.connect (() => {
			view.extract_selected_items_to_opposite_location();
		});

		FileItem? opp_item = view.panel.opposite_pane.view.current_item;

		menu_item.sensitive = (selected_items.size > 0)
			&& ((view.current_item is FileItemArchive) || FileItem.is_archive_by_extension(selected_item.file_path)) // check file
			&& (opp_item != null) && !(opp_item is FileItemArchive) && !(opp_item is FileItemCloud); // check destination
	}

	private void add_extract_here(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){

		//if (!can_extract){ return; }

		log_debug("FileContextMenu: add_extract_here()");

		var menu_item = gtk_menu_add_item(
			menu,
			_("Extract Here"),
			_("Extract archives in same location. New folder will be created with archive name."),
			null,//IconManager.lookup_image("package-x-generic",16),
			sg_icon,
			sg_label);

		menu_item.activate.connect (() => {
			view.extract_selected_items_to_same_location();
		});

		menu_item.sensitive = (selected_items.size > 0)
			&& FileItem.is_archive_by_extension(selected_item.file_path) // check file
			&& !(view.current_item is FileItemArchive) && !(view.current_item is FileItemCloud); // check destination
	}

	private void add_disk_usage(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){

		if (!view.is_normal_directory){ return; }

		if (view.current_item is FileItemCloud){ return; }

		log_debug("FileContextMenu: add_disk_usage()");

		var baobab = DesktopApp.get_app_by_filename("org.gnome.baobab.desktop");
		if (baobab == null){ return; }

		var menu_item = gtk_menu_add_item(
			menu,
			_("Disk Usage"),
			_("Analyze disk usage"),
			null,
			sg_icon,
			sg_label);

		menu_item.activate.connect(() => {
			view.analyze_disk_usage();
		});
	}


	private void add_iso_actions(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){

		if (selected_item == null){ return; }

		if (!selected_item.is_disk_image){ return; }
		
		log_debug("FileContextMenu: add_iso_actions()");
	
		var menu_item = gtk_menu_add_item(
			menu,
			_("Disk Image"),
			"",
			gtk_image_from_pixbuf(IconManager.generic_icon_iso(16)),
			sg_icon,
			sg_label);
			
		var sub_menu = new Gtk.Menu();
		//sub_menu.reserve_toggle_size = false;
		menu_item.submenu = sub_menu;

		var sg_icon_sub = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);
		var sg_label_sub = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);
		
		add_mount_iso(sub_menu, sg_icon_sub, sg_label_sub);
		
		add_boot_iso(sub_menu, sg_icon_sub, sg_label_sub);

		add_write_iso(sub_menu, sg_icon_sub, sg_label_sub);
	}
	
	private void add_mount_iso(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){
		
		if (selected_item == null){ return; }

		if (!selected_item.is_disk_image){ return; }

		log_debug("FileContextMenu: add_mount_iso()");

		var menu_item = gtk_menu_add_item(
			menu,
			_("Mount"),
			_("Mount the disk image as read-only device"),
			null,
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
			_("Boot in VM"),
			_("Boot ISO file in QEMU-KVM virtual machine"),
			null,
			sg_icon,
			sg_label);

		menu_item.activate.connect (() => {
			view.boot_iso();
		});
	}

	private void add_write_iso(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){
		
		if (selected_item == null){ return; }

		if (!selected_item.is_iso){ return; }

		if (!App.tool_exists("polo-iso")) { return; }

		log_debug("FileContextMenu: add_write_iso()");

		var menu_item = gtk_menu_add_item(
			menu,
			_("Write to USB"),
			_("Write ISO file to USB drive"),
			null,
			sg_icon,
			sg_label);

		menu_item.sensitive = true;

		var sub_menu = new Gtk.Menu();
		//sub_menu.reserve_toggle_size = false;
		menu_item.submenu = sub_menu;

		var sg_icon_sub = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);
		var sg_label_sub = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);

		var list = Main.get_devices();
		
		bool devices_available = false;
		
		foreach(var dev in list){
		
			if (dev.pkname.length > 0){ continue; }
			if (!dev.removable){ continue; }
			if (dev.size_bytes > 100 * GB){ continue; }
			
			var sub_menu_item = gtk_menu_add_item(
				sub_menu,
				dev.description_simple(),
				"",
				null,
				sg_icon_sub,
				sg_label_sub);

			sub_menu_item.activate.connect (() => {
				view.write_iso(dev);
			});

			devices_available = true;
		}

		if (!devices_available){
			
			var sub_menu_item2 = gtk_menu_add_item(
				sub_menu,
				_("No USB devices found"),
				_("Connect a USB device and come back to this menu"),
				null,
				sg_icon_sub,
				sg_label_sub);
				
			sub_menu_item2.sensitive = false;
		}
	}


	private void add_kvm_actions(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){

		if (!App.kvm_enable) { return; }

		if (view.current_item is FileItemCloud){ return; }

		log_debug("FileContextMenu: add_kvm_actions()");
		
		var menu_item = gtk_menu_add_item(
			menu,
			_("KVM"),
			"",
			IconManager.lookup_image("kvm",16),
			sg_icon,
			sg_label);
			
		var sub_menu = new Gtk.Menu();
		sub_menu.reserve_toggle_size = false;
		menu_item.submenu = sub_menu;

		var sg_icon_sub = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);
		var sg_label_sub = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);

		add_boot_disk(sub_menu, sg_icon_sub, sg_label_sub);

		gtk_menu_add_separator(sub_menu); //--------------------------------
		
		add_create_disk(sub_menu, sg_icon_sub, sg_label_sub);

		add_create_disk_derived(sub_menu, sg_icon_sub, sg_label_sub);

		add_create_disk_merged(sub_menu, sg_icon_sub, sg_label_sub);
		
		add_mount_disk(sub_menu, sg_icon_sub, sg_label_sub);

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
			null,
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
			null,
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
			null,
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
			null,
			sg_icon,
			sg_label);

		menu_item.activate.connect (() => {
			if (selected_item == null){ return; }
			view.kvm_boot_disk();
		});

		menu_item.sensitive = (selected_item != null) && KvmTask.is_supported_disk_format(selected_item.file_path);
	}

	private void add_mount_disk(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){
		
		log_debug("FileContextMenu: add_mount_disk()");

		var menu_item = gtk_menu_add_item(
			menu,
			_("Mount Disk"),
			_("Mount the selected disk"),
			null,
			sg_icon,
			sg_label);

		menu_item.activate.connect (() => {
			if (selected_item == null){ return; }
			view.kvm_mount_disk();
		});

		menu_item.sensitive = (selected_item != null) && (selected_item.file_extension == ".qcow2");
	}

	private void add_install_disk(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){
		
		log_debug("FileContextMenu: add_install_disk()");

		var menu_item = gtk_menu_add_item(
			menu,
			_("Install from ISO..."),
			_("Boot from an ISO file with the selected disk attached"),
			null,
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
			null,
			sg_icon,
			sg_label);


		menu_item.sensitive = (selected_item != null);

		if (selected_item == null){ return; }
			
		var sub_menu = new Gtk.Menu();
		sub_menu.reserve_toggle_size = false;
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
				null,
				sg_icon_sub,
				sg_label_sub);

			sub_menu_item.activate.connect (() => {
				view.kvm_convert_disk(format.split("-")[0].strip());
			});
		}
	}


	private void add_pdf_actions(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){

		if (view.current_item is FileItemCloud){ return; }
		
		if (selected_item == null){ return; }

		if (!selected_item.is_pdf){ return; }

		if (!App.tool_exists("polo-pdf")) { return; }
		
		log_debug("FileContextMenu: add_pdf_actions()");

		var menu_item = gtk_menu_add_item(
			menu,
			_("PDF"),
			"",
			gtk_image_from_pixbuf(IconManager.generic_icon_pdf(16)),
			sg_icon,
			sg_label);
			
		var sub_menu = new Gtk.Menu();
		sub_menu.reserve_toggle_size = false;
		menu_item.submenu = sub_menu;

		var sg_icon_sub = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);
		var sg_label_sub = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);

		add_pdf_split(sub_menu, sg_icon_sub, sg_label_sub);

		add_pdf_merge(sub_menu, sg_icon_sub, sg_label_sub);

		gtk_menu_add_separator(sub_menu); //--------------------------------
		
		add_pdf_protect(sub_menu, sg_icon_sub, sg_label_sub);

		add_pdf_unprotect(sub_menu, sg_icon_sub, sg_label_sub);
		
		gtk_menu_add_separator(sub_menu); //--------------------------------

		add_pdf_compress(sub_menu, sg_icon_sub, sg_label_sub);

		add_pdf_uncompress(sub_menu, sg_icon_sub, sg_label_sub);

		gtk_menu_add_separator(sub_menu); //--------------------------------
		
		add_pdf_grayscale(sub_menu, sg_icon_sub, sg_label_sub);

		add_pdf_rotate(sub_menu, sg_icon_sub, sg_label_sub);

		add_pdf_optimize(sub_menu, sg_icon_sub, sg_label_sub);
	}
	
	private void add_pdf_split(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){
		
		log_debug("FileContextMenu: add_pdf_split()");

		var menu_item = gtk_menu_add_item(
			menu,
			_("Split"),
			_("Split PDF document by page"),
			null,
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
			null,
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
			null,
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
			null,
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
			_("Remove Color"),
			_("Remove colors from PDF document"),
			null,
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
			null,
			sg_icon,
			sg_label);

		menu_item.activate.connect (() => {
			view.pdf_uncompress();
		});
	}

	private void add_pdf_compress(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){
		
		log_debug("FileContextMenu: add_pdf_compress()");

		var menu_item = gtk_menu_add_item(
			menu,
			_("Reduce File Size"),
			_("Reduce the file size of PDF document by downscaling images. Use the 'Optimize For' submenu for more options."),
			null,
			sg_icon,
			sg_label);

		menu_item.activate.connect (() => {
			view.pdf_compress();
		});
	}

	private void add_pdf_optimize(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){

		log_debug("FileContextMenu: add_pdf_optimize()");

		var menu_item = gtk_menu_add_item(
			menu,
			_("Optimize For"),
			"",
			null,
			sg_icon,
			sg_label);

		menu_item.sensitive = (selected_item != null);

		if (selected_item == null){ return; }
			
		var sub_menu = new Gtk.Menu();
		sub_menu.reserve_toggle_size = false;
		menu_item.submenu = sub_menu;

		var sg_icon_sub = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);
		var sg_label_sub = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);

		foreach(string format in new string[] { "Default", "Screen (72 dpi)", "EBook (150 dpi)", "Printer (300 dpi)", "PrePress" }){
			
			var sub_menu_item = gtk_menu_add_item(
				sub_menu,
				format,
				"",
				null,
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
			_("Rotate"),
			"",
			null,
			sg_icon,
			sg_label);

		menu_item.sensitive = (selected_item != null);

		if (selected_item == null){ return; }
			
		var sub_menu = new Gtk.Menu();
		sub_menu.reserve_toggle_size = false;
		menu_item.submenu = sub_menu;

		var sg_icon_sub = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);
		var sg_label_sub = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);

		foreach(string direction in new string[] { "Left", "Right", "Flip Upside Down" }){
			
			var sub_menu_item = gtk_menu_add_item(
				sub_menu,
				direction,
				"",
				null,
				sg_icon_sub,
				sg_label_sub);

			sub_menu_item.activate.connect (() => {
				view.pdf_rotate(direction.split(" ")[0].strip().down());
			});
		}
	}


	private void add_image_actions(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){

		if (view.current_item is FileItemCloud){ return; }
		
		if (selected_item == null){ return; }

		if (!selected_item.is_image){ return; }

		if (!App.tool_exists("polo-image")) { return; }
		
		log_debug("FileContextMenu: add_image_actions()");

		var menu_item = gtk_menu_add_item(
			menu,
			_("Image"),
			"",
			gtk_image_from_pixbuf(IconManager.generic_icon_image(16)),
			sg_icon,
			sg_label);
			
		var sub_menu = new Gtk.Menu();
		sub_menu.reserve_toggle_size = false;
		menu_item.submenu = sub_menu;

		var sg_icon_sub = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);
		var sg_label_sub = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);

		add_image_optimize_png(sub_menu, sg_icon_sub, sg_label_sub);

		add_image_reduce_jpeg(sub_menu, sg_icon_sub, sg_label_sub);

		gtk_menu_add_separator(sub_menu); //--------------------------------
		
		add_image_decolor(sub_menu, sg_icon_sub, sg_label_sub);

		add_image_reduce_color(sub_menu, sg_icon_sub, sg_label_sub);

		add_image_boost_color(sub_menu, sg_icon_sub, sg_label_sub);

		gtk_menu_add_separator(sub_menu); //--------------------------------

		add_image_set_wallpaper(sub_menu, sg_icon_sub, sg_label_sub);
		
		add_image_rotate(sub_menu, sg_icon_sub, sg_label_sub);

		gtk_menu_add_separator(sub_menu); //--------------------------------
		
		add_image_resize(sub_menu, sg_icon_sub, sg_label_sub);

		add_image_convert(sub_menu, sg_icon_sub, sg_label_sub);
	}

	private void add_image_set_wallpaper(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){
		
		log_debug("FileContextMenu: add_image_set_wallpaper()");

		var menu_item = gtk_menu_add_item(
			menu,
			_("Set as Wallpaper"),
			_("Set the image as wallpaper"),
			null,
			sg_icon,
			sg_label);

		menu_item.activate.connect (() => {
			//view.set_wallpaper(); // check size
		});

		menu_item.sensitive = false;
	}
	
	private void add_image_optimize_png(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){
		
		log_debug("FileContextMenu: add_image_optimize_png()");

		var menu_item = gtk_menu_add_item(
			menu,
			_("Optimize PNG (lossless)"),
			_("Reduce file size of PNG images without losing quality. PNG files will be re-packed using better compression algorithms."),
			null,
			sg_icon,
			sg_label);

		menu_item.activate.connect (() => {
			view.image_optimize_png();
		});
	}

	private void add_image_reduce_jpeg(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){
		
		log_debug("FileContextMenu: add_image_reduce_jpeg()");

		var menu_item = gtk_menu_add_item(
			menu,
			_("Reduce JPEG Quality"),
			_("Reduce file size of JPEG images by reducing quality"),
			null,
			sg_icon,
			sg_label);

		menu_item.activate.connect (() => {
			view.image_reduce_jpeg();
		});
	}

	private void add_image_decolor(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){
		
		log_debug("FileContextMenu: add_image_decolor()");

		var menu_item = gtk_menu_add_item(
			menu,
			_("Remove Color"),
			_("Convert to black and white"),
			null,
			sg_icon,
			sg_label);

		menu_item.activate.connect (() => {
			view.image_decolor();
		});
	}

	private void add_image_reduce_color(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){
		
		log_debug("FileContextMenu: add_image_reduce_color()");

		var menu_item = gtk_menu_add_item(
			menu,
			_("Reduce Color"),
			_("Reduce color (less saturation). This can be used for correcting photos that are over-saturated (too much color)."),
			null,
			sg_icon,
			sg_label);

		menu_item.sensitive = (selected_item != null);

		if (selected_item == null){ return; }
			
		var sub_menu = new Gtk.Menu();
		sub_menu.reserve_toggle_size = false;
		menu_item.submenu = sub_menu;

		var sg_icon_sub = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);
		var sg_label_sub = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);

		foreach(string level in new string[] { "Light", "Medium", "Strong" }){
			
			var sub_menu_item = gtk_menu_add_item(
				sub_menu,
				level,
				"",
				null,
				sg_icon_sub,
				sg_label_sub);

			sub_menu_item.activate.connect (() => {
				view.image_reduce_color(level.split(" ")[0].strip().down());
			});
		}
	}
	
	private void add_image_boost_color(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){
		
		log_debug("FileContextMenu: add_image_boost_color()");

		var menu_item = gtk_menu_add_item(
			menu,
			_("Boost Color"),
			_("Boost color (more saturation). This can be used for correcting photos that are too dull (less color)."),
			null,
			sg_icon,
			sg_label);

		menu_item.sensitive = (selected_item != null);

		if (selected_item == null){ return; }
			
		var sub_menu = new Gtk.Menu();
		sub_menu.reserve_toggle_size = false;
		menu_item.submenu = sub_menu;

		var sg_icon_sub = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);
		var sg_label_sub = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);

		foreach(string level in new string[] { "Light", "Medium", "Strong" }){
			
			var sub_menu_item = gtk_menu_add_item(
				sub_menu,
				level,
				"",
				null,
				sg_icon_sub,
				sg_label_sub);

			sub_menu_item.activate.connect (() => {
				view.image_boost_color(level.split(" ")[0].strip().down());
			});
		}
	}

	private void add_image_resize(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){

		log_debug("FileContextMenu: add_image_rotate()");

		var menu_item = gtk_menu_add_item(
			menu,
			_("Resize to"),
			"",
			null,
			sg_icon,
			sg_label);

		menu_item.sensitive = (selected_item != null);

		if (selected_item == null){ return; }
			
		var sub_menu = new Gtk.Menu();
		sub_menu.reserve_toggle_size = false;
		menu_item.submenu = sub_menu;

		var sg_icon_sub = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);
		var sg_label_sub = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);

		foreach(string direction in new string[] { "240p", "320p", "480p", "640p", "720p", "960p", "1080p" }){
			
			var sub_menu_item = gtk_menu_add_item(
				sub_menu,
				direction,
				"",
				null,
				sg_icon_sub,
				sg_label_sub);

			sub_menu_item.activate.connect (() => {
				view.image_resize(0, int.parse(direction.replace("p","")));
			});
		}
	}
	
	private void add_image_rotate(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){

		log_debug("FileContextMenu: add_image_rotate()");

		var menu_item = gtk_menu_add_item(
			menu,
			_("Rotate"),
			"",
			null,
			sg_icon,
			sg_label);

		menu_item.sensitive = (selected_item != null);

		if (selected_item == null){ return; }
			
		var sub_menu = new Gtk.Menu();
		sub_menu.reserve_toggle_size = false;
		menu_item.submenu = sub_menu;

		var sg_icon_sub = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);
		var sg_label_sub = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);

		foreach(string direction in new string[] { "Left", "Right", "Flip Upside Down" }){
			
			var sub_menu_item = gtk_menu_add_item(
				sub_menu,
				direction,
				"",
				null,
				sg_icon_sub,
				sg_label_sub);

			sub_menu_item.activate.connect (() => {
				view.image_rotate(direction.split(" ")[0].strip().down());
			});
		}
	}

	private void add_image_convert(Gtk.Menu menu, Gtk.SizeGroup sg_icon, Gtk.SizeGroup sg_label){

		log_debug("FileContextMenu: add_image_convert()");

		var menu_item = gtk_menu_add_item(
			menu,
			_("Convert to"),
			"",
			null,
			sg_icon,
			sg_label);

		menu_item.sensitive = (selected_item != null);

		if (selected_item == null){ return; }
			
		var sub_menu = new Gtk.Menu();
		sub_menu.reserve_toggle_size = false;
		menu_item.submenu = sub_menu;

		var sg_icon_sub = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);
		var sg_label_sub = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);

		foreach(string format in new string[] { "PNG", "JPEG", "TIFF", "ICO", "BMP" }){
			
			var sub_menu_item = gtk_menu_add_item(
				sub_menu,
				format,
				"",
				null,
				sg_icon_sub,
				sg_label_sub);

			sub_menu_item.activate.connect (() => {
				view.image_convert(format.down());
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
				if (item is FileItemArchive){
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
