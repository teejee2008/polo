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

	private FileViewPane pane;
	private FileViewList view;
	private MainWindow window;

	public MediaBar(FileViewPane parent_pane){
		//base(Gtk.Orientation.VERTICAL, 6); // issue with vala
		Object(orientation: Gtk.Orientation.HORIZONTAL, spacing: 6); // work-around
		margin = 3;

		log_debug("MediaBar()");

		pane = parent_pane;
		view = parent_pane.view;
		window = App.main_window;

		init_ui();

		gtk_hide(this);
	}

	private void init_ui(){

		var label = new Gtk.Label(_("Switch to media browser view?"));
		label.xalign = 0.5f;
		label.hexpand = true;
		label.margin = 6;
		add(label);

		string css = " background-color: #2196F3; ";
		gtk_apply_css(new Gtk.Widget[] { this }, css);

		css = " color: #ffffff; ";
		gtk_apply_css(new Gtk.Widget[] { label }, css);

		add_include_button();

		add_exclude_button();

		//add_exit_button();
	}

	private void add_include_button(){

		var ebox = gtk_add_event_box(this);

		var text = _("Yes");
		var label = new Gtk.Label(text);
		//link.ellipsize = Pango.EllipsizeMode.MIDDLE;
		label.set_use_markup(true);
		label.margin = 6;
		//label.margin_right = 12;
		label.set_tooltip_text(_("Switch to media browser view mode"));
		ebox.add(label);

		var css = " color: #ffffff; ";
		gtk_apply_css(new Gtk.Widget[] { label }, css);

		ebox.button_press_event.connect((event) => {
			gtk_set_busy(true, window);
			gtk_do_events();

			string path = view.current_item.file_path;

			App.mediaview_include.add(path);

			if (App.mediaview_exclude.contains(path)){
				App.mediaview_exclude.remove(path);
			}

			App.save_folder_selections();

			view.set_view_mode(ViewMode.MEDIA, false);

			refresh();

			gtk_set_busy(false, window);
			////ebox.get_window().set_cursor(null);
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

	private void add_exclude_button(){

		var ebox = gtk_add_event_box(this);

		var text = _("No");
		var label = new Gtk.Label(text);
		//link.ellipsize = Pango.EllipsizeMode.MIDDLE;
		label.set_use_markup(true);
		label.margin = 6;
		label.margin_right = 12;
		label.set_tooltip_text(_("Stay in current view"));
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

			refresh();

			gtk_set_busy(false, window);
			////ebox.get_window().set_cursor(null);
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

		//log_debug("MediaBar: view.has_media(): %s".printf(view.has_media.to_string()));
		//log_debug("MediaBar: mediaview_included(): %s".printf(view.mediaview_included.to_string()));
		//log_debug("MediaBar: mediaview_excluded(): %s".printf(view.mediaview_excluded.to_string()));
		//log_debug("MediaBar: refresh(): %s".printf(view.has_media.to_string()));

		if (view.has_media && (view.get_view_mode() != ViewMode.MEDIA)
			&& !view.mediaview_include && !view.mediaview_exclude
			&& !view.current_item.is_trash && !view.current_item.is_archive && !view.current_item.is_archived_item){

			gtk_show(this);
		}
		else{
			gtk_hide(this);
		}
	}

}

