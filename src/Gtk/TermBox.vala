/*
 * TermBox.vala
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

public class TermBox : Gtk.Box {

	// parents
	private FileViewPane _pane;

	private FileViewList? view{
		get{
			return (pane == null) ? null : pane.view;
		}
	}

	private FileViewPane? pane {
		get{
			if (_pane != null){
				return _pane;
			}
			else{
				return App.main_window.active_pane;
			}
		}
	}

	private LayoutPanel? panel {
		get{
			return (pane == null) ? null : pane.panel;
		}
	}

	private MainWindow window{
		get{
			return App.main_window;
		}
	}
	
	private Vte.Terminal term;
	private Pid child_pid;
	private bool cancelled = false;
	private bool is_running = false;
	private TermContextMenu menu_term;

	public const int DEF_FONT_SIZE = 11;
	public const string DEF_COLOR_FG = "#DCDCDC";
	public const string DEF_COLOR_BG = "#2C2C2C";
	
	public TermBox(FileViewPane parent_pane){
		//base(Gtk.Orientation.VERTICAL, 6); // issue with vala
		Object(orientation: Gtk.Orientation.VERTICAL, spacing: 0); // work-around

		log_debug("TermBox(): ----------------------------");

		//var timer = timer_start();
		
		_pane = parent_pane;
		
		init_ui();

		this.set_no_show_all(true);

		//log_trace("tab initialized: %s".printf(timer_elapsed_string(timer)));

		log_debug("TermBox(): created --------------------");
	}

	private void init_ui(){

		log_debug("TermBox: init_ui()");

		//sw_ppa
		var scrolled = new Gtk.ScrolledWindow(null, null);
		scrolled.set_shadow_type (ShadowType.ETCHED_IN);
		scrolled.expand = true;
		this.add(scrolled);

		term = new Vte.Terminal();
		term.expand = true;
		scrolled.add(term);
		
		//#if VTE_291
		
		term.input_enabled = true;
		term.backspace_binding = Vte.EraseBinding.AUTO;
		term.cursor_blink_mode = Vte.CursorBlinkMode.SYSTEM;
		term.cursor_shape = Vte.CursorShape.UNDERLINE;
		term.rewrap_on_resize = true;
		term.allow_bold = false;
		//#endif
		
		term.scroll_on_keystroke = true;
		term.scroll_on_output = true;
		term.scrollback_lines = 100000;

		set_font_desc(App.term_font);
		set_color_foreground(App.term_fg_color);
		set_color_background(App.term_bg_color);

		//set_color_foreground("#000000FF");
		//set_color_background("#FFFFFFFF");

		// connect signal for shift+F10
        term.popup_menu.connect(() => {
			//if (current_item == null) { return false; }
			menu_term = new TermContextMenu(pane);
			return menu_term.show_menu(null);
		});

        // connect signal for right-click
		term.button_press_event.connect((w, event) => {

			window.active_pane = pane;
			
			window.update_accelerators_for_terminal();

			pane.selection_bar.close_panel();

			term.grab_focus();
			
			if (event.button == 3) {
				menu_term = new TermContextMenu(pane);
				return menu_term.show_menu(event);
			}

			return false;
		});
	}

	public void start_shell(){

		log_debug("TermBox: start_shell()");
		
		string[] argv = new string[1];
		argv[0] = get_cmd_path(App.shell_default);

		if (!cmd_exists(App.shell_default)){
			argv[0] = get_cmd_path("sh");
		}

		string[] env = Environ.get();
		
		try{

			is_running = true;
			
			term.spawn_sync(
				Vte.PtyFlags.DEFAULT, //pty_flags
				App.user_home, //working_directory
				argv, //argv
				env, //env
				GLib.SpawnFlags.SEARCH_PATH, //spawn_flags
				null, //child_setup
				out child_pid,
				null
			);

			term.child_exited.connect((status)=>{
				log_debug("TermBox: child_exited(): pid=%d, status=%d".printf(child_pid, status));
				if (!cancelled){
					start_shell();
				}
			});

			reset();

			log_debug("TermBox: start_shell(): started");
		}
		catch (Error e) {
			log_error (e.message);
		}
	}

	public void exit_shell(){
		cancelled = true;
		feed_command("exit");
	}

	public void terminate_child(){
		//btn_cancel.sensitive = false;
		//process_quit(child_pid);
	}

	public bool has_running_process {
		get{
			var children = get_process_children(child_pid);
			return (children.length > 0);
		}
	}

	public int get_child_pid() {
		return child_pid;
	}

	public void feed_command(string command, bool newline = true){
		string txt = command;
		if (newline){
			txt += "\n";
		}
		term.feed_child(txt, -1);
	}

	public void refresh(){

		log_debug("TermBox: refresh()");
		
		if (this.visible && !is_running){
			start_shell();
		}
	}

	public void toggle(){

		log_debug("TermBox: toggle()");
		
		if (this.visible){
			gtk_hide(this);
			window.update_accelerators_for_active_pane();
		}
		else{
			gtk_show(this);

			pane.unmaximize_terminal();
			
			refresh();
			
			if (view.is_normal_directory){
				change_directory(view.current_item.file_path);
				reset();
			}

			term.grab_focus();

			window.update_accelerators_for_terminal();
		}
	}

	public void change_directory(string dir_path){

		//if (has_running_process){
		//	show_running_process_message();
		//	return;
		//}
		
		log_debug("TermBox: change_directory()");
		
		feed_command("cd '%s'".printf(escape_single_quote(dir_path)));
	}

	private void show_running_process_message(){
		// TODO: Add check to ignore background process
		gtk_messagebox(_("Terminal is busy"),
			_("This action cannot be executed while a process is running"), window, true);
	}

	public void copy(){

		log_debug("TermBox: copy()");
		
		term.copy_primary();

		Gdk.Display display = this.get_display ();
		var clipboard = Gtk.Clipboard.get_for_display (display, Gdk.SELECTION_PRIMARY);
		string txt = clipboard.wait_for_text();
		if (txt != null){
			clipboard = Gtk.Clipboard.get_for_display (display, Gdk.SELECTION_CLIPBOARD);
			clipboard.set_text(txt, -1);
		}
	}

	public void paste(){

		log_debug("TermBox: paste()");
		
		Gdk.Display display = this.get_display ();
		Gtk.Clipboard clipboard = Gtk.Clipboard.get_for_display (display, Gdk.SELECTION_CLIPBOARD);
		string txt = clipboard.wait_for_text();
		if (txt != null){
			feed_command(txt, false);
		}
	}

	public void reset(){

		log_debug("TermBox: reset()");
		
		feed_command("tput reset");
	}

	public void open_settings(){

		log_debug("TermBox: open_settings()");
		
		feed_command("fish_config");
	}

	public void set_font_size(int size_pts){
		term.font_desc = Pango.FontDescription.from_string("normal %d".printf(size_pts));
	}

	public void set_font_desc(Pango.FontDescription font_desc){
		term.set_font(font_desc);
	}

	public void set_color_foreground(string color){

		log_debug("TermBox: set_color_foreground(): %s".printf(color));
		
		var rgba = Gdk.RGBA();
		rgba.parse(color);
		term.set_color_foreground(rgba);
	}
	
	public void set_color_background(string color){
		
		log_debug("TermBox: set_color_background(): %s".printf(color));
		
		var rgba = Gdk.RGBA();
		rgba.parse(color);
		term.set_color_background(rgba);
	}

	public void set_defaults(){
		set_font_size(DEF_FONT_SIZE);
		set_color_foreground(DEF_COLOR_FG);
		set_color_background(DEF_COLOR_BG);
	}

	public void chroot(string path){

		var cmd = "sudo polo-chroot '%s' \n".printf(
			//App.term_enable_network ? "--enable-network" : "",
			//App.term_enable_gui ? "--enable-gui" : "",
			escape_single_quote(path));
		
		feed_command(cmd);
	}

	public void unchroot(string path){

		feed_command("exit");

		foreach(string txt in new string[] { "dev", "dev/pts", "proc", "run", "sys" }){
			string dest = path_combine(path, txt);
			var cmd = "sudo umount '%s'".printf(escape_single_quote(dest));
			feed_command(cmd);
		}
	}
}

