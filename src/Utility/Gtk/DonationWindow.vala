/*
 * DonationWindow.vala
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

using Gtk;

using TeeJee.Logging;
using TeeJee.FileSystem;
using TeeJee.JsonHelper;
using TeeJee.ProcessHelper;
using TeeJee.System;
using TeeJee.Misc;
using TeeJee.GtkHelper;

public class DonationWindow : Gtk.Window {

	private Gtk.Box vbox_main;
	private string username = "";
	private string appname = "Polo";
	private bool has_donation_plugins = true;
	private bool has_wiki = true;

	public DonationWindow(Gtk.Window window) {

		set_title(_("Donate"));
		set_transient_for(window);
		window_position = WindowPosition.CENTER_ON_PARENT;
		set_destroy_with_parent (true);
		set_modal (true);
		set_deletable(true);
		set_skip_taskbar_hint(false);
		set_default_size (400, 700);
		icon = get_app_icon(16);

		//vbox_main
		vbox_main = new Gtk.Box(Orientation.VERTICAL, 0);
		vbox_main.margin = 6;
		//vbox_main.spacing = 6;
		this.add(vbox_main);
		
		if (get_user_id_effective() == 0){
			username = get_username();
		}

		// -----------------------------

		string msg = _("If you find this application useful, you can make a donation with PayPal to support this project. Your contributions will help keep this project alive and support future development.");
		
		add_label(msg);

		var hbox = add_hbox();
		
		add_link_button(hbox, _("Donate ($5)"),
			"https://www.paypal.com/cgi-bin/webscr?business=teejeetech@gmail.com&cmd=_xclick&currency_code=USD&amount=5.00&item_name=%s+Donation".printf(appname));

		add_link_button(hbox, _("Become a Patron"),
			"https://www.patreon.com/bePatron?u=3059450");

		// -----------------------------

		add_heading(_("Paid Support"));
		
		msg = _("If you need support for this application, use the button below to make a donation with PayPal. You can either email me directly (teejeetech@gmail.com), or add your questions to the Issue Tracker, and send me the issue number. This option is only for queries you may have about the application, and for help with issues you are facing. This does not cover development work.");

		add_label(msg);

		hbox = add_hbox();

		add_link_button(hbox, _("Get Support ($10)"),
			"https://www.paypal.com/cgi-bin/webscr?business=teejeetech@gmail.com&cmd=_xclick&currency_code=USD&amount=10.00&item_name=%s+Support".printf(appname));

		// -----------------------------

		add_heading(_("Free Support"));
		
		msg = _("Please use the GitHub Issue Tracker to report issues, request features, and ask questions. Search for a topic to find answers for common questions, and solutions for common issues. Issues and features will be picked up from this tracker and implemented in a future release.");
		
		add_label(msg);
		
		hbox = add_hbox();
		
		add_link_button(hbox, _("Issue Tracker"),
			"https://github.com/teejee2008/%s/issues".printf(appname.down()));

		if (has_wiki){
			
			add_link_button(hbox, _("Wiki (Documentation)"),
				"https://github.com/teejee2008/%s/wiki".printf(appname.down()));
		}

		// -----------------------------

		if (has_donation_plugins){
			
			add_heading(_("Donation Features"));
			
			msg = _("I sometimes create exclusive plugins to encourage people to contribute. You can make a contribution by translating the application to other languages, submitting code changes, or by making a donation for $10 with PayPal. Contributors are added to an email distribution list, and plugins are sent by email.");

			add_label(msg);

			hbox = add_hbox();
			
			add_link_button(hbox, _("Donation Features"),
				"https://github.com/teejee2008/%s/wiki/Donation-Features".printf(appname.down()));

			add_link_button(hbox, _("Get Donation Plugins ($10)"),
				"https://www.paypal.com/cgi-bin/webscr?business=teejeetech@gmail.com&cmd=_xclick&currency_code=USD&amount=10.00&item_name=%s+Donation+Plugins".printf(appname));
		}
		
		// -----------------------------

		add_heading(_("Sponsored Features"));
		
		msg = _("You can sponsor the development for a bugfix or feature. These items are labelled as <i>\"OpenForSponsorship\"</i> in the issue tracker, along with an amount for the work involved. You can make a donation for that amount via PayPal, and either leave a comment on the thread, or email me with the issue number. I will work on it the next time I update the application, and changes will be included in the next release.");

		add_label(msg);

		hbox = add_hbox();
		
		add_link_button(hbox, _("Items for Sponsorship"),
			"https://github.com/teejee2008/" + appname.down() + "/issues?q=is%3Aissue+is%3Aopen+label%3AOpenForSponsorship");
			
		add_link_button(hbox, _("Sponsor a Feature"),
			"https://www.paypal.com/cgi-bin/webscr?business=teejeetech@gmail.com&cmd=_xclick&currency_code=USD&item_name=%s+Sponsor".printf(appname));
		
		// close window ---------------------------------------------------------

		hbox = add_hbox();
		
		var button = new Gtk.Button.with_label(_("Close Window"));
		button.margin_top = 12;
		hbox.add(button);
		
		button.clicked.connect(() => {
			this.destroy();
		});

		this.show_all();
	}

	private void add_heading(string msg){

		var label = new Gtk.Label("<span weight=\"bold\" size=\"large\">%s</span>".printf(msg));
		label.wrap = true;
		label.wrap_mode = Pango.WrapMode.WORD;
		label.set_use_markup(true);
		label.max_width_chars = 50;
		label.xalign = 0.0f;
		label.margin_top = 6;
		vbox_main.add(label);
	}

	private void add_label(string msg){

		var label = new Gtk.Label(msg);
		label.wrap = true;
		label.wrap_mode = Pango.WrapMode.WORD;
		label.set_use_markup(true);
		label.max_width_chars = 50;
		label.xalign = 0.0f;
		//label.margin_bottom = 6;

		var scrolled = new Gtk.ScrolledWindow(null, null);
		scrolled.hscrollbar_policy = PolicyType.NEVER;
		scrolled.vscrollbar_policy = PolicyType.NEVER;
		scrolled.add(label);
		vbox_main.add(scrolled);
	}

	private Gtk.ButtonBox add_hbox(){

		var hbox = new Gtk.ButtonBox(Orientation.HORIZONTAL);
		hbox.set_layout(Gtk.ButtonBoxStyle.CENTER);
		vbox_main.add(hbox);
		return hbox;
	}

	private void add_link_button(Gtk.Box box, string text, string url){

		var button = new Gtk.LinkButton.with_label("", text);
		button.set_tooltip_text(url);
		box.add(button);
		
		button.clicked.connect(() => {
			xdg_open(url, username);
		});
	}
}

