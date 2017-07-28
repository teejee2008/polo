/*
 * ConnectServerWindow.vala
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

public class ConnectServerWindow : Gtk.Window, IPaneActive {
	
	private Gtk.Box vbox_main;
	private Gtk.Box vbox_content;
	
	private Gtk.Entry entry_server;
	private Gtk.SpinButton spin_port;
	private Gtk.ComboBox cmb_type;
	private Gtk.Entry entry_share;
	private Gtk.Entry entry_domain;
	private Gtk.Entry entry_username;
	private Gtk.Entry entry_password;
	private Gtk.Entry entry_uri;
	
	private Gtk.SizeGroup sg_label;
	private Gtk.SizeGroup sg_option;

	private Gtk.Button btn_ok;
	private Gtk.Button btn_cancel;

	private uint tmr_init = 0;

	public ConnectServerWindow(Window parent, string uri) {
		
		set_transient_for(parent);
		window_position = WindowPosition.CENTER_ON_PARENT;

		this.delete_event.connect(on_delete_event);

		init_ui();

		tmr_init = Timeout.add(100, init_delayed);

		show_all();
	}

	private bool on_delete_event(Gdk.EventAny event){
		btn_cancel_clicked();
		return false; // close window
	}	

	private bool init_delayed(){
		if (tmr_init > 0){
			Source.remove(tmr_init);
			tmr_init = 0;
		}

		cmb_type.active = 1;
		return false;
	}
	
	private void init_ui () {

		log_debug("ConnectServerWindow: init_window()");
		
		title = _("Connect to Server");

		set_modal(true);
		set_skip_taskbar_hint(true);
		set_skip_pager_hint(true);
		icon = get_app_icon(16);
		deletable = true;
		resizable = false;

		vbox_main = new Gtk.Box(Orientation.VERTICAL, 6);
		vbox_main.margin = 12;
		this.add(vbox_main);
		
		vbox_content = new Gtk.Box(Orientation.VERTICAL, 6);
		//vbox_content.margin_bottom = 48;
		vbox_main.add(vbox_content);

		sg_label = new Gtk.SizeGroup(Gtk.SizeGroupMode.HORIZONTAL);
		sg_option = new Gtk.SizeGroup(Gtk.SizeGroupMode.HORIZONTAL);

		ui_add_server_type();
		ui_add_server_and_port();
		ui_add_domain();
		ui_add_username();
		ui_add_password();
		ui_add_server_share();
		ui_add_uri();
		ui_add_action_area();

		connect_signals();

		log_debug("ConnectServerWindow: init_window(): exit");
	}

	private void ui_add_server_and_port() {

		log_debug("ConnectServerWindow: ui_add_server_and_port()");
		
		var hbox = new Gtk.Box(Orientation.HORIZONTAL, 6);
		vbox_content.add(hbox);

		// label ----------------
		
		var label = new Gtk.Label (_("Server") + ":");
		label.xalign = 1.0f;
		hbox.add(label);
		
		sg_label.add_widget(label);

		// entry ----------------
		
		var entry = new Gtk.Entry();
		entry.hexpand = true;
		entry.set_size_request(200,-1);
		hbox.add(entry);
		entry_server = entry;

		entry.placeholder_text = _("Example: 192.0.2.1");

		//entry.key_press_event.connect(server_key_press_event);

		sg_option.add_widget(entry);
		
		//remove text highlight
		entry.focus_out_event.connect((entry, event) => {
			entry_server.select_region(0, 0);
			return false;
		});

		// label ----------------
		
		label = new Gtk.Label (_("Port") + ":");
		label.xalign = 1.0f;
		hbox.add(label);
		var lbl_port = label;
		
		//sg_label.add_widget(label);

		// spin ---------------------
		
		var adj = new Gtk.Adjustment(1, 1, 65535, 1, 1, 0); //value, lower, upper, step, page_step, size
		var spin = new Gtk.SpinButton (adj, 1, 0);
		spin.xalign = (float) 0.5;
		hbox.add(spin);
		spin_port = spin;

		//sg_option.add_widget(spin);

		spin.notify["sensitive"].connect(()=>{
			lbl_port.sensitive = spin.sensitive;
		});

		spin.notify["visible"].connect(()=>{
			lbl_port.visible = spin.visible;
			hbox.visible = spin.visible;
		});
	}

	private void ui_add_server_type() {

		log_debug("ConnectServerWindow: ui_add_server_type()");
		
		var hbox = new Gtk.Box(Orientation.HORIZONTAL, 6);
		vbox_content.add(hbox);
		
		// label --------------------------------------
		
		var label = new Gtk.Label(_("Type") + ":");
		label.xalign = 1.0f;
		hbox.add(label);

		sg_label.add_widget(label);
		
		// combo ---------------------------------
		
		var combo = new Gtk.ComboBox();
		hbox.add(combo);
		cmb_type = combo;

		//sg_option.add_widget(combo);
		
		var cell = new CellRendererText();
		combo.pack_start(cell, false);
		combo.set_attributes(cell, "text", 0);

		// render text
		combo.set_cell_data_func (cell, (cell_layout, cell, model, iter) => {
			string txt, val;
			model.get (iter, 0, out txt, 1, out val, -1);

			(cell as Gtk.CellRendererText).text = txt;
		});

		combo.notify["sensitive"].connect(()=>{
			label.sensitive = combo.sensitive;
		});

		combo.notify["visible"].connect(()=>{
			label.visible = combo.visible;
			hbox.visible = combo.visible;
		});
		
		ui_server_type_populate();
	}

	private void ui_server_type_populate() {
		
		TreeIter iter;
		var model = new Gtk.ListStore (3, typeof (string), typeof (string), typeof(bool));
		
		model.append (out iter);
		model.set (iter, 0, "SSH", 1, "ssh");

		model.append (out iter);
		model.set (iter, 0, "FTP", 1, "ftp");

		model.append (out iter);
		model.set (iter, 0, "SFTP", 1, "sftp");

		model.append (out iter);
		model.set (iter, 0, "Samba / Windows Share", 1, "smb");
		
		cmb_type.model = model;
		cmb_type.active = -1; // unset, will be set by init_delayed()
	}

	private void ui_add_server_share() {

		log_debug("ConnectServerWindow: ui_add_server_share()");
		
		var hbox = new Gtk.Box(Orientation.HORIZONTAL, 6);
		vbox_content.add(hbox);

		// label ----------------
		
		var label = new Gtk.Label (_("Share") + ":");
		label.xalign = 1.0f;
		hbox.add(label);
		
		sg_label.add_widget(label);

		// entry ----------------
		
		var entry = new Gtk.Entry();
		entry.hexpand = true;
		entry.set_size_request(200,-1);
		hbox.add(entry);
		entry_share = entry;

		entry.placeholder_text = _("Optional");

		sg_option.add_widget(entry);
		
		//remove text highlight
		entry.focus_out_event.connect((entry, event) => {
			entry_share.select_region(0, 0);
			return false;
		});

		entry.notify["sensitive"].connect(()=>{
			label.sensitive = entry.sensitive;
		});

		entry.notify["visible"].connect(()=>{
			label.visible = entry.visible;
			hbox.visible = entry.visible;
		});
	}

	private void ui_add_domain() {

		log_debug("ConnectServerWindow: ui_add_domain()");
		
		var hbox = new Gtk.Box(Orientation.HORIZONTAL, 6);
		vbox_content.add(hbox);

		// label ----------------
		
		var label = new Gtk.Label (_("Domain") + ":");
		label.xalign = 1.0f;
		hbox.add(label);

		sg_label.add_widget(label);

		// entry ----------------
		
		var entry = new Gtk.Entry();
		entry.hexpand = true;
		entry.set_size_request(200,-1);
		hbox.add(entry);
		entry_domain = entry;

		entry.placeholder_text = _("Optional");

		sg_option.add_widget(entry);
		
		//remove text highlight
		entry.focus_out_event.connect((entry, event) => {
			entry_domain.select_region(0, 0);
			return false;
		});

		entry.notify["sensitive"].connect(()=>{
			label.sensitive = entry.sensitive;
		});

		entry.notify["visible"].connect(()=>{
			label.visible = entry.visible;
			hbox.visible = entry.visible;
		});
	}
	
	private void ui_add_username() {

		log_debug("ConnectServerWindow: ui_add_username()");
		
		var hbox = new Gtk.Box(Orientation.HORIZONTAL, 6);
		vbox_content.add(hbox);

		// label ----------------
		
		var label = new Gtk.Label (_("Username") + ":");
		label.xalign = 1.0f;
		hbox.add(label);
		
		sg_label.add_widget(label);

		// entry ----------------
		
		var entry = new Gtk.Entry();
		entry.hexpand = true;
		entry.set_size_request(200,-1);
		hbox.add(entry);
		entry_username = entry;

		entry.placeholder_text = _("Optional");

		sg_option.add_widget(entry);
		
		//remove text highlight
		entry.focus_out_event.connect((entry, event) => {
			entry_username.select_region(0, 0);
			return false;
		});

		entry.notify["sensitive"].connect(()=>{
			label.sensitive = entry.sensitive;
		});

		entry.notify["visible"].connect(()=>{
			label.visible = entry.visible;
			hbox.visible = entry.visible;
		});
	}

	private void ui_add_password() {

		log_debug("ConnectServerWindow: ui_add_password()");
		
		var hbox = new Gtk.Box(Orientation.HORIZONTAL, 6);
		vbox_content.add(hbox);

		// label ----------------
		
		var label = new Gtk.Label (_("Password") + ":");
		label.xalign = 1.0f;
		hbox.add(label);
		
		sg_label.add_widget(label);

		// entry ----------------
		
		var entry = new Gtk.Entry();
		entry.hexpand = true;
		entry.set_size_request(200,-1);
		entry.set_visibility(false);
		hbox.add(entry);
		entry_password = entry;

		entry.placeholder_text = _("Optional");

		sg_option.add_widget(entry);
		
		//remove text highlight
		entry.focus_out_event.connect((entry, event) => {
			entry_password.select_region(0, 0);
			return false;
		});

		entry.notify["sensitive"].connect(()=>{
			label.sensitive = entry.sensitive;
		});

		entry.notify["visible"].connect(()=>{
			label.visible = entry.visible;
			hbox.visible = entry.visible;
		});
	}

	private void ui_add_uri() {

		log_debug("ConnectServerWindow: ui_add_uri()");
		
		var hbox = new Gtk.Box(Orientation.HORIZONTAL, 6);
		vbox_content.add(hbox);

		// label ----------------
		
		var label = new Gtk.Label (_("URI") + ":");
		label.xalign = 1.0f;
		hbox.add(label);
		
		sg_label.add_widget(label);

		// entry ----------------
		
		var entry = new Gtk.Entry();
		entry.hexpand = true;
		entry.set_size_request(200,-1);
		hbox.add(entry);
		entry_uri = entry;

		entry.sensitive = false;

		sg_option.add_widget(entry);
		
		//remove text highlight
		entry.focus_out_event.connect((entry, event) => {
			entry_uri.select_region(0, 0);
			return false;
		});
	}

	private void ui_add_action_area() {

		log_debug("ConnectServerWindow: ui_add_action_area()");

		var label = new Gtk.Label("");
		label.vexpand = true;
		vbox_main.add(label);
		
		var box = new Gtk.ButtonBox(Orientation.HORIZONTAL);
		box.set_layout(Gtk.ButtonBoxStyle.CENTER);
		box.set_spacing(6);
		vbox_main.add(box);
		
		var button = new Gtk.Button.with_label(_("Cancel"));
		button.clicked.connect(btn_cancel_clicked);
		box.add(button);
		btn_ok = button;
		
		button = new Gtk.Button.with_label(_("Connect"));
		button.clicked.connect(btn_ok_clicked);
		box.add(button);
		btn_cancel = button;

		button.grab_focus();
	}

	private void connect_signals(){

		cmb_type.changed.connect(() => {
			
			switch(scheme){
			case "ftp":
			case "sftp":
			case "ssh":
			
				entry_server.placeholder_text = _("Host IP (Eg: 192.0.10.1)");

				spin_port.visible = true;
				port = (scheme == "ftp") ? 21 : 22;

				entry_domain.visible = false;
				domain = "";
				
				if (username.length == 0){
					username = "anonymous";
					password = "";
				}

				entry_share.visible = false;
				share = "";
				break;
				
			case "smb":
			
				entry_server.placeholder_text = _("Host IP or Name");

				spin_port.visible = false;
				port = 0;

				entry_domain.visible = true;
				domain = "WORKGROUP";
				
				username = "";
				
				password = "";

				entry_share.visible = true;
				share = "";

				break;
			}
			
			entry_uri.text = build_uri(true);
		});
		
		entry_server.changed.connect(() => {

			if (scheme == "smb"){ return; }

			string text = entry_server.text;

			if (text.contains(":")){
				var arr = text.split(":");
				server = arr[0];
				if (is_numeric(arr[1])){
					port = int.parse(arr[1]);
				}
				return;
			}
			
			log_debug(text);

			for (int i = 0; i < text.length; i++){
				unichar c = text[i];
				if (!c.isdigit() && (c != '.')){
					entry_server.text = text.replace(c.to_string(),"");
					return;
				}
			}

			entry_uri.text = build_uri(true);
		});

		spin_port.changed.connect(() => {
			entry_uri.text = build_uri(true);
		});

		entry_domain.changed.connect(() => {
			entry_uri.text = build_uri(true);
		});

		entry_username.changed.connect(() => {
			entry_password.visible = (username != "anonymous");
			entry_uri.text = build_uri(true);
		});

		entry_password.changed.connect(() => {
			entry_uri.text = build_uri(true);
		});

		entry_share.changed.connect(() => {
			entry_uri.text = build_uri(true);
		});
	}

	//properties ------------------------------------------------------

	public string server {
		owned get {
			return entry_server.text;
		}
		set {
			entry_server.text = value;
		}
	}

	public int port {
		get {
			return (int) spin_port.get_value();
		}
		set {
			spin_port.set_value(value);
		}
	}

	public string scheme {
		owned get {
			return gtk_combobox_get_value(cmb_type, 1, "ftp");
		}
		set {
			gtk_combobox_set_value(cmb_type, 1, value);
		}
	}

	public string share {
		owned get {
			return entry_share.text;
		}
		set {
			entry_share.text = value;
		}
	}

	public string domain {
		owned get {
			return entry_domain.text;
		}
		set {
			entry_domain.text = value;
		}
	}
	
	public string username {
		owned get {
			return entry_username.text;
		}
		set {
			entry_username.text = value;
		}
	}

	public string password {
		owned get {
			return entry_password.text;
		}
		set {
			entry_password.text = value;
		}
	}

	public string uri {
		owned get {
			return build_uri(false);
		}
		set {
			entry_uri.text = value;
		}
	}

	private string build_uri(bool mask){
		
		string txt = "";
		string login = "";
		string param = "";
		
		// scheme://domain;username:password@server:port/share
		
		if (scheme.length > 0){
			param = "%s://".printf(scheme);
			txt += param;
		}

		if (domain.length > 0){
			param = "%s;".printf(domain);
			txt += param;
			login += param;
		}

		if (username.length > 0){
			param = "%s".printf(username);
			txt += param;
			login += param;
		}

		if (password.length > 0){
			param = ":%s".printf((mask ? string.nfill(password.length, '*') : password));
			txt += param;
			login += param;
		}

		if (server.length > 0){
			param = "";
			if (login.length > 0){
				param += "@";
			}
			param += "%s".printf(server);
			txt += param;
		}

		if (scheme != "smb"){
			param = ":%d".printf(port);
			txt += param;
		}

		if (share.length > 0){
			param = "/%s".printf(share);
			txt += param;
		}

		txt += "/";
		
		return txt;
	}

	// actions ----------------------------------
	 
	private void btn_ok_clicked(){

		log_debug("btn_ok_clicked()");

		// check if already mounted
		foreach(var item in GvfsMounts.get_mounts(App.user_id)){
			log_debug("item: %s".printf(item.file_uri));
			if (item.file_uri == uri){
				log_debug("already mounted");
				view.set_view_item(item);
				this.destroy(); // exit
				return;
			}
		}

		vbox_content.sensitive = false;
		gtk_set_busy(true, this);
		
		btn_ok.sensitive = false;

		err_log_clear();
		
		bool ok = GvfsMounts.mount(uri);

		gtk_set_busy(false, this);
		vbox_content.sensitive = true;
		
		if (ok){

			// open the mounted path in active pane
			foreach(var item in GvfsMounts.get_mounts(App.user_id)){
				log_debug("item: %s".printf(item.file_uri));
				if (item.file_uri == uri){
					log_debug("success: setting view item");
					view.set_view_item(item);
					break;
				}
			}
			
			this.close();
		}
		else{
			gtk_messagebox(_("Failed to Connect"), err_log_read(), this, true);
		}
	}

	private void btn_cancel_clicked(){
		this.close();
	}
}


