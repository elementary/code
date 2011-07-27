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
        public Label label;
//        public Label label;
        public string filename;
        
        public Tab () {
            
            set_policy (PolicyType.AUTOMATIC, PolicyType.AUTOMATIC);
            
            text_view = new SourceView ();
            
            add (text_view);
//            label = new Label ("New file");
            filename = null;
            show_all();

        }

    }
    
    public class TabLabel : HBox {

        public HBox tablabel;
        public Label label;
        public Button close;
        
        public TabLabel(string textlabel="New file") {
            
            label = new Label (textlabel);
            
            var image = new Image.from_stock(Stock.CLOSE, IconSize.MENU);
            close = new Button ();
            close.clicked.connect (on_close_clicked);
            close.set_relief (ReliefStyle.NONE);
            close.set_image (image);
            
            pack_start (label, false, false, 0);
            pack_start (close, false, false, 0);
            
            this.show_all ();		
        }
        
        public void on_close_clicked() {
            
            return;	
            
        }
        
    }
    
    public class ScratchNotebook : Notebook {

        //widgets for the label
        public TabLabel tablabel;
        public Label label;
        public Button close;

        public ScratchNotebook () {
            this.set_scrollable (true);
        }

        public int add_tab (string tabtext="New file") {
            
            //tab label
            this.tablabel = new TabLabel ();
            //create the tab
            var new_tab = new Tab ();
            set_tab_reorderable (new_tab, true);
            return this.append_page (new_tab, tablabel);
        }
        
        public void change_label (string label) {
            
            var tablabel = (TabLabel) this.get_nth_page (this.get_current_page());
            tablabel.label.set_text (label);
            
        }

        //events
        public void on_close_clicked () {
            
            return;	
            
        }



    }
} // Namespace
