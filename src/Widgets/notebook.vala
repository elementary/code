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
using Pango;

namespace Scratch.Widgets {

    public class Tab : ScrolledWindow {

        public SourceView text_view;
        public TabLabel label;
        public string filename;
        public bool saved; //TODO define its initial value...

		public Notebook notebook;        
        
        public Tab (Notebook parent) {
        
        	notebook = parent;
            
            set_policy (PolicyType.AUTOMATIC, PolicyType.AUTOMATIC);
            notebook.set_tab_reorderable (this, true);            
            
            text_view = new SourceView ();
            label = new TabLabel(this);
            
            add (text_view);
            filename = null;
            show_all();

        }
        
		public void on_close_clicked() {
		
		    stdout.printf("closing: %s\n", this.filename);
		    //TODO check saved status
		    var n = notebook.page_num(this);
		    notebook.remove_page(n);
		    
    }
        

    }
    
    public class TabLabel : HBox {
	
		public HBox tablabel;
        public Label label;
        public Button close;
        
        public TabLabel(Tab my_tab, string textlabel="New file") {
            
            label = new Label (textlabel);
            
            var image = new Image.from_stock(Stock.CLOSE, IconSize.MENU);
            close = new Button ();
            close.clicked.connect (my_tab.on_close_clicked);
            close.set_relief (ReliefStyle.NONE);
            close.set_image (image);
            
            //"close" as first, because eOs HIG
            pack_start (close, false, false, 0);
            pack_start (label, false, false, 0);
            
            this.show_all ();		
        }


        public void change_text (string text) {
            label.set_text (text);
        }


    }
    
    public class ScratchNotebook : Notebook {

        public ScratchNotebook () {
            this.set_scrollable (true);
        }

        public int add_tab (string tabtext="New file") {
            
            var new_tab = new Tab (this);
            return this.append_page (new_tab, new_tab.label);
            
        }
        
    }
} // Namespace
