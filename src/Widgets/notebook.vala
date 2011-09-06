// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
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

using Scratch.Dialogs;

namespace Scratch.Widgets {

    public class Tab : ScrolledWindow {

        private MainWindow window;

        public SourceView text_view;
        public TabLabel label;
        public ScratchNotebook notebook;
        public string filename = null;
        public bool saved = true;

        
        public Tab (ScratchNotebook parent, string labeltext, MainWindow window) {
            
            this.window = window;
        	this.notebook = parent;
            
            set_policy (PolicyType.AUTOMATIC, PolicyType.AUTOMATIC);            
            
            text_view = new SourceView (window);
            text_view.focus_in_event.connect (on_focus_in);
            label = new TabLabel(this, labeltext);
   			label.scroll_event.connect (notebook.window.on_scroll_event);
            
            add (text_view);
            show_all();


        }


		public void on_close_clicked() {
			
			if (this.saved == false) {
			
				var save_dialog = new SaveDialog(this);
				save_dialog.run();
						
		    } else this.close ();
		    		    
        }
		
		public bool on_focus_in (EventFocus event) {
			notebook.window.current_notebook = notebook.window.split_view.get_current_notebook ();
			notebook.window.current_tab = (Tab) notebook.window.current_notebook.get_nth_page (notebook.window.current_notebook.get_current_page());
			notebook.window.set_undo_redo ();
			
			if (window.current_tab.filename != null) {
					window.set_combobox_language (window.current_tab.filename);
			}
			return true;
			
		}
		
        public void close () {
			
    		message("closing: %s\n", this.filename);		    
		    var n = notebook.page_num(this);
		    notebook.remove_page(n);
		    
		    if (notebook.get_n_pages() == 0)
		    	notebook.show_welcome();

        }
        
        public int save () {
	
            if (this.filename == null) {
            
            	var filech = notebook.window.filech;
            	string new_filename = null;
					
            	//show dialog
                filech = new FileChooserDialog ("Save as", notebook.window, FileChooserAction.SAVE, null);
                filech.add_button (Stock.CANCEL, ResponseType.CANCEL);
                filech.add_button (Stock.SAVE, ResponseType.ACCEPT);
                filech.set_default_response (ResponseType.ACCEPT);
                
                var response = filech.run();
                
                switch (response) {
					case ResponseType.ACCEPT:
					new_filename = filech.get_filename();				
	                filech.close();
					break;
					
					case ResponseType.CANCEL:
	                filech.close();
					return 1;
										
				}
                
				//check choise
				if (new_filename != null) this.filename = new_filename;
				else return 1;
				
				window.set_combobox_language (filename);
            
            }
            
			message ("Saving: %s", this.filename);
			
			try {
			
				FileUtils.set_contents (this.filename, this.text_view.buffer.text);
				this.saved = true;
				var name = Path.get_basename (this.filename);
				this.label.label.set_text (name);
                window.set_window_title (this.filename);
		        return 0;
		        
		    } catch (Error e) {
		    
				warning ("Error: %s\n", e.message);
				return 1;
				
		    }

	
        }

        public int save_file (string filename, string contents) {

            if (filename != "") {
                try {
                    FileUtils.set_contents (filename, contents);
                    return 0;				
                } catch (Error e) {
                    warning("Error: %s\n", e.message);
                    return 1;
                }
                    
            } else return 1;		
    
        }

    }
    
    public class TabLabel : HBox {
	
		public HBox tablabel;
        private EventBox event_box;
        public Label label;
        public Entry entry;
        public Button close;
        
        public TabLabel (Tab my_tab, string labeltext) {
                        
            label = new Label (labeltext);
            entry = new Entry ();

            event_box = new EventBox ();
            event_box.set_visible_window (false);
            event_box.add (label);
            
            var image = new Image.from_stock(Stock.CLOSE, IconSize.MENU);
            close = new Button ();
            close.clicked.connect (my_tab.on_close_clicked);
            close.set_relief (ReliefStyle.NONE);
            close.set_image (image);
            
            if (is_close_first ()) {
                pack_start (close, false, false, 0);
                pack_start (event_box, false, false, 0);
            } else {
                pack_start (event_box, false, false, 0);
                pack_start (close, false, false, 0);
            }

            event_box.button_press_event.connect (click_event);
            this.show_all ();		
        }

        protected bool click_event (EventButton event) {

            if ((event.type == EventType.2BUTTON_PRESS) || (event.type == EventType.3BUTTON_PRESS)) {
                event_box.hide ();
                add (entry);
                entry.text = label.get_text ();
                entry.show ();
                entry.key_press_event.connect (return_event);
            }
            return false;
        }

