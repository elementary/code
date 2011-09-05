// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/***
  BEGIN LICENSE
    
  Copyright (C) 2011 Mario Guerriero <mefrio.g@gmail.com>    
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

namespace Scratch {

   
    public class MainWindow : Gtk.Window {
    
        const string ui_string = """
            <ui>
            <popup name="MenuItemTool">
                <menuitem name="Fetch" action="Fetch"/>
                <menuitem name="New tab" action="New tab"/>
                <menuitem name="SaveFile" action="SaveFile"/>
            </popup>
            </ui>
        """;
        Gtk.ActionGroup main_actions;
        Gtk.UIManager ui;
    
        public const string TITLE = "Scratch";
        private string search_string = "";
        
        //widgets
        public ScratchNotebook notebook;
        public SplitView split_view;
        public Widgets.Toolbar toolbar;
        
        Gtk.Notebook notebook_context;
        Gtk.Notebook notebook_sidebar;

        //dialogs
        public FileChooserDialog filech;

        public Tab current_tab;
        public ScratchNotebook current_notebook;
        
        //bools for key press event
        bool ctrlL = false;
        bool ctrlR = false;
        
        //objects for the set_theme ()
        FontDescription font;
        Gdk.Color bgcolor;
        Gdk.Color fgcolor;

        public MainWindow () {
                
            this.title = TITLE;
            restore_saved_state ();

            main_actions = new Gtk.ActionGroup("MainActionGroup"); /* Actions and UIManager */
            main_actions.set_translation_domain("scratch");
            main_actions.add_actions(main_entries, this);
            ui = new Gtk.UIManager();
            try {
                ui.add_ui_from_string(ui_string, -1);
            }
            catch(Error e) {
                error("Couldn't load the UI");
            }
            Gtk.AccelGroup accel_group = ui.get_accel_group();
            add_accel_group(accel_group);
     
            ui.insert_action_group(main_actions, 0);
            ui.ensure_update();
            
            create_window ();
            connect_signals ();
            
            set_theme ();
            
            List<string> s = plugins.get_available_plugins ();
            stdout.printf ("%s\n\n", s.nth_data(1));
            
        }
        
        void action_fetch()
        {
            toolbar.entry.grab_focus();
        }

        void on_notebook_context_new_page(Gtk.Notebook notebook, Widget page, uint num)
        {
            if(settings.schema.get_boolean((notebook == notebook_context ? "context" : "sidebar") + "-visible")) notebook.show_all();
            if(notebook == notebook_context)
            {
                toolbar.menu.context_visible.sensitive = true;
            }
            else
                toolbar.menu.sidebar_visible.sensitive = true;
            page.show_all();
            notebook.show_tabs = num >= 1;
        }

        void key_changed(string key)
        {
            if(key == "context-visible")
            {
                if(settings.schema.get_boolean("context-visible") && notebook_context.get_n_pages() > 0)
                {
                    notebook_context.show_all();
                }
                else
                {
                    notebook_context.hide();
                }
            }
            if(key == "sidebar-visible")
            {
                if(settings.schema.get_boolean("sidebar-visible") && notebook_sidebar.get_n_pages() > 0)
                {
                    notebook_sidebar.show_all();
                }
                else
                {
                    notebook_sidebar.hide();
                }
            }
        }
        
        public void create_window () {
            
            this.toolbar = new Widgets.Toolbar (this, ui, main_actions);
        
            notebook_context = new Gtk.Notebook();
            notebook_context.page_added.connect(on_notebook_context_new_page);
            var hpaned_addons = new Granite.Widgets.HCollapsablePaned();
        
            notebook_sidebar = new Gtk.Notebook();
            notebook_sidebar.page_added.connect(on_notebook_context_new_page);
            var hpaned_sidebar = new Granite.Widgets.HCollapsablePaned();
            hpaned_addons.pack1(hpaned_sidebar, true, true);
            
            this.split_view = new SplitView (this);
            hpaned_sidebar.pack1(notebook_sidebar, false, false);
            notebook_sidebar.visible = false;
            hpaned_sidebar.pack2(split_view, true, true);
            hpaned_addons.pack2(notebook_context, false, false);
            notebook_context.visible = true;
            settings.schema.changed.connect(key_changed);

            plugins.hook_notebook_sidebar(notebook_sidebar);
            plugins.hook_notebook_context(notebook_context);

            this.notebook =  new ScratchNotebook (this);
            this.notebook.add_tab();
            
            split_view.add_view (notebook);
                                    
            //adding all to the vbox
            var vbox = new VBox (false, 0);
            vbox.pack_start (toolbar, false, false, 0);
            vbox.pack_start (hpaned_addons, true, true, 0); 
            vbox.show_all  ();
            
            this.add (vbox);
            
            notebook.window.current_notebook = notebook.window.split_view.get_current_notebook ();
            notebook.window.current_tab = (Tab) notebook.window.current_notebook.get_nth_page (notebook.window.current_notebook.get_current_page());
            
            set_undo_redo ();    

            //show_all();
            key_changed("sidebar-visible");
            key_changed("context-visible");
        
			toolbar.toolreplace.hide ();
        
        }
        
