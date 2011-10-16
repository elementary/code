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
    
	public class ScratchNotebook : Notebook {
		
		public MainWindow window; //used in dialog		
		//public ScratchWelcome welcome_screen;

	    public ScratchNotebook (MainWindow parent) {
	    
	    	this.window = parent;
			//this.welcome_screen = new ScratchWelcome(this);
	    	
	    	this.switch_page.connect (on_switch_page);
	    	
	    	expand = true;
			set_scrollable (true);
			set_group_name ("s");
			
			drag_end.connect (on_drag_end);
			
			show_all ();
			
			page_removed.connect(on_page_removed);
			page_added.connect(on_page_added);
			
	    }

        void on_page_added(Gtk.Widget w, uint page_num)
        {
            /* If it is a Tab (something where we can put text, not a welcome screen)
             * we want to hide the tabs and the welcome screen.
             */
            if(w is Tab) {
                //welcome_screen.hide ();
                set_show_tabs(true);
            }
        }
	    
	    void on_page_removed(Gtk.Widget w, uint page_num)
	    {
	    	if(get_n_pages () == 0) {
	    		((Gtk.Container)get_parent()).remove(this);
	    	}
	    	
	    	set_tab ();
	    	/*if (get_n_pages() == 0 || (get_n_pages() == 1 && welcome_screen.get_parent() != null))
	    		show_welcome ();*/
	    }
	    
        public int add_tab (string labeltext="New file") {
            var new_tab = new Tab (this, labeltext, window);
            int index = this.append_page (new_tab, new_tab.label);
            set_tab_reorderable(new_tab, true);
            set_tab_detachable(new_tab, true);
            
            window.toolbar.set_actions (true);
            
            set_tab ();
            
            return index; 
        }
		
		public void set_tab () {
		    
		    debug ("%s", get_n_pages ().to_string ());
		    
		    if (get_n_pages () == 1)
		        set_show_tabs (false);
		    else
		        set_show_tabs (true);
		}
		
		public void on_switch_page (Widget page, uint number) {
		
			var tab = page as Tab;
            if(tab == null) {
                /* Welcome screen */
                return;
            }
            /* Ok, it is a real Tab then */
			if (tab.filename != null)
				window.set_window_title (tab.filename);
			else
				window.set_window_title ("Scratch");
				//tab.text_view.set_file (tab.filename, tab.text_view.buffer.text);
			
			GtkSource.Language lang;
            lang = tab.text_view.manager.get_language ( window.toolbar.combobox.get_active_id () );
            tab.text_view.buffer.set_language (lang);
  
            //window.set_undo_redo ();
						
		}
		
        public void on_drag_end (DragContext context) {
			
			/*List<Widget> children = ((Gtk.Container)get_parent ()).get_children ();
			int i;
			
			for (i = 0; i!=children.length(); i++) {//ScratchNotebook notebook in children) { 
				var notebook = children.nth_data (i) as ScratchNotebook;
				if (notebook.get_n_pages () == 0) {
					window.split_view.remove (notebook);
				}
			}
			window.split_view.set_menu_item_sensitive ();*/
		}
        
		/*public void show_welcome () {

			if (window.split_view.get_children().length() == 1) {
                this.set_show_tabs (false);
                if(welcome_screen.get_parent() == null)
                {
                    page = append_page(welcome_screen, null);
                }
                welcome_screen.show_all();
                window.set_undo_redo ();
                window.toolbar.set_actions (false);
                window.title = window.TITLE;
			}
		
			else {
                warning ("I won't put a Welcome Screen if there are some others views.");
			}
		
		}*/
		
		public void show_tabs_view () {
			
			/*if (welcome_screen.active) {
			
				this.remove_page (this.page_num(welcome_screen));
				this.set_show_tabs (true);
				this.welcome_screen.active = false;
				
			}*/
			
		}



        
    }
    
	public class ScratchWelcome : Granite.Widgets.Welcome {
	
		public bool active = false;
		private ScratchNotebook notebook;
		MainWindow window;
		
		public ScratchWelcome(MainWindow window) {
	
			base(_("No files are open."), _("Open a file to begin editing."));
	
			//notebook = caller;
	
			append(Stock.OPEN, _("Open file"), _("Open a saved file."));
			append(Stock.NEW, _("New file"), _("Create a new empty file."));
			this.activated.connect (on_activated);
			this.window = window;
			
			show_all();

		}
		
		private void on_activated(int index) {

			switch (index) {
				case 0: //open
				window.main_actions.get_action ("Open").activate ();
				break;

				case 1: // new
				window.main_actions.get_action ("New tab").activate ();
				break;
			
			}

			
		}
	
	
	}
     
} // Namespace
