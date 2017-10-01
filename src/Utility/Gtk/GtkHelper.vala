

using TeeJee.Logging;
using TeeJee.FileSystem;
using TeeJee.JsonHelper;
using TeeJee.ProcessHelper;
using TeeJee.System;
using TeeJee.Misc;

namespace TeeJee.GtkHelper{

	using Gtk;

	// messages -----------
	
	public void show_err_log(Gtk.Window parent, bool disable_log = true){
		if ((err_log != null) && (err_log.length > 0)){
			gtk_messagebox(_("Error"), err_log, parent, true);
		}

		if (disable_log){
			err_log_disable();
		}
	}
	
	public void gtk_do_events (){

		/* Do pending events */

		while(Gtk.events_pending ())
			Gtk.main_iteration ();
	}

	public void gtk_set_busy (bool busy, Gtk.Window win) {

		/* Show or hide busy cursor on window */

		Gdk.Cursor? cursor = null;

		if (busy){
			cursor = new Gdk.Cursor.from_name(Gdk.Display.get_default(), "wait");
		}
		else{
			cursor = new Gdk.Cursor.from_name(Gdk.Display.get_default(), "default");
		}

		var window = win.get_window();

		if (window != null) {
			window.set_cursor (cursor);
		}

		gtk_do_events();
	}

	public void set_pointer_cursor_for_eventbox(Gtk.EventBox ebox){
		
		var cursor = new Gdk.Cursor.from_name(Gdk.Display.get_default(), "pointer");

		if (ebox.get_realized()){
			ebox.get_window().set_cursor(cursor);
		}
		else{
			ebox.realize.connect(()=>{
				ebox.get_window().set_cursor(cursor);
			});
		}
	}
	
	public void gtk_messagebox(
		string title, string message, Gtk.Window? parent_win, bool is_error = false){

		/* Shows a simple message box */

		var type = Gtk.MessageType.INFO;
		if (is_error){
			type = Gtk.MessageType.ERROR;
		}
		else{
			type = Gtk.MessageType.INFO;
		}

		/*var dlg = new Gtk.MessageDialog.with_markup(null, Gtk.DialogFlags.MODAL, type, Gtk.ButtonsType.OK, message);
		dlg.title = title;
		dlg.set_default_size (200, -1);
		if (parent_win != null){
			dlg.set_transient_for(parent_win);
			dlg.set_modal(true);
		}
		dlg.run();
		dlg.destroy();*/

		var dlg = new CustomMessageDialog(title,message,type,parent_win, Gtk.ButtonsType.OK);
		dlg.run();
		dlg.destroy();
	}

	public Gtk.ResponseType gtk_messagebox_yes_no(
		string title, string message, Gtk.Window? parent_win, bool is_warning = false){

		/* Shows a simple message box */

		var type = Gtk.MessageType.INFO;
		if (is_warning){
			type = Gtk.MessageType.WARNING;
		}

		var dlg = new CustomMessageDialog(title,message,type,parent_win, Gtk.ButtonsType.YES_NO);
		int response = dlg.run();
		dlg.destroy();

		return (Gtk.ResponseType) response;
	}

	public string? gtk_inputbox(
		string title, string message, Gtk.Window? parent_win, bool mask_password = false, string default_text = ""){

		/* Shows a simple input prompt */

		//vbox_main
        Gtk.Box vbox_main = new Gtk.Box(Orientation.VERTICAL, 0);
        vbox_main.margin = 0;

		//lbl_input
		Gtk.Label lbl_input = new Gtk.Label(title);
		lbl_input.xalign = 0.0f;
		lbl_input.label = message;

		//txt_input
		Gtk.Entry txt_input = new Gtk.Entry();
		txt_input.margin_top = 3;
		txt_input.set_visibility(!mask_password);
		txt_input.text = default_text;
		
		//create dialog
		var dlg = new Gtk.Dialog.with_buttons(title, parent_win, DialogFlags.MODAL);
		dlg.title = title;
		dlg.set_default_size (300, -1);
		if (parent_win != null){
			dlg.set_transient_for(parent_win);
			dlg.set_modal(true);
		}

		//add widgets
		var content = (Box) dlg.get_content_area ();
		vbox_main.pack_start (lbl_input, false, true, 0);
		vbox_main.pack_start (txt_input, false, true, 0);
		content.add(vbox_main);
		content.margin = 6;
		
		//add buttons
		var actions = (Box) dlg.get_action_area ();
		dlg.add_button(_("OK"),Gtk.ResponseType.OK);
		dlg.add_button(_("Cancel"),Gtk.ResponseType.CANCEL);
		//actions.margin = 6;
		actions.margin_top = 12;
		
		//keyboard shortcuts
		txt_input.key_press_event.connect ((w, event) => {
			if (event.keyval == 65293) {
				dlg.response(Gtk.ResponseType.OK);
				return true;
			}
			return false;
		});

		dlg.show_all();
		int response = dlg.run();
		string input_text = txt_input.text;
		dlg.destroy();

		if (response == Gtk.ResponseType.CANCEL){
			return null;
		}
		else{
			return input_text;
		}
	}

