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

public class Scratch.Widgets.DocumentView : Granite.Widgets.DynamicNotebook {
    public signal void document_change (Services.Document? document, DocumentView parent);
    public signal void empty ();

    public unowned MainWindow window { get; construct set; }

    public Services.Document current_document {
        get {
            return (Services.Document) current;
        }
        set {
            current = value;
        }
    }

    public GLib.List<Services.Document> docs;

    public uint view_id = -1;
    public bool is_closing = false;

    private Gtk.CssProvider style_provider;

    public DocumentView (MainWindow window) {
        base ();
        allow_restoring = true;
        allow_new_window = true;
        allow_drag = true;
        allow_duplication = true;
        group_name = Constants.PROJECT_NAME;
        this.window = window;
    }

    construct {
        docs = new GLib.List<Services.Document> ();

        // Layout
        tab_added.connect (on_doc_added);
        tab_removed.connect (on_doc_removed);
        tab_reordered.connect (on_doc_reordered);
        tab_moved.connect (on_doc_moved);

        new_tab_requested.connect (() => {
            new_document ();
        });

        close_tab_requested.connect ((tab) => {
            var document = tab as Services.Document;
            if (!document.is_file_temporary && document.file != null) {
                tab.restore_data = document.get_uri ();
            }

            return document.do_close ();
        });

        tab_switched.connect ((old_tab, new_tab) => {
            document_change (new_tab as Services.Document, this);
            save_current_file (new_tab as Services.Document);
        });

        tab_restored.connect ((label, restore_data, icon) => {
            var doc = new Services.Document (window.actions, File.new_for_uri (restore_data));
            open_document (doc);
        });

        tab_duplicated.connect ((tab) => {
            duplicate_document (tab as Services.Document);
        });

        style_provider = new Gtk.CssProvider ();
        update_inline_tab_colors ();
        settings.notify["style-scheme"].connect (update_inline_tab_colors);
        Gtk.StyleContext.add_provider_for_screen (
            Gdk.Screen.get_default (),
            style_provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        );

        /* SplitView shows view as required */
    }

    private void update_inline_tab_colors () {
        var sssm = Gtk.SourceStyleSchemeManager.get_default ();
        var style_context = get_style_context ();

        if (settings.style_scheme in sssm.scheme_ids) {
            var theme = sssm.get_scheme (settings.style_scheme);
            var text_color_data = theme.get_style ("text");

            // Default gtksourceview background color is white
            var color = "#FFFFFF";
            if (text_color_data != null) {
                // If the current style has a background color, use that
                color = text_color_data.background;
            }

            var define = "@define-color tab_base_color %s;".printf (color);
            style_context.add_class (Gtk.STYLE_CLASS_INLINE_TOOLBAR);
            try {
                style_provider.load_from_data (define);
                return;
            } catch (Error e) {
                critical ("Unable to set inline tab styling, going back to classic notebook tabs");
            }
        }

        // Fallback to a non inline toolbar if something went wrong above
        style_context.remove_class (Gtk.STYLE_CLASS_INLINE_TOOLBAR);
    }

    private string unsaved_file_path_builder () {
        var timestamp = new DateTime.now_local ();
        
        string new_text_file = _("Text file from %s:%d").printf (timestamp.format ("%Y-%m-%d %H:%M:%S"), timestamp.get_microsecond ());

        return Path.build_filename (Application.instance.data_home_folder_unsaved, new_text_file);
    }

    public void new_document () {
        var file = File.new_for_path (unsaved_file_path_builder ());
        try {
            file.create (FileCreateFlags.PRIVATE);

            var doc = new Services.Document (window.actions, file);

            insert_tab (doc, -1);
            current_document = doc;

            doc.focus ();
            save_opened_files ();
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

            var doc = new Services.Document (window.actions, file);

            insert_tab (doc, -1);
            current_document = doc;

            doc.focus ();
            save_opened_files ();
        } catch (Error e) {
            critical ("Cannot insert clipboard: %s", clipboard);
        }
    }

    public void open_document (Services.Document doc, bool focus = true) {
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

        insert_tab (doc, -1);
        if (focus) {
            current_document = doc;
        }

        Idle.add_full (GLib.Priority.LOW, () => { // This helps ensures new tab is drawn before opening document.
            doc.open.begin (false, (obj, res) => {
                doc.open.end (res);
                doc.focus ();
                save_opened_files ();
            });

            return false;
        });
    }

    // Set a copy of content
    public void duplicate_document (Services.Document original) {
        try {
            var file = File.new_for_path (unsaved_file_path_builder ());
            file.create (FileCreateFlags.PRIVATE);

            var doc = new Services.Document (window.actions, file);
            doc.source_view.set_text (original.get_text ());

            if (settings.autosave) {
                doc.save.begin (true);
            }

            insert_tab (doc, -1);
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
        remove_tab (doc);
        doc.do_close ();
    }

    public void close_current_document () {
        var doc = current_document;
        if (doc != null) {
            if (close_tab_requested (doc)) {
                remove_tab (doc);
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
        doc.actions = window.actions;

        docs.append (doc);
        doc.source_view.focus_in_event.connect_after (on_focus_in_event);
        doc.source_view.drag_data_received.connect (drag_received);
    }

    private void on_doc_removed (Granite.Widgets.Tab tab) {
        var doc = tab as Services.Document;

        docs.remove (doc);
        doc.source_view.focus_in_event.disconnect (on_focus_in_event);
        doc.source_view.drag_data_received.disconnect (drag_received);

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
            remove_tab (doc);
            other_view.insert_tab (doc, -1);

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
            document_change (doc, this);
        }

        return false;
    }

    private void drag_received (Gtk.Widget w, Gdk.DragContext ctx, int x, int y, Gtk.SelectionData sel,  uint info, uint time) {
        var uris = sel.get_uris ();
        foreach (var filename in uris) {
            var file = File.new_for_uri (filename);
            var doc = new Services.Document (window.actions, file);
            open_document (doc);
        }

       Gtk.drag_finish (ctx, true, false, time);
    }

    public void save_opened_files () {
        string[] opened_files = {};

        tabs.foreach ((tab) => {
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
