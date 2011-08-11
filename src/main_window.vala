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
        private string search_string = "";
        
        //widgets
        public ScratchNotebook notebook;
        public SplitView split_view;
        public Widgets.Toolbar toolbar;
        
        //dialogs
        public FileChooserDialog filech;

        public Tab current_tab;
        
        //bools for key press event
        bool ctrlL = false;
		bool ctrlR = false;

        public MainWindow () {
				
            this.title = TITLE;
            restore_saved_state ();
            
            create_window ();
            connect_signals ();

        }
        
        public void create_window () {
			
	    this.split_view = new SplitView ();
			
            this.notebook = new ScratchNotebook (this);
            this.notebook.add_tab();
            
            split_view.add_view (notebook);
            
            this.toolbar = new Widgets.Toolbar (this);

            //adding all to the vbox
            var vbox = new VBox (false, 0);
            vbox.pack_start (toolbar, false, false, 0);
            vbox.pack_start (split_view, true, true, 0); 
            
            this.add (vbox);
            
            set_undo_redo ();		
        
        }
        
        public void connect_signals () {

            //signals for the window
            this.destroy.connect (Gtk.main_quit);
            
            this.key_release_event.connect (on_key_released);
            this.key_press_event.connect (on_key_press);

            //signals for the toolbar
            toolbar.new_button.clicked.connect (on_new_clicked);
            toolbar.open_button.clicked.connect (on_open_clicked);
            toolbar.save_button.clicked.connect (on_save_clicked);
            toolbar.undo_button.clicked.connect (on_undo_clicked);
            toolbar.repeat_button.clicked.connect (on_repeat_clicked);
            toolbar.combobox.changed.connect (on_combobox_changed);
            toolbar.entry.changed.connect (on_changed_text);
            
            //signals for the notebook
            notebook.switch_page.connect (on_switch_tab);    
        }
        
        
         
        //signals functions
        public void on_destroy () {
			if (!notebook.welcome_screen.active) {
				//var tab = (Tab) notebook.get_nth_page (notebook.get_current_page());
				this.show_all ();
				string isnew = current_tab.label.label.get_text () [0:1];
				if (isnew == "*") {
					var save_on_close_dialog = new SaveOnCloseDialog (current_tab.filename, this);
						save_on_close_dialog.run ();
					} else {
						this.destroy();
					}
			}
        }
        
        private void reset_ctrl_flags() {
			ctrlR = false;
			ctrlL = false;
		}
        
        // untoggles Control Trigger
        private bool on_key_released (EventKey event) {

			string key = Gdk.keyval_name(event.keyval);
			
			if (key == "Control_L" || key == "Control_R")
				reset_ctrl_flags();
				
			return true;
		}
        
        public bool on_key_press (EventKey event) {
			
            string key = Gdk.keyval_name(event.keyval);
			            
            /// Q: Do we really need ctrlL and ctrlR? One Var may be enough
			if (key == "Control_L")
				ctrlL = true;
			if (key == "Control_R")
				ctrlR = true;

		    if ((ctrlL || ctrlR))
			{
				switch(key.down()/*This avoids checking for "t" and "T*/)
				{
					// Open new Tab
					case "t":		
						if (!notebook.welcome_screen.active) {
							int tab_index = notebook.add_tab ();
		                		notebook.set_current_page (tab_index);            
						}
					break;

					// Close current Tab
					case "w":
						if (!notebook.welcome_screen.active) {					
							var current_tab = (Tab) notebook.get_nth_page (notebook.get_current_page());
							current_tab.on_close_clicked ();
						}
					break;
					
					// Close Scratch by Ctrl+Q
					// we may also add ctrl+e
					case "q":
						warning("Killler");
						this.on_destroy();
					break;

					// Save current File by Ctrl+S
					case "s":
						this.on_save_clicked();
						reset_ctrl_flags();
					break;		
					
					// Undo by Ctrl+Z
					case "z":
						this.on_undo_clicked();
					break;	
						
					// Redo by Ctrl+Y
					case "y":
						this.on_repeat_clicked();
					break;
				}
			}
            return false;
        }
        
        public void on_new_clicked () {
        
            int new_tab_index = notebook.add_tab ();
            notebook.set_current_page (new_tab_index);
        	notebook.show_tabs_view ();
            
        }
        
        public void on_open_clicked () {

			// show dialog
            this.filech = new FileChooserDialog ("Open a file", this, FileChooserAction.OPEN, null);
            filech.add_button (Stock.CANCEL, ResponseType.CANCEL);
            filech.add_button (Stock.OPEN, ResponseType.ACCEPT);
            filech.set_default_response (ResponseType.ACCEPT);
            
            // filech.response.connect (on_response);

            if (filech.run () == ResponseType.ACCEPT) {
				string filename = filech.get_filename ();
				
		        if (filename != null) {
		        
		        	// check if file is already opened
		        	int target_page = -1;
		        	
		        	if (!notebook.welcome_screen.active) {
				    			        	
				    	int tot_pages = notebook.get_n_pages ();		        	
			    		for (int i = 0; i < tot_pages; i++) {
				    		current_tab = (Tab) notebook.get_nth_page (i);
				    		if (current_tab.filename == filename) {
				    			target_page = i;
				    		}
			    		}

					}

					if (target_page >= 0) {
						message ("file already opened: %s\n", filename);
						notebook.set_current_page (target_page);
	        		} else {
						message ("Opening: %s\n", filename);
			        	notebook.show_tabs_view ();						
				        load_file (filename);
				        //set the name of the file, not all the path, in the tab label
				        var name = filename.split("/");
	    				current_tab.label.label.set_text (name[name.length-1]);

				    }
		        }
            
            }
            
            
            
            filech.close ();
            set_undo_redo ();
                
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
        
            current_tab = (Tab) notebook.get_nth_page (notebook.get_current_page());
  			current_tab.save();
  		    
/*      
        	string filename = current_tab.filename;
            
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
            
			message("Saving: %s", filename);
            if (save_file (filename, current_tab.text_view.buffer.text) == 0) {
				current_tab.filename = filename;
				current_tab.saved = true;
				var name = filename.split("/");
				current_tab.label.change_text (name[name.length-1]);
			}

*/
			
        }
        
        public void on_undo_clicked () {

            current_tab = (Tab) notebook.get_nth_page (notebook.get_current_page());
            current_tab.text_view.undo ();
            set_undo_redo ();

        }
	
        public void on_repeat_clicked () {

            current_tab = (Tab) notebook.get_nth_page (notebook.get_current_page());
            current_tab.text_view.redo ();
            set_undo_redo ();
		
        }
        
        public void on_combobox_changed () {

        	current_tab = (Tab) notebook.get_nth_page (notebook.get_current_page());
        	var lang = toolbar.combobox.get_active_text().down();
        	if (lang == "c++") {
        		current_tab.text_view.buffer.set_language ( current_tab.text_view.manager.get_language("cpp") );
        	}
        	else if (lang == "c#") {
        		current_tab.text_view.buffer.set_language ( current_tab.text_view.manager.get_language("c-sharp") );
        	}
        	else if (lang == "gettext") {
        		current_tab.text_view.buffer.set_language ( current_tab.text_view.manager.get_language("gettext-translation") );
        	}
        	else if (lang == ".desktop") {
        		current_tab.text_view.buffer.set_language ( current_tab.text_view.manager.get_language("desktop") );
        	}
        	else if (lang == "javascript") {
        		current_tab.text_view.buffer.set_language ( current_tab.text_view.manager.get_language("js") );
        	}
        	else if (lang == "objective-c") {
        		current_tab.text_view.buffer.set_language ( current_tab.text_view.manager.get_language("objc") );
        	}
        	else {
        		current_tab.text_view.buffer.set_language ( current_tab.text_view.manager.get_language(lang) );
		}
        }
	
        public void on_switch_tab (Widget page, uint page_num) {

            current_tab = (Tab) notebook.get_nth_page (notebook.get_current_page()-1);	

            if (current_tab.filename != null) {
                set_window_title (current_tab.filename);
            } else {
                this.title = this.TITLE;
            }
            
        }
	
        public void on_changed_text (){
            current_tab = (Tab) notebook.get_nth_page (notebook.get_current_page());	
            search_string = toolbar.entry.get_text();
            TextIter iter;
            TextIter start, end;
            current_tab.text_view.buffer.get_start_iter (out iter);
            var found = iter.forward_search (search_string, TextSearchFlags.CASE_INSENSITIVE, out start, out end, null);
            if (found) {
                current_tab.text_view.buffer.select_range (start, end);
            }
        }
        
        

        //generic functions
        public void load_file (string filename) {
            if (filename != "") {
                try {
                    string text;
                    FileUtils.get_contents (filename, out text);
                    
                    //get the filename from strig filename =)
                    var name = Filename.display_basename (filename);
                    
					Tab target_tab;
			        current_tab = (Tab) notebook.get_nth_page (notebook.get_current_page());

		            if ((current_tab != null) && (current_tab.filename == null) ) {
		            
		            	//open in this tab
						target_tab = current_tab;  
		            } else {

		                //create new tab
		                int tab_index = notebook.add_tab (name);
		                notebook.set_current_page (tab_index);		                
		                target_tab = (Tab) notebook.get_nth_page (tab_index);
		                
		            }    
		                
	                //set new values
                   	target_tab.text_view.set_file (filename, text);
	                target_tab.filename = filename;
	                target_tab.saved = true;
	                //set values for label
	                var tab = (Tab) notebook.get_nth_page (notebook.get_current_page());
            		var label = tab.label.label;
            		if (label.get_text().substring (0, 1) == "*"){
                		label.set_text (filename);
            		}
                    set_window_title (filename);
	                                        
                } catch (Error e) {
					warning("Error: %s\n", e.message);
                }
            }
            var tab = (Tab) notebook.get_nth_page (notebook.get_current_page());
            var label = tab.label.label;
            if (label.get_text().substring (0, 1) == "*"){
                label.set_text (filename);
            }
                
        }

        public void set_window_title (string filename) {

            this.title = this.TITLE + " - " + Path.get_basename (filename);
            var home_dir = Environment.get_home_dir ();
            // Sorry for this mess...
            var path = Path.get_dirname (filename).replace (home_dir, "~");
            this.title += " (" + path + ")";
        
        }

        protected override bool delete_event (Gdk.EventAny event) {

            on_destroy ();
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
        
        public void set_undo_redo () {
        	
            current_tab = (Tab) notebook.get_nth_page (notebook.get_current_page());
            var buf = current_tab.text_view.buffer;

			toolbar.set_button_sensitive(Widgets.Toolbar.ToolButtons.UNDO_BUTTON, buf.can_undo);
			toolbar.set_button_sensitive(Widgets.Toolbar.ToolButtons.REPEAT_BUTTON, buf.can_redo);
		
        }
        
        public void set_combobox_language (string filename) {
        	GtkSource.Language lang;
        	current_tab = (Tab) notebook.get_nth_page (notebook.get_current_page());
            lang = current_tab.text_view.manager.guess_language (filename, null);
        	toolbar.combobox.set_active_id ( lang.get_id() );
        }
        
        public void create_instance () {
		
				var instance = new ScratchNotebook (this);
				instance.add_tab ();
				split_view.add_view(instance);
				split_view.show_all ();
							
		}

    }
} // Namespace	
