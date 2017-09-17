/*
 * LoadingWindow.vala
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

public class LoadingWindow : Gtk.Window {
	
	private Gtk.Box vbox_main;
	private Gtk.Label lbl_msg;

	private string msg_title;
	private string msg_body;
	private bool show_ok;

	public LoadingWindow(Gtk.Window? window, string _msg_title, string _msg_body, bool _show_ok) {
			
		this.set_transient_for(window);
		this.set_modal(true);
		this.set_type_hint(Gdk.WindowTypeHint.SPLASHSCREEN);
		this.set_skip_taskbar_hint(true);
		this.set_skip_pager_hint(true);

		this.window_position = WindowPosition.CENTER;
		this.icon = get_app_icon(16);
		this.resizable = false;
		this.deletable = false;
		
		msg_title = _msg_title;
		msg_body = _msg_body;
		show_ok = _show_ok;
		
		init_window();

		//show_all();
	}

	public void init_window () {
		
		title = "";

		// vbox_main
		vbox_main = new Gtk.Box(Orientation.HORIZONTAL, 6);
		vbox_main.margin = 6;
		add(vbox_main);
		
		// hbox_contents
		var hbox_contents = new Gtk.Box(Orientation.HORIZONTAL, 6);
		hbox_contents.margin = 6;
		vbox_main.add (hbox_contents);
		
		// image ----------------
		
		var spinner = new Gtk.Spinner();
		spinner.margin_right = 12;
		spinner.set_size_request(48,48);
		hbox_contents.add(spinner);
		spinner.start();
		
		// label -------------------

		var text = "<span weight=\"bold\" size=\"x-large\">%s</span>\n\n%s".printf(
			escape_html(msg_title),
			escape_html(msg_body));
		lbl_msg = new Gtk.Label(text);
		lbl_msg.xalign = 0.0f;
		lbl_msg.max_width_chars = 70;
		lbl_msg.wrap = true;
		lbl_msg.wrap_mode = Pango.WrapMode.WORD_CHAR;
		lbl_msg.use_markup = true;
		hbox_contents.add(lbl_msg);
		
		// actions -------------------------
		
		var action_area = new Gtk.Box(Orientation.HORIZONTAL, 6);
		action_area.margin_top = 12;
		vbox_main.add(action_area);
		
		if (show_ok){
			
			var button = new Gtk.Button.with_label(_("OK"));
			action_area.add(button);

			button.clicked.connect(()=>{
				this.close();
			});
		}
	}
}


