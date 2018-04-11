
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

	// static -----------------------------
	
	public static void init(){

		get_block_devices();
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
		
				var match_a = regex_match("""^(.*)([0-9]+)$""", a.kname);
					
				var match_b = regex_match("""^(.*)([0-9]+)$""", b.kname);

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

	public bool unmount(){

		var cmd = "udisksctl unmount -b '%s'".printf(device);
		log_debug(cmd);
		string std_err, std_out;
		exec_sync(cmd, out std_out,  out std_err);

		if (std_err.length > 0){
			log_error(std_err);
		}

		query_mount_points();
		
		return is_mounted;
	}

	public bool unlock(string _mapped_name, bool show_on_success = false){

		if (is_unlocked){ return true; }

		var cmd = "cryptsetup luksOpen '%s' '%s'".printf(device, _mapped_name);
		log_debug(cmd);

		string std_out, std_err;
		exec_sync(cmd, out std_out, out std_err);

		get_block_devices();

		var dev = get_device_by_name(device);
		
		return ((dev != null) && dev.has_children);
	}

	public bool lock_device(){

		log_debug("Device: lock_device(): %s".printf(device));

		var dev = this;

		if (is_encrypted_partition){
			if (!has_children){
				log_debug("Device is locked!");
				return true;
			}
			else{
				dev = children[0];
			}
		}
		else if (is_on_encrypted_partition){

			dev = this;
		}
		else{
			log_debug("Device not encrypted!");
			return true;
		}

		if (dev.mapped_name.length == 0){
			log_error("Could not determine mapped name!");
			return false;
		}

		var cmd = "cryptsetup luksClose %s".printf(dev.mapped_name);
		log_debug(cmd);

		string std_out, std_err;
		exec_script_sync(cmd, out std_out, out std_err, false, true); // prompt user if not admin

		get_block_devices();
		
		dev = get_device_by_name(dev.device);
		
		return (dev == null);
	}

	public void flush_buffers(){
		if (!is_mounted) { return; }
		if (type != "disk") { return; }
		string cmd = "blockdev --flushbufs %s".printf(device);
		Posix.system(cmd);
	}

	public static void show_message(string message, string details, bool is_error, bool show_on_success){ 
 
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

	public static void update_usage(Gee.ArrayList<Device>? _list = null){

		//log_debug("Device: update_usage(): %d".printf(device_list.size));

		Gee.ArrayList<Device>? list = _list;
		
		if (list == null){ list = device_list; }
		
		var list2 = get_disk_space_using_df();
		
		foreach(var dev2 in list2){
			
			var dev = get_device_by_uuid(dev2.uuid, list);
			
			if (dev != null){
				dev.size_bytes = dev2.size_bytes;
				dev.used_bytes = dev2.used_bytes;
				dev.available_bytes = dev2.available_bytes;
			}
		}
	}
	
	public static void update_mounts(Gee.ArrayList<Device>? _list = null){

		//log_debug("Device: update_usage(): %d".printf(device_list.size));

		Gee.ArrayList<Device>? list = _list;
		
		if (list == null){ list = device_list; }
		
		var list2 = get_mounted_filesystems_using_mtab();

		foreach(var dev2 in list2){
			
			var dev = get_device_by_uuid(dev2.uuid, list);
			
			if (dev != null){
				dev.mount_points = dev2.mount_points;
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
		//log_debug(cmd);

		string std_out, std_err;
		exec_sync(cmd, out std_out, out std_err);
		//ret_val is not reliable, no need to check

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

	public static Gee.ArrayList<MountEntry> get_device_mount_points(string dev_alias){

		var list_mtab = get_mounted_filesystems_using_mtab();

		var dev_name = resolve_device_name(dev_alias);

		var dev = get_device_by_name(dev_name, list_mtab);

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

	// testing -----------------------------------

	public static void test_all(){

		get_devices();
		
		print_device_list();

		print_device_relationships();

		print_device_mounts();
	}
	
	public static void print_device_list(Gee.ArrayList<Device>? _list = null){

		Gee.ArrayList<Device>? list = _list;
		if (list == null){ list = device_list; }
		
		log_msg("");

		log_msg("%-15s %-10s %-10s %-10s %-10s %-10s".printf(
			"device",
			"pkname",
			"kname",
			"type",
			"fstype",
			"mapped"
			));

		log_msg(string.nfill(100, '-'));

		foreach(var dev in list){
			log_msg("%-15s %-10s %-10s %-10s %-10s %-10s".printf(
				dev.device ,
				dev.pkname,
				dev.kname,
				dev.type,
				dev.fstype,
				dev.mapped_name
				));
		}

		log_msg("");

		//print_device_relationships(list);
	}

	public static void print_device_relationships(Gee.ArrayList<Device>? _list = null){

		Gee.ArrayList<Device>? list = _list;
		if (list == null){ list = device_list; }
		
		log_msg("");

		log_msg(string.nfill(100, '-'));
		
		foreach(var dev in list){
			
			if (dev.pkname.length == 0){
				
				log_msg("%-10s".printf(dev.kname));

				foreach(var child1 in dev.children){
					if (!child1.has_children){
						log_msg("%-10s -- %-10s".printf(dev.kname, child1.kname));
					}
					else{
						foreach(var child2 in child1.children){
							log_msg("%-10s -- %-10s -- %-10s".printf(dev.kname, child1.kname, child2.kname));
						}
					}
				}
			}
		}

		log_msg("");
	}

	public static void print_device_mounts(Gee.ArrayList<Device>? _list = null){ 

		Gee.ArrayList<Device>? list = _list;
		if (list == null){ list = device_list; }
		
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

	public static void print_device_list_short(Gee.ArrayList<Device> list){
	
		string txt = "";
		foreach(var item in list){
			txt += (txt.length == 0) ? "" : " ";
			txt += "%s".printf(file_basename(item.device));
		}
		log_debug("Devices: " + txt);
	}

}





