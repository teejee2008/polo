
/*
 * Device.vala
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

/* Functions and classes for handling disk partitions */

using TeeJee.Logging;
using TeeJee.FileSystem;
using TeeJee.ProcessHelper;
using TeeJee.GtkHelper;
using TeeJee.Misc;

public class Device : GLib.Object, Gee.Comparable<Device>{

	/* Class for storing disk information */

	public static double KB = 1000;
	public static double MB = 1000 * KB;
	public static double GB = 1000 * MB;

	public static double KiB = 1024;
	public static double MiB = 1024 * KiB;
	public static double GiB = 1024 * MiB;

	public string device = "";
	public string name = "";
	public string kname = "";
	public string pkname = "";
	public string pkname_toplevel = "";
	public string mapped_name = "";
	public string uuid = "";
	public string label = "";
	public string partuuid = "";
	public string partlabel = "";
	
	public int major = -1;
	public int minor = -1;

	public string device_mapper = "";
	public string device_by_uuid = "";
	public string device_by_label = "";
	public string device_by_partuuid = "";  // gpt only
	public string device_by_partlabel = ""; // gpt only

	public string type = ""; // disk, part, crypt, loop, rom, lvm
	public string fstype = ""; // iso9660, ext4, btrfs, ...

	public int order = -1;

	public string vendor = "";
	public string model = "";
	public string serial = "";
	public string revision = "";

	public bool removable = false;
	public bool read_only = false;

	public int64 size_bytes = 0;
	public int64 used_bytes = 0;
	public int64 available_bytes = 0;

	//public string used_percent = "";
	public string dist_info = "";
	public Gee.ArrayList<MountEntry> mount_points = new Gee.ArrayList<MountEntry>();
	public Gee.ArrayList<string> symlinks = new Gee.ArrayList<string>();

	public Device? parent = null;
	public Gee.ArrayList<Device> children = new Gee.ArrayList<Device>();

	private static string lsblk_version = "";
	private static bool lsblk_is_ancient = false;

	private static Gee.ArrayList<Device> device_list;

	private static DeviceMonitor? monitor;

	public static bool use_gio;

	// static -----------------------------
	
	public static void init(){

		log_debug("Device.init()");
		
		get_block_devices();
		
		get_monitor();

		use_gio = cmd_exists("gio");

		log_debug("Device.init(): exit");
	}
	
	public static DeviceMonitor get_monitor(){
		
		if (monitor != null){ return monitor; }

		log_debug("Device.get_monitor()");
		
		var monitor = DeviceMonitor.get_monitor();

		monitor.changed.connect(()=>{
			log_debug("Device: get_monitor(): monitor_changed");
			//get_block_devices_using_lsblk();
			get_block_devices();
		});

		log_debug("Device.get_monitor(): exit");
		
		return monitor;
	}
	
	public static void test_lsblk_version(){

		if ((lsblk_version != null) && (lsblk_version.length > 0)){
			return;
		}

		string std_out, std_err;
		int status = exec_sync("lsblk --bytes --pairs --output HOTPLUG,PKNAME,VENDOR,SERIAL,REV", out std_out, out std_err);
		if (status == 0){
			lsblk_version = std_out;
			lsblk_is_ancient = false;
		}
		else{
			lsblk_version = "ancient";
			lsblk_is_ancient = true;
		}
	}

	public static Gee.ArrayList<Device> get_devices(){
		if (device_list == null){
			get_block_devices();
		}
		
		return device_list;
	}

	public int compare_to(Device b){

		var a = this;

		// list loop devices after other types ----------------------
		
		if (a.kname.has_prefix("loop") && !b.kname.has_prefix("loop")){
			return 1;
		}
		else if (!a.kname.has_prefix("loop") && b.kname.has_prefix("loop")){
			return -1;
		}
		else {

			// list internal disks before removable disks ----------
			
			if (a.removable && !b.removable){
				return 1;
			}
			else if (!a.removable && b.removable){
				return -1;
			}
			else {

				// use numeric sorting for numbered partitions --------------
		
				var match_a = regex_match("""^([a-zA-Z]*)([0-9]+)$""", a.kname);
					
				var match_b = regex_match("""^([a-zA-Z]*)([0-9]+)$""", b.kname);

				if ((match_a != null) && (match_b != null)){
					
					if (match_a.fetch(1) == match_b.fetch(1)){

						return int.parse(match_a.fetch(2)) - int.parse(match_b.fetch(2));
					}
					else{
						return strcmp(a.kname, b.kname);
					}
				}
				else{
					return strcmp(a.kname, b.kname);
				}
			}
		}
	}

	// instance ------------------
	
	public Device(){
		
		mount_points = new Gee.ArrayList<MountEntry>();
		symlinks = new Gee.ArrayList<string>();
		children = new Gee.ArrayList<Device>();

		test_lsblk_version();
	}

	public int64 free_bytes{
		get{
			return (used_bytes == 0) ? 0 : (size_bytes - used_bytes);
		}
	}

	public string size_formatted{
		owned get{
			return (size_bytes == 0) ? "" : format_file_size(size_bytes);
		}
	}

	public string used_formatted{
		owned get{
			return (used_bytes == 0) ? "" : format_file_size(used_bytes);
		}
	}

	public string free_formatted{
		owned get{
			return (free_bytes == 0) ? "" : format_file_size(free_bytes);
		}
	}

	public string mount_path{
		owned get{
			string mpath = "";
			foreach(var mp in mount_points){
				if ((mp.subvolume_name() == "/") || (mp.subvolume_name() == "")){
					mpath = mp.mount_point;
					break;
				}
				else{
					mpath = mp.mount_point;
				}
			}
			return mpath;
		}
	}
	
	public bool is_mounted {
		get {
			return (mount_points.size > 0);
		}
	}

	public bool is_mounted_at_path(string subvolname, string mount_path){

		foreach (var mnt in mount_points){
			if (mnt.mount_point == mount_path){
				if (subvolname.length == 0){
					return true;
				}
				else if (mnt.mount_options.contains("subvol=%s".printf(subvolname))
					|| mnt.mount_options.contains("subvol=/%s".printf(subvolname))){

					return true;
				}
			}
		}

		return false;
	}

	public bool has_linux_filesystem(){
		switch (fstype){
			case "ext2":
			case "ext3":
			case "ext4":
			case "reiserfs":
			case "reiser4":
			case "xfs":
			case "jfs":
			case "btrfs":
			case "lvm":
			case "lvm2":
			case "lvm2_member":
			case "luks":
			case "crypt":
			case "crypto_luks":
				return true;
			default:
				return false;
		}
	}

	public bool is_encrypted_partition {
		get {
			return fstype.down().contains("luks");
		}
	}

	public bool is_unlocked {
		get {
			return has_children;
		}
	}

	public bool is_on_encrypted_partition {
		get {
			return (type == "crypt");
		}
	}

	public bool is_lvm_partition(){
		return (type == "part") && fstype.down().contains("lvm2_member");
	}

	public bool is_top_level {
		get {
			//return ((type == "disk") || (type == "loop")) && (parent == null);
			return (pkname.length == 0);
		}
	}
	
	public bool has_children {
		get{
			return (children.size > 0);
		}
	}

	public Device? first_linux_child(){

		foreach(var child in children){
			if (child.has_linux_filesystem()){
				return child;
			}
		}

		return null;
	}

	public bool has_mounted_partitions {
		get {
			if (is_mounted){
				return true;
			}
			
			foreach(var child in children){
				if (child.has_mounted_partitions){
					return true;
				}
			}

			return false;
		}
	}

	public bool has_parent(){
		return (parent != null);
	}

	public bool is_system_device {
		get {
			foreach (var mnt in mount_points){
				switch (mnt.mount_point){
				case "/":
				case "/boot":
				case "/boot/efi":
				case "/home":
				case "/var":
				case "/usr":
					return true;
				default:
					if (fstype == "swap"){
						return true;
					}
					break;
				}
			}

			foreach(var child in children){
				if (child.is_system_device){
					return true;
				}
			}

			return false;
		}
	}

	public bool is_snap_volume {
		get {
			return (mount_points.size > 0) && (mount_points[0].mount_point.has_prefix("/snap/"));
		}
	}

	public bool is_swap_volume {
		get {
			return (fstype == "swap");
		}
	}

	// actions ------------------------------

	public bool unmount(Gtk.Window? parent_window = null){

		var cmd = "udisksctl unmount -b '%s'".printf(device);
		log_debug(cmd);
		string std_err, std_out;
		int status = exec_sync(cmd, out std_out, out std_err);

		if (status != 0){
			if (parent_window != null){
				string title = "Error unmounting %s".printf(device);
				//string msg = std_err;
				gtk_messagebox(title, std_err, parent_window, true);
			}
		}

		query_mount_points();
		return !is_mounted;
	}

	public bool automount(Gtk.Window? parent_window, bool show_on_success = false){

		query_mount_points();
		if (is_mounted){
			return true;
		}

		string std_out, std_err;
		int status;
		if (device.has_prefix("/dev/nbd")){

			string mpath = "/mnt/%s".printf(uuid);

			string cmd = "";
			cmd += "mkdir -p '%s' &&".printf(escape_single_quote(mpath));
			cmd += "mount '%s' '%s'".printf(device, mpath);
			log_debug(cmd);

			status = exec_script_sync(cmd, out std_out, out std_err, false, true);
		}
		else {
			var cmd = "";
			cmd += "udisksctl mount -b '%s'".printf(device);
			log_debug(cmd);

			status = exec_sync(cmd, out std_out, out std_err);
		}
		
		query_mount_points();
		
		if (is_mounted){
			string message = _("Device mounted successfully");
			string details = "%s: %s, %s: %s".printf(_("Device"), device, _("Path"), mount_points[0].mount_point);
			bool is_error = false;
			show_message(message, details, is_error, parent_window, show_on_success);
			return is_error;
		}
		else{
			string message = _("Failed to mount device");
			string details = "%s: %s\n\n%s".printf(_("Device"), device, std_err);
			bool is_error = true;
			show_message(message, details, is_error, parent_window, show_on_success);
			return is_error;
		}
	}

