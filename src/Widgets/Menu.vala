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

        public CheckMenuItem fullscreen;
        public ImageMenuItem preferences;

        public Menu menu_language;

        private Dialogs.Preferences dialog;
        Gtk.ActionGroup actions;

        public MenuProperties (MainWindow parent, Gtk.ActionGroup actions) {
            this.window = parent;
            this.actions = actions;
            create ();
        }

        public void create () {

            var view = (Gtk.MenuItem) actions.get_action ("New view").create_menu_item ();

            var remove_view = (Gtk.MenuItem) actions.get_action ("Remove view").create_menu_item ();

            fullscreen = new CheckMenuItem.with_label (_("Fullscreen"));
            fullscreen.active = (Scratch.saved_state.window_state == ScratchWindowState.FULLSCREEN);

            preferences = new ImageMenuItem.from_stock (Stock.PREFERENCES, null);

            append (view);
            append (remove_view);
            append (fullscreen);
            append (new SeparatorMenuItem ());
            append (preferences);

            dialog = new Dialogs.Preferences ("Preferences", this.window);
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
