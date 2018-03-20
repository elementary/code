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

namespace Scratch.FolderManager {
    /**
     * Normal item in the source list, represents a textfile.
     */
    internal class FileItem : Item {
        public FileItem (File file, FileView view) requires (file.is_valid_textfile) {
            Object (file: file, view: view);
        }

        public override Gtk.Menu? get_context_menu () {
            var files_item_grid = new Gtk.Grid ();
            files_item_grid.add (new Gtk.Image.from_icon_name ("system-file-manager", Gtk.IconSize.MENU));
            files_item_grid.add (new Gtk.Label (_("File Manager")));

            var files_menuitem = new Gtk.MenuItem ();
            files_menuitem.add (files_item_grid);
            files_menuitem.activate.connect (() => show_file_uri (file));

            var other_menuitem = new Gtk.MenuItem.with_label (_("Other Application…"));
            other_menuitem.activate.connect (() => show_app_chooser (file));

            var open_in_menu = new Gtk.Menu ();
            open_in_menu.add (files_menuitem);
            open_in_menu.add (new Gtk.SeparatorMenuItem ());
            open_in_menu.add (other_menuitem);

            var open_in_item = new Gtk.MenuItem.with_label (_("Open In"));
            open_in_item.submenu = open_in_menu;

            var rename_item = new Gtk.MenuItem.with_label (_("Rename"));
            rename_item.activate.connect (() => view.start_editing_item (this));

            var delete_item = new Gtk.MenuItem.with_label (_("Move to Trash"));
            delete_item.activate.connect (trash);

            var menu = new Gtk.Menu ();
            menu.append (open_in_item);
            menu.append (new Gtk.SeparatorMenuItem ());
            menu.append (rename_item);
            menu.append (delete_item);
            menu.show_all ();

            return menu;
        }

        private void show_app_chooser (File file) {
            var dialog = new Gtk.AppChooserDialog (new Gtk.Window (), Gtk.DialogFlags.MODAL, file.file);
            if (dialog.run () == Gtk.ResponseType.OK) {
                var app_info = dialog.get_app_info ();
                if (app_info != null) {
                    var file_list = new List<GLib.File> ();
                    file_list.append (file.file);
                    try {
                        app_info.launch (file_list, null);
                    } catch (Error e) {
                        warning (e.message);
                    }
                }
            }

            dialog.destroy ();
        }

        private void show_file_uri (File file) {
            var file_list = new List<GLib.File> ();
            file_list.append (file.file);

            var app_info = AppInfo.get_default_for_type ("inode/directory", true);

            try {
                app_info.launch (file_list, null);
            } catch (Error e) {
                warning ("Failed to open file manager: %s", e.message);
            }
        }
    }
}