        public void set_theme () {
            
            string theme = "elementary";
            if (theme == "normal")
            {
                Gtk.Settings.get_default().gtk_application_prefer_dark_theme = false;
                
                // Get the system's style
                realize();
                font = FontDescription.from_string(system_font());
                bgcolor = get_style().bg[StateType.NORMAL];
                fgcolor = get_style().fg[StateType.NORMAL];
            }
            else
            {
                Gtk.Settings.get_default().gtk_application_prefer_dark_theme = true;
                
                // Get the system's style
                realize();
                font = FontDescription.from_string(system_font());
                bgcolor = get_style().bg[StateType.NORMAL];
                fgcolor = get_style().fg[StateType.NORMAL];
            }
        }
        
        static string system_font () {
            
            string font_name = null;
            /* Wait for GNOME 3 FIXME
             * var settings = new GLib.Settings("org.gnome.desktop.interface");
             * font_name = settings.get_string("monospace-font-name");
             */
            font_name = "Ubuntu Regular 10";
            return font_name;
        }
        
        public void connect_signals () {

            //signals for the window
            this.destroy.connect (Gtk.main_quit);
            
            this.key_release_event.connect (on_key_released);
            this.key_press_event.connect (on_key_press);

            //signals for the toolbar
            toolbar.new_button.clicked.connect (on_new_clicked);
            toolbar.open_button.clicked.connect (on_open_clicked);
            toolbar.undo_button.clicked.connect (on_undo_clicked);
            toolbar.repeat_button.clicked.connect (on_repeat_clicked);
            toolbar.combobox.changed.connect (on_combobox_changed);
            toolbar.entry.focus_out_event.connect ( () => { start = end = null; return false; });
            toolbar.entry.changed.connect (on_changed_text);
            toolbar.entry.key_press_event.connect (on_search_key_press);
            toolbar.replace.activate.connect (on_replace_activate);

        }
        
        
        bool on_search_key_press (Gdk.EventKey event) {
            string key = Gdk.keyval_name(event.keyval);
            switch(key)
            {
            case "Up":
                TextIter iter;
                if (end == null || start == null) {
                    TextIter start_buffer;
                    current_tab.text_view.buffer.get_iter_at_offset(out start_buffer, current_tab.text_view.buffer.cursor_position);
                    end = start_buffer;
                    start = start_buffer;
                }
                TextIter local_end = end;
                TextIter local_start = start;
                bool found = start.backward_search (search_string, TextSearchFlags.CASE_INSENSITIVE, out local_start, out local_end, null);
                if (found) {
                    end = local_end;
                    start = local_start;
                    current_tab.text_view.buffer.select_range (start, end);
                    current_tab.text_view.scroll_to_iter (start, 0, false, 0, 0);
                }
                return true;
			case "Return":
            case "Down":
				TextIter iter;

                if (end == null || start == null) {
                    TextIter start_buffer;
                    current_tab.text_view.buffer.get_iter_at_offset(out start_buffer, current_tab.text_view.buffer.cursor_position);
                    end = start_buffer;
                    start = start_buffer;
                }
                TextIter local_end = end;
                TextIter local_start = start;
                bool found = end.forward_search (search_string, TextSearchFlags.CASE_INSENSITIVE, out local_start, out local_end, null);
                if (found) {
                    end = local_end;
                    start = local_start;
                    current_tab.text_view.buffer.select_range (start, end);
                    current_tab.text_view.scroll_to_iter (start, 0, false, 0, 0);
                }
                return true;
            }
            return false;
        }
		
		public void on_replace_activate () {
			warning ("The feaure is not implemented yet");
		}		
         
        //signals functions
        public void on_destroy () {
            if (!current_notebook.welcome_screen.active) {
                this.show_all ();
                string isnew = current_tab.label.label.get_text () [0:1];
                if (isnew == "*") {
                    var save_on_close_dialog = new SaveOnCloseDialog (current_tab.filename, this);
                        save_on_close_dialog.run ();
                    } else {
                        this.destroy();
                    }
            }
        }
        
        private void reset_ctrl_flags() {
            ctrlR = false;
            ctrlL = false;
        }
        
        // untoggles Control Trigger
        private bool on_key_released (EventKey event) {

            string key = Gdk.keyval_name(event.keyval);
            
            if (key == "Control_L" || key == "Control_R")
                reset_ctrl_flags();
                
            return true;
        }
        
