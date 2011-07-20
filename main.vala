/***
  BEGIN LICENSE
	
  Copyright (C) 2011 Mario Guerriero <mefrio.g@gmail.com>	
  This program is free software: you can redistribute it and/or modify it	
  under the terms of the GNU Lesser General Public License version 3, as published	
  by the Free Software Foundation.
	
  This program is distributed in the hope that it will be useful, but	
  WITHOUT ANY WARRANTY; without even the implied warranties of	
  MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR	
  PURPOSE.  See the GNU General Public License for more details.
	
  You should have received a copy of the GNU General Public License along	
  with this program.  If not, see <http://www.gnu.org/licenses/>	
  
  END LICENSE	
***/


/* 
compile with

 valac --pkg gtk+-3.0 --pkg gio-2.0 --pkg=granite  main.vala main_window.vala entry.vala menu.vala -o scratch
 
and launch with

 ./scratch
*/

void main(string[] args)
{	
	
	if (args[1] != null) {
		Gtk.init (ref args);
		var window =new MainWindow (args[1]);
		window.create_window();
		window.connect_signals();
		window.show_all ();
		Gtk.main ();
	}
	
	else {
		Gtk.init (ref args);
		var window =new MainWindow ("");
		window.create_window();
		window.connect_signals();
		window.show_all ();
		Gtk.main ();
	}
}
