
/*
 * GtkTheme.vala
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

using TeeJee.Logging;
using TeeJee.FileSystem;
using TeeJee.ProcessHelper;
using TeeJee.Misc;
using TeeJee.GtkHelper;
using TeeJee.System;

public class GtkTheme : GLib.Object {
	
	public string path = "";
	public string name = "";

	public static string user_name;
	public static string user_home;
	public static string preferred_theme = "Arc-Darker-Polo";
	public static string preferred_theme_alt = "Arc-Darker";
	
	public static Gee.ArrayList<GtkTheme> themes = new Gee.ArrayList<GtkTheme>();

	// constructors
	
	public GtkTheme(string _name, string _path){
		
		name = _name;
		path = _path;
	}

	// static methods
	
	public static void query(string _user_name){

		user_name = _user_name;
		user_home = get_user_home(user_name);

		themes = new Gee.ArrayList<GtkTheme>();
		
		query_from_path("/usr/share/themes"); 
		query_from_path("%s/.local/share/themes".printf(user_home)); 
		query_from_path("%s/.themes".printf(user_home));
		
		themes.sort((a,b)=>{
			return strcmp(a.name, b.name);
		});
		
		log_debug("GtkTheme: current: %s".printf(get_gtk_theme()));
	}
	
	private static void query_from_path(string base_path){
		
		var dir = new FileItem.from_path(base_path);
		dir.query_children(2);
		
		foreach(var theme_dir in dir.children.values){
			if (theme_dir.has_child("gtk-3.0")){
				themes.add(new GtkTheme(theme_dir.file_name, theme_dir.file_path));
			}
		}
	}
	
	public static bool has_theme(string theme_name){
		
		foreach(var theme in GtkTheme.themes){
			
			if (theme.name == theme_name){
				
				return true;
			}
		}
		
		return false;
	}
	
	public static string get_gtk_theme(){
		
		var settings = Gtk.Settings.get_default();
		return settings.gtk_theme_name;
	}
	
	public static void set_gtk_theme(string theme_name){
		
		var settings = Gtk.Settings.get_default();
		
		settings.gtk_theme_name = theme_name;
	}
	
	public static void set_gtk_theme_preferred(){
		
		bool found = false;
		
		log_debug("GtkTheme: set_gtk_theme_preferred(): %s".printf(preferred_theme));
		
		foreach(var theme in GtkTheme.themes){
			
			if (theme.name == preferred_theme){
				
				log_debug("GtkTheme: set_gtk_theme_preferred(): found");
				set_gtk_theme(theme.name);
				found = true;
			}
		}
		
		if (!found){
			
			log_debug("GtkTheme: set_gtk_theme_preferred(): alt: %s".printf(preferred_theme_alt));
			
			foreach(var theme in GtkTheme.themes){
				
				if (theme.name == preferred_theme_alt){
					
					log_debug("GtkTheme: set_gtk_theme_preferred(): found");
					set_gtk_theme(theme.name);
				}
			}
		}
	}
}


