/*
 * MainWindow.vala
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

public enum AccelContext {
	TERM,
	NORMAL,
	TRASH,
	ARCHIVE,
	EDIT,
	NONE
}

public class MainWindow : Gtk.Window {

	private Gtk.Box vbox_main;
	private Gtk.Paned pane_nav;
	private Gtk.Notebook notebook;

	public MainMenuBar menubar;
	public Sidebar sidebar;
	public FileViewToolbar toolbar;
	public Pathbar pathbar;
	public LayoutBox layout_box;
	public Statusbar statusbar;
	public MainHeaderBar headerbar;

	public ProgressPanel pending_action = null;

	public FileMonitor? open_task_monitor = null;

	public bool refresh_apps_pending = false;

	// window
	private int def_width = 700;
	private int def_height = 500;

	private uint tmr_task = 0;
	private uint tmr_init = 0;
	private uint tmr_init_tab_delayed = 0;

	public bool window_is_ready = false;
	public bool window_is_closing = false;

	public static Gee.ArrayList<MainWindow> instances;

	public const Gtk.TargetEntry[] drop_target_types = {
		{ "text/uri-list", 0, 0 }
	};

	public MainWindow() {

		log_debug("MainWindow()");

		App.main_window = this;

		App.increment_run_count();

		this.destroy.connect(on_destroy);
		this.delete_event.connect(on_delete_event);

		if (instances == null){
			instances = new Gee.ArrayList<MainWindow> ();
		}
		instances.add(this);

		if (App.maximise_on_startup){
			maximize();
		}
		else{
			def_width = get_display_width() - 400;
			def_height = get_display_height() - 200;
		}

		check_dependencies();

		init_window();

		//TODO: mark strings for translation

		log_debug("MainWindow():exit");
	}

	private void on_destroy(){
		Gtk.main_quit();
	}

	private bool on_delete_event(Gdk.EventAny event){

		log_debug("MainWindow: on_delete_event()");

		this.delete_event.disconnect(on_delete_event); //disconnect this handler

		App.sidebar_position = pane_nav.position;

		if (show_file_operation_warning_on_window_close() == Gtk.ResponseType.NO){
			log_debug("MainWindow: running operation warning displayed");
			log_debug("MainWindow: cancelled on_delete_event");
			this.delete_event.connect(on_delete_event); // reconnect this handler
			return true; // keep window open
		}
		else{
			log_debug("MainWindow: no operations running");
			
			save_session();

			if (App.check_donation_trigger()){
				log_debug("Donation message shown");
				App.increment_run_count();
				open_donate_window();
			}

			log_debug("MainWindow: exiting...");
		
			window_is_closing = true; // set after save_session()
			return false; // close window
		}
	}

	private Gtk.ResponseType show_file_operation_warning_on_window_close(){

		var response = Gtk.ResponseType.YES;

		var list = file_operations;

		if (list.size > 0){
			string title = _("Cancel File Operations?");
			string msg = _("Closing the application will cancel running file operations.\nDo you want to cancel?");
			response = gtk_messagebox_yes_no(title, msg, this);

			if (response == Gtk.ResponseType.YES){
				foreach(var action in list){
					action.cancel();
				}
				sleep(1000);
			}
		}

		return response;
	}

	//init

	private void init_window () {

		title = AppName + " v" + AppVersion;
		set_default_size(def_width, def_height);
		window_position = WindowPosition.CENTER;
		icon = get_app_icon(256);
		resizable = true;

		//vbox_main
		vbox_main = new Gtk.Box(Orientation.VERTICAL, 0);
		vbox_main.margin = 0;
		add (vbox_main);

		init_hotkeys();
		
		init_menubar();

		init_headerbar();

		init_toolbar();

		init_pathbar();

		init_sidebar();

		init_layout_box();

		init_statusbar();

		init_device_events();

		show_all();

		tmr_init = Timeout.add(100, init_delayed);
	}

	private bool init_delayed(){

		if (tmr_init > 0){
			Source.remove(tmr_init);
			tmr_init = 0;
		}

		gtk_set_busy(true, this);

		initialize_views();

		headerbar.refresh();
		
		toolbar.refresh();

		pathbar.refresh();

		sidebar.refresh();

		reset_sidebar_width();

		statusbar.refresh();

		layout_box.refresh_for_active_pane();

		menubar.delayed_init();

		gtk_set_busy(false, this);

		window_is_ready = true;

		if (App.first_run){
			open_wizard_window();
		}
		else{
			if (App.first_run_after_update()){
				App.open_changelog_webpage();
			}
		}

		foreach(var view in views){
			view.start_thumbnail_updater();
		}

		return false;
	}

	private void init_menubar(){

		if (!App.headerbar_enabled){
			
			menubar = new MainMenuBar(false);
			vbox_main.add(menubar);
		}
		else{
			menubar = new MainMenuBar(true);
			//vbox_main.add(menubar);
		}

	}

	private void init_headerbar(){
		headerbar = new MainHeaderBar();
		//vbox_main.add(headerbar);
		if (App.headerbar_enabled){
			this.set_titlebar(headerbar);
		}
	}

	private void init_toolbar(){
		toolbar = new FileViewToolbar();
		vbox_main.add(toolbar);
	}

	private void init_pathbar(){
		pathbar = new Pathbar(null);
		vbox_main.add(pathbar);
	}

	private void init_sidebar(){

		// add a horizontal pane (pane_nav) to the window

		var pane = new Gtk.Paned (Gtk.Orientation.HORIZONTAL);
		//pane.position = 300;
		//pane.margin = 3;
		vbox_main.add(pane);
		pane_nav = pane;

		// add the navigation box to the left pane of pane_nav
		sidebar = new Sidebar(null,null,null);
		pane_nav.pack1(sidebar, false, false); // resize, shrink

		DeviceMonitor.get_monitor().changed.connect(()=>{
			sidebar.refresh();
		});

		App.trashcan.query_completed.connect(()=>{
			if (window_is_ready) {
				sidebar.refresh();
			}
		});
	}

	private void init_layout_box(){
		layout_box = new LayoutBox();
		pane_nav.pack2(layout_box, true, false); // resize, no shrink
	}
	
	private void initialize_views(){

		TreeModelCache.enable();

		if (App.cmd_files.size > 0){

			log_debug("opening directories specified as command line arguments");

			foreach(string file_path in App.cmd_files){
				if (dir_exists(file_path)){
					var tab = layout_box.panel1.add_tab(false);
					tab.pane.view.set_view_path(file_path);
				}
			}

			layout_box.set_panel_layout(PanelLayout.SINGLE, false);

			if (layout_box.panel1.tabs.size > 0){
				active_pane = layout_box.panel1.tabs[0].pane;
			}

			log_debug("opening directories specified as command line arguments: exit");
		}
		else{

			bool session_loaded = false;

			if (App.restore_last_session && App.session_lock.lock_acquired){
				session_loaded = load_session();
			}

			if (!session_loaded){
				log_debug("opening new session with default settings");

				foreach(var panel in layout_box.panels){
					var tab = panel.add_tab(false);
					tab.pane.view.set_view_path(App.user_home);
				}

				layout_box.apply_panel_layout();

				active_pane = layout_box.panel1.tabs[0].pane;

				log_debug("opening new session with default settings: exit");
			}
		}

		add_monitor_for_single_instance();

		TreeModelCache.disable();
	}

	private void add_monitor_for_single_instance(){
		
		var openpath = new FileItem.from_path(App.app_conf_dir_path_open);
		Cancellable? cancellable;
		open_task_monitor = openpath.monitor_for_changes(out cancellable);

		open_task_monitor.changed.connect(open_task_monitor_directory_changed);
	}

	private void open_task_monitor_directory_changed(File src, File? dest, FileMonitorEvent event){

		if (dest != null) {
			log_msg("[MONITOR-SI] %s: %s, %s".printf(event.to_string(), src.get_path(), dest.get_path()));
		} else {
			log_msg("[MONITOR-SI] %s: %s".printf(event.to_string(), src.get_path()));
		}

		switch (event){
		case FileMonitorEvent.CREATED:
			string task_file = src.get_path();
			if (file_exists(task_file)){
				string path_to_open = file_read(task_file);
				if (dir_exists(path_to_open)){
					if (active_pane != null){
						active_pane.view.open_in_new_tab(path_to_open);
					}
				}
				file_delete(task_file);
			}
			bring_window_to_front();
			break;
		}
	}

	private void bring_window_to_front(){
		this.deiconify();
		//this.maximize();
		this.set_keep_above(true);
		this.present();
		sleep(100);
		this.set_keep_above(false);
		gtk_set_busy(false, this);
	}

	private void init_hotkeys() { 

		Hotkeys.init();
		this.add_accel_group(Hotkeys.accel_group);

		//enable_accelerators();
		//this.accel_group.connect("<Control>x", Gdk.ModifierType.CONTROL_MASK, Gtk.AccelFlags.VISIBLE, () => view.cut());
		
		//Hotkeys.bind("<Control>c", (grp, acc, keyval, mod) =>{ active_pane.view.copy(); return true; }); 
		//Hotkeys.bind("<Control>x", (grp, acc, keyval, mod) =>{ active_pane.view.cut(); return true; }); 
		//Hotkeys.bind("<Control>v", (grp, acc, keyval, mod) =>{ active_pane.view.paste(); return true; }); 
	}

	public void update_accelerators_for_active_pane(){
		
		if (active_pane == null){ return; }
		if (active_pane.view == null){ return; }
		if (active_pane.view.current_item == null){ return; }

		if (active_pane.view.current_item.is_trash || active_pane.view.current_item.is_trashed_item){
			update_accelerators_for_context(AccelContext.TRASH);
		}
		else if (active_pane.view.current_item.is_archive || active_pane.view.current_item.is_archived_item){
			update_accelerators_for_context(AccelContext.ARCHIVE);
		}
		else {
			update_accelerators_for_context(AccelContext.NORMAL);
		}
	}

	public void update_accelerators_for_terminal(){
		update_accelerators_for_context(AccelContext.TERM);
	}

	public void update_accelerators_for_edit(){
		update_accelerators_for_context(AccelContext.EDIT);
	}
	
	public void update_accelerators_for_context(AccelContext context){

		menubar.context_none();
		
		switch(context){
		case AccelContext.TERM:
			menubar.context_term();
			break;
		case AccelContext.NORMAL:
			menubar.context_normal();
			break;
		case AccelContext.TRASH:
			menubar.context_trash();
			break;
		case AccelContext.ARCHIVE:
			menubar.context_archive();
			break;
		case AccelContext.EDIT:
			menubar.context_edit();
			break;
		case AccelContext.NONE:
			menubar.context_none();
			break;
		}
	}

	private void init_statusbar(){
		statusbar = new Statusbar(null);
		vbox_main.add(statusbar);
	}

	private void init_device_events(){
		DeviceMonitor.get_monitor().mount_removed.connect(mount_removed);
	}
	
	private void mount_removed(Mount mount){
		//log_debug("MainWindow: mount_removed(): %s".printf(path_prefix));
		var mount_path = mount.get_root().get_path();
		foreach(var view in views){
			if ((view.current_item != null) && (view.current_item.file_path.has_prefix(mount_path))){
				view.set_overlay_on_unmount();
			}
		}
	}
	
	private void check_dependencies(){

		string message;
		if (!App.check_dependencies(out message)) {
			string title = _("Missing Dependencies");
			gtk_messagebox(title, message, this, true);
			exit(1);
		}

		/*if (ArchiveTask.7zip_version < 0){
			string title = _("Missing Dependencies");
			message = _("7-Zip version is unsupported") + " (v%s)\n".printf(ArchiveTask.7zip_version_name);
			message += _("Please report this by sending an email to teejeetech@gmail.com");
			gtk_messagebox(title, message, this, true);
			exit (1);
		}*/
	}

	// properties ------------------------

	private FileViewPane _active_pane;
	public FileViewPane active_pane{
		get {
			return _active_pane;
		}
		set {

			if (_active_pane == value){
				return;
			}

			log_debug("MainWindow: active_pane_changed: panel = %ld, tab = %d".printf(value.panel.number, value.tab.tab_index));
			
			_active_pane = value;

			toolbar.refresh_for_active_pane();

			pathbar.refresh_for_active_pane();

			headerbar.refresh_for_active_pane();

			statusbar.refresh_for_active_pane();

			layout_box.refresh_for_active_pane();

			menubar.active_pane_changed();

			this.update_accelerators_for_active_pane();
		}
	}

	private Gee.ArrayList<ProgressPanel> file_operations{
		owned get{
			return layout_box.file_operations;
		}
	}

	public Gee.ArrayList<FileViewList> views {
		owned get {
			var list = new Gee.ArrayList<FileViewList>();
			foreach(var pane in panes){
				list.add(pane.view);
			}
			return list;
		}
	}

	public Gee.ArrayList<TermBox> terminals {
		owned get {
			var list = new Gee.ArrayList<TermBox>();
			foreach(var pane in panes){
				list.add(pane.terminal);
			}
			return list;
		}
	}
	
	public Gee.ArrayList<FileViewPane> panes {
		owned get {
			var list = new Gee.ArrayList<FileViewPane>();
			foreach(var panel in panels){
				foreach(var tab in panel.tabs){
					list.add(tab.pane);
				}
			}
			return list;
		}
	}

	public Gee.ArrayList<LayoutPanel> panels {
		owned get {
			return layout_box.panels;
		}
	}

	// refresh

	/*public void refresh_views(string dir_path){
		log_debug("MainWindow: refresh_views(%s)".printf(dir_path));
		foreach(var view in views){
			if ((view.current_item != null) && (view.current_item.file_path == dir_path)){
				//view.query_items();
				view.pane.refresh();
			}
		}
		log_debug("MainWindow: refresh_views(): exit");
	}*/

	public void refresh_trash(){
		log_debug("MainWindow: refresh_trash()");
		foreach(var view in views){
			if ((view.current_item != null) && view.current_item.is_trash){
				//view.query_items();
				view.pane.refresh();
				sidebar.refresh();
			}
		}
	}

	/*public void reset_views_with_path_prefix(string path_prefix){
		log_debug("MainWindow: reset_views_with_path_prefix(): %s".printf(path_prefix));
		foreach(var view in views){
			if ((view.current_item != null) && (view.current_item.file_path.has_prefix(path_prefix))){
				view.set_view_path(App.user_home);
			}
		}
		log_debug("MainWindow: reset_views_with_path_prefix(): exit");
	}*/

	public void refresh_treemodels(){

		log_debug("MainWindow: refresh_treemodels()");

		gtk_set_busy(true, this);

		foreach(var view in views){
			view.refresh_treeview(); // will refresh iconview if required
		}

		gtk_do_events();
		gtk_set_busy(false, this);

		log_debug("MainWindow: refresh_treemodels(): exit");
	}

	public void reset_sidebar_width(){
		if (App.sidebar_visible){
			pane_nav.position = App.sidebar_position;
		}
		else{
			pane_nav.position = 0; // set default size
		}
	}

	public void save_sidebar_position(){
		if (sidebar.visible && (pane_nav.position > 0)){
			log_debug("MainWindow: save_sidebar_position: %d".printf(pane_nav.position));
			App.sidebar_position = pane_nav.position;
		}
	}

	public void restore_sidebar_position(){
		if (sidebar.visible){
			log_debug("MainWindow: restore_sidebar_position: %d".printf(App.sidebar_position));
			if (App.sidebar_position < 10){
				App.sidebar_position = 250;
			}
			pane_nav.position = App.sidebar_position;
		}
	}

	public bool is_fullscreen = false;
	
	public void toggle_fullscreen(){
		
		if (this.is_fullscreen){
			this.unfullscreen();
			is_fullscreen = false;
		}
		else{
			this.fullscreen();
			is_fullscreen = true;
		}

	}
	
	// actions

	public void open_settings_window(){

		// add tab if all tabs are closed
		//if (tabs.size == 0){
			//add_tab();
		//}

		var dlg = new SettingsWindow();
	}

	public void open_wizard_window(){

		// add tab if all tabs are closed
		//if (tabs.size == 0){
			//add_tab();
		//}

		var dlg = new WizardWindow();
	}

	public void open_donate_window(){
		log_debug("open_donate_window()");
		var dialog = new DonationWindow();
		dialog.set_transient_for(this);
		dialog.run();
		dialog.destroy();
	}

	public void open_about_window(){

		var dialog = new AboutWindow();
		dialog.set_transient_for (this);

		dialog.authors = {
			"Tony George:teejeetech@gmail.com"
		};

		dialog.translators = {
			"Thomas Gorzka (German):thomas.gorzka@gmail.com"
			//"Jorge Jamhour (Brazilian Portuguese):https://launchpad.net/~jorge-jamhour",
			//"B. W. Knight (Korean):https://launchpad.net/~kbd0651",
			//"Rodion R. (Russian):https://launchpad.net/~r0di0n"
		};

		dialog.third_party = {
			"Arc Icon Theme (fallback icons):https://github.com/horst3180/arc-icon-theme",
			"Elementary Icon Theme (fallback icons):https://github.com/elementary/icons",
			"Faba Icon Theme (fallback icons):https://github.com/snwh/faba-icon-theme",
			"Moka Icon Theme (fallback icons):https://github.com/snwh/moka-icon-theme",
			"7zip by Igor Pavlov (archive handling):http://www.7-zip.org/",
			"ExifTool by Phil Harvey (EXIF properties):http://www.sno.phy.queensu.ca/~phil/exiftool/",
			"FFmpeg (video thumbnails):https://ffmpeg.org/",
			"MediaInfo (media properties):https://mediaarea.net/en/MediaInfo",
			"p7zip (archive handling):http://p7zip.sourceforge.net/",
			"PDFtk (PDF handling):https://www.pdflabs.com/tools/pdftk-the-pdf-toolkit/",
			"Ghostscript (PDF handling):https://www.ghostscript.com/",
			"QEMU (vm):http://www.qemu.org/"
		};

		//TODO: Add all icon theme sources

		dialog.documenters = null;
		dialog.artists = null;
		dialog.donations = null;

		dialog.program_name = AppName;
		dialog.comments = _("A modern, light-weight file manager for Linux");
		dialog.copyright = "Copyright © 2017 Tony George (%s)".printf(AppAuthorEmail);
		dialog.version = AppVersion;
		dialog.logo = get_app_icon(128,".svg");

		//dialog.license = "";
		dialog.website = "http://teejeetech.in";
		dialog.website_label = "http://teejeetech.blogspot.in";

		dialog.initialize();
		dialog.show_all();
	}

	public void rebuild_font_cache(){
		string cmd = "fc-cache -f -v";
		layout_box.panel1.run_script_in_new_terminal_tab(cmd, _("Rebuilding Font Cache..."));
	}

	public void clear_thumbnail_cache(){

		string cmd = "";
		
		foreach(string dir in new string[] { "normal", "large", "fail" }){
			cmd += "rm -rfv '%s/.cache/thumbnails/%s'\n".printf(escape_single_quote(App.user_home), dir);
			cmd += "mkdir -pv '%s/.cache/thumbnails/%s'\n".printf(escape_single_quote(App.user_home), dir);
		}
		
		layout_box.panel1.run_script_in_new_terminal_tab(cmd, _("Cleaning Thumbnail Cache..."));
	}

	public void cloud_login(){

		err_log_clear();

		var win = new CloudLoginWindow(this);

	}

	// session -------------------------------------
	
	public void save_session(){

		log_msg("MainWindow: save_session()");

		if (!App.session_lock.lock_acquired){ return; }

		if (!window_is_ready){ return; }

		if (window_is_closing){ return; }

		var timer = timer_start();

		set_numeric_locale("C");

		var node_config = new Json.Object();

		// session
		var node_session = new Json.Object();
		node_config.set_object_member("session", node_session);

		node_session.set_int_member("format-version", (int64) Main.SESSION_FORMAT_VERSION);
		node_session.set_string_member("timestamp", (new DateTime.now_utc()).to_unix().to_string());
		node_session.set_string_member("user", App.user_name);
		node_session.set_int_member("layout", ((int64) layout_box.get_panel_layout()));
		node_session.set_int_member("pane_pos_top", (int64) layout_box.paned_dual_top.position);
		node_session.set_int_member("pane_pos_bottom", (int64) layout_box.paned_dual_bottom.position);
		node_session.set_int_member("pane_pos_quad", (int64) layout_box.paned_quad.position);

		// panes
		var node_panes = new Json.Array();
		node_session.set_array_member("panes", node_panes);

		foreach(var panel in layout_box.panels){

			log_debug("panel: %d".printf(panel.number));

			// pane
			var node_pane = new Json.Object();
			node_panes.add_object_element(node_pane);

			node_pane.set_int_member("number", (int64) panel.number);
			node_pane.set_int_member("active_tab", (int64) panel.notebook.get_current_page());
			node_pane.set_boolean_member("visible", panel.visible);

			// tabs
			var node_tabs = new Json.Array();
			node_pane.set_array_member("tabs", node_tabs);

			foreach(var tab in panel.tabs){

				if (tab.is_dummy) { continue; }
				//if (tab.pane.view.current_item == null) { continue; }

				// tab
				var node_tab = new Json.Object();
				node_tabs.add_object_element(node_tab);

				string tab_view_path = "";
				if (tab.pane.view.current_item == null){
					tab_view_path = tab.pane.view.current_path_saved;
				}
				//else if (tab.pane.view.current_item.is_trash || tab.pane.view.current_item.is_trashed_item){
				//	tab_view_path = "trash://";
				//}
				//else if (tab.pane.view.current_item.is_archive || tab.pane.view.current_item.is_archived_item){
				//	tab_view_path = tab.pane.view.current_item.display_path;
				//}
				else{
					tab_view_path = tab.pane.view.current_item.display_path;
				}

				node_tab.set_boolean_member("renamed", tab.renamed);
				node_tab.set_string_member("name", tab.tab_name);
				node_tab.set_string_member("path", tab_view_path);
				node_tab.set_int_member("view", ((int64) tab.pane.view.get_view_mode_user())); // save view mode user
				node_tab.set_boolean_member("show_hidden", tab.pane.view.show_hidden_files);
				node_tab.set_boolean_member("active", (active_pane == tab.pane));
			}
		}

		var json = new Json.Generator();
		json.pretty = true;
		json.indent = 2;
		var node = new Json.Node(Json.NodeType.OBJECT);
		node.set_object(node_config);
		json.set_root(node);

		try{
			json.to_file(App.app_conf_session);
		}
		catch (Error e) {
	        log_error (e.message);
	    }

	    log_msg("session saved");

	    log_trace("session saved: %s".printf(timer_elapsed_string(timer)));

		set_numeric_locale("");
	}

	public bool load_session(){

		if (!App.restore_last_session){ return false; }

		if (!App.session_lock.lock_acquired){ return false; }

		if (!file_exists(App.app_conf_session)){ return false; }

		var win = new LoadingWindow(this, _("Restoring session..."), "", false);
		win.show_all();

		log_debug("restoring session: %s".printf(string.nfill(60,'=')));

		set_numeric_locale("C");

		var parser = new Json.Parser();

        try{
			parser.load_from_file(App.app_conf_session);
		}
		catch (Error e) {
	        log_error (e.message);
	    }

		var timer = timer_start();

	    TreeModelCache.enable();

        var node = parser.get_root();
        var config = node.get_object();

        var node_session = (Json.Object) config.get_object_member("session");

		if (Main.format_is_obsolete(node_session, Main.SESSION_FORMAT_VERSION)){
			TreeModelCache.disable();
			timer_elapsed(timer); // stops timer
			win.close();
			return false;
		}

		layout_box.set_panel_layout((PanelLayout) node_session.get_int_member("layout"));

		//layout_box.paned_dual_top.position= (int) node_session.get_int_member("pane_pos_top");
		//layout_box.paned_dual_bottom.position = (int) node_session.get_int_member("pane_pos_bottom");
		//layout_box.paned_quad.position = (int) node_session.get_int_member("pane_pos_quad");

		var node_panes = (Json.Array) node_session.get_array_member("panes");
		foreach(var panenode in node_panes.get_elements()){
			load_session_pane(panenode);
		}

		set_numeric_locale("");

		TreeModelCache.disable();

		win.close();

		log_msg("session restored: %s".printf(string.nfill(60,'=')));

		log_trace("session restored: %s".printf(timer_elapsed_string(timer)));

		return true;
	}

	private void load_session_pane(Json.Node node){

		var node_pane = node.get_object();

		int num = (int) node_pane.get_int_member("number");
		int active_tab = (int) node_pane.get_int_member("active_tab");
		bool is_visible = node_pane.get_boolean_member("visible");

		log_debug("session-load: pane: %d".printf(num));

		var panel = layout_box.panels[num-1];

		bool atleast_one_tab_loaded = false;
		
		var node_tabs = (Json.Array) node_pane.get_array_member("tabs");
		foreach(var tabnode in node_tabs.get_elements()){
			bool ok = load_session_tab(panel, tabnode);
			if (ok){
				atleast_one_tab_loaded = true;
			}
		}

		if (!atleast_one_tab_loaded){
			var tab = panel.add_tab(false);
			tab.pane.view.set_view_path(App.user_home);
			active_tab = 0;
		}

		if (active_tab < panel.notebook.get_n_pages() - 1){
			panel.notebook.set_current_page(active_tab);
		}
		else{
			panel.notebook.set_current_page(0);
		}

		log_debug("session-load: pane: %d: ok".printf(num));

		gtk_do_events();
	}

	private bool load_session_tab(LayoutPanel panel, Json.Node node){

		log_debug("session-load: tab: %d".printf(panel.tabs.size));

		var node_tab = node.get_object();

		var tab = panel.add_tab();
		tab.tab_name = node_tab.get_string_member("name");
		tab.renamed = node_tab.get_boolean_member("renamed");

		var path = node_tab.get_string_member("path");
		var vmode = (int) node_tab.get_int_member("view");
		bool show_hidden = node_tab.get_boolean_member("show_hidden");
		bool is_active = node_tab.get_boolean_member("active");

		if ((vmode < 1) || (vmode > 4)){
			vmode = (int) App.view_mode;
		}

		var view = tab.pane.view;
		view.show_hidden_files = show_hidden;
		view.set_view_mode((ViewMode) vmode);
		view.set_view_path(path);
		
		if (is_active){
			active_pane = tab.pane;
		}

		log_debug("session-load: tab: %d: ok".printf(panel.tabs.size - 1));

		return true;
	}
}
