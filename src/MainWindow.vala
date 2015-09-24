// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/***
  BEGIN LICENSE

  Copyright (C) 2011-2013 Mario Guerriero <mefrio.g@gmail.com>
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

namespace Scratch {
    public class MainWindow : Gtk.Window {
        public int FONT_SIZE_MAX = 72;
        public int FONT_SIZE_MIN = 7;

        public weak ScratchApp app;

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

        public MainWindow (Scratch.ScratchApp scratch_app) {
            this.app = scratch_app;
            set_application (this.app);
            this.title = this.app.app_cmd_name;
            this.window_position = Gtk.WindowPosition.CENTER;
            this.set_size_request (450, 400);
            this.set_hide_titlebar_when_maximized (false);
            restore_saved_state ();
            this.icon_name = "accessories-text-editor";

            clipboard = Gtk.Clipboard.get_for_display (this.get_display (), Gdk.SELECTION_CLIPBOARD);


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

        }

        private void init_layout () {
            var main_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);

            // Toolbar
            var menu = ui.get_widget ("ui/AppMenu") as Gtk.Menu;
            this.toolbar = new Scratch.Widgets.Toolbar (main_actions, menu);
            this.toolbar.title = this.title;
            this.toolbar.show_close_button = true;
            this.set_titlebar (this.toolbar);

            // SearchManager
            this.search_revealer = new Gtk.Revealer ();
            this.search_manager = new Scratch.Widgets.SearchManager (this);
            this.search_manager.get_style_context ().add_class ("search-bar");
            this.search_revealer.add (this.search_manager);

            // SlitView
            this.split_view = new Scratch.Widgets.SplitView (this);

            // LoadingView
            this.loading_view = new Scratch.Widgets.LoadingView ();

            // Signals
            this.split_view.welcome_shown.connect (() => {
                this.toolbar.title = this.app.app_cmd_name;
                set_widgets_sensitive (false);
            });

            this.split_view.welcome_hidden.connect (() => {
                set_widgets_sensitive (true);
            });

            this.split_view.document_change.connect ((doc) => {
                this.search_manager.set_text_view (doc.source_view);
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

                    this.toolbar.title = toolbar_title;
                }
                // Set actions sensitive property
                main_actions.get_action ("SaveFile").visible = (!settings.autosave || doc.file == null);
                main_actions.get_action ("SaveFileAs").visible = (doc.file != null);
                doc.check_undoable_actions ();
            });

            // Plugins widgets
            this.sidebar = new Gtk.Notebook ();
            this.sidebar.no_show_all = true;
            this.sidebar.page_added.connect (() => { on_plugin_toggled (sidebar); });
            this.sidebar.page_removed.connect (() => { on_plugin_toggled (sidebar); });

            this.contextbar = new Gtk.Notebook ();
            this.contextbar.no_show_all = true;
            this.contextbar.page_removed.connect (() => { on_plugin_toggled (contextbar); });
            this.contextbar.page_added.connect (() => {
                if (!this.split_view.is_empty ()) {
                    on_plugin_toggled (contextbar);
                }
            });



            this.bottombar = new Gtk.Notebook ();
            this.bottombar.no_show_all = true;
            this.bottombar.page_removed.connect (() => { on_plugin_toggled (bottombar); });
            this.bottombar.page_added.connect (() => {
                if (!this.split_view.is_empty ())
                    on_plugin_toggled (bottombar);
            });

            hp1 = new Gtk.Paned (Gtk.Orientation.HORIZONTAL);
            hp2 = new Gtk.Paned (Gtk.Orientation.HORIZONTAL);
            vp = new Gtk.Paned (Gtk.Orientation.VERTICAL);

            var content = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            content.pack_start (search_revealer, false, true, 0);
            content.pack_start (split_view, true, true, 0);
            // Set a proper position for ThinPaned widgets
            int width, height;
            this.get_size (out width, out height);

            hp1.position = 180;
            hp2.position = (width - 180);
            vp.position = (height - 150);

            hp1.pack1 (sidebar, false, false);
            hp1.pack2 (content, true, false);
            hp2.pack1 (hp1, true, false);
            hp2.pack2 (contextbar, false, false);
            vp.pack1 (hp2, true, false);
            vp.pack2 (bottombar, false, false);

            // Add everything to the window
            main_box.pack_start (loading_view, true, true, 0);
            main_box.pack_start (vp, false, true, 0);
            this.add (main_box);

