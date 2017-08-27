/*
 * Sidebar.vala
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

public class Statusbar : Gtk.Box {

	// reference properties ----------

	private MainWindow window{
		get { return App.main_window; }
	}
	
	FileViewPane _pane;
	private FileViewPane? pane {
		get{
			if (_pane != null){ return _pane; }
			else { return window.active_pane; }
		}
	}

	private FileViewList? view{
		get{ return (pane == null) ? null : pane.view; }
	}

	private LayoutPanel? panel {
		get { return (pane == null) ? null : pane.panel; }
	}

	// -------------------------------
	
	private Gtk.Label lbl_file_count;
	private Gtk.Label lbl_dir_count;
	private Gtk.Label lbl_size;
	private Gtk.Label lbl_hidden;
	private Gtk.Label lbl_hidden_count;
	private Gtk.Label lbl_progress;
	private Gtk.Spinner spin_progress;
	private Gtk.Label lbl_fs_free;
	private Gtk.Label lbl_fs_read_only;
	private Gtk.Label lbl_fs_type;
	private Gtk.Image img_sidebar_toggle;
	private Gtk.DrawingArea fs_bar;
	private Gtk.EventBox ebox_left_toggle;
	private Gtk.EventBox ebox_filter;
	private Gtk.EventBox ebox_terminal;
	
	private double fs_bar_value = 0;

	private bool is_global{
		get{
			return (_pane == null);
		}
	}

	// contruct

	public Statusbar(FileViewPane? parent_pane){
		//base(Gtk.Orientation.VERTICAL, 6); // issue with vala
		Object(orientation: Gtk.Orientation.HORIZONTAL, spacing: 6); // work-around
		margin = 6;

		log_debug("Statusbar()");

		_pane = parent_pane;

		init_statusbar();

		this.set_no_show_all(true);
	}

	private void init_statusbar() {

		add_sidebar_toggle();

		add_dir_count();

		add_file_count();

		add_hidden_count();

		add_size();

		add_progress_spinner();

		add_spacer();

		add_filesystem_free();

		add_filesystem_type();

		add_filesystem_read_only();

		//add_hide_toggle();

		//add_dual_pane_toggle();

		add_filter_toggle();
		
		add_terminal_toggle();

		//add_style_toggle();
	}

	private void add_dir_count(){

		var separator = new Gtk.Separator(Gtk.Orientation.VERTICAL);
		add(separator);
		
		var img = gtk_image_from_pixbuf(IconManager.generic_icon_directory(16));
		add(img);
		
		var label = new Gtk.Label ("");
		label.xalign = 0.0f;
		add(label);
		lbl_dir_count = label;

		//label = new Gtk.Label (_("dirs"));
		//label.xalign = 0.0f;
		//add(label);

		lbl_dir_count.notify["visible"].connect(()=>{
			label.visible = lbl_dir_count.visible;
			//separator.visible = lbl_dir_count.visible;
		});
	}

	private void add_file_count(){
		
		var separator = new Gtk.Separator(Gtk.Orientation.VERTICAL);
		add(separator);

		var img = gtk_image_from_pixbuf(IconManager.generic_icon_file(16));
		add(img);
		
		var label = new Gtk.Label ("");
		label.xalign = 0.0f;
		add(label);
		lbl_file_count = label;

		//label = new Gtk.Label(_("files"));
		//label.xalign = 0.0f;
		//add(label);

		lbl_file_count.notify["visible"].connect(()=>{
			label.visible = lbl_file_count.visible;
			separator.visible = lbl_file_count.visible;
		});
	}

	private void add_hidden_count(){

		var separator = new Gtk.Separator(Gtk.Orientation.VERTICAL);
		add(separator);

		var label = new Gtk.Label ("");
		label.xalign = 0.0f;
		label.set_use_markup(true);
		lbl_hidden_count = label;
		
		var ebox_count = new Gtk.EventBox();
		ebox_count.add(lbl_hidden_count);
		add(ebox_count);

		ebox_count.set_tooltip_text(_("Show hidden items"));

		label = new Gtk.Label(_("hidden"));
		label.xalign = 0.0f;
		label.set_use_markup(true);
		add(label);
		lbl_hidden = label;
		
		lbl_hidden_count.notify["visible"].connect(()=>{
			label.visible = lbl_hidden_count.visible;
			separator.visible = lbl_hidden_count.visible;
		});

		// set hand cursor
		if (ebox_count.get_realized()){
			ebox_count.get_window().set_cursor(new Gdk.Cursor(Gdk.CursorType.HAND1));
		}
		else{
			ebox_count.realize.connect(()=>{
				ebox_count.get_window().set_cursor(new Gdk.Cursor(Gdk.CursorType.HAND1));
			});
		}

		ebox_count.button_press_event.connect((event)=>{
			view.show_hidden();
			return true;
		});
	}

	private void add_size(){

		var separator = new Gtk.Separator(Gtk.Orientation.VERTICAL);
		add(separator);

		var label = new Gtk.Label ("");
		label.xalign = 0.0f;
		add(label);
		lbl_size = label;

		lbl_size.notify["visible"].connect(()=>{
			separator.visible = lbl_hidden_count.visible;
		});
	}

	private void add_progress_spinner(){

		var separator = new Gtk.Separator(Gtk.Orientation.VERTICAL);
		add(separator);

		var spinner = new Gtk.Spinner();
		spinner.start();
		add(spinner);
		spin_progress = spinner;

		var label = new Gtk.Label("");
		label.xalign = 0.0f;
		add(label);
		lbl_progress = label;

		lbl_progress.notify["visible"].connect(()=>{
			spinner.visible = lbl_progress.visible;
			separator.visible = lbl_progress.visible;
		});

		gtk_hide(separator);
		gtk_hide(spinner);
		gtk_hide(lbl_progress);
	}

	private void add_filesystem_free(){

		//var separator = new Gtk.Separator(Gtk.Orientation.VERTICAL);
		//add(separator);

		var label = new Gtk.Label ("");
		label.xalign = 0.0f;
		add(label);
		lbl_fs_free = label;

		label = new Gtk.Label(_("free"));
		label.xalign = 0.0f;
		add(label);

		add_fs_bar();

		lbl_fs_free.notify["visible"].connect(()=>{
			label.visible = lbl_fs_free.visible;
			//separator.visible = lbl_fs_free.visible;
			fs_bar.visible = lbl_fs_free.visible;
		});
	}

	private void add_filesystem_read_only(){

		//var separator = new Gtk.Separator(Gtk.Orientation.VERTICAL);
		//add(separator);

		var label = new Gtk.Label ("");
		label.xalign = 0.0f;
		add(label);
		lbl_fs_read_only = label;

		//lbl_fs_read_only.notify["visible"].connect(()=>{
		//	separator.visible = lbl_fs_read_only.visible;
		//});
	}

	private void add_filesystem_type(){

		//var separator = new Gtk.Separator(Gtk.Orientation.VERTICAL);
		//add(separator);

		var label = new Gtk.Label ("");
		label.xalign = 0.0f;
		add(label);
		lbl_fs_type = label;

		//lbl_fs_type.notify["visible"].connect(()=>{
		//	separator.visible = lbl_fs_type.visible;
		//});
	}

	private void add_fs_bar(){
		fs_bar = new Gtk.DrawingArea();
		fs_bar.set_size_request(50, -1);
		add(fs_bar);

		var color_white = Gdk.RGBA();
		color_white.parse("white");
		color_white.alpha = 1.0;

		var color_black = Gdk.RGBA();
		color_black.parse("#606060");
		color_black.alpha = 1.0;

		var color_red = Gdk.RGBA();
		color_red.parse("red");
		color_red.alpha = 1.0;

		var color_blue_200 = Gdk.RGBA();
		color_blue_200.parse("#90CAF9");
		color_blue_200.alpha = 1.0;

		var color_green_300 = Gdk.RGBA();
		color_green_300.parse("#81C784");
		color_green_300.alpha = 1.0;

		var color_yellow_300 = Gdk.RGBA();
		color_yellow_300.parse("#FFA500");
		color_yellow_300.alpha = 1.0;

		var color_red_300 = Gdk.RGBA();
		color_red_300.parse("#E57373");
		color_red_300.alpha = 1.0;

		Gdk.RGBA color_bar = color_green_300;

		int line_width = 2;

		fs_bar.draw.connect ((context) => {
			int w = fs_bar.get_allocated_width();
			int h = fs_bar.get_allocated_height();

			if (view.current_item == null){
				return true;
			}

			double percent = (view.current_item.filesystem_used * 100.0) / view.current_item.filesystem_size;
			int x_level = (int) ((w * percent) / 100.00);

			string tt = "%8s: %10s".printf(_("Size"), format_file_size(view.current_item.filesystem_size));

			tt += "\n%8s: %10s (%.0f%%)".printf(_("Used"),
				format_file_size(view.current_item.filesystem_used),
				(view.current_item.filesystem_used * 100.0) / view.current_item.filesystem_size
				);

			tt += "\n%8s: %10s (%.0f%%)".printf(_("Free"),
				format_file_size(view.current_item.filesystem_free),
				(view.current_item.filesystem_free * 100.0) / view.current_item.filesystem_size
				);

			fs_bar.set_tooltip_markup("<tt>%s</tt>".printf(tt));

			if (percent >= 75){
				color_bar = color_red_300;
			}
			else if (percent >= 50){
				color_bar = color_yellow_300;
			}
			else{
				color_bar = color_green_300;
			}

			// origin is top_left

			Gdk.cairo_set_source_rgba (context, color_black);
			context.set_line_width (line_width);

			context.rectangle(0, 0, w, h);
			context.stroke();

			//context.set_line_width (1); // 1
			//context.move_to (x_level + line_width + 2, 0);
			//context.line_to (x_level + line_width + 2, h);
			//context.stroke();

			Gdk.cairo_set_source_rgba (context, color_bar);
			context.set_line_width (line_width);

			context.rectangle(line_width, line_width, x_level, h - (line_width * 2));
			context.fill();

			return true;
		});
	}

	private void add_spacer(){
		var label = new Gtk.Label("");
		label.xalign = 0.0f;
		label.hexpand = true;
		add(label);
	}

	private void add_sidebar_toggle(){

		img_sidebar_toggle = new Gtk.Image();

		var ebox = new Gtk.EventBox();
		ebox.add(img_sidebar_toggle);
		add(ebox);
		ebox_left_toggle = ebox;

		if (is_global || panel.is_left_panel){
			img_sidebar_toggle.pixbuf = IconManager.lookup("sidebar-show",16);
			ebox.set_tooltip_text(_("Toggle Sidebar"));
		}
		else{
			img_sidebar_toggle.pixbuf = IconManager.lookup("middlebar-show",16);
			ebox.set_tooltip_text(_("Toggle Middle Toolbar"));
		}

		// set hand cursor
		if (ebox.get_realized()){
			ebox.get_window().set_cursor(new Gdk.Cursor(Gdk.CursorType.HAND1));
		}
		else{
			ebox.realize.connect(()=>{
				ebox.get_window().set_cursor(new Gdk.Cursor(Gdk.CursorType.HAND1));
			});
		}

		ebox.button_press_event.connect((event)=>{

			if (is_global || panel.is_left_panel){
				App.sidebar_visible = !App.sidebar_visible;
				window.sidebar.refresh_visibility();
			}
			else{
				App.middlebar_visible = !App.middlebar_visible;
				window.layout_box.middlebar.refresh_visibility();
			}

			return true;
		});
	}

	private void add_terminal_toggle(){

		var img = IconManager.lookup_image("terminal",16);
		img.set_tooltip_text(_("Toggle terminal panel"));
		//img.margin_left = 6;
		//img.margin_right = 6;

		var ebox = new Gtk.EventBox();
		ebox.add(img);
		add(ebox);
		ebox_terminal = ebox;
		
		// set hand cursor
		if (ebox.get_realized()){
			ebox.get_window().set_cursor(new Gdk.Cursor(Gdk.CursorType.HAND1));
		}
		else{
			ebox.realize.connect(()=>{
				ebox.get_window().set_cursor(new Gdk.Cursor(Gdk.CursorType.HAND1));
			});
		}

		ebox.button_press_event.connect((event)=>{

			pane.terminal.toggle();

			return true;
		});
	}

	private void add_filter_toggle(){

		var img = IconManager.lookup_image("view-filter",16);
		img.set_tooltip_text(_("Filter Items"));
		//img.margin_left = 6;
		//img.margin_right = 6;

		var ebox = new Gtk.EventBox();
		ebox.add(img);
		add(ebox);
		ebox_filter = ebox;	
		
		// set hand cursor
		if (ebox.get_realized()){
			ebox.get_window().set_cursor(new Gdk.Cursor(Gdk.CursorType.HAND1));
		}
		else{
			ebox.realize.connect(()=>{
				ebox.get_window().set_cursor(new Gdk.Cursor(Gdk.CursorType.HAND1));
			});
		}

		ebox.button_press_event.connect((event)=>{

			pane.selection_bar.toggle(true);

			return true;
		});
	}

	// refresh

	public void refresh(){

		log_debug("Statusbar: refresh()");

		refresh_visibility();

		refresh_for_active_pane();

		refresh_for_layout_change();
	}

	public void refresh_visibility(){

		log_debug("Statusbar: refresh_visibility()");

		if ((this.is_global && App.statusbar_unified) || (!this.is_global && !App.statusbar_unified)){
			this.set_no_show_all(false);
			this.show_all();
		}
		else{
			this.set_no_show_all(true);
			this.hide();
		}
	}

	public void refresh_for_active_pane(){

		log_debug("Statusbar: refresh_for_active_pane()");

		if ((panel != null) && panel.visible){
			refresh_summary();
			refresh_usage_bar();
		}
	}

	public void refresh_for_layout_change(){

		log_debug("Statusbar: refresh_for_layout_change()");

		if (window == null){ return; }

		bool show_item = false;

		if (is_global){
			show_item = true;
		}
		else{
			switch (window.layout_box.get_panel_layout()){
			case PanelLayout.SINGLE:
				if (panel.is_left_panel && panel.is_top_panel){
					show_item = true;
				}
				break;
			case PanelLayout.DUAL_VERTICAL:
				if ((panel.is_left_panel || panel.is_right_panel) && panel.is_top_panel){
					show_item = true;
				}
				break;
			case PanelLayout.DUAL_HORIZONTAL:
			case PanelLayout.QUAD:
				if (panel.is_left_panel && panel.is_bottom_panel){
					show_item = true;
				}
				break;
			}
		}

		if (show_item){
			gtk_show(ebox_left_toggle);
		}
		else{
			gtk_hide(ebox_left_toggle);
		}
	}

	public void refresh_summary(string prefix = "") {

		log_debug("Statusbar: set_statusbar_summary()");

		//lbl_statusbar.label = "%ld files, %ld dirs, %s size".printf(App.archive.file_count_total,App.archive.dir_count_total,format_file_size(App.archive.byte_count_total));

		if ((view == null) || (view.current_item == null)){
			set_empty();
			return;
		}

		refresh_selection_counts();

		if (view.show_hidden_files){
			lbl_hidden_count.label = "0";
			//lbl_hidden.label = "%s".printf(_("hidden"));
		}
		else{
			lbl_hidden_count.label = "<span weight=\"bold\">%'ld</span>".printf(view.current_item.hidden_count);
			//lbl_hidden.label = "<span weight=\"bold\">%s</span>".printf(_("hidden"));
		}
		
		//lbl_hidden_count.visible = (view.current_item.hidden_count > 0);

		if (view.current_item.is_trash){
			lbl_size.label = "%s".printf(App.trashcan.size_formatted);
			lbl_size.visible = true;
		}
		else{
			lbl_size.visible = false;
		}

		lbl_fs_free.label = "%s".printf(format_file_size(view.current_item.filesystem_free));
		lbl_fs_free.visible = (view.current_item.filesystem_free > 0);

		var dev = view.current_item.get_device();
		
		if (dev != null){
			log_debug("file_item is on device: %s".printf(dev.device));

			if ((view.current_item.filesystem_type != null) && (view.current_item.filesystem_type != "ext3/ext4")){
				lbl_fs_type.label = "%s".printf(view.current_item.filesystem_type); // prefer this
			}
			else{
				lbl_fs_type.label = "%s".printf(dev.fstype); // not correct for tmpfs paths
			}
		}
		else{
			if (view.current_item.filesystem_type != null){
				lbl_fs_type.label = "%s".printf(view.current_item.filesystem_type);  // prefer this
			}
			else{
				lbl_fs_type.label = "";
			}
		}
		
		lbl_fs_type.visible = (lbl_fs_type.label.length > 0);

		lbl_fs_read_only.label = "%s".printf(view.current_item.filesystem_read_only ? "ReadOnly" : "");
		lbl_fs_read_only.visible = (lbl_fs_read_only.label.length > 0);

		ebox_filter.visible = view.current_item.is_local;
		ebox_terminal.visible = view.current_item.is_local;
		
		//lbl_fs_read_only

		/*if (pane.view.current_item.is_archive){
			var arch = (ArchiveFile) pane.view.current_item;

			if (arch.size > 0) {
				txt += " | Size: %s".printf(format_file_size(arch.size));
			}

			if (arch.file_path.length > 0) {
				txt += " | Packed: %s".printf(format_file_size(arch.archive_size));
			}

			if (arch.archive_is_encrypted) {
				txt += " | Encrypted";
			}

			if (arch.archive_is_solid) {
				txt += " | Solid";
			}
		}

		if (prefix.length > 0) {
			txt = prefix + txt;
		}

		lbl_status.label = txt;
		* */
	}

	public void set_empty(){
		lbl_dir_count.label = "%'ld".printf(0);
		lbl_file_count.label = "%'ld".printf(0);
		lbl_hidden_count.visible = false;
		lbl_fs_free.visible = false;
		lbl_fs_type.visible = false;
		lbl_fs_read_only.visible = false;
		ebox_filter.visible = false;
		ebox_terminal.visible = false;
	}	
	
	public void refresh_selection_counts(){

		if ((view == null) || (view.current_item == null)){
			set_empty();
			return;
		}

		log_debug("Statusbar: refresh_selection_counts()");

		/*if (view.current_item.is_virtual){

			lbl_dir_count.label = "%'ld".printf(view.current_item.dir_count);
			
			lbl_file_count.label = "%'ld".printf(view.current_item.file_count);
		}
		else{*/

			int files, dirs;
			view.get_selected_counts(out files, out dirs);

			lbl_dir_count.label = "%'ld/%'ld".printf(dirs, view.current_item.dir_count);
			
			lbl_file_count.label = "%'ld/%'ld".printf(files, view.current_item.file_count);
		//}
	}
	
	private void refresh_usage_bar() {
		fs_bar.queue_draw_area(0, 0, fs_bar.get_allocated_width(), fs_bar.get_allocated_height());
	}

	public void show_spinner(string msg){
		lbl_progress.label = msg;
		gtk_show(lbl_progress);
	}

	public void hide_spinner(){
		lbl_progress.label = "";
		gtk_hide(lbl_progress);
	}
}




