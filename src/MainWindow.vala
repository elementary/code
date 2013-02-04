// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/***
  BEGIN LICENSE
 afsd as 
  Copyright (C) 2011-2012 Mario Guerriero <mefrio.g@gmail.com>
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
using Gdk;
using Pango;

using Zeitgeist;

using Granite.Widgets;
using Granite.Services;

using Scratch.Widgets;
using Scratch.Dialogs;
using Scratch.Services;

namespace Scratch {

    public class MainWindow : Gtk.Window {

        const string ui_string = """
            <ui>
            <popup name="MenuItemTool">
                <menuitem name="Fetch" action="Fetch"/>
                <menuitem name="HideSearchBar" action="HideSearchBar"/>
                <menuitem name="CloseTab" action="CloseTab"/>
                <menuitem name="Quit" action="Quit"/>
                <menuitem name="ShowGoTo" action="ShowGoTo"/>
                <menuitem name="ShowReplace" action="ShowReplace"/>
                <menuitem name="New tab" action="New tab"/>
                <menuitem name="New view" action="New view"/>
                <menuitem name="Fullscreen" action="Fullscreen"/>
                <menuitem name="Open" action="Open"/>
                <menuitem name="Duplicate" action="Duplicate"/>
                <menuitem name="SaveFile" action="SaveFile"/>
                <menuitem name="SaveFileAs" action="SaveFileAs"/>
                <menuitem name="Undo" action="Undo"/>
                <menuitem name="Redo" action="Redo"/>
                <menuitem name="SearchNext" action="SearchNext"/>
                <menuitem name="SearchBack" action="SearchBack"/>
            </popup>
            <popup name="ToolbarContext">
                <menuitem action="ShowSidebar" />
                <menuitem action="ShowContextView" />
                <menuitem action="ShowBottomPanel" />
                <menuitem action="ShowStatusBar" />
            </popup>
            <popup name="AppMenu">
                <menuitem action="New view" />
                <menuitem action="Remove view" />
                <menuitem action="Fullscreen" />
                <menuitem action="Fetch" />
                <menuitem action="Templates" />
                <separator />
                <menuitem action="Preferences" />
            </popup>
            </ui>
        """;

        public Gtk.ActionGroup main_actions;
        Gtk.UIManager ui;

        public string TITLE = "Scratch";

        public SplitView? split_view = null;
        public Widgets.Toolbar toolbar;

        /**
         * Search manager
         */ 
        Gtk.Toolbar search_bar; 
        public Scratch.Services.SearchManager search_manager;
        
        /**
         * The Gtk.Notebook which is used to display panels which are related
         * to the current files.
         **/
        public Gtk.Notebook notebook_context;
        /**
         * A Notebook to show general panels, like file managers, project managers,
         * etc...
         **/
        public Gtk.Notebook notebook_sidebar;
        /**
         * This notebook can be used for things like terminals.
         **/
        public Gtk.Notebook notebook_bottom;

        //dialogs
        public NotificationBar info_bar;
        private Dialogs.Preferences? preferences = null;
        
        public Scratch.Widgets.Tab current_tab { get { return (Scratch.Widgets.Tab) current_notebook.current_tab; }}
        public ScratchNotebook current_notebook { get { return split_view.get_current_notebook (); } }
        public Document current_document { get { return current_tab.document; } }

        //objects for the set_theme ()
        FontDescription font;
        public Scratch.ScratchApp scratch_app;
        public Scratch.Widgets.StatusBar? statusbar = null;

        public ScratchWelcome welcome_screen;
        Granite.Widgets.HCollapsablePaned hpaned_sidebar;

        private Zeitgeist.DataSourceRegistry registry;
        
        // Signals
        public signal void welcome_state_change (Scratch.Widgets.ScratchWelcomeState state);
        
