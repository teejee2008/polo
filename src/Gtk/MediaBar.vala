/*
 * MediaBar.vala
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

public class MediaBar : Gtk.Box {

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

	private Gtk.Label label_folders;
	private Gtk.Label label_other_files;
	
	public MediaBar(FileViewPane parent_pane){
		//base(Gtk.Orientation.VERTICAL, 6); // issue with vala
		Object(orientation: Gtk.Orientation.HORIZONTAL, spacing: 6); // work-around
		margin = 3;

		log_debug("MediaBar()");

		pane = parent_pane;

		init_ui();

		gtk_hide(this);
	}

	private void init_ui(){

		var label = new Gtk.Label(_("Showing photos and videos in Media View"));
		label.xalign = 0.0f;
		label.hexpand = true;
		label.margin = 6;
		add(label);

		string css = " background-color: #2196F3; ";
		gtk_apply_css(new Gtk.Widget[] { this }, css);

		css = " color: #ffffff; font-weight: bold; ";
		gtk_apply_css(new Gtk.Widget[] { label }, css);

		// actions ------------------------------
		
		add_show_other_files_button();

		add_hide_folders_button();
		
		add_ignore_button();

		add_exit_button();
	}

	private void add_show_other_files_button(){

		var ebox = gtk_add_event_box(this);
		var label = new Gtk.Label("");
		label.set_use_markup(true);
		label.margin = 6;
		ebox.add(label);

		label_other_files = label;
		
		var css = " color: #ffffff; ";
		gtk_apply_css(new Gtk.Widget[] { label }, css);

		ebox.button_press_event.connect((event) => {
			
			gtk_set_busy(true, window);
			gtk_do_events();

			view.show_other_files_in_media_view = !view.show_other_files_in_media_view;
			view.refilter();

			refresh();
			
			gtk_set_busy(false, window);
			return false;
		});

		ebox.enter_notify_event.connect((event) => {
			//log_debug("lbl.enter_notify_event()");
			label.label = "<u>%s</u>".printf(label.label);
			return false;
		});

		ebox.leave_notify_event.connect((event) => {
			//log_debug("lbl.leave_notify_event()");
			label.label = "%s".printf(label.label.replace("<u>", "").replace("</u>", ""));
			return false;
		});
	}

	private void add_hide_folders_button(){

		var ebox = gtk_add_event_box(this);
		var label = new Gtk.Label("");
		label.set_use_markup(true);
		label.margin = 6;
		ebox.add(label);

		label_folders = label;

		var css = " color: #ffffff; ";
		gtk_apply_css(new Gtk.Widget[] { label }, css);

		ebox.button_press_event.connect((event) => {
			
			gtk_set_busy(true, window);
			gtk_do_events();

			view.show_folders_in_media_view = !view.show_folders_in_media_view;
			view.refilter();

			refresh();
			
			gtk_set_busy(false, window);
			return false;
		});

		ebox.enter_notify_event.connect((event) => {
			//log_debug("lbl.enter_notify_event()");
			label.label = "<u>%s</u>".printf(label.label);
			return false;
		});

		ebox.leave_notify_event.connect((event) => {
			//log_debug("lbl.leave_notify_event()");
			label.label = "%s".printf(label.label.replace("<u>", "").replace("</u>", ""));
			return false;
		});
	}


	private void add_ignore_button(){

		var ebox = gtk_add_event_box(this);

		var text = _("[Ignore]");
		var label = new Gtk.Label(text);
		label.set_use_markup(true);
		label.margin = 6;
		label.set_tooltip_text(_("Ignore photos and videos in this location and do not switch to Media View automatically."));
		ebox.add(label);

		var css = " color: #ffffff; ";
		gtk_apply_css(new Gtk.Widget[] { label }, css);

		ebox.button_press_event.connect((event) => {
			
			gtk_set_busy(true, window);
			gtk_do_events();

			string path = view.current_item.file_path;

			App.mediaview_exclude.add(path);

			if (App.mediaview_include.contains(path)){
				App.mediaview_include.remove(path);
			}

			App.save_folder_selections();

			view.set_view_mode(ViewMode.MEDIA, false);

			refresh();

			gtk_set_busy(false, window);
			return false;
		});

		ebox.enter_notify_event.connect((event) => {
			//log_debug("lbl.enter_notify_event()");
			label.label = "<u>%s</u>".printf(text);
			return false;
		});

		ebox.leave_notify_event.connect((event) => {
			//log_debug("lbl.leave_notify_event()");
			label.label = "%s".printf(text);
			return false;
		});
	}

	private void add_exit_button(){

		var ebox = gtk_add_event_box(this);

		var text = _("[Exit]");
		var label = new Gtk.Label(text);
		label.set_use_markup(true);
		label.margin = 6;
		label.margin_right = 12;
		label.set_tooltip_text(_("Exit Media View"));
		ebox.add(label);

		var css = " color: #ffffff; ";
		gtk_apply_css(new Gtk.Widget[] { label }, css);

		ebox.button_press_event.connect((event) => {
			
			gtk_set_busy(true, window);
			gtk_do_events();

			view.set_view_mode_user();
			
			refresh();

			gtk_set_busy(false, window);
			return false;
		});

		ebox.enter_notify_event.connect((event) => {
			//log_debug("lbl.enter_notify_event()");
			label.label = "<u>%s</u>".printf(text);
			return false;
		});

		ebox.leave_notify_event.connect((event) => {
			//log_debug("lbl.leave_notify_event()");
			label.label = "%s".printf(text);
			return false;
		});
	}

	public void refresh(){

		log_debug("MediaBar: refresh()");

		if (view.get_view_mode() == ViewMode.MEDIA){

			if (view.show_folders_in_media_view){
				label_folders.label = "[%s]".printf(_("Hide Folders"));
			}
			else{
				label_folders.label = "[%s]".printf(_("Show Folders"));
			}

			if (view.show_other_files_in_media_view){
				label_other_files.label = "[%s]".printf(_("Hide Other Files"));
			}
			else{
				label_other_files.label = "[%s]".printf(_("Show Other Files"));
			}

			gtk_show(this);
		}
		else{
			gtk_hide(this);
		}
	}

}

