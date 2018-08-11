/*
 * FilePreviewBox.vala
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

public class FilePreviewBox : Gtk.Box {

	private FileItem file_item;
	private MediaFile mfile;

	private Gtk.Image image;

	private Gtk.Window window;

	private bool panel_mode = false;

	// player ui
	private uint tmr_status = 0;

	public FilePreviewBox(Gtk.Window parent_window, bool _panel_mode){
		//base(Gtk.Orientation.VERTICAL, 6); // issue with vala
		Object(orientation: Gtk.Orientation.VERTICAL, spacing: 0); // work-around

		window = parent_window;

		panel_mode = _panel_mode;

		init_ui();
	}

	private void init_ui(){

		init_ui_image();
		
		this.expand = true;
	}

	private void init_ui_image(){

		image = new Gtk.Image();
		image.xalign = 0.5f;
		image.yalign = 0.5f;
		this.add(image);

		image.expand = true;

		gtk_hide(image);
	}
	
	public void preview_file(FileItem _file_item){

		log_debug("FilePreviewBox: preview_file()");
		
		file_item = _file_item;
		
		if (file_item.is_image_gdk_supported){

			if (preview_image()){
				
				return;
			}
		}

		preview_thumbnail();
	}

	private bool preview_image(){
	
		log_debug("FilePreviewBox: preview_image()");

		gtk_show(image);

		try{
			var pix = new Gdk.Pixbuf.from_file_at_scale(file_item.file_path, 256, 256, true);
			pix = IconManager.resize_icon(pix, 256);
			image.set_from_pixbuf(pix);
			return true;
		}
		catch(Error e){
			//ignore
		}

		return false;
	}

	private bool preview_thumbnail(){

		log_debug("FilePreviewBox: preview_thumbnail()");

		gtk_show(image);
		
		ThumbTask task;
		var thumb = file_item.get_image(256, true, false, false, out task);

		if (task != null){
			while (!task.completed){
				sleep(100);
				gtk_do_events();
			}
			thumb = file_item.get_image(256, true, false, false, out task);
		}
		
		if (thumb != null) {
			image.pixbuf = thumb;
			log_debug("setting from file_item.get_image()");
		}
		else if (file_item.icon != null) {
			image.gicon = file_item.icon;
			log_debug("setting from file_item.gicon");
		}
		else{
			if (file_item.file_type == FileType.DIRECTORY) {
				image.pixbuf = IconManager.generic_icon_directory(256);
			}
			else{
				image.pixbuf = IconManager.generic_icon_file(256);
			}
		}

		return true;
	}
}


