/*-
 * Copyright (c) 2017 elementary LLC. (https://elementary.io),
 *               2013 Julien Spautz <spautz.julien@gmail.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License version 3
 * as published by the Free Software Foundation, either version 3 of the
 * License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranties of
 * MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
 * PURPOSE. See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Authored by: Julien Spautz <spautz.julien@gmail.com>, Andrei-Costin Zisu <matzipan@gmail.com>
 */

namespace Scratch.Plugins.FolderManager {
    /**
     * Normal item in the source list, represents a textfile.
     */
    internal class FileItem : Item {

        public FileItem (File file, FileView view) requires (file.is_valid_textfile) {
            Object (file: file, view: view);
        }

        public override Gtk.Menu? get_context_menu () {
            var trash_item = new Gtk.MenuItem.with_label (_("Move to Trash"));
            trash_item.activate.connect (trash);

            var rename_item = new Gtk.MenuItem.with_label (_("Rename"));
            rename_item.activate.connect (() => view.start_editing_item (this));

            var menu = new Gtk.Menu ();
            menu.append (trash_item);
            menu.append (rename_item);

            menu.show_all ();

            return menu;
        }
    }
}
