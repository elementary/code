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
                <menuitem name="Open" action="Open"/>
                <menuitem name="SaveFile" action="SaveFile"/>
                <menuitem name="Undo" action="Undo"/>
                <menuitem name="Redo" action="Redo"/>
                <menuitem name="SearchNext" action="SearchNext"/>
                <menuitem name="SearchBack" action="SearchBack"/>
            </popup>
            </ui>
        """;
        public Gtk.ActionGroup main_actions;
        Gtk.UIManager ui;
    
        public const string TITLE = "Scratch";
        string search_string = "";

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
		
		public ScratchInfoBar infobar;
		
        //dialogs
        public FileChooserDialog filech;

        public Tab current_tab { get { return (Tab) current_notebook.get_nth_page (current_notebook.get_current_page()); }}
        public ScratchNotebook current_notebook { get { return split_view.get_current_notebook (); } set {}}
        
        //objects for the set_theme ()
        FontDescription font;
        Gdk.Color bgcolor;
        Gdk.Color fgcolor;
        Scratch.ScratchApp scratch_app;
        
        ScratchWelcome welcome_screen;
        Granite.Widgets.HCollapsablePaned hpaned_sidebar;
        
				
        public MainWindow (Scratch.ScratchApp scratch_app) {
        	this.scratch_app = scratch_app;
            set_application(scratch_app);
                
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
                        
        }
        
        void action_fetch () {
            toolbar.entry.grab_focus();
        }

		/**
		 * This function checks the settings and show the sidebar (or the sidepanel)
		 * if needed when a page is added.
		 **/
        void on_notebook_context_new_page (Gtk.Notebook notebook, Widget page, uint num) {
        	string part = "bottom-panel-visible";
            if(notebook == notebook_context)
            {
            	part = "context-visible";
                toolbar.menu.context_visible.visible = true;
            }
            else if(notebook == notebook_sidebar)
            {
            	part = "sidebar-visible";
                toolbar.menu.sidebar_visible.visible = true;
            }
            else if(notebook == notebook_bottom)
            {
            	part = "bottom-panel-visible";
                toolbar.menu.bottom_visible.visible = true;
            }
            page.show_all();
            notebook.show_tabs = num >= 1;
            notebook_settings_changed (part);
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
            if(notebook != null)
            {
		        notebook.hide ();
		        if(!key_value)
		        	return;
		        foreach(var w in notebook.get_children ())
		        {
		        	if(w.visible)
		        	{
		        		notebook.show_all ();
		        		return;
		        	}
		        }
            }
        }
        
        public void create_window () {
            
            this.toolbar = new Widgets.Toolbar (this, ui, main_actions);
        
            notebook_context = new Gtk.Notebook();
            notebook_context.page_added.connect(on_notebook_context_new_page);
            var hpaned_addons = new Granite.Widgets.HCollapsablePaned();
            var vpaned_bottom_panel = new Granite.Widgets.VCollapsablePaned();
        
            notebook_sidebar = new Gtk.Notebook();
            notebook_sidebar.page_added.connect(on_notebook_context_new_page);
            hpaned_sidebar = new Granite.Widgets.HCollapsablePaned();
            hpaned_addons.pack1(hpaned_sidebar, true, true);
            
            split_view = new SplitView (this);
            welcome_screen = new ScratchWelcome(this);
            split_view.notify["is-empty"].connect (on_split_view_empty_changed);
            hpaned_sidebar.pack1(notebook_sidebar, false, false);
            notebook_sidebar.visible = false;
            hpaned_sidebar.pack2(split_view, true, true);
            hpaned_addons.pack2(notebook_context, false, false);
            notebook_context.visible = true;
            settings.schema.changed.connect(notebook_settings_changed);

            plugins.hook_notebook_sidebar(notebook_sidebar);
            plugins.hook_notebook_context(notebook_context);

            var notebook =  new ScratchNotebook (this);
            split_view.add_view (notebook);

            notebook_bottom = new Gtk.Notebook();
            notebook_bottom.page_added.connect(on_notebook_context_new_page);
            
            /* Add the sourceview + the sidepanel to the container of the bottom panel */
            vpaned_bottom_panel.pack1 (hpaned_addons, true, true);
            vpaned_bottom_panel.pack2 (notebook_bottom, false, false);
            plugins.hook_notebook_bottom(notebook_bottom);


            //adding all to the vbox
            var vbox = new VBox (false, 0);
            vbox.pack_start (toolbar, false, false, 0);
            vbox.pack_start (vpaned_bottom_panel, true, true, 0); 
            vbox.show_all  ();

            //add infobar
            infobar = new ScratchInfoBar (vbox);

            this.add (infobar);
            
            set_undo_redo (); 
            
            on_split_view_empty_changed ();   

            show_all();
            notebook_settings_changed("sidebar-visible");
            notebook_settings_changed("context-visible");
            notebook_settings_changed("bottom-panel-visible");
        	
			toolbar.toolreplace.hide ();
			toolbar.toolgoto.hide ();
			
			infobar.hide ();
        }
        
        public void set_actions (bool val) {
        	main_actions.get_action ("SaveFile").set_sensitive (val);
        	main_actions.get_action ("Undo").set_sensitive (val);
        	main_actions.get_action ("Redo").set_sensitive (val);
        	main_actions.get_action ("Fetch").set_sensitive (val);
        	toolbar.set_actions (val);
        }
        
        void on_split_view_empty_changed ()
        {
        	if(split_view.is_empty) {
				set_actions (false);
        		if(split_view.get_parent () != null) {
		    		hpaned_sidebar.remove (split_view);
		        	hpaned_sidebar.pack2 (welcome_screen, true, true);
            	}
            	toolbar.set_button_sensitive (toolbar.ToolButtons.SAVE_BUTTON, false);
            	toolbar.set_button_sensitive (toolbar.ToolButtons.UNDO_BUTTON, false);
            	toolbar.set_button_sensitive (toolbar.ToolButtons.REPEAT_BUTTON, false);
            	toolbar.set_button_sensitive (toolbar.ToolButtons.SHARE_BUTTON, false);
            	toolbar.set_entry_sensitive (toolbar.ToolEntry.SEARCH_ENTRY, false);
            	toolbar.set_entry_sensitive (toolbar.ToolEntry.REPLACE_ENTRY, false);
            	toolbar.set_entry_sensitive (toolbar.ToolEntry.GOTO_ENTRY, false);
            	toolbar.combobox.set_sensitive (false);
        	}
        	else {
				set_actions (true);
        		if(split_view.get_parent () == null) {
		    		hpaned_sidebar.remove (welcome_screen);
		        	hpaned_sidebar.pack2 (split_view, true, true);
            	}
        	}
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
            /* Try to use Gnome3 settings? */
			var settings = new GLib.Settings("org.gnome.desktop.interface");
			font_name = settings.get_string("monospace-font-name");
            //font_name = "Ubuntu Regular 10";
            return font_name;
        }
        
        public void connect_signals () {

            //signals for the window
            this.destroy.connect (on_destroy);

            //signals for the toolbar
            toolbar.combobox.changed.connect (on_combobox_changed);
            toolbar.entry.focus_out_event.connect ( () => { start = end = null; return false; });
            toolbar.entry.changed.connect (on_changed_text);
            toolbar.entry.key_press_event.connect (on_search_key_press);
            toolbar.replace.activate.connect (on_replace_activate);
            toolbar.go_to.activate.connect (on_goto_activate);

        }
        
        bool on_search_key_press (Gdk.EventKey event) {
            string key = Gdk.keyval_name(event.keyval);
            switch(key)
            {
            case "Up":
                case_up ();
                return true;
			case "Return":
            case "Down":
				case_down ();
				return true;
            }
            return false;
        }
		
		/* FIXME: case_up and case_down should be moved to SourceView */
		public void case_up () {

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
		}
		
		public void case_down () {

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
                current_tab.text_view.buffer.move_mark_by_name ("selection", local_end);
                current_tab.text_view.scroll_to_iter (start, 0, false, 0, 0);
            }
		}
		
		public void on_replace_activate () {
			TextIter s, e;
			if (current_tab.text_view.buffer.get_selection_bounds(out s, out e)) {
			var buf = current_tab.text_view.buffer;
			string replace_string = toolbar.replace.get_text ();
			buf.delete_selection (true, true);
			buf.insert_at_cursor (replace_string, replace_string.length);
			//simil to case_down() ...
            TextIter start_buffer;
            current_tab.text_view.buffer.get_iter_at_offset(out start_buffer, current_tab.text_view.buffer.cursor_position);
            end = start_buffer;
            start = start_buffer;

            TextIter local_end = end;
            TextIter local_start = start;
            bool found = end.forward_search (search_string, TextSearchFlags.CASE_INSENSITIVE, out local_start, out local_end, null);
            if (found) {
                end = local_end;
                start = local_start;
                current_tab.text_view.buffer.select_range (start, end);
                current_tab.text_view.scroll_to_iter (start, 0, false, 0, 0);
            }
			}
		}		
         
        public void on_goto_activate () {
			current_tab.text_view.go_to_line (int.parse (toolbar.go_to.get_text ()));
		}
         
        //signals functions
        public void on_destroy () {
			//List<ScratchNotebook> list = split_view.get_children ();
			
			foreach(var doc in scratch_app.documents) {						
				if(doc.modified) {
					var save_dialog = new SaveOnCloseDialog(doc.name, this);
					save_dialog.run();
				}
			}
			
        }
        
        void action_close_tab () {
            current_tab.on_close_clicked ();
        }
        
        void action_quit () {
			on_destroy ();
			Gtk.main_quit ();
        }

        void action_show_replace () {
			toolbar.show_replace_entry ();
        }
        
        void action_show_go_to () {
            toolbar.show_go_to_entry ();
        }
        
        public void on_new_clicked () {	
			action_new_tab ();
        }
        
        public void action_new_tab () {
			int new_tab_index = current_notebook.add_tab ();
			current_notebook.set_current_page (new_tab_index);
			current_notebook.show_tabs_view ();
		}
        
        public void action_open_clicked () {
            
            toolbar.set_sensitive (true);
                                
            // show dialog
            this.filech = new FileChooserDialog ("Open a file", this, FileChooserAction.OPEN, null);
            filech.set_select_multiple (true);
            filech.add_button (Stock.CANCEL, ResponseType.CANCEL);
            filech.add_button (Stock.OPEN, ResponseType.ACCEPT);
            filech.set_default_response (ResponseType.ACCEPT);

            if (filech.run () == ResponseType.ACCEPT)
					foreach (string file in filech.get_filenames ()) 
						scratch_app.open_file (file);
						
            filech.close ();
            set_undo_redo ();
		}
        
        public void open (string filename) {            
            scratch_app.open_file (filename);
        }
        
        public void action_save () {
              current_tab.save();
        }
        
        public void on_combobox_changed () {
            GtkSource.Language lang;
            lang = current_tab.text_view.manager.get_language ( toolbar.combobox.get_active_id () );
            current_tab.text_view.buffer.set_language (lang);
            //current_tab.text_view.buffer.set_language ( current_tab.text_view.manager.get_language (toolbar.combobox.get_active_id () ) );//current_tab.text_view.manager.get_language("c-sharp") );
        }
        
        public Gtk.TextView get_active_view() {
            return current_tab.text_view;
        }
    

        public Gtk.TextBuffer? get_active_buffer() {
            if(current_tab != null) return current_tab.text_view.buffer;
            return null;
        }

        TextIter? end;
        TextIter? start;
    
        public void on_changed_text () {
            if (current_tab.text_view.buffer.text != "") {
                search_string = toolbar.entry.get_text();
                var buffer = get_active_buffer ();
                TextIter iter;
                
                buffer.get_iter_at_offset(out start, buffer.cursor_position);
                end = start;

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
                        iter.forward_search ("", TextSearchFlags.CASE_INSENSITIVE, out start, out end, null);
                        current_tab.text_view.buffer.select_range (start, end);
                        start = end = null;
                        infobar.set_info ("\"" + search_string + "\" couldn't be found");
                    }
                
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

            this.title = /*this.TITLE + " - " + */Path.get_basename (filename);
            var home_dir = Environment.get_home_dir ();
            // Sorry for this mess...
            var path = Path.get_dirname (filename).replace (home_dir, "~");
            this.title += " (" + path + ") - Scratch";
        
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
            
			bool undo = false;
			bool redo = false;
            if(current_tab != null) {
		        GtkSource.Buffer buf;
		        
				buf = current_tab.text_view.buffer;
				undo = buf.can_undo;
				redo = buf.can_redo;
			
			}
			
            main_actions.get_action ("Undo").set_sensitive (undo);
            main_actions.get_action ("Redo").set_sensitive (redo);
			
			toolbar.set_button_sensitive (toolbar.ToolButtons.UNDO_BUTTON, undo);
			toolbar.set_button_sensitive (toolbar.ToolButtons.REPEAT_BUTTON, redo);
			
        }
        
        public void set_combobox_language (string filename) {
        
            GtkSource.Language lang;
            lang = GtkSource.LanguageManager.get_default ().guess_language (filename, null);
            if (lang != null) {
		        var id = lang.get_id();
		        if (id != null) {
		            toolbar.combobox.set_active_id (id); 
		        }
		        else {
		            toolbar.combobox.set_active_id ("normal");
		        }
		        
		        var nopath = filename.split ("/");
		        var sfile = nopath[nopath.length-1].split (".");
		        
		        if (sfile [sfile.length-1] == "ui")
					toolbar.combobox.set_active_id ("xml");
				
				else if (sfile [sfile.length-2] == "CMakeLists")
					toolbar.combobox.set_active_id ("cmake");
				
				else 
					toolbar.combobox.set_active_id ("normal");
			}
			else {
				warning ("Couldn't detect language highlight for %s", filename);
			}
        }
        
        public void create_instance () {
			
			if (split_view.get_children ().length() <= 2) {
			
				var instance = new ScratchNotebook (this);
				split_view.add_view(instance);
				instance.add_tab ();
                
            }
                            
        }
        
        void action_undo () {
			current_tab.text_view.undo ();
			set_undo_redo ();
        }
        void action_redo () {
			current_tab.text_view.redo ();
			set_undo_redo ();
        }
        
        void action_new_view () {
            create_instance ();
        }

        static const Gtk.ActionEntry[] main_entries = {
           { "Fetch", Gtk.Stock.SAVE,
          /* label, accelerator */       N_("Fetch"), "<Control>f",
          /* tooltip */                  N_("Fetch"),
                                         action_fetch },
           { "ShowGoTo", Gtk.Stock.OK,
          /* label, accelerator */       N_("Go to line..."), "<Control>i",
          /* tooltip */                  N_("Go to line..."),
                                         action_show_go_to },
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
                                         action_show_replace },
           { "New tab", Gtk.Stock.NEW,
          /* label, accelerator */       N_("New tab"), "<Control>t",
          /* tooltip */                  N_("Open a new tab"),
                                         action_new_tab },
           { "New view", Gtk.Stock.NEW,
          /* label, accelerator */       N_("Add a new view"), "F3",
          /* tooltip */                  N_("Add a new view"),
                                         action_new_view },
           { "Undo", Gtk.Stock.UNDO,
          /* label, accelerator */       N_("Undo"), "<Control>z",
          /* tooltip */                  N_("Undo"),
                                         action_undo },
           { "Redo", Gtk.Stock.REDO,
          /* label, accelerator */       N_("Redo"), "<Control><shift>z",
          /* tooltip */                  N_("Redo"),
                                         action_redo },
           { "SearchNext", Gtk.Stock.REDO,
          /* label, accelerator */       N_("Next Search"), "<Control>g",
          /* tooltip */                  N_("Next Search"),
                                         case_down },
           { "SearchBack", Gtk.Stock.REDO,
          /* label, accelerator */       N_("Previous Search"), "<Control><shift>g",
          /* tooltip */                  N_("Previous Search"),
                                         case_up },
           { "Open", Gtk.Stock.OPEN,
          /* label, accelerator */       N_("Open"), "<Control>o",
          /* tooltip */                  N_("Open"),
                                         action_open_clicked },
           { "SaveFile", Gtk.Stock.SAVE,
          /* label, accelerator */       N_("Save"), "<Control>s",
          /* tooltip */                  N_("Save current file"),
                                         action_save }
        };
    }
} // Namespace    

