// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*
* Copyright (c) 2011-2013 Mario Guerriero <mefrio.g@gmail.com>
*               2017 elementary LLC. <https://elementary.io>
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 3 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*/

namespace Scratch {
    public class MainWindow : Gtk.Window {
        public int FONT_SIZE_MAX = 72;
        public int FONT_SIZE_MIN = 7;
        private const uint MAX_SEARCH_TEXT_LENGTH = 255;

        public weak Application app { get; construct; }

        // Widgets
        public Scratch.Widgets.Toolbar toolbar;
        private Gtk.Revealer search_revealer;
        public Scratch.Widgets.SearchManager search_manager;
        public Scratch.Widgets.LoadingView loading_view;
        public Scratch.Widgets.SplitView split_view;

        // Plugins
        private Scratch.Services.PluginsManager plugins;

        // Widgets for Plugins
        public Gtk.Notebook sidebar;
        public Gtk.Notebook contextbar;
        public Gtk.Notebook bottombar;

        private Gtk.Paned hp1;
        private Gtk.Paned hp2;
        private Gtk.Paned vp;

        // GtkActions
        public Gtk.ActionGroup main_actions;
        public Gtk.UIManager ui;

        public Gtk.Clipboard clipboard;

#if HAVE_ZEITGEIST
        // Zeitgeist integration
        private Zeitgeist.DataSourceRegistry registry;
#endif

        // Delegates
        delegate void HookFunc ();

        public SimpleActionGroup actions { get; construct; }

        public const string ACTION_PREFIX = "win.";
        public const string ACTION_NEW_VIEW = "action_new_view";
        public const string ACTION_PREFERENCES = "preferences";
        public const string ACTION_REMOVE_VIEW = "action_remove_view";

        private const ActionEntry[] action_entries = {
            { ACTION_NEW_VIEW, action_new_view },
            { ACTION_PREFERENCES, action_preferences },
            { ACTION_REMOVE_VIEW, action_remove_view }
        };

        public MainWindow (Application scratch_app) {
            Object (application: scratch_app,
                    app: scratch_app,
                    icon_name: "accessories-text-editor");

            title = app.app_cmd_name;
            application.set_accels_for_action (ACTION_PREFIX + ACTION_NEW_VIEW, { "F3" });
        }

        construct {
            actions = new SimpleActionGroup ();
            actions.add_action_entries (action_entries, this);
            insert_action_group ("win", actions);

            set_size_request (450, 400);
            set_hide_titlebar_when_maximized (false);

            restore_saved_state ();

            clipboard = Gtk.Clipboard.get_for_display (get_display (), Gdk.SELECTION_CLIPBOARD);

            plugins = new Scratch.Services.PluginsManager (this, app.app_cmd_name.down ());

            // Set up GtkActions
            init_actions ();

            // Set up layout
            init_layout ();

            // Restore session
            restore_saved_state_extra ();

            // Crate folder for unsaved documents
            create_unsaved_documents_directory ();

#if HAVE_ZEITGEIST
            // Set up the Data Source Registry for Zeitgeist
            registry = new Zeitgeist.DataSourceRegistry ();

            var ds_event = new Zeitgeist.Event ();
            ds_event.actor = "application://scratch-text-editor.desktop";
            ds_event.add_subject (new Zeitgeist.Subject ());
            var ds_events = new GenericArray<Zeitgeist.Event> ();
            ds_events.add(ds_event);
            var ds = new Zeitgeist.DataSource.full ("scratch-logger",
                                          _("Zeitgeist Datasource for Scratch"),
                                          "A data source which logs Open, Close, Save and Move Events",
                                          ds_events); // FIXME: templates!
            registry.register_data_source.begin (ds, null, (obj, res) => {
                try {
                    registry.register_data_source.end (res);
                } catch (Error reg_err) {
                    critical (reg_err.message);
                }
            });
#endif

            Unix.signal_add (Posix.SIGINT, quit_source_func, Priority.HIGH);
            Unix.signal_add (Posix.SIGTERM, quit_source_func, Priority.HIGH);
        }