        public MainWindow (Scratch.ScratchApp scratch_app) {
            this.scratch_app = scratch_app;
            set_application (scratch_app);

            this.title = TITLE;
            this.icon_name = "accessories-text-editor";
            restore_saved_state ();
            this.window_position = Gtk.WindowPosition.CENTER;
            
            //main actions
            main_actions = new Gtk.ActionGroup ("MainActionGroup"); /* Actions and UIManager */
            main_actions.set_translation_domain (Constants.GETTEXT_PACKAGE);
            main_actions.add_actions (main_entries, this);
            main_actions.add_toggle_actions (toggle_entries, this);
            
            settings.schema.bind("sidebar-visible", main_actions.get_action ("ShowSidebar"), "active", SettingsBindFlags.DEFAULT);
            settings.schema.bind("context-visible", main_actions.get_action ("ShowContextView"), "active", SettingsBindFlags.DEFAULT);
            settings.schema.bind("bottom-panel-visible", main_actions.get_action ("ShowBottomPanel"), "active", SettingsBindFlags.DEFAULT);
            settings.schema.bind("statusbar-visible", main_actions.get_action ("ShowStatusBar"), "active", SettingsBindFlags.DEFAULT);
            main_actions.get_action ("ShowContextView").visible = false;
            main_actions.get_action ("ShowBottomPanel").visible = false;
            main_actions.get_action ("ShowSidebar").visible = false;
            main_actions.get_action ("ShowStatusBar").visible = false;
            main_actions.get_action ("Templates").sensitive = plugins.plugin_iface.template_manager.template_available;
            plugins.plugin_iface.template_manager.notify["template_available"].connect ( () => {
                main_actions.get_action ("Templates").sensitive = plugins.plugin_iface.template_manager.template_available;
            });
            
            ui = new Gtk.UIManager ();

            try {
                ui.add_ui_from_string (ui_string, -1);
            }
            catch(Error e) {
                error ("Couldn't load the UI: %s", e.message);
            }

            Gtk.AccelGroup accel_group = ui.get_accel_group();
            add_accel_group (accel_group);

            ui.insert_action_group (main_actions, 0);
            ui.ensure_update ();

            create_window ();
            connect_signals ();
            
            /* Update app status at settings updates */
            settings.schema.changed.connect ((key) => {  
                if (key == "autosave" && settings.autosave == false)
                    action_save_all ();
            });
             
            set_theme ();
            
            // Set up the Data Source Registry
            registry = new DataSourceRegistry ();
            
            var ds_event = new Zeitgeist.Event();
            ds_event.set_actor("application://scratch.desktop");
            ds_event.add_subject(new Zeitgeist.Subject());
            PtrArray ptr_array = new PtrArray.with_free_func (Object.unref);
            ptr_array.add(ds_event);
            var ds = new DataSource.full (  "scratch-logger",
                                            _("Zeitgeist Datasource for Scratch"),
                                            "A data source which logs Open, Close, Save and Move Events",
                                            (owned)ptr_array); // FIXME: templates!
            try
            {
                registry.register_data_source (ds, null);
            }
            catch (GLib.Error reg_err)
            {
                warning ("%s", reg_err.message);
            }
            
            // Set minimum window size.
            this.set_size_request(300,250);
        }

        public void on_drag_data_received (Gdk.DragContext context, int x, int y, SelectionData selection_data, uint info, uint time_) {

            foreach (string s in selection_data.get_uris ()) {
                try {
                    scratch_app.open_file (s);
                }
                catch (Error e) {
                    warning ("%s doesn't seem to be a valid URI, couldn't open it.", s);
                }
            }

        }

        /**
         * This function checks the settings and show the sidebar (or the sidepanel)
         * if needed when a page is added.
         **/
        void on_notebook_context_new_page (Gtk.Notebook notebook, Widget page, uint num) {

            string part = "bottom-panel-visible";
            bool has_tabs = notebook.get_n_pages() > 0;

            if (notebook == notebook_context)
            {
                part = "context-visible";
                main_actions.get_action ("ShowContextView").visible = has_tabs;
            }
            else if (notebook == notebook_sidebar)
            {
                part = "sidebar-visible";
                main_actions.get_action ("ShowSidebar").visible = has_tabs;
            }
            else if (notebook == notebook_bottom)
            {
                part = "bottom-panel-visible";
                main_actions.get_action ("ShowBottomPanel").visible = has_tabs;
            }

            if (has_tabs) {
                page.show_all();
                notebook.show_tabs = num >= 1;
            }
            notebook_settings_changed (part);
            
            ui.ensure_update ();

        }

