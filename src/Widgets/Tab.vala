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
using Gdk;

using Scratch.Dialogs;

namespace Scratch.Widgets {

    public class Tab : ScrolledWindow {

        public SourceView text_view { set; get; }
        public TabLabel label;
        public string filename = null;
        public bool saved = true;
        public signal void closed ();
        public Scratch.Services.Document document;


        public Tab (ScratchNotebook parent, string labeltext) {

            set_policy (PolicyType.AUTOMATIC, PolicyType.AUTOMATIC);

            text_view = new SourceView ();
            text_view.buffer.changed.connect (buffer_changed);

            label = new TabLabel(this, labeltext);

            add (text_view);
            show_all();
        }

        public void change_syntax_highlight_for_filename (string filename) {
            text_view.change_syntax_highlight_for_filename (filename);
        }

        public void on_close_clicked() {
            var doc = document;

            if (doc.can_write () && text_view.modified == true) {

                var save_dialog = new SaveDialog(this);
                save_dialog.run();

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
                text_view.modified = false;

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
            //}

            message ("Saving: %s", this.filename);

            try {

                var or = File.new_for_path (this.filename);
                var bk = File.new_for_path (this.filename + "~");

                if (!bk.query_exists ()) {
                    try {
                        or.copy (bk, FileCopyFlags.NONE);
                    } catch (Error e) {
                        warning (e.message);
                    }
                }
                
                make_backup ();
                
                FileUtils.set_contents (this.filename, this.text_view.buffer.text);
                this.saved = true;
                text_view.modified = false;

                //updating the tab label
                var f = File.new_for_path (this.filename);
                label.label.set_text (f.get_basename ());

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
        
        void buffer_changed () {
            var top = get_toplevel () as Scratch.MainWindow; 
            top.set_undo_redo (); 
            
            if (filename != null) {
                string f, b;
                
                try {
                    f = text_view.buffer.text;
			        FileUtils.get_contents (this.filename + "~", out b);
                } catch (Error e) {
                    return;
                }

                if (f == b) {
                    top.main_actions.get_action ("Revert").set_sensitive (false);
                    //top.toolbar.revert_button.set_sensitive (false);
                    top.main_actions.get_action ("Save").set_sensitive (false);
                    top.toolbar.save_button.set_sensitive (false);
                    label.label.set_text(label.label_text);
                    text_view.modified = false;
                }
                else {
                    top.main_actions.get_action ("Revert").set_sensitive (true);
                    //top.toolbar.revert_button.set_sensitive (true);
                    top.main_actions.get_action ("Save").set_sensitive (true);
                    top.toolbar.save_button.set_sensitive (true);
                    label.label.use_markup = true;
                    label.label.set_markup ("<span font_style='italic'>%s</span>".printf(label.label_text));
                    text_view.modified = true;                    
                } 
            }
            else {
                top.main_actions.get_action ("Revert").set_sensitive (false);
                //top.toolbar.revert_button.set_sensitive (false);
                //top.main_actions.get_action ("Save").set_sensitive (false);
                //top.toolbar.revert_button.set_sensitive (false);
            }
         }
        
    }
}
