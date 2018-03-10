/*
 * TouchFileDateContextMenu.vala
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

public class TouchFileDateContextMenu : Gtk.Menu {

	private FileItem file_item;
	private bool touch_modified;
	private bool touch_accessed;
	private Gtk.Window window;
	private Gtk.Entry entry;
	private bool task_is_running;

	private bool recurse;
	private bool follow_links;

	public signal void file_touched();

	public TouchFileDateContextMenu(FileItem _file_item, bool _touch_accessed, bool _touch_modified, Gtk.Window _window, Gtk.Entry _entry){

		//log_debug("TouchFileDateContextMenu()");

		file_item = _file_item;
		touch_modified = _touch_modified;
		touch_accessed = _touch_accessed;

		window = _window;

		entry = _entry;

		reserve_toggle_size = false;
		
		add_item_touch();

		add_item_touch_recursive();

		add_item_touch_recursive_follow_links();

		this.show_all();

		//log_debug("TouchFileDateContextMenu(): exit");
	}

	public void add_item_touch(){

		string tt = "%s.".printf(
				_("Update timestamp to current date and time")
			);
			
		var item = gtk_menu_add_item(
			this,
			_("Touch"),
			tt,
			null,
			null,
			null);

		item.activate.connect(()=>{
			touch_file_item(false, false);
		});

		item.sensitive = true;
	}

	public void add_item_touch_recursive(){

		string tt = "%s. %s.".printf(
				_("Update timestamp to current date and time"),
				_("Update recursively for all items inside the folder")
			);
				
		var item = gtk_menu_add_item(
			this,
			_("Touch Recursive"),
			tt,
			null,
			null,
			null);

		item.activate.connect(()=>{
			touch_file_item(true, false);
		});

		item.sensitive = file_item.is_directory;
	}

	public void add_item_touch_recursive_follow_links(){

		string tt = "%s\n + %s\n + %s.".printf(
				_("Update timestamp to current date and time"),
				_("Update recursively for all items inside the folder"),
				_("Follow into symlinked subfolders")
			);
			
		var item = gtk_menu_add_item(
			this,
			_("Touch Recursive (Follow Symlinks)"),
			tt,
			null,
			null,
			null);

		item.activate.connect(()=>{
			touch_file_item(true, true);
		});

		item.sensitive = file_item.is_directory;
	}

	private void touch_file_item(bool _recurse, bool _follow_links){

		recurse = _recurse;
		follow_links = _follow_links;
		
		try {
			task_is_running = true;
			Thread.create<void> (touch_file_item_thread, true);
		}
		catch (Error e) {
			log_error("TouchFileDateContextMenu: touch_file_item_thread()");
			task_is_running = false;
			log_error (e.message);
		}

		while (task_is_running){
			sleep(200);
			entry.progress_pulse();
			gtk_do_events();
		}
		
		entry.set_progress_fraction(0.0);
		gtk_do_events();
	}

	private void touch_file_item_thread(){
		
		task_is_running = true;

		entry.progress_pulse_step = 0.2;

		touch(file_item.file_path, touch_accessed, touch_modified, recurse, follow_links, window);
		file_item.query_file_info();
		file_touched();
		
		task_is_running = false;
	}

	//private bool check_task_is_running(){
	//	return task_is_running;
	//}

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