        private void init_actions () {
            // Actions
            main_actions = new Gtk.ActionGroup ("MainActionGroup"); /* Actions and UIManager */
            main_actions.set_translation_domain (Constants.GETTEXT_PACKAGE);
            main_actions.add_actions (main_entries, this);
            main_actions.add_toggle_actions (toggle_entries, this);

            // UIManager
            ui = new Gtk.UIManager ();

            try {
                ui.add_ui_from_file (Utils.UI_PATH);
            } catch(Error e) {
                error ("Couldn't load the UI: %s", e.message);
            }

            Gtk.AccelGroup accel_group = ui.get_accel_group();
            add_accel_group (accel_group);

            ui.insert_action_group (main_actions, 0);
            ui.ensure_update ();

            key_press_event.connect (on_key_pressed);
        }

        private void init_layout () {
            toolbar = new Scratch.Widgets.Toolbar (main_actions);
            toolbar.title = title;
            toolbar.show_close_button = true;
            set_titlebar (toolbar);

            // SearchManager
            search_manager = new Scratch.Widgets.SearchManager (this);
            search_manager.get_style_context ().add_class ("search-bar");
            search_revealer = new Gtk.Revealer ();
            search_revealer.add (search_manager);

            search_manager.map.connect_after ((w) => { /* signalled when reveal child */
                set_search_text ();
            });
            search_manager.search_entry.unmap.connect_after (() => { /* signalled when reveal child */
                search_manager.set_search_string ("");
                search_manager.highlight_none ();
            });

            // SlitView
            split_view = new Scratch.Widgets.SplitView (this);

            // LoadingView
            loading_view = new Scratch.Widgets.LoadingView ();

            // Signals
            split_view.welcome_shown.connect (() => {
                toolbar.title = app.app_cmd_name;
                set_widgets_sensitive (false);
            });

            split_view.welcome_hidden.connect (() => {
                set_widgets_sensitive (true);
            });

            split_view.document_change.connect ((doc) => {
                search_manager.set_text_view (doc.source_view);
                // Update MainWindow title
                if (doc != null && doc.file != null) {
                    var home_dir = Environment.get_home_dir ();
                    var path = Path.get_dirname (doc.file.get_uri ()).replace (home_dir, "~");
                    path = path.replace ("file://", "");

                    if ("trash://" in path) {
                        path = _("Trash");
                    }

                    path = Uri.unescape_string (path);

                    string toolbar_title = doc.file.get_basename () + " (%s)".printf (path);
                    if (doc.is_file_temporary) {
                        toolbar_title = "(%s)".printf (doc.get_basename ());
                    }

                    toolbar.title = toolbar_title;
                }
                // Set actions sensitive property
                main_actions.get_action ("SaveFile").visible = (!settings.autosave || doc.file == null);
                main_actions.get_action ("SaveFileAs").visible = (doc.file != null);
                doc.check_undoable_actions ();
            });

            // Plugins widgets
            sidebar = new Gtk.Notebook ();
            sidebar.no_show_all = true;
            sidebar.width_request = 200;
            sidebar.get_style_context ().remove_class (Gtk.STYLE_CLASS_FRAME);
            sidebar.page_added.connect (() => { on_plugin_toggled (sidebar); });
            sidebar.page_removed.connect (() => { on_plugin_toggled (sidebar); });

            contextbar = new Gtk.Notebook ();
            contextbar.no_show_all = true;
            contextbar.width_request = 200;
            contextbar.page_removed.connect (() => { on_plugin_toggled (contextbar); });
            contextbar.page_added.connect (() => {
                if (!split_view.is_empty ()) {
                    on_plugin_toggled (contextbar);
                }
            });

            bottombar = new Gtk.Notebook ();
            bottombar.no_show_all = true;
            bottombar.page_removed.connect (() => { on_plugin_toggled (bottombar); });
            bottombar.page_added.connect (() => {
                if (!split_view.is_empty ())
                    on_plugin_toggled (bottombar);
            });

            var content = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            content.width_request = 200;
            content.pack_start (search_revealer, false, true, 0);
            content.pack_start (split_view, true, true, 0);

            // Set a proper position for ThinPaned widgets
            int width, height;
            get_size (out width, out height);

            hp1 = new Gtk.Paned (Gtk.Orientation.HORIZONTAL);
            hp1.position = 180;
            hp1.pack1 (sidebar, false, false);
            hp1.pack2 (content, true, false);

            hp2 = new Gtk.Paned (Gtk.Orientation.HORIZONTAL);
            hp2.position = (width - 180);
            hp2.pack1 (hp1, true, false);
            hp2.pack2 (contextbar, false, false);

            vp = new Gtk.Paned (Gtk.Orientation.VERTICAL);
            vp.position = (height - 150);
            vp.pack1 (hp2, true, false);
            vp.pack2 (bottombar, false, false);

            var main_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            main_box.pack_start (loading_view, true, true, 0);
            main_box.pack_start (vp, false, true, 0);
            add (main_box);

            // Show/Hide widgets
            show_all ();

            search_revealer.set_reveal_child (false);

            main_actions.get_action ("SaveFile").visible = !settings.autosave;
            main_actions.get_action ("Templates").visible = plugins.plugin_iface.template_manager.template_available;
            plugins.plugin_iface.template_manager.notify["template_available"].connect ( () => {
                main_actions.get_action ("Templates").visible = plugins.plugin_iface.template_manager.template_available;
            });

            // All the files have already been opened in Application.activate (),
            // if we reach this point without any document open let's just show
            // the welcome screen.
            if (is_empty ()) {
                split_view.show_welcome ();
            }

            split_view.document_change.connect ((doc) => { plugins.hook_document (doc); });

            // Plugins hook
            HookFunc hook_func = () => {
                plugins.hook_window (this);
                plugins.hook_toolbar (toolbar);
                plugins.hook_main_menu (toolbar.menu);
                plugins.hook_share_menu (toolbar.share_menu);
                plugins.hook_notebook_sidebar (sidebar);
                plugins.hook_notebook_context (contextbar);
                plugins.hook_notebook_bottom (bottombar);
                plugins.hook_split_view (split_view);
            };

            plugins.extension_added.connect (() => {
                hook_func ();
            });

            hook_func ();

            set_widgets_sensitive (!split_view.is_empty ());
        }