        public void notebook_settings_changed (string key) {

            bool key_value = settings.schema.get_boolean (key);
            Gtk.Notebook? notebook = null;
            if (key == "context-visible") {
                notebook = notebook_context;
            }
            else if (key == "sidebar-visible") {
                notebook = notebook_sidebar;
            }
            else if (key == "bottom-panel-visible") {
                notebook = notebook_bottom;
            }
            /* So, now we know which notebook we are talking about. */
            if (notebook != null)
            {
                /* We can hide it by default */
                notebook.hide ();
                /* Stop here if it must be hidden */
                if (!key_value)
                    return;
                /* Now, let's check there is at least one visible
                 * children notebook in it, and show it if it is the case */

                foreach (var w in notebook.get_children ())
                {
                    if (w.visible)
                    {
                        notebook.show_all ();
                        return;
                    }
                }
            }

        }

        void on_split_view_page_changed (Gtk.Widget w) {

            if (w is Scratch.Widgets.SourceView) {
                search_manager.set_text_view ((Scratch.Widgets.SourceView) w);
            }
            else
                warning("The focused widget is not a valid TextView");

        }
        
        Gtk.Box? vbox_split_view_toolbar = null;

        public void create_window () {

            this.toolbar = new Widgets.Toolbar (this, ui, main_actions);
            
            notebook_context = new Gtk.Notebook ();
            notebook_context.page_added.connect (on_notebook_context_new_page);
            notebook_context.page_removed.connect (on_notebook_context_new_page);
            var hpaned_addons = new Granite.Widgets.HCollapsablePaned ();
            var vpaned_bottom_panel = new Granite.Widgets.VCollapsablePaned ();

            notebook_sidebar = new Gtk.Notebook ();
            notebook_sidebar.page_added.connect (on_notebook_context_new_page);
            notebook_sidebar.page_removed.connect (on_notebook_context_new_page);
            hpaned_sidebar = new Granite.Widgets.HCollapsablePaned ();
            hpaned_addons.pack1 (hpaned_sidebar, true, true);

            split_view = new SplitView (this);
            split_view.page_changed.connect (on_split_view_page_changed);
            split_view.notify["is-empty"].connect (on_split_view_empty_changed);
            welcome_screen = new ScratchWelcome (this);
            hpaned_sidebar.pack1 (notebook_sidebar, false, false);
            notebook_sidebar.visible = false;
            
            
            vbox_split_view_toolbar = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            statusbar = new Scratch.Widgets.StatusBar ();
            vbox_split_view_toolbar.pack_start (split_view, true, true, 0);
            vbox_split_view_toolbar.pack_end (statusbar, false, false, 0);
            hpaned_sidebar.pack2 (vbox_split_view_toolbar, true, true);
            
            hpaned_addons.pack2 (notebook_context, false, false);
            notebook_context.visible = true;
            settings.schema.changed.connect (notebook_settings_changed);

            plugins.sidebar = notebook_sidebar;
            plugins.hook_notebook_sidebar ();
            plugins.context = notebook_context;
            plugins.hook_notebook_context ();
            
            /**
             * Search manager
             */ 
            search_manager = new Scratch.Services.SearchManager (main_actions);
            //Scratch.settings.schema.bind ("search-sensitive", search_manager, "case-sensitive", SettingsBindFlags.DEFAULT);
            search_manager.need_hide.connect (hide_search_bar);
            
            search_bar = new Gtk.Toolbar ();
            search_bar.get_style_context ().add_class ("secondary-toolbar");
            search_bar.add (search_manager.get_search_entry ());
            search_bar.add (search_manager.get_arrow_previous ());
            search_bar.add (search_manager.get_arrow_next ());
            search_manager.get_replace_entry ().set_margin_left (5);
            search_bar.add (search_manager.get_replace_entry ());
            var spacer = new Gtk.ToolItem ();
            spacer.set_expand (true);
            search_bar.add (spacer);
            search_bar.add (search_manager.get_go_to_label ());
            search_manager.get_go_to_label ().set_margin_right (5);
            search_bar.add (search_manager.get_go_to_entry ());
            search_bar.add (search_manager.get_close_button ());
            
            /**
             * Info bar
             */
            info_bar = new NotificationBar ();
            info_bar.no_show_all = true;
            
            var notebook =  new ScratchNotebook (this);
            notebook.switch_page.connect( () => { hide_search_bar(); });
            search_bar.no_show_all = true;
            search_bar.visible = false;
            split_view.additional_widget = search_bar;
            split_view.info_bar = info_bar;
            split_view.add_view (notebook);

            notebook_bottom = new Gtk.Notebook ();
            notebook_bottom.page_added.connect (on_notebook_context_new_page);
            notebook_bottom.page_removed.connect (on_notebook_context_new_page);
 
            /* Add the sourceview + the sidepanel to the container of the bottom panel */
            vpaned_bottom_panel.pack1 (hpaned_addons, true, true);
            vpaned_bottom_panel.pack2 (notebook_bottom, false, false);
            plugins.hook_notebook_bottom (notebook_bottom);
            
            //adding all to the vbox
            var vbox = new VBox (false, 0);
            vbox.pack_start (toolbar, false, false, 0);
            vbox.pack_start (vpaned_bottom_panel, true, true, 0);
            vbox.show_all ();

            this.add (vbox);

            set_undo_redo ();

            show_all();
            toolbar.show_hide_button ();
            notebook_settings_changed ("sidebar-visible");
            notebook_settings_changed ("context-visible");
            notebook_settings_changed ("bottom-panel-visible");
            
            main_actions.get_action ("ShowStatusBar").visible = false;
            statusbar.check ();
            
            on_split_view_empty_changed ();

            /* trap SIGINT and SIGTERM and terminate properly when catching one */
            Unix.signal_add (Posix.SIGINT, action_quit_source_func, Priority.HIGH);
            Unix.signal_add (Posix.SIGTERM, action_quit_source_func, Priority.HIGH);

        }
        
