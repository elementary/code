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
        
        public DocumentView () {
            orientation = Orientation.VERTICAL;
            
            docs = new GLib.List<Document> ();
            
            // Layout
            this.notebook = new DynamicNotebook ();
            this.notebook.allow_restoring = true;

            this.notebook.new_tab_requested.connect (() => {
                new_document ();
            });

            this.notebook.close_tab_requested.connect ((tab) => {
                if ((tab as Document).file != null)
                    tab.restore_data = (tab as Document).get_uri ();
                return close_document_from_tab ((tab as Document));
            });

            this.notebook.tab_switched.connect ((old_tab, new_tab) => {
                document_change (new_tab as Document);
            });

            this.notebook.tab_restored.connect ((label, restore_data, icon) => {
                var doc = new Document (File.new_for_uri (restore_data));
                open_document (doc);
            });
            
            this.pack_start (notebook, true, true, 0);
            
            show_all ();
        }
        
        public void new_document () {
            var doc = new Document ();
            doc.create_page ();
           
            this.notebook.insert_tab (doc, -1);
            
            doc.source_view.focus_in_event.connect (() => {
                document_change (doc);
                return true;
            });
            
            this.notebook.current = doc;
            add_document (doc);
            
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

            doc.source_view.focus_in_event.connect (() => {
                document_change (doc);
                return true;
            });
            
            this.notebook.current = doc;
            add_document (doc);
            
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
            remove_document (doc);
        }
        
        private bool close_document_from_tab (Document doc) {
            if (!doc.close ())
                return false;

            remove_document (doc);
            // Check if the view is empty
            if (this.notebook.get_children ().length () <= 1)
                empty ();
            
            return true;
        }
        
        private void add_document (Document doc) {
            this.docs.append (doc);
            // Update the opened-files setting
            if (settings.show_at_start == "last-tabs" && doc.file != null) {
                var files = settings.schema.get_strv ("opened-files");
                files += doc.file.get_uri ();
                settings.schema.set_strv ("opened-files", files);
            }
            
            // Handle Drag-and-drop functionality on source-view
            Gtk.TargetEntry uris = {"text/uri-list", 0, 0};
            Gtk.TargetEntry text = {"text/plain", 0, 0};
            Gtk.drag_dest_set (doc.source_view, Gtk.DestDefaults.ALL, {uris, text}, Gdk.DragAction.COPY);
            doc.source_view.drag_data_received.connect (this.drag_received);
        }
        
        private void remove_document (Document doc) {
            this.docs.remove (doc);
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
            
            doc.source_view.drag_data_received.disconnect (this.drag_received);
        }
        
        private void drag_received(Gdk.DragContext ctx, int x, int y, Gtk.SelectionData sel,  uint info, uint time){
            var uris = sel.get_uris ();
            if (uris.length > 0){
                for (var i = 0; i < uris.length; i++){
                    string filename = uris[i];
                    File file = File.new_for_uri(filename);
                    Document doc = new Document(file);
                    this.open_document(doc);
                }
                
                Gtk.drag_finish (ctx, true, false, time);
            }
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
        
        public new void focus () {
            get_current_document ().focus ();
        }
        
    }
    
}