        public void restore_opened_documents () {
            start_loading ();

            string[] uris_view1 = settings.opened_files_view1;
            string[] uris_view2 = settings.opened_files_view2;
            string focused_document1 = settings.focused_document_view1;
            string focused_document2 = settings.focused_document_view2;

            if (uris_view1.length > 0) {
                var view = add_view ();
                load_files_for_view (view, uris_view1);
                set_focused_document (view, focused_document1);

                if (view.is_empty ()) {
                    split_view.remove_view (view);
                }
            }

            if (uris_view2.length > 0) {
                var view = add_view ();
                load_files_for_view (view, uris_view2);
                set_focused_document (view, focused_document2);

                if (view.is_empty ()) {
                    split_view.remove_view (view);
                }
            }

            stop_loading ();
        }

        private void load_files_for_view (Scratch.Widgets.DocumentView view, string[] uris) {
            foreach (string uri in uris) {
               if (uri != "") {
                    var file = File.new_for_uri (uri);
                    if (file.query_exists ()) {
                        var doc = new Scratch.Services.Document (main_actions, file);

                        if (!doc.is_file_temporary || doc.exists ()) {
                            open_document (doc, view);
                        }
                    }
                }
            }
        }

        // Set focus to last focused document, after all documents finished loading
        private void set_focused_document (Scratch.Widgets.DocumentView view, string focused_document) {
            if (focused_document != "") {
                Scratch.Services.Document document_to_focus = null;

                foreach (Scratch.Services.Document doc in view.docs) {
                    if (doc.file != null) {
                        if (doc.file.get_uri() == focused_document) {
                            document_to_focus = doc;
                            break;
                        }
                    }
                }

                if (document_to_focus != null) {
                    view.current_document = document_to_focus;
                }
            }
        }

        private bool on_key_pressed (Gdk.EventKey event) {
            switch (Gdk.keyval_name (event.keyval)) {
                case "Escape":
                    if (search_revealer.get_child_revealed ()) {
                        var fetch_action = (Gtk.ToggleAction) main_actions.get_action ("ShowFetch");
                        fetch_action.active = false;
                    }
                    break;
            }

            // propagate this event to child widgets
            return false;
        }

        private void on_plugin_toggled (Gtk.Notebook notebook) {
            var pages = notebook.get_n_pages ();
            notebook.set_show_tabs (pages > 1);
            notebook.no_show_all = (pages == 0);
            notebook.visible = (pages > 0);
        }