	public bool unlock(string mapped_name, string passphrase, Gtk.Window? parent_window, bool show_on_success = false){

		// depends: gio cryptsetup
		
		/* Unlocks a LUKS device using provided passphrase.
		 * Prompts the user for passphrase if empty.
		 * Displays a GTK prompt if parent_window is not null
		 * Otherwise prompts user on terminal with a timeout of 20 secsonds
		 * */

		log_debug("Device: unlock(): %s".printf(device));

		Device unlocked_device = null;
		string std_out = "", std_err = "";
		bool is_error = false;
		string message = "";
		string details = "";

		// check if not encrypted
		if (!is_encrypted_partition){
			log_debug("not encrypted!");
			return true;
		}

		// check if already unlocked
		query_changes();
		if (has_children){
			log_debug("has children!");
			return true;
		}

		string luks_pass = passphrase;
		string luks_name = mapped_name;

		if ((luks_name == null) || (luks_name.length == 0)){
			luks_name = "%s_crypt".printf(kname);
		}

		if (parent_window == null){

			// console mode

			if ((luks_pass == null) || (luks_pass.length == 0)){

				// prompt user on terminal and unlock, else timeout after 20 secs

				var counter = new TimeoutCounter();
				counter.kill_process_on_timeout("cryptsetup", 20, true);

				string cmd_name = use_gio ? "gio mount" : "gvfs-mount";
				string cmd = "%s -d '%s'".printf(cmd_name, device);

				log_debug(cmd);
				Posix.system(cmd);
				counter.stop();
				log_msg("");

				// no need to show messages
			}
			else{

				// use password to unlock

				string cmd_name = use_gio ? "gio mount" : "gvfs-mount";
				var cmd = "echo '%s' | %s -d '%s'\n".printf(luks_pass, cmd_name, device);

				log_debug(cmd.replace(luks_pass, "**PASSWORD**"));

				int status = exec_script_sync(cmd, out std_out, out std_err);

				switch (status){
				case 512: // invalid passphrase
					message = _("Wrong password");
					details = _("Failed to unlock device");
					show_message(message, details, true, parent_window, show_on_success);
					return false;
				}
			}
		}
		else{

			// gui mode

			if ((luks_pass == null) || (luks_pass.length == 0)){

				// show input prompt

				log_debug("Prompting user for passphrase..");

				//luks_pass = gtk_inputbox(_("Encrypted Device"),_("Enter passphrase to unlock '%s'").printf(name),parent_window, true);

				luks_pass = prompt_for_password(this, parent_window);
				
				if ((luks_pass == null) || (luks_pass.length == 0)){
					// cancelled by user
					message = _("Failed to unlock device");
					details = _("User cancelled the password prompt");
					show_message(message, details, true, null, show_on_success); // do not pass parent_window
					return false;
				}
			}

			if ((luks_pass != null) && (luks_pass.length > 0)){

				// use password to unlock

				string cmd_name = use_gio ? "gio mount" : "gvfs-mount";
				var cmd = "echo '%s' | %s -d '%s'\n".printf(luks_pass, cmd_name, device);

				log_debug(cmd.replace(luks_pass, "**PASSWORD**"));

				int status = exec_script_sync(cmd, out std_out, out std_err);

				switch (status){
				case 2: // invalid passphrase
					message = _("Invalid Passphrase");
					details = _("Failed to unlock device");
					show_message(message, details, true, parent_window, show_on_success);
					return false;
				}
			}

		}

		// check if unlocked
		query_changes();
		if (has_children){
			unlocked_device = children[0];
		}

		if (unlocked_device == null){
			message = _("Failed to unlock device");
			details = "%s: %s\n\n%s".printf(_("Device"), device, std_err);
			is_error = true;
		}
		else{
			message = _("Unlocked successfully");
			details = "%s: %s, %s: /dev/mapper/%s".printf(_("Device"), device, _("Unlocked"), unlocked_device.mapped_name);
			is_error = false;
		}

		show_message(message, details, is_error, parent_window, show_on_success);
		return (unlocked_device != null);
	}

	public static string prompt_for_password(Device dev, Gtk.Window? parent_window){

		log_debug("Device: prompt_for_password()");

		string msg = "<span size=\"large\" weight=\"bold\">%s: %s</span>\n\n".printf(
			_("Encrypted device"), dev.device);
		
		msg += _("Enter Password to Unlock") + ":";
		
		return PasswordDialog.prompt_user(parent_window, false, "", msg);
	}

	public bool lock_device(Gtk.Window? parent_window, bool show_on_success = false){

		log_debug("Device: lock_device(): %s".printf(device));

		// check if not on encrypted device
		if (!is_encrypted_partition){
			log_debug("Device not encrypted!");
			return true;
		}

		if (!has_children){
			log_debug("Device does not have unlocked children!");
			return true;
		}

		var cmd = "cryptsetup luksClose %s".printf(children[0].mapped_name);
		log_debug(cmd);
		string std_out, std_err;
		int status = exec_script_sync(cmd, out std_out, out std_err, false, true); // prompt user if not admin
		return (status == 0);
	}

	public void flush_buffers(){
		if (!is_mounted) { return; }
		if (type != "disk") { return; }
		string cmd = "blockdev --flushbufs %s".printf(device);
		Posix.system(cmd);
	}
	
	// static --------------------------------

	public static Gee.ArrayList<Device> get_block_devices(){

		/* Returns list of block devices
		   Populates all fields in Device class */

		log_debug("Device: get_block_devices()");

		var list = get_block_devices_using_lsblk();

		if (device_list == null){
			device_list = list; // initialize in advance if null
		}

		//update_device_ids(list);
		
		update_usage(list);

		update_mounts(list);

		device_list = list;

		//print_device_list(list);

		//print_device_mounts(list);

		log_debug("Device: get_block_devices(): %d".printf(device_list.size));

		return device_list;
	}

	public static void update_usage(Gee.ArrayList<Device> list = get_devices()){

		log_debug("Device: update_usage(): %d".printf(list.size));
		
		var list_df = get_disk_space_using_df();
		
		foreach(var dev_df in list_df){
			
			var dev = get_device_by_uuid(dev_df.uuid, list);
			
			if (dev != null){
				dev.size_bytes = dev_df.size_bytes;
				dev.used_bytes = dev_df.used_bytes;
				dev.available_bytes = dev_df.available_bytes;
			}
		}
	}
	
	public static void update_mounts(Gee.ArrayList<Device> list = get_devices()){

		log_debug("Device: update_mounts(): %d".printf(list.size));
		
		var list_mtab = get_mounted_filesystems_using_mtab();

		foreach(var dev_mtab in list_mtab){
			
			var dev = get_device_by_uuid(dev_mtab.uuid, list);
			
			if (dev != null){
				dev.mount_points = dev_mtab.mount_points;
			}
		}
	}

	private static void find_child_devices(Gee.ArrayList<Device> list, Device parent){
		
		if (lsblk_is_ancient && (parent.type == "disk")){
			
			foreach (var part in list){
				
				if ((part.kname != parent.kname) && part.kname.has_prefix(parent.kname)){
					
					parent.children.add(part);
					part.parent = parent;
					part.pkname = parent.kname;
					log_debug("%s -> %s".printf(parent.kname, part.kname));
				}
			}
		}
		else{
			foreach (var part in list){
				if (part.pkname == parent.kname){
					parent.children.add(part);
					part.parent = parent;
				}
			}
		}

		if (parent.removable){
			foreach(var child in parent.children){
				child.removable = true;
			}
		}

		parent.children.sort();
	}

	private static void find_toplevel_parent(Gee.ArrayList<Device> list, Device dev){

		if (dev.pkname.length == 0){ return; }

		var top_kname = dev.pkname;
		
		foreach (var part in list){
			if (part.kname == top_kname){
				if (part.pkname.length > 0){
					top_kname = part.pkname; // get parent's parent if not empty
				}
			}
		}

		dev.pkname_toplevel = top_kname;

		//log_debug("%s -> %s -> %s".printf(dev.pkname_toplevel, dev.pkname, dev.kname));
	}

	private static void find_child_devices_using_dmsetup(Gee.ArrayList<Device> list){

		string std_out, std_err;
		exec_sync("dmsetup deps -o blkdevname", out std_out, out std_err);

		/*
		sdb3_crypt: 1 dependencies	: (sdb3)
		sda5_crypt: 1 dependencies	: (sda5)
		mmcblk0_crypt: 1 dependencies	: (mmcblk0)
		*/

		Regex rex;
		MatchInfo match;

		foreach(string line in std_out.split("\n")){
			if (line.strip().length == 0) { continue; }

			try{

				rex = new Regex("""([^:]*)\:.*\((.*)\)""");

				if (rex.match (line, 0, out match)){

					string child_name = match.fetch(1).strip();
					string parent_kname = match.fetch(2).strip();

					Device parent = null;
					foreach(var dev in list){
						if ((dev.kname == parent_kname)){
							parent = dev;
							break;
						}
					}

					Device child = null;
					foreach(var dev in list){
						if ((dev.mapped_name == child_name)){
							child = dev;
							break;
						}
					}

					if ((parent != null) && (child != null)){
						child.pkname = parent.kname;
						//log_debug("%s -> %s".printf(parent.kname, child.kname));
					}

				}
				else{
					log_debug("no-match: %s".printf(line));
				}
			}
			catch(Error e){
				log_error (e.message);
			}
		}
	}

