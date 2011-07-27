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

        private ImageMenuItem preferences;
        private CheckMenuItem fullscreen;
        
        public MenuProperties (MainWindow parent) {
            this.window = parent;
            create ();
        }
        
        public void create () {		

            preferences = new ImageMenuItem.from_stock (Stock.PREFERENCES, null);
            fullscreen = new CheckMenuItem.with_label ("Fullscreen");
            fullscreen.active = (Scratch.saved_state.window_state == ScratchWindowState.FULLSCREEN);

            append (fullscreen);
            append (preferences);
  
            preferences.activate.connect (() => {new Dialogs.Preferences ("Preferences", this.window);});
            fullscreen.toggled.connect (toggle_fullscreen);

        }

        private void toggle_fullscreen () {

            if (fullscreen.active)
                window.fullscreen ();
            else
                window.unfullscreen ();

        }
        
    }

} // Namespace
