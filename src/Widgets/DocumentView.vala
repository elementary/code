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

namespace Scratch.Widgets {
    
    public class DocumentView : Gtk.Box {
        
        // Widgets
        private Granite.Widgets.DynamicNotebook notebook;
        
        public GLib.List<Document> docs;
        
        // Signals
        public signal void document_change (Document? document);
        public signal void empty ();
        
        public DocumentView () {
            orientation = Orientation.VERTICAL;
            
            docs = new GLib.List<Document> ();
            
            // Layout
            this.notebook = new Granite.Widgets.DynamicNotebook ();
            this.notebook.tab_added.connect ((tab) => {
                new_document (tab);
            });
            this.notebook.tab_switched.connect ((old_tab, new_tab) => {
                document_change (new_tab as Document);
            });
            
            this.pack_start (notebook, true, true, 0);
            
            show_all ();
        }
        
        public void new_document (owned Granite.Widgets.Tab? tab = null) {
            
            var doc = new Document ();
            doc.create_page ();
            
            if (tab != null)
                this.notebook.remove_tab (tab);
            
            this.notebook.insert_tab (doc, -1);
            
            this.notebook.tab_removed.connect ((closing_tab) => {
                return close_document_from_tab (doc, closing_tab);
            });
            
            doc.focus ();
            
            doc.source_view.focus_in_event.connect (() => {
                document_change (doc);
                return true;
            });
            
            this.notebook.current = doc;
            this.docs.append (doc);
        }
        
        public void open_document (Document doc) {
            bool already_opened = false;
            for (int n = 0; n <= docs.length (); n++) {
                if (docs.nth_data (n) == null)
                    continue;
                if (docs.nth_data (n).file != null 
                        && docs.nth_data (n).file.get_uri () == doc.file.get_uri ()) {
                    already_opened = true;
                    this.notebook.current = docs.nth_data (n);
                }
            }
            
            if (already_opened) {
                warning ("This Document was already opened! Not opening a duplicate!");
                return;
            }
            
            doc.create_page ();
            
            this.notebook.insert_tab (doc, -1);
            this.notebook.tab_removed.connect ((closing_tab) => {
                return close_document_from_tab (doc, closing_tab);
            });
            doc.source_view.focus_in_event.connect (() => {
                document_change (doc);
                return true;
            });
            
            doc.focus ();
            
            this.notebook.current = doc;
            this.docs.append (doc);
        }
        
        public void close_document (Document doc) {
            this.notebook.remove_tab (doc);
            doc.close ();
            this.docs.remove (doc);
        }
        
        private bool close_document_from_tab (Document doc, Granite.Widgets.Tab closing_tab) {
            // Close the Document object too
            if (closing_tab == doc) {
                bool ret_value = doc.close ();
                // Check if the view is empty
                if (this.notebook.get_children ().length () <= 1)
                    empty ();
                return ret_value;
            }
            else
                return true;
        }
        
        public Document? get_current_document () {
            return (this.notebook.current as Document);
        }
        
        public void set_current_document (Document doc) {
            this.notebook.current = doc;
        }
        
        public bool is_empty () {
            return (this.docs.length () == 0);
        }
        
    }
    
}
