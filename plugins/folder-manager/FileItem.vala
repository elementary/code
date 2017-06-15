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
     * Normal item in the source list, represents a textfile.
     */
    internal class FileItem : Item {
        public FileItem (File file, FileView view) requires (file.is_valid_textfile) {
            Object (file: file, view: view);
        }

        public override Gtk.Menu? get_context_menu () {
            var menu = new Gtk.Menu ();
            var rename_item = new Gtk.MenuItem.with_label (_("Rename"));
            rename_item.activate.connect (() => view.start_editing_item (this));
            menu.append (rename_item);

            var delete_item = new Gtk.MenuItem.with_label (_("Move to Trash"));
            delete_item.activate.connect (() => do_remove ());
            menu.append (delete_item);

            menu.show_all ();
            return menu;
        }
    }
}