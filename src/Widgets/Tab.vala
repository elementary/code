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

    public class Tab : Gtk.Grid {

        public SourceView text_view { set; get; }
        public TabLabel label;
        public string filename = null;
        public bool saved = true;
        public signal void closed ();
        public Scratch.Services.Document document;

        public Tab (ScratchNotebook parent, string labeltext) {

            var scrolled_window = new Gtk.ScrolledWindow (null, null);
            scrolled_window.set_policy (PolicyType.AUTOMATIC, PolicyType.AUTOMATIC);

            text_view = new SourceView ();

            label = new TabLabel (this, labeltext);
            
            scrolled_window.add (text_view);

            attach (scrolled_window, 0, 1, 1, 1);
            scrolled_window.hexpand = true;
            scrolled_window.vexpand = true;
            
            show_all();
            
            scrolled_window.grab_focus ();
        }
        
        public void set_overlay (Gtk.Widget widget) {
            ((Gtk.Container)widget.get_parent ()).remove (widget);
            attach (widget, 0, 0, 1, 1);
            show_all ();
        } 

        public void change_syntax_highlight_for_filename (string? filename) {
            if (filename != null)
                text_view.change_syntax_highlight_for_filename (filename);
        }

        public void on_close_clicked() {
            if (document.can_write () && document.modified == true) {

                var save_dialog = new SaveOnCloseDialog (document.name, ((MainWindow)get_toplevel ()));
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
            closed ();
            ((Gtk.Notebook)get_parent()).remove(this);
        
        }

        public int save () {

            if (this.filename == null) {
                string new_filename = null;

                //show dialog
                var filech = new FileChooserDialog ("Save as", (Gtk.Window)get_toplevel (), FileChooserAction.SAVE, null);
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

            message ("Saving: %s", this.filename);

            try {

                FileUtils.set_contents (this.filename, this.text_view.buffer.text);
                this.saved = true;
				
				//updating the tab label and window title
                var f = File.new_for_path (this.filename);
                label.label.set_text (f.get_basename ());
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
                var filech = new FileChooserDialog ("Save as", (Gtk.Window)get_toplevel (), FileChooserAction.SAVE, null);
                filech.add_button (Stock.CANCEL, ResponseType.CANCEL);
                filech.add_button (Stock.SAVE, ResponseType.ACCEPT);
                filech.set_default_response (ResponseType.ACCEPT);

                if (this.filename != null)
                    filech.set_filename (this.filename);

                var response = filech.run ();

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
            //}

            message ("Saving: %s", this.filename);

            try {
     
                if (settings.make_backup) make_backup ();
                
                FileUtils.set_contents (this.filename, this.text_view.buffer.text);
                this.saved = true;

                //updating the tab label and the window title
                var f = File.new_for_path (this.filename);
                label.label.set_text (f.get_basename ());
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
        
        public void make_backup () {
            var or = File.new_for_path (this.filename);
            var bk = File.new_for_path (this.filename + "~");

            if (!bk.query_exists ()) {
                try {
                    or.copy (bk, FileCopyFlags.NONE);
                } catch (Error e) {
                    warning (e.message);
                }
            }
        }
        
    }
}
