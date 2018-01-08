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

        public weak Scratch.Application app { get; construct; }

        // Widgets
        public Scratch.Widgets.HeaderBar toolbar;
        private Gtk.Revealer search_revealer;
        public Scratch.Widgets.SearchBar search_bar;
        public Scratch.Widgets.SplitView split_view;

        // Plugins
        private Scratch.Services.PluginsManager plugins;

        // Widgets for Plugins
        public Gtk.Notebook contextbar;
        public Gtk.Notebook bottombar;
        public Code.Pane project_pane;

        private Gtk.Paned hp1;
        private Gtk.Paned hp2;
        private Gtk.Paned vp;

        public Gtk.Clipboard clipboard;

#if HAVE_ZEITGEIST
        // Zeitgeist integration
        private Zeitgeist.DataSourceRegistry registry;
#endif

        // Delegates
        delegate void HookFunc ();

        public SimpleActionGroup actions { get; construct; }

        public const string ACTION_PREFIX = "win.";
        public const string ACTION_FIND = "action_find";
        public const string ACTION_OPEN = "action_open";
        public const string ACTION_GO_TO = "action_go_to";
        public const string ACTION_NEW_VIEW = "action_new_view";
        public const string ACTION_NEW_TAB = "action_new_tab";
        public const string ACTION_NEW_FROM_CLIPBOARD = "action_new_from_clipboard";
        public const string ACTION_NEXT_TAB = "action_next_tab";
        public const string ACTION_PREFERENCES = "preferences";
        public const string ACTION_PREVIOUS_TAB = "action_previous_tab";
        public const string ACTION_REMOVE_VIEW = "action_remove_view";
        public const string ACTION_UNDO = "action_undo";
        public const string ACTION_REDO = "action_redo";
        public const string ACTION_REVERT = "action_revert";
        public const string ACTION_SAVE = "action_save";
        public const string ACTION_SAVE_AS = "action_save_as";
        public const string ACTION_SHOW_FIND = "action_show_find";
        public const string ACTION_TEMPLATES = "action_templates";
        public const string ACTION_ZOOM_DEFAULT = "action_zoom_default";
        public const string ACTION_SHOW_REPLACE = "action_show_replace";
        public const string ACTION_TO_LOWER_CASE = "action_to_lower_case";
        public const string ACTION_TO_UPPER_CASE = "action_to_upper_case";
        public const string ACTION_DUPLICATE = "action_duplicate";
        public const string ACTION_FULLSCREEN = "action_fullscreen";
        public const string ACTION_CLOSE_TAB = "action_close_tab";
        public const string ACTION_QUIT = "action_quit";

        public static Gee.MultiMap<string, string> action_accelerators = new Gee.HashMultiMap<string, string> ();

        private const ActionEntry[] action_entries = {
            { ACTION_FIND, action_fetch },
            { ACTION_OPEN, action_open },
            { ACTION_PREFERENCES, action_preferences },
            { ACTION_REVERT, action_revert },
            { ACTION_SAVE, action_save },
            { ACTION_SAVE_AS, action_save_as },
            { ACTION_SHOW_FIND, action_show_fetch, null, "false" },
            { ACTION_TEMPLATES, action_templates },
            { ACTION_ZOOM_DEFAULT, action_set_default_zoom },
            { ACTION_GO_TO, action_go_to },
            { ACTION_NEW_VIEW, action_new_view },
            { ACTION_NEW_TAB, action_new_tab },
            { ACTION_NEW_FROM_CLIPBOARD, action_new_tab_from_clipboard },
            { ACTION_NEXT_TAB, action_next_tab },
            { ACTION_PREFERENCES, action_preferences },
            { ACTION_PREVIOUS_TAB, action_previous_tab },
            { ACTION_REMOVE_VIEW, action_remove_view },
            { ACTION_UNDO, action_undo },
            { ACTION_REDO, action_redo },
            { ACTION_SHOW_REPLACE, action_fetch },
            { ACTION_TO_LOWER_CASE, action_to_lower_case },
            { ACTION_TO_UPPER_CASE, action_to_upper_case },
            { ACTION_DUPLICATE, action_duplicate },
            { ACTION_FULLSCREEN, action_fullscreen },
            { ACTION_CLOSE_TAB, action_close_tab },
            { ACTION_QUIT, action_quit }
        };

        public MainWindow (Scratch.Application scratch_app) {
            Object (
                application: scratch_app,
                app: scratch_app,
                icon_name: Constants.PROJECT_NAME,
                title: _("Code")
            );
        }

        static construct {
            action_accelerators.set (ACTION_FIND, "<Control>f");
            action_accelerators.set (ACTION_OPEN, "<Control>o");
            action_accelerators.set (ACTION_REVERT, "<Control><shift>o");
            action_accelerators.set (ACTION_SAVE, "<Control>s");
            action_accelerators.set (ACTION_SAVE_AS, "<Control><shift>s");
            action_accelerators.set (ACTION_ZOOM_DEFAULT, "<Control>0");
            action_accelerators.set (ACTION_GO_TO, "<Control>i");
            action_accelerators.set (ACTION_NEW_VIEW, "F3");
            action_accelerators.set (ACTION_NEW_TAB, "<Control>n");
            action_accelerators.set (ACTION_NEXT_TAB, "<Control><Alt>Page_Up");
            action_accelerators.set (ACTION_PREVIOUS_TAB, "<Control><Alt>Page_Down");
            action_accelerators.set (ACTION_UNDO, "<Control>z");
            action_accelerators.set (ACTION_REDO, "<Control><shift>z");
            action_accelerators.set (ACTION_SHOW_REPLACE, "<Control>r");
            action_accelerators.set (ACTION_TO_LOWER_CASE, "<Control>l");
            action_accelerators.set (ACTION_TO_UPPER_CASE, "<Control>u");
            action_accelerators.set (ACTION_DUPLICATE, "<Control>d");
            action_accelerators.set (ACTION_FULLSCREEN, "F11");
            action_accelerators.set (ACTION_CLOSE_TAB, "<Control>w");
            action_accelerators.set (ACTION_QUIT, "<Control>q");
        }

        construct {
            actions = new SimpleActionGroup ();
            actions.add_action_entries (action_entries, this);
            insert_action_group ("win", actions);

            actions.action_state_changed.connect ((name, new_state) => {
                if (name == ACTION_SHOW_FIND) {
                    if (new_state.get_boolean () == false) {
                        toolbar.find_button.tooltip_text = _("Find…");
                    } else {
                        toolbar.find_button.tooltip_text = _("Hide search bar");
                    }

                    search_revealer.set_reveal_child (new_state.get_boolean ());
                }
            });

            foreach (var action in action_accelerators.get_keys ()) {
                app.set_accels_for_action (ACTION_PREFIX + action, action_accelerators[action].to_array ());
            }

            set_size_request (450, 400);
            set_hide_titlebar_when_maximized (false);

            restore_saved_state ();

            clipboard = Gtk.Clipboard.get_for_display (get_display (), Gdk.SELECTION_CLIPBOARD);

            plugins = new Scratch.Services.PluginsManager (this, app.app_cmd_name.down ());

            key_press_event.connect (on_key_pressed);

            // Set up layout
            init_layout ();

            toolbar.templates_button.visible = (plugins.plugin_iface.template_manager.template_available);
            plugins.plugin_iface.template_manager.notify["template_available"].connect (() => {
                toolbar.templates_button.visible = (plugins.plugin_iface.template_manager.template_available);
            });

            // Restore session
            restore_saved_state_extra ();

            // Crate folder for unsaved documents
            create_unsaved_documents_directory ();

#if HAVE_ZEITGEIST
            // Set up the Data Source Registry for Zeitgeist
            registry = new Zeitgeist.DataSourceRegistry ();

            var ds_event = new Zeitgeist.Event ();
            ds_event.actor = "application://" + Constants.PROJECT_NAME + ".desktop";
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

            /* Splitview controls showing and hiding of Welcome view */
        }

        private void init_layout () {
            toolbar = new Scratch.Widgets.HeaderBar ();
            toolbar.title = title;
            set_titlebar (toolbar);

            // SearchBar
            search_bar = new Scratch.Widgets.SearchBar (this);
            search_revealer = new Gtk.Revealer ();
            search_revealer.add (search_bar);

            search_bar.map.connect_after ((w) => { /* signalled when reveal child */
                set_search_text ();
            });
            search_bar.search_entry.unmap.connect_after (() => { /* signalled when reveal child */
                search_bar.set_search_string ("");
                search_bar.highlight_none ();
            });

            // SlitView
            split_view = new Scratch.Widgets.SplitView (this);

            // Signals
            split_view.welcome_shown.connect (() => {
                toolbar.title = app.app_cmd_name;
                toolbar.document_available (false);
                set_widgets_sensitive (false);
            });

            split_view.welcome_hidden.connect (() => {
                toolbar.document_available (true);
                set_widgets_sensitive (true);
            });

            split_view.document_change.connect ((doc) => {
                search_bar.set_text_view (doc.source_view);
                // Update MainWindow title
                if (doc != null) {
                    toolbar.set_document_focus (doc);
                }

                // Set actions sensitive property
                Utils.action_from_group (ACTION_SAVE_AS, actions).set_enabled (doc.file != null);
                doc.check_undoable_actions ();
            });

            project_pane = new Code.Pane ();

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
            hp1.pack1 (project_pane, false, false);
            hp1.pack2 (content, true, false);

            hp2 = new Gtk.Paned (Gtk.Orientation.HORIZONTAL);
            hp2.position = (width - 180);
            hp2.pack1 (hp1, true, false);
            hp2.pack2 (contextbar, false, false);

            vp = new Gtk.Paned (Gtk.Orientation.VERTICAL);
            vp.position = (height - 150);
            vp.pack1 (hp2, true, false);
            vp.pack2 (bottombar, false, false);

            add (vp);

            // Show/Hide widgets
            show_all ();

            search_revealer.set_reveal_child (false);

            split_view.document_change.connect ((doc) => { plugins.hook_document (doc); });

            // Plugins hook
            HookFunc hook_func = () => {
                plugins.hook_window (this);
                plugins.hook_toolbar (toolbar);
                plugins.hook_main_menu (toolbar.menu);
                plugins.hook_share_menu (toolbar.share_menu);
                plugins.hook_notebook_context (contextbar);
                plugins.hook_notebook_bottom (bottombar);
                plugins.hook_split_view (split_view);
            };

            plugins.extension_added.connect (() => {
                hook_func ();
            });

            hook_func ();
        }

        public void restore_opened_documents () {
            string[] uris_view1 = settings.opened_files_view1;
            string[] uris_view2 = settings.opened_files_view2;
            string focused_document1 = settings.focused_document_view1;
            string focused_document2 = settings.focused_document_view2;

            if (uris_view1.length > 0) {
                var view = add_view ();
                load_files_for_view (view, uris_view1, focused_document1);
            }

            if (uris_view2.length > 0) {
                var view = add_view ();
                load_files_for_view (view, uris_view2, focused_document2);
            }
        }

        private void load_files_for_view (Scratch.Widgets.DocumentView view, string[] uris, string focused_document) {
            foreach (string uri in uris) {
               if (uri != "") {
                    GLib.File file;
                    if (Uri.parse_scheme (uri) != null) {
                        file = File.new_for_uri (uri);
                    } else {
                        file = File.new_for_commandline_arg (uri);
                    }
                    /* Leave it to doc to handle problematic files properly */
                    var doc = new Scratch.Services.Document (actions, file);
                    if (!doc.is_file_temporary) {
                        open_document (doc, view, file.get_uri () == focused_document);
                    }
                }
            }
        }

        private bool on_key_pressed (Gdk.EventKey event) {
            switch (Gdk.keyval_name (event.keyval)) {
                case "Escape":
                    if (search_revealer.get_child_revealed ()) {
                        var fetch_action = Utils.action_from_group (ACTION_SHOW_FIND, actions);
                        fetch_action.set_state (false);
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
            Utils.action_from_group (ACTION_FIND, actions).set_enabled (val);
            Utils.action_from_group (ACTION_GO_TO, actions).set_enabled (val);
            Utils.action_from_group (ACTION_SHOW_REPLACE, actions).set_enabled (val);
            // Toolbar Actions
            Utils.action_from_group (ACTION_SAVE, actions).set_enabled (val);
            Utils.action_from_group (ACTION_SAVE_AS, actions).set_enabled (val);
            Utils.action_from_group (ACTION_UNDO, actions).set_enabled (val);
            Utils.action_from_group (ACTION_REDO, actions).set_enabled (val);
            Utils.action_from_group (ACTION_REVERT, actions).set_enabled (val);
            toolbar.share_app_menu.sensitive = val;

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

        // Open a document
        public void open_document (Scratch.Services.Document doc, Scratch.Widgets.DocumentView? view_ = null, bool focus = true) {
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

                view.open_document (doc, focus);
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
            dialog.set_modal (true);
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
            var response = filech.run ();
            filech.close (); // Close now so it does not stay open during lengthy or failed loading

            if (response == Gtk.ResponseType.ACCEPT) {
                foreach (string uri in filech.get_uris ()) {
                    // Update last visited path
                    Utils.last_path = Path.get_dirname (uri);
                    // Open the file
                    var file = File.new_for_uri (uri);
                    var doc = new Scratch.Services.Document (actions, file);
                    open_document (doc);
                }
            }
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
                var fetch_action = Utils.action_from_group (ACTION_SHOW_FIND, actions);
                if (fetch_action.enabled) {
                    /* Toggling the fetch action causes this function to be called again but the search_revealer child
                     * is still not revealed so nothing more happens.  We use the map signal on the search entry
                     * to set it up once it has been revealed. */
                    fetch_action.set_state (true);
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
                    search_bar.set_search_string (selected_text);
                }

                search_bar.search_entry.grab_focus (); /* causes loss of document selection */

                if (selected_text != "") {
                    search_bar.search_next (); /* this selects the next match (if any) */
                }

            }
        }

        /** Toggle action - linked to toolbar togglebutton. **/
        private void action_show_fetch () {
            var fetch_action = Utils.action_from_group (ACTION_SHOW_FIND, actions);
            fetch_action.set_state (!fetch_action.get_state ().get_boolean ());
        }

        private void action_go_to () {
            toolbar.format_bar.line_toggle.active = true;
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
    }
}
