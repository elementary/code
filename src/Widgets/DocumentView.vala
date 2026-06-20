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
    const int TAB_HISTORY_MAX_ITEMS = 20;

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
            if (tab_view.selected_page != value.tab && value.tab != null) {
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
    private weak Hdy.TabPage? tab_menu_target = null;
    private Gtk.CssProvider style_provider;
    private Gtk.MenuButton tab_history_button;

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

        tab_view.menu_model = create_menu_model ();
        tab_view.setup_menu.connect (tab_view_setup_menu);
        tab_view.notify["selected-page"].connect (() => {
            if (tab_view.selected_page == null) {
                return;
            }

            current_document = tab_view.selected_page.child as Services.Document;
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

        tab_history_button = new Gtk.MenuButton () {
            image = new Gtk.Image.from_icon_name ("document-open-recent-symbolic", Gtk.IconSize.MENU),
            tooltip_text = _("Closed Tabs"),
            use_popover = false,
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
            var doc = tab.child as Services.Document;
            if (doc == null || doc.closing) {
                return true; // doc.do_close () already called once
            }

            if (doc == null) {
                tab_view.close_page_finish (tab, true);
            } else {
                doc.do_close.begin (false, (obj, res) => {
                    var should_close = doc.do_close.end (res);
                    // Ensure removed doc is saved by handling this first
                    if (!is_closing) {
                        update_opened_files_setting ();
                    }
                    //`page-detached` handler will perform rest of necessary cleanup
                    tab_view.close_page_finish (tab, should_close);
                });
            }

            return true;
        });

        tab_view.page_attached.connect (on_doc_added);
        tab_view.page_detached.connect (on_page_detached);
        tab_view.page_reordered.connect (on_doc_reordered);
        tab_view.create_window.connect (on_doc_to_new_window);

        style_provider = new Gtk.CssProvider ();
        Gtk.StyleContext.add_provider_for_screen (
            Gdk.Screen.get_default (),
            style_provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        );

        update_inline_tab_colors ();
        Scratch.settings.changed["style-scheme"].connect (update_inline_tab_colors);
        Scratch.settings.changed["follow-system-style"].connect (update_inline_tab_colors);
        var granite_settings = Granite.Settings.get_default ();
        granite_settings.notify["prefers-color-scheme"].connect (update_inline_tab_colors);

        notify["outline-visible"].connect (update_outline_visible);
        Scratch.saved_state.bind ("outline-width", this, "outline-width", DEFAULT);
        this.notify["outline-width"].connect (() => {
            foreach (var doc in docs) {
                doc.set_outline_width (outline_width);
            }
        });

        // Handle Drag-and-drop of files onto add-tab button to create document
        Gtk.TargetEntry uris = {"text/uri-list", 0, TargetType.URI_LIST};
        Gtk.drag_dest_set (tab_bar, Gtk.DestDefaults.ALL, {uris}, Gdk.DragAction.COPY);
        tab_bar.drag_data_received.connect (drag_received);

        add (tab_bar);
        add (tab_view);
    }

    private void update_inline_tab_colors () {
        var style_scheme = "";
        if (settings.get_boolean ("follow-system-style")) {
            var system_prefers_dark = Granite.Settings.get_default ().prefers_color_scheme == Granite.Settings.ColorScheme.DARK;
            if (system_prefers_dark) {
                style_scheme = "elementary-dark";
            } else {
                style_scheme = "elementary-light";
            }
        } else {
            style_scheme = Scratch.settings.get_string ("style-scheme");
        }

        var sssm = Gtk.SourceStyleSchemeManager.get_default ();
        if (style_scheme in sssm.scheme_ids) {
            var theme = sssm.get_scheme (style_scheme);
            var text_color_data = theme.get_style ("text");

            // Default gtksourceview background color is white
            var color = "#FFFFFF";
            if (text_color_data != null) {
                // If the current style has a background color, use that
                color = text_color_data.background;
            }

            var define = "@define-color tab_base_color %s;".printf (color);
            try {
                style_provider.load_from_data (define);
            } catch (Error e) {
                critical ("Unable to set inline tab styling, going back to classic notebook tabs");
            }
        }
    }

    public void transfer_tab_to_new_window () {
        var target = tab_menu_target ?? tab_view.selected_page;

        if (target == null) {
            return;
        }

        var new_window = new MainWindow (false);
        tab_view.transfer_page (target, new_window.document_view.tab_view, 0);
    }

    public void close_document (Services.Document? doc = null) {
        if (doc != null) {
            tab_view.close_page (doc.tab);
            return;
        }

        var target = tab_menu_target ?? tab_view.selected_page;
        if (target == null) {
            return;
        }

        tab_view.close_page (target);
    }

    public void close_tabs_to_right () {
        var target = tab_menu_target ?? tab_view.selected_page;

        if (target == null) {
            return;
        }

        if (current_document != null) {
            tab_view.close_pages_after (target);
        }
    }

    public void close_other_tabs () {
        var target = tab_menu_target ?? tab_view.selected_page;

        if (target == null) {
            return;
        }

        if (current_document != null) {
            tab_view.close_other_pages (target);
        }
    }

    public void duplicate_tab () {
        var target = tab_menu_target ?? tab_view.selected_page;
        if (target == null) {
            return;
        }

        var original_doc = target.get_child () as Services.Document;
        if (original_doc == null) {
            return;
        }

        try {
            var file = File.new_for_path (unsaved_duplicated_file_path_builder (original_doc.file.get_basename ()));
            file.create (FileCreateFlags.PRIVATE);

            var doc = new Services.Document (window.actions, file);
            doc.source_view.set_text (original_doc.get_text ());
            doc.source_view.language = original_doc.source_view.language;
            if (Scratch.settings.get_boolean ("autosave")) {
                doc.save_with_hold.begin (true);
            }

            insert_document (doc, tab_view.get_page_position (target) + 1);
            current_document = doc;
            doc.focus ();
        } catch (Error e) {
            warning ("Cannot copy \"%s\": %s", original_doc.get_basename (), e.message);
        }
    }

    public void new_document () {
        var file = File.new_for_path (unsaved_file_path_builder ());
        try {
            file.create (FileCreateFlags.PRIVATE);

            var doc = new Services.Document (window.actions, file);
            // Must open document in order to unlock it.
            open_document.begin (doc);
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

            open_document.begin (doc);


        } catch (Error e) {
            critical ("Cannot insert clipboard: %s", clipboard);
        }
    }

    public async void open_document (Services.Document doc, bool focus = true, int cursor_position = 0, SelectionRange range = SelectionRange.EMPTY) {
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
                        update_opened_files_setting ();

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

        yield doc.open (false);

        if (focus && doc == current_document) {
            doc.focus ();
        }

        if (range != SelectionRange.EMPTY) {
            doc.source_view.select_range (range);
        } else if (cursor_position > 0) {
            doc.source_view.cursor_position = cursor_position;
        }

        update_opened_files_setting ();
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

    public void update_opened_files_setting () {
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

    // This is called when tab context menu is opened or closed
    private void tab_view_setup_menu (Hdy.TabPage? page) {
        tab_menu_target = page;

        var close_other_tabs_action = Utils.action_from_group (MainWindow.ACTION_CLOSE_OTHER_TABS, window.actions);
        var close_tabs_to_right_action = Utils.action_from_group (MainWindow.ACTION_CLOSE_TABS_TO_RIGHT, window.actions);

        int page_position = page != null ? tab_view.get_page_position (page) : -1;

        close_other_tabs_action.set_enabled (page != null && tab_view.n_pages > 1);
        close_tabs_to_right_action.set_enabled (page != null && page_position != tab_view.n_pages - 1);
    }

    private void insert_document (Scratch.Services.Document doc, int pos) {
        tab_view.insert (doc, pos);
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

    private string unsaved_duplicated_file_path_builder (string original_filename) {
        string extension = "txt";
        string[] parts = original_filename.split (".", 2);
        if (parts.length > 1) {
            extension = parts[parts.length - 1];
        }

        return unsaved_file_path_builder (extension);
    }

    private void on_page_detached (Hdy.TabPage tab, int position) {
        var doc = tab.get_child () as Services.Document;
        if (doc == null) {
            return;
        }

        if (tab_history_button.menu_model == null) {
            tab_history_button.menu_model = new Menu ();
        }

        var path = doc.file.get_path ();
        var path_in_menu = false;

        var menu = (Menu) tab_history_button.menu_model;
        int position_in_menu = -1;
        for (var i = 0; i < menu.get_n_items (); i++) {
            if (path == menu.get_item_attribute_value (i, Menu.ATTRIBUTE_TARGET, VariantType.STRING).get_string ()) {
                path_in_menu = true;
                position_in_menu = i;
                break;
            }
        }

        if (path_in_menu) {
            menu.remove (position_in_menu);
        }

        if (menu.get_n_items () == TAB_HISTORY_MAX_ITEMS) {
            menu.remove (TAB_HISTORY_MAX_ITEMS - 1);
        }

        menu.prepend (
            path,
            "%s::%s".printf (MainWindow.ACTION_PREFIX + MainWindow.ACTION_RESTORE_CLOSED_TAB, path)
        );

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

        request_placeholder_if_empty ();
    }

    public void restore_closed_tab (string path) {
        var file = File.new_for_path (path);
        var doc = new Services.Document (window.actions, file);
        open_document.begin (doc);

        var menu = (Menu) tab_history_button.menu_model;
        for (var i = 0; i < menu.get_n_items (); i++) {
            if (path == menu.get_item_attribute_value (i, Menu.ATTRIBUTE_TARGET, VariantType.STRING).get_string ()) {
                menu.remove (i);
                break;
            }
        }

        if (menu.get_n_items () == 0) {
            tab_history_button.menu_model = null;
        }
    }

    private void on_doc_reordered (Hdy.TabPage tab, int new_position) {
        var doc = tab.child as Services.Document;
        if (doc != null) {
            docs.remove (doc);
            docs.insert (doc, new_position);
            current_document = doc;
        }

        update_opened_files_setting ();
    }

    private unowned Hdy.TabView? on_doc_to_new_window (Hdy.TabView tab_view) {
        var other_window = new MainWindow (false);
        return other_window.document_view.tab_view;
    }

    private void on_doc_added (Hdy.TabPage page, int position) {
        var doc = page.get_child () as Services.Document;

        doc.init_tab (page);

        docs.append (doc);
        doc.actions = window.actions;

        Scratch.Services.DocumentManager.get_instance ().add_open_document (doc);

        if (!doc.is_file_temporary) {
           rename_tabs_with_same_title (doc);
        }

        doc.source_view.focus_in_event.connect_after (on_focus_in_event);
        tab_added (doc);
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
                    d.title = new_tabname_d;
                }

                if (doc_tab_name.length < new_tabname_doc.length) {
                    doc_tab_name = new_tabname_doc;
                }
            }
        }

        doc.title = doc_tab_name;
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

    private GLib.Menu create_menu_model () {
        var menu = new GLib.Menu ();

        var close_tab_section = new Menu ();
        close_tab_section.append (_("Close Tabs to the Right"), MainWindow.ACTION_PREFIX + MainWindow.ACTION_CLOSE_TABS_TO_RIGHT);
        close_tab_section.append (_("Close Other Tabs"), MainWindow.ACTION_PREFIX + MainWindow.ACTION_CLOSE_OTHER_TABS);
        close_tab_section.append (_("Close Tab"), MainWindow.ACTION_PREFIX + MainWindow.ACTION_CLOSE_TAB + "::");

        var open_tab_section = new Menu ();
        open_tab_section.append (_("Open in New Window"), MainWindow.ACTION_PREFIX + MainWindow.ACTION_MOVE_TAB_TO_NEW_WINDOW);
        open_tab_section.append (_("Duplicate Tab"), MainWindow.ACTION_PREFIX + MainWindow.ACTION_DUPLICATE_TAB);

        menu.append_section (null, open_tab_section);
        menu.append_section (null, close_tab_section);
        return menu;
    }

    private void drag_received (Gtk.Widget w,
                                Gdk.DragContext ctx,
                                int x,
                                int y,
                                Gtk.SelectionData sel,
                                uint info,
                                uint time) {

        if (info == TargetType.URI_LIST) {
            var uris = sel.get_uris ();
            foreach (var filename in uris) {
                var file = File.new_for_uri (filename);
                var doc = new Services.Document (window.actions, file);
                open_document.begin (doc);
            }

            Gtk.drag_finish (ctx, true, false, time);
        }
    }
}
