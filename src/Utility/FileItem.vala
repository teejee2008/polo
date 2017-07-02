/*
 * FileItem.vala
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

public class FileItem : GLib.Object, Gee.Comparable<FileItem> {

	public static Gee.HashMap<string, FileItem> cache = new Gee.HashMap<string, FileItem>();
	public static uint64 object_count = 0;

	public string file_path = "";
	public string file_path_prefix = "";
	public FileType file_type = FileType.REGULAR;

	public DateTime modified = null;
	public DateTime accessed = null;
	public DateTime created = null;
	public DateTime changed = null;

	public string owner_user = "";
	public string owner_group = "";
	public string content_type = "";
	public string content_type_desc = "";
	public string file_status = "";
	public string checksum_md5 = "";
	public string checksum_sha1 = "";
	public string checksum_sha256 = "";
	public string checksum_sha512 = "";

	public uint32 unix_mode = 0;
	public string permissions = "";
	public string[] perms = {};

	public string edit_name = "";

	public bool can_read = false;
	public bool can_write = false;
	public bool can_execute = false;
	public bool can_rename = false;
	public bool can_trash = false;
	public bool can_delete = false;
	public string access_flags = "";

	public uint64 filesystem_free = 0;
	public uint64 filesystem_size = 0;
	public uint64 filesystem_used = 0;
	public bool filesystem_read_only = false;
	public string filesystem_type = "";
	public string filesystem_id = "";

	// trash ---------------------
	
	public bool is_trash = false;

	private bool _is_trashed_item = false;
	public bool is_trashed_item{
		get {
			if (_is_trashed_item){
				return true;
			}
			else{
				return !is_trash && (trash_original_path.length > 0);
			}
		}
		set{
			_is_trashed_item = value;
		}
	}

	public string trash_item_name = "";
	public string trash_info_file = "";
	public string trash_data_file = "";
	public string trash_basepath = "";
	public string trash_original_path = "";
	public uint32 trash_item_count = 0;
	public DateTime trash_deletion_date = null;

	// archive ------------------------
	
	private bool _is_archive = false;
	public bool is_archive {
		get {

			if (_is_archive){ return true; }
			
			foreach(var ext in archive_extensions){
				if (file_path.has_suffix(ext)) {
					return true;
				}
			}

			if (content_type.contains("compressed")){
				// ignore
			}

			return false;
		}
		set{
			_is_archive = value;
		}
	}

	// archive properties
	public int64 archive_size = 0;
	public int64 archive_unpacked_size = 0;
	public double compression_ratio = 0.0;
	public string archive_type = "";
	public string archive_method = "";
	public bool archive_is_encrypted = false;
	public bool archive_is_solid = false;
	public int archive_blocks = 0;
	public int64 archive_header_size = 0;
	public DateTime archive_modified;
	public string password = "";
	public string keyfile = "";

	public bool is_package {
		get {

			foreach(var ext in package_extensions){
				if (file_path.has_suffix(ext)) {
					return true;
				}
			}

			return false;
		}
	}

	public FileItem? archive_base_item; // for use by archived items
	//public string source_archive_path = ""; // for use by archived items

	private bool _is_archived_item = false;
	public bool is_archived_item{
		get {
			return _is_archived_item;
			/*if (_is_archived_item){
				return true;
			}
			else{
				return (source_archive_path.length > 0);
			}*/
		}
		set {
			_is_archived_item = value;
		}
	}

	public Gee.ArrayList<string> extract_list = new Gee.ArrayList<string>();
	public string extraction_path = "";
	
	// other -----------------
	
	public bool is_selected = false;
	public bool is_symlink = false;
	public string symlink_target = "";
	public bool is_stale = false;
	public bool dir_size_queried = false;
	
	public bool fileinfo_queried{
		get{
			return (modified != null);
		}
	}

	//public bool attr_is_hidden = false;

	public FileItem parent;
	public Gee.HashMap<string, FileItem> children = new Gee.HashMap<string, FileItem>();

	public Gee.ArrayList<string> hidden_list = new Gee.ArrayList<string>();

	public GLib.Object? tag;
	//public Gtk.TreeIter? treeiter;
	public string compared_status = "";
	public string compared_file_path = "";

	public long file_count = 0;
	public long dir_count = 0;
	public long hidden_count = 0;
	public long file_count_total = 0;
	public long dir_count_total = 0;
	
	public long item_count{
		get {
			return (file_count + dir_count);
		}
	}

	public long item_count_total{
		get {
			return (file_count_total + dir_count_total);
		}
	}

	public bool query_children_running = false;
	public bool query_children_pending = false;
	
	// operation flags
	public bool query_children_async_is_running = false;
	public bool query_children_aborted = false;

	public GLib.Icon icon;
	private Gtk.Window? window = null;

	public bool is_dummy = false;

	private Gee.ArrayList<Gdk.Pixbuf> animation_list = new Gee.ArrayList<Gdk.Pixbuf>();

	public static Mutex mutex = Mutex();

	public static string[] archive_extensions = {
		".001", ".tar",
		".tar.gz", ".tgz",
		".tar.bzip2", ".tar.bz2", ".tbz", ".tbz2", ".tb2",
		".tar.lzma", ".tar.lz", ".tlz",
		".tar.xz", ".txz",
		".tar.7z",
		".tar.zip",
		".7z", ".lzma",
		".bz2", ".bzip2",
		".gz", ".gzip",
		".zip", ".rar", ".cab", ".arj", ".z", ".taz", ".cpio",
		".rpm", ".deb",
		".lzh", ".lha",
		".chm", ".chw", ".hxs",
		".iso", ".dmg", ".xar", ".hfs", ".ntfs", ".fat", ".vhd", ".mbr",
		".wim", ".swm", ".squashfs", ".cramfs", ".scap"
	};

	public static string[] package_extensions = {
		".rpm", ".deb"
	};

	// static  ------------------

	public static void init(){
		log_debug("FileItem: init()");
		cache = new Gee.HashMap<string, FileItem>();
	}

	// contructors -------------------------------

	public FileItem(string name = "New Archive") {
		//file_name = name;
	}

	public FileItem.dummy(FileType _file_type) {
		is_dummy = true;
		file_type = _file_type;
	}

	public FileItem.dummy_root() {
		//file_name = "dummy";
		//file_location = "";
		is_dummy = true;
	}

	public FileItem.from_path(string _file_path){
		resolve_file_path(_file_path);
		query_file_info();
		object_count++;
	}

	public FileItem.from_path_and_type(string _file_path, FileType _file_type, bool query_info) {
		resolve_file_path(_file_path);
		file_type = _file_type;
		if (query_info){
			query_file_info();
		}
		object_count++;
	}

	private void resolve_file_path(string _file_path){

		file_path = _file_path;

		if (_file_path.contains("://")){
			file_path_prefix = _file_path[0 : _file_path.index_of("://")].down() + "://";
			file_path = _file_path[_file_path.index_of("://") + 3: _file_path.length];
			//log_debug("file_path_prefix=%s".printf(file_path_prefix));
			//log_debug("file_path=%s".printf(file_path));
		}
		else{
			file_path_prefix = "file://"; //local file
		}
	}

	public static void add_to_cache(FileItem item){
		cache[item.display_path] = item;
		//log_debug("add cache: %s".printf(item.display_path), true);
	}

	public static void remove_from_cache(FileItem item){
		if (cache.has_key(item.display_path)){
			cache.unset(item.display_path);
		}
		//log_debug("add cache: %s".printf(item.display_path), true);
	}

	public static FileItem? find_in_cache(string item_display_path){

		if (cache.has_key(item_display_path)){
			var cached_item = cache[item_display_path];
			//if (!cached_item.is_directory){
				//log_debug("get cache: %s".printf(item_display_path), true);
				return cached_item;
			//}
		}

		return null;
	}
	
	// properties --------------------------------------

	protected int64 _size = 0;
	public int64 size {
		get{
			return _size;
		}
	}

	public string size_formatted {
		owned get{
			return format_file_size(_size);
		}
	}

	private int64 _size_compressed = 0;
	public int64 size_compressed {
		get{
			return _size_compressed;
		}
	}

	public string file_name {
		owned get{
			if (file_path.length == 0){ return ""; }
			return file_basename(file_path);
		}
	}

	public string file_extension {
		owned get{
			if (file_path.length == 0){ return ""; }
			string[] parts = file_name.split(".");
			
			if (parts.length == 1){ // no extension
				return "";
			}
			else if ((parts.length > 2) && (parts[parts.length-2].length <= 4) && (parts[parts.length-1].length <= 4)){ // 2-part extension
				return ".%s.%s".printf(parts[parts.length-2], parts[parts.length-1]);
			}
			else{
				return ".%s".printf(parts[parts.length - 1]);
			}
		}
	}
	
	public string file_title {
		owned get{
			if (file_path.length == 0){ return ""; }
			int end = file_name.length - file_extension.length;
			return file_name[0:end];
		}
	}

	public string file_location {
		owned get{
			if (file_path.length == 0){ return ""; }
			return file_parent(file_path);
		}
	}

	public string file_uri {
		owned get{
			if (file_path_prefix == "file://"){
				// skip the prefix for local files
				return file_path;
			}
			else{
				// use full path with prefix
				return file_path_prefix + file_path;
			}
		}
	}

	string _thumb_key = null;
	public string thumb_key {
		get {
			if (_thumb_key == null){
				_thumb_key = string_checksum(file_path_prefix + file_path);
			}
			return _thumb_key;
		}
	}

