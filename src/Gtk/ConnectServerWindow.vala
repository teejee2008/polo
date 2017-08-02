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
using Json;

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
	private Gtk.Box hbox_status;
	private Gtk.Label lbl_status;
	private Gtk.Menu menu_config;
	
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

	private Gtk.Button btn_connect;
	private Gtk.Button btn_cancel;

	private GvfsTask task;
	
	protected bool aborted = false;
	protected uint tmr_status = 0;

	private uint tmr_init = 0;

	private string uri_temp = "";

	public ConnectServerWindow(Window parent, string uri_text) {
		
		set_transient_for(parent);
		window_position = WindowPosition.CENTER_ON_PARENT;

		this.delete_event.connect(on_delete_event);
		
		uri_temp = uri_text;

		init_ui();

		this.set_size_request(500,-1);

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

		if (uri_temp.length > 0){
			parse_uri(uri_temp);
		}
		else{
			cmb_type.active = 1;
		}
		
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
		ui_add_statusbar();
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
		spin.xalign = 0.5f;
		hbox.add(spin);
		spin_port = spin;

		//sg_option.add_widget(spin);

		spin_port.notify["sensitive"].connect(()=>{
			lbl_port.sensitive = spin_port.sensitive;
		});

		spin_port.notify["visible"].connect(()=>{
			lbl_port.visible = spin_port.visible;
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

		ui_add_history_icon(hbox);
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

		if (!LOG_DEBUG){
			gtk_hide(hbox);
		}

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

	private void ui_add_statusbar(){

		var hbox = new Gtk.Box(Orientation.HORIZONTAL, 6);
		hbox.margin_top = 12;
		vbox_main.add(hbox);
		hbox_status = hbox;

		string css = " background-color: #1976d2; ";
		gtk_apply_css(new Gtk.Widget[] { hbox }, css);

		gtk_hide(hbox_status);

		// label ----------------
		
		var label = new Gtk.Label(_("Connecting to Server..."));
		label.xalign = 0.0f;
		//label.hexpand = true;
		label.margin = 6;
		label.margin_left = 12;
		hbox.add(label);

		css = " color: #ffffff; ";
		gtk_apply_css(new Gtk.Widget[] { label }, css);

		// label ----------------
		
		label = new Gtk.Label("");
		label.xalign = 0.0f;
		label.hexpand = true;
		label.margin = 6;
		label.margin_left = 0;
		hbox.add(label);
		lbl_status = label;

		css = " color: #ffffff; ";
		gtk_apply_css(new Gtk.Widget[] { label }, css);

		// button -------------
		
		add_cancel_button(hbox);
	}

	private void add_cancel_button(Gtk.Box box){

		var ebox = gtk_add_event_box(box);

		var text = _("Cancel");
		var label = new Gtk.Label(text);
		//link.ellipsize = Pango.EllipsizeMode.MIDDLE;
		label.set_use_markup(true);
		label.margin = 6;
		label.margin_right = 12;
		ebox.add(label);

		var css = " color: #ffffff; ";
		gtk_apply_css(new Gtk.Widget[] { label }, css);

		ebox.button_press_event.connect((event) => {
			aborted = true;
			if (task != null){
				task.stop();
			}
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
		btn_cancel = button;
		
		button = new Gtk.Button.with_label(_("Connect"));
		button.clicked.connect(btn_connect_clicked);
		box.add(button);
		btn_connect = button;

		button.grab_focus();
	}

	private void ui_add_history_icon(Gtk.Box box){

		var list = dir_list_names(App.app_conf_dir_remotes);

		if (list.size == 0) { return; }
		
		var ebox = gtk_add_event_box(box);
		ebox.margin_left = 6;

		var img = IconManager.lookup_image("preferences-system", 16);
		ebox.add(img);

		var tt = _("History");
		img.set_tooltip_text(tt);
		ebox.set_tooltip_text(tt);

		ebox.button_press_event.connect((event)=>{

			log_debug("remote_history:button_press_event()");
			
			menu_config = new Gtk.Menu();
			menu_config.reserve_toggle_size = false;

			foreach(string file_name in list){

				var item = new Gtk.MenuItem();
				menu_config.append(item);

				string file_path = path_combine(App.app_conf_dir_remotes, file_name);
				
				var lbl = new Gtk.Label(file_get_title(file_name));
				lbl.xalign = 0.0f;
				lbl.margin_right = 6;
				item.add(lbl);

				item.activate.connect (() => {
					log_debug("item_activated(): %s".printf(file_path));
					load_settings(file_path);
				});
			}

			menu_config.show_all();
		
			if (event != null) {
				menu_config.popup (null, null, null, event.button, event.time);
			}
			else {
				menu_config.popup (null, null, null, 0, Gtk.get_current_event_time());
			}
			
			return true;
		});
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
				
				username = "";
				entry_username.placeholder_text = _("Optional: anonymous (default)");

				password = "";

				entry_share.visible = false;
				share = "";
				break;
				
			case "smb":
			
				entry_server.placeholder_text = _("NETBIOS Name");

				spin_port.visible = false;
				port = 0;

				entry_domain.visible = true;
				entry_domain.placeholder_text = _("Optional: WORKGROUP (default)");
				
				domain = "";
				
				username = "";
				entry_username.placeholder_text = _("Optional: guest (default)");
				
				password = "";

				entry_share.visible = true;
				entry_share.placeholder_text = "Required";

				break;
			}
			
			entry_uri.text = build_uri(true);
		});
		
		entry_server.changed.connect(() => {

			if (scheme == "smb"){
				entry_uri.text = build_uri(true);
				return;
			}

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

		spin_port.value_changed.connect(() => {
			entry_uri.text = build_uri(true);
		});

		entry_domain.changed.connect(() => {
			entry_uri.text = build_uri(true);
		});

		entry_username.changed.connect(() => {
			//entry_password.visible = (username != "anonymous");
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

		if (scheme != "smb"){

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

	public void parse_uri(string text){

		log_debug("parse_uri: %s".printf(text));

		// scheme --------------------------------
		
		var match = regex_match("""^(ftp|sftp|ssh|smb):""", text);
		if (match != null){
			scheme = match.fetch(1);
			log_debug("parsed: scheme: %s".printf(match.fetch(1)));
		}

		// ftp --------------------------------
		
		match = regex_match("""^(ftp|sftp|ssh):\/\/([0-9.]+)""", text);
		if (match != null){
			server = match.fetch(2);
			log_debug("parsed: server: %s".printf(match.fetch(2)));
		}

		match = regex_match("""^(ftp|sftp|ssh):\/\/([0-9.]+):([0-9]+)""", text);
		if (match != null){
			if (is_numeric(match.fetch(3))){
				port = int.parse(match.fetch(3));
				log_debug("parsed: port: %s".printf(match.fetch(3)));
			}
		}
		
		// samba --------------------------------

		match = regex_match("""^(smb):\/\/([^\/]+)\/*""", text);
		if (match != null){
			server = match.fetch(2);
			log_debug("parsed: server: %s".printf(match.fetch(2)));
		}

		match = regex_match("""^(smb):\/\/([^\/]+)\/([^\/]+)\/*""", text);
		if (match != null){
			share = match.fetch(3);
			log_debug("parsed: share: %s".printf(match.fetch(3)));
		}
	}

	// actions ----------------------------------
	 
	private void btn_connect_clicked(){

		log_debug("ConnectServerWindow: btn_connect_clicked()");

		// check if already mounted
		var item = GvfsMounts.find_by_uri(uri);
		if (item != null){
			log_debug("already mounted");
			view.set_view_item(item);
			this.destroy(); // exit
			return;
		}

		switch(scheme){
		case "ftp":
		case "sftp":
		case "ssh":

			var match = regex_match("^[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}$", server);
			if (match == null){
				gtk_messagebox(_("Invalid Server Name"),_("Enter IP address in correct format (Eg: 192.0.10.1)"), window, false);
				return;
			}	

			break;
			
		case "smb":
		
			var match = regex_match("^[a-zA-Z0-9]{1,15}$", server);
			if (match == null){
				gtk_messagebox(_("Invalid Server Name"),_("Enter NETBIOS name in correct format (1-15 alpha-numeric characters)"), window, false);
				return;
			}
			
			if (share.length == 0){
				gtk_messagebox(_("Share Name Not Specified"),_("Enter share name to connect (Required)"), window, false);
				return;
			}

			break;
		}

		connect_begin();
	}

	private void connect_begin(){

		log_debug("ConnectServerWindow: connect_begin(): %s".printf(uri));

		aborted = false;
		
		vbox_content.sensitive = false;
		btn_connect.sensitive = false;
		gtk_show(hbox_status);

		gtk_set_busy(true, this);

		err_log_clear();

		task = new GvfsTask();
		task.mount(uri, domain, username, password);

		//task.task_complete.connect(connect_end);

		task.execute();

		tmr_status = Timeout.add(500, update_status);
	}

	public bool update_status() {

		log_debug("update_status(): %s".printf(task.status.to_string()));
		
		if (task.is_running){
			lbl_status.label = "(%s)".printf(task.stat_time_elapsed_simple);
			gtk_do_events();
		}
		else{
			connect_end();
			return false;
		}

		return true;
	}

	public void stop_status_timer(){
		if (tmr_status > 0){
			Source.remove(tmr_status);
			tmr_status = 0;
		}
	}

	private void connect_end(){

		log_debug("ConnectServerWindow: connect_end()");
		
		gtk_set_busy(false, this);
		vbox_content.sensitive = true;
		btn_connect.sensitive = true;
		gtk_hide(hbox_status);

		log_debug("checking status");

		var file = File.new_for_uri(uri);
		if ((file.get_path() != null) && !file.get_path().contains("://")){
			// open the mounted path in active pane
			save_settings();
			log_debug("success: setting view set_view_path");
			view.set_view_path(uri);
			this.close();
		}
		else{
			if (!aborted){
				gtk_messagebox(_("Failed to Connect"), err_log_read(), this, true);
				// keep window open
			}
		}
	}

	private void btn_cancel_clicked(){
		aborted = true;
		if (task != null){
			task.stop();
		}
		this.close();
	}

	// settings

	private void save_settings(){
		
		var config = new Json.Object();

		set_numeric_locale("C"); // switch numeric locale

		config.set_string_member("scheme", scheme);
		config.set_string_member("server", server);
		config.set_string_member("port", port.to_string());
		config.set_string_member("domain", domain);
		config.set_string_member("username", username);
		config.set_string_member("password", password);
		config.set_string_member("share", share);

		var json = new Json.Generator();
		json.pretty = true;
		json.indent = 2;
		var node = new Json.Node(NodeType.OBJECT);
		node.set_object(config);
		json.set_root(node);

		file_delete(conf_path);

		try {
			json.to_file(conf_path);
		} catch (Error e) {
			log_error (e.message);
		}

		set_numeric_locale(""); // reset numeric locale

		log_debug(_("Remote config saved") + ": '%s'".printf(conf_path));
	}

	private void load_settings(string remote_conf_path){

		var f = File.new_for_path(remote_conf_path);
		if (!f.query_exists()) {
			return;
		}

		var parser = new Json.Parser();
		try {
			parser.load_from_file(remote_conf_path);
		}
		catch (Error e) {
			log_error (e.message);
		}

		var node = parser.get_root();
		var config = node.get_object();

		set_numeric_locale("C"); // switch numeric locale

		scheme = json_get_string(config, "scheme", scheme);
		server = json_get_string(config, "server", server);
		port = json_get_int(config, "port", port);
		domain = json_get_string(config, "domain", domain);
		username = json_get_string(config, "username", username);
		password = json_get_string(config, "password", password);
		share = json_get_string(config, "share", share);

		log_debug(_("Remote config loaded") + ": '%s'".printf(remote_conf_path));

		set_numeric_locale(""); // reset numeric locale
	}

	private string conf_path {
		owned get {
			
			string text = "";
			text += "%s".printf(scheme);
			text += "-%s".printf(server);
			
			if (scheme == "smb"){
				if (domain.length > 0){
					text += "-%s".printf(domain);
				}
				if (username.length > 0){
					text += "-%s".printf(username);
				}
				if (share.length > 0){
					text += "-%s".printf(share);
				}
			}
			else{
				if (port > 0){
					text += "-%d".printf(port);
				}
				if (domain.length > 0){
					text += "-%s".printf(domain);
				}
				if (username.length > 0){
					text += "-%s".printf(username);
				}
			}

			text += ".json";

			return path_combine(App.app_conf_dir_remotes, text);
		}
	}
}