        void action_new_tab () {
            if (!current_notebook.welcome_screen.active) {
                int tab_index = current_notebook.add_tab ();
                    current_notebook.set_current_page (tab_index);            
            }
        }
        
        public bool on_key_press (EventKey event) {
            
            string key = Gdk.keyval_name(event.keyval);
                
            /// Q: Do we really need ctrlL and ctrlR? One Var may be enough
            if (key == "Control_L")
                ctrlL = true;
            if (key == "Control_R")
                ctrlR = true;

            if ((ctrlL || ctrlR))
            {
                switch(key.down()/*This avoids checking for "t" and "T*/)
                {
                    // Close current Tab
                    case "w":
                        if (!current_notebook.welcome_screen.active) {                    
                            current_tab.on_close_clicked ();
                        }
                    break;
                    
                    // Close Scratch by Ctrl+Q or Ctrl+E
                    case "q":
                        warning("Killler");
                        this.on_destroy();
                    break;
                    
                    case "e":
                        warning("Killler");
                        this.on_destroy();
                    break; 

                    // Undo by Ctrl+Z
                    case "z":
                        this.on_undo_clicked();
                    break;    
                        
                    // Redo by Ctrl+Y
                    case "y":
                        this.on_repeat_clicked();
                    break;
                }
            }
            else if (key == "F3")
                create_instance ();

            return false;
        }
        
        public void on_new_clicked () {
            int new_tab_index = current_notebook.add_tab ();
            current_notebook.set_current_page (new_tab_index);
            current_notebook.show_tabs_view ();
            
        }
        
        public void on_open_clicked () {
            
            if (current_notebook.welcome_screen.active)
                on_new_clicked ();
                                
            // show dialog
            this.filech = new FileChooserDialog ("Open a file", this, FileChooserAction.OPEN, null);
            filech.add_button (Stock.CANCEL, ResponseType.CANCEL);
            filech.add_button (Stock.OPEN, ResponseType.ACCEPT);
            filech.set_default_response (ResponseType.ACCEPT);
            
            if (filech.run () == ResponseType.ACCEPT)
                    open (filech.get_filename ());

            filech.close ();
            set_undo_redo ();

        }
        
        public void open (string filename) {            
            if (filename != null) {
                // check if file is already opened
                int target_page = -1;

                try {
                    set_combobox_language (filename);
                } catch (Error e) {
                    warning ("Cannont set the combobox id");
                }
                                
                if (!current_notebook.welcome_screen.active) {
    
                    int tot_pages = current_notebook.get_n_pages ();
                    for (int i = 0; i < tot_pages; i++)
                        if (current_tab.filename == filename)
                            target_page = i;
                }
                
                if (target_page >= 0) {
                    message ("file already opened: %s\n", filename);
                    current_notebook.set_current_page (target_page);
                } else {
                    message ("Opening: %s\n", filename);
                    current_notebook.show_tabs_view ();    
                    var name = filename.split("/");
                    load_file (filename,name[name.length-1]);
                    }
            }
        }
        
        public void action_save () {
              current_tab.save();
        }
        
        public void action_replace () {
			toolbar.add_replace_entry ();
		}
        
        public void on_undo_clicked () {
            
            current_tab.text_view.undo ();
            set_undo_redo ();

        }
    
        public void on_repeat_clicked () {
            
            current_tab.text_view.redo ();
            set_undo_redo ();
        
        }
        
        public void on_combobox_changed () {
                    
            try {
                current_tab.text_view.buffer.set_language ( current_tab.text_view.manager.get_language (toolbar.combobox.get_active_id () ) );//current_tab.text_view.manager.get_language("c-sharp") );
            } catch (Error e) {
                return;
            }
        }
        
        public Gtk.TextView get_active_view() {
            return current_tab.text_view;
        }
    

        public Gtk.TextBuffer get_active_buffer() {
            return current_tab.text_view.buffer;
        }

        TextIter? end;
        TextIter? start;
    
        public void on_changed_text () {
            search_string = toolbar.entry.get_text();
            var buffer = get_active_buffer ();
            TextIter iter;
            
            /*if(start == null)*/ {
                buffer.get_iter_at_offset(out start, buffer.cursor_position);
                end = start;
            }
            iter = start;
            
            var found = iter.forward_search (search_string, TextSearchFlags.CASE_INSENSITIVE, out start, out end, null);
            if (found) {
                current_tab.text_view.buffer.select_range (start, end);
                current_tab.text_view.scroll_to_iter (start, 0, false, 0, 0);
            }
            else {
                buffer.get_start_iter (out iter);
                found = iter.forward_search (search_string, TextSearchFlags.CASE_INSENSITIVE, out start, out end, null);
                if (found) {
                    current_tab.text_view.buffer.select_range (start, end);
                    current_tab.text_view.scroll_to_iter (start, 0, false, 0, 0);
                }
                else {
                    start = end = null;
                }
            }
		}
				
