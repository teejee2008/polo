/*
 * SimpleProgressWindow.vala
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

public class SimpleProgressWindow : Gtk.Dialog {
	private Gtk.Box vbox_main;
	private Gtk.Spinner spinner;
	private Gtk.Label lbl_msg;
	private Gtk.Label lbl_status;
	private ProgressBar progressbar;
	private Gtk.Button btn_cancel;
	
	private uint tmr_init = 0;
	private uint tmr_pulse = 0;
	private uint tmr_close = 0;
	private int def_width = 400;
	private int def_height = 50;

	private string status_message;
	private bool allow_cancel = false;
	private bool allow_close = false;
	public bool is_cancelled = false;
	
	// init
	
	public SimpleProgressWindow.with_parent(Window parent, string message, bool allow_cancel = false) {
		set_transient_for(parent);
		set_modal(true);
		set_skip_taskbar_hint(true);
		set_skip_pager_hint(true);
		//set_type_hint(Gdk.WindowTypeHint.DIALOG);
		window_position = WindowPosition.CENTER_ON_PARENT;

		App.status_line = "";
		App.progress_count = 0;
		App.progress_total = 0;
		
		this.status_message = message;
		this.allow_cancel = allow_cancel;

		is_cancelled = false;
		
		this.delete_event.connect(close_window);
		
		init_window();
	}

	private bool close_window(){
		if (allow_close){
			// allow window to close 
			return false;
		}
		else{
			// do not allow window to close 
			return true;
		}
	}
	
	public void init_window () {
		title = "";
		icon = get_app_icon(16);
		resizable = false;
		set_deletable(false);

		var vbox_contents = get_content_area();
		
		//vbox_main
		vbox_main = new Gtk.Box(Orientation.VERTICAL, 6);
		vbox_main.margin = 12;
		vbox_main.set_size_request (def_width, def_height);
		vbox_contents.add (vbox_main);

		var hbox_status = new Gtk.Box(Orientation.HORIZONTAL, 6);
		vbox_main.add (hbox_status);
		
		spinner = new Gtk.Spinner();
		spinner.active = true;
		hbox_status.add(spinner);
		
		//lbl_msg
		lbl_msg = new Label (status_message);
		lbl_msg.halign = Align.START;
		lbl_msg.ellipsize = Pango.EllipsizeMode.END;
		lbl_msg.max_width_chars = 40;
		hbox_status.add (lbl_msg);

		//progressbar
		progressbar = new ProgressBar();
		//progressbar.set_size_request(-1, 25);
		progressbar.pulse_step = 0.1;
		vbox_main.pack_start (progressbar, false, true, 0);

		//lbl_status
		lbl_status = new Label ("");
		lbl_status.halign = Align.START;
		lbl_status.ellipsize = Pango.EllipsizeMode.END;
		lbl_status.max_width_chars = 40;
		vbox_main.pack_start (lbl_status, false, true, 0);
		
		//box
		var box = new Gtk.Box(Orientation.HORIZONTAL, 6);
		box.set_homogeneous(true);
		vbox_main.add (box);

		var sizegroup = new SizeGroup(SizeGroupMode.HORIZONTAL);

		//btn
		var button = new Gtk.Button.with_label (_("Cancel"));
		button.margin_top = 6;
		box.pack_start (button, false, false, 0);
		btn_cancel = button;
		sizegroup.add_widget(button);
		
		button.clicked.connect(()=>{
			is_cancelled = true;
			btn_cancel.sensitive = false;
		});

		show_all();

		//btn_cancel.visible = allow_cancel;
		btn_cancel.sensitive = allow_cancel;
	}

	// common

	public void pulse_start(){
		tmr_pulse = Timeout.add(100, pulse_timeout);
	}

	private bool pulse_timeout(){
		if (tmr_pulse > 0) {
			Source.remove(tmr_pulse);
			tmr_pulse = 0;
		}
			
		progressbar.pulse();
		gtk_do_events();

		tmr_pulse = Timeout.add(100, pulse_timeout);
		return true;
	}
	
	public void pulse_stop(){
		if (tmr_pulse > 0) {
			Source.remove(tmr_pulse);
			tmr_pulse = 0;
		}
	}

	public void update_message(string msg){
		if (msg.length > 0){
			lbl_msg.label = msg;
		}
	}

	public void update_status_line(bool clear = false){
		if (clear){
			lbl_status.label = "";
		}
		else{
			lbl_status.label = App.status_line;
		}
	}
	
	public void update_progressbar(){
		double fraction = App.progress_count / (App.progress_total * 1.0);
		if (fraction > 1.0){
			fraction = 1.0;
		}
		progressbar.fraction = fraction;
		gtk_do_events();
	}
	
	public void finish(string message = "") {
		btn_cancel.sensitive = false;
		
		pulse_stop();
		progressbar.fraction = 1.0;
		
		lbl_msg.label = message;
		lbl_status.label = "";
		
		spinner.visible = false;
		
		gtk_do_events();
		auto_close_window();
	}

	private void auto_close_window() {
		tmr_close = Timeout.add(2000, ()=>{
			if (tmr_init > 0) {
				Source.remove(tmr_init);
				tmr_init = 0;
			}

			allow_close = true;
			this.close();
			return false;
		});
	}
	
	public void sleep(int ms){
		Thread.usleep ((ulong) ms * 1000);
		gtk_do_events();
	}
}


