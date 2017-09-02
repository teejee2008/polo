/*
 * PasswordDialog.vala
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

public class PasswordDialog : Gtk.Dialog {
	
	private Gtk.Box vbox_main;
	private Gtk.Label lbl_message;
	private Gtk.Entry txt_password;
	private Gtk.Entry txt_confirm;
	private Gtk.Button btn_ok;
	private Gtk.Button btn_cancel;
	private string message;
	private bool confirm_password = false;
	
	public PasswordDialog.with_parent(Gtk.Window parent, bool confirm_password, string title = "", string message = "") {
		set_transient_for(parent);
		set_modal(true);

		this.message = message;
		this.title = title;
		this.confirm_password = confirm_password;
		
		init_window();

		show_all();

		txt_confirm.visible = confirm_password;
		lbl_message.visible = (message.length > 0);
	}

	public void init_window () {
		
		window_position = WindowPosition.CENTER;
		resizable = false;
		deletable = false;
		icon = get_app_icon(16);
		
		// vbox_main
		vbox_main = get_content_area () as Gtk.Box;
		vbox_main.margin = 12;

		// grid
		var grid = new Grid();
		grid.set_column_spacing (6);
		grid.set_row_spacing (6);
		grid.margin_bottom = 12;
		vbox_main.add(grid);

		int row = -1;

		// lbl_message
		var label = new Gtk.Label(message);
		label.xalign = 0.0f;
		label.wrap = true;
		label.wrap_mode = Pango.WrapMode.WORD;
		label.max_width_chars = 80;
		label.use_markup = true;
		//label.margin_bottom = 12;
		grid.attach(label, 0, ++row, 1, 1);
		lbl_message = label;
		
		// password -------------------------------------------
		
		// txt_password
		var txt = new Gtk.Entry();
		txt.placeholder_text = _("Enter Passphrase");
		txt.hexpand = true;	
		txt.set_visibility(false);
		txt.set_size_request(350,-1);
		grid.attach(txt, 0, ++row, 1, 1);
		txt_password = txt;
		
		// icon
		var img = IconManager.lookup_image("lock",16);
		if (img != null){
			txt.secondary_icon_pixbuf = img.pixbuf;
		}
		txt.set_icon_tooltip_text(EntryIconPosition.SECONDARY, _("Show"));

		// icon click
		txt.icon_press.connect((p0, p1) => {
			password_visibility_toggle();
		});

		// ok button state
		txt.key_release_event.connect((event)=>{
			set_ok_button_state();
			return true;
		});

		//this.add_events(Gdk.EventMask.KEY_PRESS_MASK);
		
		// confirm -------------------------------------
		
		//txt_confirm
		txt = new Gtk.Entry();
		txt.placeholder_text = _("Confirm Passphrase");
		txt.hexpand = true;		
		txt.set_visibility(false);
		grid.attach(txt, 0, ++row, 1, 1);
		txt_confirm = txt;
		
		//ok button state
		txt.key_release_event.connect((event)=>{
			set_ok_button_state();
			return true;
		});

		// click OK on ENTER key press -------------
		
		if (confirm_password){
			txt_confirm.activate.connect (() => {
				btn_ok_clicked();
			});
		}
		else{
			txt_password.activate.connect (() => {
				btn_ok_clicked();
			});
		}
		
		// actions -----------------------------------
		
		btn_ok = (Gtk.Button) add_button ("_Ok", Gtk.ResponseType.NONE);

		btn_ok.clicked.connect(btn_ok_clicked);
		
		btn_cancel = (Gtk.Button) add_button ("_Cancel", Gtk.ResponseType.NONE);

		btn_cancel.clicked.connect(btn_cancel_clicked);

		set_ok_button_state();
	}

	public static string prompt_user(Gtk.Window parent, bool confirm_password, string dlg_title, string dlg_msg){
		
		var dlg = new PasswordDialog.with_parent(parent, confirm_password, dlg_title, dlg_msg);

		int response_id = ResponseType.NONE;
		
		do{
			response_id = dlg.run();
		}
		while (response_id == ResponseType.NONE);

		string user_password = "";
		
		switch (response_id) {
		case Gtk.ResponseType.OK:
			if (dlg.password.length > 0){
				user_password = dlg.password;
			}
			break;
		case Gtk.ResponseType.CANCEL:
			//do nothing
			//log_error(_("Password dialog cancelled by user"));
			break;
		}
		
		dlg.destroy();

		return user_password;
	}
	
	private void password_visibility_toggle(){
		
		txt_password.set_visibility(!txt_password.get_visibility());
		txt_confirm.set_visibility(txt_password.get_visibility());

		string text = (txt_password.get_visibility() == true) ? _("Hide") : _("Show");
		txt_password.set_icon_tooltip_text(EntryIconPosition.SECONDARY, text);
	}
	
	private void set_ok_button_state(){
		
		if (txt_confirm.visible){
			btn_ok.sensitive = (txt_password.text.length > 0) && (txt_confirm.text.length > 0);
		}
		else{
			btn_ok.sensitive = (txt_password.text.length > 0);
		}
	}

	public string password{
		owned get {
			return txt_password.text.strip();
		}
	}

	private void btn_ok_clicked(){
		
		if (confirm_password){
			if (txt_password.text != txt_confirm.text) {
				gtk_messagebox(_("Password Mismatch"), _("Passwords do not match"), this, true);
				return;
			}
		}
		
		this.response(Gtk.ResponseType.OK);
	}

	private void btn_cancel_clicked(){
		this.response(Gtk.ResponseType.CANCEL);
	}
}


