/*
 * Main.vala
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

public Main App;
public const string AppName = "Polo File Manager";
public const string AppShortName = "polo";
public const string AppVersion = "18.2 BETA";
public const string AppWikiVersion = ""; // update only if wiki page exists
public const string AppAuthor = "Tony George";
public const string AppAuthorEmail = "teejeetech@gmail.com";

public const int PLUGIN_VER_ISO = 3;
public const int PLUGIN_VER_PDF = 3;
public const int PLUGIN_VER_IMAGE = 3;
public const int PLUGIN_VER_YT = 4;
public const int PLUGIN_VER_CLAMAV = 1;

const string GETTEXT_PACKAGE = "";
const string LOCALE_DIR = "/usr/share/locale";

extern void exit(int exit_code);

public class Main : GLib.Object {

	// static defaults ---------------------------------
	
	public static double LV_FONT_SCALE = 1.0;
	public static int LV_ICON_SIZE = 32;
	public static int LV_ROW_SPACING = 0;

	public static int IV_ICON_SIZE = 64;
	public static int IV_ROW_SPACING = 10;
	public static int IV_COLUMN_SPACING = 50;

	public static int TV_ICON_SIZE = 80;
	public static int TV_ROW_SPACING = 2;
	public static int TV_PADDING = 2;

	public static int DEFAULT_SIDEBAR_POSITION = 200;
	public static int DEFAULT_PROPBAR_POSITION = 600;

	public static string REQUIRED_COLUMNS = "name,indicator,spacer";
	public static string REQUIRED_COLUMNS_END = "spacer";
	public static string DEFAULT_COLUMNS = "name,indicator,size,modified,filetype,spacer";
	public static string DEFAULT_COLUMN_ORDER = "name,indicator,size,modified,filetype,permissions,user,group,access,mimetype,symlink_target,original_path,deletion_date,compressed,md5,spacer";

	public static int SESSION_FORMAT_VERSION = 1;
	public static int APP_CONFIG_FORMAT_VERSION = 1;
	public static int APP_CONFIG_FOLDERS_FORMAT_VERSION = 1;
	public static int APP_CONFIG_ARCHIVE_FORMAT_VERSION = 1;

	// instance ------------------------------------------------
	
	public string[] cmd_args;
	public bool gui_mode = false;
	
	public string user_name = "";
	public string user_name_effective = "";
	public string user_home = "";
	public string user_home_effective = "";
	public int user_id = -1;
	public int user_id_effective = -1;
	public XdgUserDirectories user_dirs = null;
	
	public bool add_context_menu = true;
	public bool add_context_submenu = false;
	public bool associate_archives = true;
	public string last_input_dir = "";
	public string last_output_dir = "";

	public string app_version_in_config = "";

	public bool first_run = false;
	public FileItem fs_root = null;
	
	public string gtk_theme = "";

	public AppLock session_lock;

	public SysInfo sysinfo;

	public Gee.HashMap<string,Tool> tools = new Gee.HashMap<string,Tool>();

	public Gee.HashMap<string,Plugin> plugins = new Gee.HashMap<string,Plugin>();

	public string temp_dir = "";
	public string current_dir = "";
	public string share_dir = "/usr/share/polo";
	public string app_conf_path = "";
	public string app_conf_folders = "";
	public string app_conf_session = "";
	public string app_conf_archive = "";
	public string app_conf_dir_path = "";
	public string app_conf_dir_path_open = "";
	public string app_conf_dir_remotes = "";

	public string rclone_mounts = "";

	public Json.Object appconfig;
	public Bash bash_admin_shell;

	public string shell_default = "fish";
	public string compare_default = "bcompare";

	public AppMode app_mode = AppMode.OPEN;
	public Gee.ArrayList<string> cmd_files;
	public string arg_outpath = "";
	public bool arg_same_path = false;
	public bool arg_prompt_outpath = false;

	public bool use_large_icons_nav_pane = false;
	public ViewMode view_mode = ViewMode.ICONS;
	public bool single_click_activate = false;
	public bool restore_last_session = true;

	public bool query_subfolders = false;
	
	public bool sidebar_visible = true;
	public bool sidebar_bookmarks = true;
	public bool sidebar_places = true;
	public bool sidebar_devices = true;
	public bool sidebar_dark = true;
	public bool sidebar_action_button = false;
	public int sidebar_position = DEFAULT_SIDEBAR_POSITION;
	public string sidebar_collapsed_sections = "";

	public bool propbar_visible = false;
	public int propbar_position = DEFAULT_PROPBAR_POSITION;

	public int bookmarks_position = 300;

	public bool headerbar_enabled = false;
	public bool headerbar_enabled_temp = false;
	public bool headerbar_window_buttons_left = false;

	public bool middlebar_visible = true;

	public bool toolbar_visible = true;
	public bool toolbar_large_icons = false;
	public bool toolbar_dark = true;
	public bool toolbar_labels = true;
	public bool toolbar_labels_beside_icons = true;

	public bool toolbar_item_back = true;
	public bool toolbar_item_next = true;
	public bool toolbar_item_up = true;
	public bool toolbar_item_reload = true;
	public bool toolbar_item_home = true;
	public bool toolbar_item_terminal = true;
	public bool toolbar_item_properties = true;
	public bool toolbar_item_hidden = true;
	public bool toolbar_item_dual_pane = true;
	public bool toolbar_item_view = true;
	public bool toolbar_item_bookmarks = true;
	public bool toolbar_item_devices = true;

	public bool pathbar_unified = false;
	public PathbarStyle pathbar_style = PathbarStyle.COMPACT; 
	public bool pathbar_show_bookmarks = true;
	public bool pathbar_show_disks = true;
	public bool pathbar_show_back = false;
	public bool pathbar_show_next = false;
	public bool pathbar_show_up = false;
	public bool pathbar_show_home = false;
	public bool pathbar_show_swap = true;
	public bool pathbar_show_other = true;
	public bool pathbar_show_close = true;

	public bool statusbar_unified = false;

	public bool confirm_delete = true;
	public bool confirm_trash = true;

	public bool show_context_menu_disk_usage = true;
	public bool show_context_menu_clamav = true;
	public bool show_context_menu_archive = true;
	public bool show_context_menu_checksum = true;
	public bool show_context_menu_kvm = true;

	public bool overwrite_pdf_split = false;
	public bool overwrite_pdf_merge = false;
	public bool overwrite_pdf_compress = false;
	public bool overwrite_pdf_uncompress = false;
	public bool overwrite_pdf_protect = false;
	public bool overwrite_pdf_unprotect = false;
	public bool overwrite_pdf_decolor = false;
	public bool overwrite_pdf_optimize = false;
	public bool overwrite_pdf_rotate = false;

	public bool overwrite_image_optimize_png = false;
	public bool overwrite_image_reduce_jpeg = false;
	public bool overwrite_image_resize = false;
	public bool overwrite_image_rotate = false;
	public bool overwrite_image_convert = false;
	public bool overwrite_image_decolor = false;
	public bool overwrite_image_boost_color = false;
	public bool overwrite_image_reduce_color = false;
	
	public bool tabs_bottom = false;
	public bool tabs_close_visible = true;

	public const string TERM_FONT_DESC = "11";
	public Pango.FontDescription term_font;
	public string term_fg_color = "#DCDCDC";
	public string term_bg_color = "#2C2C2C";
	public bool term_enable_network = true;
	public bool term_enable_gui = true;

	public string kvm_vga = "std";
	public string kvm_cpu = "host";
	public int kvm_smp = 1;
	public int kvm_mem = 2048;
	public int kvm_cpu_limit = 80;
	public string kvm_format = ".qcow2";

	public TermBox? admin_shell = null;

	public string selected_columns = DEFAULT_COLUMNS;

	public bool show_hidden_files = false;
	public PanelLayout panel_layout = PanelLayout.SINGLE;
	public bool maximise_on_startup = true;
	public bool single_instance_mode = true;
	public bool minimize_to_tray = true;
	public bool autostart = true;
	
	public double listview_font_scale = LV_FONT_SCALE;
	public int listview_icon_size = LV_ICON_SIZE;
	public int listview_row_spacing = LV_ROW_SPACING;
	public bool listview_emblems = false;
	public bool listview_thumbs = true;
	public bool listview_transparency = true;

	public int iconview_icon_size = IV_ICON_SIZE;
	public int iconview_row_spacing = IV_ROW_SPACING;
	public int iconview_column_spacing = IV_COLUMN_SPACING;
	public bool iconview_emblems = true;
	public bool iconview_thumbs = true;
	public bool iconview_transparency = true;

	public bool iconview_trim_names = true;

	public int tileview_icon_size = TV_ICON_SIZE;
	public int tileview_row_spacing = TV_ROW_SPACING;
	public int tileview_padding = TV_PADDING;
	public bool tileview_emblems = true;
	public bool tileview_thumbs = true;
	public bool tileview_transparency = true;

	public bool donation_plugins_found = false;
	public bool plugin_obsolete_iso = false;
	public bool plugin_obsolete_pdf = false;
	public bool plugin_obsolete_image = false;

	public bool dm_hide_fs = false;
	public bool dm_hide_mp = false;
	public bool dm_hide_size = false;
	public bool dm_hide_header = false;
	public int dm_width = 800;
	public int dm_height = 600;
	
	public Gee.ArrayList<string> mediaview_exclude = new Gee.ArrayList<string>();
	public Gee.ArrayList<string> mediaview_include = new Gee.ArrayList<string>();
	
	public string status_line = "";
	public int64 progress_count;
	public int64 progress_total;

	public MainWindow main_window = null;

	public TrashCan trashcan;

	public RCloneClient rclone;

	public string admin_pass = "";

	public string[] supported_formats_open;

	// donation counter
	private int run_count = 0;
	private int[] donation_triggers = { 100 };

	public static string[] extensions_tar = {
		".tar"
	};

	public static string[] extensions_tar_compressed = {
		".tar.gz", ".tgz",
		".tar.bzip2",".tar.bz2", ".tbz", ".tbz2", ".tb2",
		".tar.lzma", ".tar.lz", ".tlz",
		".tar.lzo",
		".tar.xz", ".txz"
	};

	public static string[] extensions_tar_packed = {
		".tar.7z",
		".tar.zip",
		".deb"
	};

	public static string[] extensions_7z_unpack = {
		".001", ".7z" , ".lzma",
		".bz2", ".bzip2",
		".gz" , ".gzip",
		".zip", ".jar", ".war", ".ear",
		".rar", ".cab", ".arj", ".z", ".taz", ".cpio",
		".rpm", ".deb",
		".lzh", ".lha",
		".chm", ".chw", ".hxs",
		".iso", ".dmg", ".dar", ".xar", ".hfs", ".ntfs", ".fat", ".vhd", ".mbr",
		".wim", ".swm", ".squashfs", ".cramfs", ".scap"
	};

	public static string[] extensions_single_file = {
		".bz2", ".gz", ".xz", ".lzo"
	};

	public static string[] formats_single_file = {
		"bz2", "gz", "xz", "lzo"
	}; //7z,zip,tar support multiple files

	public Main(string[] args, bool _gui_mode) {

		App = this;

		cmd_args = args;

		gui_mode = _gui_mode;

		cmd_files = new Gee.ArrayList<string>();

		//get user info
		
		user_name = get_username();
		user_name_effective = get_username_effective();
		user_id = get_user_id();
		user_id_effective = get_user_id_effective();
		user_home = get_user_home();
		user_home_effective = get_user_home_effective();

		user_dirs = new XdgUserDirectories(user_name);

		sysinfo = new SysInfo();
		
		SystemUser.query_users();
		SystemGroup.query_groups();

		session_lock = new AppLock();
		session_lock.create(AppShortName, "session"); // may succeed or fail
		
		Device.init();

		FileItem.init();
		IconManager.init(args, AppShortName);
		Thumbnailer.init();

		IconCache.enable();

		app_conf_dir_path      = path_combine(user_home, ".config/polo");
		dir_create(app_conf_dir_path);
		
		app_conf_dir_path_open = path_combine(app_conf_dir_path, "open");
		dir_create(app_conf_dir_path_open);
		
		app_conf_dir_remotes   = path_combine(app_conf_dir_path, "remotes");
		dir_create(app_conf_dir_remotes);
		
		app_conf_path    = path_combine(app_conf_dir_path, "polo.json");
		app_conf_folders = path_combine(app_conf_dir_path, "polo-folders.json");
		app_conf_session = path_combine(app_conf_dir_path, "polo-last-session.json");
		app_conf_archive = path_combine(app_conf_dir_path, "polo-archive.json");

		supported_formats_open = {
			".tar",
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

		//initialize current_dir as current directory for CLI mode
		if (!gui_mode) {
			current_dir = Environment.get_current_dir();
		}

		try {
			//create temp dir
			temp_dir = get_temp_file_path();

			var f = File.new_for_path(temp_dir);
			if (f.query_exists()) {
				Posix.system("rm -rf %s".printf(temp_dir));
			}
			f.make_directory_with_parents();
		}
		catch (Error e) {
			log_error (e.message);
		}

		MimeType.query_mimetypes();
		DesktopApp.query_apps();
		MimeApp.query_mimeapps(user_home);

		trashcan = new TrashCan(user_id_effective, user_name_effective, user_home_effective);
		trashcan.query_items(false);

		rclone = new RCloneClient();
		rclone_mounts = rclone.rclone_mounts;
		
		/*foreach(var app in DesktopApp.applist.values){
			if (app.desktop_file_name == "crunchy.desktop"){
				crunchy_app = app;
				break;
			}
		}*/

		fs_root = new FileItem.from_path_and_type("/", FileType.DIRECTORY, true);

		//load_mimetype_list();

		string src_path = path_combine(share_dir, "files/fish_prompt.fish");
		string dst_path = path_combine(user_home, ".config/fish/functions/fish_prompt.fish");
		if (!file_exists(dst_path)){
			dir_create(path_combine(user_home, ".config/fish/functions"));
			file_copy(src_path, dst_path);
			//chown(dst_path, user_name, user_name, false, null);
			//chmod(dst_path, "u+rw", null);
		}

		src_path = path_combine(share_dir, "files/bashrc");
		dst_path = path_combine(app_conf_dir_path, "bashrc");
		if (!file_exists(dst_path)){
			file_copy(src_path, dst_path);
			//chown(dst_path, user_name, user_name, false, null);
			//chmod(dst_path, "u+rw", null);
		}

		init_tools();

		init_plugins();

		load_app_config();

		Proc.list_processes();
	}

	public void start_bash_admin_shell(){
		if (bash_admin_shell == null){
			bash_admin_shell = new Bash();
			bash_admin_shell.start_shell();
			//Device.bash_admin_shell = bash_admin_shell;
		}
	}

	public bool check_dependencies(out string msg) {
		msg = "";

		string[] dependencies = { "grep", "awk", "find", "xdg-mime", "7z" }; //"7z", "tar", "gzip",

		foreach(string cmd_tool in dependencies) {
			if (!command_exists(cmd_tool)) {
				msg += " * " + cmd_tool + "\n";
			}
		}

		if (msg.length > 0) {
			msg = _("Commands listed below are not available on this system") + ":\n\n" + msg + "\n";
			msg += _("Please install required packages and try running again");
			log_msg(msg);
			return false;
		}
		else {
			return true;
		}
	}

	public void init_tools(){
		
		tools["ffmpeg"] = new Tool("ffmpeg","FFmpeg Encoder","Generate thumbnails for video");
		tools["mediainfo"] = new Tool("mediainfo","MediaInfo","Read media properties from audio and video files");
		tools["exiftool"] = new Tool("exiftool","ExifTool","Read EXIF properties from JPG/TIFF/PNG/PDF files");
		tools["tar"] = new Tool("tar","tar","Read and extract TAR archives");
		tools["7z"] = new Tool("7z","7zip","Read and extract multiple archive formats");
		tools["lzop"] = new Tool("lzop","lzop","Read and extract LZO archives");
		tools["pv"] = new Tool("pv","pv","Get progress info for compression and extraction");
		tools["lsblk"] = new Tool("lsblk","lsblk","Read device information");
		tools["udisksctl"] = new Tool("udisksctl","udisksctl","Mount and unmount devices");
		tools["cryptsetup"] = new Tool("cryptsetup","cryptsetup","Unlock encrypted LUKS devices");
		tools["xdg-mime"] = new Tool("xdg-mime","xdg-mime","Set file type associations");
		tools["fish"] = new Tool("fish","Fish Shell","Terminal Shell");
		tools["kvm"] = new Tool("kvm","Qemu-Kvm Emulator","Virtual Machine Emulator");
		tools["pdftk"] = new Tool("pdftk","pdftk","Converting PDF files");
		tools["convert"] = new Tool("convert","convert","Converting images and PDF documents");
		tools["pngcrush"] = new Tool("pngcrush","pngcrush","Reduce file size of PNG files");
		tools["gs"] = new Tool("gs","ghostscript","Ghostscript - Converting PDF files");
		tools["polo-clamav"] = new Tool("polo-clamav","polo-clamav","ClamAV Plugin (Donation)");
		tools["polo-iso"] = new Tool("polo-iso","polo-iso","Polo ISO Plugin (Donation)");
		tools["polo-pdf"] = new Tool("polo-pdf","polo-pdf","Polo PDF Plugin (Donation)");
		tools["polo-image"] = new Tool("polo-image","polo-image","Polo Image Plugin (Donation)");
		tools["polo-yt"] = new Tool("polo-yt","polo-yt","Polo Video Download Plugin (Donation)");
		tools["polo-disk"] = new Tool("polo-disk","polo-disk","Polo Disk Helper Plugin");
		tools["gnome-disks"] = new Tool("gnome-disks","gnome-disks","GNOME Disk Utility");
		tools["rclone"] = new Tool("rclone","rclone","rsync for Cloud Storage");
		tools["youtube-dl"] = new Tool("youtube-dl","youtube-dl","youtube-dl Downloader");
		tools["diffuse"] = new Tool("diffuse","diffuse","File Compare Utility");
		tools["groot"] = new Tool("groot","groot","Groot Utility for chroot");

		check_all_tools();
	}

	public void check_all_tools(){
		
		foreach(var tool in tools.values){
			
			tool.check_availablity();
		}
	}

	public bool tool_exists(string cmd, bool check_again = false){
		
		if (tools.keys.contains(cmd) && !check_again){
			
			var tool = tools[cmd];
			return tool.available;
		}
		else{
			return cmd_exists(cmd);
		}
	}

	public void init_plugins(){
		
		plugins["iso"] = new Plugin("polo-iso", "Polo ISO Plugin", PLUGIN_VER_ISO);
		plugins["pdf"] = new Plugin("polo-pdf", "Polo PDF Plugin", PLUGIN_VER_PDF);
		plugins["image"] = new Plugin("polo-image", "Polo Image Plugin", PLUGIN_VER_IMAGE);
		plugins["yt"] = new Plugin("polo-yt", "Polo Video Download Plugin", PLUGIN_VER_YT);
		plugins["clamav"] = new Plugin("polo-clamav", "Polo ClamAV Plugin", PLUGIN_VER_CLAMAV);

		check_all_plugins();
	}

	public void check_all_plugins(){
		
		foreach(var plugin in plugins.values){
			
			plugin.check_availablity();

			if (plugin.available){
				donation_plugins_found = true;
			}
		}
	}

	/* Configuration */

	public void save_app_config() {

		var config = new Json.Object();

		set_numeric_locale("C"); // switch numeric locale

		config.set_string_member("app-version", AppVersion);

		config.set_string_member("run-count", run_count.to_string());

		config.set_int_member("format-version", (int64) APP_CONFIG_FORMAT_VERSION);
		
		config.set_string_member("gtk_theme", gtk_theme);
		
		config.set_string_member("middlebar_visible", middlebar_visible.to_string());
		config.set_string_member("sidebar_visible", sidebar_visible.to_string());
		config.set_string_member("sidebar_dark", sidebar_dark.to_string());
		config.set_string_member("sidebar_places", sidebar_places.to_string());
		config.set_string_member("sidebar_bookmarks", sidebar_bookmarks.to_string());
		config.set_string_member("sidebar_devices", sidebar_devices.to_string());
		config.set_string_member("sidebar_position", sidebar_position.to_string());
		config.set_string_member("sidebar_action_button", sidebar_action_button.to_string());
		config.set_string_member("sidebar_collapsed_sections", sidebar_collapsed_sections);

		config.set_string_member("propbar_visible", propbar_visible.to_string());
		config.set_string_member("propbar_position", propbar_position.to_string());

		config.set_string_member("bookmarks_position", bookmarks_position.to_string());

		//save headerbar_enabled_temp instead of headerbar_enabled
		config.set_string_member("headerbar_enabled", headerbar_enabled_temp.to_string());
		config.set_string_member("headerbar_window_buttons_left", headerbar_window_buttons_left.to_string());

		config.set_string_member("show_hidden_files", show_hidden_files.to_string());
		config.set_string_member("panel_layout", ((int)panel_layout).to_string());
		config.set_string_member("view_mode", ((int)view_mode).to_string());
		config.set_string_member("shell_default", shell_default);

		config.set_string_member("listview_font_scale", listview_font_scale.to_string());
		config.set_string_member("listview_icon_size", listview_icon_size.to_string());
		config.set_string_member("listview_row_spacing", listview_row_spacing.to_string());
		config.set_string_member("listview_emblems", listview_emblems.to_string());
		config.set_string_member("listview_thumbs", listview_thumbs.to_string());
		config.set_string_member("listview_transparency", listview_transparency.to_string());

		config.set_string_member("iconview_icon_size", iconview_icon_size.to_string());
		config.set_string_member("iconview_row_spacing", iconview_row_spacing.to_string());
		config.set_string_member("iconview_column_spacing", iconview_column_spacing.to_string());
		config.set_string_member("iconview_emblems", iconview_emblems.to_string());
		config.set_string_member("iconview_thumbs", iconview_thumbs.to_string());
		config.set_string_member("iconview_transparency", iconview_transparency.to_string());

		config.set_string_member("iconview_trim_names", iconview_trim_names.to_string());

		config.set_string_member("tileview_icon_size", tileview_icon_size.to_string());
		config.set_string_member("tileview_row_spacing", tileview_row_spacing.to_string());
		config.set_string_member("tileview_padding", tileview_padding.to_string());
		config.set_string_member("tileview_emblems", tileview_emblems.to_string());
		config.set_string_member("tileview_thumbs", tileview_thumbs.to_string());
		config.set_string_member("tileview_transparency", tileview_transparency.to_string());

		config.set_string_member("toolbar_visible", toolbar_visible.to_string());
		config.set_string_member("toolbar_large_icons", toolbar_large_icons.to_string());
		config.set_string_member("toolbar_dark", toolbar_dark.to_string());
		//config.set_string_member("toolbar_unified", toolbar_unified.to_string());
		config.set_string_member("toolbar_labels", toolbar_labels.to_string());
		config.set_string_member("toolbar_labels_beside_icons", toolbar_labels_beside_icons.to_string());

		config.set_string_member("toolbar_item_back", toolbar_item_back.to_string());
		config.set_string_member("toolbar_item_next", toolbar_item_next.to_string());
		config.set_string_member("toolbar_item_up", toolbar_item_up.to_string());
		config.set_string_member("toolbar_item_reload", toolbar_item_reload.to_string());
		config.set_string_member("toolbar_item_home", toolbar_item_home.to_string());
		config.set_string_member("toolbar_item_terminal", toolbar_item_terminal.to_string());
		config.set_string_member("toolbar_item_properties", toolbar_item_properties.to_string());
		config.set_string_member("toolbar_item_hidden", toolbar_item_hidden.to_string());
		config.set_string_member("toolbar_item_dual_pane", toolbar_item_dual_pane.to_string());
		config.set_string_member("toolbar_item_view", toolbar_item_view.to_string());
		config.set_string_member("toolbar_item_bookmarks", toolbar_item_bookmarks.to_string());
		config.set_string_member("toolbar_item_devices", toolbar_item_devices.to_string());

		config.set_string_member("pathbar_unified", pathbar_unified.to_string());
		config.set_string_member("pathbar_style", pathbar_style.to_string());
		config.set_string_member("pathbar_show_bookmarks", pathbar_show_bookmarks.to_string());
		config.set_string_member("pathbar_show_disks", pathbar_show_disks.to_string());
		config.set_string_member("pathbar_show_back", pathbar_show_back.to_string());
		config.set_string_member("pathbar_show_next", pathbar_show_next.to_string());
		config.set_string_member("pathbar_show_up", pathbar_show_up.to_string());
		config.set_string_member("pathbar_show_home", pathbar_show_home.to_string());
		config.set_string_member("pathbar_show_swap", pathbar_show_swap.to_string());
		config.set_string_member("pathbar_show_other", pathbar_show_other.to_string());
		config.set_string_member("pathbar_show_close", pathbar_show_close.to_string());

		config.set_string_member("statusbar_unified", statusbar_unified.to_string());

		config.set_string_member("tabs_bottom", tabs_bottom.to_string());
		config.set_string_member("tabs_close_visible", tabs_close_visible.to_string());

		config.set_string_member("term_font", term_font.to_string());
		config.set_string_member("term_fg_color", term_fg_color);
		config.set_string_member("term_bg_color", term_bg_color);
		config.set_string_member("term_enable_network", term_enable_network.to_string());
		config.set_string_member("term_enable_gui", term_enable_gui.to_string());

		config.set_string_member("kvm_cpu", kvm_cpu);
		config.set_string_member("kvm_smp", kvm_smp.to_string());
		config.set_string_member("kvm_cpu_limit", kvm_cpu_limit.to_string());
		config.set_string_member("kvm_vga", kvm_vga);
		config.set_string_member("kvm_mem", kvm_mem.to_string());

		config.set_string_member("selected_columns", selected_columns);
		config.set_string_member("maximise_on_startup", maximise_on_startup.to_string());
		//config.set_string_member("single_click_activate", single_click_activate.to_string());
		config.set_string_member("restore_last_session", restore_last_session.to_string());
		config.set_string_member("single_instance_mode", single_instance_mode.to_string());
		config.set_string_member("minimize_to_tray", minimize_to_tray.to_string());
		config.set_string_member("autostart", autostart.to_string());

		config.set_string_member("query_subfolders", query_subfolders.to_string());

		config.set_string_member("confirm_delete", confirm_delete.to_string());
		config.set_string_member("confirm_trash", confirm_trash.to_string());

		config.set_string_member("show_context_menu_disk_usage", show_context_menu_disk_usage.to_string());
		config.set_string_member("show_context_menu_clamav", show_context_menu_clamav.to_string());
		config.set_string_member("show_context_menu_archive", show_context_menu_archive.to_string());
		config.set_string_member("show_context_menu_checksum", show_context_menu_checksum.to_string());
		config.set_string_member("show_context_menu_kvm", show_context_menu_kvm.to_string());

		config.set_string_member("overwrite_pdf_split", overwrite_pdf_split.to_string());
		config.set_string_member("overwrite_pdf_merge", overwrite_pdf_merge.to_string());
		config.set_string_member("overwrite_pdf_compress", overwrite_pdf_compress.to_string());
		config.set_string_member("overwrite_pdf_uncompress", overwrite_pdf_uncompress.to_string());
		config.set_string_member("overwrite_pdf_protect", overwrite_pdf_protect.to_string());
		config.set_string_member("overwrite_pdf_unprotect", overwrite_pdf_unprotect.to_string());
		config.set_string_member("overwrite_pdf_decolor", overwrite_pdf_decolor.to_string());
		config.set_string_member("overwrite_pdf_rotate", overwrite_pdf_rotate.to_string());
		config.set_string_member("overwrite_pdf_optimize", overwrite_pdf_optimize.to_string());

		config.set_string_member("overwrite_image_optimize_png", overwrite_image_optimize_png.to_string());
		config.set_string_member("overwrite_image_reduce_jpeg", overwrite_image_reduce_jpeg.to_string());
		config.set_string_member("overwrite_image_resize", overwrite_image_resize.to_string());
		config.set_string_member("overwrite_image_rotate", overwrite_image_rotate.to_string());
		config.set_string_member("overwrite_image_convert", overwrite_image_convert.to_string());
		config.set_string_member("overwrite_image_decolor", overwrite_image_decolor.to_string());
		config.set_string_member("overwrite_image_boost_color", overwrite_image_boost_color.to_string());
		config.set_string_member("overwrite_image_reduce_color", overwrite_image_reduce_color.to_string());

		config.set_string_member("dm_hide_fs", dm_hide_fs.to_string());
		config.set_string_member("dm_hide_mp", dm_hide_mp.to_string());
		config.set_string_member("dm_hide_size", dm_hide_size.to_string());
		config.set_string_member("dm_hide_header", dm_hide_header.to_string());
		config.set_string_member("dm_width", dm_width.to_string());
		config.set_string_member("dm_height", dm_height.to_string());
		
		save_folder_selections();
		
		GtkBookmark.save_bookmarks();

		var json = new Json.Generator();
		json.pretty = true;
		json.indent = 2;
		var node = new Json.Node(NodeType.OBJECT);
		node.set_object(config);
		json.set_root(node);

		try {
			json.to_file(this.app_conf_path);
		} catch (Error e) {
			log_error (e.message);
		}

		set_numeric_locale(""); // reset numeric locale

		log_debug("\n" + _("App config saved") + ": '%s'".printf(app_conf_path));
	}

	public void load_app_config() {

		var f = File.new_for_path(app_conf_path);
		if (!f.query_exists()) {
			first_run = true;
			load_app_config_finish();
			return;
		}

		var parser = new Json.Parser();
		try {
			parser.load_from_file(this.app_conf_path);
		}
		catch (Error e) {
			log_error (e.message);
		}

		var node = parser.get_root();
		var config = node.get_object();

		appconfig = config;

		if (format_is_obsolete(config, Main.APP_CONFIG_FORMAT_VERSION)){
			first_run = true; // regard as first run
			return;
		}

		set_numeric_locale("C"); // switch numeric locale

		app_version_in_config = json_get_string(config, "app-version", "0");
		run_count = json_get_int_from_string(config, "run-count", 0);
		// set dummy version number, if config file exists but parameter is missing
		// this will trigger display of change log file
		
		gtk_theme = json_get_string(config, "gtk_theme", gtk_theme);
		
		middlebar_visible = json_get_bool_from_string(config, "middlebar_visible", middlebar_visible);
		sidebar_visible = json_get_bool_from_string(config, "sidebar_visible", sidebar_visible);
		sidebar_dark = json_get_bool_from_string(config, "sidebar_dark", sidebar_dark);
		sidebar_places = json_get_bool_from_string(config, "sidebar_places", sidebar_places);
		sidebar_bookmarks = json_get_bool_from_string(config, "sidebar_bookmarks", sidebar_bookmarks);
		sidebar_devices = json_get_bool_from_string(config, "sidebar_devices", sidebar_devices);
		sidebar_position = json_get_int_from_string(config, "sidebar_position", sidebar_position);
		sidebar_action_button = json_get_bool_from_string(config, "sidebar_action_button", sidebar_action_button);

		bookmarks_position = json_get_int_from_string(config, "bookmarks_position", bookmarks_position);
		
		headerbar_enabled = json_get_bool_from_string(config, "headerbar_enabled", headerbar_enabled);
		headerbar_enabled_temp = headerbar_enabled;
		headerbar_window_buttons_left = json_get_bool_from_string(config, "headerbar_window_buttons_left", headerbar_window_buttons_left);
		
		show_hidden_files = json_get_bool_from_string(config, "show_hidden_files", show_hidden_files);
		panel_layout = (PanelLayout) json_get_int_from_string(config, "panel_layout", panel_layout);
		shell_default = json_get_string(config, "shell_default", shell_default);
		
		int vmode = json_get_int_from_string(config, "view_mode", view_mode);
		if (vmode >= 1 && vmode <= 4){
			view_mode = (ViewMode) vmode;
		}
		else{
			view_mode = ViewMode.LIST;
		}

		listview_font_scale = json_get_double(config, "listview_font_scale", LV_FONT_SCALE);
		listview_icon_size = json_get_int_from_string(config, "listview_icon_size", LV_ICON_SIZE);
		listview_row_spacing = json_get_int_from_string(config, "listview_row_spacing", LV_ROW_SPACING);
		listview_emblems = json_get_bool_from_string(config, "listview_emblems", listview_emblems);
		listview_thumbs = json_get_bool_from_string(config, "listview_thumbs", listview_thumbs);
		listview_transparency = json_get_bool_from_string(config, "listview_transparency", listview_transparency);

		iconview_icon_size = json_get_int_from_string(config, "iconview_icon_size", IV_ICON_SIZE);
		iconview_row_spacing = json_get_int_from_string(config, "iconview_row_spacing", IV_ROW_SPACING);
		iconview_column_spacing = json_get_int_from_string(config, "iconview_column_spacing", IV_COLUMN_SPACING);
		iconview_emblems = json_get_bool_from_string(config, "iconview_emblems", iconview_emblems);
		iconview_thumbs = json_get_bool_from_string(config, "iconview_thumbs", iconview_thumbs);
		iconview_transparency = json_get_bool_from_string(config, "iconview_transparency", iconview_transparency);

		iconview_trim_names = json_get_bool_from_string(config, "iconview_trim_names", iconview_trim_names);

		tileview_icon_size = json_get_int_from_string(config, "tileview_icon_size", TV_ICON_SIZE);
		tileview_row_spacing = json_get_int_from_string(config, "tileview_row_spacing", TV_ROW_SPACING);
		tileview_padding = json_get_int_from_string(config, "tileview_padding", TV_PADDING);
		listview_emblems = json_get_bool_from_string(config, "listview_emblems", listview_emblems);
		listview_thumbs = json_get_bool_from_string(config, "listview_thumbs", listview_thumbs);
		listview_transparency = json_get_bool_from_string(config, "listview_transparency", listview_transparency);

		toolbar_visible = json_get_bool_from_string(config, "toolbar_visible", toolbar_visible);
		toolbar_large_icons = json_get_bool_from_string(config, "toolbar_large_icons", toolbar_large_icons);
		toolbar_dark = json_get_bool_from_string(config, "toolbar_dark", toolbar_dark);
		//toolbar_unified = json_get_bool_from_string(config, "toolbar_unified", toolbar_unified);
		toolbar_labels = json_get_bool_from_string(config, "toolbar_labels", toolbar_labels);
		toolbar_labels_beside_icons = json_get_bool_from_string(config, "toolbar_labels_beside_icons", toolbar_labels_beside_icons);

		toolbar_item_back = json_get_bool_from_string(config, "toolbar_item_back", toolbar_item_back);
		toolbar_item_next = json_get_bool_from_string(config, "toolbar_item_next", toolbar_item_next);
		toolbar_item_up = json_get_bool_from_string(config, "toolbar_item_up", toolbar_item_up);
		toolbar_item_reload = json_get_bool_from_string(config, "toolbar_item_reload", toolbar_item_reload);
		toolbar_item_home = json_get_bool_from_string(config, "toolbar_item_home", toolbar_item_home);
		toolbar_item_terminal = json_get_bool_from_string(config, "toolbar_item_terminal", toolbar_item_terminal);
		toolbar_item_properties = json_get_bool_from_string(config, "toolbar_item_properties", toolbar_item_properties);
		toolbar_item_hidden = json_get_bool_from_string(config, "toolbar_item_hidden", toolbar_item_hidden);
		toolbar_item_dual_pane = json_get_bool_from_string(config, "toolbar_item_dual_pane", toolbar_item_dual_pane);
		toolbar_item_view = json_get_bool_from_string(config, "toolbar_item_view", toolbar_item_view);
		toolbar_item_bookmarks = json_get_bool_from_string(config, "toolbar_item_bookmarks", toolbar_item_bookmarks);
		toolbar_item_devices = json_get_bool_from_string(config, "toolbar_item_devices", toolbar_item_devices);

		pathbar_unified = json_get_bool_from_string(config, "pathbar_unified", pathbar_unified);

		var text = json_get_string(config, "pathbar_style", "compact");
		pathbar_style = PathbarStyle.from_string(text);

		pathbar_show_bookmarks = json_get_bool_from_string(config, "pathbar_show_bookmarks", pathbar_show_bookmarks);
		pathbar_show_disks = json_get_bool_from_string(config, "pathbar_show_disks", pathbar_show_disks);
		pathbar_show_back = json_get_bool_from_string(config, "pathbar_show_back", pathbar_show_back);
		pathbar_show_next = json_get_bool_from_string(config, "pathbar_show_next", pathbar_show_next);
		pathbar_show_up = json_get_bool_from_string(config, "pathbar_show_up", pathbar_show_up);
		pathbar_show_home = json_get_bool_from_string(config, "pathbar_show_home", pathbar_show_home);
		pathbar_show_swap = json_get_bool_from_string(config, "pathbar_show_swap", pathbar_show_swap);
		pathbar_show_other = json_get_bool_from_string(config, "pathbar_show_other", pathbar_show_other);
		pathbar_show_close = json_get_bool_from_string(config, "pathbar_show_close", pathbar_show_close);

		statusbar_unified = json_get_bool_from_string(config, "statusbar_unified", statusbar_unified);

		tabs_bottom = json_get_bool_from_string(config, "tabs_bottom", tabs_bottom);
		tabs_close_visible = json_get_bool_from_string(config, "tabs_close_visible", tabs_close_visible);

		var term_font_string = json_get_string(config, "term_font", TERM_FONT_DESC);
		term_font = Pango.FontDescription.from_string(term_font_string);
		
		term_fg_color = json_get_string(config, "term_fg_color", term_fg_color);
		term_bg_color = json_get_string(config, "term_bg_color", term_bg_color);
		term_enable_network = json_get_bool_from_string(config, "term_enable_network", term_enable_network);
		term_enable_gui = json_get_bool_from_string(config, "term_enable_gui", term_enable_gui);

		kvm_cpu = json_get_string(config, "kvm_cpu", kvm_cpu);
		kvm_smp = json_get_int_from_string(config, "kvm_smp", kvm_smp);
		kvm_cpu_limit = json_get_int_from_string(config, "kvm_cpu_limit", kvm_cpu_limit);
		kvm_vga = json_get_string(config, "kvm_vga", kvm_vga);
		kvm_mem = json_get_int_from_string(config, "kvm_mem", kvm_mem);
		
		selected_columns = json_get_string(config, "selected_columns", selected_columns);
		selected_columns = selected_columns.replace(" ",""); // remove spaces

		maximise_on_startup = json_get_bool_from_string(config, "maximise_on_startup", maximise_on_startup);
		//single_click_activate = json_get_bool_from_string(config, "single_click_activate", single_click_activate);
		restore_last_session = json_get_bool_from_string(config, "restore_last_session", restore_last_session);
		single_instance_mode = json_get_bool_from_string(config, "single_instance_mode", single_instance_mode);
		minimize_to_tray = json_get_bool_from_string(config, "minimize_to_tray", minimize_to_tray);
		autostart = json_get_bool_from_string(config, "autostart", autostart);

		query_subfolders = json_get_bool_from_string(config, "query_subfolders", query_subfolders);

		confirm_delete = json_get_bool_from_string(config, "confirm_delete", confirm_delete);
		confirm_trash = json_get_bool_from_string(config, "confirm_trash", confirm_trash);

		config.set_string_member("", show_context_menu_disk_usage.to_string());
		config.set_string_member("", show_context_menu_clamav.to_string());
		config.set_string_member("", show_context_menu_archive.to_string());
		config.set_string_member("", show_context_menu_checksum.to_string());
		config.set_string_member("", show_context_menu_kvm.to_string());

		show_context_menu_disk_usage = json_get_bool_from_string(config, "show_context_menu_disk_usage", show_context_menu_disk_usage);
		show_context_menu_clamav = json_get_bool_from_string(config, "show_context_menu_clamav", show_context_menu_clamav);
		show_context_menu_archive = json_get_bool_from_string(config, "show_context_menu_archive", show_context_menu_archive);
		show_context_menu_checksum = json_get_bool_from_string(config, "show_context_menu_checksum", show_context_menu_checksum);
		show_context_menu_kvm = json_get_bool_from_string(config, "show_context_menu_kvm", show_context_menu_kvm);

		overwrite_pdf_split = json_get_bool_from_string(config, "overwrite_pdf_split", overwrite_pdf_split);
		overwrite_pdf_merge = json_get_bool_from_string(config, "overwrite_pdf_merge", overwrite_pdf_merge);
		overwrite_pdf_compress = json_get_bool_from_string(config, "overwrite_pdf_compress", overwrite_pdf_compress);
		overwrite_pdf_uncompress = json_get_bool_from_string(config, "overwrite_pdf_uncompress", overwrite_pdf_uncompress);
		overwrite_pdf_protect = json_get_bool_from_string(config, "overwrite_pdf_protect", overwrite_pdf_protect);
		overwrite_pdf_unprotect = json_get_bool_from_string(config, "overwrite_pdf_unprotect", overwrite_pdf_unprotect);
		overwrite_pdf_decolor = json_get_bool_from_string(config, "overwrite_pdf_decolor", overwrite_pdf_decolor);
		overwrite_pdf_rotate = json_get_bool_from_string(config, "overwrite_pdf_rotate", overwrite_pdf_rotate);
		overwrite_pdf_optimize = json_get_bool_from_string(config, "overwrite_pdf_optimize", overwrite_pdf_optimize);

		overwrite_image_optimize_png = json_get_bool_from_string(config, "overwrite_image_optimize_png", overwrite_image_optimize_png);
		overwrite_image_reduce_jpeg = json_get_bool_from_string(config, "overwrite_image_reduce_jpeg", overwrite_image_reduce_jpeg);
		overwrite_image_resize = json_get_bool_from_string(config, "overwrite_image_resize", overwrite_image_resize);
		overwrite_image_rotate = json_get_bool_from_string(config, "overwrite_image_rotate", overwrite_image_rotate);
		overwrite_image_convert = json_get_bool_from_string(config, "overwrite_image_convert", overwrite_image_convert);
		overwrite_image_decolor = json_get_bool_from_string(config, "overwrite_image_decolor", overwrite_image_decolor);
		overwrite_image_boost_color = json_get_bool_from_string(config, "overwrite_image_boost_color", overwrite_image_boost_color);
		overwrite_image_reduce_color = json_get_bool_from_string(config, "overwrite_image_reduce_color", overwrite_image_reduce_color);

		middlebar_visible = json_get_bool_from_string(config, "middlebar_visible", middlebar_visible);
		sidebar_visible = json_get_bool_from_string(config, "sidebar_visible", sidebar_visible);
		sidebar_dark = json_get_bool_from_string(config, "sidebar_dark", sidebar_dark);
		sidebar_places = json_get_bool_from_string(config, "sidebar_places", sidebar_places);
		sidebar_bookmarks = json_get_bool_from_string(config, "sidebar_bookmarks", sidebar_bookmarks);
		sidebar_devices = json_get_bool_from_string(config, "sidebar_devices", sidebar_devices);
		sidebar_position = json_get_int_from_string(config, "sidebar_position", sidebar_position);
		sidebar_action_button = json_get_bool_from_string(config, "sidebar_action_button", sidebar_action_button);
		sidebar_collapsed_sections = json_get_string(config, "sidebar_collapsed_sections", sidebar_collapsed_sections);
		
		propbar_visible = json_get_bool_from_string(config, "propbar_visible", propbar_visible);
		propbar_position = json_get_int_from_string(config, "propbar_position", propbar_position);
		
		dm_hide_fs = json_get_bool_from_string(config, "dm_hide_fs", dm_hide_fs);
		dm_hide_mp = json_get_bool_from_string(config, "dm_hide_mp", dm_hide_mp);
		dm_hide_size = json_get_bool_from_string(config, "dm_hide_size", dm_hide_size);
		dm_hide_header = json_get_bool_from_string(config, "dm_hide_header", dm_hide_header);
		
		dm_width = json_get_int_from_string(config, "dm_width", dm_width);
		dm_height = json_get_int_from_string(config, "dm_height", dm_height);
		
		load_folder_selections();

		load_app_config_finish();

		log_debug(_("App config loaded") + ": '%s'".printf(this.app_conf_path));

		set_numeric_locale(""); // reset numeric locale
	}

	private void load_app_config_finish(){
		
		GtkBookmark.load_bookmarks(user_name, true);
		
		init_gtk_themes();
	}
	
	private void init_gtk_themes(){

		log_debug("Main(): gtk_theme: user: %s".printf(user_name_effective));
		
		GtkTheme.query(user_name);

		if (!GtkTheme.has_theme("Arc-Darker-Polo")){
				
			log_debug("Main(): gtk_theme: not_found: Arc-Darker-Polo");
			log_debug("Main(): gtk_theme: installing: Arc-Darker-Polo");
			
			string sh_file = "/usr/share/polo/files/gtk-theme/install-gtk-theme";
			Posix.system(sh_file);
			
			GtkTheme.query(user_name_effective); // requery
		}
		else{
			log_debug("Main(): gtk_theme: found: Arc-Darker-Polo");
		}

		if (gtk_theme.length == 0){
			
			log_debug("Main(): gtk_theme: none_selected");
			GtkTheme.set_gtk_theme_preferred();
			gtk_theme = GtkTheme.get_gtk_theme();
			log_debug("Main(): gtk_theme: applied: Arc-Darker-Polo");
		}
		else {
			GtkTheme.set_gtk_theme(gtk_theme);
			log_debug("Main(): gtk_theme: applied: %s".printf(gtk_theme));
		}
	}
	
	public void increment_run_count() {
		run_count++;
	}

	public bool check_donation_trigger() {
		log_debug("run_count: %d".printf(run_count));
		return !donation_plugins_found && array_contains(run_count, donation_triggers);
	}

	public bool first_run_after_update(){

		if ((app_version_in_config.length > 0) && (app_version_in_config != AppVersion)){
			save_app_config(); // update new version in config file
			return true;
		}

		return false;
	}

	public void open_changelog_webpage(){
		
		string username = "";
		if (get_user_id_effective() == 0){
			username = get_username();
		}

		string uri = "https://github.com/teejee2008/polo/wiki/Polo-v%s".printf(AppVersion.replace(" ","-"));

		if (AppVersion == AppWikiVersion){
			xdg_open(uri, username);
		}
	}
	
	public void save_folder_selections() {

		var config = new Json.Object();

		//if (archiver != null){
		//	config = archiver.to_json();
		//}

		set_numeric_locale("C"); // switch numeric locale

		config.set_int_member("format-version", (int64) APP_CONFIG_FOLDERS_FORMAT_VERSION);

		var included = new Json.Array();
		foreach(var path in mediaview_include){
			included.add_string_element(path);
		}
		config.set_array_member("mediaview_include", included);

		var excluded = new Json.Array();
		foreach(var path in mediaview_exclude){
			excluded.add_string_element(path);
		}
		config.set_array_member("mediaview_exclude", excluded);

		var json = new Json.Generator();
		json.pretty = true;
		json.indent = 2;
		var node = new Json.Node(NodeType.OBJECT);
		node.set_object(config);
		json.set_root(node);

		try {
			json.to_file(this.app_conf_folders);
		} catch (Error e) {
			log_error (e.message);
		}

		set_numeric_locale(""); // reset numeric locale

		log_debug("\n" + _("App config saved") + ": '%s'".printf(app_conf_folders));
	}

	public void load_folder_selections() {

		var f = File.new_for_path(app_conf_folders);
		if (!f.query_exists()) {
			//first_run = true; // don't set flag here
			return;
		}

		var parser = new Json.Parser();
		try {
			parser.load_from_file(this.app_conf_folders);
		}
		catch (Error e) {
			log_error (e.message);
		}

		var node = parser.get_root();
		var config = node.get_object();

		if (format_is_obsolete(config, Main.APP_CONFIG_FOLDERS_FORMAT_VERSION)){
			//first_run = true; // don't set
			return;
		}
		
		set_numeric_locale("C"); // switch numeric locale

		mediaview_include = json_get_array(config, "mediaview_include", mediaview_include);

		mediaview_exclude = json_get_array(config, "mediaview_exclude", mediaview_exclude);

		log_debug(_("App config loaded") + ": '%s'".printf(this.app_conf_folders));

		set_numeric_locale(""); // reset numeric locale
	}


	public void save_archive_selections(ArchiveTask task) {

		var config = new Json.Object();
		
		set_numeric_locale("C"); // switch numeric locale

		config.set_int_member("format-version", (int64) APP_CONFIG_ARCHIVE_FORMAT_VERSION);

		// begin ---------------------------

		config.set_string_member("format", task.format);
		config.set_string_member("method", task.method);
		config.set_string_member("level", task.level);
		config.set_string_member("dict_size", task.dict_size);
		config.set_string_member("word_size", task.word_size);
		config.set_string_member("block_size", task.block_size);
		config.set_string_member("passes", task.passes);
		config.set_string_member("encrypt_header", task.encrypt_header.to_string());
		config.set_string_member("encrypt_method", task.encrypt_method);
		//config.set_string_member("password", task.password);
		config.set_string_member("split_mb", task.split_mb);

		// end ---------------------------

		var json = new Json.Generator();
		json.pretty = true;
		json.indent = 2;
		var node = new Json.Node(NodeType.OBJECT);
		node.set_object(config);
		json.set_root(node);

		try {
			json.to_file(this.app_conf_archive);
		} catch (Error e) {
			log_error (e.message);
		}

		set_numeric_locale(""); // reset numeric locale

		log_debug("\n" + _("App config saved") + ": '%s'".printf(app_conf_archive));
	}

	public void load_archive_selections(ArchiveTask task) {

		var f = File.new_for_path(app_conf_archive);
		if (!f.query_exists()) {
			//first_run = true; // don't set flag here
			return;
		}

		var parser = new Json.Parser();
		try {
			parser.load_from_file(this.app_conf_archive);
		}
		catch (Error e) {
			log_error (e.message);
		}

		var node = parser.get_root();
		var config = node.get_object();

		if (format_is_obsolete(config, Main.APP_CONFIG_ARCHIVE_FORMAT_VERSION)){
			//first_run = true; // don't set
			return;
		}
		
		set_numeric_locale("C"); // switch numeric locale

		// begin ---------------------------

		task.format = json_get_string(config, "format", task.format);
		task.method = json_get_string(config, "method", task.method);
		task.level = json_get_string(config, "level", task.level);
		task.dict_size = json_get_string(config, "dict_size", task.dict_size);
		task.word_size = json_get_string(config, "word_size", task.word_size);
		task.block_size = json_get_string(config, "block_size", task.block_size);
		task.passes = json_get_string(config, "passes", task.passes);
		task.encrypt_header = json_get_bool_from_string(config, "encrypt_header", task.encrypt_header);
		task.encrypt_method = json_get_string(config, "encrypt_method", task.encrypt_method);
		task.split_mb = json_get_string(config, "split_mb", task.split_mb);
		
		// end ---------------------------
		
		log_debug(_("App config loaded") + ": '%s'".printf(this.app_conf_archive));

		set_numeric_locale(""); // reset numeric locale
	}

	public static bool format_is_obsolete(Json.Object node, int64 current_version){
		
		bool unsupported_format = false;
		
		if (node.has_member("format-version")){
			
			int format_version = (int) node.get_int_member("format-version");
			
			if (format_version < current_version){
				unsupported_format = true;
			}
		}
		else{
			unsupported_format = true;
		}

		return unsupported_format;
	}

	/* Common */
	
	public string create_log_dir() {
		string log_dir = "%s/.local/logs/%s".printf(user_home, AppShortName);
		dir_create(log_dir);
		return log_dir;
	}

	public void exit_app() {

		save_app_config();

		if (session_lock.lock_acquired){
			session_lock.remove();
		}

		try {
			//delete temporary files
			var f = File.new_for_path(temp_dir);
			if (f.query_exists()) {
				f.delete();
			}
		}
		catch (Error e) {
			log_error (e.message);
		}

		log_msg(_("Exiting Application"));
	}

	public Json.Object get_kvm_config(){
		var config = new Json.Object();
		config.set_string_member("kvm_cpu", kvm_cpu);
		config.set_string_member("kvm_smp", kvm_smp.to_string());
		config.set_string_member("kvm_vga", kvm_vga);
		config.set_string_member("kvm_mem", kvm_mem.to_string());
		config.set_string_member("kvm_smb", App.user_dirs.user_public);
		return config;
	}

	public int exec_admin(string _cmd, out string std_out, out string std_err){

		int status = -1;
		std_out = "";
		std_err = "";
		
		if (admin_shell == null){

			string admin_prefix = "";

			if (get_user_id_effective() != 0){

				if (cmd_exists("pkexec")){
					
					admin_prefix = "%s ".printf("pkexec");
				}
				else if (cmd_exists("gksu")){
					admin_prefix = "%s ".printf("gksu");
				}
				//else if (cmd_exists("gksudo")){
				//	admin_prefix = "%s ".printf("gksudo");
				//}
				else{
					gtk_messagebox(_("Missing Dependencies"), _("'pkexec' or 'gksu' is needed for executing admin operations. Install required packages and try again."), main_window, true);
				}
			}
			else{
				admin_prefix = ""; // not needed
			}

			admin_shell = new TermBox(null);
			admin_shell.start_shell();

			//var children = admin_shell.get_child_processes();
			//log_debug("children.size: %d".printf(children.length));

			admin_shell.feed_command(admin_prefix + "bash");
			sleep(200);

			//children = admin_shell.get_child_processes();
			//log_debug("children.size: %d".printf(children.length));

			while (admin_shell.waiting_for_admin_prompt()){

				//log_debug("waiting for pkexec");
				sleep(1000);
				gtk_do_events();
			}
		}

		if (!admin_shell.has_root_bash()){
			
			admin_shell.feed_command("exit");
			admin_shell = null;
			
			string msg = _("Failed to execute operation as admin");
			log_error(msg);
			std_err = msg;
			return 1;
		}
		
		string cmd = _cmd;
		string tmp_stdout = get_temp_file_path();
		string tmp_stderr = get_temp_file_path();
		string tmp_status = get_temp_file_path();

		cmd += " >'%s' ".printf(escape_single_quote(tmp_stdout));
		cmd += " 2>'%s' ".printf(escape_single_quote(tmp_stderr));
		cmd += " ; echo $? > '%s'".printf(escape_single_quote(tmp_status));

		log_debug("admin_cmd: " + cmd);

		admin_shell.feed_command(cmd);

		int wait_secs = 0;
		
		while (!file_exists(tmp_status)){
			
			gtk_do_events();
			
			sleep(1000);
			
			wait_secs++;
			if (wait_secs > 30){
				break;
			}
		}

		if (file_exists(tmp_status)){
			status = int.parse(file_read(tmp_status));
		}

		if (file_exists(tmp_stdout)){
			std_out = file_read(tmp_stdout);
		}

		if (file_exists(tmp_stderr)){
			std_err = file_read(tmp_stderr);
		}

		return status;
	}
	
	/* Core */

	public static Gee.ArrayList<Device> get_devices(){

		var list = new Gee.ArrayList<Device>();

		foreach(var dev in Device.get_devices()){

			if ((dev.fstype.length == 0) && (dev.type == "part")){
				// partition with uknown filsystem
				continue;
			}
			else if (dev.is_encrypted_partition && dev.has_children){
				// unlocked LUKS partition
				continue;
			}
			else if (dev.is_snap_volume || dev.is_swap_volume){
				// snap loop device, or swap volume
				continue;
			}
			else if (dev.size_bytes < 100 * KB){
				// very small partition, ???
				continue;
			}
			else{
				list.add(dev);
			}
		}

		return list;
	}
}

public enum AppMode {
	NEW,
	CREATE,
	OPEN,
	TEST,
	EXTRACT
}

public enum PanelLayout{
	SINGLE = 1,
	DUAL_VERTICAL = 2,
	DUAL_HORIZONTAL = 3,
	QUAD = 4,
	CUSTOM = 5
}

public enum ViewMode{
	LIST = 1,
	ICONS = 2,
	TILES = 3,
	MEDIA = 4
}
