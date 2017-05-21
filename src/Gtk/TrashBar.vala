/*
 * TrashBar.vala
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

public class TrashBar : Gtk.Box {

	private FileViewPane pane;
	private FileViewList view;
	private MainWindow window;
	private Gtk.Label lbl_status;

	public TrashBar(FileViewPane? parent_pane){
		//base(Gtk.Orientation.VERTICAL, 6); // issue with vala
		Object(orientation: Gtk.Orientation.HORIZONTAL, spacing: 6); // work-around
		margin = 3;

		log_debug("TrashBar()");

		pane = parent_pane;
		view = parent_pane.view;
		window = App.main_window;

		init_ui();

		gtk_hide(this);
	}

	private void init_ui(){

		var label = new Label("");
		label.xalign = 0.5f;
		label.hexpand = true;
		label.margin = 6;
		add(label);
		lbl_status = label;

		string css = " background-color: #3F51B5; ";
		gtk_apply_css(new Gtk.Widget[] { this }, css);

		css = " color: #ffffff; ";
		gtk_apply_css(new Gtk.Widget[] { label }, css);

		add_delete_button();

		add_restore_button();

		add_empty_button();
	}

	private void add_delete_button(){

		var ebox = gtk_add_event_box(this);

		var text = _("Delete");
		var label = new Gtk.Label(text);
		label.set_use_markup(true);
		label.margin = 6;
		label.set_tooltip_text(_("Delete selected items permanently"));
		ebox.add(label);

		var css = " color: #ffffff; ";
		gtk_apply_css(new Gtk.Widget[] { label }, css);

		ebox.button_press_event.connect((event) => {
			gtk_set_busy(true, window);

			view.delete_items();

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

	private void add_restore_button(){

		var ebox = gtk_add_event_box(this);

		var text = _("Restore");
		var label = new Gtk.Label(text);
		label.set_use_markup(true);
		label.margin = 6;
		label.set_tooltip_text(_("Restore selected items to original locations"));
		ebox.add(label);

		var css = " color: #ffffff; ";
		gtk_apply_css(new Gtk.Widget[] { label }, css);

		ebox.button_press_event.connect((event) => {
			gtk_set_busy(true, window);

			view.restore_items();

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

	private void add_empty_button(){

		var ebox = gtk_add_event_box(this);

		var text = _("Empty Trash");
		var label = new Gtk.Label(text);
		label.set_use_markup(true);
		label.margin = 6;
		label.margin_right = 12;
		label.set_tooltip_text(_("Empty trash can"));
		ebox.add(label);

		var css = " color: #ffffff; ";
		gtk_apply_css(new Gtk.Widget[] { label }, css);

		ebox.button_press_event.connect((event) => {
			gtk_set_busy(true, window);

			view.delete_items(true);

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

		log_debug("TrashBar: refresh()");

		if ((view.current_item != null) && (view.current_item.is_trash)){
			gtk_show(this);

			lbl_status.label = "%s's Trash: %d items, %s".printf(
				App.user_name_effective, App.trashcan.children.values.size, App.trashcan.size_formatted);
		}
		else{
			gtk_hide(this);
		}
	}
}