        void hide_search_bar () {
            search_bar.no_show_all = true;
            search_bar.visible = false;
            current_tab.text_view.grab_focus ();            
        }

        public void set_actions (bool val) {

            main_actions.get_action ("SaveFile").set_sensitive (val);
            main_actions.get_action ("SaveFileAs").set_sensitive (val);
            main_actions.get_action ("Undo").set_sensitive (val);
            main_actions.get_action ("Redo").set_sensitive (val);
            main_actions.get_action ("Revert").set_sensitive (val);
            main_actions.get_action ("Fetch").set_sensitive (val);
            main_actions.get_action ("HideSearchBar").set_sensitive (val);
            main_actions.get_action ("ShowReplace").set_sensitive (val);
            main_actions.get_action ("ShowGoTo").set_sensitive (val);
            bool split_view_not_full = split_view.get_children ().length () < split_view.max - 1;
            bool split_view_multiple_view = split_view.get_children ().length () > 1;
            if (!val) main_actions.get_action ("New view").set_sensitive (false);
            else main_actions.get_action ("New view").set_sensitive (split_view_not_full);
            main_actions.get_action ("Remove view").set_sensitive (val ? split_view_multiple_view : false);
            main_actions.get_action ("ShowStatusBar").set_sensitive (val);
            toolbar.set_actions (val);
            //toolbar.search_arrow.set_sensitive (val);
        }

        void on_split_view_empty_changed ()
        {
            if (split_view.is_empty) {
                set_actions (false);
                
                if (statusbar != null) {
                    statusbar.check ();
                    action_show_status_bar (main_actions.get_action ("ShowStatusBar"));
                }
                
                welcome_state_change (ScratchWelcomeState.HIDE);
                
                if (split_view.get_parent () != null && vbox_split_view_toolbar != null) {
                    vbox_split_view_toolbar.remove (split_view);
                    vbox_split_view_toolbar.remove (statusbar);
                    vbox_split_view_toolbar.pack_start (welcome_screen, true, true);
                    /* Set the window title for the WelcomeScreen */
                    this.title = TITLE;
                }

                toolbar.set_button_sensitive (toolbar.ToolButtons.SAVE_BUTTON, false);
                toolbar.set_button_sensitive (toolbar.ToolButtons.UNDO_BUTTON, false);
                toolbar.set_button_sensitive (toolbar.ToolButtons.REPEAT_BUTTON, false);
                toolbar.set_button_sensitive (toolbar.ToolButtons.SHARE_BUTTON, false);
            }

            else {
                set_actions (true);
                
                if (statusbar != null) {
                    statusbar.check ();
                    action_show_status_bar (main_actions.get_action ("ShowStatusBar"));
                }
                
                welcome_state_change (ScratchWelcomeState.SHOW);
                
                if (split_view.get_parent () == null && vbox_split_view_toolbar != null) {
                    vbox_split_view_toolbar.remove (welcome_screen);
                    vbox_split_view_toolbar.pack_start (split_view, true, true);
                    vbox_split_view_toolbar.pack_end (statusbar, false, false, 0);
                }
            }
        }