        protected override bool delete_event (Gdk.EventAny event) {
            handle_quit ();
            return !check_unsaved_changes ();
        }

        // Set sensitive property for 'delicate' Widgets/GtkActions while
        private void set_widgets_sensitive (bool val) {
            // SearchManager's stuffs
            var fetch = (Gtk.ToggleAction) main_actions.get_action ("ShowFetch");
            fetch.sensitive = val;
            fetch.active = (fetch.active && val);
            main_actions.get_action ("ShowGoTo").sensitive = val;
            main_actions.get_action ("ShowReplace").sensitive = val;
            // Toolbar Actions
            main_actions.get_action ("SaveFile").sensitive = val;
            main_actions.get_action ("SaveFileAs").sensitive = val;
            main_actions.get_action ("Undo").sensitive = val;
            main_actions.get_action ("Redo").sensitive = val;
            main_actions.get_action ("Revert").sensitive = val;
            toolbar.share_app_menu.sensitive = val;

            // Zoom button
            main_actions.get_action ("Zoom").visible = get_current_font_size () != get_default_font_size () && val;

            // PlugIns
            if (val) {
                on_plugin_toggled (contextbar);
                on_plugin_toggled (bottombar);
            } else {
                contextbar.visible = val;
                bottombar.visible = val;
            }
        }

        // Get current view
        public Scratch.Widgets.DocumentView? get_current_view () {
            Scratch.Widgets.DocumentView? view = null;

            view = split_view.get_current_view ();

            if (view == null && !split_view.is_empty ()) {
                view = (split_view.get_child1 () ?? split_view.get_child2 ()) as Scratch.Widgets.DocumentView;
            }

            return view;
        }

        // Get current document
        public Scratch.Services.Document? get_current_document () {
            var view = get_current_view ();
            if (view != null) {
                return view.current_document;
            }

            return null;
        }

        // Add new view
        public Scratch.Widgets.DocumentView? add_view () {
            return split_view.add_view ();
        }

        // Show LoadingView
        public void start_loading () {
            loading_view.start ();
            vp.visible = false;
            toolbar.sensitive = false;
        }

        // Hide LoadingView
        public void stop_loading () {
            loading_view.stop ();
            vp.visible = true;
            toolbar.sensitive = true;
        }

        // Open a document
        public void open_document (Scratch.Services.Document doc, Scratch.Widgets.DocumentView? view_ = null) {
            while (Gtk.events_pending ()) {
                Gtk.main_iteration ();
            }

            Scratch.Widgets.DocumentView view = null;

            if (view_ != null) {
                view = view_;
            }

            if (split_view.is_empty ()) {
                view = split_view.add_view ();
                view.open_document (doc);
            } else {
                if (view == null) {
                    view = split_view.get_focus_child () as Scratch.Widgets.DocumentView;
                }

                if (view == null) {
                    view = split_view.current_view;
                }

                view.open_document (doc);
            }
        }

        // Close a document
        public void close_document (Scratch.Services.Document doc) {
            Scratch.Widgets.DocumentView? view = null;
            if (split_view.is_empty ()) {
                view = split_view.add_view ();
                view.close_document (doc);
            } else {
                view = split_view.get_focus_child () as Scratch.Widgets.DocumentView;
                if (view == null) {
                    view = split_view.current_view;
                }

                view.close_document (doc);
            }
        }

        // Return true if there are no documents
        public bool is_empty () {
            return split_view.is_empty ();
        }

        public bool has_temporary_files () {
            try {
                var enumerator = File.new_for_path (app.data_home_folder_unsaved).enumerate_children (FileAttribute.STANDARD_NAME, 0, null);
                for (var fileinfo = enumerator.next_file (null); fileinfo != null; fileinfo = enumerator.next_file (null)) {
                    if (!fileinfo.get_name ().has_suffix ("~")) {
                        return true;
                    }
                }
            } catch (Error e) {
                critical (e.message);
            }

            return false;
        }

        // Check if there no unsaved changes
        private bool check_unsaved_changes () {
            if (!is_empty ()) {
                foreach (var w in split_view.views) {
                    var view = w as Scratch.Widgets.DocumentView;
                    view.is_closing = true;
                    foreach (var doc in view.docs) {
                        if (!doc.close (true)) {
                            view.current_document = doc;
                            return false;
                        }
                    }
                }
            }

            return true;
        }

