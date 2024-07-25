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

            var open_in_terminal_pane_item = new GLib.MenuItem (
                _("Open in Terminal Pane"),
                GLib.Action.print_detailed_name (
                    MainWindow.ACTION_PREFIX + MainWindow.ACTION_OPEN_IN_TERMINAL,
                    new Variant.string (file.file.get_parent ().get_path ())
                )
            );

            var external_actions_section = new GLib.Menu ();
            external_actions_section.append_item (open_in_terminal_pane_item);
            external_actions_section.append_item (create_submenu_for_open_in (file_type));
            external_actions_section.append_submenu (
                _("Other Actions"),
                Utils.create_contract_items_for_file (file.file)
            );

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

            //  menu.append (open_in_terminal_pane_item);
            //  menu.append (open_in_item);
            //  menu.append (contractor_item);
            //  menu.append (new Gtk.SeparatorMenuItem ());
            //  menu.append (rename_item);
            //  menu.append (delete_item);
            //  menu.show_all ();

            var menu_model = new GLib.Menu ();
            menu_model.append_section (null, external_actions_section);

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