            // Show/Hide widgets
            show_all ();

            this.search_revealer.set_reveal_child (false);

            main_actions.get_action ("OpenTemporaryFiles").visible = this.has_temporary_files ();
            main_actions.get_action ("SaveFile").visible = !settings.autosave;
            main_actions.get_action ("Templates").visible = plugins.plugin_iface.template_manager.template_available;
            plugins.plugin_iface.template_manager.notify["template_available"].connect ( () => {
                main_actions.get_action ("Templates").visible = plugins.plugin_iface.template_manager.template_available;
            });

            if (has_temporary_files ()) {
                action_open_temporary_files ();
            } else {
                this.split_view.show_welcome ();
            }

            // Plugins hook
            HookFunc hook_func = () => {
                plugins.hook_window (this);
                plugins.hook_toolbar (this.toolbar);
                plugins.hook_main_menu (this.toolbar.menu);
                plugins.hook_share_menu (this.toolbar.share_menu);
                plugins.hook_notebook_sidebar (this.sidebar);
                plugins.hook_notebook_context (this.contextbar);
                plugins.hook_notebook_bottom (this.bottombar);
                this.split_view.document_change.connect ((doc) => { plugins.hook_document (doc); });
                plugins.hook_split_view (this.split_view);
            };

            plugins.extension_added.connect (() => {
                hook_func ();
            });

            hook_func ();

            set_widgets_sensitive (!split_view.is_empty ());
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
            var fetch = (Gtk.ToggleAction) main_actions.get_action ("Fetch");
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
            this.toolbar.share_app_menu.sensitive = val;

            // Zoom button
            main_actions.get_action ("Zoom").visible = get_current_font_size () != get_default_font_size () && val;

            // PlugIns
            if (val) {
                on_plugin_toggled (this.contextbar);
                on_plugin_toggled (this.bottombar);
            } else {
                this.contextbar.visible = val;
                this.bottombar.visible = val;
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
            var view = this.get_current_view ();
            if (view != null) {
                return view.get_current_document ();
            }

            return null;
        }

        // Add new view
        public Scratch.Widgets.DocumentView? add_view () {
            return split_view.add_view ();
        }

        // Show LoadingView
        public void start_loading () {
            this.loading_view.start ();
            this.vp.visible = false;
            this.toolbar.sensitive = false;
        }

        // Hide LoadingView
        public void stop_loading () {
            this.loading_view.stop ();
            this.vp.visible = true;
            this.toolbar.sensitive = true;
        }

        // Open a document
        public void open_document (Scratch.Services.Document doc) {
            while (Gtk.events_pending ()) {
                Gtk.main_iteration ();
            }

            Scratch.Widgets.DocumentView? view = null;
            if (this.split_view.is_empty ()) {
                view = split_view.add_view ();
                view.open_document (doc);
            } else {
                view = split_view.get_focus_child () as Scratch.Widgets.DocumentView;
                if (view == null) {
                    view = this.split_view.current_view;
                }

                view.open_document (doc);
            }
        }

