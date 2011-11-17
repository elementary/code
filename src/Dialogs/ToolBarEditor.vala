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
using Granite.Widgets;

namespace Scratch.Dialogs {

    public class ToolBarEditor : Dialog {

        private MainWindow window;
        
        TreeView view_avaible;
        TreeView view_showed;
        
        public ToolBarEditor (string? title, MainWindow? window) {
            
            this.window = window;
            this.title = title;
            this.type_hint = Gdk.WindowTypeHint.DIALOG;
            this.set_modal (true);
            this.set_transient_for (window);
            
            set_default_size (400, 300);
            
            create_layout ();

            response.connect (on_response);

        }

        private void create_layout () {
			
			var vbox = new VBox (false, 5);
			
			var l = new Label (_("Select the elements to show in the toolbar. You can customize them also with drag n drop"));
			vbox.pack_start (l, false, false, 5);

			var next = new ToolButton.from_stock (Stock.GO_FORWARD);
			var back = new ToolButton.from_stock (Stock.GO_BACK);
			var bbox = new VBox (false, 5);
			bbox.pack_start (next, true, true, 5);
			bbox.pack_start (back, true, true, 5);
			
			var hbox = new HBox (false, 5);
			hbox.pack_start (treeview_avaible (), true, true, 5);
			hbox.pack_start (bbox, false, false, 5);
			hbox.pack_start (treeview_showed (), true, true, 5);
			
			vbox.pack_start (hbox, true, true, 5);
			
            add_button (Stock.CLOSE, ResponseType.ACCEPT);                       
            
            ((Gtk.Box)get_content_area()).add (vbox);
            
        }

        private void on_response (int response_id) {
            
            this.hide ();

        }
        
        TreeView treeview_avaible () {
            view_avaible = new TreeView ();
			
			var column_icon = new TreeViewColumn.with_attributes ("", new CellRendererText (), "text", 0);

			var column_name = new TreeViewColumn.with_attributes (_("Avaible elements"), new CellRendererText (), "text", 1);

			view_avaible.insert_column (column_icon, 0);
			view_avaible.insert_column (column_name, 1);
						
			var listmodel = new ListStore (3, typeof(Gdk.Pixbuf), typeof(string));
			view_avaible.set_model (listmodel);
			
			return view_avaible;
        }
        
        TreeView treeview_showed () {
            view_showed = new TreeView ();
			
			var column_icon = new TreeViewColumn.with_attributes ("", new CellRendererText (), "text", 0);

			var column_name = new TreeViewColumn.with_attributes (_("Avaible elements"), new CellRendererText (), "text", 1);

			view_showed.insert_column (column_icon, 0);
			view_showed.insert_column (column_name, 1);
						
			var listmodel = new ListStore (3, typeof(Gdk.Pixbuf), typeof(string));
			view_showed.set_model (listmodel);
			
			return view_showed;
        }
        
    }

} // Namespace
