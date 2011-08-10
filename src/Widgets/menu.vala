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

        private MainWindow window;
        
        private ImageMenuItem print;
        private CheckMenuItem fullscreen;
        private ImageMenuItem preferences;
        
        public MenuProperties (MainWindow parent) {
            this.window = parent;
            create ();
        }
        
        public void create () {		
            
            print = new ImageMenuItem.from_stock (Stock.PRINT, null);

            fullscreen = new CheckMenuItem.with_label (_("Fullscreen"));
            fullscreen.active = (Scratch.saved_state.window_state == ScratchWindowState.FULLSCREEN);
            
            preferences = new ImageMenuItem.from_stock (Stock.PREFERENCES, null);

            append (print);
            append (fullscreen);
            append (preferences);
            
            print.activate.connect (() => {new PrintSettings ();});
            fullscreen.toggled.connect (toggle_fullscreen);
            preferences.activate.connect (() => {new Dialogs.Preferences ("Preferences", this.window);});

        }

        private void toggle_fullscreen () {

            if (fullscreen.active)
                window.fullscreen ();
            else
                window.unfullscreen ();

        }
        
    }

} // Namespace