        public bool on_scroll_event (EventScroll event) {
            
            if (event.direction == ScrollDirection.UP || event.direction == ScrollDirection.LEFT)  {
                
                if (current_notebook.get_current_page() != 0) {
                    
                    current_notebook.set_current_page ( current_notebook.get_current_page()-1 );    
                
                }
                
            }
            
            if (event.direction == ScrollDirection.DOWN || event.direction == ScrollDirection.RIGHT)  {
                
                if (current_notebook.get_current_page() != current_notebook.get_n_pages () ) {
                    
                    current_notebook.set_current_page ( current_notebook.get_current_page()+1 );    
                
                }
                
            }
            
            return true;
        }
        
        //generic functions
        public void load_file (string filename, string? title=null) {
            
            if (filename != "") {                
                try {
                    string text;
                    FileUtils.get_contents (filename, out text);
                    
                    //get the filename from strig filename =)
                    var name = Filename.display_basename (filename);
                    
                    Tab target_tab;

                    if ((current_tab != null) && (current_tab.filename == null) ) {
                    
                        //open in this tab
                        target_tab = current_tab;  
                    } else {

                        //create new tab
                        int tab_index = current_notebook.add_tab (name);
                        current_notebook.set_current_page (tab_index);                        
                        target_tab = (Tab) current_notebook.get_nth_page (tab_index);
                        
                    }
                        
                    //set new values
                       target_tab.text_view.set_file (filename, text);
                    target_tab.filename = filename;
                    target_tab.saved = true;
                    //set values for label
                    var tab = (Tab) current_notebook.get_nth_page (current_notebook.get_current_page());
                    var label = tab.label.label;
                    
                    if (title != null)
                        label.set_text (title);
                    else 
                        label.set_text (filename);
                    set_window_title (filename);
                                            
                } catch (Error e) {
                    warning("Error: %s\n", e.message);
                }
            }
            var tab = (Tab) current_notebook.get_nth_page (current_notebook.get_current_page());
            var label = tab.label.label;

            if (title != null)
                label.set_text (title);
            else if (label.get_text().substring (0, 1) == "*"){
                label.set_text (filename);
            }
                
        }

        public void set_window_title (string filename) {

            this.title = this.TITLE + " - " + Path.get_basename (filename);
            var home_dir = Environment.get_home_dir ();
            // Sorry for this mess...
            var path = Path.get_dirname (filename).replace (home_dir, "~");
            this.title += " (" + path + ")";
        
        }
#if VALA_0_14
        protected override bool delete_event (Gdk.EventAny event) {
#else
        protected override bool delete_event (Gdk.Event event) {
#endif

            update_saved_state ();
            on_destroy ();
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
            
            var buf = current_tab.text_view.buffer;

            toolbar.set_button_sensitive(Widgets.Toolbar.ToolButtons.UNDO_BUTTON, buf.can_undo);
            toolbar.set_button_sensitive(Widgets.Toolbar.ToolButtons.REPEAT_BUTTON, buf.can_redo);
            
            if (current_notebook.welcome_screen.active) {
                toolbar.set_button_sensitive(Widgets.Toolbar.ToolButtons.UNDO_BUTTON, false);
                toolbar.set_button_sensitive(Widgets.Toolbar.ToolButtons.REPEAT_BUTTON, false);
            }
        
        }
        
        public void set_combobox_language (string filename) {
        
            GtkSource.Language lang;
            lang = current_tab.text_view.manager.guess_language (filename, null);
                        
            string id = lang.get_id();
            if (id != null) {
                toolbar.combobox.set_active_id (id); 
            }
            else {
                toolbar.combobox.set_active_id ("normal");
            }
            
        }
        
        public void create_instance () {
        
            var instance = new ScratchNotebook (this);
            instance.add_tab ();
            split_view.add_view(instance);
            split_view.show_all ();
                            
        }

        static const Gtk.ActionEntry[] main_entries = {
           { "Fetch", Gtk.Stock.SAVE,
          /* label, accelerator */       N_("Fetch"), "<Control>f",
          /* tooltip */                  N_("Fetch"),
                                         action_fetch },
           { "New tab", Gtk.Stock.NEW,
          /* label, accelerator */       N_("New tab"), "<Control>t",
          /* tooltip */                  N_("Open a new tab"),
                                         action_new_tab },
           { "SaveFile", Gtk.Stock.SAVE,
          /* label, accelerator */       N_("Save"), "<Control>s",
          /* tooltip */                  N_("Save current file"),
                                         action_save },
           { "Replace", Gtk.Stock.CUT,
          /* label, accelerator */       N_("Replace"), "<Control>r",
          /* tooltip */                  N_("Open a replace entry"),
                                         action_replace }
        };
    }
} // Namespace    
