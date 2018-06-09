/*
 * PoloGtk.vala
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

using GLib;
using Gtk;
using Gee;
using Json;

using TeeJee.Logging;
using TeeJee.FileSystem;
using TeeJee.JsonHelper;
using TeeJee.ProcessHelper;
using TeeJee.GtkHelper;
using TeeJee.System;
using TeeJee.Misc;

public class PoloGtk : GLib.Object {

	public static int main (string[] args) {
		set_locale();

		Gtk.init(ref args);

		init_tmp(AppShortName);

		LOG_TIMESTAMP = true;

		parse_arguments(args);
		
		App = new Main(args, true);
		
		parse_arguments(args);

		//Device.test_all();
		//exit(0);

		new MainWindow();
		//window.destroy.connect(Gtk.main_quit);

		//start event loop
		Gtk.main();

		App.exit_app();

		return 0;
	}

	private static void set_locale() {
		Intl.setlocale(GLib.LocaleCategory.MESSAGES, AppShortName);
		Intl.textdomain(GETTEXT_PACKAGE);
		Intl.bind_textdomain_codeset(GETTEXT_PACKAGE, "utf-8");
		Intl.bindtextdomain(GETTEXT_PACKAGE, LOCALE_DIR);
	}

	public static bool parse_arguments(string[] args) {

		bool force_new_window = false;
		
		//parse options
		for (int k = 1; k < args.length; k++) // Oth arg is app path
		{
			switch (args[k].down()) {
			
			case "--debug":
				LOG_DEBUG = true;
				break;

			case "--trace":
				LOG_TRACE = true;
				break;

			case "--new-window":
				force_new_window = true;
				break;

			case "--help":
			case "--h":
			case "-h":
				log_msg(help_message());
				exit(0);
				return true;

			default:
				// check if argument is a directory
				if (!dir_exists(args[k])) {
					log_error(_("File not found") + ": %s".printf(args[k]));
					log_msg(help_message());
					exit(1);
					return false;
				}

				if (App != null){
					// add to list
					App.cmd_files.add(args[k]);
				}

				break;
			}
		}
		
		if (!force_new_window && (App != null) && (App.cmd_files.size > 0) && !App.session_lock.lock_acquired && App.single_instance_mode){

			log_msg("single instance mode: creating tasks for main instance");

			foreach(string file_path in App.cmd_files){
				if (dir_exists(file_path)){
					string fpath = path_combine(App.app_conf_dir_path_open, random_string());
					file_write(fpath, file_path);
				}
			}

			log_msg("single instance mode: exiting");
			exit(0);
		}

		return true;
	}

	public static string help_message() {
		string msg = "\n" + AppName + " v" + AppVersion + " by Tony George (teejee2008@gmail.com)" + "\n";
		msg += "\n";
		msg += _("Syntax") + ": %s [options] <path(s)>\n".printf(AppShortName);
		msg += "\n";
		msg += _("Options") + ":\n";
		msg += "\n";
		msg += "--new-window   %s\n".printf(_("Forces new window to be opened (overrides single-instance mode)"));
		return msg;
	}
}



