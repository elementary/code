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

public class Scratch.Widgets.DocumentView : Gtk.Box {
    public signal void document_change (Services.Document? document);
    public signal void empty ();

    private weak MainWindow _window;
    public MainWindow window {
        get {
            return _window;
        }
        construct set {
            _window = value;
        }
    }

    public Services.Document current_document {
        get {
            return (Services.Document) notebook.current;
        }
        set {
            notebook.current = value;
        }
    }

    private Granite.Widgets.DynamicNotebook notebook;
    public GLib.List<Services.Document> docs;

    public uint view_id = -1;
    public bool is_closing = false;

    public DocumentView (MainWindow window) {
        Object (window: window);
    }

    construct {
        orientation = Gtk.Orientation.VERTICAL;

        docs = new GLib.List<Services.Document> ();

        // Layout
        notebook = new Granite.Widgets.DynamicNotebook ();
        notebook.allow_restoring = true;
        notebook.allow_new_window = true;
        notebook.allow_drag = true;
        notebook.allow_duplication = true;
        notebook.tab_added.connect (on_doc_added);
        notebook.tab_removed.connect (on_doc_removed);
        notebook.tab_reordered.connect (on_doc_reordered);
        notebook.tab_moved.connect (on_doc_moved);
        notebook.group_name = "scratch-text-editor";

        notebook.new_tab_requested.connect (() => {
            new_document ();
        });

        notebook.close_tab_requested.connect ((tab) => {
            if ((tab as Services.Document).file != null)
                tab.restore_data = (tab as Services.Document).get_uri ();
            return (tab as Services.Document).close ();
        });

        notebook.tab_switched.connect ((old_tab, new_tab) => {
            document_change (new_tab as Services.Document);
            save_current_file (new_tab as Services.Document);
        });

        notebook.tab_restored.connect ((label, restore_data, icon) => {
            var doc = new Services.Document (window.main_actions, File.new_for_uri (restore_data));
            open_document (doc);
        });

        notebook.tab_duplicated.connect ((tab) => {
            duplicate_document (tab as Services.Document);
        });

        pack_start (notebook, true, true, 0);

        show_all ();
    }

    private string unsaved_file_path_builder () {
        var timestamp = new DateTime.now_local ();
        string new_text_file = _("Text file from ") + timestamp.format ("%Y-%m-%d %H:%M:%S");

        return Application.instance.data_home_folder_unsaved + new_text_file;
    }

    public void new_document () {
        var file = File.new_for_path (unsaved_file_path_builder ());
        try {
            file.create (FileCreateFlags.PRIVATE);

            var doc = new Services.Document (window.main_actions, file);
            doc.create_page ();

            notebook.insert_tab (doc, -1);
            current_document = doc;

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

            notebook.insert_tab (doc, -1);
            current_document = doc;

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
                current_document = nth_doc;
                warning ("This Document was already opened! Not opening a duplicate!");
                return;
            }
        }

        doc.create_page ();
        doc.working = true;
        current_document = doc;

        Idle.add (() => { // This ensures new tab is drawn before opening document.
            doc.open.begin ((obj, res) => {
                if (doc.open.end (res)) {
                    doc.focus ();
                    save_opened_files ();
                } else  {
                   notebook.remove_tab (doc);
                }
            });

            return false;
        });
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

            notebook.insert_tab (doc, -1);
            current_document = doc;
            doc.focus ();
        } catch (Error e) {
            warning ("Cannot copy \"%s\": %s", original.get_basename (), e.message);
        }
    }

    public void next_document () {
        uint current_index = docs.index (current_document) + 1;
        if (current_index < docs.length ()) {
            var next_doc = docs.nth_data (current_index++);
            current_document = next_doc;
            next_doc.focus ();
        }
    }

    public void previous_document () {
        uint current_index = docs.index (current_document);
        if (current_index > 0) {
            var previous_doc = docs.nth_data (--current_index);
            current_document = previous_doc;
            previous_doc.focus ();
        }
    }

    public void close_document (Services.Document doc) {
        notebook.remove_tab (doc);
        doc.close ();
    }

    public void close_current_document () {
        var doc = current_document;
        if (doc != null) {
            if (notebook.close_tab_requested (doc)) {
                notebook.remove_tab (doc);
            }
        }
    }

    public bool is_empty () {
        return docs.length () == 0;
    }

    public new void focus () {
        current_document.focus ();
    }

    private void on_doc_added (Granite.Widgets.Tab tab) {
        var doc = tab as Services.Document;
        doc.main_actions = window.main_actions;

        docs.append (doc);
        doc.source_view.focus_in_event.connect (on_focus_in_event);
        doc.source_view.drag_data_received.connect (drag_received);
        doc.source_view.drag_motion.connect (drag_motion);
    }

    private void on_doc_removed (Granite.Widgets.Tab tab) {
        var doc = tab as Services.Document;

        docs.remove (doc);
        doc.source_view.focus_in_event.disconnect (on_focus_in_event);
        doc.source_view.drag_data_received.disconnect (drag_received);
        doc.source_view.drag_motion.disconnect (drag_motion);

        // Check if the view is empty
        if (is_empty ()) {
            empty ();
        }

        if (!is_closing) {
            save_opened_files ();
        }
    }

    private void on_doc_moved (Granite.Widgets.Tab tab, int x, int y) {
        var doc = tab as Services.Document;

        var other_window = window.app.new_window ();
        other_window.move (x, y);

        DocumentView other_view = other_window.add_view ();

        // We need to make sure switch back to the main thread
        // when we are modifiying Gtk widgets shared by two threads.
        Idle.add (() => {
            notebook.remove_tab (doc);
            other_view.notebook.insert_tab (doc, -1);

            return false;
        });
    }

    private void on_doc_reordered (Granite.Widgets.Tab tab, int new_pos) {
        var doc = tab as Services.Document;

        docs.remove (doc);
        docs.insert (doc, new_pos);

        doc.focus ();

        save_opened_files ();
    }

    private bool on_focus_in_event () {
        var doc = current_document;
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
            open_document (doc);

            Gtk.drag_finish (ctx, true, false, time);
        }
    }

    public void save_opened_files () {
        string[] opened_files = {};

        notebook.tabs.foreach ((tab) => {
            var doc = tab as Scratch.Services.Document;
            if (doc.file != null && doc.exists ()) {
                opened_files += doc.file.get_uri ();
            }
        });

        if (view_id == 1) {
            settings.opened_files_view1 = opened_files;
        } else {
            settings.opened_files_view2 = opened_files;
        }
    }

    public void save_current_file (Services.Document? current_document) {
        string file_uri = "";

        if (current_document != null) {
            file_uri = current_document.file.get_uri();
        }

        if (file_uri != "") {
            if (view_id == 1) {
                settings.focused_document_view1 = file_uri;
            } else {
                settings.focused_document_view2 = file_uri;
            }
        } else {
            if (view_id == 1) {
                settings.schema.reset ("focused-document_view1");
            } else {
                settings.schema.reset ("focused-document_view2");
            }
        }
    }
}
