
/*
 * Shell.vala
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
using TeeJee.ProcessHelper;

public class Shell : GLib.Object{

	public string cmd = "";
	public string cmd_path = "";
	public string display_name = "";
	public bool exists = true;

	public static Gee.HashMap<string,Shell> shells = new Gee.HashMap<string,Shell>();

	public static void query_shells(){
		
		var shell = new Shell("bash", _("Bourne again shell (bash)"));
		shells[shell.cmd] = shell;

		shell = new Shell("fish", _("Friendly interactive shell (fish)"));
		shells[shell.cmd] = shell;

		shell = new Shell("ksh", _("Korn shell (ksh)"));
		shells[shell.cmd] = shell;

		shell = new Shell("tcsh", _("tcsh shell (tcsh)"));
		shells[shell.cmd] = shell;

		shell = new Shell("csh", _("C shell (csh)"));
		shells[shell.cmd] = shell;

		shell = new Shell("zsh", _("Z shell (zsh)"));
		shells[shell.cmd] = shell;

		shell = new Shell("sh", _("Default shell (sh)"));
		shells[shell.cmd] = shell;

		shell = new Shell("ash", _("Almquist shell (ash)"));
		shells[shell.cmd] = shell;

		shell = new Shell("dash", _("Debian Almquist shell (dash)"));
		shells[shell.cmd] = shell;
		
		var shells_file = "/etc/shells";
		
		if (file_exists(shells_file)){
			
			foreach(var line in file_read(shells_file).split("\n")){

				if (line.strip().has_prefix("#")){ continue; }
				if (line.strip().length == 0){ continue; }
				
				var command = file_basename(line);
				
				if (shells.has_key(command)){
					shells[command].cmd_path = line;
				}
				else{
					shell = new Shell(command, line);
					shell.cmd_path = line;
					shells[shell.cmd] = shell;
				}
			}
		}
		else{
			foreach(var sh in shells.values){
				string path = get_cmd_path(sh.cmd);
				if ((path != null) && (path.length > 0)){
					sh.cmd_path = path;
				}
			}
		}
	}

	public Shell(string command, string description){
		cmd = command;
		display_name = description;
	}

	public static Gee.ArrayList<Shell> get_installed_shells(){

		if (shells.size == 0){
			query_shells();
		}
		
		var list = new Gee.ArrayList<Shell>();
		foreach(var shell in shells.values){
			if (shell.cmd_path.length > 0){
				list.add(shell);
			}
		}
		list.sort((a,b)=>{ return strcmp(a.cmd, b.cmd); });

		return list;
	}
}