	public void wait_and_close_window(int milliseconds, Gtk.Window window){
		gtk_do_events();
		int millis = 0;
		while(millis < milliseconds){
			sleep(200);
			millis += 200;
			gtk_do_events();
		}
		window.destroy();
	}

	public void gtk_show(Gtk.Widget widget){
		widget.set_no_show_all(false);
		widget.show_all();
	}

	public void gtk_hide(Gtk.Widget widget){
		widget.set_no_show_all(true);
		widget.hide();
	}

	public void gtk_suppress_context_menu(Gtk.Widget widget){
		
		// connect signal for shift+F10
        widget.popup_menu.connect(() => {
			return true; // suppress right-click menu
		});

        // connect signal for right-click
		widget.button_press_event.connect((w, event) => {
			if (event.button == 3) {
				return true; // suppress right-click menu
			}
			return false;
		});
	}
	
	public TreeIter gtk_get_iter_next (Gtk.TreeModel model, Gtk.TreeIter iter_find){

		bool return_next = false;
		
		TreeIter iter;
		bool iterExists = model.get_iter_first (out iter);
		while (iterExists){
			if (return_next){
				return iter;
			}
			else if (iter == iter_find){
				return_next = true;
			}
			iterExists = model.iter_next (ref iter);
		}

		return iter_find;
	}

	public TreeIter gtk_get_iter_prev (Gtk.TreeModel model, Gtk.TreeIter iter_find){

		TreeIter iter_prev = iter_find;
		
		TreeIter iter;
		bool iterExists = model.get_iter_first (out iter);
		while (iterExists){
			if (iter == iter_find){
				return iter_prev;
			}
			iter_prev = iter;
			iterExists = model.iter_next (ref iter);
		}

		return iter_find;
	}
	
	// combo ---------
	
	public bool gtk_combobox_set_value (ComboBox combo, int index, string val){

		/* Conveniance function to set combobox value */

		TreeIter iter;
		string comboVal;
		TreeModel model = (TreeModel) combo.model;

		bool iterExists = model.get_iter_first (out iter);
		while (iterExists){
			model.get(iter, 1, out comboVal);
			if (comboVal == val){
				combo.set_active_iter(iter);
				return true;
			}
			iterExists = model.iter_next (ref iter);
		}

		return false;
	}

	public string gtk_combobox_get_value (ComboBox combo, int index, string default_value){

		/* Conveniance function to get combobox value */

		if ((combo.model == null) || (combo.active < 0)) { return default_value; }

		TreeIter iter;
		string val = "";
		combo.get_active_iter (out iter);
		TreeModel model = (TreeModel) combo.model;
		model.get(iter, index, out val);

		return val;
	}

	public GLib.Object gtk_combobox_get_selected_object (
		ComboBox combo,
		int index,
		GLib.Object default_value){

		/* Conveniance function to get combobox value */

		if ((combo.model == null) || (combo.active < 0)) { return default_value; }

		TreeIter iter;
		GLib.Object val = null;
		combo.get_active_iter (out iter);
		TreeModel model = (TreeModel) combo.model;
		model.get(iter, index, out val);

		return val;
	}
	
	public int gtk_combobox_get_value_enum (ComboBox combo, int index, int default_value){

		/* Conveniance function to get combobox value */

		if ((combo.model == null) || (combo.active < 0)) { return default_value; }

		TreeIter iter;
		int val;
		combo.get_active_iter (out iter);
		TreeModel model = (TreeModel) combo.model;
		model.get(iter, index, out val);

		return val;
	}

	// icon -------
	
	public Gdk.Pixbuf? get_app_icon(int icon_size, string format = ".png"){
		
		var img_icon = get_shared_icon(AppShortName, AppShortName + format,icon_size,"pixmaps");
		if (img_icon != null){
			return img_icon.pixbuf;
		}
		else{
			return null;
		}
	}