        // Close a document
        public void close_document (Scratch.Services.Document doc) {
            Scratch.Widgets.DocumentView? view = null;
            if (this.split_view.is_empty ()) {
                view = split_view.add_view ();
                view.close_document (doc);
            } else {
                view = split_view.get_focus_child () as Scratch.Widgets.DocumentView;
                if (view == null) {
                    view = this.split_view.current_view;
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
                foreach (var w in this.split_view.views) {
                    var view = w as Scratch.Widgets.DocumentView;
                    foreach (var doc in view.docs) {
                        if (!doc.close (true)) {
                            view.set_current_document (doc);
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
                    this.move (Scratch.saved_state.window_x, Scratch.saved_state.window_y);
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
            this.get_position (out x, out y);
            Scratch.saved_state.window_x = x;
            Scratch.saved_state.window_y = y;

            // Plugin panes size
            Scratch.saved_state.hp1_size = hp1.get_position ();
            Scratch.saved_state.hp2_size = hp2.get_position ();
            Scratch.saved_state.vp_size = vp.get_position ();
        }

        // Update files-opened settings key
        private void update_opened_files () {
            // File list
            string[] opened_files = {};
            this.split_view.views.foreach ((view) => {
                view.notebook.tabs.foreach ((tab) => {
                    var doc = tab as Scratch.Services.Document;
                    if (doc.file != null && doc.exists ()) {
                        opened_files += doc.file.get_uri ();
                    }
                });
            });

            // Update the opened-files setting
            if (settings.show_at_start == "last-tabs") {
                settings.opened_files = opened_files;

                // Update the focused-document setting
                string file_uri = "";
                if (this.split_view.current_view != null) {
                    var current_document = this.split_view.current_view.get_current_document();
                    if (current_document != null) {
                        file_uri = current_document.file.get_uri();
                    }
                }

                if (file_uri != "") {
                    settings.focused_document = file_uri;
                } else {
                    settings.schema.reset ("focused-document");
                }
            }
        }

        // SIGTERM/SIGINT Handling
        public bool quit_source_func () {
            action_quit ();
            return false;
        }

        // For exit cleanup
        private void handle_quit () {
            update_saved_state ();
            update_opened_files ();
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

        private void action_restore_tab () {
            
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
                    this.open_document (doc);
                }
            }

            filech.close ();
        }

        private void action_open_temporary_files () {
            try {
                var enumerator = File.new_for_path (app.data_home_folder_unsaved).enumerate_children (FileAttribute.STANDARD_NAME, 0, null);
                for (var fileinfo = enumerator.next_file (null); fileinfo != null; fileinfo = enumerator.next_file (null)) {
                    if (!fileinfo.get_name ().has_suffix ("~")) {
                        debug ("open temporary file: %s", fileinfo.get_name ());
                        var file = File.new_for_path (app.data_home_folder_unsaved + fileinfo.get_name ());
                        var doc = new Scratch.Services.Document (this.main_actions, file);
                        this.open_document (doc);
                    }
                }
            } catch (Error e) {
                critical (e.message);
            }
        }

        private void action_save () {
            var doc = this.get_current_document ();
            if (doc.is_file_temporary == true) {
                this.action_save_as ();
            } else {
                doc.save.begin ();
            }
        }

        private void action_save_as () {
            this.get_current_document ().save_as.begin ();
        }

        private void action_undo () {
            this.get_current_document ().undo ();
        }

        private void action_redo () {
            this.get_current_document ().redo ();
        }

        private void action_revert () {
            this.get_current_document ().revert ();
        }

        private void action_duplicate () {
            this.get_current_document ().duplicate_selection ();
        }

        private void action_new_tab () {
            Scratch.Widgets.DocumentView? view = null;
            if (this.split_view.is_empty ()) {
                view = split_view.add_view ();
            } else {
                view = split_view.get_focus_child () as Scratch.Widgets.DocumentView;
            }

            view.new_document ();
        }

        private void action_new_tab_from_clipboard () {
            Scratch.Widgets.DocumentView? view = null;
            if (this.split_view.is_empty ()) {
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
                this.unfullscreen ();
            } else {
                this.fullscreen ();
            }
        }

        private void action_fetch () {
            var fetch_action = (Gtk.ToggleAction) main_actions.get_action ("Fetch");
            var fetch_active = fetch_action.active;
            var current_doc = this.get_current_document ();
            // This is also called when all documents are closed.
            if (current_doc != null) {
                var selected_text = current_doc.get_selected_text ();
                if (fetch_active == false) {
                    search_manager.search_entry.text = "";
                } else if (selected_text != "") {
                    //If the user is selecting text, he plobably wants to search for it.
                    search_manager.search_entry.text = selected_text;
                }

                if (search_manager.search_entry.text != "") {
                    search_manager.search_next ();
                } else {
                    search_manager.highlight_none ();
                }
            }

            search_revealer.set_reveal_child (fetch_active);
            if (fetch_active) {
                fetch_action.tooltip = _("Hide search bar");
                search_manager.search_entry.grab_focus ();
            } else {
                fetch_action.tooltip = _("Find…");
            }
        }

        private void action_go_to () {
            var fetch_action = (Gtk.ToggleAction) main_actions.get_action ("Fetch");
            fetch_action.active = true;
            this.search_manager.go_to_entry.grab_focus ();
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
            var doc = view.get_current_document ();
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
            var doc = view.get_current_document ();
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
        private static const Gtk.ActionEntry[] main_entries = {
            { "ShowGoTo", "dialog-ok",
          /* label, accelerator */       N_("Go to line…"), "<Control>i",
          /* tooltip */                  N_("Go to line…"),
                                         action_go_to },
            { "Quit", "application-exit",
          /* label, accelerator */       N_("Quit"), "<Control>q",
          /* tooltip */                  N_("Quit"),
                                         action_quit },
            { "CloseTab", "window-close",
          /* label, accelerator */       N_("Close"), "<Control>w",
          /* tooltip */                  N_("Close"),
                                         action_close_tab },
            { "ShowReplace", "dialog-ok",
          /* label, accelerator */       N_("Replace"), "<Control>r",
          /* tooltip */                  N_("Replace"),
                                         action_fetch },
            { "RestoreTab", null,
          /* label, accelerator */       N_("Reopen closed document"), "<Control><Shift>t",
          /* tooltip */                  N_("Open last closed document in a new tab"),
                                         action_restore_tab },
            { "NewTab", "add",
          /* label, accelerator */       N_("Add New Tab"), "<Control>n",
          /* tooltip */                  N_("Add a new tab"),
                                         action_new_tab },
            { "NewView", "add",
          /* label, accelerator */       N_("Add New View"), "F3",
          /* tooltip */                  N_("Add a new view"),
                                         action_new_view },
            { "RemoveView", "window-close",
          /* label, accelerator */       N_("Remove Current View"), null,
          /* tooltip */                  N_("Remove this view"),
                                         action_remove_view },
            { "Undo", "edit-undo",
          /* label, accelerator */       N_("Undo"), "<Control>z",
          /* tooltip */                  N_("Undo the last action"),
                                         action_undo },
            { "Redo", "edit-redo",
          /* label, accelerator */       N_("Redo"), "<Control><shift>z",
          /* tooltip */                  N_("Redo the last undone action"),
                                         action_redo },
            { "Revert", "document-revert",
          /* label, accelerator */       N_("Revert"), "<Control><shift>o",
          /* tooltip */                  N_("Restore this file"),
                                         action_revert },
            { "Duplicate", null,
          /* label, accelerator */       N_("Duplicate selected strings"), "<Control>d",
          /* tooltip */                  N_("Duplicate selected strings"),
                                         action_duplicate },
            { "Open", "document-open",
          /* label, accelerator */       N_("Open"), "<Control>o",
          /* tooltip */                  N_("Open a file"),
                                         action_open },
            { "Clipboard", "edit-paste",
          /* label, accelerator */       N_("Clipboard"), null,
          /* tooltip */                  N_("New file from Clipboard"),
                                         action_new_tab_from_clipboard },
            { "Zoom", "zoom-original",
          /* label, accelerator */       N_("Zoom"), "<Control>0",
          /* tooltip */                  N_("Zoom 1:1"),
                                         action_set_default_zoom },
            { "SaveFile", "document-save",
          /* label, accelerator */       N_("Save"), "<Control>s",
          /* tooltip */                  N_("Save this file"),
                                         action_save },
            { "SaveFileAs", "document-save-as",
          /* label, accelerator */       N_("Save As…"), "<Control><shift>s",
          /* tooltip */                  N_("Save this file with a different name"),
                                         action_save_as },
            { "Templates", "text-x-generic-template",
          /* label, accelerator */       N_("Templates"), null,
          /* tooltip */                  N_("Project templates"),
                                         action_templates },
            { "Preferences", "preferences-desktop",
          /* label, accelerator */       N_("Preferences"), null,
          /* tooltip */                  N_("Change Scratch settings"),
                                         action_preferences },
            { "NextTab", "next-tab",
          /* label, accelerator */       N_("Next Tab"), "<Control><Alt>Page_Up",
          /* tooltip */                  N_("Next Tab"),
                                         action_next_tab },
            { "PreviousTab", "previous-tab",
          /* label, accelerator */       N_("Previous Tab"), "<Control><Alt>Page_Down",
          /* tooltip */                  N_("Previous Tab"),
                                         action_previous_tab },

            { "ToLowerCase", null,
          /* label, accelerator */       null, "<Control>l",
          /* tooltip */                  null,
                                         action_to_lower_case },

            { "ToUpperCase", null,
          /* label, accelerator */       null, "<Control>u",
          /* tooltip */                  null,
                                         action_to_upper_case }
        };

        private static const Gtk.ToggleActionEntry[] toggle_entries = {
            { "Fullscreen", "view-fullscreen",
          /* label, accelerator */       N_("Fullscreen"), "F11",
          /* tooltip */                  N_("Fullscreen"),
                                         action_fullscreen },
            { "Fetch", "edit-find",
          /* label, accelerator */       N_("Find…"), "<Control>f",
          /* tooltip */                  N_("Find…"),
                                         action_fetch }
        };
    }
}
