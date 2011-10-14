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

using Scratch.Dialogs;

namespace Scratch.Widgets {
	
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
			bool r = false;
			for (int i=0; i!=window.current_notebook.get_n_pages(); i++) {
				window.current_notebook.set_current_page (i);
				var tab = (Tab) window.current_notebook.get_nth_page (i);
				string isnew = tab.label.label.get_text () [0:1];
				
				if (isnew == "*")
					tab.on_close_clicked ();
				else
					r = true;
					//show_save_dialog (window.current_notebook);
				
					//remove (window.current_notebook);
			}
			//if (r)
				remove (window.current_notebook);
			
			set_menu_item_sensitive ();
									
			if (get_children().length() >= 2)
				return true;
			else 
				return false;						
		}
		
		public void show_save_dialog (ScratchNotebook notebook) {
			int n;
								
			for (n = 0; n!=notebook.get_n_pages(); n++) {
				notebook.set_current_page (n);
				var label = (Tab) notebook.get_nth_page (n);
					
				string isnew = label.label.label.get_text () [0:1];
			
				if (isnew == "*") {
					var save_dialog = new SaveDialog (label);
					//var save_dialog = new SaveOnCloseDialog(label.label.label.get_text (), window);
					save_dialog.run();
				}
			}
		}
		
		public weak ScratchNotebook get_current_notebook () {
			weak ScratchNotebook child = get_focus_child () as ScratchNotebook;
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
}