	public Gtk.Image? get_shared_icon(
		string icon_name,
		string fallback_icon_file_name,
		int icon_size,
		string icon_directory = AppShortName + "/images"){
		
		Gdk.Pixbuf pix_icon = null;
		Gtk.Image img_icon = null;

		if ((icon_name.length == 0) && (fallback_icon_file_name.length == 0)){
			return null;
		}
		
		try {
			if (icon_name.length > 0) {
				
				Gtk.IconTheme icon_theme = Gtk.IconTheme.get_default();
				
				pix_icon = icon_theme.load_icon_for_scale (
					icon_name, Gtk.IconSize.MENU, icon_size, Gtk.IconLookupFlags.FORCE_SIZE);
			}
		}
		catch (Error e) {
			log_warning (e.message);
		}

		if (fallback_icon_file_name.length == 0){ return null; }
		
		string fallback_icon_file_path = "/usr/share/%s/%s".printf(icon_directory, fallback_icon_file_name);

		if (pix_icon == null){
			try {
				pix_icon = new Gdk.Pixbuf.from_file_at_size (fallback_icon_file_path, icon_size, icon_size);
			} catch (Error e) {
				log_warning (e.message);
			}
		}

		if (pix_icon == null){
			log_warning (_("Missing Icon") + ": '%s', '%s'".printf(icon_name, fallback_icon_file_path));
		}
		else{
			img_icon = new Gtk.Image.from_pixbuf(pix_icon);
		}

		return img_icon;
	}

	public Gdk.Pixbuf? get_gicon(
		GLib.Icon gicon,
		int icon_size){
			
		Gdk.Pixbuf pix_icon = null;
		Gtk.Image img_icon = null;

		try {
			Gtk.IconTheme icon_theme = Gtk.IconTheme.get_default();
			
			pix_icon = icon_theme.lookup_by_gicon (
				gicon,icon_size , Gtk.IconLookupFlags.FORCE_SIZE).load_icon();
				
		} catch (Error e) {
			//log_error (e.message);
		}

		return pix_icon;
	}

	public Gdk.Pixbuf? get_shared_icon_pixbuf(string icon_name,
		string fallback_file_name,
		int icon_size,
		string icon_directory = AppShortName + "/images"){
			
		var img = get_shared_icon(icon_name, fallback_file_name, icon_size, icon_directory);
		var pixbuf = (img == null) ? null : img.pixbuf;
		return pixbuf;
	}

    public Gtk.Image? gtk_image_from_pixbuf(Gdk.Pixbuf? pixbuf) {
		
		if (pixbuf != null){
			return new Gtk.Image.from_pixbuf(pixbuf);
		}
		else{
			return null;
		}
    }
    
	public int gtk_icon_size_to_index(Gtk.IconSize icon_size){
		
		switch(icon_size){
		case Gtk.IconSize.MENU:
		case Gtk.IconSize.BUTTON:
		case Gtk.IconSize.SMALL_TOOLBAR:
			return 1; // 16px
		case Gtk.IconSize.LARGE_TOOLBAR:
			return 2; // 24px
		case Gtk.IconSize.DND:
			return 3; // 32px
		case Gtk.IconSize.DIALOG:
			return 4; // 48px
		default:
			return 1;
		}
	}

	public Gtk.IconSize gtk_index_to_icon_size(int icon_size_index){
		
		switch(icon_size_index){
		case 1:
			return Gtk.IconSize.SMALL_TOOLBAR;
		case 2:
			return Gtk.IconSize.LARGE_TOOLBAR;
		case 3:
			return Gtk.IconSize.DND;
		case 4:
			return Gtk.IconSize.DIALOG;
		default:
			return Gtk.IconSize.SMALL_TOOLBAR;
		}
	}

	public Gtk.IconSize gtk_width_to_icon_size(int icon_width){

		Gtk.IconSize icon_size = Gtk.IconSize.MENU;

		if (icon_width <= 16){
			icon_size = Gtk.IconSize.MENU;
		}
		else if (icon_width <= 24){
			icon_size = Gtk.IconSize.LARGE_TOOLBAR;
		}
		else if (icon_width <= 32){
			icon_size = Gtk.IconSize.DND;
		}
		else if (icon_width <= 48){
			icon_size = Gtk.IconSize.DIALOG;
		}
		else{
			icon_size = Gtk.IconSize.MENU;
		}

		return icon_size;
	}



	// styles ----------------

