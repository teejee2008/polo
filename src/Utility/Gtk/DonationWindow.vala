/*
 * DonationWindow.vala
 *
 * Copyright 2012-2017 Tony George <teejeetech@gmail.com>
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

using TeeJee.Logging;
using TeeJee.FileSystem;
using TeeJee.JsonHelper;
using TeeJee.ProcessHelper;
using TeeJee.System;
using TeeJee.Misc;
using TeeJee.GtkHelper;

public class DonationWindow : Dialog {

	private string username = "";

	public DonationWindow() {

		set_title(_("Donate"));
		window_position = WindowPosition.CENTER_ON_PARENT;
		set_destroy_with_parent (true);
		set_modal (true);
		set_deletable(true);
		set_skip_taskbar_hint(false);
		set_default_size (500, 20);
		icon = get_app_icon(16);

		//vbox_main
		var vbox_main = get_content_area();
		vbox_main.margin = 6;
		vbox_main.spacing = 6;
		//vbox_main.homogeneous = false;

		//get_action_area().visible = false;

		string msg = _("Did you find this application useful?\n\nYou can buy me a coffee or make a donation via PayPal to show your support.\n\nThis application includes a few extra features for people who have contributed to the project through donations, translations, etc. You can make a donation for $10 or more via PayPal to receive the plugins by email. Your contributions will help keep the project alive and support future development.\n\nThanks,\nTony George");
		
		var label = new Gtk.Label(msg);
		label.wrap = true;
		label.wrap_mode = Pango.WrapMode.WORD;
		label.max_width_chars = 50;
		label.xalign = 0.0f;
		label.margin_bottom = 6;

		var scrolled = new Gtk.ScrolledWindow(null, null);
		scrolled.hscrollbar_policy = PolicyType.NEVER;
		scrolled.vscrollbar_policy = PolicyType.NEVER;
		scrolled.add (label);
		vbox_main.add(scrolled);
		
		/*var hbox = new Gtk.Box(Orientation.HORIZONTAL, 6);
		hbox.margin_top = 24;
		vbox_main.pack_start(hbox, false, false, 0);
		
		var bbox = new Gtk.ButtonBox(Orientation.HORIZONTAL);
		//bbox.set_layout(Gtk.ButtonBoxStyle.EXPAND);
		bbox.set_spacing(6);
		bbox.set_homogeneous(false);
		hbox.add(bbox);
		* */

		if (get_user_id_effective() == 0){
			username = get_username();
		}

		// donation_features
		var button = new Gtk.LinkButton.with_label("", _("Donation Features"));
		button.set_tooltip_text("https://github.com/teejee2008/polo/wiki/Donation-Features");
		vbox_main.add(button);
		button.clicked.connect(() => {
			xdg_open("https://github.com/teejee2008/polo/wiki/Donation-Features", username);
		});
		
		// donate paypal
		button = new Gtk.LinkButton.with_label("", _("Donate with PayPal"));
		button.set_tooltip_text("Donate to: teejeetech@gmail.com");
		vbox_main.add(button);
		button.clicked.connect(() => {
			xdg_open("https://www.paypal.com/cgi-bin/webscr?business=teejeetech@gmail.com&cmd=_xclick&currency_code=USD&amount=10&item_name=Polo%20Donation", username);
		});

		// patreon
		button = new Gtk.LinkButton.with_label("", _("Become a Patron"));
		button.set_tooltip_text("https://www.patreon.com/bePatron?u=3059450");
		vbox_main.add(button);
		button.clicked.connect(() => {
			xdg_open("https://www.patreon.com/bePatron?u=3059450", username);
		});

		// issue tracker
		button = new Gtk.LinkButton.with_label("", _("Issue Tracker ~ Report Issues, Request Features, Ask Questions"));
		button.set_tooltip_text("https://github.com/teejee2008/polo/issues");
		vbox_main.add(button);
		button.clicked.connect(() => {
			xdg_open("https://github.com/teejee2008/polo/issues", username);
		});

		// wiki
		button = new Gtk.LinkButton.with_label("", _("Wiki ~ Documentation & Help"));
		button.set_tooltip_text("https://github.com/teejee2008/polo/wiki");
		vbox_main.add(button);
		button.clicked.connect(() => {
			xdg_open("https://github.com/teejee2008/polo/wiki", username);
		});

		// website
		button = new Gtk.LinkButton.with_label("", _("Website ~ teejeetech.in"));
		button.set_tooltip_text("http://www.teejeetech.in");
		vbox_main.add(button);
		button.clicked.connect(() => {
			xdg_open("http://www.teejeetech.in", username);
		});

		// close window
		button = new Gtk.LinkButton.with_label("", _("Close Window"));
		vbox_main.add(button);
		button.clicked.connect(() => {
			this.destroy();
		});

		this.show_all();
	}
}

