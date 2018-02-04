/*
 * TreeViewColumnManager.vala
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

using TeeJee.Logging;
using TeeJee.FileSystem;
using TeeJee.JsonHelper;
using TeeJee.ProcessHelper;
using TeeJee.System;
using TeeJee.Misc;
using TeeJee.GtkHelper;
using Gtk;

public class TreeViewColumnManager : GLib.Object {
	
	private Gtk.TreeView treeview;
	private Gee.HashMap<string,Gtk.TreeViewColumn> columns;
	private string columns_required = "";
	private string columns_required_end = "";
	private string columns_default = "";
	private string columns_all = "";
	
	public TreeViewColumnManager(TreeView _treeview, string _columns_required, string _columns_required_end, string _columns_default, string _columns_all){
		treeview = _treeview;

		columns = new Gee.HashMap<string,Gtk.TreeViewColumn>();
		foreach(var col in treeview.get_columns()){
			columns[col.get_data<string>("name")] = col;
		}

		columns_required = _columns_required;
		columns_default = _columns_default;
		columns_all = _columns_all;
		columns_required_end = _columns_required_end;
	}

	public string get_columns(){
		string s = "";
		foreach(var col in treeview.get_columns()){
			if (col.visible){
				string name = col.get_data<string>("name");
				if (s.length > 0){
					s += ",";
				}
				s += name;
			}
		}
		//log_debug("get_current_column_string: %s".printf(s));
		return s;
	}

	public void set_columns(string selected_columns){

		log_debug("set_columns(): %s".printf(selected_columns));

		var list = new Gee.ArrayList<string>();

		var list_req_end = new Gee.ArrayList<string>();
		foreach(var item in columns_required_end.split(",")){
			list_req_end.add(item);
		}

		// add required columns -------------------------

		Gtk.TreeViewColumn? column = null;
		Gtk.TreeViewColumn? last_column = null;
		
		foreach(string name in columns_required.split(",")){

			// skip ending columns
			if (list_req_end.contains(name)){ continue; }

			// skip existing
			if (list.contains(name)){ continue; }

			// show column
			if (columns.has_key(name)){

				//log_debug("set_columns: show: %s".printf(name));
				
				column = columns[name];
				column.visible = true;
				treeview.move_column_after(column, last_column);
				last_column = column;
				
				list.add(name);
			}
		}

		// add optional selected columns --------------------
		
		foreach(string name in selected_columns.split(",")){

			// skip ending columns
			if (list_req_end.contains(name)){ continue; }

			// skip existing
			if (list.contains(name)){ continue; }

			// show column
			if (columns.has_key(name)){
				
				//log_debug("set_columns: show: %s".printf(name));
				
				column = columns[name];
				column.visible = true;
				treeview.move_column_after(column, last_column);
				last_column = column;
				
				list.add(name);
			}
		}

		// hide all columns not in list

		foreach(string name in columns_all.split(",")){
			
			// skip ending columns
			if (list_req_end.contains(name)){ continue; }

			// skip existing
			if (list.contains(name)){ continue; }

			// hide column
			if (columns.has_key(name)){

				//log_debug("set_columns: hide: %s".printf(name));
				
				column = columns[name];
				column.visible = false;
				treeview.move_column_after(column, last_column);
				last_column = column;

				list.add(name);
			}
		}

		// move required_end columns after other columns

		foreach(string name in list_req_end){
			
			if (columns.has_key(name)){

				column = columns[name];
				column.visible = true;
				treeview.move_column_after(column, last_column);
				last_column = column;
			}
		}
		

		/* spacer can be reordered by dragging other columns after it,
		 * (even though we have set reorderable = false for spacer column)
		 * */
	}

	public Gee.ArrayList<TreeViewColumn> get_all_columns(){
		
		var list = new Gee.ArrayList<TreeViewColumn>();
		
		if (columns_all.length > 0){
			foreach(string name in columns_all.split(",")){
				list.add(columns[name]);
			}
		}
		else{
			foreach(var item in columns.values){
				 list.add(item);
			}
		}
		
		return list;
	}

	public void add_column(string name){
		
		log_debug("add_column(): %s".printf(name));
		
		if (columns.has_key(name)){
			var col = columns[name];
			col.visible = true;
		}
	}

	public void remove_column(string name){

		log_debug("remove_column(): %s".printf(name));
		
		if (columns.has_key(name)){
			var col = columns[name];
			col.visible = false;
		}
	}

	public void reset_columns(){
		log_debug("reset_columns()");
		set_columns(columns_default);
	}
}
