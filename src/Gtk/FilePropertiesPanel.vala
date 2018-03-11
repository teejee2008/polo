/*
 * FilePropertiesPanel.vala
 *
 * Copyright 2012-18 Tony George <teejeetech@gmail.com>
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

public class FilePropertiesPanel : Gtk.Box {

	private FileItem? file_item;

	private FilePreviewBox box_preview;
	private FilePropertiesBox box_props;
	private FilePermissionsBox box_perms;
	
	private Gtk.Window window;

	private bool ui_empty = true;
	
	public FilePropertiesPanel(Gtk.Window parent_window){
		//base(Gtk.Orientation.VERTICAL, 6); // issue with vala
		Object(orientation: Gtk.Orientation.VERTICAL, spacing: 12); // work-around

		window = parent_window;

		init_ui_empty();
	}

	public void show_properties_for_file(FileItem _file_item){

		file_item = _file_item;

		if (ui_empty){
			init_ui_for_file();
			update_ui_for_file();
		}
		else{
			update_ui_for_file();
		}
	}

	private void init_ui_empty(){

		gtk_container_remove_children(this);
		
		var vbox = new Gtk.Box(Orientation.VERTICAL, 12);
		vbox.margin = 12;
		this.add(vbox);

		var label = new Gtk.Label(_("File Properties"));
		label.xalign = 0.5f;
		label.use_markup = true;
		label.label = "<b>%s</b>".printf(label.label);
		vbox.add(label);

		label = new Gtk.Label(_("Select file to view properties"));
		label.xalign = 0.5f;
		label.margin_bottom = 12;
		label.use_markup = true;
		label.label = "<i>%s</i>".printf(label.label);
		vbox.add(label);

		if (box_preview != null){
			box_preview.stop();
		}

		ui_empty = true;

		this.show_all();
	}

	private void init_ui_for_file(){

		log_debug("FilePropertiesPanel: init_ui_for_file()");

		gtk_container_remove_children(this);

		// scrolled
		var scrolled = new Gtk.ScrolledWindow(null, null);
		//scrolled.set_shadow_type(ShadowType.ETCHED_IN);
		scrolled.hscrollbar_policy = PolicyType.AUTOMATIC;
		scrolled.vscrollbar_policy = PolicyType.AUTOMATIC;
		scrolled.hexpand = true;
		scrolled.vexpand = true;
		this.add(scrolled);

		var box = new Gtk.Box(Orientation.VERTICAL, 12);
		scrolled.add(box);

		box_preview = new FilePreviewBox(window, true);
		box.add(box_preview);

		box_props = new FilePropertiesBox(window, true);
		box.add(box_props);

		box_perms = new FilePermissionsBox(window, true);
		box.add(box_perms);
		
		ui_empty = false;
		
		this.show_all();
	}

	private void update_ui_for_file(){

		if (ui_empty){
			init_ui_for_file();
		}

		if (box_preview != null){
			box_preview.stop();
		}

		log_debug("FilePropertiesPanel: update_ui_for_file()");

		box_preview.preview_file(file_item);
		
		var group_label = box_props.show_properties_for_file(file_item);

		box_perms.show_properties_for_file(file_item, group_label);

		this.show_all();
	}

	public void refresh(){

		refresh_visibility();
	}
	
	public void refresh_visibility(){

		if (App.propbar_visible){
			show_panel();
		}
		else{
			hide_panel();
		}
	}
	
	public void show_panel(){

		log_debug("FilePropertiesPanel: show_panel()");

		App.propbar_visible = true;

		gtk_show(this);

		init_ui_empty();

		App.main_window.restore_propbar_position();
	}

	public void hide_panel(){

		log_debug("FilePropertiesPanel: hide_panel()");

		App.main_window.save_propbar_position();

		App.propbar_visible = false;

		if (box_preview != null){
			box_preview.quit();
		}

		gtk_hide(this);
	}
	
	public void toggle(){

		log_debug("FilePropertiesPanel: toggle()");
		
		if (this.visible){
			hide_panel();
		}
		else{
			show_panel();
		}
	}

}


