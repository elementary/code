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

        private MainWindow window;

        public SourceView text_view;
        public TabLabel label;
		private ScratchNotebook notebook;
        public string filename = null;
        public bool saved = true;

        
        public Tab (ScratchNotebook parent, string labeltext, MainWindow window) {
            
            this.window = window;
        	this.notebook = parent;
            
            set_policy (PolicyType.AUTOMATIC, PolicyType.AUTOMATIC);
            notebook.set_tab_reorderable (this, true);            
            
            text_view = new SourceView (window);
            label = new TabLabel(this, labeltext);
            add (text_view);
            show_all();

        }
        

		private class SaveDialog : Window {

			private Tab caller;
			
			private Box headbox;
			private Label label;
			private Image image;

			private Box buttonbox;
			private Button discard;
			private Button cancel;
			private Button save;

			private Box container; 

			public SaveDialog(Tab callertab) {

				caller = callertab;

				label = new Label("Changes on this file aren't saved.\nDo you want to save changes before close this file?");
				image = new Image.from_stock(Stock.DIALOG_WARNING, IconSize.DIALOG);				
				
				headbox = new Box(Orientation.HORIZONTAL, 10);
				headbox.add(image);
				headbox.add(label);				
		
				discard = new Button.with_label(Stock.DISCARD);
					discard.set_use_stock(true);
					discard.clicked.connect(this.on_discard_clicked);
				cancel = new Button.with_label(Stock.CANCEL);
					cancel.set_use_stock(true);
					cancel.clicked.connect(this.on_cancel_clicked);
				save = new Button.with_label(Stock.SAVE);
					save.set_use_stock(true);
					save.clicked.connect(this.on_save_clicked);
		
				buttonbox = new Box (Orientation.HORIZONTAL, 10);
				buttonbox.set_homogeneous(true);
				buttonbox.add(discard);
				buttonbox.add(cancel);
				buttonbox.add(save);				
	
				container = new Box(Orientation.VERTICAL, 10);
				container.add(headbox);
				container.add(buttonbox);

				//window properties
				this.title = "";
				this.set_skip_taskbar_hint(true);
				this.set_modal(false);
				this.set_transient_for (caller.notebook.window);
				this.set_resizable(false);
		
				this.add(container);

			}
			
			public void run() {
				this.show_all();
			}
	
			//responses
			private void on_discard_clicked() {
				this.destroy();
				caller.close();
			}

			private void on_cancel_clicked() {
				this.destroy();				
			}

			private void on_save_clicked() { 
				this.destroy();				
				if (caller.save() == 0)
					caller.close();
			}


		}
        
        
		public void on_close_clicked() {
		
			if (this.saved == false) {
			
				var save_dialog = new SaveDialog(this);
				save_dialog.run();

						
		    } else this.close();
		    		    
    }
    
    public void close () {

    		message("closing: %s\n", this.filename);		    
		    var n = notebook.page_num(this);
		    notebook.remove_page(n);

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
            
            }
            
			message("Saving: %s", this.filename);
			
			try {
			
				FileUtils.set_contents (this.filename, this.text_view.buffer.text);
				this.saved = true;
				var name = this.filename.split("/");
				this.label.change_text (name[name.length-1]);
		        return 0;
		        
		    } catch (Error e) {
		    
				warning("Error: %s\n", e.message);
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

		public MainWindow window; //used in dialog

	    public ScratchNotebook (MainWindow parent) {
	    
	    	this.window = parent;
			this.set_scrollable (true);
			
	    }

        public int add_tab (string labeltext="New file") {
            
            var new_tab = new Tab (this, labeltext, window);
            return this.append_page (new_tab, new_tab.label);
            
        }
        
    }
} // Namespace