	public static int CSS_AUTO_CLASS_INDEX = 0;
	public static void gtk_apply_css(Gtk.Widget[] widgets, string css_style){
		var css_provider = new Gtk.CssProvider();
		var css = ".style_%d { %s }".printf(++CSS_AUTO_CLASS_INDEX, css_style);
		try {
			css_provider.load_from_data(css,-1);
		} catch (GLib.Error e) {
            warning(e.message);
        }

        foreach(var widget in widgets){
			
			widget.get_style_context().add_provider(
				css_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
				
			widget.get_style_context().add_class("style_%d".printf(CSS_AUTO_CLASS_INDEX));
		}

		/*
		css_style sample format:
		
		padding-left: 1px; padding-right: 1px;

		https://developer.gnome.org/gtk3/stable/chap-css-overview.html
		
        */
	}

	public static void gtk_apply_css_globally(string css_style){
		var provider = new Gtk.CssProvider();
		var css = css_style;

		try {
			provider.load_from_data(css,-1);
		}
		catch (GLib.Error e) {
            warning(e.message);
        }
        
        var screen = Gdk.Screen.get_default();
        Gtk.StyleContext.add_provider_for_screen(screen, provider, STYLE_PROVIDER_PRIORITY_USER);
        
		/*
		css_style sample format:
		
		GtkLinkButton { padding-left: 1px; padding-right: 1px;}

		https://developer.gnome.org/gtk3/stable/chap-css-overview.html
		
        */
	}
	
	// treeview -----------------
	
	public int gtk_treeview_model_count(TreeModel model){
		int count = 0;
		TreeIter iter;
		if (model.get_iter_first(out iter)){
			count++;
			while(model.iter_next(ref iter)){
				count++;
			}
		}
		return count;
	}

	public void gtk_stripe_row(Gtk.CellRenderer cell,
		bool odd_row, string odd_color = "#F4F6F7", string even_color = "#FFFFFF"){

		if (cell is Gtk.CellRendererText){
			(cell as Gtk.CellRendererText).background = odd_row ? odd_color : even_color;
		}
		else if (cell is Gtk.CellRendererPixbuf){
			(cell as Gtk.CellRendererPixbuf).cell_background = odd_row ? odd_color : even_color;
		}
	}

	public void gtk_treeview_redraw(Gtk.TreeView treeview){
		var model = treeview.model;
		treeview.model = null;
		treeview.model = model;
	}
	
	// menu
	
	public Gtk.SeparatorMenuItem gtk_menu_add_separator(Gtk.Menu menu){
		
		Gdk.RGBA gray = Gdk.RGBA();
		gray.parse ("rgba(200,200,200,1)");
		
		// separator
		var menu_item = new Gtk.SeparatorMenuItem();
		//menu_item.override_color (StateFlags.NORMAL, gray);
		menu.append(menu_item);

		return menu_item;
	}

	public Gtk.MenuItem gtk_menu_add_item(
		Gtk.Menu menu, string label, string tooltip,
		Gtk.Image? icon_image, Gtk.SizeGroup? sg_icon = null, Gtk.SizeGroup? sg_label = null){

		//log_debug("gtk_menu_add_item()");
		
		var menu_item = new Gtk.MenuItem();

		var box = new Gtk.Box(Orientation.HORIZONTAL, 3);

		// add icon

		if (icon_image == null){
			var dummy = new Gtk.Label("");
			box.add(dummy);

			if (sg_icon != null){
				sg_icon.add_widget(dummy);
			}
		}
		else{
			box.add(icon_image);

			if (sg_icon != null){
				sg_icon.add_widget(icon_image);
			}
		}
		
		// add label
		
		var lbl = new Gtk.Label(label);
		lbl.xalign = 0.0f;
		lbl.margin_right = 6;
		lbl.set_use_markup(true);
		box.add(lbl);

		if (sg_label != null){
			sg_label.add_widget(lbl);
		}

		box.set_tooltip_text(tooltip);

		menu_item.add(box);
		menu.append(menu_item);
		
		menu_item.show_all();

		//log_debug("gtk_menu_add_item(): done");

		return menu_item;
	}

	public Gtk.RadioMenuItem? gtk_menu_add_radio_item(Gtk.Menu menu, string label, string tooltip, Gtk.RadioMenuItem? group){
		var menu_item = new Gtk.RadioMenuItem.with_label(null, label);
		menu_item.set_tooltip_text(tooltip);
		if (group != null){
			menu_item.join_group(group);
		}
		menu.append(menu_item);
		return menu_item;
	}

	public Gtk.CheckMenuItem? gtk_menu_add_check_item(Gtk.Menu menu, string label, string tooltip){
		var menu_item = new Gtk.CheckMenuItem.with_label(label);
		menu_item.set_tooltip_text(tooltip);
		menu.append(menu_item);
		return menu_item;
	}

	// build ui

	public Gtk.Label gtk_box_add_header(Gtk.Box box, string text){
		var label = new Gtk.Label("<b>" + text + "</b>");
		label.set_use_markup(true);
		label.xalign = 0.0f;
		label.margin_bottom = 6;
		box.add(label);

		return label;
	}

	public Gtk.Box gtk_add_scrolled_box(Gtk.Box box){
		
		var scrolled = new Gtk.ScrolledWindow(null, null);
		scrolled.set_shadow_type (ShadowType.ETCHED_IN);
		scrolled.hscrollbar_policy = PolicyType.NEVER;
		scrolled.vscrollbar_policy = PolicyType.NEVER;
		box.add(scrolled);

		var hbox = new Gtk.Box(Orientation.HORIZONTAL, 6);
		scrolled.add(hbox);

		return hbox;
	}

	public Gtk.EventBox gtk_add_event_box(Gtk.Box box){
		
		var ebox = new Gtk.EventBox();
		box.add(ebox);

		set_pointer_cursor_for_eventbox(ebox);
		
		/*
		var tt = _("Edit Path");
		img.set_tooltip_text(tt);
		ebox.set_tooltip_text(tt);

		ebox.button_press_event.connect((event)=>{
			//current_view = view;
			path_edit_mode = !path_edit_mode;
			refresh();
			return true;
		});
		*/

		return ebox;
	}
	
	// misc
	
	public bool gtk_container_has_child(Gtk.Container container, Gtk.Widget widget){
		foreach(var child in container.get_children()){
			if (child == widget){
				return true;
			}
		}
		return false;
	}

	public Gee.ArrayList<Gtk.Widget> gtk_container_get_children(Gtk.Container container){
		var list = new Gee.ArrayList<Gtk.Widget>();
		foreach(var child in container.get_children()){
			list.add(child);
			if (child is Gtk.Container){
				var decendants = gtk_container_get_children((Gtk.Container)child);
				foreach(var decendant in decendants){
					list.add(decendant);
				}
			}
		}
		return list;
	}

	public void gtk_container_remove_children(Gtk.Container container){
		container.forall ((element) => container.remove (element));
	}

	private void text_view_append(Gtk.TextView view, string text){
		TextIter iter;
		view.buffer.get_end_iter(out iter);
		view.buffer.insert(ref iter, text, text.length);
	}

	private void text_view_prepend(Gtk.TextView view, string text){
		TextIter iter;
		view.buffer.get_start_iter(out iter);
		view.buffer.insert(ref iter, text, text.length);
	}

	private void text_view_scroll_to_end(Gtk.TextView view){
		TextIter iter;
		view.buffer.get_end_iter(out iter);
		view.scroll_to_iter(iter, 0.0, false, 0.0, 0.0);
	}

	private void text_view_scroll_to_start(Gtk.TextView view){
		TextIter iter;
		view.buffer.get_start_iter(out iter);
		view.scroll_to_iter(iter, 0.0, false, 0.0, 0.0);
	}
	
	// file chooser ----------------

	public Gee.ArrayList<string> gtk_select_files(Gtk.Window? parent_window,
		bool select_files = true, bool select_multiple = false, Gee.ArrayList<Gtk.FileFilter>? filters = null, Gtk.FileFilter? default_filter = null, string window_title = "", string default_path = ""){


		/* Example:
		
		var filters = new Gee.ArrayList<Gtk.FileFilter>();
		var filter = create_file_filter("All Files", { "*" });
		filters.add(filter);
		filter = create_file_filter("ISO Image File (*.iso)", { "*.iso" });
		filters.add(filter);
		var default_filter = filter;

		var selected_files = gtk_select_files(dummy_window, true, false, filters, default_filter);
		string iso_file = (selected_files.size > 0) ? selected_files[0] : "";
		*/
		
		Gtk.FileChooserDialog chooser = null;

		if (select_files){
			chooser = new Gtk.FileChooserDialog((window_title.length > 0) ? window_title : _("Select File(s)"), parent_window, Gtk.FileChooserAction.OPEN,
					"gtk-cancel", Gtk.ResponseType.CANCEL, "gtk-open", Gtk.ResponseType.ACCEPT);
		}
		else{
			chooser = new Gtk.FileChooserDialog((window_title.length > 0) ? window_title : _("Select Folder(s)"), parent_window, Gtk.FileChooserAction.SELECT_FOLDER,
					"gtk-cancel", Gtk.ResponseType.CANCEL, "gtk-open", Gtk.ResponseType.ACCEPT);
		}

		chooser.local_only = true;
 		chooser.set_modal (true);
 		chooser.set_select_multiple (select_multiple);

 		if (default_path.length > 0){
			chooser.set_current_folder(default_path);
		}

		if (filters != null){
			foreach(var filter in filters){
				chooser.add_filter(filter);
			}
			if (default_filter != null){
				chooser.filter = default_filter;
			}
		}

		var list = new Gee.ArrayList<string>();
		
 		if (chooser.run() == Gtk.ResponseType.ACCEPT){
			//get file list
			foreach (string item_path in chooser.get_filenames()){
				list.add(item_path);
			}
	 	}

		chooser.close();
		//dlg.destroy();
		gtk_do_events();

		return list;
	}
	
		
	public Gtk.FileFilter create_file_filter(string group_name, string[] patterns) {
		var filter = new Gtk.FileFilter ();
		filter.set_filter_name(group_name);
		foreach(string pattern in patterns) {
			filter.add_pattern (pattern);
		}
		return filter;
	}

	// utility ------------------

	// add_notebook
	private Gtk.Notebook add_notebook(
		Gtk.Box box, bool show_tabs = true, bool show_border = true){
			
        // notebook
		var book = new Gtk.Notebook();
		book.margin = 0;
		book.show_tabs = show_tabs;
		book.show_border = show_border;
		
		box.pack_start(book, true, true, 0);
		
		return book;
	}

	// add_tab
	private Gtk.Box add_tab(
		Gtk.Notebook book, string title, int margin = 12, int spacing = 6){
			
		// label
		var label = new Gtk.Label(title);

        // vbox
        var vbox = new Gtk.Box(Gtk.Orientation.VERTICAL, spacing);
        vbox.margin = margin;
        book.append_page (vbox, label);

        return vbox;
	}

	// add_treeview
	private Gtk.TreeView add_treeview(Gtk.Box box,
		Gtk.SelectionMode selection_mode = Gtk.SelectionMode.SINGLE){
			
		// TreeView
		var treeview = new Gtk.TreeView();
		treeview.get_selection().mode = selection_mode;
		treeview.set_rules_hint (true);
		treeview.show_expanders = true;
		treeview.enable_tree_lines = true;

		// ScrolledWindow
		var scrollwin = new Gtk.ScrolledWindow(null, null);
		scrollwin.set_shadow_type (ShadowType.ETCHED_IN);
		scrollwin.add (treeview);
		scrollwin.expand = true;
		box.add(scrollwin);

		return treeview;
	}

	// add_column_text
	private Gtk.TreeViewColumn add_column_text(
		Gtk.TreeView treeview, string title, out Gtk.CellRendererText cell){
			
		// TreeViewColumn
		var col = new Gtk.TreeViewColumn();
		col.title = title;
		
		cell = new Gtk.CellRendererText();
		cell.xalign = 0.0f;
		col.pack_start (cell, false);
		treeview.append_column(col);
		
		return col;
	}


	// add_column_icon
	private Gtk.TreeViewColumn add_column_icon(
		Gtk.TreeView treeview, string title, out Gtk.CellRendererPixbuf cell){
		
		// TreeViewColumn
		var col = new Gtk.TreeViewColumn();
		col.title = title;
		
		cell = new Gtk.CellRendererPixbuf();
		cell.xpad = 2;
		col.pack_start (cell, false);
		treeview.append_column(col);

		return col;
	}

	// add_column_icon_and_text
	private Gtk.TreeViewColumn add_column_icon_and_text(
		Gtk.TreeView treeview, string title,
		out Gtk.CellRendererPixbuf cell_pix, out Gtk.CellRendererText cell_text){
			
		// TreeViewColumn
		var col = new Gtk.TreeViewColumn();
		col.title = title;

		cell_pix = new Gtk.CellRendererPixbuf();
		cell_pix.xpad = 2;
		col.pack_start (cell_pix, false);
		
		cell_text = new Gtk.CellRendererText();
		cell_text.xalign = 0.0f;
		col.pack_start (cell_text, false);
		treeview.append_column(col);

		return col;
	}

	// add_column_radio_and_text
	private Gtk.TreeViewColumn add_column_radio_and_text(
		Gtk.TreeView treeview, string title,
		out Gtk.CellRendererToggle cell_radio, out Gtk.CellRendererText cell_text){
			
		// TreeViewColumn
		var col = new Gtk.TreeViewColumn();
		col.title = title;

		cell_radio = new Gtk.CellRendererToggle();
		cell_radio.xpad = 2;
		cell_radio.radio = true;
		cell_radio.activatable = true;
		col.pack_start (cell_radio, false);
		
		cell_text = new Gtk.CellRendererText();
		cell_text.xalign = 0.0f;
		col.pack_start (cell_text, false);
		treeview.append_column(col);

		return col;
	}

	// add_column_icon_radio_text
	private Gtk.TreeViewColumn add_column_icon_radio_text(
		Gtk.TreeView treeview, string title,
		out Gtk.CellRendererPixbuf cell_pix,
		out Gtk.CellRendererToggle cell_radio,
		out Gtk.CellRendererText cell_text){
			
		// TreeViewColumn
		var col = new Gtk.TreeViewColumn();
		col.title = title;

		cell_pix = new Gtk.CellRendererPixbuf();
		cell_pix.xpad = 2;
		col.pack_start (cell_pix, false);

		cell_radio = new Gtk.CellRendererToggle();
		cell_radio.xpad = 2;
		cell_radio.radio = true;
		cell_radio.activatable = true;
		col.pack_start (cell_radio, false);
		
		cell_text = new Gtk.CellRendererText();
		cell_text.xalign = 0.0f;
		col.pack_start (cell_text, false);
		treeview.append_column(col);

		return col;
	}

	// add_label_scrolled
	private Gtk.Label add_label_scrolled(
		Gtk.Box box, string text,
		bool show_border = false, bool wrap = false, int ellipsize_chars = 40){

		// ScrolledWindow
		var scroll = new Gtk.ScrolledWindow(null, null);
		scroll.hscrollbar_policy = PolicyType.NEVER;
		scroll.vscrollbar_policy = PolicyType.ALWAYS;
		scroll.expand = true;
		box.add(scroll);
		
		var label = new Gtk.Label(text);
		label.xalign = 0.0f;
		label.yalign = 0.0f;
		label.margin = 6;
		label.set_use_markup(true);
		scroll.add(label);

		if (wrap){
			label.wrap = true;
			label.wrap_mode = Pango.WrapMode.WORD;
		}
		else {
			label.wrap = false;
			label.ellipsize = Pango.EllipsizeMode.MIDDLE;
			label.max_width_chars = ellipsize_chars;
		}

		if (show_border){
			scroll.set_shadow_type (ShadowType.ETCHED_IN);
		}
		else{
			label.margin_left = 0;
		}
		
		return label;
	}

	// add_text_view
	private Gtk.TextView add_text_view(
		Gtk.Box box, string text){

		// ScrolledWindow
		var scrolled = new Gtk.ScrolledWindow(null, null);
		scrolled.hscrollbar_policy = PolicyType.NEVER;
		scrolled.vscrollbar_policy = PolicyType.ALWAYS;
		scrolled.expand = true;
		box.add(scrolled);
		
		var view = new Gtk.TextView();
		view.wrap_mode = Gtk.WrapMode.WORD_CHAR;
		view.accepts_tab = false;
		view.editable = false;
		view.cursor_visible = false;
		view.buffer.text = text;
		view.sensitive = false;
		scrolled.add (view);

		return view;
	}
		
	// add_label
	private Gtk.Label add_label(
		Gtk.Box box, string text, bool bold = false,
		bool italic = false, bool large = false){
			
		string msg = "<span%s%s%s>%s</span>".printf(
			(bold ? " weight=\"bold\"" : ""),
			(italic ? " style=\"italic\"" : ""),
			(large ? " size=\"x-large\"" : ""),
			text);
			
		var label = new Gtk.Label(msg);
		label.set_use_markup(true);
		label.xalign = 0.0f;
		label.wrap = true;
		label.wrap_mode = Pango.WrapMode.WORD;
		box.add(label);
		return label;
	}

	private string format_text(
		string text,
		bool bold = false, bool italic = false, bool large = false){
			
		string msg = "<span%s%s%s>%s</span>".printf(
			(bold ? " weight=\"bold\"" : ""),
			(italic ? " style=\"italic\"" : ""),
			(large ? " size=\"x-large\"" : ""),
			escape_html(text));
			
		return msg;
	}

	// add_label_header
	private Gtk.Label add_label_header(
		Gtk.Box box, string text, bool large_heading = false){
		
		var label = add_label(box, escape_html(text), true, false, large_heading);
		label.margin_bottom = 12;
		return label;
	}

	// add_label_subnote
	private Gtk.Label add_label_subnote(
		Gtk.Box box, string text){
		
		var label = add_label(box, text, false, true);
		label.margin_left = 6;
		return label;
	}

	// add_radio
	private Gtk.RadioButton add_radio(
		Gtk.Box box, string text, Gtk.RadioButton? another_radio_in_group){

		Gtk.RadioButton radio = null;

		if (another_radio_in_group == null){
			radio = new Gtk.RadioButton(null);
		}
		else{
			radio = new Gtk.RadioButton.from_widget(another_radio_in_group);
		}

		radio.label = text;
		
		box.add(radio);

		foreach(var child in radio.get_children()){
			if (child is Gtk.Label){
				var label = (Gtk.Label) child;
				label.use_markup = true;
				break;
			}
		}
		
		return radio;
	}

	// add_checkbox
	private Gtk.CheckButton add_checkbox(
		Gtk.Box box, string text){

		var chk = new Gtk.CheckButton.with_label(text);
		chk.label = text;
		box.add(chk);

		foreach(var child in chk.get_children()){
			if (child is Gtk.Label){
				var label = (Gtk.Label) child;
				label.use_markup = true;
				break;
			}
		}
		
		/*
		chk.toggled.connect(()=>{
			chk.active;
		});
		*/

		return chk;
	}

	// add_spin
	private Gtk.SpinButton add_spin(
		Gtk.Box box, double min, double max, double val,
		int digits = 0, double step = 1, double step_page = 1){

		var adj = new Gtk.Adjustment(val, min, max, step, step_page, 0);
		var spin  = new Gtk.SpinButton(adj, step, digits);
		spin.xalign = 0.5f;
		box.add(spin);

		/*
		spin.value_changed.connect(()=>{
			label.sensitive = spin.sensitive;
		});
		*/

		return spin;
	}

	// add_button
	private Gtk.Button add_button(
		Gtk.Box box, string text, string tooltip,
		ref Gtk.SizeGroup? size_group,
		Gtk.Image? icon = null){
			
		var button = new Gtk.Button();
        box.add(button);

        button.set_label(text);
        button.set_tooltip_text(tooltip);

        if (icon != null){
			button.set_image(icon);
			button.set_always_show_image(true);
		}

		if (size_group == null){
			size_group = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);
		}
		
		size_group.add_widget(button);
		
        return button;
	}

