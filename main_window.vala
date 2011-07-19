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

using Gtk;

public class MainWindow : Window {

	private const string TITLE = "Scratch";
	
	public TextView text_view;
	public Notebook notebook;
	
	public MainWindow (string arg="") {
		if (arg == "") {
			this.title = this.TITLE;
		}
		else {
			this.title = arg;
		}
		
		load_file (arg);
		
		this.set_default_size (800, 500);
		//this.set_icon ("text-editor");
		this.maximize ();
		
		//create_window();
		//connect_signals();
	}
	
	public void create_window () {
		//create the hbox		
		var toolbar = new ScratchToolbar ();
		
		//notebook, textview and its scrolledwindow
		var notebook = new Notebook ();
		var scrolled = new ScrolledWindow (null, null);
		scrolled.set_policy (PolicyType.AUTOMATIC, PolicyType.AUTOMATIC);
		this.text_view = new TextView ();
		scrolled.add (text_view);
		notebook.add (scrolled);
		//addingo all to the vbox
		var vbox = new VBox (false, 0);
		vbox.pack_start (toolbar, false, false, 0);
		vbox.pack_start (notebook, true, true, 0); 
		
		this.add (vbox);		
	
	}
	
	public void connect_signals () {
		this.destroy.connect (Gtk.main_quit);
			
	}
	
	public void load_file (string filename) {
		if (filename != "") {
			try {
				string text;
           			FileUtils.get_contents (filename, out text);
          			this.text_view.buffer.text = text;
			} catch (Error e) {
         	   		stderr.printf ("Error: %s\n", e.message);
        		}
		}
			
	}
	
	public void set_text (string text) {
		this.text_view.buffer.text = text;
	}
	
}
	
