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
		
		Gtk.Widget? focused_widget = null;

		public bool is_empty { get; set; default = true; }
		
		public SplitView (MainWindow window) {
			
			homogeneous = false;
			expand = true;
			
			this.window = window;
			
		}
		
		public void add_view (ScratchNotebook view) {
			pack_start (view);
						
			//set_menu_item_sensitive ();
			
			//set_focus_child (view);
			
			//set sensitive for remove menutitem
			if (get_children ().length() >= 2) 
				window.toolbar.menu.remove_view.set_sensitive (true);
			else 
				window.toolbar.menu.remove_view.set_sensitive (false);
			
			view.focus_in_event.connect(on_notebook_focus);
			view.page_added.connect (recompute_empty);
			view.page_removed.connect (recompute_empty);
		}
		
		bool is_empty_or_without_tabs () {
			foreach(var widget in get_children ())
			{
				if(!(widget is Notebook)) {
					return false;
				}
				else {
					foreach(var page in ((Notebook)widget).get_children ()) {
						return false;
					}
				}
			}
			return true;
		}
		
		void recompute_empty ()
		{
			is_empty = is_empty_or_without_tabs ();
		}
		
		bool on_notebook_focus(Gtk.Widget notebook, Gdk.EventFocus event) {
			focused_widget = notebook;
			return false;
		}
		
		public bool remove_current_view () {
			if (focused_widget == null)
				return false;
			else {
				remove(focused_widget);
				focused_widget = null;
			}
			return true;
		/*
			bool r = false;
			for (int i=0; i!=window.current_notebook.get_n_pages(); i++) {
				window.current_notebook.set_current_page (i);
				var tab = (Tab) window.current_notebook.get_nth_page (i);
				string isnew = tab.label.label.get_text () [0:1];
				
				if (isnew == "*")
					tab.on_close_clicked ();
				else
					r = true;
			}
			remove (window.current_notebook);
			
			set_menu_item_sensitive ();
									
			if (get_children().length() >= 2)
				return true;
			else 
				return false;	*/					
		}
		
		public void show_save_dialog (ScratchNotebook notebook) {
			int n;
								
			for (n = 0; n!=notebook.get_n_pages(); n++) {
				notebook.set_current_page (n);
				var label = (Tab) notebook.get_nth_page (n);
					
				string isnew = label.label.label.get_text () [0:1];
			
				if (isnew == "*") {
					var save_dialog = new SaveDialog (label);
					save_dialog.run();
				}
			}
		}
		
		public weak ScratchNotebook get_current_notebook () {
			if(focused_widget != null && focused_widget.get_parent() != this) {
				focused_widget = null;
			}
			weak ScratchNotebook child = focused_widget as ScratchNotebook;
			if (child == null) {
			    child = get_children ().nth_data (0) as ScratchNotebook;
			    if( child == null) {
			        critical ("No valid notebook for the split view? Let's create one.");
			        var note = new ScratchNotebook(window);
			        add_view (note);
			        focused_widget = note;
			        child = note;
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
