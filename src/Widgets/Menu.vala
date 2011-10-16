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
        
        //private ImageMenuItem print;
        public MenuItem view;
        public MenuItem remove_view;
        public CheckMenuItem fullscreen;
        public ImageMenuItem preferences;
        public CheckMenuItem sidebar_visible;
        public CheckMenuItem context_visible;
        public CheckMenuItem bottom_visible;
        
        private Dialogs.Preferences dialog;
        
        public MenuProperties (MainWindow parent) {
            this.window = parent;
            create ();
        }
        
        public void create () {		
            
            view = new MenuItem.with_label (_("Add New View"));
            
            remove_view = new MenuItem.with_label (_("Remove Current View"));
            if (window.split_view != null) {
				if (window.split_view.total_view <= 1) remove_view.set_sensitive(false);
				else remove_view.set_sensitive(true);
			}
	        else remove_view.set_sensitive(false);

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

            append (view);
            append (remove_view);
            append (fullscreen);
            append (new SeparatorMenuItem ());
            append (sidebar_visible);
            append (context_visible);
            append (bottom_visible);
            append (new SeparatorMenuItem ());
            append (preferences);
            
            dialog = new Dialogs.Preferences ("Preferences", this.window);
            
            view.activate.connect (() => {window.create_instance ();});
            remove_view.activate.connect (() => {remove_view.set_sensitive (window.split_view.remove_current_view ()) ;} );
            fullscreen.toggled.connect (toggle_fullscreen);
            preferences.activate.connect (() => { new Dialogs.Preferences ("Preferences", this.window).show_all(); });

        }

        private void toggle_fullscreen () {

            if (fullscreen.active)
                window.fullscreen ();
            else
                window.unfullscreen ();

        }
        
    }

} // Namespace
