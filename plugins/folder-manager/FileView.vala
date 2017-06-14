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
     * SourceList that displays folders and their contents.
     */
    internal class FileView : Granite.Widgets.SourceList {
        private Settings settings;

        public signal void select (GLib.File file);
        public signal void welcome_visible (bool visible);
        
        // This is a workaround for SourceList silliness: you cannot remove an item
        // without it automatically selecting another one.
        public bool ignore_next_select = false;

        public FileView () {
            width_request = 180;
            
            item_selected.connect (on_item_selected);

            settings = new Settings ();
        }
        
        private void on_item_selected (Granite.Widgets.SourceList.Item? item) {
            // This is a workaround for SourceList silliness: you cannot remove an item
            // without it automatically selecting another one.
            if (ignore_next_select) {
                ignore_next_select = false;
                return;
            }

            if (item is FileItem) {
                select ((item as FileItem).file.file);
            }
        }

        public void restore_settings () {
            foreach (var folder_path in settings.opened_folders) {
                add_folder (folder_path);
            }
        }

        public void open_folder (string folder_path) {
            add_folder (folder_path);
            write_settings ();
        }

        public void close_folder (string folder_path) {
            foreach (var child in root.children) {
                var folder = child as FolderItem;

                if (folder != null && folder.path == folder_path) {
                    // This is a workaround for SourceList silliness: you cannot remove an item
                    // without it automatically selecting another one.
                    ignore_next_select = true;
                    root.remove(folder);
                    selected = null;
                }
            }

            if (root.n_children == 0) {
                welcome_visible (true);
            }

            write_settings ();
        }

        // Adds the folder to the view without saving to settings
        private void add_folder (string folder_path, bool expand = true) {
            if (folder_path == null) {
                warning ("Was given null folder path to add");
            } else if (is_open (folder_path)) {
                warning ("Folder '%s' is already open.", folder_path);
                return;
            }

            var folder = new File(folder_path);

            if (!folder.is_valid_directory) {
                warning ("Cannot open invalid directory.");
                return;
            }

            bool has_valid_children = false;

            foreach (var child in folder.children) {
                if (child.is_valid_textfile || child.is_valid_directory) {
                    has_valid_children = true;
                    break;
                }
            }

            if (!has_valid_children) {
                warning ("Cannot open empty directory due to limitations with Granite.SourceList.");
                return;
            }

            var folder_item = new FolderItem (folder, this);
            folder_item.expanded = expand;
            root.add (folder_item);

            welcome_visible (false);
        }

        private bool is_open (string folder_path) {
            foreach (var child in root.children) {
                if (folder_path == (child as Item).path) {
                    return true;
                }
            }

            return false;
        }

        private void write_settings () {
            string[] paths = {};
            foreach (var child in root.children) {
                if (child is FolderItem) {
                    paths += ((FolderItem) child).path;
                }
            }

            settings.opened_folders = paths;
        }
    }
}