        // Save windows size and state
        private void restore_saved_state () {
            default_width = Scratch.saved_state.window_width;
            default_height = Scratch.saved_state.window_height;

            switch (Scratch.saved_state.window_state) {
                case ScratchWindowState.MAXIMIZED:
                    maximize ();
                    break;
                case ScratchWindowState.FULLSCREEN:
                    fullscreen ();
                    break;
                default:
                    move (Scratch.saved_state.window_x, Scratch.saved_state.window_y);
                    break;
            }
        }

        // Save session informations different from window state
        private void restore_saved_state_extra () {
            // Plugin panes size
            hp1.set_position (Scratch.saved_state.hp1_size);
            hp2.set_position (Scratch.saved_state.hp2_size);
            vp.set_position (Scratch.saved_state.vp_size);
        }

        private void create_unsaved_documents_directory () {
            var directory = File.new_for_path (app.data_home_folder_unsaved);
            if (!directory.query_exists ()) {
                try {
                    directory.make_directory_with_parents ();
                    debug ("created 'unsaved' directory: %s", directory.get_path ());
                } catch (Error e) {
                    critical ("Unable to create the 'unsaved' directory: '%s': %s", directory.get_path (), e.message);
                }
            }
        }

        private void update_saved_state () {
            // Save window state
            var state = get_window ().get_state ();
            if (Gdk.WindowState.MAXIMIZED in state) {
                Scratch.saved_state.window_state = ScratchWindowState.MAXIMIZED;
            } else if (Gdk.WindowState.FULLSCREEN in state) {
                Scratch.saved_state.window_state = ScratchWindowState.FULLSCREEN;
            } else {
                Scratch.saved_state.window_state = ScratchWindowState.NORMAL;
                // Save window size
                int width, height;
                get_size (out width, out height);
                Scratch.saved_state.window_width = width;
                Scratch.saved_state.window_height = height;
            }

            // Save window position
            int x, y;
            get_position (out x, out y);
            Scratch.saved_state.window_x = x;
            Scratch.saved_state.window_y = y;

            // Plugin panes size
            Scratch.saved_state.hp1_size = hp1.get_position ();
            Scratch.saved_state.hp2_size = hp2.get_position ();
            Scratch.saved_state.vp_size = vp.get_position ();
        }

        // SIGTERM/SIGINT Handling
        public bool quit_source_func () {
            action_quit ();
            return false;
        }

        // For exit cleanup
        private void handle_quit () {
            update_saved_state ();
        }

        public void set_default_zoom () {
            Scratch.settings.font = get_current_font () + " " + get_default_font_size ().to_string ();
        }

        // Ctrl + scroll
        public void zoom_in () {
             zooming (Gdk.ScrollDirection.UP);
        }

        // Ctrl + scroll
        public void zoom_out () {
            zooming (Gdk.ScrollDirection.DOWN);
        }

        private void zooming (Gdk.ScrollDirection direction) {
            string font = get_current_font ();
            int font_size = (int) get_current_font_size ();
            if (Scratch.settings.use_system_font) {
                Scratch.settings.use_system_font = false;
                font = get_default_font ();
                font_size = (int) get_default_font_size ();
            }

            if (direction == Gdk.ScrollDirection.DOWN) {
                font_size --;
                if (font_size < FONT_SIZE_MIN) {
                    return;
                }
            } else if (direction  == Gdk.ScrollDirection.UP) {
                font_size ++;
                if (font_size > FONT_SIZE_MAX) {
                    return;
                }
            }

            string new_font = font + " " + font_size.to_string ();
            Scratch.settings.font = new_font;
            main_actions.get_action ("Zoom").visible = get_current_font_size () != get_default_font_size () && !split_view.is_empty ();
        }

        public string get_current_font () {
            string font = Scratch.settings.font;
            string font_family = font.substring (0, font.last_index_of (" "));
            return font_family;
        }

        public double get_current_font_size () {
            string font = Scratch.settings.font;
            string font_size = font.substring (font.last_index_of (" ") + 1);
            return double.parse (font_size);
        }

