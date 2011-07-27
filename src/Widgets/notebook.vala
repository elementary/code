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
		private ScratchNotebook notebook;
        public string filename = null;
        public bool saved = true; //don't ask to save a new empty file

        
        public Tab (ScratchNotebook parent, string labeltext) {
        
        	notebook = parent;
            
            set_policy (PolicyType.AUTOMATIC, PolicyType.AUTOMATIC);
            notebook.set_tab_reorderable (this, true);            
            
            text_view = new SourceView ();
            label = new TabLabel(this, labeltext);
            add (text_view);
            show_all();

        }
        
		public void on_close_clicked() {
		
			if (this.saved == false) {

				var save_dialog = new Dialog();
//				var save_dialog = new Dialog.with_buttons("title", (Window) notebook.window, DialogFlags.MODAL, DialogFlags.DESTROY_WITH_PARENT);

				var message_box = new VBox(true, 10);
				var head = new HBox(false, 20);
				var head_label = new Label("Changes on this file aren't saved.");
				var head_img = new Image.from_stock(Stock.DIALOG_WARNING, IconSize.DIALOG);
				head.add(head_img);
				head.add(head_label);
				var label = new Label ("Do you want to save changes before close this file?");
				message_box.add(head);
				message_box.add(label);


				var content_area = (Box) save_dialog.get_content_area ();
				content_area.add(message_box);
				save_dialog.show_all();

					
				save_dialog.add_button ("Discard changes", ResponseType.REJECT);
				save_dialog.add_button ("Cancel", ResponseType.CANCEL);
				save_dialog.add_button ("Save", ResponseType.YES);
				save_dialog.set_default_response (ResponseType.CANCEL);

				var response = save_dialog.run();
				save_dialog.close();

				switch (response) {
					case ResponseType.REJECT:
					this.close();
					break;

					case ResponseType.YES:
					//TODO save and close
					break;
				
				}
							
		    } else this.close();
		    		    
    }
    
    private void close () {
    
    		message("closing: %s\n", this.filename);		    
		    var n = notebook.page_num(this);
		    notebook.remove_page(n);
    }
        

    }
    
    public class TabLabel : HBox {
	
		public HBox tablabel;
        public Label label;
        public Button close;
        
        public TabLabel(Tab my_tab, string labeltext) {
            
            label = new Label (labeltext);
            
            var image = new Image.from_stock(Stock.CLOSE, IconSize.MENU);
            close = new Button ();
            close.clicked.connect (my_tab.on_close_clicked);
            close.set_relief (ReliefStyle.NONE);
            close.set_image (image);
            
            //"close" as first, because eOs HIG
            //TODO: read button position from system!
            pack_start (close, false, false, 0);
            pack_start (label, false, false, 0);
            
            this.show_all ();		
        }


        public void change_text (string text) {
            label.set_text (text);
        }


    }
    
    public class ScratchNotebook : Notebook {

		public MainWindow window;

        public ScratchNotebook (MainWindow parent) {
        	window = parent;
			this.set_scrollable (true);
        }

        public int add_tab (string labeltext="New file") {
            
            var new_tab = new Tab (this, labeltext);
            return this.append_page (new_tab, new_tab.label);
            
        }
        
    }
} // Namespace
