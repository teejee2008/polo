/*
 * Thumbnailer.vala
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
using Gee;

using TeeJee.Logging;
using TeeJee.FileSystem;
using TeeJee.JsonHelper;
using TeeJee.ProcessHelper;
using TeeJee.GtkHelper;
using TeeJee.System;
using TeeJee.Misc;

public class Thumbnailer : GLib.Object {

	// static
	public static string user_login;
	public static string user_home;

	public static Gee.ArrayList<string> search_paths;

	public static Gee.ArrayList<ThumbTask> task_list;

	public static Gee.HashMap<string, string> hash_lookup = new Gee.HashMap<string, string>();

	public static string default_thumbdir;

	public static bool generator_is_running;

	public static Mutex task_mutex;
	public static Mutex map_mutex;

	public static void init(){

		user_login = get_username();
		user_home = get_user_home();

		search_paths = new Gee.ArrayList<string>();
		foreach(string thumbdir in new string[] { ".thumbnails", ".cache/thumbnails" }){
			//foreach(string subdir in new string[] { "normal", "large" }){
				//search_paths.add(path_combine(path_combine(user_home, thumbdir), subdir));
				search_paths.add(path_combine(user_home, thumbdir));
			//}
		}

		default_thumbdir = path_combine(user_home, ".cache/thumbnails");

		hash_lookup = new Gee.HashMap<string, string>();

		task_list = new Gee.ArrayList<ThumbTask>();

		task_mutex = Mutex();
	}

	private static string fail_directory {
		owned get {
			return path_combine(default_thumbdir, "fail/%s-%s".printf(AppShortName, AppVersion));
		}
	}

	public static Gdk.Pixbuf? lookup(FileItem file_item, int icon_size){

		Gdk.Pixbuf? pixbuf = null;

		string file_uri = file_item.file_path_prefix + file_item.file_path;
		string hash = file_item.thumb_key;

		// use images smaller than 128px directly, instead of generating thumbnails

		if (file_item.is_image){

			int width, height;
			Gdk.Pixbuf.get_file_info(file_item.file_path, out width, out height);

			if ((width <= icon_size) && (height <= icon_size)){
				try{
					pixbuf = new Gdk.Pixbuf.from_file(file_item.file_path);
					if (pixbuf != null){ return pixbuf; }
				}
				catch (Error e){
					// ignore
				}
			}
		}

		// use the file itself when getting thumbnail for file in thumbnails cache

		if (file_item.file_location.contains("thumbnails/normal")
			|| file_item.file_location.contains("thumbnails/large")
			|| file_item.file_location.contains("thumbnails/fail")){

			try {
				pixbuf = new Gdk.Pixbuf.from_file_at_scale(file_item.file_path, icon_size, icon_size, true);
				return pixbuf;
			}
			catch (Error e){
				// file itself is unreadable?
				return pixbuf;
			}
		}

		foreach(string thumbdir in search_paths){

			//log_debug("thumbnail cache: %s".printf(subdir));

			// try get normal and return if found -----

			if (icon_size <= 128){

				// search normal
				pixbuf = read_thumbnail_from_directory(thumbdir, "normal", hash, icon_size);

				if ((pixbuf != null) && (pixbuf.get_option("tEXt::Thumb::MTime") == file_item.modified_unix_time.to_string())){
					//log_debug("MTime: %s, URI: %s".printf(pixbuf.get_option("tEXt::Thumb::MTime"),pixbuf.get_option("tEXt::Thumb::URI")));
					return pixbuf;
				}

				// search large
				pixbuf = read_thumbnail_from_directory(thumbdir, "large", hash, icon_size);

				if ((pixbuf != null) && (pixbuf.get_option("tEXt::Thumb::MTime") == file_item.modified_unix_time.to_string())){
					//log_debug("MTime: %s, URI: %s".printf(pixbuf.get_option("tEXt::Thumb::MTime"),pixbuf.get_option("tEXt::Thumb::URI")));
					return pixbuf;
				}
			}
			else{
				// search large
				pixbuf = read_thumbnail_from_directory(thumbdir, "large", hash, icon_size);

				if ((pixbuf != null) && (pixbuf.get_option("tEXt::Thumb::MTime") == file_item.modified_unix_time.to_string())){
					//log_debug("MTime: %s, URI: %s".printf(pixbuf.get_option("tEXt::Thumb::MTime"),pixbuf.get_option("tEXt::Thumb::URI")));
					return pixbuf;
				}

				// search normal
				//pixbuf = read_thumbnail_from_directory(thumbdir, "normal", hash, icon_size);
				//if (pixbuf != null){
				//	return pixbuf;
				//}
			}

			// search fail
			pixbuf = read_thumbnail_from_directory(fail_directory, "", hash, icon_size);

			if ((pixbuf != null)
				&& (pixbuf.get_option("tEXt::Thumb::MTime") == file_item.modified_unix_time.to_string())
				&& (pixbuf.get_option("tEXt::Software") == "polo-file-manager")){

				log_debug("skipping failed thumbnail generated by Polo");
				return pixbuf;
			}
		}

		return null;
	}

	public static Gee.ArrayList<Gdk.Pixbuf> lookup_animation(FileItem file_item, int icon_size){

		log_debug("Thumbnailer: lookup_animation(): %s".printf(file_item.file_path));

		var list = new Gee.ArrayList<Gdk.Pixbuf>();

		string file_uri = file_item.file_path_prefix + file_item.file_path;

		string hash = "";

		if (hash_lookup.has_key(file_uri)){
			hash = hash_lookup[file_uri];
		}
		else{
			hash = string_checksum(file_uri);
			hash_lookup[file_uri] = hash;
		}

		foreach(string thumbdir in search_paths){

			if (icon_size <= 128){

				// search normal
				list = read_animation_from_directory(thumbdir, "normal", hash, icon_size);
				if (list.size > 0){ return list; }

				// search large
				list = read_animation_from_directory(thumbdir, "large", hash, icon_size);
				if (list.size > 0){ return list; }
			}
			else{
				// search large
				list = read_animation_from_directory(thumbdir, "large", hash, icon_size);
				if (list.size > 0){ return list; }

				// search normal
				list = read_animation_from_directory(thumbdir, "normal", hash, icon_size);
				if (list.size > 0){ return list; }
			}
		}

		return list;
	}

	private static Gdk.Pixbuf? read_thumbnail_from_directory(
		string thumbdir, string subdir,string hash, int icon_size){

		string thumb_path = path_combine(thumbdir, subdir);
		thumb_path = path_combine(thumb_path, hash + ".png");

		if (file_exists(thumb_path)){

			//log_debug("found thumbnail: %s".printf(thumb_path));

			try {

				int width, height;
				Gdk.Pixbuf.get_file_info(thumb_path, out width, out height);
				Gdk.Pixbuf pixbuf = null;

				if ((width <= icon_size) && (height <= icon_size)){
					// do not upscale, load smaller image
					pixbuf = new Gdk.Pixbuf.from_file(thumb_path);
				}
				else{
					// scale down
					pixbuf = new Gdk.Pixbuf.from_file_at_scale(thumb_path, icon_size, icon_size, true);
				}

				if (pixbuf != null){
					return pixbuf;
				}
			}
			catch (Error e){
				// ignore
			}
		}

		return null;
	}

	private static Gee.ArrayList<Gdk.Pixbuf> read_animation_from_directory(
		string thumbdir, string subdir, string hash, int icon_size){

		var list = new Gee.ArrayList<Gdk.Pixbuf>();

		string thumb_path = path_combine(thumbdir, subdir);
		string thumb_file = path_combine(thumb_path, hash + ".png");

		log_debug("Thumbnailer: read_animation_from_directory(): %s".printf(thumb_path));

		try {
			string img_dir = path_combine(thumbdir, subdir);

			for(int i = 1; i <= 10; i++){

				var img_file = path_combine(img_dir, hash + "-%03d.png".printf(i));

				if (file_exists(img_file)){
					var pixbuf = new Gdk.Pixbuf.from_file_at_scale(img_file, icon_size, icon_size, true);
					list.add(pixbuf);
					log_debug("found: %s".printf(img_file));
				}
				else{
					log_debug("not found: %s".printf(img_file));
					break;
				}
			}
		}
		catch (Error e){
			// ignore
		}

		return list;
	}

	public static void add_to_queue(ThumbTask task){

		if (!task.file_item.is_image && !task.file_item.is_video){
			return;
		}

		task_mutex.lock();
		task_list.add(task);
		task_mutex.unlock();

		log_debug("Thumbnailer: add_to_queue(): %s".printf(task.file_item.file_path));

		if (!generator_is_running){
			start_thumbnail_generator();
		}
	}

	public static void remove_from_queue(ThumbTask task){

		task_mutex.lock();
		if (task_list.contains(task)){
			task_list.remove(task);
		}
		task_mutex.unlock();
	}

	public static void start_thumbnail_generator(){

		log_debug("Thumbnailer: start_thumbnail_generator()");

		try {
			//start thread for thumbnail generation
			Thread.create<void> (thumbnail_generator_thread, true);
		}
		catch (Error e) {
			log_error ("Thumbnailer: start_thumbnail_generator()");
			log_error (e.message);
		}
	}

	public static void thumbnail_generator_thread(){

		generator_is_running = true;

		while (true){

			ThumbTask task = null;

			task_mutex.lock();

			if (task_list.size > 0) {
				task = task_list[0];
				task_list.remove(task);
				task_mutex.unlock();
			}
			else{
				task_mutex.unlock();
				break;
			}

			if (lookup(task.file_item, task.icon_size) != null){
				task.completed = true;
				continue; // was generated by another task
			}

			//log_debug("Thumbnailer: thumbnail_generator_thread: generate_thumbnail(): %s".printf(task.file_item.file_path));
			//log_debug("Thumbnailer: thumbnail_generator_thread: count = %d".printf(task_list.size));
			generate_thumbnail(task);
		}

		generator_is_running = false;
	}

	public static void generate_thumbnail(ThumbTask task){

		if (lookup(task.file_item, task.icon_size) != null){
			task.completed = true;
			return; // was generated by another task
		}

		if (!file_exists(task.file_item.file_path)){
			return;
		}

		if (!task.file_item.is_image && !task.file_item.is_video){
			return;
		}

		log_debug("Thumbnailer: generate_thumbnail(): %s".printf(task.file_item.file_path));

		//string thumb_dir = path_combine(default_thumbdir, (task.icon_size <= 128 ? "normal" : "large"));
		//dir_create(thumb_dir);

		//string temp_file = path_combine(thumb_dir, random_string(16));
		//var thumb_file = path_combine(thumb_dir, hash + ".png");
		//int icon_size = (task.icon_size <= 128 ? 128 : 256);

		if (task.file_item.is_image){
			generate_thumbnail_for_image(task);
		}
		else{
			generate_thumbnail_for_video(task);
		}
	}

	public static void generate_thumbnail_for_image(ThumbTask task){

		var timer = timer_start();

		string thumb_dir = path_combine(default_thumbdir, (task.icon_size <= 128 ? "normal" : "large"));
		dir_create(thumb_dir);

		string temp_file = path_combine(thumb_dir, random_string(16));
		var thumb_file = path_combine(thumb_dir, task.hash + ".png");

		int icon_size = (task.icon_size <= 128 ? 128 : 256);

		bool success = false;

		try {

			int width, height;
			Gdk.Pixbuf.get_file_info(task.file_item.file_path, out width, out height);
			Gdk.Pixbuf pixbuf = null;

			if ((width <= icon_size) && (height <= icon_size)){
				// do not upscale, load smaller image
				pixbuf = new Gdk.Pixbuf.from_file(task.file_item.file_path);
			}
			else{
				// scale down
				pixbuf = new Gdk.Pixbuf.from_file_at_scale(task.file_item.file_path, icon_size, icon_size, true);
			}

			if (pixbuf != null){
				success = save_thumb_image(pixbuf, task, temp_file, thumb_file);
			}
		}
		catch (Error e){
			log_error(e.message);
		}

		if (!success){
			save_failed_thumb_image(task, true);
		}

		log_trace("thumb generated: %s, %s".printf(thumb_file, timer_elapsed_string(timer)));
	}

	public static void generate_thumbnail_for_video(ThumbTask task){

		var timer = timer_start();

		string thumb_dir = path_combine(default_thumbdir, (task.icon_size <= 128 ? "normal" : "large"));
		dir_create(thumb_dir);

		string temp_file = path_combine(thumb_dir, random_string(16));
		var thumb_file = path_combine(thumb_dir, task.hash + ".png"); // -%03d.png

		int icon_size = (task.icon_size <= 128 ? 128 : 256);

		//string images_dir = path_combine(thumb_dir, hash);
		//dir_create(images_dir);

		//ThumbnailImagePath = get_temp_file_path() + ".png";
		string std_out, std_err;

		string cmd = "%s -ss 00:00:03 -i '%s' -y -f image2 -vf \"select='eq(pict_type,PICT_TYPE_I)',scale=256:-1\" -vsync vfr -vframes 1 -r 1 '%s'".printf(
			"ffmpeg", escape_single_quote(task.file_item.file_path), //-s %dx%dicon_size, icon_size,
			temp_file);

		log_debug(cmd);

		exec_sync(cmd, out std_out, out std_err);

		//string first_image_file = path_combine(thumb_dir, hash + "-001.png");

		bool success = false;

		if (file_exists(temp_file)){

			try {
				var pixbuf = new Gdk.Pixbuf.from_file_at_scale(temp_file, icon_size, icon_size, true);
				if (pixbuf != null){
					success = save_thumb_image(pixbuf, task, temp_file, thumb_file);
				}
			}
			catch (Error e){
				log_error(e.message);
			}
		}

		if (!success){
			save_failed_thumb_image(task, false);
		}

		log_trace("thumb generated: %s, %s".printf(thumb_file, timer_elapsed_string(timer)));
	}

	private static void save_failed_thumb_image(ThumbTask task, bool is_image){

		dir_create(fail_directory);

		var temp_file = path_combine(fail_directory, random_string(16));
		var thumb_file = path_combine(fail_directory, task.hash + ".png");

		Gdk.Pixbuf? pixbuf = null;

		if (is_image){
			pixbuf = IconManager.generic_icon_image(task.icon_size);
		}
		else{
			pixbuf = IconManager.generic_icon_image(task.icon_size);
		}

		save_thumb_image(pixbuf, task, temp_file, thumb_file);

		task.completed = true;
	}

	private static bool save_thumb_image(Gdk.Pixbuf pixbuf, ThumbTask task, string temp_file, string thumb_file){

		string file_modified = task.file_item.modified.to_unix().to_string();

		try {
			// delete existing thumnail (outdated)
			file_delete(thumb_file);

			// save temp file with metadata
			pixbuf.save(temp_file,
				"png", "tEXt::Thumb::MTime", file_modified,
				"tEXt::Thumb::URI", task.file_uri,
				"tEXt::Software", "polo-file-manager");

			// move temp file
			file_move(temp_file, thumb_file);

			task.completed = true;

			/*
			Note: Freedesktop.org specifications require thumbnail file to be saved with temporary file name and then renamed to correct name.
			This prevents multiple applications from corrupting data while attempting to write thumbnails for same file
			*/

			return true;
		}
		catch (Error e){
			log_error(e.message);
		}

		return false;
	}
}

public class ThumbTask : GLib.Object {

	public FileItem file_item;
	public int icon_size;
	public bool _completed = false;
	public static Mutex mutex = Mutex();

	public ThumbTask(FileItem _file_item, int _icon_size){
		file_item = _file_item;
		icon_size = _icon_size;
	}

	public bool completed {
		get {
			bool val = false;
			mutex.lock();
			val = _completed;
			mutex.unlock();
			return val;
		}
		set{
			mutex.lock();
			_completed = value;
			mutex.unlock();
		}
	}

	public bool large {
		get {
			return (icon_size > 128);
		}
	}

	public string hash {
		owned get {
			return file_item.thumb_key;
		}
	}

	public string file_uri {
		owned get {
			return file_item.file_path_prefix + file_item.file_path;
		}
	}
}