        public string get_default_font () {
            string font = app.default_font;
            string font_family = font.substring (0, font.last_index_of (" "));
            return font_family;
        }

        public double get_default_font_size () {
            string font = app.default_font;
            string font_size = font.substring (font.last_index_of (" ") + 1);
            return double.parse (font_size);
        }

        // Actions functions
        private void action_set_default_zoom () {
            set_default_zoom ();
        }

        private void action_preferences () {
            var dialog = new Scratch.Dialogs.Preferences (this, plugins);
            dialog.show_all ();
        }

        private void action_close_tab () {
            var view = get_current_view ();
            if (view != null)
                view.close_current_document ();
        }

        private void action_quit () {
            handle_quit ();
            check_unsaved_changes ();
            destroy ();
        }

        private void action_open () {
            // Show a GtkFileChooserDialog
            var filech = Utils.new_file_chooser_dialog (Gtk.FileChooserAction.OPEN, _("Open some files"), this, true);
            if (filech.run () == Gtk.ResponseType.ACCEPT) {
                foreach (string uri in filech.get_uris ()) {
                    // Update last visited path
                    Utils.last_path = Path.get_dirname (uri);
                    // Open the file
                    var file = File.new_for_uri (uri);
                    var doc = new Scratch.Services.Document (main_actions, file);
                    open_document (doc);
                }
            }

            filech.close ();
        }

        private void action_save () {
            var doc = get_current_document (); /* may return null */
            if (doc != null) {
                if (doc.is_file_temporary == true) {
                    action_save_as ();
                } else {
                    doc.save.begin ();
                }
            }
        }

        private void action_save_as () {
            var doc = get_current_document ();
            if (doc != null) {
                doc.save_as.begin ();
            }
        }

        private void action_undo () {
            var doc = get_current_document ();
            if (doc != null) {
                doc.undo ();
            }
        }

        private void action_redo () {
            var doc = get_current_document ();
            if (doc != null) {
                doc.redo ();
            }
        }

        private void action_revert () {
            var doc = get_current_document ();
            if (doc != null) {
                doc.revert ();
            }
        }

        private void action_duplicate () {
            var doc = get_current_document ();
            if (doc != null) {
                doc.duplicate_selection ();
            }
        }

        private void action_new_tab () {
            Scratch.Widgets.DocumentView? view = null;
            if (split_view.is_empty ()) {
                view = split_view.add_view ();
            } else {
                view = split_view.get_focus_child () as Scratch.Widgets.DocumentView;
            }

            view.new_document ();
        }

        private void action_new_tab_from_clipboard () {
            Scratch.Widgets.DocumentView? view = null;
            if (split_view.is_empty ()) {
                view = split_view.add_view ();
            } else {
                view = split_view.get_focus_child () as Scratch.Widgets.DocumentView;
            }

            string text_from_clipboard = clipboard.wait_for_text ();
            view.new_document_from_clipboard (text_from_clipboard);
        }

        private void action_new_view () {
            var view = split_view.add_view ();
            if (view != null) {
                view.new_document ();
            }
        }

        private void action_remove_view () {
            split_view.remove_view ();
        }

        private void action_fullscreen () {
            if (Gdk.WindowState.FULLSCREEN in get_window ().get_state ()) {
                unfullscreen ();
            } else {
                fullscreen ();
            }
        }

        /** Not a toggle action - linked to keyboard short cut (Ctrl-f). **/
        private void action_fetch () {
            if (!search_revealer.child_revealed) {
                var fetch_action = (Gtk.ToggleAction) main_actions.get_action ("ShowFetch");
                if (fetch_action.sensitive) {
                    /* Toggling the fetch action causes this function to be called again but the search_revealer child
                     * is still not revealed so nothing more happens.  We use the map signal on the search entry
                     * to set it up once it has been revealed. */
                    fetch_action.active = true;
                }
            } else {
                set_search_text ();
            }
        }

        private void set_search_text () {
            var current_doc = get_current_document ();
            // This is also called when all documents are closed.
            if (current_doc != null) {
                var selected_text = current_doc.get_selected_text ();
                if (selected_text.length < MAX_SEARCH_TEXT_LENGTH) {
                    search_manager.set_search_string (selected_text);
                }

                search_manager.search_entry.grab_focus (); /* causes loss of document selection */

                if (selected_text != "") {
                    search_manager.search_next (); /* this selects the next match (if any) */
                }

            }
        }

