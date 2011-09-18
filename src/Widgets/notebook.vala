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
			
			string isnew = label.label.get_text () [0:1];
			
			if (isnew == "*") {
			
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

			window.status.hide ();
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
        private string old;
        private Tab tab;
        
        public TabLabel (Tab my_tab, string labeltext) {
                                                
            homogeneous = false;    
            
            this.tab = my_tab;
                                            
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
			
			string filename = tab.filename;

			if (filename != null) {
			
				if ((event.type == EventType.2BUTTON_PRESS) || (event.type == EventType.3BUTTON_PRESS)) {
					event_box.hide ();
					add (entry);
					entry.text = label.get_text ();
					entry.show ();
					entry.key_press_event.connect (return_event);
				}
			}
            return false;
        }

        protected bool return_event (EventKey event) {
            if (event.keyval == 65293) { // 65293 is the return key
                string old = tab.filename;
                var sold = old.split ("/");
				string newname = "";
				foreach (string s in sold) {
					if (s != "" && s != sold[sold.length-1])
						newname = newname +  "/" + s;
					if (s == sold[sold.length-1])
						newname = newname +  "/" + entry.text;
				}
                
                
                entry.hide ();
                event_box.show ();
                FileUtils.rename (old, newname);
                
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
	    	
	    	this.switch_page.connect (on_switch_page);
	    	
	    	expand = true;
			set_scrollable (true);
			set_group_name ("s");
			
			drag_end.connect (on_drag_end);
			
			show_all ();
			
	    }
	    
        public int add_tab (string labeltext="New file") {
            
            //var new_tab = new Tab (this, labeltext, window);
            var new_tab = new Tab (this, labeltext, window);
            int index = this.append_page (new_tab, new_tab.label);
            set_tab_reorderable(new_tab, true);
            set_tab_detachable(new_tab, true);
            return index; 
        }
		
		public void on_switch_page (Widget page, uint number) {
		
			var tab = page as Tab;
			if (tab.filename != null)
				window.set_combobox_language (tab.filename);
				//tab.text_view.set_file (tab.filename, tab.text_view.buffer.text);
			
			GtkSource.Language lang;
            lang = tab.text_view.manager.get_language ( window.toolbar.combobox.get_active_id () );
            tab.text_view.buffer.set_language (lang);
						
		}
		
        public void on_drag_end (DragContext context) {
			
			List<Widget> children = window.split_view.get_children ();
			int i;
			
			for (i = 0; i!=children.length(); i++) {//ScratchNotebook notebook in children) { 
				var notebook = children.nth_data (i) as ScratchNotebook;
				if (notebook.get_n_pages () == 0) {
					window.split_view.remove (notebook);
				}
			}
			window.split_view.set_menu_item_sensitive ();
		}
        
		public void show_welcome () {

			if (window.split_view.get_children().length() == 1) {

				if (!welcome_screen.active) {
					
					List<Widget> children = window.split_view.get_children ();
					int i;
			
					for (i = 0; i!=children.length(); i++) {//ScratchNotebook notebook in children) { 
						window.split_view.remove ( children.nth_data (i) );
					}
							
					//split_view.remove (current_notebook.welcome_screen);
					//window.create_instance ();
					
					window.split_view.add (welcome_screen);
					//this.append_page (welcome_screen, null); //here scratch crash
					this.set_show_tabs (false);
					this.welcome_screen.active = true;
					window.set_undo_redo ();
				}
			}
		
			else {
				window.split_view.remove (this);
				window.split_view.set_menu_item_sensitive ();
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
		
				base(_("No files are open."), _("Open a file to begin editing"));
		
				notebook = caller;
		
				append(Stock.OPEN, _("Open file"), _("open a saved file"));
				append(Stock.NEW, _("New file"), _("create a new empty file"));
				this.activated.connect (on_activated);
				
				show_all();

			}
			
			private void on_activated(int index) {

				switch (index) {
					case 0: //open
					//notebook.window.on_new_clicked ();
					notebook.window.action_open_clicked (true);
					break;

					case 1: // new
					notebook.window.action_new_clicked(true);
					break;
				
				}

				
			}
		
		
		}

        
    }
    
    public class SplitView : HBox {
		
		//IN THIS CLASS I COMMENTED ALL THE CODE WHICH WAS USED FOR A SPLITVIEW WITH GTK.TABLE
		
		//private int current_row = 0;
		//private int current_col = 0;
		//private int rmax = 4;
		//private int cmax = 2;
		private int max = 4; //max = max--
		
		public MainWindow window;
		public uint total_view {
			get {return get_children().length();}
		}
		
		public SplitView (MainWindow window) {
			
			homogeneous = false;
			expand = true;
			
			this.window = window;
			
		}
		
		public void add_view (ScratchNotebook view) {
			/*			
			if (current_row == rmax - 1) {
			    current_row = 0;
			    current_col++;
			}
			
			if (current_col == cmax - 1) 				
				if (current_row == rmax - 2) 
					window.toolbar.menu.view.set_sensitive (false);
			
			int row = rmax - current_row;
			             
			if (current_col != cmax) { 
			            
				if (current_col == 0)
					this.attach (view, current_row, current_row + 1,
							current_col, current_col + 1, AttachOptions.FILL, AttachOptions.FILL,
							0, 0);
				else 
					this.attach (view, current_row, current_row + 3,
							current_col, current_col + 1, AttachOptions.FILL, AttachOptions.FILL,
							0, 0);
			}
			             
			current_row++;
			*/
			pack_start (view);
						
			set_menu_item_sensitive ();
			
			set_focus_child (view);
			
			//set sensitive for remove menutitem
			if (get_children ().length() >= 2) 
				window.toolbar.menu.remove_view.set_sensitive (true);
			else 
				window.toolbar.menu.remove_view.set_sensitive (false);
			
			show_all ();
		}
		
		public bool remove_current_view () {
			remove (window.current_notebook);
			
			set_menu_item_sensitive ();
									
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
		
		public void set_menu_item_sensitive () {
			if (get_children ().length() == (max-1))
				window.toolbar.menu.view.set_sensitive (false);
			else
				window.toolbar.menu.view.set_sensitive (true);
		}
		
		
	}
    
} // Namespace
