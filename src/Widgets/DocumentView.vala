// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/***
  BEGIN LICENSE

  Copyright (C) 2013 Mario Guerriero <mario@elementaryos.org>
                2024 Colin Kiama <colinkiama@gmail.com>
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
     public enum TargetType {
        URI_LIST
    }

    public signal void document_change (Services.Document? document, DocumentView parent);
    public signal void request_placeholder ();
    public signal void tab_added (Services.Document document);
    public signal void tab_removed (Services.Document document);

    public GLib.List<Services.Document> docs;

    private Services.Document _current_document;
    public Services.Document current_document {
        get {
            return _current_document;
        }
        set {
            if (is_closing) {
                return;
            }

            _current_document = value;
            document_change (_current_document, this);
            _current_document.focus ();
            save_focused_document_uri (current_document);
            if (tab_view.selected_page != value.tab) {
                tab_view.selected_page = value.tab;
            }
        }
    }

    public unowned MainWindow window { get; construct; }

    public bool is_closing = false;
    public bool outline_visible { get; set; default = false; }
    public int outline_width { get; set; }


    private Hdy.TabView tab_view;
    private Hdy.TabBar tab_bar;

    public DocumentView (Scratch.MainWindow window) {
        Object (
            window: window,
            orientation: Gtk.Orientation.VERTICAL,
            hexpand: true,
            vexpand: true
        );
    }

    construct {
        docs = new GLib.List<Services.Document> ();
        var app_instance = (Gtk.Application) GLib.Application.get_default ();
        tab_view = new Hdy.TabView () {
            hexpand = true,
            vexpand = true
        };

        tab_view.menu_model = new GLib.Menu ();
        tab_view.setup_menu.connect (tab_view_setup_menu);
        tab_view.notify["selected-page"].connect (() => {
            current_document = search_for_document_in_tab (tab_view.selected_page);
        });

        var new_tab_button = new Gtk.Button.from_icon_name ("list-add-symbolic") {
            relief = Gtk.ReliefStyle.NONE,
            tooltip_markup = Granite.markup_accel_tooltip (
                app_instance.get_accels_for_action (MainWindow.ACTION_PREFIX + MainWindow.ACTION_NEW_TAB),
                _("New Tab")
            )
        };

        new_tab_button.clicked.connect (() => {
            new_document ();
        });

        var tab_history_button = new Gtk.MenuButton () {
            image = new Gtk.Image.from_icon_name ("document-open-recent-symbolic", Gtk.IconSize.MENU),
            tooltip_text = _("Closed Tabs"),
            use_popover = false
        };

        tab_bar = new Hdy.TabBar () {
            autohide = false,
            expand_tabs = false,
            inverted = true,
            start_action_widget = new_tab_button,
            end_action_widget = tab_history_button,
            view = tab_view,
        };

        // TabView tab events
        tab_view.close_page.connect ((tab) => {
            var doc = search_for_document_in_tab (tab);
            if (doc == null) {
                tab_view.close_page_finish (tab, true);
            } else {
                doc.do_close.begin (false, (obj, res) => {
                    var should_close = doc.do_close.end (res);
                    if (should_close) {
                        before_doc_removed (doc);
                    }

                    tab_view.close_page_finish (tab, should_close);
                });
            }

            return true;
        });

        tab_view.page_detached.connect (on_doc_removed);
        tab_view.page_reordered.connect (on_doc_reordered);

        notify["outline-visible"].connect (update_outline_visible);
        Scratch.saved_state.bind ("outline-width", this, "outline-width", DEFAULT);
        this.notify["outline-width"].connect (() => {
            foreach (var doc in docs) {
                doc.set_outline_width (outline_width);
            }
        });

        // Handle Drag-and-drop of files onto add-tab button to create document
        Gtk.TargetEntry uris = {"text/uri-list", 0, TargetType.URI_LIST};
        var drag_dest_targets = new Gtk.TargetList ({uris});
        tab_bar.set_extra_drag_dest_targets (drag_dest_targets);
        // tab_bar.extra_drag_data_received (drag_received);

        add (tab_bar);
        add (tab_view);
    }

    public void close_document (Services.Document doc) {
        tab_view.close_page (doc.tab);
    }

    public void close_tabs_to_right () {
        if (current_document != null) {
            tab_view.close_pages_after (current_document.tab);
        }
    }

    public void close_other_tabs () {
        if (current_document != null) {
            tab_view.close_pages_before (current_document.tab);
        }
    }

    public void duplicate_tab () {
        if (current_document != null) {
            new_document_from_clipboard (current_document.get_text ());
        }
    }

    public Services.Document search_for_document_in_tab (Hdy.TabPage tab) {
        unowned var current = docs;

        bool should_end_search = false;
        Services.Document matching_document = null;

        while (!should_end_search) {
            if (current == null || current.length () == 0) {
                should_end_search = true;
            } else {
                var doc = current.data;
                if (doc.tab == tab) {
                    matching_document = doc;
                    should_end_search = true;
                }

                current = current.next;
            }

        }

        return matching_document;
    }

    public void new_document () {
        var file = File.new_for_path (unsaved_file_path_builder ());
        try {
            file.create (FileCreateFlags.PRIVATE);

            var doc = new Services.Document (window.actions, file);
            // Must open document in order to unlock it.
            open_document (doc);
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

            open_document (doc);

        } catch (Error e) {
            critical ("Cannot insert clipboard: %s", clipboard);
        }
    }


    public void open_document (Services.Document doc, bool focus = true, int cursor_position = 0, SelectionRange range = SelectionRange.EMPTY) {
       for (int n = 0; n <= docs.length (); n++) {
            var nth_doc = docs.nth_data (n);
            if (nth_doc == null) {
                continue;
            }

            if (nth_doc.file != null && nth_doc.file.get_uri () == doc.file.get_uri ()) {
                if (focus) {
                    current_document = nth_doc;
                }

                debug ("This Document was already opened! Not opening a duplicate!");
                if (range != SelectionRange.EMPTY) {
                    Idle.add_full (GLib.Priority.LOW, () => { // This helps ensures new tab is drawn before opening document.
                        current_document.source_view.select_range (range);
                        save_opened_files ();

                        return false;
                    });
                }

                return;
            }
        }

        insert_document (doc, (int) docs.length ());
        if (focus) {
            current_document = doc;
        }

        Idle.add_full (GLib.Priority.LOW, () => { // This helps ensures new tab is drawn before opening document.
            doc.open.begin (false, (obj, res) => {
                doc.open.end (res);
                if (focus && doc == current_document) {
                    doc.focus ();
                }

                if (range != SelectionRange.EMPTY) {
                    doc.source_view.select_range (range);
                } else if (cursor_position > 0) {
                    doc.source_view.cursor_position = cursor_position;
                }

                save_opened_files ();
            });

            return false;
        });
    }

    public void next_document () {
        uint current_index = docs.index (current_document) + 1;
        if (current_index < docs.length ()) {
            var next_doc = docs.nth_data (current_index++);
            current_document = next_doc;
            next_doc.focus ();
        } else if (docs.length () > 0) {
            var next_doc = docs.nth_data (0);
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
        } else if (docs.length () > 0) {
            var previous_doc = docs.nth_data (docs.length () - 1);
            current_document = previous_doc;
            previous_doc.focus ();
        }
    }

    public void request_placeholder_if_empty () {
        if (docs.length () == 0) {
            request_placeholder ();
        }
    }

    public void save_opened_files () {
        if (privacy_settings.get_boolean ("remember-recent-files")) {
            var vb = new VariantBuilder (new VariantType ("a(si)"));
            docs.foreach ((doc) => {
                if (doc.file != null && doc.exists ()) {
                    vb.add ("(si)", doc.file.get_uri (), doc.source_view.cursor_position);
                }
            });

            Scratch.settings.set_value ("opened-files", vb.end ());
        }
    }

    public void update_outline_visible () {
        docs.@foreach ((doc) => {
            doc.show_outline (outline_visible);
        });
    }

    public new void focus () {
        current_document.focus ();
    }

    private void tab_view_setup_menu (Hdy.TabPage? page) {
        if (page == null) {
            return;
        }


        var tab_menu = (Menu) tab_view.menu_model;
        tab_menu.remove_all ();

        var close_tab_section = new Menu ();
        close_tab_section.append (_("Close Tabs to the Right"), MainWindow.ACTION_PREFIX + MainWindow.ACTION_CLOSE_TABS_TO_RIGHT);
        close_tab_section.append (_("Close Other Tabs"), MainWindow.ACTION_PREFIX + MainWindow.ACTION_CLOSE_OTHER_TABS);
        close_tab_section.append (_("Close Tab"), MainWindow.ACTION_PREFIX + MainWindow.ACTION_CLOSE_TAB + "::");

        var open_tab_section = new Menu ();
        open_tab_section.append (_("Duplicate"), MainWindow.ACTION_PREFIX + MainWindow.ACTION_DUPLICATE_TAB);

        tab_menu.append_section (null, close_tab_section);
        tab_menu.append_section (null, open_tab_section);
    }

    private void insert_document (Scratch.Services.Document doc, int pos) {
        var page = tab_view.insert (doc, pos);
        doc.init_tab (page);
        on_doc_added (doc);
        if (Scratch.saved_state.get_boolean ("outline-visible")) {
            debug ("setting outline visible");
            doc.show_outline (true);
        }
    }

    private string unsaved_file_path_builder (string extension = "txt") {
        var timestamp = new DateTime.now_local ();

        string new_text_file = _("Text file from %s:%d").printf (
                                    timestamp.format ("%Y-%m-%d %H:%M:%S"), timestamp.get_microsecond ()
                                );

        return Path.build_filename (window.app.data_home_folder_unsaved, new_text_file) + "." + extension;
    }

    private void on_doc_added (Services.Document doc) {
        if (doc == null) {
            print ("No tab!\n");
            return;
        }

        docs.append (doc);
        doc.actions = window.actions;

        Scratch.Services.DocumentManager.get_instance ().add_open_document (doc);

        if (!doc.is_file_temporary) {
           rename_tabs_with_same_title (doc);
        }

        doc.source_view.focus_in_event.connect_after (on_focus_in_event);
        tab_added (doc);
    }

    private void before_doc_removed (Services.Document doc) {
        docs.remove (doc);
        tab_removed (doc);
        Scratch.Services.DocumentManager.get_instance ().remove_open_document (doc);

        doc.source_view.focus_in_event.disconnect (on_focus_in_event);

        if (docs.length () > 0) {
            if (!doc.is_file_temporary) {
                foreach (var d in docs) {
                    rename_tabs_with_same_title (d);
                }
            }
        }

        if (!is_closing) {
            save_opened_files ();
        }
    }

    private void on_doc_removed (Hdy.TabPage tab, int position) {
        request_placeholder_if_empty ();
    }

    private void on_doc_reordered (Hdy.TabPage tab, int new_position) {
        var doc = search_for_document_in_tab (tab);
        docs.remove (doc);
        docs.insert (doc, new_position);
        current_document = doc;
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

    private void rename_tabs_with_same_title (Services.Document doc) {
        if (doc.is_file_temporary) {
            return;
        }

        string doc_tab_name = doc.file.get_basename ();
        foreach (var d in docs) {
            if (d.is_file_temporary) {
                continue;
            }

            string new_tabname_doc, new_tabname_d;

            if (Utils.find_unique_path (d.file, doc.file, out new_tabname_d, out new_tabname_doc)) {
                if (d.title.length < new_tabname_d.length) {
                    d.tab_name = new_tabname_d;
                }

                if (doc_tab_name.length < new_tabname_doc.length) {
                    doc_tab_name = new_tabname_doc;
                }
            }
        }

        doc.tab_name = doc_tab_name;
    }

    private void save_focused_document_uri (Services.Document? current_document) {
        if (privacy_settings.get_boolean ("remember-recent-files")) {
            var file_uri = "";

            if (current_document != null) {
                file_uri = current_document.file.get_uri ();
            }

            Scratch.settings.set_string ("focused-document", file_uri);
        }
    }
}
