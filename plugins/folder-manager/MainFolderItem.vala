// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/***
  BEGIN LICENSE

  Copyright (C) 2013 Julien Spautz <spautz.julien@gmail.com>
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

namespace Scratch.Plugins.FolderManager {
    /**
     * Special root folder.
     * TODO rename, create new file
     */
    internal class MainFolderItem : FolderItem {
        public signal void closed ();

        Gtk.Menu menu;
        Gtk.MenuItem item_close;
        //Gtk.MenuItem item_create;

        public MainFolderItem (File file) requires (file.is_valid_directory) {
            base (file);
        }

        public override Gtk.Menu? get_context_menu () {
            menu = new Gtk.Menu ();
            item_close = new Gtk.MenuItem.with_label (_("Close Folder"));
            //item_create = new Gtk.MenuItem.with_label (_("Create new File"));
            menu.append (item_close);
            //menu.append (item_create);
            item_close.activate.connect (() => { closed (); });
            /*item_create.activate.connect (() => {
                var new_file = GLib.File.new_for_path (file.path + "/new File");

                try {
                    FileOutputStream os = new_file.create (FileCreateFlags.NONE);
                } catch (Error e) {
                    warning ("Error: %s\n", e.message);
                }
            });*/
            menu.show_all ();
            return menu;
        }
    }
}