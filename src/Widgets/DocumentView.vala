// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/***
  BEGIN LICENSE

  Copyright (C) 2013 Mario Guerriero <mario@elementaryos.org>
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

using Scratch.Services;
using Granite.Widgets;

namespace Scratch.Widgets {
    
    public class DocumentView : Gtk.Box {

        // Parent window
        private weak MainWindow window;
        
        // Widgets
        public DynamicNotebook notebook;
        
        public GLib.List<Document> docs;
        
        public Scratch.Services.Document current {
            set {
                notebook.current = value;
            }
        }
        
        // Signals
        public signal void document_change (Document? document);
        public signal void empty ();

        public DocumentView (MainWindow window) {
            orientation = Orientation.VERTICAL;
            this.window = window;
            
            docs = new GLib.List<Document> ();
            
            // Layout
            this.notebook = new DynamicNotebook ();
            this.notebook.allow_restoring = true;
            this.notebook.allow_new_window = true;
            this.notebook.allow_drag = true;
            this.notebook.tab_added.connect (on_doc_added);
            this.notebook.tab_removed.connect (on_doc_removed);
            this.notebook.tab_reordered.connect (on_doc_reordered);
            this.notebook.tab_moved.connect (on_doc_moved);
            this.notebook.group_name = "scratch-text-editor";

            this.notebook.new_tab_requested.connect (() => {
                new_document ();
            });

            this.notebook.close_tab_requested.connect ((tab) => {
                if ((tab as Document).file != null)
                    tab.restore_data = (tab as Document).get_uri ();
                return (tab as Document).close ();
            });

            this.notebook.tab_switched.connect ((old_tab, new_tab) => {
                document_change (new_tab as Document);
            });

            this.notebook.tab_restored.connect ((label, restore_data, icon) => {
                var doc = new Document (window.main_actions, File.new_for_uri (restore_data));
                open_document (doc);
            });
            
            this.pack_start (notebook, true, true, 0);
            
            show_all ();
        }
        
        public void new_document () {
            var doc = new Document (window.main_actions);
            doc.create_page ();
           
            this.notebook.insert_tab (doc, -1);
            this.notebook.current = doc;
            
            doc.focus ();
        }
        
        public void open_document (Document doc) {
            for (int n = 0; n <= docs.length (); n++) {
                if (docs.nth_data (n) == null)
                    continue;
                if (docs.nth_data (n).file != null 
                        && docs.nth_data (n).file.get_uri () == doc.file.get_uri ()) {
                    this.notebook.current = docs.nth_data (n);
                    docs.nth_data (n).load_content ();
                    warning ("This Document was already opened! Not opening a duplicate!");
                    return;
                }
            }
           
            doc.create_page ();
            
            this.notebook.insert_tab (doc, -1);
            this.notebook.current = doc;
            
            doc.focus ();
        }
        
        public void next_document () {
            uint current_index = docs.index (get_current_document ()) + 1;
            if (current_index < docs.length ()) {
                Document? next_doc = docs.nth_data (current_index++);
                this.notebook.current = next_doc;
                next_doc.focus();
            } 
        }
        
        public void previous_document () {
            uint current_index = docs.index (get_current_document ());
            if (current_index > 0) {
                Document? previous_doc = docs.nth_data (--current_index);
                this.notebook.current = previous_doc;
                previous_doc.focus();   
            }        
        }
        
        public void close_document (Document doc) {
            this.notebook.remove_tab (doc);
            doc.close ();
        }
        
        public Document? get_current_document () {
            return this.notebook.current as Document;
        }
        
        public void set_current_document (Document doc) {
            this.notebook.current = doc;
        }
        
        public bool is_empty () {
            return this.docs.length () == 0;
        }
        
        public new void focus () {
            get_current_document ().focus ();
        }
        
        private void on_doc_added (Granite.Widgets.Tab tab) {
            var doc = tab as Document;
            doc.main_actions = window.main_actions;

            this.docs.append (doc);
            doc.source_view.focus_in_event.connect (on_focus_in_event);

            // Update the opened-files setting
            if (settings.show_at_start == "last-tabs" && doc.file != null) {
                var files = settings.schema.get_strv ("opened-files");
                files += doc.file.get_uri ();
                settings.schema.set_strv ("opened-files", files);
            }
        }

        private void on_doc_removed (Granite.Widgets.Tab tab) {
            var doc = tab as Document;

            this.docs.remove (doc);
            doc.source_view.focus_in_event.disconnect (on_focus_in_event);

            // Update the opened-files setting
            if (settings.show_at_start == "last-tabs") {
                var files = settings.schema.get_strv ("opened-files");
                string[] opened = { "" };
                foreach (var file in files) {
                    if (file != doc.get_uri ())
                        opened += file;
                }
                settings.schema.set_strv ("opened-files", opened);
            }

            // Check if the view is empty
            if (this.is_empty ())
                empty ();
        }

        private void on_doc_moved (Tab tab, int x, int y) {
            var doc = tab as Document;

            var other_window = window.app.new_window ();
            other_window.move (x, y);

            DocumentView other_view = other_window.add_view ();

            this.notebook.remove_tab (doc);
            other_view.notebook.insert_tab (doc, -1);
        }

        private void on_doc_reordered (Tab tab) {
            (tab as Document).focus ();
        }

        private bool on_focus_in_event () {
            var doc = get_current_document ();

            if (doc == null) {
                warning ("Focus event callback cannot get current document");
            } else {
                document_change (doc);
            }

            return true;
        }
    }   
}