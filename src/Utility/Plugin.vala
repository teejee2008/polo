
/*
 * Plugin.vala
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

public class Plugin : GLib.Object{
	
	public string command = "";
	public string name = "";
	
	public string app_version = "";
	public int cli_version = 0;
	public int cli_version_min = 0;
	
	public bool available = false;

	public Plugin(string cmd, string _name, int _cli_version_min){
		command = cmd;
		name = _name;
		cli_version_min = _cli_version_min;
	}

	public bool check_availablity(){

		available = cmd_exists(command);

		if (available){
			
			string std_out, std_err;
			exec_sync("%s --version".printf(command), out std_out, out std_err);
			if (std_out.length > 0){
				var arr = std_out.split(":");
				if (arr.length == 2){
					app_version = arr[0].strip();
					cli_version = int.parse(arr[1].strip());
				}
				else{
					available = false;
				}
			}
			else{
				available = false;
			}
		}
		
		return available;
	}

	public bool check_version(){
		return (cli_version >= cli_version_min);
	}
}
