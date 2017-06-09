/*
 * AdminBar.vala
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

public class AdminBar : Gtk.Box {

	public FileViewPane pane;
	
	public AdminBar(FileViewPane? parent_pane){
		//base(Gtk.Orientation.VERTICAL, 6); // issue with vala
		Object(orientation: Gtk.Orientation.HORIZONTAL, spacing: 6); // work-around
		margin = 3;

		log_debug("AdminBar()");

		pane = parent_pane;

		init_ui();

		gtk_hide(this);
	}

	private void init_ui(){
		var label = new Gtk.Label(_("Running with Admin Priviledges (!)"));
		label.xalign = 0.5f;
		label.hexpand = true;
		label.margin = 6;
		add(label);

		string css = " background-color: #f44336; ";
		gtk_apply_css(new Gtk.Widget[] { this }, css);

		css = " color: #ffffff; ";
		gtk_apply_css(new Gtk.Widget[] { label }, css);
	}

	public void refresh(){

		log_debug("AdminBar: refresh()");
		
		if (get_user_id_effective() == 0){
			gtk_show(this);
		}
		else{
			gtk_hide(this);
		}
	}
	
}


