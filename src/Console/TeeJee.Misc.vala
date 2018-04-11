
/*
 * TeeJee.Misc.vala
 *
 * Copyright 2016 Tony George <teejeetech@gmail.com>
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
 
namespace TeeJee.Misc {

	/* Various utility functions */

	using TeeJee.Logging;

	// timestamp ----------------
	
	public string timestamp (bool show_millis = false){

		/* Returns a formatted timestamp string */

		// NOTE: format() does not support milliseconds

		DateTime now = new GLib.DateTime.now_local();
		
		if (show_millis){
			var msec = now.get_microsecond () / 1000;
			return "%s.%03d".printf(now.format("%H:%M:%S"), msec);
		}
		else{
			return now.format ("%H:%M:%S");
		}
	}

	public string timestamp_numeric (){

		/* Returns a numeric timestamp string */

		return "%ld".printf((long) time_t ());
	}

	public string timestamp_for_path (){

		/* Returns a formatted timestamp string */

		Time t = Time.local (time_t ());
		return t.format ("%Y-%d-%m_%H-%M-%S");
	}

	public string random_string(int length = 8, string charset = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz1234567890"){
		string random = "";

		for(int i=0;i<length;i++){
			int random_index = Random.int_range(0,charset.length);
			string ch = charset.get_char(charset.index_of_nth_char(random_index)).to_string();
			random += ch;
		}

		return random;
	}

	public MatchInfo? regex_match(string expression, string line){

		Regex regex = null;

		try {
			regex = new Regex(expression);
		}
		catch (Error e) {
			log_error (e.message);
			return null;
		}

		MatchInfo match;
		if (regex.match(line, 0, out match)) {
			return match;
		}
		else{
			return null;
		}
	}

	public string regex_escape(string str){

		string chars = """.^$*+?()[{|"""; // no \
		
		string txt = str;

		// replace the escape char first
		txt = txt.replace("""\""","""\\""");
		
		for (int i = 0; i < chars.length; i++){
			string ch = chars[i].to_string();
			txt = txt.replace(ch, """\""" + ch);
		}
		
		return txt;
	}
}
