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

namespace Scratch.Widgets {

    public class DocumentView : Gtk.Box {

        // Parent window
        private weak MainWindow window;

        // Widgets
        public Granite.Widgets.DynamicNotebook notebook;

        public GLib.List<Services.Document> docs;

        public Services.Document current {
            set {
                notebook.current = value;
            }
        }

        // Signals
        public signal void document_change (Services.Document? document);
        public signal void empty ();

        public DocumentView (MainWindow window) {
            orientation = Gtk.Orientation.VERTICAL;
            this.window = window;

            docs = new GLib.List<Services.Document> ();

            // Layout
            this.notebook = new Granite.Widgets.DynamicNotebook ();
            this.notebook.allow_restoring = true;
            this.notebook.allow_new_window = true;
            this.notebook.allow_drag = true;
            this.notebook.allow_duplication = true;
            this.notebook.tab_added.connect (on_doc_added);
            this.notebook.tab_removed.connect (on_doc_removed);
            this.notebook.tab_reordered.connect (on_doc_reordered);
            this.notebook.tab_moved.connect (on_doc_moved);
            this.notebook.group_name = "scratch-text-editor";

            this.notebook.new_tab_requested.connect (() => {
                new_document ();
            });

            this.notebook.close_tab_requested.connect ((tab) => {
                if ((tab as Services.Document).file != null)
                    tab.restore_data = (tab as Services.Document).get_uri ();
                return (tab as Services.Document).close ();
            });

            this.notebook.tab_switched.connect ((old_tab, new_tab) => {
                document_change (new_tab as Services.Document);
            });

            this.notebook.tab_restored.connect ((label, restore_data, icon) => {
                var doc = new Services.Document (window.main_actions, File.new_for_uri (restore_data));
                open_document (doc);
            });

            this.notebook.tab_duplicated.connect ((tab) => {
                duplicate_document (tab as Services.Document);
            });

            this.pack_start (notebook, true, true, 0);

            show_all ();
        }

        private string unsaved_file_path_builder () {
            var timestamp = new DateTime.now_local ();
            string new_text_file = _("Text file from ") + timestamp.format ("%Y-%m-%d %H:%M:%S");

            return ScratchApp.instance.data_home_folder_unsaved + new_text_file;
        }

        public void new_document () {
            var file = File.new_for_path (unsaved_file_path_builder ());
            try {
                file.create (FileCreateFlags.PRIVATE);

                var doc = new Services.Document (window.main_actions, file);
                doc.create_page ();

                this.notebook.insert_tab (doc, -1);
                this.notebook.current = doc;

                doc.focus ();
            } catch (Error e) {
                critical (e.message);
            }
        }

        public void new_document_from_clipboard (string clipboard) {
            var file = File.new_for_path (unsaved_file_path_builder ());

            // Set clipboard content
            try {
                file.create (FileCreateFlags.PRIVATE);
                file.replace_contents (clipboard.data, null, false, 0, null);

                var doc = new Services.Document (window.main_actions, file);
                doc.create_page ();

                this.notebook.insert_tab (doc, -1);
                this.notebook.current = doc;

                doc.focus ();
            } catch (Error e) {
                critical ("Cannot insert clipboard: %s", clipboard);
            }
        }

        public void open_document (Services.Document doc) {
            for (int n = 0; n <= docs.length (); n++) {
                var nth_doc = docs.nth_data (n);
                if (nth_doc == null) {
                    continue;
                }

                if (nth_doc.file != null && nth_doc.file.get_uri () == doc.file.get_uri ()) {
                    this.notebook.current = nth_doc;
                    warning ("This Document was already opened! Not opening a duplicate!");
                    return;
                }
            }

            doc.create_page ();
            this.notebook.insert_tab (doc, -1);
            this.notebook.current = doc;
            doc.focus ();
        }

        // Set a copy of content
        public void duplicate_document (Services.Document original) {
            try {
                var file = File.new_for_path (unsaved_file_path_builder ());
                file.create (FileCreateFlags.PRIVATE);

                var doc = new Services.Document (window.main_actions, file);
                doc.create_page ();
                string s;
                doc.file.replace_contents (original.source_view.buffer.text.data, null, false, 0, out s);
                this.notebook.insert_tab (doc, -1);
                this.notebook.current = doc;
                doc.focus ();
            } catch (Error e) {
                warning ("Cannot copy \"%s\": %s", original.get_basename (), e.message);
            }
        }

        public void next_document () {
            uint current_index = docs.index (get_current_document ()) + 1;
            if (current_index < docs.length ()) {
                var next_doc = docs.nth_data (current_index++);
                this.notebook.current = next_doc;
                next_doc.focus ();
            }
        }

        public void previous_document () {
            uint current_index = docs.index (get_current_document ());
            if (current_index > 0) {
                var previous_doc = docs.nth_data (--current_index);
                this.notebook.current = previous_doc;
                previous_doc.focus ();
            }
        }

        public void close_document (Services.Document doc) {
            this.notebook.remove_tab (doc);
            doc.close ();
        }

        public void close_current_document () {
            var doc = get_current_document ();
            if (doc != null) {
                if (this.notebook.close_tab_requested (doc)) {
                    this.notebook.remove_tab (doc);
                }
            }
        }

        public Services.Document? get_current_document () {
            return this.notebook.current as Services.Document;
        }

        public void set_current_document (Services.Document doc) {
            this.notebook.current = doc;
        }

        public bool is_empty () {
            return this.docs.length () == 0;
        }

        public new void focus () {
            get_current_document ().focus ();
        }

        private void on_doc_added (Granite.Widgets.Tab tab) {
            var doc = tab as Services.Document;
            doc.main_actions = window.main_actions;

            this.docs.append (doc);
            doc.source_view.focus_in_event.connect (this.on_focus_in_event);
            doc.source_view.drag_data_received.connect (this.drag_received);
            doc.source_view.drag_motion.connect (this.drag_motion);

        }

        private void on_doc_removed (Granite.Widgets.Tab tab) {
            var doc = tab as Services.Document;

            this.docs.remove (doc);
            doc.source_view.focus_in_event.disconnect (this.on_focus_in_event);
            doc.source_view.drag_data_received.disconnect (this.drag_received);
            doc.source_view.drag_motion.disconnect (this.drag_motion);

            // Check if the view is empty
            if (this.is_empty ()) {
                empty ();
            }
        }

        private void on_doc_moved (Granite.Widgets.Tab tab, int x, int y) {
            var doc = tab as Services.Document;
            Idle.add (() => {
                var other_window = window.app.new_window ();
                other_window.move (x, y);

                DocumentView other_view = other_window.add_view ();

                this.notebook.remove_tab (doc);
                other_view.notebook.insert_tab (doc, -1);
                return false;
            });
        }

        private void on_doc_reordered (Granite.Widgets.Tab tab, int new_pos) {
            var doc = tab as Services.Document;

            this.docs.remove (doc);
            this.docs.insert (doc, new_pos);

            doc.focus ();
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

        private bool drag_motion (Gdk.DragContext ctx, int x, int y, uint time){
            return true;
        }

        private void drag_received (Gdk.DragContext ctx, int x, int y, Gtk.SelectionData sel,  uint info, uint time){
            var uris = sel.get_uris ();
            foreach (var filename in uris) {
                var file = File.new_for_uri (filename);
                var doc = new Services.Document (window.main_actions, file);
                this.open_document (doc);

                Gtk.drag_finish (ctx, true, false, time);
            }
        }
    }
}
