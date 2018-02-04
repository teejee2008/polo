/*
 * PathbarStyleMenu.vala
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

public enum PathbarStyle{
	
	COMPACT,
	ARROWS,
	BUTTONS,
	FLAT_BUTTONS;

	public string to_string() {
        switch (this) {
            case COMPACT:
                return "compact";

            case ARROWS:
                return "arrows";

            case BUTTONS:
                return "buttons";

            case FLAT_BUTTONS:
                return "flat_buttons";

            default:
                assert_not_reached();
        }
    }

    public static PathbarStyle from_string(string text) {
		
        switch (text.down()) {
            case "compact":
                return COMPACT;

            case "arrows":
                return ARROWS;

            case "buttons":
                return BUTTONS;

            case "flat_buttons":
                return FLAT_BUTTONS;

            default:
                assert_not_reached();
        }
    }

    public Gtk.Image get_image(int image_size) {
        return IconManager.lookup_image("pathbar_%s".printf(this.to_string()), image_size);
    }

    public static PathbarStyle[] all() {
		return { COMPACT, ARROWS, BUTTONS, FLAT_BUTTONS };
	}
}

public class PathbarStyleMenu : Gtk.Menu {

	private Gtk.LinkButton button;

	public PathbarStyleMenu(Gtk.LinkButton _button){

		//log_debug("PathbarStyleMenu()");

		button = _button;

		reserve_toggle_size = false;
		
		build_menu();

		//log_debug("PathbarStyleMenu(): exit");
	}

	public void build_menu(){

		var sg_label = new Gtk.SizeGroup(Gtk.SizeGroupMode.HORIZONTAL);
		var sg_image = new Gtk.SizeGroup(Gtk.SizeGroupMode.HORIZONTAL);
		
		foreach(var style in PathbarStyle.all()){

			var item = add_item(this, style.to_string(), style.get_image(380), sg_label, sg_image);

			item.activate.connect (() => {
				App.pathbar_style = style;
				App.main_window.refresh_pathbars();
				button.label = style.to_string();
			});
		}

		this.show_all();
	}
	
	public Gtk.MenuItem add_item(Gtk.Menu menu, string text, Gtk.Image image,
		Gtk.SizeGroup sg_label, Gtk.SizeGroup sg_icon){

		var menu_item = new Gtk.MenuItem();
		menu.append(menu_item);
			
		var box = new Gtk.Box(Orientation.HORIZONTAL, 3);
		menu_item.add(box);

		// label
		var label = new Gtk.Label(text);
		label.xalign = 0.0f;
		//label.margin_right = 6;
		box.add(label);
		sg_label.add_widget(label);
		
		// image
		box.add(image);
		sg_icon.add_widget(image);

		return menu_item;
	}

	public bool show_menu(Gdk.EventButton? event) {

		if (event != null) {
			this.popup (null, null, null, event.button, event.time);
		}
		else {
			this.popup (null, null, null, 0, Gtk.get_current_event_time());
		}

		return true;
	}
}


