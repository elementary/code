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
            GLib.FileInfo info = null;

            try {
                info = file.file.query_info (GLib.FileAttribute.STANDARD_CONTENT_TYPE, 0);
            } catch (Error e) {
                warning (e.message);
            }

            var file_type = info.get_attribute_string (GLib.FileAttribute.STANDARD_CONTENT_TYPE);
            var open_in_terminal_pane_item = new Gtk.MenuItem.with_label (_("Open in Terminal Pane")) {
                action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_OPEN_IN_TERMINAL,
                action_target = new Variant.string (file.file.get_parent ().get_path ())
            };

            var new_window_menuitem = new Gtk.MenuItem.with_label (_("New Window")) {
                action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_OPEN_IN_NEW_WINDOW,
                action_target = file.path
            };

            var other_menuitem = new Gtk.MenuItem.with_label (_("Other Application…")) {
                action_name = FileView.ACTION_PREFIX + FileView.ACTION_SHOW_APP_CHOOSER,
                action_target = file.path
            };

            var open_in_menu = new Gtk.Menu ();
            if (file.is_valid_textfile) {
                open_in_menu.add (new_window_menuitem);
                open_in_menu.add (new Gtk.SeparatorMenuItem ());
            }

            //  Utils.create_executable_app_items_for_file (file.file, file_type, open_in_menu);

            open_in_menu.add (new Gtk.SeparatorMenuItem ());
            open_in_menu.add (other_menuitem);

            var open_in_item = new Gtk.MenuItem.with_label (_("Open In"));
            //  open_in_item.submenu = open_in_menu;

            var contractor_item = new Gtk.MenuItem.with_label (_("Other Actions"));
            //  contractor_item.submenu = Utils.create_contract_items_for_file (file.file);

            var rename_item = new Gtk.MenuItem.with_label (_("Rename")) {
                action_name = FileView.ACTION_PREFIX + FileView.ACTION_RENAME_FILE,
                action_target = new Variant.string (file.path),
            };
            var rename_action = Utils.action_from_group (FileView.ACTION_RENAME_FILE, view.actions);
            rename_action.set_enabled (view.rename_request (file));

            var delete_item = new Gtk.MenuItem.with_label (_("Move to Trash")) {
                action_name = FileView.ACTION_PREFIX + FileView.ACTION_DELETE,
                action_target = new Variant.string (file.path)
            };

            var menu = new Gtk.Menu ();
            menu.append (open_in_terminal_pane_item);
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
