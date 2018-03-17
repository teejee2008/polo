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

	string fstype = "";

	string username = "";

	check_admin_access();

	//parse options
	for (int k = 1; k < args.length; k++) {
		
		switch (args[k].down()) {

		case "backup":
		case "restore":
		case "eject":
		case "format":
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

		case "--fstype":
			k++;
			if (k < args.length){
				fstype = args[k];
			}
			else{
				stderr.printf("E: %s\n".printf("File system type not specified"));
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
	
	if (((command == "restore")||(command == "backup")) && image_file.length == 0){
		stderr.printf("E: %s\n".printf("Image file not specified"));
		return 1;
	}

	if ((command == "restore") && !file_exists(image_file)){
		stderr.printf("E: %s: %s\n".printf("File not found", image_file));
		return 1;
	}

	if ((command == "format") && (fstype.length == 0)){
		stderr.printf("E: %s\n".printf("File system type not specified"));
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

		// unmount ------------------------------------

		if (device_is_mounted(device)){

			cmd = "umount %s".printf(device);

			stdout.printf(cmd + "\n");
			
			int status = Posix.system(cmd);

			if (status != 0){
				stderr.printf("E: Failed to unmount device\n");
				exit(1);
			}
		}
	
		if (format.length == 0){ // not specified by user

			format = get_file_format_from_file_name(image_file);

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

		// unmount ------------------------------------

		if (device_is_mounted(device)){

			cmd = "umount %s".printf(device);

			stdout.printf(cmd + "\n");
			
			int status = Posix.system(cmd);

			if (status != 0){
				stderr.printf("E: Failed to unmount device\n");
				exit(1);
			}
		}
		
		format = get_file_format_from_file_name(image_file);

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

	case "format":
	
		format_device(device, fstype, username);
		break;

	case "eject":

		//http://www.redhatgeek.com/linux/remove-a-disk-from-redhatcentos-linux-without-rebooting-the-system

		//cmd = "umount %s?*".printf(device);

		cmd = "ls %s?* | xargs -n1 umount -l".printf(device);
		
		string kname = device.replace("/dev/","").strip();

		// mark offline
		string sysfile = "/sys/block/%s/device/state".printf(kname);
		//file_write(sysfile, "offline", true);
		cmd = "echo 'offline' > %s".printf(sysfile);
		Posix.system(cmd);

		// delete entries from system
		sysfile = "/sys/block/%s/device/delete".printf(kname);
		//file_write(sysfile, "1", true);
		cmd = "echo '1' > %s".printf(sysfile);
		Posix.system(cmd);
		break;
	}

	return 0;
}

public bool format_device(string device, string fstype, string username){

	// check --------------------------------------

	if (!fstype_available(fstype)){
		stderr.printf("E: Missing dependencies\n");
		stderr.printf("E: Utility packages are not installed for selected file system format\n");
		exit(1);
	}
	
	// unmount ------------------------------------

	if (device_is_mounted(device)){

		string cmd = "umount %s".printf(device);

		stdout.printf(cmd + "\n");
		
		int status = Posix.system(cmd);

		if (status != 0){
			stderr.printf("E: Failed to unmount device\n");
			exit(1);
		}
	}
	
	// format ------------------------------------

	thread_sleep(100);
	
	string cmd_format = fstype_command(fstype);
				
	if (cmd_format.length == 0){
		stderr.printf("E: Failed to set command\n");
		exit(1);
	}

	string cmd = "%s %s".printf(cmd_format, device);

	stdout.printf(cmd + "\n");
	
	int status = Posix.system(cmd);

	if (status != 0){
		stderr.printf("E: Failed to unmount device\n");
		exit(1);
	}

	// set owner ----------------------------------

	if (fstype in new string[]{ "exfat", "fat16", "fat32" } ){
		// setting owner not supported
	}
	else{
		set_device_owner(device, username);
	}

	return true;
}

public void set_device_owner(string device, string username){

	string mpath = get_temp_file_path(false);
	dir_create(mpath);

	// mount ------------------------------------

	thread_sleep(100);
	
	string cmd = "mount %s '%s'".printf(device, escape_single_quote(mpath));

	stdout.printf(cmd + "\n");
	
	int status = Posix.system(cmd);

	if (status != 0){
		stderr.printf("E: Failed to mount device\n");
		exit(0); // exit without error
	}

	// chown ------------------------------------

	thread_sleep(100);
	
	cmd = "chown %s:%s '%s'".printf(username, username, escape_single_quote(mpath));

	stdout.printf(cmd + "\n");
	
	status = Posix.system(cmd);

	if (status != 0){
		stderr.printf("E: Failed to set owner\n");
		exit(0); // exit without error
	}

	// unmount ------------------------------------

	thread_sleep(100);
	
	cmd = "umount '%s'".printf(escape_single_quote(mpath));

	stdout.printf(cmd + "\n");
	
	status = Posix.system(cmd);

	if (status != 0){
		stderr.printf("E: Failed to unmount device\n");
		exit(0); // exit without error
	}
}

public string get_file_format_from_file_name(string file_name){

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

public bool fstype_available(string fmt){

	string cmd = "";
			
	switch(fmt){
	case "btrfs":
	case "ext2":
	case "ext3":
	case "ext4":
	case "f2fs":
	case "jfs":
	case "nilfs2":
	case "ntfs":
	case "ufs":
	case "xfs":
		cmd += "mkfs.%s".printf(fmt);
		break;

	case "exfat":
		cmd += "mkfs.exfat";
		break;
		
	case "fat16":
		cmd += "mkfs.fat";
		break;

	case "fat32":
		cmd += "mkfs.fat";
		break;

	case "hfs":
		cmd += "hformat";
		break;

	case "hfs+":
		cmd += "mkfs.hfsplus";
		break;

	case "reiser4":
		cmd += "mkfs.reiser4";
		break;
	
	case "reiserfs":
		cmd += "mkreiserfs";
		break;
	}

	return cmd_exists(cmd);
}

public string fstype_command(string fmt){

	string cmd = "";
	
	switch(fmt){
	case "ext2":
	case "ext3":
	case "ext4":
		cmd += "mkfs.%s -F -L \"\"".printf(fmt);
		break;
		
	case "f2fs":
		cmd += "mkfs.%s -l \"\"".printf(fmt);
		break;
		
	case "ufs":
		cmd += "mkfs.%s".printf(fmt);
		break;

	case "jfs":
		cmd += "mkfs.%s -q -L \"\"".printf(fmt);
		break;
		
	case "btrfs":
		cmd += "mkfs.%s -f -L \"\"".printf(fmt);
		break;
		
	case "xfs":
		cmd += "mkfs.%s -f -L \"\"".printf(fmt);
		break;

	case "nilfs2":
		cmd += "mkfs.%s -f -v -L \"\"".printf(fmt);
		break;

	case "ntfs":
		cmd += "mkfs.%s -Q -v -F -L \"\"".printf(fmt);
		break;

	case "exfat":
		cmd += "mkfs.exfat";
		break;
		
	case "fat16":
		cmd += "mkfs.fat -F16 -v";
		break;

	case "fat32":
		cmd += "mkfs.fat -F32 -v";
		break;

	case "hfs":
		cmd += "hformat -f";
		break;

	case "hfs+":
		cmd += "mkfs.hfsplus";
		break;

	case "reiser4":
		cmd += "mkfs.reiser4 --force --yes --label \"\"";
		break;
	
	case "reiserfs":
		cmd += "mkreiserfs -f -f --label \"\"";
		break;
	}

	return cmd.strip();
}

