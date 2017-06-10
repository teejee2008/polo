/*
 * KvmTask.vala
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

public enum KvmTaskType{
	CONVERT_MERGE,
	CONVERT_DISK,
	CREATE_DISK,
	CREATE_DISK_DERIVED
}

public class KvmTask : AsyncTask {

	private KvmTaskType task_type;
	private string file_path = "";
	private string derived_file = "";
	//private string base_file = "";
	private string disk_format = "";
	private Gtk.Window? window = null;

	public KvmTask(){
		init_regular_expressions();
	}

	public void create_disk_merged(string _file_path, string _derived_file, Gtk.Window? _window){
		file_path = _file_path;
		derived_file = _derived_file;
		window = _window;
		task_type = KvmTaskType.CONVERT_MERGE;
	}

	public void convert_disk(string _file_path, string _derived_file, string _disk_format, Gtk.Window? _window){
		file_path = _file_path;
		derived_file = _derived_file;
		disk_format = _disk_format;
		window = _window;
		task_type = KvmTaskType.CONVERT_DISK;
	}

	private void init_regular_expressions(){
		
		regex_list = new Gee.HashMap<string, Regex>();
		
		try {
			//   (1.00/100%)
			regex_list["qemu-convert"] = new Regex("""[ \t]*[(]?([0-9.]+)\/[0-9.]+[%]?[)]?""");
		}
		catch (Error e) {
			log_error (e.message);
		}
	}

	public void prepare() {
		
		string script_text = build_script();
		save_bash_script_temp(script_text, script_file);

		count_completed = 0;
		count_total = 100;
	}

	private string build_script() {
		
		string cmd = "";

		switch (task_type){
		case KvmTaskType.CONVERT_MERGE:
			cmd = build_script_create_disk_merged();
			break;
		case KvmTaskType.CONVERT_DISK:
			cmd = build_script_convert_disk();
			break;
		}
		
		return cmd;
	}

	private string build_script_create_disk_merged(){
		
		string cmd = "qemu-img convert";
		
		cmd += " -p";
		
		//cmd += " -f qcow2";

		cmd += " -O qcow2";

		cmd += " '%s'".printf(escape_single_quote(derived_file));

		cmd += " '%s'".printf(escape_single_quote(file_path));

		log_debug(cmd);

		return cmd;
	}

	private string build_script_convert_disk(){

		string cmd = "qemu-img convert";
		
		cmd += " -p";
		
		//cmd += " -f qcow2";

		cmd += " -O %s".printf(disk_format.down());

		cmd += " '%s'".printf(escape_single_quote(derived_file));

		cmd += " '%s'".printf(escape_single_quote(file_path));

		log_debug(cmd);

		return cmd;
		
	}

	
	public static bool is_supported_disk_format(string disk_file_path){
		
		string extension = file_get_extension(disk_file_path);

		switch(extension.down()){
		case ".qcow":
		case ".qcow2":
		case ".vdi":
		case ".vmdk":
		case ".vhd":
		case ".img":
			return true;
		}
		
		return false;
	}
	
	// extra, sync

	public void create_disk(string file_path, double size, string base_file, Gtk.Window? window){
		
		string cmd = "qemu-img create";

		cmd += " -f qcow2";

		if (base_file.length > 0){
			cmd += " -b '%s'".printf(escape_single_quote(file_basename(base_file)));
		}

		cmd += " '%s'".printf(escape_single_quote(file_path));

		if (base_file.length == 0){
			cmd += " %.1fG".printf(size);
		}

		log_debug(cmd);

		gtk_set_busy(true, window);
		
		string std_out, std_err;
		exec_sync(cmd, out std_out, out std_err);

		gtk_set_busy(false, window);

		if (std_err.length > 0){
			gtk_messagebox(_("Finished with errors"), std_err, window, true);
		}
		else{
			if (base_file.length > 0){
				chmod(base_file, "a-w", window);
			}
		}
	}

	public void boot_iso(string iso_path, Json.Object config){
		
		string cmd = "";
		
		cmd += get_kvm_config(config);
		
		cmd += " -boot d -cdrom '%s'".printf(escape_single_quote(iso_path));
		
		log_debug(cmd);
		
		int pid = exec_script_async(cmd);

		if (pid != -1){
			set_cpu_limit(pid);
		}
	}

	public void boot_disk(string disk_path, Json.Object config){
		
		string cmd = "";
		
		cmd += get_kvm_config(config);
		
		cmd += " -hda '%s'".printf(escape_single_quote(disk_path));
		
		log_debug(cmd);
		
		int pid = exec_script_async(cmd);

		if (pid != -1){
			set_cpu_limit(pid);
		}
	}

	public void boot_iso_attach_disk(string iso_path, string disk_path, Json.Object config){
		
		string cmd = "";
		
		cmd += get_kvm_config(config);

		cmd += " -hda '%s'".printf(escape_single_quote(disk_path));
		
		cmd += " -boot d -cdrom '%s'".printf(escape_single_quote(iso_path));
		
		log_debug(cmd);
		
		int pid = exec_script_async(cmd);

		if (pid != -1){
			set_cpu_limit(pid);
		}
	}

	public string get_kvm_config(Json.Object config){

		string kvm_cpu = json_get_string(config, "kvm_cpu", "host");
		int kvm_smp = json_get_int(config, "kvm_smp", 1);
		string kvm_vga = json_get_string(config, "kvm_vga", "vmware");
		int kvm_mem = json_get_int(config, "kvm_mem", 1024);
		string kvm_smb = json_get_string(config, "kvm_smb", "");

		string cmd = "";
		cmd += "kvm -enable-kvm";
		cmd += " -cpu %s".printf(kvm_cpu);
		cmd += " -smp %d".printf(kvm_smp);
		cmd += " -vga %s".printf(kvm_vga);
		cmd += " -m %dM".printf(kvm_mem);
		//cmd += " -net nic,model=virtio -net user";
		cmd += " -netdev user,id=vmnic -device virtio-net,netdev=vmnic";
		if (kvm_smb.length > 0){
			cmd += " -smb '%s'".printf(kvm_smb);
		}
		return cmd;
	}

	public void set_cpu_limit(int pid){

		if (App.kvm_cpu_limit == 100) { return; }

		int cpu_max = App.sysinfo.cpu_cores * App.kvm_cpu_limit;

		string cmd = "cpulimit -l %d -p %d".printf(cpu_max, pid);
		
		log_debug(cmd);
		
		exec_script_async(cmd);
	}

	// execution ----------------------------

	public void execute() {

		prepare();

		begin();

		if (status == AppStatus.RUNNING){
			
			
		}
	}

	public override void parse_stdout_line(string out_line){
		if (is_terminated) {
			return;
		}
		
		update_progress_parse_console_output(out_line);
	}
	
	public override void parse_stderr_line(string err_line){
		if (is_terminated) {
			return;
		}
		
		update_progress_parse_console_output(err_line);
	}

	public bool update_progress_parse_console_output (string line) {
		
		if ((line == null) || (line.length == 0)) { return true; }

		log_debug(line);
		
		MatchInfo match;
		if (regex_list["qemu-convert"].match(line, 0, out match)) {
			string txt = match.fetch(1);
			count_completed = int.parse(txt);
			progress = count_completed / 100.0;
			status_line = "%lld%%".printf(count_completed);
		}
		
		return true;
	}

	protected override void finish_task(){
		if ((status != AppStatus.CANCELLED) && (status != AppStatus.PASSWORD_REQUIRED)) {
			status = AppStatus.FINISHED;
		}
	}

	public int read_status(){
		var status_file = working_dir + "/status";
		var f = File.new_for_path(status_file);
		if (f.query_exists()){
			var txt = file_read(status_file);
			return int.parse(txt);
		}
		return -1;
	}
}
