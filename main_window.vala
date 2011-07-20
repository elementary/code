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
using Granite.Widgets;

public class MainWindow : Window {

	private const string TITLE = "Scratch";
	
	//widgets for the window
	public TextView text_view;
	public Notebook notebook;
	
	//widgets for the toolbars
	public Toolbar BasicToolbar;
	public Toolbar SearchToolbar;
	public HBox hbox;
	
	public ToolButton new_;
	public ToolButton open_;
	public ToolButton save_;
	public SeparatorToolItem separator1;
	public ToolButton cancel_;
	public ToolButton repeat_;
	public ToolItem combo;
	public ComboBox cb;
	public SeparatorToolItem separator2;
	
	public SeparatorToolItem separator3;
	public ToolItem entry_cont;
	public Entry entry;
	public AppMenu app_menu;
	
	//dialogs
	public FileChooserDialog filech;
	
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
		create_toolbars ();
		//notebook, textview and its scrolledwindow
		this.notebook = new Notebook ();
		var scrolled = new ScrolledWindow (null, null);
		scrolled.set_policy (PolicyType.AUTOMATIC, PolicyType.AUTOMATIC);
		this.text_view = new TextView ();
		scrolled.add (text_view);
		notebook.add (scrolled);
		//addingo all to the vbox
		var vbox = new VBox (false, 0);
		vbox.pack_start (hbox, false, false, 0);
		vbox.pack_start (notebook, true, true, 0); 
		
		this.add (vbox);		
	
	}
	
	public void connect_signals () {
		//signals for the window
		this.destroy.connect (Gtk.main_quit);
		//signals for the toolbars
		this.new_.clicked.connect (on_new_clicked);
		this.open_.clicked.connect (on_open_clicked);
			
	}
	
	public void create_toolbars () {
		//
		//	FIRST TOOLBAR
		//
		this.BasicToolbar = new Toolbar ();
		
		this.new_ = new ToolButton.from_stock(Stock.NEW);
		this.open_ = new ToolButton.from_stock (Stock.OPEN);
		this.save_ = new ToolButton.from_stock (Stock.SAVE);
		this.separator1 = new SeparatorToolItem ();
		this.cancel_ = new ToolButton.from_stock (Stock.UNDO);
		this.repeat_ = new ToolButton.from_stock (Stock.REDO);
		this.separator2 = new SeparatorToolItem ();
		this.combo = new ToolItem ();
		
		this.cb = new ComboBox ();
		this.combo.add (cb);
		this.combo.set_expand (false);		
		
		BasicToolbar.add (new_);
		BasicToolbar.add (open_);
		BasicToolbar.add (save_);
		BasicToolbar.add (separator1);
		BasicToolbar.add (cancel_);
		BasicToolbar.add (repeat_);
		BasicToolbar.add (separator2);
		BasicToolbar.add (combo);
		
		//
		//	SECOND TOOLBAR
		//
		this.SearchToolbar = new Toolbar ();
		
		this.separator3 = new SeparatorToolItem ();	
		
		this.entry = new SearchBar ("Search in the text...");
		this.entry_cont = new ToolItem ();
		this.entry_cont.add (entry);	
		this.entry_cont.set_expand (true);	
			
		//var image = new Image.from_stock (Stock.PROPERTIES, IconSize.LARGE_TOOLBAR);
		var menu = new MenuProperties (); 
			
		//var w = new MainWindow ();
			
		this.app_menu = new AppMenu (menu);

		SearchToolbar.add (separator3);
		SearchToolbar.add (entry_cont);		
		SearchToolbar.add (app_menu);
		////////////
		this.hbox = new HBox (false, 0);
		
		hbox.pack_start (BasicToolbar, true, true, 0);
		hbox.pack_end (SearchToolbar, true, true, 0);
					
	}
	
	//signals functions
	public void on_new_clicked () {
		create_tab ();
	}
	
	public void on_open_clicked () {
		this.filech = new FileChooserDialog ("Open a file", this, FileChooserAction.OPEN);
		filech.add_button (Stock.CANCEL, ResponseType.CANCEL);
       	 	filech.add_button (Stock.OPEN, ResponseType.ACCEPT);
        	filech.set_default_response (ResponseType.ACCEPT);
        	
	       	//if (filech.run () == ResponseType.OK) {
            	//	stdout.printf ("filename = %s\n".printf (filech.get_filename ()));
        	//}
        	filech.run ();
        	filech.response.connect (on_response);
        	
	}
	
	public void on_response (Dialog source, int response_id) {
		switch (response_id) {
        		case ResponseType.ACCEPT:
         			stdout.printf ("filename = %s\n".printf (filech.get_filename ()));
         			load_file ( filech.get_filename () );
         			filech.close ();
         			break;
        		case ResponseType.CANCEL:
            			filech.close ();
            			break;
        	}
		
	}
	
	//generic functions
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
	
	public void create_tab () {
		var s = new ScrolledWindow (null, null);
		s.set_policy (PolicyType.AUTOMATIC, PolicyType.AUTOMATIC);
		var t = new TextView ();
		
		var l = new Label ("New file");
		
		s.add (t);
		
		notebook.append_page (s, l);
		
	}
	
}
	
