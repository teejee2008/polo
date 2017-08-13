/*
 * ToolsWindow.vala
 *
 * Copyright 2012 Tony George <teejee2008@gmail.com>
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

using TeeJee.Logging;
using TeeJee.FileSystem;
using TeeJee.ProcessHelper;
using TeeJee.GtkHelper;
using TeeJee.System;
using TeeJee.Misc;

public class ToolsWindow : Gtk.Dialog {

	private Gtk.Box vbox_main;
	private Gtk.Box vbox_actions;
	private Gtk.Button btn_ok;
	private Gtk.Button btn_refresh;
	private Gtk.TreeView tv;
	private Gtk.ScrolledWindow sw;

	public ToolsWindow (Gtk.Window parent) {
		title = _("External Tools");

		set_transient_for(parent);
		set_modal(true);
		
        window_position = WindowPosition.CENTER_ON_PARENT;
        destroy_with_parent = true;
        skip_taskbar_hint = true;
		deletable = true;
		resizable = false;
		icon = get_app_icon(16);

		// get content area
		vbox_main = get_content_area();
		vbox_main.set_size_request (600, 450);
		vbox_main.margin = 6;
		
		// get action area
		vbox_actions = (Box) get_action_area();
		vbox_actions.margin = 6;

	    tv = new Gtk.TreeView();
		tv.get_selection().mode = SelectionMode.NONE;
		tv.headers_visible = true;
		//tv.set_rules_hint (true);

		sw = new Gtk.ScrolledWindow(null, null);
		sw.set_shadow_type (ShadowType.ETCHED_IN);
		sw.add (tv);
		sw.expand = true;
		vbox_main.add(sw);

		var col_name = new TreeViewColumn();
		col_name.title = " " + _("Utility") + " ";
		col_name.resizable = false;
		tv.append_column(col_name);
		
		var cell_icon = new CellRendererPixbuf ();
		col_name.pack_start (cell_icon, false);
		col_name.set_attributes(cell_icon, "pixbuf", 3);
		
		var cell_name = new CellRendererText ();
		col_name.pack_start (cell_name, false);
		col_name.set_attributes(cell_name, "text", 0);

		var col_status = new TreeViewColumn();
		col_status.title = " " + _("Status") + " ";
		tv.append_column(col_status);

		var cell_status = new CellRendererText ();
		cell_status.xalign = 0.5f;
		col_status.pack_start (cell_status, false);
		col_status.set_attributes(cell_status, "text", 2);
		
		var col_desc = new TreeViewColumn();
		col_desc.title = " " + _("Required for") + " ";
		tv.append_column(col_desc);

		var cell_desc = new CellRendererText ();
		col_desc.pack_start (cell_desc, false);
		col_desc.set_attributes(cell_desc, "text", 1);

		tv_refresh();

		//btn_refresh
        btn_refresh = new Gtk.Button.with_label("   " + _("Check") + "   ");
		vbox_actions.add(btn_refresh);
		btn_refresh.clicked.connect(()=>{
			gtk_set_busy(true,this);
			App.check_all_tools();
			App.check_all_plugins();
			tv_refresh();
			gtk_set_busy(false,this);
		});

        //btn_ok
        btn_ok = (Button) add_button ("gtk-ok", Gtk.ResponseType.ACCEPT);
        btn_ok.clicked.connect (() => {  destroy();  });

		show_all();
	}

	public void tv_refresh(){
		
		var store = new Gtk.ListStore (4, typeof (string), typeof (string), typeof (string), typeof(Gdk.Pixbuf));

		//status icons
		Gdk.Pixbuf pix_ok = null;
		Gdk.Pixbuf pix_missing = null;

		try{
			pix_ok = IconManager.lookup("item-green", 16, false, true);
			pix_missing  = IconManager.lookup("item-red", 16, false, true);
		}
        catch(Error e){
	        log_error (e.message);
	    }

		TreeIter iter;
		var list = new Gee.ArrayList<Tool>();
		foreach (var tool in App.tools.values){
			list.add(tool);
		}
		CompareDataFunc<Tool> func = (a, b) => {
			return strcmp(a.command,b.command);
		};
		list.sort((owned)func);
		
		foreach (var tool in list){
			store.append(out iter);
			store.set(iter, 0, tool.command);
			store.set(iter, 1, tool.description);
			store.set(iter, 2, tool.available ? _("Found") : _("Missing"));
			store.set(iter, 3, tool.available ? pix_ok : pix_missing);
		}
		
		tv.set_model(store);
		tv.columns_autosize();
	}
}

public class Tool : GLib.Object{
	
	public string command = "";
	public string name = "";
	public string description = "";
	public bool available = false;

	public Tool(string cmd, string _name, string desc){
		command = cmd;
		name = _name;
		description = desc;
	}

	public bool check_availablity(){
		available = cmd_exists(command);
		return available;
	}
}