        protected bool return_event (EventKey event) {
            if (event.keyval == 65293) { // 65293 is the return key
                entry.hide ();
                event_box.show ();
                label.label = entry.text;
            }
            return false;
        }

        private bool is_close_first () {

            string path = "/apps/metacity/general/button_layout";
            GConf.Client cl = GConf.Client.get_default ();
            string key;

            try {
                if (cl.get (path) != null)
                    key = cl.get_string (path);
                else
                    return false;
            } catch (GLib.Error err) {
                warning ("Unable to read metacity settings: %s", err.message);
            }

            string[] keys = key.split (":");
            if ("close" in keys[0])
                return true;
            else
                return false;

        }

    }
    
	public class ScratchNotebook : Notebook {

		public MainWindow window; //used in dialog		
		public ScratchWelcome welcome_screen;

	    public ScratchNotebook (MainWindow parent) {
	    
	    	this.window = parent;
			this.welcome_screen = new ScratchWelcome(this);
	    	
			set_scrollable (true);
			set_group_name ("s");
			
			drag_end.connect (on_drag_end);
			
			show_all ();
			
	    }
	    
        public int add_tab (string labeltext="New file") {
            
            var new_tab = new Tab (this, labeltext, window);
            int index = this.append_page (new_tab, new_tab.label);
            set_tab_reorderable(new_tab, true);
            set_tab_detachable(new_tab, true);
            return index; 
        }
       
        public void on_drag_end (DragContext context) {
			
			List<Widget> children = window.split_view.get_children ();
			int i;
			
			for (i = 0; i!=children.length(); i++) {//ScratchNotebook notebook in children) { 
				var notebook = children.nth_data (i) as ScratchNotebook;
				if (notebook.get_n_pages () == 0)
					window.split_view.remove (notebook);
			}
		}
        
		public void show_welcome () {
						
			if (window.split_view.get_children().length() == 1) {
			
				if (!welcome_screen.active) {
						
					this.append_page (welcome_screen, null);
					this.set_show_tabs (false);
					this.welcome_screen.active = true;
					window.set_undo_redo ();
				}
			}
		
			else {
				window.split_view.remove (this);
			}
		
		}
		
		public void show_tabs_view () {
			
			if (welcome_screen.active) {
			
				this.remove_page (this.page_num(welcome_screen));
				this.set_show_tabs (true);
				this.welcome_screen.active = false;
				
			}
			
		}


		public class ScratchWelcome : Granite.Widgets.Welcome {
		
			public bool active = false;
			private ScratchNotebook notebook;
			
			public ScratchWelcome(ScratchNotebook caller) {
		
				base(_("No files opened."), _("Open a file to start editing"));
		
				notebook = caller;
		
				append(Stock.OPEN, _("Open file"), _("open a saved file"));
				append(Stock.NEW, _("New file"), _("create an new empty file"));
				this.activated.connect (on_activated);
				
				show_all();

			}
			
			private void on_activated(int index) {

				switch (index) {
					case 0: //open
					//notebook.window.on_new_clicked ();
					notebook.window.on_open_clicked ();
					break;

					case 1: // new
					notebook.window.on_new_clicked();
					break;
				
				}

				
			}
		
		
		}

        
    }
    
    public class SplitView : HBox {
		
		public MainWindow window;
		public uint total_view {
			get {return get_children().length();}
		}
		
		public SplitView (MainWindow window) {
			this.window = window;
			
			//var notebook = new ScratchNotebook (window);
			//add_view (notebook);
		}
		
		public void add_view (ScratchNotebook view) {
			pack_start (view, true, true, 0);
			this.set_focus_child (view);
			//set sensitive for remove menutitem
			if (get_children ().length() >= 2) 
				window.toolbar.menu.remove_view.set_sensitive (true);
			else 
				window.toolbar.menu.remove_view.set_sensitive (false);
			show_all ();
		}
		
		public bool remove_current_view () {
			remove (window.current_notebook);
			if (get_children().length() >= 2)
				return true;
			else 
				return false;
						
		}
		
		public ScratchNotebook get_current_notebook () {
			ScratchNotebook child = get_focus_child () as ScratchNotebook;
			if (child == null) {
			    child = get_children ().nth_data (0) as ScratchNotebook;
			    if( child == null) {
			        critical ("No valid notebook for the split view?");
			    }
			}
			return child;
		}
		
		
	}
    
} // Namespace
