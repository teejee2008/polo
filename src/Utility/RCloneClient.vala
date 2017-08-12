
/*
 * RCloneClient.vala
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
using TeeJee.System;
using TeeJee.Misc;

public class RCloneClient : GLib.Object {

	public string config_file_path = "";
	public string rclone_mounts = "";
	public string rclone_logs = "";

	public signal void changed();
	
	public Gee.ArrayList<CloudAccount> accounts = new Gee.ArrayList<CloudAccount>();
	public Gee.HashMap<string,CloudAccount> lookup = new Gee.HashMap<string,CloudAccount>();

	public RCloneClient(){

		string user_home = get_user_home();
		
		config_file_path = path_combine(user_home, ".config/rclone/rclone.conf");

		rclone_mounts = path_combine(user_home, ".config/rclone/rclone-mounts");
		
		accounts = new Gee.ArrayList<CloudAccount>();
		lookup = new Gee.HashMap<string,CloudAccount>();
		
		query_accounts();
	}

	public void query_accounts(){

		log_debug("RCloneClient: query_accounts()");
		
		accounts.clear();
		lookup.clear();
		
		parse_config_file();
		
		query_mounted_remotes();
		
		log_debug("RCloneClient: query_accounts(): %d".printf(accounts.size));

		//changed(); // will be called by query_mounted_remotes()
	}

	private void parse_config_file(){
		
		if(!file_exists(config_file_path)){ return; }

		string txt = file_read(config_file_path);

		string name = "";
		string type = "";
		
		foreach(string line in txt.split("\n")){

			var match = regex_match("""^\[(.*)\]$""", line);
			if (match != null){
				name = match.fetch(1);
				continue;
			}

			match = regex_match("""^type[ \t]*=[ \t]*(.*)$""", line);
			if (match != null){
				type = match.fetch(1);
				continue;
			}

			if ((line.length == 0) && (name.length > 0) && (type.length > 0)){
				
				add_account(name, type);
				name = "";
				type = "";
			}
		}
	}

	public void query_mounted_remotes(){

		log_debug("RCloneClient: query_mounted_remotes()");
		
		string txt = file_read("/etc/mtab");

		foreach(var acc in accounts){
			acc._mounted = false;
			acc._mounted_path = "";
		}
		
		int mounted_count = 0;
				
		foreach(string line in txt.split("\n")){

			if (!line.contains("fuse.rclone")){ continue; }

			var match = regex_match("""^(.+)[ \t]+(.+)[ \t]+(.+)[ \t]+(.+)[ \t]+([0-9]+)[ \t]+([0-9]+)$""", line);
			
			if (match != null){

				//log_debug("match: %s".printf(line));
				
				string device = match.fetch(1);
				string mpath = match.fetch(2);
				string fs = match.fetch(3);
				string options = match.fetch(4);

				if (fs != "fuse.rclone"){ continue; }

				foreach(var acc in accounts){
					//log_debug("device: %s, name: %s".printf(device, acc.name));
					if (acc.name == device.replace(":","")){
						acc._mounted = true;
						acc._mounted_path = mpath.replace("""\040"""," ").replace("""\046""","&"); // replace space. TODO: other chars?;
						log_debug("found remote mount: %s, %s".printf(acc.name, acc._mounted_path));
						mounted_count++;
						break;
					}
				}
			}
		}

		changed();
		
		log_debug("RCloneClient: query_mounted_remotes(): %d".printf(mounted_count));
	}

	public CloudAccount add_account(string name, string type){
		
		var acc = new CloudAccount(this, name, type, rclone_mounts);
		accounts.add(acc);
		lookup[acc.name] = acc;
		
		log_debug("Found account: %s, %s".printf(name, type));
		
		return acc;
	}

	public string get_mounted_path(string acc_name){
		if (lookup.has_key(acc_name)){
			return lookup[acc_name]._mounted_path;
		}
		return "";
	}
}

public class CloudAccount : GLib.Object {
	
	public string name = "";
	public string local_path = "";
	public string type = "";

	public string rclone_mounts = "";
	public string mount_path = "";

	public bool _mounted = false; // for use by RCloneClient only
	public string _mounted_path = ""; // for use by RCloneClient only
	
	private RCloneClient client = null;
	
	public static string[] account_types = {
		"amazon cloud drive",
		"s3",
		"b2",
		"dropbox",
		"google cloud storage",
		"drive",
		"hubic",
		"onedrive",
		"swift",
		"yandex"
	};

	public static string[] account_type_names = {
		"Amazon Drive",
		"Amazon S3",
		"Backblaze B2",
		"Dropbox",
		"Google Cloud Storage",
		"Google Drive",
		"Hubic",
		"Microsoft OneDrive",
		"Openstack Swift",
		"Yandex Disk"
	};

	private static void initialize_types(){
		
		/*
		types["amazon cloud drive"] = "Amazon Drive";
		types["s3"] = "Amazon S3 (also Dreamhost, Ceph, Minio)";
		types["b2"] = "Backblaze B2";
		types["dropbox"] = "Dropbox";
		types["google cloud storage"] = "Google Cloud Storage";
		types["drive"] = "Google Drive";
		types["hubic"] = "Hubic";
		types["onedrive"] = "Microsoft OneDrive";
		types["swift"] = "Openstack Swift (Rackspace Cloud Files, Memset Memstore, OVH)";
		types["sftp"] = "SSH/SFTP Connection";
		types["yandex"] = "Yandex Disk";
		*/
	}
	
	public CloudAccount(RCloneClient _client, string _name, string _type, string _rclone_mounts){

		client = _client;
		
		initialize_types();
		
		name = _name;
		type = _type;

		rclone_mounts = _rclone_mounts;
		mount_path = path_combine(_rclone_mounts, _name);
	}

	public string type_name{
		owned get {
			var list = new Gee.ArrayList<string>.wrap(account_types);
			return account_type_names[list.index_of(type)];
		}
	}

	public void mount(){

		log_debug("CloudAccount: mount(): %s, %s".printf(name, mount_path));
		
		dir_create(mount_path);

		string rclone_logs = path_combine(rclone_mounts, "logs");
		dir_create(rclone_logs);

		string log_name = "%s_%s.log".printf(name, timestamp_for_path());
		string log_path = path_combine(rclone_logs, log_name);
		
		string cmd = "rclone mount %s: '%s' > '%s'".printf(name, escape_single_quote(mount_path), escape_single_quote(log_path));

		log_debug(cmd);
		
		exec_process_new_session(cmd);
	
		start_changed_delayed_timer();
	}

	public void unmount(){

		log_debug("CloudAccount: unmount(): %s, %s".printf(name, mount_path));

		string cmd = "fusermount -u '%s'".printf(escape_single_quote(mount_path));

		log_debug(cmd);
		
		string std_out, std_err;
		int status = exec_sync(cmd, out std_out, out std_err);

		start_changed_delayed_timer();
	}
	
	// trigger changed signal with delay ------------------------

	private static uint tmr_changed = 0;
	
	private void start_changed_delayed_timer(){
		if (tmr_changed > 0){
			Source.remove(tmr_changed);
			tmr_changed = 0;
		}
		tmr_changed = Timeout.add(500, changed_delayed);
	}
	
	private bool changed_delayed(){

		if (tmr_changed > 0){
			Source.remove(tmr_changed);
			tmr_changed = 0;
		}

		client.query_mounted_remotes();
		client.changed();
		
		return false;
	}
}

