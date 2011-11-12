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

namespace Scratch.Widgets {

    public class MenuProperties : Menu {

        public MainWindow window;
        
        new Gee.HashMap<string, string> map;
        
        public MenuItem languages;
        public CheckMenuItem fullscreen;
        public ImageMenuItem preferences;
        public CheckMenuItem sidebar_visible;
        public CheckMenuItem context_visible;
        public CheckMenuItem bottom_visible;
        public MenuItem additional_separator;
        
        public Menu menu_language;
        
        private Dialogs.Preferences dialog;
        Gtk.ActionGroup actions;
        
        public MenuProperties (MainWindow parent, Gtk.ActionGroup actions) {
            this.window = parent;
            this.actions = actions;
            create ();
            create_map ();
        }
        
        public void create () {		
            
            languages = new MenuItem.with_label (_("Syntax Highlighting"));
            add_submenu (languages);
            
            var view = (Gtk.MenuItem) actions.get_action ("New view").create_menu_item ();
            
            var remove_view = (Gtk.MenuItem) actions.get_action ("Remove view").create_menu_item ();

            fullscreen = new CheckMenuItem.with_label (_("Fullscreen"));
            fullscreen.active = (Scratch.saved_state.window_state == ScratchWindowState.FULLSCREEN);
            
            preferences = new ImageMenuItem.from_stock (Stock.PREFERENCES, null);

            sidebar_visible = new CheckMenuItem.with_label (_("Show Sidebar"));
            settings.schema.bind("sidebar-visible", sidebar_visible, "active", SettingsBindFlags.DEFAULT);
            context_visible = new CheckMenuItem.with_label (_("Show Context View"));
            settings.schema.bind("context-visible", context_visible, "active", SettingsBindFlags.DEFAULT);
            bottom_visible = new CheckMenuItem.with_label (_("Show Bottom Panel"));
            settings.schema.bind("bottom-panel-visible", bottom_visible, "active", SettingsBindFlags.DEFAULT);
            sidebar_visible.visible = false;
            sidebar_visible.no_show_all = true;
            context_visible.visible = false;
            context_visible.no_show_all = true;
            bottom_visible.visible = false;
            bottom_visible.no_show_all = true;
            
            append (languages);
            append (new SeparatorMenuItem ());
            append (view);
            append (remove_view);
            append (fullscreen);
            append (new SeparatorMenuItem ());
            append (sidebar_visible);
            append (context_visible);
            append (bottom_visible);
            additional_separator = new SeparatorMenuItem ();
            append (additional_separator);
            additional_separator.no_show_all = true;
            additional_separator.visible = false;
            append (preferences);
            
            dialog = new Dialogs.Preferences ("Preferences", this.window);
            fullscreen.toggled.connect (toggle_fullscreen);
            preferences.activate.connect (() => { new Dialogs.Preferences ("Preferences", this.window).show_all(); });

        }
        
        void create_map () {
            map = new Gee.HashMap<string, string> ();
            
            map.set ("Bash", "sh");
            map.set ("C", "c");
            map.set ("C#", "c-sharp");
            map.set ("C++", "cpp");
            map.set ("CMake", "cmake");
            map.set ("CSS", "css");
            map.set (".desktop", "desktop");
            map.set ("Diff", "diff");
            map.set ("Fortran", "fortran");
            map.set ("Gettext", "gettext-translation");
            map.set ("HTML", "html");
            map.set ("ini", "ini");
            map.set ("Java", "java");
            map.set ("JavaScript", "js");
            map.set ("LaTex", "latext");
            map.set ("Lua", "lua");
            map.set ("MakeFile", "makefile");
            map.set ("Objective-C", "objc");
            map.set ("Pascal", "pascal");
            map.set ("Perl", "perl");
            map.set ("PHP", "php");
            map.set ("Python", "python");
            map.set ("Ruby", "ruby");
            map.set ("Vala", "vala");
            map.set ("XML", "xml");

        }
        
