/*
 * IconManager.vala
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

public class IconManager : GLib.Object {

	public static Gtk.IconTheme theme;

	public static Gee.ArrayList<string> search_paths = new Gee.ArrayList<string>();

	public static void init(string[] args, string app_name){

		log_debug("IconManager: init()");
		
		search_paths = new Gee.ArrayList<string>();

		string binpath = file_resolve_executable_path(args[0]);
		log_debug("bin_path: %s".printf(binpath));

		// check absolute location
		string path = "/usr/share/%s/images".printf(app_name);
		if (dir_exists(path)){
			search_paths.add(path);
			log_debug("found images directory: %s".printf(path));
		}

		// check relative location
		string base_path = file_parent(file_parent(file_parent(binpath)));
		if (base_path != "/"){
			log_debug("base_path: %s".printf(base_path));
			path = path_combine(base_path, path);
			if (dir_exists(path)){
				search_paths.add(path);
				log_debug("found images directory: %s".printf(path));
			}
		}

		refresh_icon_theme();
	}

	public static void refresh_icon_theme(){
		theme = Gtk.IconTheme.get_default();
		foreach(string path in search_paths){
			theme.append_search_path(path);
		}
	}

	public static Gdk.Pixbuf? lookup(string icon_name, int icon_size, bool symbolic = false, bool use_hardcoded = false){

		Gdk.Pixbuf? pixbuf = null;

		if (icon_name.length == 0){ return null; }

		if (!use_hardcoded){
			try {
				pixbuf = theme.load_icon_for_scale(icon_name, icon_size, 1, Gtk.IconLookupFlags.FORCE_SIZE);
				if (pixbuf != null){ return pixbuf; }
			}
			catch (Error e) {
				log_debug(e.message);
			}
		}

		foreach(string search_path in search_paths){

			foreach(string ext in new string[] { ".svg", ".png", ".jpg", ".gif"}){

				string img_file = path_combine(search_path, icon_name + ext);

				if (file_exists(img_file)){

					try {
						pixbuf = new Gdk.Pixbuf.from_file_at_scale(img_file, icon_size, icon_size, true);
						if (pixbuf != null){ return pixbuf; }
					}
					catch (Error e) {
						log_debug(e.message);
					}

				}
			}
		}

		return pixbuf;
	}
	
	public static Gtk.Image? lookup_image(string icon_name, int icon_size, bool symbolic = false, bool use_hardcoded = false){

		if (icon_name.length == 0){ return null; }
		
		Gdk.Pixbuf? pix = lookup(icon_name, icon_size, symbolic, use_hardcoded);
		
		if (pix != null){
			return new Gtk.Image.from_pixbuf(pix);
		}
		else{
			return null;
		}
	}

	public static Gdk.Pixbuf? lookup_gicon(GLib.Icon? gicon, int icon_size){

		Gdk.Pixbuf? pixbuf = null;

		if (gicon == null){ return null; }
		
		try {
			pixbuf = theme.lookup_by_gicon(gicon, icon_size, Gtk.IconLookupFlags.FORCE_SIZE).load_icon();
		}
		catch (Error e) {
			log_debug(e.message);
		}

		return pixbuf;
	}

	public static Gtk.Image? lookup_animation(string gif_name){

		if (gif_name.length == 0){ return null; }
		
		foreach(string search_path in search_paths){

			foreach(string ext in new string[] { ".gif" }){

				string img_file = path_combine(search_path, gif_name + ext);

				if (file_exists(img_file)){

					return new Gtk.Image.from_file(img_file);
				}
			}
		}

		return null;
	}

	public static Gdk.Pixbuf? add_emblem (Gdk.Pixbuf pixbuf, string icon_name, int emblem_size,
		bool emblem_symbolic, Gtk.CornerType corner_type) {

		if (icon_name.length == 0){ return pixbuf; }

        Gdk.Pixbuf? emblem = null;

		var SMALL_EMBLEM_COLOR = Gdk.RGBA();
		SMALL_EMBLEM_COLOR.parse("#000000");
		SMALL_EMBLEM_COLOR.alpha = 1.0;

		var EMBLEM_PADDING = 1;

        try {
            var icon_info = theme.lookup_icon (icon_name, emblem_size, Gtk.IconLookupFlags.FORCE_SIZE);
            if (emblem_symbolic){
				emblem = icon_info.load_symbolic(SMALL_EMBLEM_COLOR);
			}
			else{
				emblem = icon_info.load_icon();
			}
        } catch (GLib.Error e) {
            log_error("get_icon_emblemed(): %s".printf(e.message));
            return pixbuf;
        }

        if (emblem == null)
            return pixbuf;

        var offset_x = EMBLEM_PADDING;

        if ((corner_type == Gtk.CornerType.BOTTOM_RIGHT) || (corner_type == Gtk.CornerType.TOP_RIGHT)){
			offset_x = pixbuf.width - emblem.width - EMBLEM_PADDING ;
		}

		var offset_y = EMBLEM_PADDING;

		if ((corner_type == Gtk.CornerType.BOTTOM_LEFT) || (corner_type == Gtk.CornerType.BOTTOM_RIGHT)){
			offset_y = pixbuf.height - emblem.height - EMBLEM_PADDING ;
		}

        var emblemed = pixbuf.copy();
        emblem.composite(emblemed, offset_x, offset_y, emblem_size, emblem_size,
			offset_x, offset_y, 1.0, 1.0, Gdk.InterpType.BILINEAR, 255);

        return emblemed;
    }

    public static Gdk.Pixbuf? add_transparency (Gdk.Pixbuf pixbuf, int opacity = 130) {

		var trans = pixbuf.copy();
		trans.fill((uint32) 0xFFFFFF00);

		//log_debug("add_transparency");

        try {
			int width = pixbuf.get_width();
			int height = pixbuf.get_height();
			pixbuf.composite(trans, 0, 0, width, height, 0, 0, 1.0, 1.0, Gdk.InterpType.BILINEAR, opacity);
        }
        catch (GLib.Error e) {
			log_error("get_icon_transparent(): %s".printf(e.message));
            return pixbuf;
        }

        return trans;
    }

    public static Gdk.Pixbuf? generic_icon_image(int icon_size) {
		return lookup("image-x-generic", icon_size, false);
    }

    public static Gdk.Pixbuf? generic_icon_video(int icon_size) {
		return lookup("video-x-generic", icon_size, false);
    }

    public static Gdk.Pixbuf? generic_icon_file(int icon_size) {
		return lookup("text-x-preview", icon_size, false);
    }

     public static Gdk.Pixbuf? generic_archive_file(int icon_size) {
		return lookup("package-x-generic", icon_size, false);
    }

    public static Gdk.Pixbuf? generic_icon_directory(int icon_size) {
		return lookup("folder", icon_size, false);
    }

    public static Gdk.Pixbuf? generic_icon_iso(int icon_size) {
		return lookup("media-cdrom", icon_size, false);
    }

    public static Gdk.Pixbuf? generic_icon_pdf(int icon_size) {
		return lookup("application-pdf", icon_size, false);
    }

}