/*
	public string file_path_effective {
		owned get{
			if (is_archived_item){

				var arch = source_archive;
				var txt = "";
				while (arch != null){
					txt = path_combine(arch.file_path, txt);
					arch = arch.source_archive;
				}
				return path_combine(txt, file_path);
			}
			else { // if (is_local){
				return file_path;
			}
			//else{
			//	return file_path_prefix + file_path; // don't use path_combine()
			//}
		}
	}
*/
	public string file_size_formatted {
		owned get{
			if (!is_dummy) {
				if (!is_directory){
					return format_file_size(size);
				}
				else{
					if (dir_size_queried && (size > 0)){
						return format_file_size(size); // directory size will be available for trashed dirs
					}
					else{
						if (item_count == 0){
							return "%'lld %s".printf(item_count, _("item"));
						}
						else if (item_count > 1){
							return "%'lld %s".printf(item_count, _("items"));
						}
						else{
							return _("empty");
						}
					}
				}
				//if (size > 0) {
				//return format_file_size(size); // directory size will be available for trashed dirs
				//}
				/*else if (file_type == FileType.DIRECTORY){
					if (children.size == 1){
						return "%'lld %s".printf(children.size, _("item"));
					}
					else if (children.size > 1){
						return "%'lld %s".printf(children.size, _("items"));
					}
					else{
						return _("empty");
					}
				}*/
				//else{
				//	return "0 B";
				//}
			}
			else {
				return "";
			}
		}
	}

	private string _display_name = null;
	public string display_name {
		owned get {
			if (_display_name != null){
				return _display_name;
			}
			else if (is_trashed_item){
				/*string txt = file_basename(trash_original_path);
				if (txt.contains("\\")){
					var arr = txt.split("\\");
					txt = arr[arr.length - 1];
				}
				txt = uri_decode(txt);
				return txt;*/
				return file_basename(display_path);
			}
			else{
				return file_basename(file_path);
			}
		}
		set {
			_display_name = value;
		}
	}

	private string _display_path = "";
	public string display_path {
		owned get {

			if (_display_path.length > 0){
				return _display_path;
			}

			string txt = "";
			
			if (is_trash){
				//log_debug("is_trash: display_path: " + display_name);
				txt = file_path_prefix + "/";
			}
			else if (is_trashed_item){
				//log_debug("trash_original_path: " + trash_original_path);
				//string files_dir = file_parent(trash_data_file);
				//log_debug("trash_basepath: %s".printf(trash_basepath));
				//log_debug("is_trashed_item: display_path: %s".printf(file_path[trash_basepath.length + 1 : file_path.length]));
				txt = file_path_prefix + file_path[trash_basepath.length : file_path.length];
			}
			else if (is_archived_item && (archive_base_item != null)){
				txt = path_combine(archive_base_item.display_path, file_path); 
			}
			else{
				//log_debug("is_normal: " + display_name);
				txt = file_path;
			}

			return txt;
		}
		set {
			_display_path = value;
		}
	}

	public string display_location {
		owned get{
			if (file_path_prefix == "trash://"){
				return "trash://" + file_parent(display_path.replace("trash://",""));
			}
			else{
				return file_parent(display_path);
			}
		}
	}

	public bool is_backup {
		get{
			return file_name.has_suffix("~");
		}
	}

	public bool is_hidden {
		get{
			return file_name.has_prefix(".") || ((parent != null) && parent.hidden_list.contains(file_name));
		}
	}

	public bool is_backup_or_hidden {
		get{
			return is_backup || is_hidden;
		}
	}

	public bool is_directory {
		get{
			return (file_type == FileType.DIRECTORY);
		}
	}

	public bool is_virtual {
		get{
			return (is_dummy || is_trash || is_trashed_item || is_archive || is_archived_item);
		}
	}

	public bool is_local {
		get{
			return (file_path_prefix.length == 0) || (file_path_prefix == "file://");
		}
	}

	public bool is_sys_root {
		get{
			return children.has_key("bin")
				&& children.has_key("dev")
				&& children.has_key("proc")
				&& children.has_key("run")
				&& children.has_key("sys");
		}
	}

	public bool has_child(string base_name) {
		return this.children.keys.contains(base_name);
	}

	private string get_access_flags() {
		string txt = "";
		txt += can_read ? "R" : "-";
		txt += can_write ? "W" : "-";
		txt += can_execute ? "X" : "-";
		txt += can_rename ? "N" : "-";
		txt += can_trash ? "T" : "-";
		txt += can_delete ? "D" : "-";
		return txt;
	}

	public string file_name_ellipsized {
		owned get{
			int max_chars = 20;
			return (file_name.length) > max_chars ? file_name[0:max_chars-1] + "..." : file_name;
		}
	}

	public string display_name_ellipsized {
		owned get{
			int max_chars = 20;
			return (display_name.length > max_chars) ? display_name[0:max_chars-1] + "..." : display_name;
		}
	}

	public string tile_tooltip {
		owned get{
			string txt = "";
			txt += "%s:  %s\n".printf(_("Name"), escape_html(file_name));
			txt += "%s:  %s\n".printf(_("Size"), file_size_formatted);
			if (modified != null){
				txt += "%s:  %s\n".printf(_("Modified"), modified.format("%Y-%m-%d %H:%M"));
			}
			txt += "%s:  %s\n".printf(_("Type"), escape_html(content_type_desc));
			txt += "%s:  %s".printf(_("Mime"), content_type);
			return txt;
		}
	}

	public string tile_markup {
		owned get{
			return "%s\n<i>%s</i>\n<i>%s</i>".printf(display_name_ellipsized, file_size_formatted, content_type_desc);
		}
	}

	public string modified_formatted{
		owned get {
			if (modified != null) {
				return modified.format ("%Y-%m-%d %H:%M");
			}
			else {
				return "(empty)";
			}
		}
	}

	public int64 modified_unix_time{
		get {
			int64 time = 0;
			if (modified != null){
				time = modified.to_unix();
			}
			return time;
		}
	}

	// check file type ----------------------
	
	public bool is_image{
		get{
			return content_type.has_prefix("image/");
		}
	}

	public bool is_text{
		get{
			return content_type.has_prefix("text/");
		}
	}

	public bool is_audio{
		get{
			return content_type.has_prefix("audio/");
		}
	}

	public bool is_video{
		get{
			return content_type.has_prefix("video/");
		}
	}

	public bool is_pdf{
		get{
			return file_extension.down().has_suffix(".pdf")
				|| (content_type == "application/pdf")
				|| (content_type == "application/x-pdf");
		}
	}

	public bool is_iso{
		get{
			return file_extension.down().has_suffix(".iso")
				|| (content_type == "application/iso-image")
				|| (content_type == "application/x-iso-image");
		}
	}

	public bool is_media_directory{
		get{
			int media_count = count_photos + count_videos;
			return (file_count > 10) && (media_count >= (file_count / 2));
		}
	}

	public int count_photos {
		get{
			int count = 0;
			foreach(var child in children.values){
				if (child.is_image){ count++; }
			}
			return count;
		}
	}

	public int count_documents {
		get{

			int count = 0;

			foreach(var child in children.values){

				switch(child.file_extension.down()){
				case "doc":
				case "docx":
				case "xls":
				case "xlsx":
				case "ppt":
				case "pptx":
				case "pdf":
				case "odt":
				case "ods":
				case "odp":
				case "epub":
				case "rtf":
					count++;
					break;
				}
			}

			return count;
		}
	}

	public int count_music {
		get{
			int count = 0;
			foreach(var child in children.values){
				if (child.is_audio){ count++; }
			}
			return count;
		}
	}

	public int count_videos {
		get{
			int count = 0;
			foreach(var child in children.values){
				if (child.is_video){ count++; }
			}
			return count;
		}
	}

	// icons ----------------------------------------------

	public Gdk.Pixbuf? get_image(int icon_size,
		bool load_thumbnail, bool add_transparency, bool add_emblems, out ThumbTask? task){

		Gdk.Pixbuf? pixbuf = null;
		
		task = null;

		//if (changed == null){
			//log_trace("changed=NULL: %s".printf(display_path));
		//}

		Gdk.Pixbuf? cached = IconCache.lookup_icon_fileitem(display_path, changed, icon_size,
			load_thumbnail, add_transparency, add_emblems); // TODO: use file_path_uri

		if (cached != null){
			return cached;
		}

		if (load_thumbnail && !is_directory){
			pixbuf = get_thumbnail(icon_size, add_transparency, add_emblems, out task);
		}
		else{
			pixbuf = get_icon(icon_size, add_transparency, add_emblems);
		}

		if (task == null){
			IconCache.add_icon_fileitem(pixbuf, display_path, changed, icon_size, // TODO: use file_path_uri
				load_thumbnail, add_transparency, add_emblems);
		}
		
		return pixbuf;
	}

	public Gdk.Pixbuf? get_icon(int icon_size, bool add_transparency, bool add_emblems){

		Gdk.Pixbuf? pixbuf = null;

		if (icon != null) {
			pixbuf = IconManager.lookup_gicon(icon, icon_size);
		}

		if (pixbuf == null){
			if (file_type == FileType.DIRECTORY) {
				pixbuf = IconManager.lookup("folder", icon_size, false);
			}
			else{
				pixbuf = IconManager.lookup("text-x-preview", icon_size, false);
			}
		}

		if (pixbuf == null){ return null; }

		if (add_emblems){
			pixbuf = add_emblems_for_state(pixbuf, false);
		}

		if (add_transparency && is_backup_or_hidden){
			pixbuf = IconManager.add_transparency(pixbuf);
		}

		return pixbuf;
	}

	public Gdk.Pixbuf? get_thumbnail(int icon_size, bool add_transparency, bool add_emblems, out ThumbTask? task){

		Gdk.Pixbuf? pixbuf = Thumbnailer.lookup(this, icon_size);

		//log_debug("get_thumbnail: %s".printf(file_path));
		// TODO2: Thumbnailer should create fail image (icon)
		// TODO2: get rid of thumbtask
		if ((pixbuf == null) && !is_directory && (is_image || is_video)){
			//log_debug("get_thumbnail: add_task: %s".printf(file_path));
			task = new ThumbTask(this, icon_size);
			Thumbnailer.add_to_queue(task);
		}
		else{
			task = null;
		}

		if (pixbuf == null){
			pixbuf = get_icon(icon_size, false, false);
		}

		if (pixbuf == null){ return null; }

		if (add_emblems){
			pixbuf = add_emblems_for_state(pixbuf, false);
		}

		if (add_transparency && is_backup_or_hidden){
			pixbuf = IconManager.add_transparency(pixbuf);
		}

		return pixbuf;
	}

	public Gee.ArrayList<Gdk.Pixbuf> get_animation(int icon_size){

		if (animation_list == null){
			animation_list = new Gee.ArrayList<Gdk.Pixbuf>();
		}

		if (animation_list.size > 0){
			return animation_list;
		}

		animation_list = Thumbnailer.lookup_animation(this, icon_size);
		return animation_list;
	}

	public Gdk.Pixbuf? add_emblems_for_state(Gdk.Pixbuf pixbuf, bool emblem_symbolic){

		int width = pixbuf.get_width();
		int height = pixbuf.get_height();

		int icon_size = (width > height) ? width : height;

		//if (icon_size < 32){
		//	return pixbuf; // icon is too small for emblems to be drawn over it
		//}

		//int emblem_size = (int) (icon_size * 0.40);

		int emblem_size = 16;
		
		if (icon_size < 32){
			emblem_size = 8;
		}

		Gdk.Pixbuf? emblemed = pixbuf.copy();

		if (is_symlink){
			emblemed = IconManager.add_emblem(emblemed, "emblem-symbolic-link", emblem_size, emblem_symbolic, Gtk.CornerType.BOTTOM_RIGHT);
		}

		if (!can_write){
			emblemed = IconManager.add_emblem(emblemed, "emblem-readonly", emblem_size, emblem_symbolic, Gtk.CornerType.TOP_RIGHT);
		}

		if (is_directory && (icon_size >= 32)){

			if (icon_size >= 32){
				emblem_size = (int) (icon_size * 0.40);
			}

			if (count_documents > 0){
				emblemed = IconManager.add_emblem(emblemed, "emblem-documents", emblem_size, emblem_symbolic, Gtk.CornerType.BOTTOM_LEFT);
			}
			else if (count_photos > 0){
				emblemed = IconManager.add_emblem(emblemed, "emblem-photos", emblem_size, emblem_symbolic, Gtk.CornerType.BOTTOM_LEFT);
			}
			else if (count_music > 0){
				emblemed = IconManager.add_emblem(emblemed, "emblem-music", emblem_size, emblem_symbolic, Gtk.CornerType.BOTTOM_LEFT);
			}
			else if (count_videos > 0){
				emblemed = IconManager.add_emblem(emblemed, "emblem-videos", emblem_size, emblem_symbolic, Gtk.CornerType.BOTTOM_LEFT);
			}
		}

		return emblemed;
	}

	public Gtk.Image? get_icon_image(int icon_size, bool add_transparency, bool add_emblems){
		
		Gdk.Pixbuf? pix = get_icon(icon_size, add_transparency, add_emblems);
		
		if (pix != null){
			return new Gtk.Image.from_pixbuf(pix);
		}
		else{
			return null;
		}
	}
	
	// helpers ----------------------------------------------

	public int compare_to(FileItem b){

		if (this.file_type == b.file_type) {
			return strcmp(this.file_name.down(), b.file_name.down());
		}
		else{
			if (this.file_type == FileType.DIRECTORY) {
				return -1;
			}
			else {
				return +1;
			}
		}
	}

	public string resolve_symlink_target(){

		string target_path = file_parent(file_path); // remove symlink file name

		foreach(var part in symlink_target.split("/")){
			if (part == ".."){
				target_path = file_parent(target_path);
			}
			else if (part == "."){
				// no change
			}
			else if (part.length == 0){
				target_path = "/";
			}
			else{
				target_path = path_combine(target_path, part);
			}
		}

		return target_path;
	}

	public Device? get_device(){
		return Device.get_device_for_path(file_path);
	}
	
	// instance methods ------------------------------------------

	public FileItem? add_child_from_disk(string child_item_file_path, int depth = -1) {

		/* Adds specified item on disk to current FileItem
		 * Adds the item's children recursively if depth is -1 or > 0
		 *  depth =  0, add child item, count child item's children if directory
		 *  depth = -1, add child item, add child item's children from disk recursively
		 *  depth =  X, add child item, add child item's children upto X levels
		 * */

		if (query_children_aborted) {
			
			return null;
		}

		//log_debug("add_child_from_disk: aborted: %s, %s".printf(query_children_aborted.to_string(), child_item_file_path));

		FileItem item = null;

		//log_debug("add_child_from_disk: %s".printf(child_item_file_path));

		try {
			FileEnumerator enumerator;
			FileInfo info;
			File file = File.parse_name (child_item_file_path);

			if (!file.query_exists()) { return null; }

			// query file type
			var item_file_type = file.query_file_type(FileQueryInfoFlags.NONE);

			// add item
			item = this.add_child(child_item_file_path, item_file_type, 0, 0, true);

			//log_debug("add_child_from_disk(): file_path=%s".printf(item.file_path));

			// check if directory
			if (!item.is_directory) {
				// add the item to cache, as it has no children
				add_to_cache(item);
				return item;
			}

			if (depth < 0){
				// we are querying everything under this directory, so the directory size will be accurate; set flag for this
				item.dir_size_queried = true;
				//log_debug("dir_size_queried: %s".printf(this.file_name));
			}
	
			// enumerate item's children

			try {

				item.file_count = 0;
				item.dir_count = 0;
				
				enumerator = file.enumerate_children ("%s,%s".printf(FileAttribute.STANDARD_NAME,FileAttribute.STANDARD_TYPE), 0);
				
				while ((info = enumerator.next_file()) != null) {
					
					if (query_children_aborted) {
						item.query_children_aborted = true;
						item.dir_size_queried = false;
						return null;
					}

					string child_path = path_combine(child_item_file_path, info.get_name());

					if (depth == 0){
						// count the item's children, do not add
						if (info.get_file_type() == FileType.DIRECTORY){
							item.dir_count++;
						}
						else{ item.file_count++; }
					}
					else{
						// add item's children from disk and drill down further
						item.add_child_from_disk(child_path, depth - 1);

						// add the item to cache, as it's children have been added
						add_to_cache(item);
					}
				}
			}
			catch (Error e) {
				log_error (e.message);
			}
		}
		catch (Error e) {
			log_error (e.message);
		}

		return item;
	}

	public FileItem add_descendant(string _file_path, FileType? _file_type, int64 item_size,int64 item_size_compressed) {

		//log_debug("add_descendant=%s".printf(_file_path));

		string item_path = _file_path.strip();
		FileType item_type = (_file_type == null) ? FileType.REGULAR : _file_type;

		if (item_path.has_suffix("/")) {
			item_path = item_path[0:item_path.length - 1];
			item_type = FileType.DIRECTORY;
		}

		if (item_path.has_prefix("/")) {
			item_path = item_path[1:item_path.length];
		}

		string dir_name = "";
		string dir_path = "";

		//create dirs and find parent dir
		FileItem current_dir = this;
		string[] arr = item_path.split("/");
		for (int i = 0; i < arr.length - 1; i++) {
			//get dir name
			dir_name = arr[i];

			//add dir
			if (!current_dir.children.keys.contains(dir_name)) {
				if ((current_dir == this) && current_dir.is_archive){
					dir_path = "";
				}
				else {
					dir_path = current_dir.file_path + "/";
				}
				dir_path = "%s%s".printf(dir_path, dir_name);
				current_dir.add_child(dir_path, FileType.DIRECTORY, 0, 0, false);
			}

			current_dir = current_dir.children[dir_name];
		}

		//get item name
		string item_name = arr[arr.length - 1];

		//add item
		if (!current_dir.children.keys.contains(item_name)) {

			//log_debug("add_descendant: add_child()");

			current_dir.add_child(
				item_path, item_type, item_size, item_size_compressed, false);
		}

		//log_debug("add_descendant: finished: %s".printf(item_path));

		return current_dir.children[item_name];
	}

	public FileItem add_child(string item_file_path, FileType item_file_type,
		int64 item_size, int64 item_size_compressed, bool item_query_file_info){

		// create new item ------------------------------

		//log_debug("add_child: %s ---------------".printf(item_file_path));

		FileItem item = null;

		//item.tag = this.tag;

		// check existing ----------------------------

		bool existing_file = false;

		string item_name = file_basename(item_file_path);
		
		if (children.has_key(item_name) && (children[item_name].file_name == item_name)){

			existing_file = true;
			item = children[item_name];

			//log_debug("existing child, queried: %s".printf(item.fileinfo_queried.to_string()));
		}
		else if (cache.has_key(item_file_path) && (cache[item_file_path].file_path == item_file_path)){
			
			item = cache[item_file_path];

			// set relationships
			item.parent = this;
			this.children[item.file_name] = item;
		}
		else{

			if (item == null){
				item = new FileItem.from_path_and_type(item_file_path, item_file_type, false);
			}
			
			// set relationships
			item.parent = this;
			this.children[item.file_name] = item;
		}

		item.is_stale = false; // mark fresh

		//item.display_path = path_combine(this.display_path, item_name);

		// copy values from parent
		
		item.file_path_prefix = this.file_path_prefix;
		
		if (this.is_trash || this.is_trashed_item){
			item.is_trashed_item = true;
			item.trash_basepath = this.trash_basepath;
		}

		if (this.is_archive || this.is_archived_item){
			item.is_archived_item = true;
			item.archive_base_item = this.archive_base_item;
		}

		// copy unchanged
		//item.trash_info_file = this.trash_info_file;
		
		//item.trash_deletion_date = this.trash_deletion_date;
		//item.trash_original_path = this.trash_original_path;
		//item.trash_data_file = this.trash_data_file;
		
		// modify
		//if (this.is_trashed_item){
		//	item.trash_original_path = path_combine(this.trash_original_path, item.file_name);
		//	item.trash_data_file = path_combine(this.trash_data_file, item.file_name);
		//}

		bool item_was_queried = item.fileinfo_queried;
		
		// query file properties
		if (item_query_file_info){
			//log_debug("add_child: item_query_file_info");
			//log_debug("add_child: query_file_info(): %s".printf(item.file_path));
			item.query_file_info();
			item_size = item.size;
		}

		if (item_file_type == FileType.REGULAR) {

			//log_debug("add_child: regular file");

			// set file sizes
			if (item_size > 0) {
				item._size = item_size;
			}
			if (item_size_compressed > 0) {
				item._size_compressed = item_size_compressed;
			}

			// update file counts
			if (!existing_file){

				// update this
				this.file_count++;
				this.file_count_total++;
				if (item.is_backup_or_hidden){
					this.hidden_count++;
				}

				// update parents
				var temp = this;
				while (temp.parent != null) {
					temp.parent.file_count_total++;
					//log_debug("file_count_total += 1, %s".printf(temp.parent.file_count_total));
					temp = temp.parent;
				}

				//log_debug("updated dir counts: %s".printf(item_name));
			}

			if (!existing_file || !item_was_queried){

				// update this
				this._size += item_size;
				this._size_compressed += item_size_compressed;

				// update parents
				var temp = this;
				while (temp.parent != null) {
					temp.parent._size += item_size;
					temp.parent._size_compressed += item_size_compressed;
					//log_debug("size += %lld, %s".printf(item_size, temp.parent.file_path));
					temp = temp.parent;
				}

				//log_debug("updated dir sizes: %s".printf(item_name));
			}
		}
		else if (item_file_type == FileType.DIRECTORY) {

			//log_debug("add_child: directory");

			if (!existing_file){

				// update this
				this.dir_count++;
				this.dir_count_total++;
				//this.size += _size;
				//size will be updated when children are added

				// update parents
				var temp = this;
				while (temp.parent != null) {
					temp.parent.dir_count_total++;
					//log_debug("dir_count_total += 1, %s".printf(temp.parent.dir_count_total));
					temp = temp.parent;
				}

				//log_debug("updated dir sizes: %s".printf(item_name));
			}
		}

		//log_debug("add_child: finished: fc=%lld dc=%lld path=%s".printf(
		//	file_count, dir_count, item_file_path));

		return item;
	}

	public FileItem remove_child(string child_name) {
		FileItem child = null;

		if (this.children.has_key(child_name)) {
			child = this.children[child_name];
			this.children.unset(child_name);

			if (child.file_type == FileType.REGULAR) {
				//update file counts
				this.file_count--;
				this.file_count_total--;

				//subtract child size
				this._size -= child.size;
				this._size_compressed -= child.size_compressed;

				//update file count and size of parent dirs
				var temp = this;
				while (temp.parent != null) {
					temp.parent.file_count_total--;

					temp.parent._size -= child.size;
					temp.parent._size_compressed -= child.size_compressed;

					temp = temp.parent;
				}
			}
			else {
				//update dir counts
				this.dir_count--;
				this.dir_count_total--;

				//subtract child counts
				this.file_count_total -= child.file_count_total;
				this.dir_count_total -= child.dir_count_total;
				this._size -= child.size;
				this._size_compressed -= child.size_compressed;

				//update dir count of parent dirs
				var temp = this;
				while (temp.parent != null) {
					temp.parent.dir_count_total--;

					temp.parent.file_count_total -= child.file_count_total;
					temp.parent.dir_count_total -= child.dir_count_total;
					temp.parent._size -= child.size;
					temp.parent._size_compressed -= child.size_compressed;

					temp = temp.parent;
				}
			}
		}

		//log_debug("%3ld %3ld %s".printf(file_count, dir_count, file_path));

		return child;
	}

	/*public FileItem rename_child(string child_name, string new_name){

		log_debug("FileItem: rename_child(): %s -> %s".printf(child_name, new_name));

		FileItem child = null;

		if (this.children.has_key(child_name)) {

			child = this.children[child_name];

			// unset
			this.children.unset(child_name);
			remove_from_cache(child);

			// set
			this.children[new_name] = child;
			child.file_path = path_combine(child.file_location, new_name);
			child.display_name = null;
			child.query_file_info();
			//add_to_cache(child);
		}

		return child;
	}*/

	public bool hide_item(){

		if ((parent != null) && dir_exists(parent.file_path)){

			string hidden_file = path_combine(parent.file_path, ".hidden");
			string txt = "";

			if (file_exists(hidden_file)){
				txt = file_read(hidden_file);
			}

			txt += (txt.length == 0) ? "" : "\n";
			txt += "%s".printf(file_name);

			file_write(hidden_file, txt, null, null, true); // overwrite in-place
			parent.read_hidden_list();
			update_access_time();
			return true;
		}

		return false;
	}

	public bool unhide_item(){

		if ((parent != null) && dir_exists(parent.file_path)){

			string hidden_file = path_combine(parent.file_path, ".hidden");
			string txt = "";

			if (file_exists(hidden_file)){

				foreach(string line in file_read(hidden_file).split("\n")){

					if (line.strip() == file_name){
						continue;
					}
					else{
						txt += (txt.length == 0) ? "" : "\n";
						txt += "%s".printf(line);
					}
				}
			}

			file_write(hidden_file, txt, null, null, true); // overwrite in-place
			parent.read_hidden_list();
			update_access_time();
			return true;
		}

		return false;
	}

	private void update_access_time(){
		// update access time (and changed time) - forces cached icon to expire
		touch(file_path, true, false, false, null); 
		query_file_info();
	}

	// query info --------------------------

	public void query_file_info() {

		try {

			FileInfo info;

			var file = File.parse_name(file_path);

			if (!file.query_exists()) {
				log_debug("query_file_info(): not found: %s".printf(file_path));
				return;
			}

			mutex.lock();
			
			// get type without following symlinks

			//log_debug("file.query_info()");
			
			info = file.query_info("%s,%s,%s".printf(
									   FileAttribute.STANDARD_TYPE,
									   FileAttribute.STANDARD_ICON,
									   FileAttribute.STANDARD_SYMLINK_TARGET),
									   FileQueryInfoFlags.NOFOLLOW_SYMLINKS);

			//log_debug("file.query_info(): ok");
			
			var item_file_type = info.get_file_type();

			this.icon = info.get_icon();

			if (item_file_type == FileType.SYMBOLIC_LINK) {
				//this.icon = GLib.Icon.new_for_string("emblem-symbolic-link");
				this.is_symlink = true;
				this.symlink_target = info.get_symlink_target();
			}
			else {
				this.is_symlink = false;
				this.symlink_target = "";
			}

			//NOTE: permissions of symbolic links are never used

			// get file info - follow symlinks

			//log_debug("file.query_info()");
			
			info = file.query_info("%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s".printf(
									   FileAttribute.STANDARD_TYPE,
									   FileAttribute.STANDARD_SIZE,
									   FileAttribute.STANDARD_ICON,
									   FileAttribute.STANDARD_CONTENT_TYPE,
									   FileAttribute.STANDARD_DISPLAY_NAME,
									   FileAttribute.STANDARD_EDIT_NAME,
									   FileAttribute.TIME_CREATED,
									   FileAttribute.TIME_ACCESS,
									   FileAttribute.TIME_MODIFIED,
									   FileAttribute.TIME_CHANGED,
									   FileAttribute.OWNER_USER,
									   FileAttribute.OWNER_GROUP,
									   FileAttribute.FILESYSTEM_FREE,
									   FileAttribute.ACCESS_CAN_DELETE,
									   FileAttribute.ACCESS_CAN_EXECUTE,
									   FileAttribute.ACCESS_CAN_READ,
									   FileAttribute.ACCESS_CAN_RENAME,
									   FileAttribute.ACCESS_CAN_TRASH,
									   FileAttribute.ACCESS_CAN_WRITE,
									   FileAttribute.UNIX_MODE,
									   FileAttribute.ID_FILESYSTEM
									   ), 0);

			//log_debug("file.query_info(): ok");
			
			if (this.is_symlink){
				// get icon for the resolved file
				this.icon = info.get_icon();
			}

			// file type resolved
			this.file_type = info.get_file_type();

			// content type
			this.content_type = info.get_content_type();

			// size
			if (!this.is_symlink && (this.file_type == FileType.REGULAR)) {
				this._size = info.get_size();
			}

			// modified
			this.modified = (new DateTime.from_timeval_utc(info.get_modification_time())).to_local();

			if (info.has_attribute(FileAttribute.TIME_ACCESS)){
				var time = (int64) info.get_attribute_uint64(FileAttribute.TIME_ACCESS); // convert uint64 to int64
				this.accessed = (new DateTime.from_unix_utc(time)).to_local();
			}

			if (info.has_attribute(FileAttribute.TIME_CREATED)){
				var time = (int64) info.get_attribute_uint64(FileAttribute.TIME_CREATED); // convert uint64 to int64
				this.created = (new DateTime.from_unix_utc(time)).to_local();
			}

			if (info.has_attribute(FileAttribute.TIME_CHANGED)){
				var time = (int64) info.get_attribute_uint64(FileAttribute.TIME_CHANGED); // convert uint64 to int64
				this.changed = (new DateTime.from_unix_utc(time)).to_local();
			}

			// owner_user
			this.owner_user = info.get_attribute_string(FileAttribute.OWNER_USER);

			// owner_group
			this.owner_group = info.get_attribute_string(FileAttribute.OWNER_GROUP);

			this.can_read = info.get_attribute_boolean(FileAttribute.ACCESS_CAN_READ);
			this.can_write = info.get_attribute_boolean(FileAttribute.ACCESS_CAN_WRITE);
			this.can_execute = info.get_attribute_boolean(FileAttribute.ACCESS_CAN_EXECUTE);

			this.can_rename = info.get_attribute_boolean(FileAttribute.ACCESS_CAN_RENAME);
			this.can_trash = info.get_attribute_boolean(FileAttribute.ACCESS_CAN_TRASH);
			this.can_delete = info.get_attribute_boolean(FileAttribute.ACCESS_CAN_DELETE);

			this.access_flags = get_access_flags();

			//this.attr_is_hidden = info.get_is_hidden();

			if (info.has_attribute(FileAttribute.UNIX_MODE)){
				this.unix_mode = info.get_attribute_uint32(FileAttribute.UNIX_MODE);
				parse_permissions();
			}

			this.filesystem_id = info.get_attribute_string(FileAttribute.ID_FILESYSTEM);

			if (this.file_type == FileType.DIRECTORY){
				query_file_system_info();
				read_hidden_list();
			}

			if (MimeType.mimetypes.has_key(this.content_type)){
				this.content_type_desc = MimeType.mimetypes[this.content_type].comment;
			}

			//if (file_path_prefix == "trash://"){

				/*log_debug("query trash attributes");

				info = file.query_info("%s,%s,%s".printf(
									   FileAttribute.TRASH_ORIG_PATH,
									   FileAttribute.TRASH_ITEM_COUNT,
									   FileAttribute.TRASH_DELETION_DATE
									   ), 0);

				this.trash_original_path = info.get_attribute_string(FileAttribute.TRASH_ORIG_PATH);
				this.trash_item_count = info.get_attribute_uint32(FileAttribute.TRASH_ITEM_COUNT);
				this.trash_deletion_date = info.get_deletion_date ();
				*/
			//}


			
		}
		catch (Error e) {
			log_error (e.message);
		}

		mutex.unlock();
	}

	private enum ModeMask{
		FILE_MODE_SUID       = 04000,
		FILE_MODE_SGID       = 02000,
		FILE_MODE_STICKY     = 01000,
		FILE_MODE_USR_ALL    = 00700,
		FILE_MODE_USR_READ   = 00400,
		FILE_MODE_USR_WRITE  = 00200,
		FILE_MODE_USR_EXEC   = 00100,
		FILE_MODE_GRP_ALL    = 00070,
		FILE_MODE_GRP_READ   = 00040,
		FILE_MODE_GRP_WRITE  = 00020,
		FILE_MODE_GRP_EXEC   = 00010,
		FILE_MODE_OTH_ALL    = 00007,
		FILE_MODE_OTH_READ   = 00004,
		FILE_MODE_OTH_WRITE  = 00002,
		FILE_MODE_OTH_EXEC   = 00001
	}

	private void parse_permissions(){

		perms = new string[10];
		perms[0] = "";
		perms[1] = ((this.unix_mode & ModeMask.FILE_MODE_USR_READ) != 0)  ? "r" : "-";
		perms[2] = ((this.unix_mode & ModeMask.FILE_MODE_USR_WRITE) != 0) ? "w" : "-";
		perms[3] = ((this.unix_mode & ModeMask.FILE_MODE_USR_EXEC) != 0)  ? "x" : "-";
		perms[4] = ((this.unix_mode & ModeMask.FILE_MODE_GRP_READ) != 0)  ? "r" : "-";
		perms[5] = ((this.unix_mode & ModeMask.FILE_MODE_GRP_WRITE) != 0) ? "w" : "-";
		perms[6] = ((this.unix_mode & ModeMask.FILE_MODE_GRP_EXEC) != 0)  ? "x" : "-";
		perms[7] = ((this.unix_mode & ModeMask.FILE_MODE_OTH_READ) != 0)  ? "r" : "-";
		perms[8] = ((this.unix_mode & ModeMask.FILE_MODE_OTH_WRITE) != 0) ? "w" : "-";
		perms[9] = ((this.unix_mode & ModeMask.FILE_MODE_OTH_EXEC) != 0)  ? "x" : "-";

		if ((this.unix_mode & ModeMask.FILE_MODE_SUID) != 0){
			perms[3] = "s";
		}

		if ((this.unix_mode & ModeMask.FILE_MODE_SGID) != 0){
			perms[6] = "s";
		}

		if ((this.unix_mode & ModeMask.FILE_MODE_STICKY) != 0){
			perms[9] = "t";
		}

		string txt = "";
		int index = 0;
		foreach(var ch in perms){
			index++;
			txt += ch;
			if (((index - 1) % 3) == 0){
				txt += " ";
			}
		}
		this.permissions = txt.strip();
	}

	public void query_children(int depth = -1) {

		/* Queries the file item's children using the file_path
		 * depth = -1, recursively find and add all children from disk
		 * depth =  1, find and add direct children
		 * depth =  0, meaningless, should not be used
		 * depth =  X, find and add children upto X levels
		 * */

		if (query_children_aborted) { return; }

		if (is_archive || is_archived_item) { return; }

		// no need to continue if not a directory
		if (!is_directory) {
			query_file_info();
			return;
		}

		if (depth == 0){ return; } // incorrect method call

		query_children_running = true;
	
		if (depth < 0){
			// we are querying everything under this directory, so the directory size will be accurate; set flag for this
			dir_size_queried = true;
			//log_debug("dir_size_queried: %s".printf(this.file_name));
		}
		
		log_debug("FileItem: query_children(%d): %s".printf(depth, file_path), true);

		FileEnumerator enumerator;
		FileInfo info;

		var file = File.parse_name(file_path);

		//if (is_trashed_item){
		//	file = File.parse_name(trash_data_file);
		//}

		if (!file.query_exists()) {
			log_error("FileItem: query_children(): file not found: %s".printf(file_path), true);
			query_children_running = false;
			return;
		}

		/*var cached = find_in_cache(display_path);
		
		if ((cached != null) && (cached.changed != null)){
			
			var cached_changed = cached.changed;
			query_file_info();

			if ((depth == 1) && dates_are_equal(changed, cached_changed)){
				// the item's 'changed date' has not changed
				// depth=1 so we are not interested in drilling further
				this.children = cached.children; // set the children from cache
				log_debug("FileItem: query_children: %s: depth=1 and no_change".printf(file_path), true);
				query_children_running = false;
				return;
			}
		}
		else{
			query_file_info();
		}*/

		query_file_info(); // read folder properties
		
		try{
			// mark existing children as stale
			foreach(var child in children.values){
				child.is_stale = true;
			}

			//children.clear();

			//log_debug("FileItem: query_children(): enumerate_children");

			// recurse children
			enumerator = file.enumerate_children ("%s".printf(FileAttribute.STANDARD_NAME), 0);
			while ((info = enumerator.next_file()) != null) {
				//log_debug("FileItem: query_children(): found: %s".printf(info.get_name()));
				string child_name = info.get_name();
				string child_path = GLib.Path.build_filename(file_path, child_name);
				var child = this.add_child_from_disk(child_path, depth - 1);
				//child.is_stale = false;
				//log_debug("fresh: name: %s".printf(child.file_name));
				
				if (query_children_aborted) {
					dir_size_queried = false;
					query_children_running = false;
					return;
				}
			}

			// remove stale children
			var list = new Gee.ArrayList<string>();
			foreach(var key in children.keys){
				if (children[key].is_stale){
					list.add(key);
				}
			}
			foreach(var key in list){
				//log_debug("unset: key: %s, name: %s".printf(key, children[key].file_name));
				children.unset(key);
			}
		}
		catch (Error e) {
			log_error (e.message);
		}

		add_to_cache(this);

		query_children_running = false;
		query_children_pending = false;
	}

	public void query_children_async() {

		log_debug("query_children_async(): %s".printf(file_path));

		query_children_async_is_running = true;
		query_children_aborted = false;

		try {
			//start thread
			Thread.create<void> (query_children_async_thread, true);
		}
		catch (Error e) {
			log_error ("FileItem: query_children_async(): error");
			log_error (e.message);
		}
	}

	private void query_children_async_thread() {
		log_debug("query_children_async_thread()");
		query_children(-1); // always add to cache
		query_children_async_is_running = false;
		query_children_aborted = false; // reset
	}
	
	public void query_file_system_info(bool fix_fstype = false) {

		try {
			var file = File.parse_name(file_path);

			var info = file.query_filesystem_info("%s,%s,%s,%s,%s".printf(
											   FileAttribute.FILESYSTEM_FREE,
											   FileAttribute.FILESYSTEM_SIZE,
											   FileAttribute.FILESYSTEM_USED,
											   FileAttribute.FILESYSTEM_READONLY,
											   FileAttribute.FILESYSTEM_TYPE
											   ), null);

			this.filesystem_free = info.get_attribute_uint64(FileAttribute.FILESYSTEM_FREE);
			this.filesystem_size = info.get_attribute_uint64(FileAttribute.FILESYSTEM_SIZE);
			this.filesystem_used = info.get_attribute_uint64(FileAttribute.FILESYSTEM_USED);
			this.filesystem_read_only = info.get_attribute_boolean(FileAttribute.FILESYSTEM_READONLY);
			this.filesystem_type = info.get_attribute_string(FileAttribute.FILESYSTEM_TYPE);
			//this.filesystem_type = (this.filesystem_type == "ext3/ext4") ? "ext3/4" : this.filesystem_type;
		}
		catch (Error e) {
			log_error (e.message);
		}
	}

	public void read_hidden_list(){

		hidden_list = new Gee.ArrayList<string>();

		string hidden_file = path_combine(file_path, ".hidden");

		if (file_exists(hidden_file)){

			foreach(string line in file_read(hidden_file).split("\n")){
				if (line.contains("/")){
					hidden_list.add(file_basename(line));
				}
				else{
					hidden_list.add(line);
				}
			}
		}
	}

	public void clear_children() {
		this.children.clear();
	}


	public FileItem? find_descendant(string path){
		var child = this;

		foreach(var part in path.split("/")){

			// query children if needed
			if (child.children.size == 0){
				if (child.is_directory){
					child.query_children(1);
				}
				else{
					break;
				}
				if (child.children.size == 0){
					break;
				}
			}

			if (child.children.has_key(part)){
				child = child.children[part];
			}
		}

		if (child.file_path == path){
			return child;
		}
		else{
			return null;
		}
	}

	public void set_file_path_prefix(string prefix){
		file_path_prefix = prefix;
		foreach(var child in this.children.values){
			child.set_file_path_prefix(prefix);
		}
	}

	public void print(int level) {

		if (level == 0) {
			stdout.printf("\n");
			stdout.flush();
		}

		stdout.printf("%s%s\n".printf(string.nfill(level * 2, ' '), file_name));
		stdout.flush();

		foreach (var key in this.children.keys) {
			this.children[key].print(level + 1);
		}
	}

	public Gee.ArrayList<FileItem> get_children_sorted(){
		var list = new Gee.ArrayList<FileItem>();

		foreach(string key in children.keys) {
			var item = children[key];
			list.add(item);
		}

		list.sort((a, b) => {
			if (a.is_directory && !b.is_directory){
				return -1;
			}
			else if (!a.is_directory && b.is_directory){
				return 1;
			}
			else{
				return strcmp(a.file_name.down(), b.file_name.down());
			}
		});

		return list;
	}

	// monitor

	public FileMonitor? monitor_for_changes(out Cancellable monitor_cancellable){

		if (!is_directory){
			return null;
		}

		FileMonitor file_monitor = null;

		var file = File.parse_name(file_path);

		try{
			monitor_cancellable = new Cancellable();
			var monitor_flags = FileMonitorFlags.WATCH_MOUNTS | FileMonitorFlags.WATCH_MOVES;
			file_monitor = file.monitor_directory(monitor_flags, monitor_cancellable);
		}
		catch (Error e){
			log_error(e.message);
			return null;
		}

		return file_monitor;
	}

	// compare

	public void compare_directory(FileItem dir2, uint64 size_limit = 2000000){

		if (dir2 == null){
			return;
		}

		foreach(var item in this.children.values){
			if (!item.content_type.has_prefix("text") || (item.size > size_limit)) { continue; }
			item.checksum_md5 = file_checksum(item.file_path);
		}

		foreach(var item in dir2.children.values){
			if (!item.content_type.has_prefix("text") || (item.size > size_limit)) { continue; }
			item.checksum_md5 = file_checksum(item.file_path);
		}

		compare_files_with_set(this, dir2, size_limit);
		compare_files_with_set(dir2, this, size_limit);
	}

	private void compare_files_with_set(FileItem dir1, FileItem dir2, uint64 size_limit){

		foreach(var file1 in dir1.children.values){

			if (!file1.content_type.has_prefix("text") || (file1.size > size_limit)){
				file1.compared_status = "skipped";
			}
			else if (dir2.children.has_key(file1.file_name)){

				var file2 = dir2.children[file1.file_name];

				file1.compared_file_path = file2.file_path;

				if (file1.checksum_md5 != file2.checksum_md5){
					file1.compared_status = "mismatch";
				}
				else{
					file1.compared_status = "match";
				}
			}
			else{
				file1.compared_status = "new";
			}
		}
	}

	// archives

	public void add_items_to_archive(Gee.ArrayList<FileItem> item_list){
		
		if (item_list.size > 0){
			foreach(var item in item_list){
				var child = add_child_from_disk(item.file_path);
				child.archive_base_item = this.archive_base_item;
			}
		}
	}

	public ArchiveTask list_archive(){
		var task = new ArchiveTask();
		task.open(this);
		return task;
	}

	public void update_size_from_children(){
		_size = 0;
		foreach(var item in children.values){
			_size += item.size;
		}
	}
/*
	public ArchiveTask extract_archive_to_same_location(){

		var task = new ArchiveTask();
		task.compress(file_path);
		return task;
		
		this.extraction_path = current_item.file_path;

		// select a subfolder in source path for extraction
			archiver.extraction_path = "%s/%s".printf(
				file_parent(archive.file_path),
				file_title(archive.file_path));

			// since user has not specified the directory we need to
			// make sure that files are not overwritten accidentally
			// in existing directories
			 
			// create a unique extraction directory
			int count = 0;
			string outpath = archiver.extraction_path;
			while (dir_exists(outpath)||file_exists(outpath)){
				log_debug("dir_exists: %s".printf(outpath));
				outpath = "%s (%d)".printf(archiver.extraction_path, ++count);
			}
			log_debug("create_dir: %s".printf(outpath));
			archiver.extraction_path = outpath;
	}
	
	public ArchiveTask extract_archive(){
		var task = new ArchiveTask();
		task.compress(this);
		return task;
	}
	*/
}

public class FileItemMonitor : GLib.Object {
	public FileItem file_item;
	public FileMonitor monitor;
	public Cancellable? cancellable;
}
