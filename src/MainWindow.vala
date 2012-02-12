// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/***
  BEGIN LICENSE

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
                <separator />
                <menuitem action="Preferences" />
            </popup>
            </ui>
        """;

        public Gtk.ActionGroup main_actions;
        Gtk.UIManager ui;

        public string TITLE = "Scratch";

        public SplitView split_view;
        public Widgets.Toolbar toolbar;
        
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
        public FileChooserDialog filech;

        public Tab current_tab { get { return (Tab) current_notebook.current_tab; }}
        public ScratchNotebook current_notebook { get { return split_view.get_current_notebook (); } }
        public Document current_document { get { return current_tab.document; } }

        //objects for the set_theme ()
        FontDescription font;
        public Scratch.ScratchApp scratch_app;
        public StatusBar statusbar;

        ScratchWelcome welcome_screen;
        Granite.Widgets.HCollapsablePaned hpaned_sidebar;


        public MainWindow (Scratch.ScratchApp scratch_app) {
            this.scratch_app = scratch_app;
            set_application (scratch_app);

            this.title = TITLE;
            restore_saved_state ();

            //main actions
            main_actions = new Gtk.ActionGroup ("MainActionGroup"); /* Actions and UIManager */
            main_actions.set_translation_domain ("scratch");
            main_actions.add_actions (main_entries, this);
            main_actions.add_toggle_actions (toggle_entries, this);
            
            settings.schema.bind("sidebar-visible", main_actions.get_action ("ShowSidebar"), "active", SettingsBindFlags.DEFAULT);
            settings.schema.bind("context-visible", main_actions.get_action ("ShowContextView"), "active", SettingsBindFlags.DEFAULT);
            settings.schema.bind("bottom-panel-visible", main_actions.get_action ("ShowBottomPanel"), "active", SettingsBindFlags.DEFAULT);
            main_actions.get_action ("ShowContextView").visible = false;
            main_actions.get_action ("ShowBottomPanel").visible = false;
            main_actions.get_action ("ShowSidebar").visible = false;
            main_actions.get_action ("ShowStatusBar").visible = false;
            
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
            settings.schema.bind("statusbar-visible", main_actions.get_action ("ShowStatusBar"), "active", SettingsBindFlags.DEFAULT);
            connect_signals ();
            
            set_theme ();
        }

        public void on_drag_data_received (Gdk.DragContext context, int x, int y, SelectionData selection_data, uint info, uint time_) {

            foreach (string s in selection_data.get_uris ()) {
                try {
                    //var w = get_toplevel () as MainWindow;
                    scratch_app.open_file (Filename.from_uri (s));
                    //w.set_undo_redo ();
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
                toolbar.search_manager.set_text_view ((Scratch.Widgets.SourceView) w);
            }
            else
                warning("The focused widget is not a valid TextView");

        }
        
        Gtk.VBox vbox_split_view_toolbar;

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
            welcome_screen = new ScratchWelcome (this);
            split_view.notify["is-empty"].connect (on_split_view_empty_changed);
            hpaned_sidebar.pack1 (notebook_sidebar, false, false);
            notebook_sidebar.visible = false;
            
            
            vbox_split_view_toolbar = new Gtk.VBox(false, 0);
            statusbar = new StatusBar ();
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

            var notebook =  new ScratchNotebook (this);
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

            on_split_view_empty_changed ();

            show_all();
            toolbar.show_hide_button ();
            notebook_settings_changed ("sidebar-visible");
            notebook_settings_changed ("context-visible");
            notebook_settings_changed ("bottom-panel-visible");
            
            
            main_actions.get_action ("ShowStatusBar").visible = false;

        }

        public void set_actions (bool val) {

            main_actions.get_action ("SaveFile").set_sensitive (val);
            main_actions.get_action ("SaveFileAs").set_sensitive (val);
            main_actions.get_action ("Undo").set_sensitive (val);
            main_actions.get_action ("Redo").set_sensitive (val);
            main_actions.get_action ("Revert").set_sensitive (val);
            main_actions.get_action ("Fetch").set_sensitive (val);
            main_actions.get_action ("ShowReplace").set_sensitive (val);
            main_actions.get_action ("ShowGoTo").set_sensitive (val);
            bool split_view_not_full = split_view.get_children ().length () < split_view.max - 1;
            bool split_view_multiple_view = split_view.get_children ().length () > 1;
            main_actions.get_action ("New view").set_sensitive (val ? split_view_not_full : false);
            main_actions.get_action ("Remove view").set_sensitive (val ? split_view_multiple_view : false);
            main_actions.get_action ("ShowStatusBar").set_sensitive (val);
            toolbar.set_actions (val);
            toolbar.search_arrow.set_sensitive (val);
        }

        void on_split_view_empty_changed ()
        {
            if (split_view.is_empty) {
                set_actions (false);
                
                statusbar.no_show_all = true;
                statusbar.visible = false;

                if (split_view.get_parent () != null) {
                    vbox_split_view_toolbar.remove (split_view);
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
                
                action_show_status_bar (main_actions.get_action ("ShowStatusBar"));

                if (split_view.get_parent () == null) {
                    vbox_split_view_toolbar.remove (welcome_screen);
                    vbox_split_view_toolbar.pack_start (split_view, true, true);
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
        
        void action_preferences () {
            var dialog = new Dialogs.Preferences ("Preferences", this);
            dialog.show_all ();
            dialog.run ();
            dialog.destroy ();
        }

        void action_close_tab () {
            current_tab.on_close_clicked ();
        }

        void action_quit () {
            int n = 0;
            string[] opened_files = {};
            
            foreach (var doc in scratch_app.documents) {            
                
                if (doc.filename != null) {
                    opened_files[n] = doc.filename;
                }
                
                if (doc.modified) {
                    var save_dialog = new SaveOnCloseDialog (doc.name, this);
                    int response = save_dialog.run ();
                    switch (response) {
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
                }
                var bk = File.new_for_path (doc.filename + "~");
                if (bk.query_exists ()) {
                    try {
                        bk.delete ();
                    } catch (Error e) {
                        debug ("Cannot delete %s~, it doesn't exist", doc.filename);
                    }
                }
                n++;
            }
            
            /*
             * Update the opened-files setting
             */
            if (settings.show_at_start == "last-tabs") {               
               settings.schema.set_strv ("opened-files", opened_files);   
            } 
        }

        public void action_new_tab () {
            var doc = new Document.empty (this);
            scratch_app.open_document (doc);
            current_notebook.show_tabs_view ();
            if (settings.autosave)
                this.toolbar.save_button.show ();
        }

        public void action_open_clicked () {

            toolbar.set_sensitive (true);

            // show dialog
            this.filech = new FileChooserDialog (_("Open a file"), this, FileChooserAction.OPEN, null);
            filech.set_select_multiple (true);
            filech.add_button (Stock.CANCEL, ResponseType.CANCEL);
            filech.add_button (Stock.OPEN, ResponseType.ACCEPT);
            filech.set_default_response (ResponseType.ACCEPT);
            filech.set_current_folder (scratch_app.current_directory);
            var all_files_filter = new FileFilter();
            all_files_filter.set_filter_name(_("All files"));
            all_files_filter.add_pattern("*");
            var text_files_filter = new FileFilter();
            text_files_filter.set_filter_name(_("Text files"));
            text_files_filter.add_mime_type("text/*");
            filech.add_filter(all_files_filter);
            filech.add_filter(text_files_filter);
            filech.set_filter(all_files_filter);

            if (filech.run () == ResponseType.ACCEPT)
                    foreach (string file in filech.get_filenames ())
                        scratch_app.open_file (file);
            
            current_tab.make_backup ();            
            
            filech.close ();
            set_undo_redo ();
        }

        public void open (string filename) {
            scratch_app.open_file (filename);
        }

        public void action_save () {
            current_tab.document.save ();
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
                    info = file.query_info (FILE_ATTRIBUTE_ACCESS_CAN_WRITE, FileQueryInfoFlags.NONE, null);
                    writable = info.get_attribute_boolean (FILE_ATTRIBUTE_ACCESS_CAN_WRITE);
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

            this.title = Path.get_basename (filename) + " (%s) - %s".printf(path, TITLE);

        }

#if VALA_0_14
        protected override bool delete_event (Gdk.EventAny event) {
#else
        protected override bool delete_event (Gdk.Event event) {
#endif

            update_saved_state ();
            action_quit ();
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
            if ((get_window ().get_state () & WindowState.MAXIMIZED) != 0)
                Scratch.saved_state.window_state = ScratchWindowState.MAXIMIZED;
            else if ((get_window ().get_state () & WindowState.FULLSCREEN) != 0)
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

            if (split_view.get_children ().length () <= 2) {

                var instance = new ScratchNotebook (this);
                split_view.add_view (instance);
                var doc = new Document.empty (this);
                instance.grab_focus ();
                scratch_app.open_document (doc);

            }
            
            if (split_view.get_children ().length () == 2)
                ; //main_actions.get_action ().
                

        }

        void case_up () {
            toolbar.search_manager.search_previous ();
        }

        void case_down () {
            toolbar.search_manager.search_next ();
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
            current_tab.document.backup ();
            var file = File.new_for_path (current_tab.document.filename);

            if (file.query_exists ())
                current_tab.document.save ();
        }
        
        void action_duplicate () {
            if (current_tab != null) {
                TextIter start, end;
                var buf = current_tab.text_view.buffer;
                buf.get_selection_bounds (out start, out end);
                string selected = buf.get_text (start, end, true);
                if (selected != "")
                    buf.insert (ref end, "\n" + selected, -1);

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
                var tab = w as Tab;
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

            split_view.remove_current_view ();
        }
        
        void action_show_status_bar (Gtk.Action action) {
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
        }

        static const Gtk.ActionEntry[] main_entries = {
           { "Fetch", Gtk.Stock.SAVE,
          /* label, accelerator */       N_("Fetch"), "<Control>f",
          /* tooltip */                  N_("Fetch"),
                                         null },
           { "ShowGoTo", Gtk.Stock.OK,
          /* label, accelerator */       N_("Go to line..."), "<Control>i",
          /* tooltip */                  N_("Go to line..."),
                                         null },
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
                                         null },
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

           { "SearchNext", Gtk.Stock.GO_FORWARD,
          /* label, accelerator */       N_("Next Search"), "<Control>g",
          /* tooltip */                  N_("Next Search"),
                                         case_down },
           { "SearchBack", Gtk.Stock.GO_BACK,
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
          /* label, accelerator */       N_("Save as"), "<Control><shift>s",
          /* tooltip */                  N_("Save the current file with a different name"),
                                         action_save_as },
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