        /** Toggle action - linked to toolbar togglebutton. **/
        private void action_show_fetch () {
            var fetch_action = (Gtk.ToggleAction) main_actions.get_action ("ShowFetch");
            var fetch_active = fetch_action.active;

            if (fetch_active == false) {
                fetch_action.tooltip = _("Find…");
            } else {
                fetch_action.tooltip = _("Hide search bar");
            }

            /* The search entry map signal is used to set up the entry text */
            search_revealer.set_reveal_child (fetch_active);
        }

        private void action_go_to () {
            var fetch_action = (Gtk.ToggleAction) main_actions.get_action ("ShowFetch");
            fetch_action.active = true;
            search_manager.go_to_entry.grab_focus ();
        }

        private void action_templates () {
            plugins.plugin_iface.template_manager.show_window (this);
        }

        private void action_next_tab () {
            Scratch.Widgets.DocumentView? view = null;
            view = split_view.get_focus_child () as Scratch.Widgets.DocumentView;
            view.next_document ();
        }

        private void action_previous_tab () {
            Scratch.Widgets.DocumentView? view = null;
            view = split_view.get_focus_child () as Scratch.Widgets.DocumentView;
            view.previous_document ();
        }

        private void action_to_lower_case () {
            Scratch.Widgets.DocumentView? view = null;
            view = split_view.get_focus_child () as Scratch.Widgets.DocumentView;
            var doc = view.current_document;
            if (doc == null) {
                return;
            }

            var buffer = doc.source_view.buffer;
            Gtk.TextIter start, end;
            buffer.get_selection_bounds (out start, out end);
            string selected = buffer.get_text (start, end, true);

            buffer.delete (ref start, ref end);
            buffer.insert (ref start, selected.down (), -1);
        }

        private void action_to_upper_case () {
            Scratch.Widgets.DocumentView? view = null;
            view = split_view.get_focus_child () as Scratch.Widgets.DocumentView;
            var doc = view.current_document;
            if (doc == null) {
                return;
            }

            var buffer = doc.source_view.buffer;
            Gtk.TextIter start, end;
            buffer.get_selection_bounds (out start, out end);
            string selected = buffer.get_text (start, end, true);

            buffer.delete (ref start, ref end);
            buffer.insert (ref start, selected.up (), -1);
        }

        // Actions array
        private const Gtk.ActionEntry[] main_entries = {
            { "ShowGoTo", null, null, "<Control>i", null, action_go_to },
            { "Quit", null, null, "<Control>q", null, action_quit },
            { "CloseTab", null, null, "<Control>w", null, action_close_tab },
            { "ShowReplace", null, null, "<Control>r", null, action_fetch },
            { "NewTab", null, null, "<Control>n", null, action_new_tab },
            { "Undo", null, null, "<Control>z", null, action_undo },
            { "Redo", null, null, "<Control><shift>z", null, action_redo },
            { "Revert", null, null, "<Control><shift>o", null, action_revert },
            { "Duplicate", null, null, "<Control>d", null, action_duplicate },
            { "Open", null, null, "<Control>o", null, action_open },
            { "Clipboard", null, null, null, null, action_new_tab_from_clipboard },
            { "Zoom", null, null, "<Control>0", null, action_set_default_zoom },
            { "SaveFile", null, null, "<Control>s", null, action_save },
            { "SaveFileAs", null, null, "<Control><shift>s", null, action_save_as },
            { "Templates", null, null, null, null, action_templates },
            { "NextTab", null, null, "<Control><Alt>Page_Up", null, action_next_tab },
            { "PreviousTab", null, null, "<Control><Alt>Page_Down", null, action_previous_tab },
            { "ToLowerCase", null, null, "<Control>l", null, action_to_lower_case },
            { "ToUpperCase", null, null, "<Control>u", null, action_to_upper_case },
            { "Fetch", null, null, "<Control>f", null, action_fetch }
        };

        private const Gtk.ToggleActionEntry[] toggle_entries = {
            { "Fullscreen", null, null, "F11", null, action_fullscreen },
            { "ShowFetch", null, null, "", null, action_show_fetch }
        };
    }
}