        public void set_theme () {
            Gtk.Settings.get_default ().gtk_application_prefer_dark_theme = false;

            // Get the system's style
            realize ();
            font = FontDescription.from_string(system_font ());
        }

        static string system_font () {

            string font_name = null;
            /* Try to use Gnome3 settings? */
            var settings = new GLib.Settings ("org.gnome.desktop.interface");
            font_name = settings.get_string ("monospace-font-name");
            //font_name = "Ubuntu Regular 10";
            return font_name;
        }

        public void connect_signals () {
            drag_data_received.connect (on_drag_data_received);
        }
        
        void update_opened_files () {
            int n = 0;
            var opened_files = new string [scratch_app.documents.length ()];
            foreach (var doc in scratch_app.documents) {            
                if (doc.name != null) {
                    opened_files[n] = doc.filename;
                    n++;
                }
            }
            /* Update the opened-files setting */
            if (settings.show_at_start == "last-tabs")
               /*settings.opened_files = opened_files;*/settings.schema.set_strv ("opened-files", opened_files);    
        }
        
        void action_preferences () {
            if (preferences == null)
                preferences = new Dialogs.Preferences (_("Preferences"), this);
            preferences.show_all ();
            preferences.run ();
            preferences.hide ();
        }

        void action_close_tab () {
            current_tab.on_close_clicked ();
        }

        void action_quit () {
            update_saved_state ();
            update_opened_files ();
            
            uint n = 0;
            bool quit = true;
            
            foreach (var doc in scratch_app.documents) {            
                if (doc.modified) {
                    var save_dialog = new SaveOnCloseDialog (doc.name, this);
                    doc.focus_sourceview ();
                    int response = save_dialog.run ();
                    switch (response) {
                    case Gtk.ResponseType.CANCEL:
                        save_dialog.destroy ();
                        quit = false;
                        break;
                    case Gtk.ResponseType.YES:
                        doc.save ();
                        quit = true;
                        break;
                    case Gtk.ResponseType.NO:
                        quit = true;
                        break;
                    }
                    save_dialog.destroy ();
                }
                doc.delete_backup ();
                if (n != scratch_app.documents.length ())
                    n++;
            }
            
            if (quit)
                destroy ();
        }

        public bool action_quit_source_func () {
        /**
         * wrapper for the actual action_quit () method that can be passed to
         * methods that expect Glib.SourceFunc method signature
         */
            action_quit ();
            return false;
        }

        public void action_new_tab () {
            var doc = new Document.empty (this);
            scratch_app.open_document (doc);
            if (settings.autosave)
                this.toolbar.save_button.show ();
        }

        public void action_open_clicked () {

            toolbar.set_sensitive (true);

            // show dialog
            var filech = new FileChooserDialog (_("Open a file"), this, FileChooserAction.OPEN, null);
            filech.set_select_multiple (true);
            filech.add_button (Stock.CANCEL, ResponseType.CANCEL);
            filech.add_button (Stock.OPEN, ResponseType.ACCEPT);
            filech.set_default_response (ResponseType.ACCEPT);
            filech.set_current_folder_uri (scratch_app.current_directory);
            filech.key_press_event.connect ((ev) => {
                if (ev.keyval == 65307) // Esc key
                    filech.destroy ();
                return false;
            });
            var all_files_filter = new FileFilter();
            all_files_filter.set_filter_name(_("All files"));
            all_files_filter.add_pattern("*");
            var text_files_filter = new FileFilter();
            text_files_filter.set_filter_name(_("Text files"));
            text_files_filter.add_mime_type("text/*");
            filech.add_filter(all_files_filter);
            filech.add_filter(text_files_filter);
            filech.set_filter(text_files_filter);

            if (filech.run () == ResponseType.ACCEPT)
                    foreach (string file in filech.get_uris ()) {
                        scratch_app.open_file (file);   
                        scratch_app.current_directory = Path.get_dirname (file);
                    }
            
            filech.close ();
            set_undo_redo ();
        }

        public void open (string filename) {
            scratch_app.open_file (filename);
        }

        public void action_save () {
            current_tab.document.save ();
        }

        public void action_save_all () {
            int n = 0;
            string[] opened_files = {};
            
            foreach (var doc in scratch_app.documents) {            
                
                if (doc.filename != null)
                    opened_files[n] = doc.filename;
                else
                    return;
                
                doc.save ();
            }
        }        
        
