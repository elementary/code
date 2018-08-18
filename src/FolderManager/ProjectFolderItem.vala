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
    internal class ProjectFolderItem : FolderItem {
        // Minimum time to elapse before querying git folder again (ms)
        private const uint GIT_UPDATE_RATE_LIMIT = 300;

        public signal void closed ();

        // Static source IDs for each instance of a top level folder, ensures we don't check for git updates too much
        private static Gee.HashMap<string, uint> git_update_timer_ids;
        private string top_level_path;
        private Ggit.Repository? git_repo = null;
        private GLib.FileMonitor git_monitor;

        private static Icon added_icon;
        private static Icon modified_icon;

        public ProjectFolderItem (File file, FileView view) requires (file.is_valid_directory) {
            Object (file: file, view: view);
        }

        ~ProjectFolderItem () {
            if (git_monitor != null) {
                git_monitor.cancel ();
            }
        }

        static construct {
            Ggit.init ();

            git_update_timer_ids = new Gee.HashMap<string, uint> ();
            added_icon = new ThemedIcon ("user-available");
            modified_icon = new ThemedIcon ("user-away");
        }

        construct {
            top_level_path = file.file.get_path () + Path.DIR_SEPARATOR_S;

            try {
                git_repo = Ggit.Repository.open (file.file);
            } catch (Error e) {
                debug ("Error opening git repo, means this probably isn't one: %s", e.message);
            }

            if (git_repo != null) {
                update_git_status ();
                var git_folder = GLib.File.new_for_path (Path.build_filename (top_level_path, ".git"));
                if (git_folder.query_exists ()) {
                    try {
                        git_monitor = git_folder.monitor_directory (GLib.FileMonitorFlags.NONE);
                        git_monitor.changed.connect (() => update_git_status ());
                    } catch (IOError e) {
                        warning ("An error occured setting up a file monitor on the git folder: %s", e.message);
                    }
                }
            }
        }

        public override Gtk.Menu? get_context_menu () {
            var close_item = new Gtk.MenuItem.with_label (_("Close Folder"));
            close_item.activate.connect (() => { closed (); });

            var delete_item = new Gtk.MenuItem.with_label (_("Move to Trash"));
            delete_item.activate.connect (() => {
                closed ();
                trash ();
            });

            var menu = new Gtk.Menu ();
            menu.append (close_item);
            menu.append (create_submenu_for_new ());
            menu.append (delete_item);
            menu.show_all ();

            return menu;
        }

        public void update_git_status () {
            var uri = file.file.get_uri ();

            if (git_update_timer_ids.has_key (uri) && git_update_timer_ids[uri] != 0) {
                // Update already queued, ignore this request
                return;
            }

            git_update_timer_ids[uri] = Timeout.add (GIT_UPDATE_RATE_LIMIT, () => {
                do_git_update ();
                git_update_timer_ids[uri] = 0;
                return Source.REMOVE;
            });
        }

        private void do_git_update () {
            if (git_repo == null) {
                return;
            }

            try {
                var head = git_repo.get_head ();
                if (head.is_branch ()) {
                    var branch = git_repo.get_head () as Ggit.Branch;
                    markup = "%s <span size='small' weight='normal'>%s</span>".printf (file.name, branch.get_name ());
                }
            } catch (Error e) {
                warning ("An error occured while fetching the current git branch name: %s", e.message);
            }

            reset_all_children (this);
            var options = new Ggit.StatusOptions (Ggit.StatusOption.INCLUDE_UNTRACKED, Ggit.StatusShow.INDEX_AND_WORKDIR, null);
            try {
                git_repo.file_status_foreach (options, check_each_git_status);
            } catch (Error e) {
                critical ("Error enumerating git status: %s", e.message);
            }
        }

        private int check_each_git_status (string path, Ggit.StatusFlags status) {
            if (Ggit.StatusFlags.WORKING_TREE_MODIFIED in status || Ggit.StatusFlags.INDEX_MODIFIED in status) {
                var modified_items = new Gee.ArrayList<Item> ();
                find_items (this, path, ref modified_items);
                foreach (var modified_item in modified_items) {
                    modified_item.activatable = modified_icon;
                }
            } else if (Ggit.StatusFlags.WORKING_TREE_NEW in status || Ggit.StatusFlags.INDEX_NEW in status) {
                var new_items = new Gee.ArrayList<Item> ();
                find_items (this, path, ref new_items);
                foreach (var new_item in new_items) {
                    // Only show an added indicator on items that aren't already showing modified state
                    if (new_item.activatable == null) {
                        new_item.activatable = added_icon;
                    }
                }
            }

            return 0;
        }

        private void find_items (Item toplevel_item, string relative_path, ref Gee.ArrayList<Item> items) {
            foreach (var child in toplevel_item.children) {
                var item = child as Item;
                if (item == null) {
                    continue;
                }

                var item_relpath = item.path.replace (top_level_path, "");
                var parts = item_relpath.split (Path.DIR_SEPARATOR_S);
                var search_parts = relative_path.split (Path.DIR_SEPARATOR_S);

                if (parts.length > search_parts.length) {
                    continue;
                }

                bool match = true;
                for (int i = 0; i < parts.length; i++) {
                    if (parts[i] != search_parts[i]) {
                        match = false;
                        break;
                    }
                }

                if (match) {
                    items.add (item);
                }

                if (item is Granite.Widgets.SourceList.ExpandableItem) {
                    find_items (item, relative_path, ref items);
                }
            }
        }

        private void reset_all_children (Item toplevel_item) {
            foreach (var child in toplevel_item.children) {
                var item = child as Item;
                if (item == null) {
                    continue;
                }

                item.name = item.file.name;
                item.markup = null;
                item.activatable = null;

                if (item is Granite.Widgets.SourceList.ExpandableItem) {
                    reset_all_children (item);
                }
            }
        }
    }
}
