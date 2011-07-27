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
using Gdk;

using Granite.Widgets;
using Granite.Services;

using Scratch.Widgets;
using Scratch.Dialogs;

namespace Scratch {
    
    public class MainWindow : Gtk.Window {

        private const string TITLE = "Scratch";
        
        //widgets
        public ScratchNotebook notebook;
        public Widgets.Toolbar toolbar;
        
        //dialogs
        public FileChooserDialog filech;
        

        public MainWindow (string arg="") {

            if (arg == "") {
                this.title = this.TITLE;
            } else {
                this.title = arg;
            }
            
            load_file (arg);
            
            this.set_default_size (800, 500);
            restore_saved_state ();
            //this.set_icon ("text-editor");
            
            create_window();
            connect_signals();
        }
        
        public void create_window () {

            //notebook, textview and its scrolledwindow
            this.notebook = new ScratchNotebook ();
            this.notebook.add_tab();
            
            this.toolbar = new Widgets.Toolbar (this);

            //adding all to the vbox
            var vbox = new VBox (false, 0);
            vbox.pack_start (toolbar, false, false, 0);
            vbox.pack_start (notebook, true, true, 0); 
            
            this.add (vbox);		
        
        }
        
        public void connect_signals () {

            //signals for the window
            this.destroy.connect (Gtk.main_quit);

            //signals for the toolbar
            toolbar.new_button.clicked.connect (on_new_clicked);
            toolbar.open_button.clicked.connect (on_open_clicked);
            toolbar.save_button.clicked.connect (on_save_clicked);
            toolbar.undo_button.clicked.connect (on_undo_clicked);
            toolbar.repeat_button.clicked.connect (on_repeat_clicked);
                
        }
        
        
        //signals functions
        public void on_new_clicked () {
            int new_tab_index = notebook.add_tab ();
            notebook.set_current_page (new_tab_index);
        }
        
        public void on_open_clicked () {

			//show dialog
            this.filech = new FileChooserDialog ("Open a file", this, FileChooserAction.OPEN, null);
            filech.add_button (Stock.CANCEL, ResponseType.CANCEL);
            filech.add_button (Stock.OPEN, ResponseType.ACCEPT);
            filech.set_default_response (ResponseType.ACCEPT);
            
//          filech.response.connect (on_response);

            if (filech.run () == ResponseType.ACCEPT) {
				string filename = filech.get_filename();
				
		        if (filename != null) {
		        
		        	//check if file is already opened
		        	int tot_pages = notebook.get_n_pages ();
		        	int target_page = -1;
		        	
	        		for (int i = 0; i < tot_pages; i++) {
		        		Tab page = (Tab) notebook.get_nth_page (i);
		        		if (page.filename == filename) {
		        			target_page = i;
		        		}
	        		}

					if (target_page >= 0){
						stdout.printf("file already opened: %s\n", filename);
						notebook.set_current_page (target_page);
	        		} else {
						stdout.printf ("Opening: %s\n", filename);
				        load_file (filename);
				    }
		        }
            
            }
            
            filech.close();
                
        }

/*
        public void on_response (Dialog source, int response_id) {
            switch (response_id) {
                    case ResponseType.ACCEPT:
                        string filename = filech.get_filename();
                        if (filename != null) {
							stdout.printf ("Opening: %s\n", filename);
                            load_file (get_filename ());
                        }
                        
                        filech.close ();
                        break;
                    case ResponseType.CANCEL:
                        filech.close ();
                        break;
                }
            
        }
*/        
        
        public void on_save_clicked() {
        
            var current_tab = (Tab) notebook.get_nth_page (notebook.get_current_page());
        	string filename = current_tab.filename;
			var name = filename.split("/");
            
            if (filename == null) {
            
            	//show dialog
                this.filech = new FileChooserDialog ("Save as", this, FileChooserAction.SAVE, null);
                filech.add_button (Stock.CANCEL, ResponseType.CANCEL);
                filech.add_button (Stock.SAVE, ResponseType.ACCEPT);
                filech.set_default_response (ResponseType.ACCEPT);
                
                //response
                if (filech.run () == ResponseType.ACCEPT)
                    filename = filech.get_filename();
                
                //close dialog
                filech.close();

				//check choise
				if (filename == null) return;
            
            }
            
			stdout.printf("Saving: %s", filename);
            if (save_file (filename, current_tab.text_view.buffer.text) == 0) {
				current_tab.filename = filename;
				current_tab.label.change_text (name[name.length-1]);
			}
			
        }
        
        public void on_undo_clicked() {
        	
		var tab = (Tab) notebook.get_nth_page (notebook.get_current_page());
		tab.text_view.undo ();
	}
	
	public void on_repeat_clicked() {
        	
		var tab = (Tab) notebook.get_nth_page (notebook.get_current_page());
		tab.text_view.redo ();
	}
	
	//generic functions
        public void load_file (string filename) {
            if (filename != "") {
                try {
                    string text;
                    FileUtils.get_contents (filename, out text);
                    
                    //get the filename from strig filename =)
                    var name = filename.split("/");
                    
					Tab target_tab;
		            var current_tab = (Tab) notebook.get_nth_page (notebook.get_current_page());
		            if (current_tab.filename == null) {
		            
		            	//open in this tab
						target_tab = current_tab;  
		            } else {

		                //create new tab
		                int tab_index = notebook.add_tab(name[name.length-1]);
		                notebook.set_current_page(tab_index);		                
		                target_tab = (Tab) notebook.get_nth_page (tab_index);
		                
		            }    
		                
	                //set new values
	                target_tab.text_view.buffer.text = text;
	                target_tab.filename = filename;
	                target_tab.label.change_text (name[name.length-1]);
	                this.title = this.TITLE + " - " + filename;
                        
                } catch (Error e) {
                    stderr.printf ("Error: %s\n", e.message);
                }
            }
                
        }
        
        public int save_file (string filename, string contents) {
        
            if (filename != "") {
                try {
                    FileUtils.set_contents (filename, contents);
                    return 0;				
                } catch (Error e) {
                    stderr.printf ("Error: %s\n", e.message);
                    return 1;
                }
                    
            } else return 1;		
            
        }

        protected override bool delete_event (Gdk.EventAny event) {

            update_saved_state ();
            return false;

        }

        private void restore_saved_state () {

            default_width = Scratch.saved_state.window_width;
            default_height = Scratch.saved_state.window_height;

            if (Scratch.saved_state.window_state == ScratchWindowState.MAXIMIZED)
                maximize ();
            else if (Scratch.saved_state.window_state == ScratchWindowState.FULLSCREEN)
                fullscreen ();
        
        }

        private void update_saved_state () {
            
			// Save window state
			if ((get_window ().get_state () & WindowState.MAXIMIZED) != 0)
				Scratch.saved_state.window_state = ScratchWindowState.MAXIMIZED;
			else if ((get_window ().get_state () & WindowState.FULLSCREEN) != 0)
				Scratch.saved_state.window_state = ScratchWindowState.FULLSCREEN;
			else
				Scratch.saved_state.window_state = ScratchWindowState.NORMAL;
			
			// Save window size
			if (Scratch.saved_state.window_state == ScratchWindowState.NORMAL) {
				int width, height;
				get_size (out width, out height);
				Scratch.saved_state.window_width = width;
				Scratch.saved_state.window_height = height;
			}

        }

    }
} // Namespace	