	public static void eject_removable_disk(Device dev){

		//http://www.redhatgeek.com/linux/remove-a-disk-from-redhatcentos-linux-without-rebooting-the-system

		
		string sh = "";

		string kname = dev.device.replace("/dev/","").strip();

		// mark offline
		string sysfile = "/sys/block/%s/device/state".printf(kname);
		sh += "echo 'offline' > %s \n".printf(sysfile);
		
		// delete entries from system
		sysfile = "/sys/block/%s/device/delete".printf(kname);
		sh += "echo '1' > %s \n".printf(sysfile);

		string std_out, std_err;
		exec_script_sync(sh, out std_out, out std_err, false, true);
		
		log_msg("ejected: %s".printf(dev.device));
	}

	public static Gee.ArrayList<Device> get_block_devices_using_lsblk(string dev_name = ""){

		//log_debug("Device: get_block_devices_using_lsblk()");
		
		/* Returns list of mounted partitions using 'lsblk' command
		   Populates device, type, uuid, label */

		test_lsblk_version();

		var list = new Gee.ArrayList<Device>();

		string std_out;
		string std_err;
		string cmd;
		int ret_val;
		Regex rex;
		MatchInfo match;

		if (lsblk_is_ancient){
			cmd = "lsblk --bytes --pairs --output NAME,KNAME,LABEL,UUID,TYPE,FSTYPE,SIZE,MOUNTPOINT,MODEL,RO,RM,MAJ:MIN";
		}
		else{
			cmd = "lsblk --bytes --pairs --output NAME,KNAME,LABEL,UUID,TYPE,FSTYPE,SIZE,MOUNTPOINT,MODEL,RO,HOTPLUG,MAJ:MIN,PARTLABEL,PARTUUID,PKNAME,VENDOR,SERIAL,REV";
		}

		if (dev_name.length > 0){
			cmd += " %s".printf(dev_name);
		}

		ret_val = exec_sync(cmd, out std_out, out std_err);

		/*
		sample output
		-----------------
		NAME="sda" KNAME="sda" PKNAME="" LABEL="" UUID="" FSTYPE="" SIZE="119.2G" MOUNTPOINT="" HOTPLUG="0"
		NAME="sda1" KNAME="sda1" PKNAME="sda" LABEL="" UUID="5345-E139" FSTYPE="vfat" SIZE="47.7M" MOUNTPOINT="/boot/efi" HOTPLUG="0"
		NAME="mmcblk0p1" KNAME="mmcblk0p1" PKNAME="mmcblk0" LABEL="" UUID="3c0e4bbf" FSTYPE="crypto_LUKS" SIZE="60.4G" MOUNTPOINT="" HOTPLUG="1"
		NAME="luks-3c0" KNAME="dm-1" PKNAME="mmcblk0p1" LABEL="" UUID="f0d933c0-" FSTYPE="ext4" SIZE="60.4G" MOUNTPOINT="/mnt/sdcard" HOTPLUG="0"

		Note: Multiple loop devices can have same UUIDs.
		Example: Loop devices created by mounting the same ISO multiple times.
		*/

		// parse output and add to list --------------------------------------------

		int index = -1;

		foreach(string line in std_out.split("\n")){
			
			if (line.strip().length == 0) { continue; }

			try{
				if (lsblk_is_ancient){
					rex = new Regex("""NAME="(.*)" KNAME="(.*)" LABEL="(.*)" UUID="(.*)" TYPE="(.*)" FSTYPE="(.*)" SIZE="(.*)" MOUNTPOINT="(.*)" MODEL="(.*)" RO="([0-9]+)" RM="([0-9]+)" MAJ:MIN="([0-9:]+)"""");
				}
				else{
					rex = new Regex("""NAME="(.*)" KNAME="(.*)" LABEL="(.*)" UUID="(.*)" TYPE="(.*)" FSTYPE="(.*)" SIZE="(.*)" MOUNTPOINT="(.*)" MODEL="(.*)" RO="([0-9]+)" HOTPLUG="([0-9]+)" MAJ:MIN="([0-9:]+)" PARTLABEL="(.*)" PARTUUID="(.*)" PKNAME="(.*)" VENDOR="(.*)" SERIAL="(.*)" REV="(.*)"""");
				}

				if (rex.match (line, 0, out match)){

					Device pi = new Device();

					int pos = 0;
					
					pi.name = match.fetch(++pos).strip();
					pi.kname = match.fetch(++pos).strip();
					
					pi.label = match.fetch(++pos); // don't strip; labels can have leading or trailing spaces
					pi.uuid = match.fetch(++pos).strip();

					pi.type = match.fetch(++pos).strip().down();

					pi.fstype = match.fetch(++pos).strip().down();
					pi.fstype = (pi.fstype == "crypto_luks") ? "luks" : pi.fstype;
					pi.fstype = (pi.fstype == "lvm2_member") ? "lvm2" : pi.fstype;

					pi.size_bytes = int64.parse(match.fetch(++pos).strip());

					var mp = match.fetch(++pos).strip();
					if (mp.length > 0){
						pi.mount_points.add(new MountEntry(pi,mp,""));
					}

					pi.model = match.fetch(++pos).strip();

					pi.read_only = (match.fetch(++pos).strip() == "1");

					pi.removable = (match.fetch(++pos).strip() == "1");

					string txt = match.fetch(++pos).strip();
					if (txt.contains(":")){
						pi.major = int.parse(txt.split(":")[0]);
						pi.minor = int.parse(txt.split(":")[1]);
					}
					
					if (!lsblk_is_ancient){
						
						pi.partlabel = match.fetch(++pos); // don't strip; labels can have leading or trailing spaces
						pi.partuuid = match.fetch(++pos).strip();
					
						pi.pkname = match.fetch(++pos).strip();
						pi.vendor = match.fetch(++pos).strip();
						pi.serial = match.fetch(++pos).strip();
						pi.revision = match.fetch(++pos).strip();
					}

					pi.order = ++index;
					pi.device = "/dev/%s".printf(pi.kname);

					if (pi.uuid.length > 0){
						pi.device_by_uuid = "/dev/disk/by-uuid/%s".printf(pi.uuid);
						pi.symlinks.add(pi.device_by_uuid);
					}

					if (pi.label.length > 0){
						pi.device_by_label = "/dev/disk/by-label/%s".printf(pi.label);
						pi.symlinks.add(pi.device_by_label);
					}

					if (pi.partuuid.length > 0){
						pi.device_by_partuuid = "/dev/disk/by-partuuid/%s".printf(pi.partuuid);
						pi.symlinks.add(pi.device_by_partuuid);
					}

					if (pi.partlabel.length > 0){
						pi.device_by_partlabel = "/dev/disk/by-partlabel/%s".printf(pi.partlabel);
						pi.symlinks.add(pi.device_by_partlabel);
					}

					list.add(pi);
				}
				else{
					log_error("no-match: %s".printf(line));
				}
			}
			catch(Error e){
				log_error (e.message);
			}
		}

		// add aliases from /dev/mapper/ -------------------------------

		try{
			var f_mapper = File.new_for_path ("/dev/mapper");

			var enumerator = f_mapper.enumerate_children (
				"%s,%s".printf(FileAttribute.STANDARD_NAME,
					FileAttribute.STANDARD_SYMLINK_TARGET),
					FileQueryInfoFlags.NOFOLLOW_SYMLINKS);

			FileInfo info;
			while ((info = enumerator.next_file ()) != null) {

				if (info.get_name() == "control") { continue; }

				string target = info.get_symlink_target();

				if (target == null){ continue; }
				
				string target_device = target.replace("..","/dev");

				foreach(var dev in list){
					if (dev.device == target_device){
						dev.mapped_name = info.get_name();
						dev.device_mapper = "/dev/mapper/" + info.get_name();
						dev.symlinks.add(dev.device_mapper);
						//log_debug("found link: %s -> %s".printf(mapped_file, dev.device));
						break;
					}
				}
			}
		}
		catch (Error e) {
			log_error (e.message);
		}

		// update relationships ----------------------------------------

		foreach (var part in list){
			find_child_devices(list, part);
			find_toplevel_parent(list, part);
		}

		//find_toplevel_parent();

		if (lsblk_is_ancient){
			find_child_devices_using_dmsetup(list);
		}

		//print_device_list(list);

		//log_debug("Device: get_block_devices_using_lsblk(): %d".printf(list.size));

		return list;
	}

	public static Gee.ArrayList<Device> get_disk_space_using_df(string dev_name_or_mount_point = ""){

		/*
		Returns list of mounted partitions using 'df' command
		Populates device, type, size, used and mount_point_list
		*/

		//log_debug("Device: get_disk_space_using_df()");

		var list = new Gee.ArrayList<Device>();

		string cmd = "df -T -B1";
		if (dev_name_or_mount_point.length > 0){
			cmd += " '%s'".printf(escape_single_quote(dev_name_or_mount_point));
		}
		log_debug(cmd);

		string std_out, std_err;
		exec_sync(cmd, out std_out, out std_err);
		//ret_val is not reliable, no need to check

		//log_debug(std_out);

		/*
		sample output
		-----------------
		Filesystem     Type     1M-blocks    Used Available Use% Mounted on
		/dev/sda3      ext4        25070M  19508M     4282M  83% /
		none           tmpfs           1M      0M        1M   0% /sys/fs/cgroup
		udev           devtmpfs     3903M      1M     3903M   1% /dev
		tmpfs          tmpfs         789M      1M      788M   1% /run
		none           tmpfs           5M      0M        5M   0% /run/lock
		/dev/sda3      ext4        25070M  19508M     4282M  83% /mnt/timeshift
		*/

		string[] lines = std_out.split("\n");

		int line_num = 0;
		foreach(string line in lines){

			if (++line_num == 1) { continue; }
			if (line.strip().length == 0) { continue; }

			var pi = new Device();

			//parse & populate fields ------------------

			int k = 1;
			foreach(string val in line.split(" ")){

				if (val.strip().length == 0){ continue; }

				switch(k++){
					case 1:
						pi.device = val.strip();
						break;
					case 2:
						pi.fstype = val.strip();
						break;
					case 3:
						pi.size_bytes = int64.parse(val.strip());
						break;
					case 4:
						pi.used_bytes = int64.parse(val.strip());
						break;
					case 5:
						pi.available_bytes = int64.parse(val.strip());
						break;
					case 6:
						//pi.used_percent = val.strip();
						break;
					case 7:
						//string mount_point = val.strip();
						//if (!pi.mount_point_list.contains(mount_point)){
						//	pi.mount_point_list.add(mount_point);
						//}
						break;
				}
			}

			/* Note:
			 * The mount points displayed by 'df' are not reliable.
			 * For example, if same device is mounted at 2 locations, 'df' displays only the first location.
			 * Hence, we will not populate the 'mount_points' field in Device object
			 * Use get_mounted_filesystems_using_mtab() if mount info is required
			 * */

			if (!pi.device.has_prefix("/")){ continue; }

			// resolve device name --------------------

			//log_debug("pi.device=%s".printf(pi.device));

			pi.device = resolve_device_name(pi.device);

			//log_debug("resolved pi.device=%s".printf(pi.device));

			// get uuid ---------------------------

			pi.uuid = get_uuid_by_name(pi.device);

			//log_debug("resolved pi.uuid=%s".printf(pi.uuid));

			// add to map -------------------------

			if (pi.uuid.length > 0){
				list.add(pi);
			}
		}

		//log_debug("Device: get_disk_space_using_df(): %d".printf(list.size));

		return list;
	}

	public static Gee.ArrayList<Device> get_mounted_filesystems_using_mtab(){

		/* Returns list of mounted partitions by reading /proc/mounts
		   Populates device, type and mount_point_list */

		var list = new Gee.ArrayList<Device>();

		// find mtab file -----------

		string mtab_path = "/proc/mounts";
		
		File f = File.new_for_path(mtab_path);
		
		if (!f.query_exists()){
			
			mtab_path = "/proc/self/mounts";
			
			f = File.new_for_path(mtab_path);
			
			if (!f.query_exists()){
				
				mtab_path = "/etc/mtab";
				
				f = File.new_for_path(mtab_path);
				
				if (!f.query_exists()){
					
					return list;
				}
			}
		}

		/* Note:
		 * /etc/mtab represents what 'mount' passed to the kernel
		 * whereas /proc/mounts shows the data as seen inside the kernel
		 * Hence /proc/mounts is always up-to-date whereas /etc/mtab might not be
		 * */

		//read -----------

		var mtab_lines = file_read(mtab_path);

		/*
		sample mtab
		-----------------
		/dev/sda3 / ext4 rw,errors=remount-ro 0 0
		proc /proc proc rw,noexec,nosuid,nodev 0 0
		sysfs /sys sysfs rw,noexec,nosuid,nodev 0 0
		none /sys/fs/cgroup tmpfs rw 0 0
		none /sys/fs/fuse/connections fusectl rw 0 0
		none /sys/kernel/debug debugfs rw 0 0
		none /sys/kernel/security securityfs rw 0 0
		udev /dev devtmpfs rw,mode=0755 0 0

		device - the device or remote filesystem that is mounted.
		mountpoint - the place in the filesystem the device was mounted.
		filesystemtype - the type of filesystem mounted.
		options - the mount options for the filesystem
		dump - used by dump to decide if the filesystem needs dumping.
		fsckorder - used by fsck to detrmine the fsck pass to use.
		*/

		//parse ------------

		string[] lines = mtab_lines.split("\n");
		var mount_list = new Gee.ArrayList<string>();

		foreach (var line in lines){

			if (line.strip().length == 0) { continue; }

			var pi = new Device();

			var mp = new MountEntry(pi,"","");

			//parse & populate fields ------------------

			int k = 1;
			foreach(string val in line.strip().split(" ")){
				
				if (val.strip().length == 0){ continue; }
				
				switch(k++){
					case 1: //device
						pi.device = val.strip();
						break;
					case 2: //mountpoint
						mp.mount_point = val.strip().replace("""\040"""," ").replace("""\046""","&"); // replace space. TODO: other chars?
						if (!mount_list.contains(mp.mount_point)){
							mount_list.add(mp.mount_point);
							pi.mount_points.add(mp);
						}
						break;
					case 3: //filesystemtype
						pi.fstype = val.strip();
						break;
					case 4: //options
						mp.mount_options = val.strip();
						break;
					default:
						//ignore
						break;
				}
			}

			// resolve device names ----------------

			pi.device = resolve_device_name(pi.device);

			// get uuid ---------------------------

			pi.uuid = get_uuid_by_name(pi.device);

			// add to map -------------------------

			if (pi.uuid.length > 0){
				
				var dev = get_device_by_uuid(pi.uuid, list);
				
				if (dev == null){
					list.add(pi);
				}
				else{
					// add mount points to existing device
					foreach(var item in pi.mount_points){
						dev.mount_points.add(item);
					}
				}
			}
		}

		log_debug("Device: get_mounted_filesystems_using_mtab(): %d".printf(list.size));

		return list;
	}

	public static Device? get_device_for_path(string path){

		Device dev = null;
		string mpath = "";

		// find longest matching mount_path and device
		foreach(var d in device_list){
			// loop through all mount_points (not just mount_path)
			foreach(var mp in d.mount_points){
				if (path.has_prefix(mp.mount_point) && (mp.mount_point.length > mpath.length)){
					dev = d;
					mpath = mp.mount_point;
				}
			}
		}

		return dev;
	}

	// static helpers ----------------------------------

	public static Device? get_device_by_uuid(string uuid, Gee.ArrayList<Device>? _list = null){

		var list = (_list == null) ? device_list : _list;
		
		foreach(var dev in list){
			if (dev.uuid == uuid){
				return dev;
			}
		}

		return null;
	}

	public static Device? get_device_by_name(string file_name, Gee.ArrayList<Device>? _list = null){

		var device_name = resolve_device_name(file_name);

		var list = (_list == null) ? device_list : _list;
		
		foreach(var dev in list){
			if (dev.device == device_name){
				return dev;
			}
		}

		return null;
	}

	public static Device? get_device_by_path(string path_to_check){

		var list = Device.get_disk_space_using_df(path_to_check);

		//print_device_list_short(list);

		if (list.size > 0){
			
			string name = list[0].device;
			
			string resolved = resolve_device_name(name);
			//log_debug("get_device_by_path: resolved: %s -> %s".printf(name, resolved));
			
			var dev = get_device_by_name(resolved);
			//log_debug("get_device_by_path: device: '%s' -> %s".printf(path_to_check, dev.device));
			
			return dev;
		}

		return null;
	}


	public static string get_uuid_by_name(string device){

		foreach(var dev in device_list){
			if (dev.device == device){
				return dev.uuid;
			}
		}

		return "";
	}

	public static Gee.ArrayList<MountEntry> get_device_mount_points(string dev_name_or_uuid){

		// resolve device name and uuid -----------------------------

		string device = "";
		string uuid = "";
		if (dev_name_or_uuid.has_prefix("/dev")){
			device = dev_name_or_uuid;
			uuid = Device.get_uuid_by_name(dev_name_or_uuid);
		}
		else{
			uuid = dev_name_or_uuid;
			device = "/dev/disk/by-uuid/%s".printf(uuid);
			device = resolve_device_name(device);
		}

		var list_mtab = get_mounted_filesystems_using_mtab();

		var dev = get_device_by_uuid(uuid, list_mtab);

		if (dev != null){
			return dev.mount_points;
		}
		else{
			return (new Gee.ArrayList<MountEntry>());
		}
	}

	public static bool device_is_mounted(string dev_name_or_uuid){

		var mps = Device.get_device_mount_points(dev_name_or_uuid);
		if (mps.size > 0){
			return true;
		}

		return false;
	}

	public static bool mount_point_in_use(string mount_point){
		var list = Device.get_mounted_filesystems_using_mtab();
		foreach (var dev in list){
			foreach(var mp in dev.mount_points){
				if (mp.mount_point.has_prefix(mount_point)){
					// check for any mount point at or under the given mount_point
					return true;
				}
			}
		}
		return false;
	}


	public static Device? resolve_device(string _dev_alias){

		if (_dev_alias.length == 0){ return null; }
		
		string dev_alias = _dev_alias;
		
		if (dev_alias.down().has_prefix("uuid=")){
			
			dev_alias = dev_alias.split("=",2)[1].strip().down();
		}
		else if (file_exists(dev_alias) && file_is_symlink(dev_alias)){

			var link_path = file_get_symlink_target(dev_alias);
			
			dev_alias = link_path.replace("../../../","/dev/").replace("../../","/dev/").replace("../","/dev/");
		}

		foreach(var dev in device_list){
			
			if (dev.device == dev_alias){
				return dev;
			}
			else if (dev.uuid == dev_alias){
				return dev;
			}
			else if (dev.label == dev_alias){
				return dev;
			}
			else if (dev.partuuid == dev_alias){
				return dev;
			}
			else if (dev.partlabel == dev_alias){
				return dev;
			}
			else if (dev.device_by_uuid == dev_alias){
				return dev;
			}
			else if (dev.device_by_label == dev_alias){
				return dev;
			}
			else if (dev.device_by_partuuid == dev_alias){
				return dev;
			}
			else if (dev.device_by_partlabel == dev_alias){
				return dev;
			}
			else if (dev.device_mapper == dev_alias){
				return dev;
			}
			else if (dev.mapped_name == dev_alias){ // check last
				return dev;
			}
		}

		return null;
	}

	public static string resolve_device_name(string _dev_alias){

		if (_dev_alias.length == 0){ return ""; }

		var dev = resolve_device(_dev_alias);

		if (dev != null){
			return dev.device;
		}
		else{
			return "";
		}
	}

	
	public Gdk.Pixbuf get_icon(int icon_size = 16, bool symbolic = false){

		Gdk.Pixbuf pixbuf = null;

		if (kname.has_prefix("mmcblk") || pkname.has_prefix("mmcblk")){
			
			pixbuf = IconManager.lookup("media-flash", icon_size, symbolic, false);
		}
		else if (type == "loop"){

			pixbuf = IconManager.lookup("media-cdrom", icon_size, symbolic, false);
		}
		else if ((type == "crypt") && (pkname.length > 0)){
			
			//pixbuf = IconManager.lookup("unlocked", icon_size, symbolic, true);
			//pixbuf = IconManager.lookup("drive-harddisk", icon_size, symbolic);

			if (removable || (has_parent() && parent.removable)){
				
				pixbuf = IconManager.lookup("drive-harddisk-usb,drive-removable-media", icon_size, symbolic);
			}
			else {
				pixbuf = IconManager.lookup("drive-harddisk", icon_size, symbolic);
			}
		}
		else if (fstype.contains("luks")){
			
			//pixbuf = IconManager.lookup("encrypted", icon_size, symbolic);
			//pixbuf = IconManager.lookup("drive-harddisk", icon_size, symbolic);
			pixbuf = IconManager.lookup("locked", icon_size, symbolic, true);
		}
		else if (fstype.contains("iso9660")){
			
			pixbuf = IconManager.lookup("media-cdrom", icon_size, symbolic);
		}
		else{
			//pixbuf = IconManager.lookup("drive-harddisk-symbolic", icon_size, symbolic);
			if (removable || (has_parent() && parent.removable)){
				
				pixbuf = IconManager.lookup("drive-harddisk-usb,drive-removable-media", icon_size, symbolic);
			}
			else{
				pixbuf = IconManager.lookup("drive-harddisk", icon_size, symbolic);
			}
		}

		if (!has_mounted_partitions && (pixbuf != null)){ // && (pkname.length > 0)
			
			pixbuf = IconManager.add_transparency(pixbuf);
		}

		return pixbuf;
	}

	public Gdk.Pixbuf? get_icon_fstype(int icon_size = 16, bool symbolic = false){
		
		if (fstype.length > 0){
			return IconManager.lookup("fs-" + fstype, icon_size);
		}
		else{
			return null;
		}
	}
	
	// instance helpers -------------------------------

	public void copy_fields_from(Device dev2){

		this.device = dev2.device;
		this.name = dev2.name;
		this.kname = dev2.kname;
		this.pkname = dev2.pkname;
		this.pkname_toplevel = dev2.pkname_toplevel;
		this.mapped_name = dev2.mapped_name;
		this.uuid = dev2.uuid;
		this.label = dev2.label;
		this.major = dev2.major;
		this.minor = dev2.minor;

		this.type = dev2.type;
		this.fstype = dev2.fstype;
		this.dist_info = dev2.dist_info;

		this.vendor = dev2.vendor;
		this.model = dev2.model;
		this.serial = dev2.serial;
		this.revision = dev2.revision;
		this.removable = dev2.removable;
		this.read_only = dev2.read_only;

		this.size_bytes = dev2.size_bytes;
		this.used_bytes = dev2.used_bytes;
		this.available_bytes = dev2.available_bytes;

		this.mount_points = dev2.mount_points;
		this.symlinks = dev2.symlinks;
		this.parent = dev2.parent;
		this.children = dev2.children;

		// aliases
		this.device_mapper = dev2.device_mapper;
		this.device_by_uuid = dev2.device_by_uuid;
		this.device_by_label = dev2.device_by_label;
		this.device_by_partuuid = dev2.device_by_partuuid;
		this.device_by_partlabel = dev2.device_by_partlabel;
		
		this.major = dev2.major;
		this.minor = dev2.minor;
	}
	
	public Device copy(){
		var dev = new Device();
		dev.copy_fields_from(this);
		return dev;
	}
	
	public Device? query_changes(){

		foreach (var dev in get_block_devices()){
			if (dev.device == device){
				copy_fields_from(dev);
				break;
			}
		}

		return this;
	}

	public void query_disk_space(){

		var list2 = get_disk_space_using_df(device);

		var dev2 = get_device_by_uuid(uuid, list2);

		if (dev2 != null){
			// update size fields
			size_bytes = dev2.size_bytes;
			used_bytes = dev2.used_bytes;
			available_bytes = dev2.available_bytes;
		}
	}

	public void query_mount_points(){

		var list = get_mounted_filesystems_using_mtab();
		
		var dev = get_device_by_name(device, list);
		
		if (dev != null){
			mount_points = dev.mount_points; // update field
		}
	}
	
	// mounting ---------------------------------

	public static bool automount_udisks(Device dev, Gtk.Window? parent_window, bool show_on_success = false){

		dev.query_mount_points();
		if (dev.is_mounted){
			return true;
		}

		if (dev.device.has_prefix("/dev/nbd")){
			
			string cmd = "";

			string mpath = "/mnt/%s".printf(dev.uuid);
			
			cmd += "mkdir -p '%s'".printf(escape_single_quote(mpath));

			cmd += "\n";
			
			cmd += "mount '%s' '%s'".printf(dev.device, mpath);

			cmd += "\n";
			
			string std_out, std_err;
			exec_script_sync(cmd, out std_out, out std_err, false, true);

			if (std_err.length > 0){
				gtk_messagebox(_("Error"), std_err, parent_window, true);
				return false;
			}
			else{
				//gtk_messagebox(_("Mounted successfully"), "%s: %s".printf(_("Device"), nbd_device), window, false);
			}

			return true;
		}

		var cmd = "udisksctl mount -b '%s'".printf(dev.device);
		log_debug(cmd);
		string std_out, std_err;
		int status = exec_sync(cmd, out std_out, out std_err);

		dev.query_mount_points();
		if (dev.is_mounted){
			string message = _("Device mounted successfully");
			string details = "%s: %s, %s: %s".printf(_("Device"), dev.device, _("Path"), dev.mount_points[0].mount_point);
			bool is_error = false;
			show_message(message, details, is_error, parent_window, show_on_success);
		}
		else{
			string message = _("Failed to mount device");
			string details = "%s: %s\n\n%s".printf(_("Device"), dev.device, std_err);
			bool is_error = true;
			show_message(message, details, is_error, parent_window, show_on_success);
		}

		return (status == 0);
	}

	public static Device? automount_udisks_iso(string iso_file_path, Gtk.Window? parent_window){

		Device? loop_dev = null;

		if (!file_exists(iso_file_path)){
			string msg = "%s: %s".printf(_("Could not find file"), iso_file_path);
			log_error(msg);
			return loop_dev;
		}

		var cmd = "udisksctl loop-setup";

		
		//if (iso_file_path.down().has_suffix("-o loop,rw,sync")){
			//cmd += " -r";
		//}

		cmd += " -f '%s'".printf(escape_single_quote(iso_file_path));

		log_debug(cmd);
		string std_out, std_err;
		int exit_code = exec_sync(cmd, out std_out, out std_err);

		if (exit_code == 0){
			log_msg("%s".printf(std_out));
			//log_msg("%s".printf(std_err));

			if (!std_out.contains(" as ")){
				log_error("Could not determine loop device");
				return loop_dev;
			}

			var loop_name = std_out.split(" as ")[1].replace(".","").strip();
			log_msg("Loop device: %s".printf(loop_name));

			get_block_devices(); // required
			loop_dev = Device.get_device_by_name(loop_name);
		}

		return loop_dev;
	}

	public static bool unmount_udisks(string dev_name_or_uuid, Gtk.Window? parent_window){

		if (dev_name_or_uuid.length == 0){
			log_error(_("Device name is empty!"));
			return false;
		}

		var cmd = "udisksctl unmount -b '%s'".printf(dev_name_or_uuid);
		log_debug(cmd);
		string std_err, std_out;
		int status = exec_sync(cmd, out std_out,  out std_err);

		if (status != 0){
			if (parent_window != null){
				string title = "Error unmounting %s".printf(dev_name_or_uuid);
				//string msg = std_err;
				gtk_messagebox(title, std_err, parent_window, true);
			}
		}

		return (status == 0);
	}

	public static Device? luks_unlock(Device dev, string mapped_name, string passphrase, Gtk.Window? parent_window, bool show_on_success = false){

		/* Unlocks a LUKS device using provided passphrase.
		 * Prompts the user for passphrase if empty.
		 * Displays a GTK prompt if parent_window is not null
		 * Otherwise prompts user on terminal with a timeout of 20 secsonds
		 * */

		Device unlocked_device = null;
		string std_out = "", std_err = "";
		bool is_error = false;
		string message = "";
		string details = "";

		// check if not encrypted
		if (!dev.is_encrypted_partition){
			return dev;
		}

		// check if already unlocked
		dev.query_changes();
		if (dev.has_children){
			return dev.children[0];
		}

		string luks_pass = passphrase;
		string luks_name = mapped_name;

		if ((luks_name == null) || (luks_name.length == 0)){
			luks_name = "%s_crypt".printf(dev.kname);
		}

		if (parent_window == null){

			// console mode

			if ((luks_pass == null) || (luks_pass.length == 0)){

				// prompt user on terminal and unlock, else timeout after 20 secs

				var counter = new TimeoutCounter();
				counter.kill_process_on_timeout("cryptsetup", 20, true);
				string cmd = "cryptsetup luksOpen '%s' '%s'".printf(dev.device, luks_name);

				log_debug(cmd);
				Posix.system(cmd);
				counter.stop();
				log_msg("");

				// no need to show messages
			}
			else{

				// use password to unlock

				var cmd = "echo -n -e '%s' | cryptsetup luksOpen --key-file - '%s' '%s'\n".printf(
					luks_pass, dev.device, luks_name);

				log_debug(cmd.replace(luks_pass, "**PASSWORD**"));

				int status = exec_script_sync(cmd, out std_out, out std_err, false, true);

				switch (status){
				case 512: // invalid passphrase
					message = _("Wrong password");
					details = _("Failed to unlock device");
					show_message(message, details, true, parent_window, show_on_success);
					return null;
				}
			}
		}
		else{

			// gui mode

			if ((luks_pass == null) || (luks_pass.length == 0)){

				// show input prompt

				log_debug("Prompting user for passphrase..");

				luks_pass = gtk_inputbox(
						_("Encrypted Device"),
						_("Enter passphrase to unlock '%s'").printf(dev.name),
						parent_window, true);

				if (luks_pass == null){
					// cancelled by user
					message = _("Failed to unlock device");
					details = _("User cancelled the password prompt");
					show_message(message, details, true, parent_window, show_on_success);
					return null;
				}
			}

			if ((luks_pass != null) && (luks_pass.length > 0)){

				// use password to unlock

				var cmd = "echo -n -e '%s' | cryptsetup luksOpen --key-file - '%s' '%s'\n".printf(
					luks_pass, dev.device, luks_name);

				log_debug(cmd.replace(luks_pass, "**PASSWORD**"));

				int status = exec_script_sync(cmd, out std_out, out std_err, false, true);

				switch (status){
				case 512: // invalid passphrase
					message = _("Wrong password");
					details = _("Failed to unlock device");
					show_message(message, details, true, parent_window, show_on_success);
					return null;
				}
			}

		}

		// check if unlocked
		dev.query_changes();
		if (dev.has_children){
			unlocked_device = dev.children[0];
		}


		if (unlocked_device == null){
			message = _("Failed to unlock device");
			details = "%s: %s\n\n%s".printf(_("Device"), dev.device, std_err);
			is_error = true;
		}
		else{
			message = _("Unlocked successfully");
			details = "%s: %s, %s: /dev/mapper/%s".printf(_("Device"), dev.device, _("Unlocked"), unlocked_device.mapped_name);
			is_error = false;
		}

		show_message(message, details, is_error, parent_window, show_on_success);
		return unlocked_device;
	}

	public static bool luks_lock(Device dev, Gtk.Window? parent_window, bool show_on_success){

		// check if not on encrypted device
		if (!dev.is_on_encrypted_partition){
			log_debug("Device is not encrypted: %s".printf(dev.device));
			return false;
		}

		var cmd = "cryptsetup luksClose %s".printf(dev.kname);
		log_debug(cmd);
		string std_out, std_err;
		int status = exec_script_sync(cmd, out std_out, out std_err, false, true); // prompt user if not admin
		return (status == 0);
	}

	public static bool mount(
		string dev_name_or_uuid, string mount_point, string mount_options = "", bool silent = false){

		/*
		 * Mounts specified device at specified mount point.
		 *
		 * */

		string cmd = "";
		string std_out;
		string std_err;
		int ret_val;

		// resolve device name and uuid -----------------------------

		string device = "";
		string uuid = "";
		if (dev_name_or_uuid.has_prefix("/dev")){
			device = dev_name_or_uuid;
			uuid = Device.get_uuid_by_name(dev_name_or_uuid);
		}
		else{
			uuid = dev_name_or_uuid;
			device = "/dev/disk/by-uuid/%s".printf(uuid);
			device = resolve_device_name(device);
		}

		// check if already mounted --------------

		var mps = Device.get_device_mount_points(dev_name_or_uuid);

		log_debug("------------------");
		log_debug("arg=%s, device=%s".printf(dev_name_or_uuid, device));
		foreach(var mp in mps){
			log_debug(mp.mount_point);
		}
		log_debug("------------------");

		foreach(var mp in mps){
			if ((mp.mount_point == mount_point) && mp.mount_options.contains(mount_options)){
				if (!silent){
					var msg = "%s is mounted at: %s".printf(device, mount_point);
					if (mp.mount_options.length > 0){
						msg += ", options: %s".printf(mp.mount_options);
					}
					log_msg(msg);
				}
				return true;
			}
		}

		dir_create(mount_point);

		// unmount if any other device is mounted

		unmount_path(mount_point);

		// mount the device -------------------

		if (mount_options.length > 0){
			cmd = "mount -o %s \"%s\" \"%s\"".printf(mount_options, device, mount_point);
		}
		else{
			cmd = "mount \"%s\" \"%s\"".printf(device, mount_point);
		}

		ret_val = exec_sync(cmd, out std_out, out std_err);

		if (ret_val != 0){
			log_error ("Failed to mount device '%s' at mount point '%s'".printf(device, mount_point));
			log_error (std_err);
			return false;
		}
		else{
			if (!silent){
				Device dev = get_device_by_name(device);
				log_msg ("Mounted '%s'%s at '%s'".printf(
					(dev == null) ? device : dev.device_name_with_parent,
					(mount_options.length > 0) ? " (%s)".printf(mount_options) : "",
					mount_point));
			}
			return true;
		}

		// check if mounted successfully ------------------

		/*mps = Device.get_device_mount_points(dev_name_or_uuid);
		if (mps.contains(mount_point)){
			log_msg("Device '%s' is mounted at '%s'".printf(dev_name_or_uuid, mount_point));
			return true;
		}
		else{
			return false;
		}*/
	}

	public static string automount_device(
		string dev_name_or_uuid, string mount_options = "", string mount_prefix = "/mnt"){

		/* Returns the mount point of specified device.
		 * If unmounted, mounts the device to /mnt/<uuid> and returns the mount point.
		 * */

		// resolve device name and uuid -----------------------------

		string device = "";
		string uuid = "";
		if (dev_name_or_uuid.has_prefix("/dev")){
			device = dev_name_or_uuid;
			uuid = Device.get_uuid_by_name(dev_name_or_uuid);
		}
		else{
			uuid = dev_name_or_uuid;
			device = "/dev/disk/by-uuid/%s".printf(uuid);
			device = resolve_device_name(device);
		}

		// check if already mounted and return mount point -------------

		var list = Device.get_block_devices();
		var dev = get_device_by_uuid(uuid, list);
		if (dev != null){
			return dev.mount_points[0].mount_point;
		}

		// check and create mount point -------------------

		string mount_point = "%s/%s".printf(mount_prefix, uuid);

		try{
			File file = File.new_for_path(mount_point);
			if (!file.query_exists()){
				file.make_directory_with_parents();
			}
		}
		catch(Error e){
			log_error (e.message);
			return "";
		}

		// mount the device and return mount_point --------------------

		if (mount(uuid, mount_point, mount_options)){
			return mount_point;
		}
		else{
			return "";
		}
	}

	public static bool unmount_path(string mount_point){

		/* Recursively unmounts all devices at given mount_point and subdirectories
		 * */

		string cmd = "";
		string std_out;
		string std_err;
		int ret_val;

		// check if mount point is in use
		if (!Device.mount_point_in_use(mount_point)) {
			return true;
		}

		// try to unmount ------------------

		try{

			string cmd_unmount = "cat /proc/mounts | awk '{print $2}' | grep '%s' | sort -r | xargs umount".printf(mount_point);

			log_debug(_("Unmounting from") + ": '%s'".printf(mount_point));

			//sync before unmount
			cmd = "sync";
			Process.spawn_command_line_sync(cmd, out std_out, out std_err, out ret_val);
			//ignore success/failure

			//unmount
			ret_val = exec_script_sync(cmd_unmount, out std_out, out std_err);

			if (ret_val != 0){
				log_error (_("Failed to unmount"));
				log_error (std_err);
			}
		}
		catch(Error e){
			log_error (e.message);
			return false;
		}

		// check if mount point is in use
		if (!Device.mount_point_in_use(mount_point)) {
			return true;
		}
		else{
			return false;
		}
	}

	public static void show_message(string message, string details, bool is_error, Gtk.Window? window, bool show_on_success){

		if (window != null){
			if (is_error){
				gtk_messagebox(message, details, window, true);
				log_error(message);
				log_error(details);
			}
			else if (show_on_success){
				gtk_messagebox(message, details, window, false);
				log_msg(message);
				log_msg(details);
			}
		}
		else{
			if (is_error){
				log_error(message);
				log_error(details);
			}
			else if (show_on_success){
				log_msg(message);
				log_msg(details);
			}
			else{
				log_debug(message);
				log_debug(details);
			}
		}
	}

	// description helpers

	public string full_name_with_alias{
		owned get{
			string text = device;
			if (mapped_name.length > 0){
				text += " (%s)".printf(mapped_name);
			}
			return text;
		}
	}

	public string full_name_with_parent{
		owned get{
			return device_name_with_parent;
		}
	}

	public string short_name_with_alias{
		owned get{
			string text = kname;
			if (mapped_name.length > 0){
				text += " (%s)".printf(mapped_name);
			}
			return text;
		}
	}

	public string short_name_with_parent{
		owned get{
			string text = kname;

			if (has_parent() && (parent.type == "part")){
				text += " (%s)".printf(pkname);
			}

			return text;
		}
	}

	public string short_name_with_parent_and_label{
		owned get{
			string s = kname;

			if (has_parent() && (parent.type == "part")){
				s = "%s → %s".printf(pkname, kname);
			}

			s += (label.length > 0) ? " (%s)".printf(label): "";

			return s;
		}
	}

	public string device_name_with_parent{
		owned get{
			string text = device;

			if (has_parent() && (parent.type == "part")){
				text += " (%s)".printf(parent.kname);
			}

			return text;
		}
	}

	public double used_percent{
		get{
			return (used_bytes * 100.0) / size_bytes;
		}
	}

	public string used_percent_text{
		owned get{
			return "%.0f%%".printf(used_percent);
		}
	}

	public string description(){
		return description_formatted().replace("<b>","").replace("</b>","");
	}

	public string description_formatted(){
		string s = "";

		if (type == "disk"){
			s += "<b>" + kname + "</b> ~";
			if (vendor.length > 0){
				s += " " + vendor;
			}
			if (model.length > 0){
				s += " " + model;
			}
			if (size_bytes > 0) {
				s += " (%s)".printf(format_file_size(size_bytes, false, "", true, 0));
			}
		}
		else{
			s += "<b>" + short_name_with_parent + "</b>" ;
			s += (label.length > 0) ? " (%s)".printf(label): "";
			s += (fstype.length > 0) ? " ~ " + fstype : "";
			if (size_bytes > 0) {
				s += " (%s)".printf(format_file_size(size_bytes, false, "", true, 0));
			}
		}

		return s.strip();
	}

	public string description_simple(bool show_device_file = true, bool short_desc = false){
		
		string s = "";

		if (type == "disk"){
			
			if (vendor.length > 0){
				s += " " + vendor;
			}
			
			if (model.length > 0){
				s += " " + model;
			}
			
			if (size_bytes > 0) {
				
				if (s.strip().length == 0){
					
					s += "%s Device".printf(format_file_size(size_bytes, false, "", true, 0));
				}
				else{
					if (!short_desc && (type != "loop")){
						s += " (%s)".printf(format_file_size(size_bytes, false, "", true, 0));
					}
				}
			}
			
			/*if (show_device_file && (device.length > 0)){
				s += " ~ %s".printf(device);
			}*/

			if (s.has_prefix("ATA ")){
				s = s[4:s.length];
			}
		}
		else{
			s += short_name_with_parent;
			s += (label.length > 0) ? " (" + label + ")": "";
			s += (fstype.length > 0) ? " ~ " + fstype : "";
			if (size_bytes > 0) {
				s += " (%s)".printf(format_file_size(size_bytes, false, "", true, 0));
			}
		}

		return s.strip();
	}

	public string description_simple_formatted(){

		string s = "";

		if (type == "disk"){
			
			if (vendor.length > 0){
				s += " " + vendor;
			}
			if (model.length > 0){
				s += " " + model;
			}
			if (size_bytes > 0) {
				if (s.strip().length == 0){
					s += "%s Device".printf(format_file_size(size_bytes, false, "", true, 0));
				}
				else{
					s += " (%s)".printf(format_file_size(size_bytes, false, "", true, 0));
				}
			}
		}
		else{
			s += "<b>" + short_name_with_parent + "</b>" ;
			s += (label.length > 0) ? " (" + label + ")": "";
			s += (fstype.length > 0) ? " ~ " + fstype : "";
			if (size_bytes > 0) {
				s += " (%s)".printf(format_file_size(size_bytes, false, "", true, 0));
			}
		}

		return s.strip();
	}

	public string description_disk_friendly(){

		var dev = this;

		while (dev.has_parent()){
			dev = dev.parent;
		}

		string s = "";
			
		if (dev.vendor.length > 0){
			s += " " + dev.vendor;
		}
		
		if (dev.model.length > 0){
			s += " " + dev.model;
		}
		
		if (dev.size_bytes > 0) {
			
			if (s.strip().length == 0){
				
				s += "%s Device".printf(format_file_size(dev.size_bytes, false, "", true, 0));
			}
			else{
				s += " (%s)".printf(format_file_size(dev.size_bytes, false, "", true, 0));
			}
		}
		
		if (s.has_prefix("ATA ")){
			s = s[4:s.length];
		}

		s = dev.device + " - " + s.strip();
		
		return s.strip();
	}

	public string description_friendly(){

		string s = "";

		s += "/dev/%s".printf(kname);
		
		if (pkname.length > 0){
			s += " (on /dev/%s)".printf(pkname);
		}

		if (label.length > 0){
			s += " (%s)".printf(label);
		}
		else if (partlabel.length > 0){
			s += " (%s)".printf(partlabel);
		}
		else if (has_parent() && (parent.partlabel.length > 0)){
			s += " (%s)".printf(parent.partlabel);
		}

		if (fstype.length > 0){
			s += " ~ %s".printf(fstype);
		}
			
		if (size_bytes > 0) {
			s += " ~ %s".printf(format_file_size(size_bytes, false, "", true, 0));
		}

		return s;
	}
	
	public string description_full_free(){
		
		string s = "";

		if (type == "disk"){
			
			s += "%s %s".printf(model, vendor).strip();
			
			if (s.length == 0){
				s = "%s Disk".printf(format_file_size(size_bytes));
			}
			else{
				s += " (%s Disk)".printf(format_file_size(size_bytes));
			}
		}
		else{
			
			s += kname;
			
			if (label.length > 0){
				s += " (%s)".printf(label);
			}
			
			if (fstype.length > 0){
				s += " ~ %s".printf(fstype);
			}
			
			if (free_bytes > 0){
				s += " ~ %s".printf(description_free());
			}
		}

		return s;
	}

	public string description_full(){
		
		string s = "";

		s += device;
		s += (label.length > 0) ? " (" + label + ")": "";
		s += (uuid.length > 0) ? " ~ " + uuid : "";
		s += (fstype.length > 0) ? " ~ " + fstype : "";
		s += (used_bytes > 0) ? " ~ " + used_formatted + " / " + size_formatted + " used (" + used_percent_text + ")" : "";

		return s;
	}

	public string description_usage(){
		if (used_bytes > 0){
			return used_formatted + " / " + size_formatted + " used (" + used_percent_text + ")";
		}
		else{
			return "";
		}
	}

	public string description_free(){
		if (used_bytes > 0){
			return format_file_size(free_bytes, false, "g", false)
				+ " / " + format_file_size(size_bytes, false, "g", true) + " free";
		}
		else{
			return "";
		}
	}

	public string tooltip_text(){

		string tt = "";

		tt += "%s: %s\n".printf(_("Device"), device);

		if (mapped_name.length > 0){
			tt += "%s: %s\n".printf(_("Mapped"), "/dev/mapper/%s".printf(mapped_name));
		}

		if ((pkname.length > 0) || (fstype.length > 0)){
			
			tt += "%s: %s\n".printf(_("UUID"), ((uuid.length > 0) ? uuid : _("(empty)")));
			
			tt += "%s: %s\n".printf(_("Label"), ((label.length > 0) ? label : _("(empty)")));

			tt += "%s: %s\n".printf(_("PartLabel"), ((partlabel.length > 0) ? partlabel : _("(empty)")));
		}

		tt += "────────────────────────────────────────\n";
		
		if (fstype.length > 0){
			tt += "%s: %s\n".printf(_("Filesystem"), fstype);
		}

		if (is_mounted){
			tt += "%s: %s\n".printf(_("Mount"), mount_points[0].mount_point);
		}
		
		tt += "%s: %s\n".printf(_("ReadOnly"), (read_only ? "Yes" : "No"));

		tt += "%s: %s\n".printf(_("Removable"), (removable ? "Yes" : "No"));

		if (vendor.length > 0){
			tt += "%s: %s\n".printf(_("Vendor"), vendor);
		}

		if (model.length > 0){
			tt += "%s: %s\n".printf(_("Model"), model);
		}

		if (serial.length > 0){
			tt += "%s: %s\n".printf(_("Serial"), serial);
		}

		if (revision.length > 0){
			tt += "%s: %s\n".printf(_("Revision"), revision);
		}

		tt += "%s: %d\n".printf(_("Major"), major);

		tt += "%s: %d\n".printf(_("Minor"), minor);

		tt += "────────────────────────────────────────\n";

		tt += "%s: %s (%'ld bytes)\n".printf(
			_("Size"), format_file_size(size_bytes), size_bytes);

		tt += "%s: %s (%'ld bytes) (%.0f%%)\n".printf(
			_("Used"), format_file_size(used_bytes),
			used_bytes, (used_bytes * 100.0) / size_bytes);

		tt += "%s: %s (%'ld bytes) (%.0f%%)".printf(
			_("Available"), format_file_size(available_bytes),
			available_bytes, (available_bytes * 100.0) / size_bytes);

		return tt;
	}

	// testing -----------------------------------

	public static void test_all(){
		var list = get_block_devices();
		log_msg("\n> get_block_devices()");
		print_device_list(list);

		log_msg("");

		list = get_mounted_filesystems_using_mtab();
		log_msg("\n> get_mounted_filesystems_using_mtab()");
		print_device_mounts(list);

		log_msg("");

		list = get_disk_space_using_df();
		log_msg("\n> get_disk_space_using_df()");
		print_device_disk_space(list);

		log_msg("");

		list = get_block_devices();
		log_msg("\n> get_filesystems()");
		print_device_list(list);
		print_device_mounts(list);
		print_device_disk_space(list);

		log_msg("");
	}

	public static void print_device_list(Gee.ArrayList<Device> list = get_devices()){

		log_debug("");

		log_debug("%-15s %-10s %-10s %-10s %-10s %-10s".printf(
			"device",
			"pkname",
			"kname",
			"type",
			"fstype",
			"mapped"
			));

		log_debug(string.nfill(100, '-'));

		foreach(var dev in list){
			log_debug("%-15s %-10s %-10s %-10s %-10s %-10s".printf(
				dev.device ,
				dev.pkname,
				dev.kname,
				dev.type,
				dev.fstype,
				dev.mapped_name
				));
		}

		log_debug("");

		print_device_relationships(list);
	}

	public static void print_device_relationships(Gee.ArrayList<Device> list = get_devices()){

		log_debug("");

		log_debug(string.nfill(100, '-'));
		
		foreach(var dev in list){
			
			if (dev.pkname.length == 0){
				
				log_debug("%-10s".printf(dev.kname));

				foreach(var child1 in dev.children){
					if (!child1.has_children){
						log_debug("%-10s -- %-10s".printf(dev.kname, child1.kname));
					}
					else{
						foreach(var child2 in child1.children){
							log_debug("%-10s -- %-10s -- %-10s".printf(dev.kname, child1.kname, child2.kname));
						}
					}
				}
			}
		}

		log_debug("");
	}

	public static void print_device_mounts(Gee.ArrayList<Device> list = get_devices()){

		stdout.printf("\n");
		stdout.printf(string.nfill(100, '-') + "\n");

		foreach(var dev in list){
			stdout.printf("%-15s: %s\n".printf(dev.device, dev.mount_path));
			foreach(var mp in dev.mount_points){
				stdout.printf("  -> %s: %s\n".printf(mp.mount_point, mp.mount_options));
			}
		}

		stdout.printf("\n");
	}

	public static void print_device_disk_space(Gee.ArrayList<Device> list = get_devices()){
		log_debug("");

		log_debug("%-15s %-12s %15s %15s %15s %10s".printf(
			"device",
			"fstype",
			"size",
			"used",
			"available",
			"used_percent"
		));

		log_debug(string.nfill(100, '-'));

		foreach(var dev in list){
			log_debug("%-15s %-12s %15s %15s %15s %10s".printf(
				dev.device,
				dev.fstype,
				format_file_size(dev.size_bytes, true),
				format_file_size(dev.used_bytes, true),
				format_file_size(dev.available_bytes, true),
				dev.used_percent_text
			));
		}

		log_debug("");
	}

	public static void print_logical_children(Gee.ArrayList<Device> list = get_devices()){
		
		log_debug("");

		foreach(var dev in list){

			if (dev.pkname.length > 0){ continue; }

			string line = "";
			
			line += "%s".printf(dev.device);

			foreach(var child in dev.children){
				
				line += " ~ ";

				if (child.is_on_encrypted_partition){
					
					line += "%s_%s".printf(child.parent.device.replace("/dev/",""), child.device.replace("/dev/",""));
				}
				else if (child.is_encrypted_partition){
					
					if (child.has_children){
						
						line += "%s_%s".printf(child.device.replace("/dev/",""), child.children[0].device.replace("/dev/",""));
					}
					else{
						line += "%s".printf(child.device.replace("/dev/",""));
					}
				}
				else{
					line += "%s".printf(child.device.replace("/dev/",""));
				}
			}
			
			log_debug(line);
		}

		log_debug("");
	}

	public static void print_device_list_short(Gee.ArrayList<Device> list){
	
		string txt = "";
		foreach(var item in list){
			txt += (txt.length == 0) ? "" : " ";
			txt += "%s".printf(file_basename(item.device));
		}
		log_debug("Devices: " + txt);
	}

}

public class DeviceMonitor : GLib.Object{

	private static DeviceMonitor? device_monitor;
	private static GLib.VolumeMonitor? monitor;
	private static uint tmr_init = 0;
	
	public signal void changed();

	public signal void drive_changed (Drive drive);
	public signal void drive_connected (Drive drive);
	public signal void drive_disconnected (Drive drive);
	//public signal void drive_eject_button (Drive drive)
	//public signal void drive_stop_button (Drive drive)
	public signal void mount_added (Mount mount);
	public signal void mount_changed (Mount mount);
	//public signal void mount_pre_unmount (Mount mount)
	public signal void mount_removed (Mount mount);
	public signal void volume_added (Volume volume);
	public signal void volume_changed (Volume volume);
	public signal void volume_removed (Volume volume);

	/*
	Known Issues:
	Sometimes when a device is mounted, the event is not detected by GLib.VolumeMonitor
	*/
	
	private DeviceMonitor(){

	}
	
	public static DeviceMonitor get_monitor(){

		if (device_monitor != null){ return device_monitor; }
		
		device_monitor = new DeviceMonitor();
		monitor = VolumeMonitor.get();

		// drive changes -------------------------------
		
		monitor.drive_connected.connect((drive) => {
			print_drive (drive, "Drive connected");
			device_monitor.drive_connected(drive);
			start_timer();
		});

		monitor.drive_changed.connect((drive) => {
			print_drive (drive, "Drive changed");
			device_monitor.drive_changed(drive);
			start_timer();
		});

		monitor.drive_disconnected.connect((drive) => {
			print_drive (drive, "Drive disconnected");
			device_monitor.drive_disconnected(drive);
			start_timer();
		});
		
		// mount changes -----------------------------------
		
		monitor.mount_added.connect((mount) => {
			print_mount (mount, "Mount added");
			device_monitor.mount_added (mount);
			start_timer();
		});

		monitor.mount_changed.connect((mount) => {
			print_mount (mount, "Mount changed");
			device_monitor.mount_changed (mount);
			start_timer();
		});

		monitor.mount_removed.connect((mount) => {
			print_mount (mount, "Mount removed");
			device_monitor.mount_removed (mount);
			start_timer();
		});

		// mountable volume changes

		monitor.volume_added.connect((volume) => {
			print_volume (volume, "Volume added");
			device_monitor.volume_added (volume);
			start_timer();
		});

		monitor.volume_changed.connect((volume) => {
			print_volume (volume, "Volume changed");
			device_monitor.volume_changed (volume);
			start_timer();
		});

		monitor.volume_removed.connect((volume) => {
			print_volume (volume, "Volume removed");
			device_monitor.volume_removed (volume);
			start_timer();
		});
		
		/*monitor.drive_connected.connect ((drive) => {
			print_drive (drive, "Drive connected");

			// Reject all newly connected drives:
			drive.eject_with_operation.begin (MountUnmountFlags.FORCE, null, null, (obj, res) => {
				try {
					bool status = drive.eject_with_operation.end (res);
					stdout.printf ("eject: %s: %s\n", drive.get_name (), status.to_string ());
				} catch (Error e) {
					stdout.printf ("Error: %s\n", e.message);
				}
			});
		});*/
	
		
		return device_monitor;
	}

	private static void start_timer(){
		if (tmr_init > 0){
			Source.remove(tmr_init);
			tmr_init = 0;
		}
		tmr_init = Timeout.add(500, init_delayed);
	}

	public static void notify_change(){
		/*
		Known Issues:
		Sometimes when a device is mounted, the event is not detected by GLib.VolumeMonitor
		Call this explicity after a mount operation
		*/
	
		start_timer();
	}

	private static bool init_delayed(){

		if (tmr_init > 0){
			Source.remove(tmr_init);
			tmr_init = 0;
		}

		device_monitor.changed();
		
		return false;
	}
	
	private static void print_drive (Drive drive, string title) {
		
		stdout.printf ("\n");
		stdout.printf ("%s:\n", title);
		stdout.printf ("  name: %s\n", drive.get_name ());
		stdout.printf ("  can-eject: %s\n", drive.can_eject ().to_string ());
		stdout.printf ("  can-poll-for-media: %s\n", drive.can_poll_for_media ().to_string ());
		stdout.printf ("  can-start: %s\n", drive.can_start ().to_string ());
		stdout.printf ("  can-start-degraded: %s\n", drive.can_start_degraded ().to_string ());
		stdout.printf ("  can-stop: %s\n", drive.can_stop ().to_string ());
		stdout.printf ("  has-volumes: %s\n", drive.has_volumes ().to_string ());
		stdout.printf ("  has-media: %s\n", drive.has_media ().to_string ());
		stdout.printf ("  is-media-check-automatic: %s\n", drive.is_media_check_automatic ().to_string ());
		stdout.printf ("  is-media-removable: %s\n", drive.is_media_removable ().to_string ());
		stdout.printf ("  start-stop-type: %s\n", drive.get_start_stop_type ().to_string ());

		string[] kinds = drive.enumerate_identifiers ();
		foreach (unowned string kind in kinds) {
			stdout.printf ("    %s = %s\n", kind, drive.get_identifier (kind));
		}
		stdout.printf ("\n");
	}

	private static void print_mount (Mount mount, string title) {
		
		stdout.printf ("\n");
		stdout.printf ("%s:\n", title);
		stdout.printf ("  name: %s\n", mount.get_name ());
		stdout.printf ("  uuid: %s\n", mount.get_uuid ());
		stdout.printf ("  can-eject: %s\n", mount.can_eject ().to_string ());
		stdout.printf ("  can-unmount: %s\n", mount.can_unmount ().to_string ());
		stdout.printf ("  is-shadowed: %s\n", mount.is_shadowed ().to_string ());
		stdout.printf ("  default-location: %s\n", mount.get_default_location ().get_path ());
		stdout.printf ("  icon: %s\n", mount.get_icon ().to_string ());
		stdout.printf ("  root: %s\n", mount.get_root ().get_path ());

		try {
			string[] types = mount.guess_content_type_sync (false);
			stdout.printf ("  guess-content-type:\n");
			foreach (unowned string type in types) {
				stdout.printf ("    %s\n", type);
			}
		} catch (Error e) {
			stdout.printf ("Error: %s\n", e.message);
		}
		stdout.printf ("\n");
	}

	private static void print_volume (Volume volume, string title) {
		
		stdout.printf ("\n");
		stdout.printf ("%s:\n", title);
		stdout.printf ("  name: %s\n", volume.get_name ());
		stdout.printf ("  can-eject: %s\n", volume.can_eject ().to_string ());
		stdout.printf ("  can-mount: %s\n", volume.can_mount ().to_string ());

		string[] kinds = volume.enumerate_identifiers ();
		foreach (unowned string kind in kinds) {
			stdout.printf ("    %s = %s\n", kind, volume.get_identifier (kind));
		}
		stdout.printf ("\n");
	}

	public static List<Mount> get_mounts(){
		return monitor.get_mounts();
	}
}






