/*-
 * Copyright (c) 2017-2018 elementary LLC. (https://elementary.io),
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
    public class FileItem : Item {
        public FileItem (File file, FileView view) {
            Object (file: file, view: view);
        }

        public override Gtk.Menu? get_context_menu () {
            var new_window_menuitem = new Gtk.MenuItem.with_label (_("New Window"));
            new_window_menuitem.activate.connect (() => {
                var new_window = ((Scratch.Application) GLib.Application.get_default ()).new_window ();
                var doc = new Scratch.Services.Document (new_window.actions, file.file);

                new_window.open_document (doc, true);
            });

            var files_menuitem = new Gtk.MenuItem.with_label (_("File Manager…"));
            files_menuitem.activate.connect (() => launch_in_file_manager (file));

            var other_menuitem = new Gtk.MenuItem.with_label (_("Other Application…"));
            other_menuitem.activate.connect (() => show_app_chooser (file));

            var open_in_menu = new Gtk.Menu ();
            if (file.is_valid_textfile) {
                open_in_menu.add (new_window_menuitem);
                open_in_menu.add (new Gtk.SeparatorMenuItem ());
            }
            open_in_menu.add (files_menuitem);

            var contractor_menu = new Gtk.Menu ();

            GLib.FileInfo info = null;

            try {
                info = file.file.query_info (GLib.FileAttribute.STANDARD_CONTENT_TYPE, 0);
            } catch (Error e) {
                warning (e.message);
            }

            if (info != null) {
                var file_type = info.get_attribute_string (GLib.FileAttribute.STANDARD_CONTENT_TYPE);

                try {
                    var contracts = Granite.Services.ContractorProxy.get_contracts_by_mime (file_type);
                    foreach (var contract in contracts) {
                        var menu_item = new ContractMenuItem (contract, file.file);
                        contractor_menu.append (menu_item);
                        menu_item.show_all ();
                    }
                } catch (Error e) {
                    warning (e.message);
                }
            }

            open_in_menu.add (new Gtk.SeparatorMenuItem ());
            open_in_menu.add (other_menuitem);

            var open_in_item = new Gtk.MenuItem.with_label (_("Open In"));
            open_in_item.submenu = open_in_menu;

            var contractor_item = new Gtk.MenuItem.with_label (_("Other Actions"));
            contractor_item.submenu = contractor_menu;

            var rename_item = new Gtk.MenuItem.with_label (_("Rename"));
            rename_item.activate.connect (() => {
                view.ignore_next_select = true;
                view.start_editing_item (this);
            });

            var delete_item = new Gtk.MenuItem.with_label (_("Move to Trash"));
            delete_item.activate.connect (trash);

            var menu = new Gtk.Menu ();
            menu.append (open_in_item);
            menu.append (contractor_item);
            menu.append (new Gtk.SeparatorMenuItem ());
            menu.append (rename_item);
            menu.append (delete_item);
            menu.show_all ();

            return menu;
        }
    }
}