        public void action_save_as () {
            current_tab.document.save_as ();
        }

        /**
         * @deprecated
         **/
        public Scratch.Widgets.SourceView get_active_view () {
            return current_tab.text_view;
        }

        /**
         * @deprecated
         **/
        public Gtk.TextBuffer? get_active_buffer () {
            if (current_tab != null) return current_tab.text_view.buffer;
            return null;
        }

        public bool can_write (string filename) {

            if (filename != null) {
                FileInfo info;
                var file = File.new_for_path (filename);
                bool writable;

                try {
                    info = file.query_info (FileAttribute.ACCESS_CAN_WRITE, FileQueryInfoFlags.NONE, null);
                    writable = info.get_attribute_boolean (FileAttribute.ACCESS_CAN_WRITE);
                    return writable;
                } catch (Error e) {
                    warning ("%s", e.message);
                    return false;
                }

            } else {
                return true;
            }

        }

        public void set_window_title (string filename) {

            var home_dir = Environment.get_home_dir ();
            var path = Path.get_dirname (filename).replace (home_dir, "~");
            path = path.replace ("file://", "");
            
            if ("trash://" in path)
                path = _("Trash");
            
            var file = File.new_for_uri (filename);
            
            this.title = file.get_basename () + " (%s) - %s".printf(path, TITLE);

        }

        protected override bool delete_event (Gdk.EventAny event) {
            
            update_saved_state ();
            update_opened_files ();
            
            uint n = 0;
            bool ret = false;
            
            foreach (var doc in scratch_app.documents) {            
                if (doc.modified) {
                    var save_dialog = new SaveOnCloseDialog (doc.name, this);
                    doc.focus_sourceview ();
                    int response = save_dialog.run ();
                    switch (response) {
                    case Gtk.ResponseType.CANCEL:
                        save_dialog.destroy ();
                        return true;
                    case Gtk.ResponseType.YES:
                        doc.save ();
                        ret = false;
                        break;
                    case Gtk.ResponseType.NO:
                        ret = false;
                        break;
                    }
                    save_dialog.destroy ();
                }
                doc.delete_backup ();
                if (n == scratch_app.documents.length ())
                    return ret;
                else
                    n++;
            }

            return false;

        }

        private void restore_saved_state () {

            default_width = Scratch.saved_state.window_width;
            default_height = Scratch.saved_state.window_height;

            if (Scratch.saved_state.window_state == ScratchWindowState.MAXIMIZED)
                maximize ();
            else if (Scratch.saved_state.window_state == ScratchWindowState.FULLSCREEN)
                fullscreen ();

        }

        private void update_saved_state () {

            // Save window state
            if (get_window ().get_state () == WindowState.MAXIMIZED)
                Scratch.saved_state.window_state = ScratchWindowState.MAXIMIZED;
            else if (get_window ().get_state () == WindowState.FULLSCREEN)
                Scratch.saved_state.window_state = ScratchWindowState.FULLSCREEN;
            else
                Scratch.saved_state.window_state = ScratchWindowState.NORMAL;

            // Save window size
            if (Scratch.saved_state.window_state == ScratchWindowState.NORMAL) {
                int width, height;
                get_size (out width, out height);
                Scratch.saved_state.window_width = width;
                Scratch.saved_state.window_height = height;
            }

        }

        public void set_undo_redo () {

            bool undo = false;
            bool redo = false;

            if (current_tab != null) {
                undo = current_document.can_undo;
                redo = current_document.can_redo;
            }

            main_actions.get_action ("Undo").set_sensitive (undo);
            main_actions.get_action ("Redo").set_sensitive (redo);

            toolbar.set_button_sensitive (toolbar.ToolButtons.UNDO_BUTTON, undo);
            toolbar.set_button_sensitive (toolbar.ToolButtons.REPEAT_BUTTON, redo);

        }

        public void create_instance () {

            if (split_view.get_children ().length () <= 1) {

                var instance = new ScratchNotebook (this);
                instance.switch_page.connect( () => { hide_search_bar(); });
                instance.additional_widget = search_bar;
                instance.info_bar = info_bar;
                split_view.add_view (instance);
                var doc = new Document.empty (this);
                instance.grab_focus ();
                scratch_app.open_document (doc);

            }
            
            if (split_view.get_children ().length () == 2)
                ; //main_actions.get_action ().
                

        }

