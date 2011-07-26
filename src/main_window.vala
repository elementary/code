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

using Scratch.Widgets;
using Scratch.Dialogs;

namespace Scratch {
    
    public class MainWindow : Window {

        private const string TITLE = "Scratch";
        
        //widgets for the window
        public ScratchNotebook notebook;
        
        //widgets for the toolbars
        public Widgets.Toolbar toolbar;
        
        //dialogs
        public FileChooserDialog filech;
        public Preferences preferences;
        
        public MainWindow (string arg="") {
            if (arg == "") {
                this.title = this.TITLE;
            }
            else {
                this.title = arg;
            }
            
            load_file (arg);
            
            this.set_default_size (800, 500);
            //this.set_icon ("text-editor");
            //this.maximize ();
            
            //create_window();
            //connect_signals();
        }
        
        public void create_window () {

            //notebook, textview and its scrolledwindow
            this.notebook = new ScratchNotebook ();
            this.notebook.add_tab();
            
            this.toolbar = new Widgets.Toolbar (this);

            //adding all to the vbox
            var vbox = new VBox (false, 0);
            vbox.pack_start (toolbar, false, false, 0);
            vbox.pack_start (notebook, true, true, 0); 
            
            this.add (vbox);		
        
        }
        
        public void connect_signals () {

            //signals for the window
            this.destroy.connect (Gtk.main_quit);

            //signals for the toolbar
            toolbar.new_button.clicked.connect (on_new_clicked);
            toolbar.open_button.clicked.connect (on_open_clicked);
            toolbar.save_button.clicked.connect (on_save_clicked);
                
        }
        
        
        //signals functions
        public void on_new_clicked () {
            int new_tab_index = notebook.add_tab ();
            notebook.set_current_page (new_tab_index);
        }
        
        public void on_open_clicked () {

            this.filech = new FileChooserDialog ("Open a file", this, FileChooserAction.OPEN);
            filech.add_button (Stock.CANCEL, ResponseType.CANCEL);
            filech.add_button (Stock.OPEN, ResponseType.ACCEPT);
            filech.set_default_response (ResponseType.ACCEPT);
            
            //if (filech.run () == ResponseType.OK) {
                //	stdout.printf ("filename = %s\n".printf (filech.get_filename ()));
            //}
            filech.run ();
            filech.response.connect (on_response);
                
        }


        public void on_response (Dialog source, int response_id) {
            switch (response_id) {
                    case ResponseType.ACCEPT:
                        string filename = filech.get_filename();
                        if (filename != null) {
                            stdout.printf ("opening: %s\n".printf (filech.get_filename ()));
                            load_file ( filech.get_filename () );
                        }
                        
                        filech.close ();
                        break;
                    case ResponseType.CANCEL:
                        filech.close ();
                        break;
                }
            
        }
        
        
        public void on_save_clicked() {
            var current_tab = (Tab) notebook.get_nth_page (notebook.get_current_page());
            
            if (current_tab.filename == null) {
            
                this.filech = new FileChooserDialog ("Save as", this, FileChooserAction.SAVE);
                filech.add_button (Stock.CANCEL, ResponseType.CANCEL);
                    filech.add_button (Stock.SAVE, ResponseType.ACCEPT);
                filech.set_default_response (ResponseType.ACCEPT);
                
                filech.run ();
                filech.response.connect (on_save_response);
            
                //TODO "save as" dialog
            }
            
            save_file (current_tab.filename, current_tab.text_view.buffer.text);
        }
        
        
        public void on_save_response(Dialog source, int response_id) {
            switch (response_id) {
                case ResponseType.ACCEPT:
                    string filename = filech.get_filename();
                    var current_tab = (Tab) notebook.get_nth_page (notebook.get_current_page());
                    save_file (filename, current_tab.text_view.buffer.text);
                    break;
            }
        }
        
        //generic functions
        public void load_file (string filename) {
            if (filename != "") {
                try {
                    string text;
                    FileUtils.get_contents (filename, out text);
                    
                    //get the filename from strig filename =)
                    var name = filename.split("/");
                    
                    //create new tab
                    int tab_index = notebook.add_tab(name[name.length-1]);
                    notebook.set_current_page(tab_index);
                    var new_tab = (Tab) notebook.get_nth_page (tab_index);
                    
                    //set new values
                    new_tab.text_view.buffer.text = text;
                    new_tab.filename = filename;
                    this.title = this.TITLE + " - " + filename;
                        
                } catch (Error e) {
                    stderr.printf ("Error: %s\n", e.message);
                }
            }
                
        }
        
        public int save_file (string filename, string contents) {
        
            if (filename != "") {
                try {
                    FileUtils.set_contents (filename, contents);
                    var name = filename.split("/");
                    notebook.change_label (name[name.length-1]);
                    return 0;				
                } catch (Error e) {
                    stderr.printf ("Error: %s\n", e.message);
                    return 1;
                }
                    
            } else return 1;		
            
        }

    }
} // Namespace	
