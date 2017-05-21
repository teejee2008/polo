
/*
 * ExtendedTreeView.vala
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
using TeeJee.Logging;

public class ExtendedTreeView : Gtk.TreeView{
	
	private Gtk.TreePath? blocked_selection_path = null;

	public ExtendedTreeView (){
		/* Allow multiple selections */
		//Gtk.TreeSelection selection = this.get_selection ();
		//selection.set_mode (Gtk.SelectionMode.MULTIPLE);

		//this.button_press_event.connect (on_button_press_event);
		//this.button_release_event.connect (on_button_release_event);
	}

	private bool on_button_press_event (Gdk.EventButton event){

		log_debug("on_button_press_event");
		
		/*if (event.button == 1)
			return block_selection (event);*/

		bool control_pressed = (event.state & Gdk.ModifierType.CONTROL_MASK) != 0;
		bool shift_pressed = (event.state & Gdk.ModifierType.SHIFT_MASK) != 0;
		bool mouse_left_pressed = (event.state & Gdk.ModifierType.BUTTON1_MASK) != 0;

		if (control_pressed){ log_debug("control_pressed"); }
		if (shift_pressed){ log_debug("shift_pressed"); }
		if (mouse_left_pressed){ log_debug("mouse_left_pressed"); }
		
		if (control_pressed){
			//set_as_drag_source(true);
			this.get_selection().set_select_function ((sel, mod, path, cursel) => { return false; });
			//return block_selection(event);
		}

		//if (control_pressed){
		//	return true;
		//}
		
		/*switch (keyval) {
        case Gdk.Key.D:
			
			return true;
			break;
		}*/
		

		// not handled
		return false;
	}

	private bool on_button_release_event (Gdk.EventButton event){

		log_debug("on_button_release_event");
		
		/* re-enable selection */
		Gtk.TreeSelection selection = this.get_selection ();
		selection.set_select_function ((sel, mod, path, cursel) => { return true; });

		Gtk.TreePath? path;
		Gtk.TreeViewColumn? column;
		bool valid = this.get_path_at_pos ((int)event.x, (int)event.y, out path, out column, null, null);

		if (valid &&
		  this.blocked_selection_path != null &&
		  path.compare (this.blocked_selection_path) == 0 && // equal paths
		  !(event.x == 0.0 && event.y == 0.0)) // a strange case
		{
			this.set_cursor (path, column, false);
		}
		
		this.blocked_selection_path = null;

		// not handled
		return false;
	}
	
	private bool block_selection (Gdk.EventButton event){
		
		/* Here we intercept mouse clicks on selected items, so that we can
		 drag multiple items without the click selecting only one item. */

		Gtk.TreePath? path;
		bool valid = this.get_path_at_pos ((int)event.x, (int)event.y, out path, null, null, null);
		Gtk.TreeSelection selection = this.get_selection ();

		if (valid &&
		  event.type == Gdk.EventType.BUTTON_PRESS &&
		  ! (bool)(event.state & (Gdk.ModifierType.CONTROL_MASK | Gdk.ModifierType.SHIFT_MASK)) &&
		  selection.path_is_selected (path))
		{
			/* Disable the selection */
			selection.set_select_function ((sel, mod, path, cursel) => { return false; });
			this.blocked_selection_path = path;
		}

		// not handled
		return false;
	}
}