        void case_up () {
            search_manager.search_previous ();
        }

        void case_down () {
            search_manager.search_next ();
        }

        void action_undo () {
            current_document.undo ();
            set_undo_redo ();
        }
        void action_redo () {
            current_document.redo ();
            set_undo_redo ();
        }

        void action_revert () {
            current_document.backup ();

            if (current_document.file.query_exists ())
                current_document.save ();
        }
        
        void action_duplicate () {
            if (current_tab != null) {
                TextIter start, end;
                var buf = current_tab.text_view.buffer;
                buf.get_selection_bounds (out start, out end);
                string selected = buf.get_text (start, end, true);
                if (selected != "")
                    buf.insert (ref end, "\n" + selected, -1);
                // If nothing is selected duplicate current line
                else {
                    buf.get_iter_at_mark (out start, buf.get_insert ());
                    if (!start.starts_line ()) start.backward_sentence_start ();

                    buf.get_iter_at_mark (out end, buf.get_insert ());
                    if (!end.ends_line ()) end.forward_sentence_end ();
                        
                    selected = buf.get_text (start, end, true);
                    buf.insert (ref end, "\n" + selected, -1);
                }
            }
                
        }        
        
        void action_new_view () {
            create_instance ();
            set_actions (true);
        }

        void action_fullscreen () {
            if ((get_window ().get_state () & WindowState.FULLSCREEN) != 0)
            {
                this.unfullscreen ();
            }
            else
            {
                this.fullscreen ();
            }
        }
        
        void action_remove_view () {
            var notebook = split_view.get_current_notebook ();

            foreach(var w in notebook.get_children ()) {
                var tab = w as Scratch.Widgets.Tab;
                if (tab != null) {
                    var doc = tab.document;
                    if (doc.modified) {
                        var save_dialog = new SaveOnCloseDialog (doc.name, this);
                        int response = save_dialog.run ();
                        switch(response) {
                        case Gtk.ResponseType.CANCEL:
                            save_dialog.destroy ();
                            return;
                        case Gtk.ResponseType.YES:
                            doc.save ();
                            break;
                        case Gtk.ResponseType.NO:
                            break;
                        }
                        save_dialog.destroy ();
                        scratch_app.documents.remove (doc);
                    }
                }
            }

            if (split_view != null)
                split_view.remove_current_view ();
        }
        
        void action_show_status_bar (Gtk.Action action) {
            if (statusbar != null) {
                if (!((Gtk.ToggleAction)action).active || statusbar.get_children ().length () == 0) {
                    statusbar.no_show_all = true;
                    statusbar.visible = false;
                    Scratch.settings.statusbar_visible = false;
                }
                else {
                    statusbar.no_show_all = false;
                    statusbar.visible = true;
                    Scratch.settings.statusbar_visible = true;
                }

                statusbar.check ();
            }
        }
        
        void action_fetch () {
            /* Get selected text to put it in the  search entry */
            if (current_tab != null) {
                TextIter start, end;
                var buf = current_tab.text_view.buffer;
                buf.get_selection_bounds (out start, out end);
                string selected = buf.get_text (start, end, true);
                selected = selected.chomp ().replace ("\n", " ");
                if (selected != "")
                    search_manager.search_entry.text = selected;
            }
            
            search_bar.no_show_all = false;
            search_bar.show_all ();
        }
        
        void action_templates () {
            plugins.plugin_iface.template_manager.show_window (this);
        }

