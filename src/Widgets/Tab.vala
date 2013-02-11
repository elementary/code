// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/***
  BEGIN LICENSE

  Copyright (C) 2011-2012 Mario Guerriero <mefrio.g@gmail.com>
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

    public class Tab : Granite.Widgets.Tab {

        public Gtk.Box box_page;
        public SourceView? text_view { set; get; default = null; }
        public string filename = null;
        public bool saved = true;
        public signal void tab_closed ();
        public Scratch.Services.Document document;

        public Tab (ScratchNotebook parent, string labeltext) {
            base (labeltext, null, null);
            
            working = false; // Not spin
            
            box_page = new Gtk.Box (Orientation.VERTICAL, 0);
            
            var scrolled_window = new Gtk.ScrolledWindow (null, null);
            scrolled_window.set_policy (PolicyType.AUTOMATIC, PolicyType.AUTOMATIC);

            text_view = new SourceView ();
            
            label = labeltext;
            
            scrolled_window.add (text_view);

            box_page.pack_end (scrolled_window, true, true, 0);
            scrolled_window.hexpand = true;
            scrolled_window.vexpand = true;
            
            show_all();
            
            scrolled_window.grab_focus ();
            
            this.page = box_page;
        }
        
        public void set_overlay (Gtk.Widget widget) {
            ((Gtk.Container)widget.get_parent ()).remove (widget);
            box_page.pack_start (widget, false, true, 0);
            show_all ();
        } 

        public void change_syntax_highlight_for_filename (string? filename) {
            if (filename != null)
                text_view.change_syntax_highlight_for_filename (filename);
        }

        public void on_close_clicked() {
            if (document.can_write () && document.modified == true) {

                var save_dialog = new SaveOnCloseDialog (document.name, ((MainWindow)get_toplevel ()));
                document.focus_sourceview ();
                int response = save_dialog.run ();
                switch(response) {
                    case Gtk.ResponseType.CANCEL:
                        save_dialog.destroy ();
                        return;
                    case Gtk.ResponseType.YES:
                        document.save ();
                        close ();
                        break;
                    case Gtk.ResponseType.NO:
                        close ();
                        break;
                    }
                save_dialog.destroy ();

            } else this.close ();
        }

        public void close () {

            message("closing: %s\n", this.filename);
            tab_closed ();
            document.delete_backup ();
            ((Gtk.Notebook)get_parent()).remove(this);
        
        }
        
        public int save () {
            
            this.filename = document.filename;
            
            if (this.filename == null) {
                string new_filename = null;

                //show dialog
                var filech = new FileChooserDialog (_("Save as"), (Gtk.Window)get_toplevel (), FileChooserAction.SAVE, null);
                filech.add_button (Stock.CANCEL, ResponseType.CANCEL);
                filech.add_button (Stock.SAVE, ResponseType.ACCEPT);
                filech.set_default_response (ResponseType.ACCEPT);
                filech.key_press_event.connect ((ev) => {
                    if (ev.keyval == 65307) // Esc key
                        filech.destroy ();
                    return false;
                });
                
                var response = filech.run();

                switch (response) {
                    case ResponseType.ACCEPT:
                    new_filename = filech.get_uri();
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

            message ("Saving: %s", this.filename);

            try {

                document.filename = this.filename;
                    
                uint8[] data = text_view.buffer.text.data;
                string s;
                
                document.file.replace_contents (data, null, false, 0, out s);
                
                this.saved = true;
				
				//updating the tab label and window title
                label = document.file.get_basename ();
                var top = get_toplevel () as MainWindow;
                top.set_window_title (this.filename);				
                
                this.document.filename = this.filename;
                this.document.last_saved_text = this.text_view.buffer.text;
				this.document.modified = false;
				
				/* If autosave is on, 
				 * to avoid to change 
				 * the syntax highlight 
				 * at every change, 
				 * it is not changed 
				 */
    		    if (!settings.autosave)
    		        change_syntax_highlight_for_filename(this.filename);
				
                return 0;

            } catch (Error e) {

                warning ("Error: %s\n", e.message);
                return 1;

            }

        }

        public int save_as () {

            //if (this.filename == null) {
                string new_filename = null;

                //show dialog
                var filech = new FileChooserDialog (_("Save as"), (Gtk.Window)get_toplevel (), FileChooserAction.SAVE, null);
                filech.add_button (Stock.CANCEL, ResponseType.CANCEL);
                filech.add_button (Stock.SAVE, ResponseType.ACCEPT);
                filech.set_default_response (ResponseType.ACCEPT);
                filech.key_press_event.connect ((ev) => {
                    if (ev.keyval == 65307) // Esc key
                        filech.destroy ();
                    return false;
                });
                
                if (this.filename != null)
                    filech.set_filename (this.filename);

                var response = filech.run ();

                switch (response) {
                    case ResponseType.ACCEPT:
                        new_filename = filech.get_uri();
                        filech.close();
                    break;

                    case ResponseType.CANCEL:
                        filech.close();
                    return 1;

                }

                //check choise
                if (new_filename != null) this.filename = new_filename;
                else return 1;
            //}

            message ("Saving: %s", this.filename);

            try {
                     
                if (!document.exists) {
                    FileUtils.set_contents (this.filename, this.text_view.buffer.text);
                }
                else {
                    uint8[] data = text_view.buffer.text.data;
                    string s;
                
                    document.file.replace_contents (data, null, false, 0, out s);
                }
                
                this.saved = true;

                //updating the tab label and the window title
                label = Filename.display_basename (filename);
                var top = get_toplevel () as MainWindow;
                top.set_window_title (this.filename);

                this.document.filename = this.filename;
                this.document.last_saved_text = this.text_view.buffer.text;
                this.document.modified = false;
                
                /* If autosave is on, 
				 * to avoid to change 
				 * the syntax highlight 
				 * at every change, 
				 * it is not changed 
				 */
    		    if (!settings.autosave)
    		        change_syntax_highlight_for_filename(this.filename);
                
                return 0;

            } catch (Error e) {

                warning ("Error: %s\n", e.message);
                return 1;

            }

        }
        
    }
}
