
/*
 * XdgUserDirectories.vala
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

public class XdgUserDirectories : GLib.Object {
	
	public string user_name = "";
	public string user_home = "";
	public string user_desktop = "";
	public string user_documents = "";
	public string user_pictures = "";
	public string user_music = "";
	public string user_videos = "";
	public string user_downloads = "";
	public string user_templates = "";
	public string user_public = "";

	public const string config_file_template = "%s/.config/user-dirs.dirs";
	
	// constructors
	
	public XdgUserDirectories(string _user_name){
		
		user_name = _user_name;
		user_home = get_user_home(user_name);

		read_directory_paths();
	}

	public void read_directory_paths(){

		var config_file = config_file_template.printf(user_home);
		
		// set defaults
		user_desktop = path_combine(user_home, "Desktop");
		user_documents = path_combine(user_home, "Documents");
		user_pictures = path_combine(user_home, "Pictures");
		user_music = path_combine(user_home, "Music");
		user_videos = path_combine(user_home, "Videos");
		user_downloads = path_combine(user_home, "Downloads");
		user_templates = path_combine(user_home, "Templates");
		user_public = path_combine(user_home, "Public");

		if (file_exists(config_file)){
			
			log_debug("Reading xdg-dirs: %s".printf(config_file));

			Regex regex_home = null;
			Regex regex_abs = null;
			
			try{
				regex_home = new Regex("""^(.*)="\$HOME\/(.*)"$""");
				regex_abs = new Regex("""^(.*)="(\/.*)"$""");
			}
			catch (Error e) {
				log_error (e.message);
			}

			foreach(var line in file_read(config_file).split("\n")){
			
				MatchInfo match;

				string key = "";
				string path = "";
					
				if (regex_home.match(line, 0, out match)) {
					
					key = match.fetch(1).up();
					path = match.fetch(2); // do not strip

					if (path.strip().length > 0){ // strip and check length
						path = path_combine(user_home, path);
					}
					else{
						continue;
					}
				}
				else if (regex_abs.match(line, 0, out match)) {
					
					key = match.fetch(1).up();
					path = match.fetch(2); // do not strip
				}
				else{
					continue;
				}

				switch(key){
				case "XDG_DESKTOP_DIR":
					user_desktop = path;
					break;
				case "XDG_DOCUMENTS_DIR":
					user_documents = path;
					break;
				case "XDG_DOWNLOAD_DIR":
					user_downloads = path;
					break;
				case "XDG_MUSIC_DIR":
					user_music = path;
					break;
				case "XDG_PICTURES_DIR":
					user_pictures = path;
					break;
				case "XDG_PUBLICSHARE_DIR":
					user_public = path;
					break;
				case "XDG_TEMPLATES_DIR":
					user_templates = path;
					break;
				case "XDG_VIDEOS_DIR":
					user_videos = path;
					break;
				}
			}
		}
		else{
			log_error(_("File not found") + ": %s".printf(config_file));
		}
	}
}


