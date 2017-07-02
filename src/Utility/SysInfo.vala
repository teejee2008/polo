
/*
 * SysInfo.vala
 *
 * Copyright 2017 Tony George <teejee2008@gmail.com>
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

public class SysInfo : GLib.Object {

	public int arch = 64;
	public int mem_total_mb = 0;
	public string hostname = "";
	public int cpu_cores = 1;
	
	public SysInfo(){
		query();
	}

	public void query(){
		query_arch();
		query_cpu_cores();
		query_host_name();
		query_memory();
		print();
	}

	public void query_arch(){

		string std_out, std_err;
		exec_sync("uname -m", out std_out, out std_err);

		if (std_out.replace("\n","").strip().down() == "x86_64"){
			arch = 64;
		}
		else{
			arch = 32;
		}
	}
	
	public void query_cpu_cores(){

		string std_out, std_err;
		exec_sync("grep -c ^processor /proc/cpuinfo", out std_out, out std_err);

		cpu_cores = int.parse(std_out);
	}

	public void query_host_name(){		

		hostname = GLib.Environment.get_host_name();
	}

	public void query_memory(){

		string std_out, std_err;
		exec_script_sync("grep MemTotal /proc/meminfo | awk '{print $2}'", out std_out, out std_err);

		mem_total_mb = (int) (int.parse(std_out) / 1024.0);
	}

	public void print(){
		log_msg("Architecture: %d-bit".printf(arch));
		log_msg("Host Name: %s".printf(hostname));
		log_msg("CPU Cores: %d".printf(cpu_cores));
		log_msg("RAM: %d MB".printf(mem_total_mb));
	}
}