        void add_submenu (MenuItem item) {
		    
		    menu_language = new Menu ();
		    
		    var slist = new SList<RadioMenuItem> ();
		    
		    var l1 = new RadioMenuItem.with_label (slist, _("Normal Text"));
		    l1.activate.connect (() => {untogle_all (l1);}); 
		    menu_language.append (l1);
		    
		    var l2 = new RadioMenuItem.with_label (slist,"Bash");
		    l2.activate.connect (() => {untogle_all (l2);}); 
		    menu_language.append (l2);
		    
		    var l3 = new RadioMenuItem.with_label (slist,"C");
		    l3.activate.connect (() => {untogle_all (l3);}); 
		    menu_language.append (l3);
		    
		    var l4 = new RadioMenuItem.with_label (slist, "C#");
		    l4.activate.connect (() => {untogle_all (l4);}); 
		    menu_language.append (l4);
		    
		    var l5 = new RadioMenuItem.with_label (slist,"C++");
		    //l5.activate.connect (() => {untogle_all (l5);}); 
		    menu_language.append (l5);
		    
		    var l6 = new RadioMenuItem.with_label (slist, "CMake");
		    l6.activate.connect (() => {untogle_all (l6);}); 
		    menu_language.append (l6);
		    
		    var l7 = new RadioMenuItem.with_label (slist, "CSS");
		    l7.activate.connect (() => {untogle_all (l7);}); 
		    menu_language.append (l7);
		    
		    var l8 = new RadioMenuItem.with_label (slist, ".desktop");
		    l8.activate.connect (() => {untogle_all (l8);}); 
		    menu_language.append (l8);
		    
		    var l9 = new RadioMenuItem.with_label (slist, "Diff");
		    l9.activate.connect (() => {untogle_all (l9);}); 
		    menu_language.append (l9);
		    
		    var l0 = new RadioMenuItem.with_label (slist, "Fortran");
		    l0.activate.connect (() => {untogle_all (l0);}); 
		    menu_language.append (l0);
		    
		    var l10 = new RadioMenuItem.with_label (slist, "Gettext");
		    l10.activate.connect (() => {untogle_all (l10);}); 
		    menu_language.append (l10);
		    
		    var l11 = new RadioMenuItem.with_label (slist, "HTML");
		    l11.activate.connect (() => {untogle_all (l11);}); 
		    menu_language.append (l11);
		    
		    var l12 = new RadioMenuItem.with_label (slist, "ini");
		    l12.activate.connect (() => {untogle_all (l12);}); 
		    menu_language.append (l12);
		    
		    var l13 = new RadioMenuItem.with_label (slist, "Java");
		    l13.activate.connect (() => {untogle_all (l13);}); 
		    menu_language.append (l13);
		    
		    var l14 = new RadioMenuItem.with_label (slist, "JavaScript");
		    l14.activate.connect (() => {untogle_all (l14);}); 
		    menu_language.append (l14);
		    
		    var l15 = new RadioMenuItem.with_label (slist, "LaTex");
		    l15.activate.connect (() => {untogle_all (l15);}); 
		    menu_language.append (l15);
		    
		    var l16 = new RadioMenuItem.with_label (slist, "Lua");
		    l16.activate.connect (() => {untogle_all (l16);}); 
		    menu_language.append (l16);
		    
		    var l17 = new RadioMenuItem.with_label (slist, "Makefile");
		    l17.activate.connect (() => {untogle_all (l17);}); 
		    menu_language.append (l17);
		    
		    var l18 = new RadioMenuItem.with_label (slist, "Objective-C");
		    l18.activate.connect (() => {untogle_all (l18);}); 
		    menu_language.append (l18);
		    
		    var l19 = new RadioMenuItem.with_label (slist, "Pascal");
		    l19.activate.connect (() => {untogle_all (l19);}); 
		    menu_language.append (l19);
		    
		    var l20 = new RadioMenuItem.with_label (slist, "Perl");
		    l20.activate.connect (() => {untogle_all (l20);}); 
		    menu_language.append (l20);
		    
		    var l21 = new RadioMenuItem.with_label (slist, "PHP");
		    l21.toggled.connect (() => {untogle_all (l21);}); 
		    menu_language.append (l21);
		    
		    var l22 = new RadioMenuItem.with_label (slist, "Python");
		    l22.toggled.connect (() => {untogle_all (l22);}); 
		    menu_language.append (l22);
		    
		    var l23 = new RadioMenuItem.with_label (slist, "Ruby");
		    l23.activate.connect (() => {untogle_all (l23);});//untogle_all (l23);}); 
		    menu_language.append (l23);
		    
		    var l24 = new RadioMenuItem.with_label (slist, "Vala");
		    l24.activate.connect (() => {untogle_all (l24);});//untogle_all (l24);}); 
		    menu_language.append (l24);
		    
		    var l25 = new RadioMenuItem.with_label (slist, "XML");
		    l25.activate.connect (() => {untogle_all (l25);}); 
		    menu_language.append (l25);
		    
		    item.set_submenu (menu_language);
		      
		}
        
        void untogle_all (CheckMenuItem ck) {
            
            //if (to_unactivate != ck)
              //  to_unactivate.set_active (false);
            //CheckMenuItem nck = null;
            
            /*foreach (var widget in menu_language.get_children ()) {
                if (((CheckMenuItem)widget) != ck) {
                    if (((CheckMenuItem)widget).get_active ())    
                        ((CheckMenuItem)widget).set_active (false);
                    
                }
             //   else 
             //       if (nck == null)
             //           nck = ck;
             //       else
             //           nck.set_active (true);
                
            }*/
            
            //menu_language.deselect (); menu_language.select_item (ck); menu_language.selection_done ();
            
            string key = ck.get_label ();
            
            var manager = new Gtk.SourceLanguageManager ();
            var language = manager.get_language (map.get (key));
            window.current_tab.text_view.buffer.language = language;
            
        }
        
        private void toggle_fullscreen () {

            if (fullscreen.active)
                window.fullscreen ();
            else
                window.unfullscreen ();

        }
        
    }

} // Namespace
