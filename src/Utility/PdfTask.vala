/*
 * PdfTask.vala
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

public enum PdfTaskType{
	SPLIT,
	MERGE,
	PROTECT,
	UNPROTECT
}

public class PdfTask : GLib.Object {

	private PdfTaskType task_type;
	private string file_path = "";
	private Gee.ArrayList<FileItem> selected_files;
	private Gtk.Window? window = null;

	public PdfTask(){

	}

	public static void split(string file_path, Gtk.Window? window){

		if (!file_exists(file_path)){ return; }
		
		string cmd = "pdftk";

		cmd += " '%s'".printf(escape_single_quote(file_path));

		cmd += " burst";
		
		string outfile = "%s_page_%%03d.pdf".printf(file_get_title(file_path));
		outfile = path_combine(file_parent(file_path), outfile);
		
		cmd += " output '%s'".printf(escape_single_quote(outfile));

		//cmd += " compress";
		
		log_debug(cmd);

		gtk_set_busy(true, window);
		
		string std_out, std_err;
		exec_sync(cmd, out std_out, out std_err);

		gtk_set_busy(false, window);

		if (std_err.length > 0){
			gtk_messagebox(_("Finished with errors"), std_err, window, true);
		}
	}
	
	public static void uncompress(string file_path, Gtk.Window? window){

		if (!file_exists(file_path)){ return; }
		
		string cmd = "pdftk";

		cmd += " '%s'".printf(escape_single_quote(file_path));

		string outfile = "%s_uncompressed.pdf".printf(file_get_title(file_path));
		outfile = path_combine(file_parent(file_path), outfile);
		cmd += " output '%s'".printf(escape_single_quote(outfile));

		cmd += " uncompress";
		
		log_debug(cmd);

		gtk_set_busy(true, window);
		
		string std_out, std_err;
		exec_sync(cmd, out std_out, out std_err);

		gtk_set_busy(false, window);

		if (std_err.length > 0){
			gtk_messagebox(_("Finished with errors"), std_err, window, true);
		}
	}

	public static void merge(Gee.ArrayList<FileItem> files, Gtk.Window? window){
		
		if (files.size == 0){ return; }
		
		string cmd = "pdftk";

		foreach(var item in files){
			cmd += " '%s'".printf(escape_single_quote(item.file_path));
		}

		cmd += " cat";

		string title = file_get_title(files[0].file_path);
		var match = regex_match("""^(.*)[^0-9][0-9]*$""", title);
		if (match != null){
			title = match.fetch(1);
		}

		string outfile = "%s_merged.pdf".printf(title);
		outfile = path_combine(file_parent(files[0].file_path), outfile);

		cmd += " output '%s'".printf(escape_single_quote(outfile));

		//cmd += " compress";
		
		log_debug(cmd);

		gtk_set_busy(true, window);
		
		string std_out, std_err;
		exec_sync(cmd, out std_out, out std_err);

		gtk_set_busy(false, window);

		if (std_err.length > 0){
			gtk_messagebox(_("Finished with errors"), std_err, window, true);
		}
	}

	public static void protect(string file_path, string password, Gtk.Window? window){
		
		if (!file_exists(file_path)){ return; }
		
		string cmd = "pdftk";

		cmd += " '%s'".printf(escape_single_quote(file_path));

		string title = file_get_title(file_path);
		var match = regex_match("""^(.*)_[un]*protected$""", title);
		if (match != null){
			title = match.fetch(1);
		}
		
		string outfile = "%s_protected.pdf".printf(title);
		outfile = path_combine(file_parent(file_path), outfile);

		cmd += " output '%s'".printf(escape_single_quote(outfile));

		//cmd += " owner_pw '%s'".printf(password);

		cmd += " user_pw '%s'".printf(password);
		
		log_debug(cmd);

		gtk_set_busy(true, window);
		
		string std_out, std_err;
		exec_sync(cmd, out std_out, out std_err);

		gtk_set_busy(false, window);

		if (std_err.length > 0){
			gtk_messagebox(_("Finished with errors"), std_err, window, true);
		}
	}

	public static void unprotect(string file_path, string password, Gtk.Window? window){
		
		if (!file_exists(file_path)){ return; }
		
		string cmd = "pdftk";

		cmd += " '%s'".printf(escape_single_quote(file_path));

		cmd += " input_pw '%s'".printf(password);

		string title = file_get_title(file_path);
		var match = regex_match("""^(.*)_[un]*protected$""", title);
		if (match != null){
			title = match.fetch(1);
		}
		
		string outfile = "%s_unprotected.pdf".printf(title);
		outfile = path_combine(file_parent(file_path), outfile);

		cmd += " output '%s'".printf(escape_single_quote(outfile));

		log_debug(cmd);

		gtk_set_busy(true, window);
		
		string std_out, std_err;
		exec_sync(cmd, out std_out, out std_err);

		gtk_set_busy(false, window);

		if (std_err.length > 0){
			gtk_messagebox(_("Finished with errors"), std_err, window, true);
		}
	}

	public static void convert_grayscale(string file_path, Gtk.Window? window){

		if (!file_exists(file_path)){ return; }

		string outfile = "%s_decolored.pdf".printf(file_get_title(file_path));
		outfile = path_combine(file_parent(file_path), outfile);
		
		string cmd = "gs";
		cmd += " -sOutputFile='%s'".printf(escape_single_quote(outfile));
		cmd += " -sDEVICE=pdfwrite";
		cmd += " -sColorConversionStrategy=Gray";
		cmd += " -dProcessColorModel=/DeviceGray";
		cmd += " -dCompatibilityLevel=1.4";
		cmd += " -dDetectDuplicateImages=true";
		cmd += " -dNOPAUSE";
		cmd += " -dBATCH";
		cmd += " '%s'".printf(escape_single_quote(file_path));

		log_debug(cmd);

		gtk_set_busy(true, window);
		
		string std_out, std_err;
		exec_sync(cmd, out std_out, out std_err);

		gtk_set_busy(false, window);

		if (std_err.length > 0){
			gtk_messagebox(_("Finished with errors"), std_err, window, true);
		}
	}

	public static void optimize(string file_path, string target, Gtk.Window? window){

		if (!file_exists(file_path)){ return; }

		string outfile = "%s_optimized_%s.pdf".printf(file_get_title(file_path), target.down());
		outfile = path_combine(file_parent(file_path), outfile);
		
		string cmd = "gs";
		cmd += " -sOutputFile='%s'".printf(escape_single_quote(outfile));
		cmd += " -sDEVICE=pdfwrite";
		cmd += " -dCompatibilityLevel=1.4";
		cmd += " -dDetectDuplicateImages=true";
		cmd += " -dCompressFonts=true";
		cmd += " -dPDFSETTINGS=/%s".printf(target.down());
		cmd += " -dNOPAUSE";
		cmd += " -dBATCH";
		cmd += " '%s'".printf(escape_single_quote(file_path));

		log_debug(cmd);

		gtk_set_busy(true, window);
		
		string std_out, std_err;
		exec_sync(cmd, out std_out, out std_err);

		gtk_set_busy(false, window);

		if (std_err.length > 0){
			gtk_messagebox(_("Finished with errors"), std_err, window, true);
		}
	}

	public static void compress(string file_path, Gtk.Window? window){
		
		if (!file_exists(file_path)){ return; }

		string outfile = "%s_compressed.pdf".printf(file_get_title(file_path));
		outfile = path_combine(file_parent(file_path), outfile);
		
		string cmd = "gs";
		cmd += " -sOutputFile='%s'".printf(escape_single_quote(outfile));
		cmd += " -sDEVICE=pdfwrite";
		cmd += " -dCompatibilityLevel=1.4";
		cmd += " -dDetectDuplicateImages=true";
		cmd += " -dCompressFonts=true";
		cmd += " -dPDFSETTINGS=/%s".printf("screen");
		cmd += " -dNOPAUSE";
		cmd += " -dBATCH";
		cmd += " '%s'".printf(escape_single_quote(file_path));

		log_debug(cmd);

		gtk_set_busy(true, window);
		
		string std_out, std_err;
		exec_sync(cmd, out std_out, out std_err);

		gtk_set_busy(false, window);

		if (std_err.length > 0){
			gtk_messagebox(_("Finished with errors"), std_err, window, true);
		}
	}
	
	public static void rotate(string file_path, string direction, Gtk.Window? window){

		if (!file_exists(file_path)){ return; }

		string cmd = "pdftk";

		cmd += " '%s'".printf(escape_single_quote(file_path));

		string orientation = "";
		
		switch(direction){
		case "right":
			orientation = "east";
			break;
		case "flip":
			orientation = "south";
			break;
		case "left":
			orientation = "west";
			break;
		}

		if (orientation.length > 0){
			cmd += " cat 1-end%s".printf(orientation);
		}
		
		string title = file_get_title(file_path);
		string outfile = "%s_rotated_%s.pdf".printf(title, direction);
		outfile = path_combine(file_parent(file_path), outfile);

		cmd += " output '%s'".printf(escape_single_quote(outfile));

		log_debug(cmd);

		gtk_set_busy(true, window);
		
		string std_out, std_err;
		exec_sync(cmd, out std_out, out std_err);

		gtk_set_busy(false, window);

		if (std_err.length > 0){
			gtk_messagebox(_("Finished with errors"), std_err, window, true);
		}
	}

}
