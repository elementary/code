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
        public signal void closed ();

        
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
			//notebook.window.set_undo_redo ();
			
			if (window.current_tab.filename != null) {
					text_view.change_syntax_highlight_for_filename (filename);
					window.set_combobox_language (window.current_tab.filename);
			}
			window.set_undo_redo ();
			return true;
			
		}
		
        public void close () {
			
    		message("closing: %s\n", this.filename);		    
		    var n = notebook.page_num(this);
		    closed ();	
		    notebook.remove_page(n);
		    
		    if (window.split_view.get_children().length() >= 2) {
		        window.split_view.remove (notebook);
		        window.toolbar.menu.remove_view.set_sensitive (false);
		    }
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
				text_view.modified = false;
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
}
