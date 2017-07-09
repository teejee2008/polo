/*
 * FileViewPane.vala
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

public class FileViewPane : Gtk.Box {

	//public FileViewToolbar toolbar;
	public Pathbar pathbar;
	public FileViewList view;
	public MediaBar mediabar;
	public SelectionBar selection_bar;
	public AdminBar adminbar;
	public TrashBar trashbar;
	public Gtk.Box file_operations_box;
	public TermBox terminal;
	public Statusbar statusbar;

	private Gtk.Box box_pathbar_view;
	private Gtk.Paned paned_term;
	
	public Gee.ArrayList<ProgressPanel> file_operations = new Gee.ArrayList<ProgressPanel>();

	// parents
	public FileViewTab tab;
	public LayoutPanel panel;
	public MainWindow window;

	public FileViewPane(FileViewTab parent_tab){
		//base(Gtk.Orientation.VERTICAL, 6); // issue with vala
		Object(orientation: Gtk.Orientation.VERTICAL, spacing: 0); // work-around

		margin = 0;

		log_debug("FileViewPane() ----------------------------------");

		tab = parent_tab;
		panel = tab.panel;
		window = App.main_window;

		var timer = timer_start();

		view = new FileViewList(this);

		log_trace("FileViewList created: %s".printf(timer_elapsed_string(timer)));
		timer_restart(timer);

		//toolbar = new FileViewToolbar(this, false);

		//log_trace("FileViewToolbar created: %s".printf(timer_elapsed_string(timer)));
		//timer_restart(timer);

		pathbar = new Pathbar(this);

		log_trace("Pathbar created: %s".printf(timer_elapsed_string(timer)));
		timer_restart(timer);

		selection_bar = new SelectionBar(this);
		
		mediabar = new MediaBar(this);

		adminbar = new AdminBar(this);

		trashbar = new TrashBar(this);

		//settings = new Settings(this, false);

		log_trace("Settings created: %s".printf(timer_elapsed_string(timer)));
		timer_restart(timer);

		terminal = new TermBox(this);

		statusbar = new Statusbar(this);

		log_trace("Statusbar created: %s".printf(timer_elapsed_string(timer)));

		//add(toolbar);

		var box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
		box.add(pathbar);
		box.add(view);
		box_pathbar_view = box;
		
		var paned = new Gtk.Paned (Gtk.Orientation.VERTICAL);
		add(paned);
		paned_term = paned;
		
		paned.pack1(box, true, true); // resize, shrink
		paned.pack2(terminal, true, true); // resize, shrink

		file_operations_box = new Gtk.Box(Orientation.VERTICAL, 6);
		add(file_operations_box);

		add(selection_bar);
		
		add(mediabar);

		add(trashbar);

		add(adminbar);

		add(statusbar);

		view.changed.connect(()=>{

			if (view.current_item != null) {

				if (!tab.renamed){
					if (view.current_item.is_trash){
						tab.tab_name = _("Trash");
					}
					else{
						tab.tab_name = view.current_item.file_name;
					}
				}
			}
			else{
				tab.tab_name = file_basename(view.current_path_saved);
			}

			refresh(false);
		});

		/*statusbar.sidebar_toggled.connect(()=>{
			window.reset_sidebar_width();
			window.sidebar.refresh();
		});*/

		/*view.treeview.enter_notify_event.connect((event) => {
			//log_debug("FileViewPane(): treeview.enter_notify_event");
			if (pathbar.path_edit_mode){
				pathbar.path_edit_mode = false;
				pathbar.refresh();
			}
			//pathbar.menu_bookmark_popdown();
			//pathbar.menu_disk_popdown();
			return false;
		});*/

		//view.changed();

		//refresh();

		log_debug("FileViewPane(): created -------------------------");
	}

	// refresh

	public void refresh(bool refresh_view_required = true){

		log_debug("FileViewPane %d: refresh(): %s".printf(this.panel.number, refresh_view_required.to_string()));

		var timer = timer_start();

		if (refresh_view_required){
			refresh_view();
		}

		refresh_pathbar();

		refresh_headerbar();

		mediabar.refresh();

		trashbar.refresh();

		adminbar.refresh();

		refresh_file_action_panel();

		refresh_terminal();
		
		refresh_statusbar();

		log_trace("Pane %d refreshed: %s".printf(this.panel.number, timer_elapsed_string(timer)));
	}

	public void refresh_view(){
		view.refresh(true);
	}

	public void refresh_pathbar(){
		window.pathbar.refresh();
		pathbar.refresh();
	}
	
	public void refresh_headerbar(){
		window.headerbar.refresh();
	}

	public void refresh_terminal(){
		terminal.refresh();
	}
	
	public void refresh_statusbar(){
		statusbar.refresh();
	}

	public void refresh_file_action_panel(){

		log_debug("FileActionPanel: refresh()");

		file_operations_box.forall ((element) => file_operations_box.remove (element));

		foreach(var actionbar in file_operations){
			file_operations_box.add(actionbar);
		}

		if (file_operations.size > 0){
			file_operations_box.set_no_show_all(false);
			file_operations_box.show_all();
		}
		else{
			file_operations_box.hide();
		}
	}

	public void maximize_terminal(){
		gtk_hide(box_pathbar_view);
	}

	public void unmaximize_terminal(){
		gtk_show(box_pathbar_view);

		int pos_height = paned_term.get_allocated_height();
		int pos_height_half = (int) (pos_height / 2);
		paned_term.set_position(pos_height_half);
	}

	// helpers

	public int tab_index{
		get {
			return panel.notebook.page_num(this);
		}
	}

}

