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
    Settings settings;

    /**
     * SourceList that displays folders and their contents.
     */
    internal class FileView : Granite.Widgets.SourceList {

        public signal void select (string file);

        public FileView () {
            this.width_request = 180;
            this.item_selected.connect ((item) => {
                select ((item as FileItem).path);
            });

            settings = new Settings ();
        }

        public void restore_saved_state () {
            foreach (var path in settings.opened_folders)
                add_folder (new File (path), false);
        }

        public void open_folder (File folder) {
            if (is_open (folder)) {
                warning ("Folder '%s' is already open.", folder.path);
                return;
            } else if (!folder.is_valid_directory) {
                warning ("Cannot open invalid directory.");
                return;
            }

            add_folder (folder, true);
            write_settings ();
        }

        private void add_folder (File folder, bool expand) {
            if (is_open (folder)) {
                warning ("Folder '%s' is already open.", folder.path);
                return;
            } else if (!folder.is_valid_directory) {
                warning ("Cannot open invalid directory.");
                return;
            }

            var folder_root = new MainFolderItem (folder);
            this.root.add (folder_root);

            folder_root.expanded = expand;
            folder_root.closed.connect (() => {
                root.remove (folder_root);
                write_settings ();
            });
        }

        private bool is_open (File folder) {
            foreach (var child in root.children)
                if (folder.path == (child as Item).path)
                    return true;
            return false;
        }

        private void write_settings () {
            string[] to_save = {};

            foreach (var main_folder in root.children) {
                var saved = false;

                foreach (var saved_folder in to_save) {
                    if ((main_folder as Item).path == saved_folder) {
                        saved = true;
                        break;
                    }
                }

                if (!saved) {
                    to_save += (main_folder as Item).path;
                }
            }

            settings.opened_folders = to_save;
        }
    }

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
