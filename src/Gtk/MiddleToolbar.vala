/*
 * MiddleToolbar.vala
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

public class MiddleToolbar : Gtk.Toolbar, IPaneActive {

	private int icon_size_actual = 16;
	//private Gtk.Menu menu_history;
	//private Gtk.Menu menu_disk;     
	//private Gtk.Menu menu_bookmark;
	//private Gtk.Menu menu_layout; 
	public bool is_global = true;

	private Gtk.ToolButton btn_cut;
	private Gtk.ToolButton btn_copy;
	private Gtk.ToolButton btn_paste;
	private Gtk.ToolButton btn_move_across;
	private Gtk.ToolButton btn_copy_across;
	private Gtk.ToolButton btn_props;
	private Gtk.ToolButton btn_new_file;
	private Gtk.ToolButton btn_new_folder;
	private Gtk.ToolButton btn_open_terminal;
	private Gtk.ToolButton btn_rename;
	private Gtk.ToolButton btn_trash;
	private Gtk.ToolButton btn_delete;
	private Gtk.ToolButton btn_swap_panels;
	private Gtk.ToolButton btn_open_left;
	private Gtk.ToolButton btn_open_right;
	private Gtk.SeparatorToolItem separator_nav;

	private Gtk.Image img_cut;
	private Gtk.Image img_copy;
	private Gtk.Image img_paste;
	private Gtk.Image img_move_across;
	private Gtk.Image img_copy_across;
	private Gtk.Image img_props;
	private Gtk.Image img_new_file;
	private Gtk.Image img_new_folder;
	private Gtk.Image img_open_terminal;
	private Gtk.Image img_rename;
	private Gtk.Image img_trash;
	private Gtk.Image img_delete;
	private Gtk.Image img_swap_panels;
	private Gtk.Image img_open_left;
	private Gtk.Image img_open_right;
	
	// contruct
	
	public MiddleToolbar(){
		//base(); // issue with vala
		//Object(orientation: Gtk.Orientation.HORIZONTAL, spacing: 0); // work-around

		log_debug("MiddleToolbar()");
		
		this.margin = 0;
		this.margin_top = 48;
		//this.spacing = 0;
		
		//gtk_apply_css({ this }, "border-width: 20px;");

		init_toolbar();

        log_debug("MiddleToolbar():exit");
	}

	private void init_toolbar() {

		this.orientation = Gtk.Orientation.VERTICAL;


		add_toolbar_button_for_copy_across();
		
		add_toolbar_button_for_move_across();

		add_toolbar_separator_nav();

		
		add_toolbar_button_for_cut();

		add_toolbar_button_for_copy();

		add_toolbar_button_for_paste();

		add_toolbar_separator_nav();

		
		add_toolbar_button_for_rename();

		add_toolbar_button_for_trash();

		add_toolbar_button_for_delete();

		add_toolbar_separator_nav();
		


		add_toolbar_button_for_new_file();

		add_toolbar_button_for_new_folder();

		add_toolbar_button_for_terminal();

		add_toolbar_separator_nav();

		
		add_toolbar_button_for_properties();

		add_toolbar_separator_nav();
		

		add_toolbar_button_for_swap_panels();

		add_toolbar_button_for_open_right();

		add_toolbar_button_for_open_left();
	}

	// init toolbar items
	
	private void add_toolbar_button_for_cut(){
		
		var button = new Gtk.ToolButton(null,null);
		button.set_tooltip_text (_("Cut\n\nCut selected items in active pane"));
		button.is_important = true;
		add(button);
		btn_cut = button;

		img_cut = new Gtk.Image();
		button.set_icon_widget(img_cut);
		
		gtk_apply_css({ button }, "padding-left: 0px; padding-right: 0px;");
		
		button.clicked.connect(() => {
			if (view == null) { return; };
			view.cut();
		});
	}
	
	private void add_toolbar_button_for_copy(){
		
		var button = new Gtk.ToolButton(null,null);
		button.set_tooltip_text (_("Copy\n\nCopy selected items in active pane"));
		button.is_important = true;
		add(button);
		btn_copy = button;

		img_copy = new Gtk.Image();
		button.set_icon_widget(img_copy);
		
		gtk_apply_css({ button }, "padding-left: 0px; padding-right: 0px;");
		
		button.clicked.connect(() => {
			if (view == null) { return; };
			view.copy();
		});
	}
	
	private void add_toolbar_button_for_paste(){
		
		var button = new Gtk.ToolButton(null,null);
		button.set_tooltip_text (_("Paste\n\nPaste items in active pane"));
		button.is_important = true;
		add(button);
		btn_paste = button;

		img_paste = new Gtk.Image();
		button.set_icon_widget(img_paste);
		
		gtk_apply_css({ button }, "padding-left: 0px; padding-right: 0px;");
		
		button.clicked.connect(() => {
			if (view == null) { return; };
			view.paste();
		});
	}

	private void add_toolbar_button_for_rename(){
		
		var button = new Gtk.ToolButton(null,null);
		button.set_tooltip_text (_("Rename selected item"));
		button.is_important = true;
		add(button);
		btn_rename = button;

		img_rename = new Gtk.Image();
		button.set_icon_widget(img_rename);
		
		gtk_apply_css({ button }, "padding-left: 0px; padding-right: 0px;");
		
		button.clicked.connect(() => {
			if (view == null) { return; };
			view.rename();
		});
	}


	private void add_toolbar_button_for_trash(){
		
		var button = new Gtk.ToolButton(null,null);
		button.set_tooltip_text (_("Trash\n\nMove selected items to recycle bin"));
		button.is_important = true;
		add(button);
		btn_trash = button;

		img_trash = new Gtk.Image();
		button.set_icon_widget(img_trash);
		
		gtk_apply_css({ button }, "padding-left: 0px; padding-right: 0px;");
		
		button.clicked.connect(() => {
			if (view == null) { return; };
			view.trash();
		});
	}


	private void add_toolbar_button_for_delete(){
		
		var button = new Gtk.ToolButton(null,null);
		button.set_tooltip_text (_("Delete\n\nDelete selected items permanently (without sending to recycle bin)"));
		button.is_important = true;
		add(button);
		btn_delete = button;

		img_delete = new Gtk.Image();
		button.set_icon_widget(img_delete);
		
		gtk_apply_css({ button }, "padding-left: 0px; padding-right: 0px;");
		
		button.clicked.connect(() => {
			if (view == null) { return; };
			view.delete_items();
		});
	}


	private void add_toolbar_button_for_move_across(){
		
		var button = new Gtk.ToolButton(null,null);
		button.set_tooltip_text (_("Move Across\n\nMove selected items in active pane to opposite pane"));
		button.is_important = true;
		add(button);
		btn_move_across = button;

		img_move_across = new Gtk.Image();
		button.set_icon_widget(img_move_across);
		
		gtk_apply_css({ button }, "padding-left: 0px; padding-right: 0px;");
		
		button.clicked.connect(() => {
			if (view == null) { return; };
			view.move_across();
		});
	}
	
	private void add_toolbar_button_for_copy_across(){
		
		var button = new Gtk.ToolButton(null,null);
		button.set_tooltip_text (_("Copy Across\n\nCopy selected items in active pane to opposite pane"));
		button.is_important = true;
		add(button);
		btn_copy_across = button;

		img_copy_across = new Gtk.Image();
		button.set_icon_widget(img_copy_across);
		
		gtk_apply_css({ button }, "padding-left: 0px; padding-right: 0px;");
		
		button.clicked.connect(() => {
			if (view == null) { return; };
			view.copy_across();
		});
	}

	private void add_toolbar_button_for_properties(){
		
		var button = new Gtk.ToolButton(null,null);
		button.set_tooltip_text (_("Properties"));
		button.is_important = true;
		add(button);
		btn_props = button;

		img_props = new Gtk.Image();
		button.set_icon_widget(img_props);
		
		gtk_apply_css({ button }, "padding-left: 0px; padding-right: 0px;");
		
		button.clicked.connect(() => {
			if (view == null) { return; };
			view.show_properties();
		});
	}

	private void add_toolbar_button_for_new_file(){
		
		var button = new Gtk.ToolButton(null,null);
		button.set_tooltip_text (_("Create New File"));
		button.is_important = true;
		add(button);
		btn_new_file = button;

		img_new_file = new Gtk.Image();
		button.set_icon_widget(img_new_file);
		
		gtk_apply_css({ button }, "padding-left: 0px; padding-right: 0px;");
		
		button.clicked.connect(() => {
			if (view == null) { return; };
			view.create_file();
		});
	}

	private void add_toolbar_button_for_new_folder(){
		
		var button = new Gtk.ToolButton(null,null);
		button.set_tooltip_text (_("Create New Folder"));
		button.is_important = true;
		add(button);
		btn_new_folder = button;

		img_new_folder = new Gtk.Image();
		button.set_icon_widget(img_new_folder);
		
		gtk_apply_css({ button }, "padding-left: 0px; padding-right: 0px;");
		
		button.clicked.connect(() => {
			if (view == null) { return; };
			view.create_directory();
		});
	}

	private void add_toolbar_button_for_terminal(){
		
		var button = new Gtk.ToolButton(null,null);
		button.set_tooltip_text (_("Toggle terminal panel"));
		button.is_important = true;
		add(button);
		btn_open_terminal = button;

		img_open_terminal = new Gtk.Image();
		button.set_icon_widget(img_open_terminal);
		
		gtk_apply_css({ button }, "padding-left: 0px; padding-right: 0px;");
		
		button.clicked.connect(() => {
			if (pane == null) { return; };
			pane.terminal.toggle();
		});
	}
	
	private void add_toolbar_separator_nav(){
		separator_nav = new Gtk.SeparatorToolItem();
		add(separator_nav);
		gtk_apply_css({ separator_nav }, " padding-left: 0px; padding-right: 0px; ");
	}

	private void add_toolbar_button_for_swap_panels(){
		
		var button = new Gtk.ToolButton(null,null);
		button.set_tooltip_text (_("Swap directory path with opposite pane"));
		button.is_important = true;
		add(button);
		btn_swap_panels = button;

		img_swap_panels = new Gtk.Image();
		button.set_icon_widget(img_swap_panels);
		
		gtk_apply_css({ button }, "padding-left: 0px; padding-right: 0px;");
		
		button.clicked.connect(() => {
			if (view == null) { return; };
			view.swap_location_with_opposite_pane();
		});
	}


	private void add_toolbar_button_for_open_left(){
		
		var button = new Gtk.ToolButton(null,null);
		button.set_tooltip_text (_("Open right-pane location in left pane"));
		button.is_important = true;
		add(button);
		btn_open_left = button;

		img_open_left = new Gtk.Image();
		button.set_icon_widget(img_open_left);
		
		gtk_apply_css({ button }, "padding-left: 0px; padding-right: 0px;");
		
		button.clicked.connect(() => {
			if (view == null) { return; }
			window.layout_box.open_panel2_location_in_panel1();
		});
	}


	private void add_toolbar_button_for_open_right(){
		
		var button = new Gtk.ToolButton(null,null);
		button.set_tooltip_text (_("Open left-pane location in right pane"));
		button.is_important = true;
		add(button);
		btn_open_right = button;

		img_open_right = new Gtk.Image();
		button.set_icon_widget(img_open_right);
		
		gtk_apply_css({ button }, "padding-left: 0px; padding-right: 0px;");
		
		button.clicked.connect(() => {
			if (view == null) { return; }
			window.layout_box.open_panel1_location_in_panel2();
		});
	}
	
	// refresh
	
	public void refresh(){

		//refresh_visibility();

		if (!App.middlebar_visible){
			return;
		}

		log_debug("MiddleToolbar: refresh()");
		
		refresh_items();

		refresh_icons();

		refresh_style();

		show_all();
	}

	public void refresh_visibility(){
		
		if (App.middlebar_visible && (window.layout_box.get_panel_layout() == PanelLayout.DUAL_VERTICAL)){
			middlebar_show();
		}
		else{
			middlebar_hide();
		}
	}
	
	public void middlebar_show(){

		log_debug("middlebar_show");
		
		App.middlebar_visible = true;

		this.set_no_show_all(false);
		
		refresh(); // calls show_all()
	}

	public void middlebar_hide(){

		log_debug("middlebar_hide");
		
		App.middlebar_visible = false;

		this.set_no_show_all(true);
		this.hide();
	}

	public void refresh_items(){
		
	}

	public void refresh_icons(){

		icon_size_actual = 16;

		img_cut.pixbuf = IconManager.lookup("edit-cut-symbolic", icon_size_actual);
		img_copy.pixbuf = IconManager.lookup("edit-copy-symbolic", icon_size_actual);
		img_paste.pixbuf = IconManager.lookup("edit-paste-symbolic", icon_size_actual);

		img_rename.pixbuf = IconManager.lookup("edit-rename", icon_size_actual);
		img_trash.pixbuf = IconManager.lookup("user-trash-symbolic", icon_size_actual);
		img_delete.pixbuf = IconManager.lookup("edit-delete-symbolic", icon_size_actual);
		
		img_move_across.pixbuf = IconManager.lookup("folder-move", icon_size_actual);
		img_copy_across.pixbuf = IconManager.lookup("folder-copy", icon_size_actual);

		img_new_file.pixbuf = IconManager.lookup("document-new", icon_size_actual);
		img_new_folder.pixbuf = IconManager.lookup("folder-new", icon_size_actual);
		img_open_terminal.pixbuf = IconManager.lookup("terminal-symbolic", icon_size_actual);

		img_props.pixbuf = IconManager.lookup("document-properties", icon_size_actual);

		img_swap_panels.pixbuf = IconManager.lookup("switch", icon_size_actual);
		img_open_left.pixbuf = IconManager.lookup("go-previous-symbolic", icon_size_actual);
		img_open_right.pixbuf = IconManager.lookup("go-next-symbolic", icon_size_actual);
	}
	
	public void refresh_style(){

		this.icon_size_set = true;
		this.icon_size = Gtk.IconSize.MENU;

		this.get_style_context().remove_class(Gtk.STYLE_CLASS_PRIMARY_TOOLBAR);

		this.set_style(ToolbarStyle.ICONS);
	}

	public void refresh_for_active_pane(){

		log_debug("MiddleToolbar: refresh_for_active_pane");

		if (!window.window_is_ready){ return; }
		
		if ((view == null) || (view.current_item == null)){
			this.sensitive = false;
			return;
		}
		else{
			this.sensitive = true;
		}

		//var list = view.get_selected_items();

		btn_cut.sensitive = view.can_cut;
		btn_copy.sensitive =  view.can_copy;
		btn_paste.sensitive = view.can_paste;
		btn_copy_across.sensitive = view.can_copy;
		btn_move_across.sensitive = view.can_cut;

		btn_delete.sensitive = view.can_delete;
		
		btn_rename.sensitive = view.can_rename;
		btn_trash.sensitive = view.can_trash;
		btn_new_file.sensitive = view.is_normal_directory;
		btn_new_folder.sensitive = view.is_normal_directory;
		btn_open_terminal.sensitive = view.is_normal_directory;

		//btn_open_terminal.sensitive = !view.current_item.is_trash;

		//btn_cut.sensitive = (list.size > 0) && (list[0].can_delete);
		//btn_cut.sensitive = (list.size > 0) && (list[0].can_delete);
		//btn_cut.sensitive = (list.size > 0) && (list[0].can_delete);
	}
	
	public void set_icon_size_actual(int _icon_size){
		//if ((_icon_size >= 16) && (_icon_size <= 64)){
		//	icon_size_actual = _icon_size;
			//refresh();
		//}
	}

	public int get_icon_size_actual(){
		return icon_size_actual;
	}
}
