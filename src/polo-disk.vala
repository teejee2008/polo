/*
 * polo-disk.vala
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

public static int main(string[] args) {

	string help_text = "Syntax: polo-disk {backup|restore} --file <disk-image> --device <device-file> --user <user> [--gz|--bz2]\n";
	
	string command = "";

	string format = "";

	string image_file = "";

	string device = "";

	string username = "";

	//parse options
	for (int k = 1; k < args.length; k++) {
		
		switch (args[k].down()) {

		case "backup":
		case "restore":
			command = args[k].down();
			break;
			
		case "--gz":
			format = "gz";
			break;

		case "--bzip2":
			format = "bz2";
			break;

		case "--file":
			k++;
			if (k < args.length){
				image_file = args[k];
			}
			else{
				stderr.printf("E: %s\n".printf("Image file not specified"));
				return 1;
			}
			break;

		case "--device":
			k++;
			if (k < args.length){
				device = args[k];
			}
			else{
				stderr.printf("E: %s\n".printf("Device not specified"));
				return 1;
			}
			break;

		case "--user":
			k++;
			if (k < args.length){
				username = args[k];
			}
			else{
				stderr.printf("E: %s\n".printf("User not specified"));
				return 1;
			}
			break;

		case "--h":
		case "--help":
			stdout.printf(help_text);
			return 0;
		}
	}

	// checks ---------------------------------------

	if (device.length == 0){
		stderr.printf("E: %s\n".printf("Device not specified"));
		return 1;
	}
	
	if (image_file.length == 0){
		stderr.printf("E: %s\n".printf("Image file not specified"));
		return 1;
	}

	if ((command == "restore") && !file_exists(image_file)){
		stderr.printf("E: %s: %s\n".printf("File not found", image_file));
		return 1;
	}

	if (!file_exists(device)){
		stderr.printf("E: %s: %s\n".printf("Device not found", device));
		return 1;
	}
	
	stdout.printf("Device: %s\n".printf(device));

	// execute ---------------------------------------------
	
	string cmd = "";

	switch(command){
		
	case "backup":

		if (format.length == 0){ // not specified by user

			format = get_format_from_file_name(image_file);

			if (format.length == 0){ // not evident from file name

				format = "img"; // use default
			}
		}
	
		cmd = "dd if=%s conv=sync,noerror bs=64K status=progress".printf(device);
		
		switch(format){
		case "gz":

			if (cmd_exists("pigz")){
				cmd += " | pigz";
			}
			else if (cmd_exists("gz")){
				cmd += " | gz";
			}
			else{
				stderr.printf("E: %s: %s\n".printf("Missing utility", "gz, pigz"));
				return 1;
			}
			
			break;
			
		case "bz2":

			if (cmd_exists("pigz")){
				cmd += " | pbzip2";
			}
			else if (cmd_exists("gz")){
				cmd += " | bzip2";
			}
			else{
				stderr.printf("E: %s: %s\n".printf("Missing utility", "bzip2, pbzip2"));
				return 1;
			}
			
			break;
		}

		string extension = "." + format;
		if (!image_file.down().has_suffix(extension)){
			image_file += extension;
		}
		stdout.printf("File: %s\n".printf(image_file));
		
		cmd += " > '%s'".printf(escape_single_quote(image_file));

		stdout.printf(cmd + "\n");
		
		Posix.system(cmd);

		if (file_exists(image_file)){
			cmd = "chown -v %s:%s '%s'".printf(username, username, escape_single_quote(image_file));
			Posix.system(cmd);
		}
		
		break;
		
	case "restore":

		format = get_format_from_file_name(image_file);

		if (format.length == 0){
			stderr.printf("E: %s (%s)\n".printf("File format not supported", "Supports: .gz, .bz2, .img"));
			return 1;
		}

		stdout.printf("Format: %s\n".printf(format));
		stdout.printf("File: %s\n".printf(image_file));
		
		cmd = "";

		switch(format){
		case "gz":

			if (cmd_exists("pigz")){
				cmd += "pigz -dc";
			}
			else if (cmd_exists("gz")){
				cmd += "gz -dc";
			}
			else{
				stderr.printf("E: %s: %s\n".printf("Missing utility", "gz, pigz"));
				return 1;
			}

			cmd += " '%s' | ".printf(escape_single_quote(image_file));

			break;
			
		case "bz2":

			if (cmd_exists("pigz")){
				cmd += "pbzip2 -dc".printf();
			}
			else if (cmd_exists("gz")){
				cmd += "bzip2 -dc";
			}
			else{
				stderr.printf("E: %s: %s\n".printf("Missing utility", "bzip2, pbzip2"));
				return 1;
			}

			cmd += " '%s' | ".printf(escape_single_quote(image_file));
			
			break;
		}

		cmd += "dd of=%s conv=sync bs=64K status=progress".printf(device);

		stdout.printf(cmd + "\n");
		
		Posix.system(cmd);
		break;
	}

	return 1;
}

public string get_format_from_file_name(string file_name){

	string format = "";
	
	if (file_name.down().has_suffix(".gz")){
		format = "gz";
	}
	else if (file_name.down().has_suffix(".bz2")){
		format = "bz2";
	}
	else if (file_name.down().has_suffix(".img")){
		format = "img";
	}

	return format;
}
