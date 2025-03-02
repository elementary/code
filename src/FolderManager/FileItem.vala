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

        public override void activated () {
            view.activate (file.path);
        }

        public override Gtk.Menu? get_context_menu () {
            GLib.FileInfo info = null;

            try {
                info = file.file.query_info (GLib.FileAttribute.STANDARD_CONTENT_TYPE, 0);
            } catch (Error e) {
                warning (e.message);
            }

            var file_type = info.get_attribute_string (GLib.FileAttribute.STANDARD_CONTENT_TYPE);
            var contractor_items = Utils.create_contract_items_for_file (file.file);
            var external_actions_section = new GLib.Menu ();
            external_actions_section.append_item (create_submenu_for_open_in (file_type));
            if (contractor_items.get_n_items () > 0) {
                external_actions_section.append_submenu (
                    _("Other Actions"),
                    contractor_items
                );
            }

            var rename_item = new GLib.MenuItem (
                _("Rename"),
                GLib.Action.print_detailed_name (
                    FileView.ACTION_PREFIX + FileView.ACTION_RENAME_FILE,
                    new Variant.string (file.path)
                )
            );
            var rename_action = Utils.action_from_group (FileView.ACTION_RENAME_FILE, view.actions);
            rename_action.set_enabled (view.rename_request (file));

            var delete_item = new GLib.MenuItem (
                _("Move to Trash"),
                GLib.Action.print_detailed_name (
                    FileView.ACTION_PREFIX + FileView.ACTION_DELETE,
                    new Variant.string (file.path)
                )
            );

            var direct_actions_section = new GLib.Menu ();
            direct_actions_section.append_item (rename_item);
            direct_actions_section.append_item (delete_item);

            var menu_model = new GLib.Menu ();
            menu_model.append_section (null, external_actions_section);
            menu_model.append_section (null, direct_actions_section);

            var menu = new Gtk.Menu.from_model (menu_model);
            menu.insert_action_group (FileView.ACTION_GROUP, view.actions);
            return menu;
        }

        private GLib.MenuItem create_submenu_for_open_in (string? file_type) {
            var new_window_menu_item = new GLib.MenuItem (
                _("New Window"),
                GLib.Action.print_detailed_name (
                    MainWindow.ACTION_PREFIX + MainWindow.ACTION_OPEN_IN_NEW_WINDOW,
                    file.path
                )
            );

            var top_section = new GLib.Menu ();
            if (file.is_valid_textfile) {
                top_section.append_item (new_window_menu_item);
            }

            var other_menu_item = new GLib.MenuItem (
                _("Other Application…"),
                GLib.Action.print_detailed_name (
                    FileView.ACTION_PREFIX + FileView.ACTION_SHOW_APP_CHOOSER,
                    file.path
                )
            );

            var extra_section = new GLib.Menu ();
            extra_section.append_item (other_menu_item);

            var open_in_menu = new GLib.Menu ();
            open_in_menu.append_section (null, top_section);
            open_in_menu.append_section (null, Utils.create_executable_app_items_for_file (file.file, file_type));
            open_in_menu.append_section (null, extra_section);

            var open_in_menu_item = new GLib.MenuItem.submenu (_("Open In"), open_in_menu);
            return open_in_menu_item;
        }
    }
}
