/*
 * SettingsWindow.vala
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

public class SettingsWindow : Gtk.Window {

	public SettingsWindow() {

		set_transient_for(App.main_window);
		set_modal(true);
		//set_type_hint(Gdk.WindowTypeHint.DIALOG); // Do not use; Hides close button on some window managers
		set_skip_taskbar_hint(true);
		set_skip_pager_hint(true);
		window_position = WindowPosition.CENTER_ON_PARENT;
		deletable = true;
		resizable = true;
		icon = get_app_icon(16,".svg");
		title = _("Settings");
		
		// get content area
		var vbox_main = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
		vbox_main.set_size_request(400,400);
		add(vbox_main);

		var settings = new Settings(this);
		vbox_main.add(settings);

		this.delete_event.connect(on_delete_event);
		
        show_all();
	}

	private bool on_delete_event(Gdk.EventAny event){

		this.delete_event.disconnect(on_delete_event); //disconnect this handler

		App.save_app_config();
		return false; // close window
	}
}