	// add_toggle_button
	private Gtk.ToggleButton add_toggle_button(
		Gtk.Box box, string text, string tooltip,
		ref Gtk.SizeGroup? size_group,
		Gtk.Image? icon = null){
			
		var button = new Gtk.ToggleButton();
        box.add(button);

        button.set_label(text);
        button.set_tooltip_text(tooltip);

        if (icon != null){
			button.set_image(icon);
			button.set_always_show_image(true);
		}

		if (size_group == null){
			size_group = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);
		}
		
		size_group.add_widget(button);
		
        return button;
	}
	
	// add_directory_chooser
	private Gtk.Entry add_directory_chooser(
		Gtk.Box box, string selected_directory, Gtk.Window parent_window){
			
		// Entry
		var entry = new Gtk.Entry();
		entry.hexpand = true;
		//entry.margin_left = 6;
		entry.secondary_icon_stock = "gtk-open";
		entry.placeholder_text = _("Enter path or browse for directory");
		box.add (entry);

		if ((selected_directory != null) && dir_exists(selected_directory)){
			entry.text = selected_directory;
		}

		entry.icon_release.connect((p0, p1) => {
			//chooser
			var chooser = new Gtk.FileChooserDialog(
			    _("Select Path"),
			    parent_window,
			    FileChooserAction.SELECT_FOLDER,
			    "_Cancel",
			    Gtk.ResponseType.CANCEL,
			    "_Open",
			    Gtk.ResponseType.ACCEPT
			);

			chooser.select_multiple = false;
			chooser.set_filename(selected_directory);

			if (chooser.run() == Gtk.ResponseType.ACCEPT) {
				entry.text = chooser.get_filename();

				//App.repo = new SnapshotRepo.from_path(entry.text, this);
				//check_backup_location();
			}

			chooser.destroy();
		});

		return entry;
	}


}