        static const Gtk.ActionEntry[] main_entries = {
           { "Fetch", Gtk.Stock.SAVE,
          /* label, accelerator */       N_("Find..."), "<Control>f",
          /* tooltip */                  N_("Find..."),
                                         action_fetch },
           { "HideSearchBar", Gtk.Stock.CLEAR,
          /* label, accelerator */       N_("Hide search bar"), "Escape",
          /* tooltip */                  N_("Hide search bar"),
                                         hide_search_bar },
           { "ShowGoTo", Gtk.Stock.OK,
          /* label, accelerator */       N_("Go to line..."), "<Control>i",
          /* tooltip */                  N_("Go to line..."),
                                         action_fetch },
           { "Quit", Gtk.Stock.QUIT,
          /* label, accelerator */       N_("Quit"), "<Control>q",
          /* tooltip */                  N_("Quit"),
                                         action_quit },
           { "CloseTab", Gtk.Stock.CLOSE,
          /* label, accelerator */       N_("Close"), "<Control>w",
          /* tooltip */                  N_("Close"),
                                         action_close_tab },
           { "ShowReplace", Gtk.Stock.OK,
          /* label, accelerator */       N_("Replace"), "<Control>r",
          /* tooltip */                  N_("Replace"),
                                         action_fetch },
           { "New tab", Gtk.Stock.NEW,
          /* label, accelerator */       N_("New document"), "<Control>t",
          /* tooltip */                  N_("Create a new document in a new tab"),
                                         action_new_tab },
           { "New view", Gtk.Stock.NEW,
          /* label, accelerator */       N_("Add New View"), "F3",
          /* tooltip */                  N_("Add a new view"),
                                         action_new_view },

           { "Remove view", Gtk.Stock.CLOSE,
          /* label, accelerator */       N_("Remove Current View"), null,
          /* tooltip */                  N_("Remove this view"),
                                         action_remove_view },
           { "Undo", Gtk.Stock.UNDO,
          /* label, accelerator */       N_("Undo"), "<Control>z",
          /* tooltip */                  N_("Undo the last action"),
                                         action_undo },
           { "Redo", Gtk.Stock.REDO,
          /* label, accelerator */       N_("Redo"), "<Control><shift>z",
          /* tooltip */                  N_("Redo the last undone action"),
                                         action_redo },

          { "Revert", Gtk.Stock.REVERT_TO_SAVED,
          /* label, accelerator */       N_("Revert"), "<Control><shift>o",
          /* tooltip */                  N_("Restore this file"),
                                         action_revert },

           { "SearchNext", "go-next-symbolic",
          /* label, accelerator */       N_("Next Search"), "<Control>g",
          /* tooltip */                  N_("Next Search"),
                                         case_down },
           { "SearchBack", "go-previous-symbolic",
          /* label, accelerator */       N_("Previous Search"), "<Control><shift>g",
          /* tooltip */                  N_("Previous Search"),
                                         case_up },
                                         
           { "Duplicate", null,
          /* label, accelerator */       N_("Duplicate selected strings"), "<Control>d",
          /* tooltip */                  N_("Duplicate selected strings"),
                                         action_duplicate },
                                         
           { "Open", Gtk.Stock.OPEN,
          /* label, accelerator */       N_("Open"), "<Control>o",
          /* tooltip */                  N_("Open a file"),
                                         action_open_clicked },
           { "SaveFile", Gtk.Stock.SAVE,
          /* label, accelerator */       N_("Save"), "<Control>s",
          /* tooltip */                  N_("Save the current file"),
                                         action_save },
           { "SaveFileAs", Gtk.Stock.SAVE_AS,
          /* label, accelerator */       N_("Save as"), "<Control><Shift>s",
          /* tooltip */                  N_("Save the current file with a different name"),
                                         action_save_as },
           { "Templates", Gtk.Stock.NEW,
          /* label, accelerator */       N_("Templates"), null,
          /* tooltip */                  N_("Create a new document from a template"),
                                         action_templates },
           { "Preferences", Gtk.Stock.PREFERENCES,
          /* label, accelerator */       N_("Preferences"), null,
          /* tooltip */                  N_("Change Scratch settings"),
                                         action_preferences }
        };

        static const Gtk.ToggleActionEntry[] toggle_entries = {
           { "Fullscreen", Gtk.Stock.FULLSCREEN,
          /* label, accelerator */       N_("Fullscreen"), "F11",
          /* tooltip */                  N_("Fullscreen"),
                                         action_fullscreen },
           { "ShowSidebar", "",
          /* label, accelerator */       N_("Sidebar"), null,
          /* tooltip */                  N_("Sidebar"),
                                         null },
           { "ShowContextView", "",
          /* label, accelerator */       N_("Context View"), null,
          /* tooltip */                  N_("Context View"),
                                         null },
           { "ShowStatusBar", "",
          /* label, accelerator */       N_("Status Bar"), null,
          /* tooltip */                  N_("Status Bar"),
                                         action_show_status_bar, true },
           { "ShowBottomPanel", "",
          /* label, accelerator */       N_("Bottom Panel"), null,
          /* tooltip */                  N_("Bottom Panel"),
                                         null }
   
        };

    }
} // Namespace
