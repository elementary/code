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
     * Expandable item in the source list, represents a folder.
     * Monitored for changes inside the directory.
     */
    internal class FolderItem : Item {
        private GLib.FileMonitor monitor;
        private bool children_loaded = false;
        private string? newly_created_path = null;
        private Ggit.Repository? git_repo = null;

        public FolderItem (File file, FileView view) requires (file.is_valid_directory) {
            Object (file: file, view: view);
        }

        ~FolderItem () {
            monitor.cancel ();
        }

        construct {
            add (new Granite.Widgets.SourceList.Item ("")); // dummy

            toggled.connect (() => {
                if (!children_loaded && expanded && n_children <= 1 && file.children.size > 0) {
                    clear ();
                    add_children ();
                    children_loaded = true;
                }
            });

            try {
                monitor = file.file.monitor_directory (GLib.FileMonitorFlags.NONE);
                monitor.changed.connect (on_changed);
            } catch (GLib.Error e) {
                warning (e.message);
            }

            // If this is a toplevel project, see if it is a git repo
            if (this is MainFolderItem) {
                try {
                    git_repo = Ggit.Repository.open (file.file);
                } catch (Error e) {
                    debug ("Error opening git repo, means this probably isn't one: %s", e.message);
                }

                if (git_repo != null) {
                    update_git_status ();
                }
            }
        }

        public override Gtk.Menu? get_context_menu () {
            var rename_item = new Gtk.MenuItem.with_label (_("Rename"));
            rename_item.activate.connect (() => view.start_editing_item (this));

            var delete_item = new Gtk.MenuItem.with_label (_("Move to Trash"));
            delete_item.activate.connect (trash);

            var menu = new Gtk.Menu ();
            menu.append (rename_item);
            menu.append (create_submenu_for_new ());
            menu.append (delete_item);
            menu.show_all ();

            return menu;
        }

        protected Gtk.MenuItem create_submenu_for_new () {
            var new_folder_item = new Gtk.MenuItem.with_label (_("Folder"));
            new_folder_item.activate.connect(() => add_folder ());

            var new_file_item = new Gtk.MenuItem.with_label (_("Empty File"));
            new_file_item.activate.connect (() => add_file ());

            var new_menu = new Gtk.Menu ();
            new_menu.append (new_folder_item);
            new_menu.append (new_file_item);

            var new_item = new Gtk.MenuItem.with_label (_("New"));
            new_item.set_submenu (new_menu);

            return new_item;
        }

        private void add_children () {
            foreach (var child in file.children) {
                if (child.is_valid_directory) {
                    var item = new FolderItem (child, view);
                    add (item);
                } else if (child.is_valid_textfile) {
                    var item = new FileItem (child, view);
                    add (item);
                }
            }
        }

        private void remove_all_children () {
            foreach (var child in children) {
                remove (child);
            }
        }

        private new void remove (Granite.Widgets.SourceList.Item item) {
            if (item is FolderItem) {
                (item as FolderItem).remove_all_children ();
            }

            base.remove (item);
        }

        private void on_changed (GLib.File source, GLib.File? dest, GLib.FileMonitorEvent event) {
            if (!children_loaded) {
                switch (event) {
                    case GLib.FileMonitorEvent.DELETED:
                        // This is a pretty intensive operation. For each file deleted, the cache will be
                        // invalidated and recreated again, from disk. If it turns out users are seeing
                        // slugishness or slowness when deleting a lot of files, then it might be worth
                        // storing file.children.size in a variable and subtracting from it with every
                        // delete
                        file.invalidate_cache ();

                        if (file.children.size == 0) {
                            clear ();
                        }
                        break;
                    case GLib.FileMonitorEvent.CREATED:
                        if (source.query_exists () == false) {
                            return;
                        }

                        file.invalidate_cache ();

                        if (n_children == 0) {
                            add (new Granite.Widgets.SourceList.Item ("")); // dummy
                        }
                        break;
                }
            } else {
                // No cache invalidation is needed here because the entire state is kept in the tree

                switch (event) {
                    case GLib.FileMonitorEvent.DELETED:
                        var children_tmp = new Gee.ArrayList<Granite.Widgets.SourceList.Item> ();
                        children_tmp.add_all (children);
                        foreach (var item in children_tmp) {
                            if ((item as Item).path == source.get_path ()) {
                                // This is a workaround for SourceList silliness: you cannot remove an item
                                // without it automatically selecting another one.

                                view.ignore_next_select = true;
                                remove (item);
                                if (file.children.size == 0) {
                                    clear ();
                                    add (new Granite.Widgets.SourceList.Item ("")); // dummy
                                    expanded = false;
                                    children_loaded = false;
                                }

                                view.selected = null;
                            }
                        }

                        break;
                    case GLib.FileMonitorEvent.CREATED:
                        if (source.query_exists () == false) {
                            return;
                        }

                        // Temporary files from GLib that are present when saving a file
                        if (source.get_basename ().has_prefix (".goutputstream")) {
                            return;
                        }

                        var file = new File (source.get_path ());
                        var exists = false;
                        foreach (var item in children) {
                            if ((item as Item).path == file.path) {
                                exists = true;
                                break;
                            }
                        }

                        Item? item = null;

                        if (!exists) {
                            if (file.is_valid_textfile) {
                                item = new FileItem (file, view);
                            } else if (file.is_valid_directory) {
                                item = new FolderItem (file, view);
                            }
                        }

                        if (item != null) {
                            add (item);

                            if (source.get_path () == newly_created_path) {
                                newly_created_path = null;

                                /*
                                 * Avoid race condition between adding and editing folder item
                                 * (not required for file items).
                                 */
                                GLib.Idle.add (() => {
                                    view.start_editing_item (item);
                                    return false;
                                });
                            }
                        }

                        break;
                }
            }
        }

        private void update_git_status () {
            if (git_repo == null) {
                return;
            }

            warning (git_repo.list_remotes ()[0]);
        }

        protected void add_folder () {
            if (!file.is_executable) {
                // This is necessary to avoid infinite loop below
                warning("Unable to open parent folder");
                return;
            }

            var new_folder = file.file.get_child (_("untitled folder"));

            var n = 1;
            while (new_folder.query_exists ()) {
                new_folder = file.file.get_child (_("untitled folder %d").printf (n));
                n++;
            }

            try {
                expanded = true;

                new_folder.make_directory ();

                newly_created_path = new_folder.get_path ();

                if (!children_loaded) {
                    clear ();
                    add_children ();
                    children_loaded = true;
                }
            } catch (Error e) {
                warning (e.message);
            }
        }

        protected void add_file () {
            if (!file.is_executable) {
                // This is necessary to avoid infinite loop below
                warning("Unable to open parent folder");
                return;
            }

            var new_file = file.file.get_child (_("new file"));

            var n = 1;
            while (new_file.query_exists ()) {
                new_file = file.file.get_child (_("new file %d").printf (n));
                n++;
            }

            try {
                expanded = true;

                new_file.create (FileCreateFlags.NONE);

                newly_created_path = new_file.get_path ();

                if (!children_loaded) {
                    clear ();
                    add_children ();
                    children_loaded = true;
                }
            } catch (Error e) {
                warning (e.message);
            }
        }
    }
}
