/*-
 * Copyright (c) 2017 elementary LLC. (https://elementary.io)
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Authored by: Julien Spautz <spautz.julien@gmail.com>, Andrei-Costin Zisu <matzipan@gmail.com>
 */

namespace Scratch.Plugins.FolderManager {
    /**
     * Normal item in the source list, represents a textfile.
     * TODO Remove, Rename
     */
    internal class FileItem : Item {

        Gtk.Menu menu;
        Gtk.MenuItem item_trash;

        public FileItem (File file) requires (file.is_valid_textfile) {
            Object (file: file);

            this.selectable = true;
            //this.editable = true;
            this.name = file.name;
            this.icon = file.icon;
        }

        /*public void rename (string new_name) {
            file.rename (new_name);
        }*/

        public override Gtk.Menu? get_context_menu () {
            item_trash = new Gtk.MenuItem.with_label (_("Move to Trash"));

            menu = new Gtk.Menu ();
            menu.append (item_trash);
            menu.show_all ();

            item_trash.activate.connect (() => {
                file.trash ();
            });

            return menu;
        }
    }
}