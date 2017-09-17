/*
 * gtk3-version.vala
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

public static int main(string[] args) {

	string help_text = "Syntax: gtk3-version [--major] [--minor] [--micro] [--major-minor]\n";
	
    if (args.length == 1) {
		// no args given
		stdout.printf("%ld.%ld.%ld\n".printf(Gtk.get_major_version(), Gtk.get_minor_version(), Gtk.get_micro_version()));
		return 0;
	}

	//parse options
	for (int k = 1; k < args.length; k++) // Oth arg is app path
	{
		switch (args[k].down()) {
		case "--major":
			stdout.printf("%ld\n".printf(Gtk.get_major_version()));
			return 0;
		case "--minor":
			stdout.printf("%ld\n".printf(Gtk.get_minor_version()));
			return 0;
		case "--micro":
			stdout.printf("%ld\n".printf(Gtk.get_micro_version()));
			return 0;
		case "--major-minor":
			stdout.printf("%ld.%ld\n".printf(Gtk.get_major_version(), Gtk.get_minor_version()));
			return 0;
		case "--h":
		case "--help":
			stdout.printf(help_text);
			return 0;
		}
	}

	stdout.printf(help_text);
	return 1;
}
