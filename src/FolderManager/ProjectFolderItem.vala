/*-
 * Copyright (c) 2018 elementary LLC. (https://elementary.io),
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
 * Authored by: David Hewitt <davidmhewitt@gmail.com>
 */

namespace Scratch.FolderManager {
    internal class ProjectFolderItem : FolderItem {
        struct VisibleItem {
            public string rel_path;
            public Item item;
        }

        private static Icon added_icon;
        private static Icon modified_icon;

        public signal void closed ();
        public signal void close_all_except ();

        private Scratch.Services.MonitoredRepository? monitored_repo = null;
        // Cache the visible item in the project.
        private List<VisibleItem?> visible_item_list = null;
        public string top_level_path { get; construct; }

        public ProjectFolderItem (File file, FileView view) requires (file.is_valid_directory) {
            Object (file: file, view: view);
        }

        static construct {
            added_icon = new ThemedIcon ("user-available");
            modified_icon = new ThemedIcon ("user-away");
        }

        construct {
            monitored_repo = Scratch.Services.GitManager.get_instance ().add_project (file.file);
            if (monitored_repo != null) {
                monitored_repo.branch_changed.connect ((update_branch_name));
                monitored_repo.ignored_changed.connect ((deprioritize_git_ignored));
                monitored_repo.file_status_change.connect (() => update_item_status (null));
                monitored_repo.update ();
            }
        }

        public void child_folder_changed (FolderItem folder) {
            if (monitored_repo != null) {
                monitored_repo.update ();
            }
        }

        public void child_folder_loaded (FolderItem folder) {
            foreach (var child in folder.children) {
                if (child is Item) {
                    var item = (Item)child;
                    var rel_path = this.file.file.get_relative_path (item.file.file);

                    if (rel_path != null && rel_path != "") {
                        visible_item_list.prepend ({rel_path, item});
                    }
                }
            }

            if (monitored_repo != null) {
                update_item_status (folder);
                deprioritize_git_ignored ();
            }
        }

        public override Gtk.Menu? get_context_menu () {
            var close_item = new Gtk.MenuItem.with_label (_("Close Folder"));
            close_item.activate.connect (() => { closed (); });

            var close_all_except_item = new Gtk.MenuItem.with_label (_("Close Other Folders"));
            close_all_except_item.activate.connect (() => { close_all_except (); });
            close_all_except_item.sensitive = view.root.children.size > 1;

            var delete_item = new Gtk.MenuItem.with_label (_("Move to Trash"));
            delete_item.activate.connect (() => {
                closed ();
                trash ();
            });

            GLib.FileInfo info = null;
            unowned string? file_type = null;

            try {
                info = file.file.query_info (GLib.FileAttribute.STANDARD_CONTENT_TYPE, GLib.FileQueryInfoFlags.NONE);
                file_type = info.get_content_type ();
            } catch (Error e) {
                warning (e.message);
            }

            var menu = new Gtk.Menu ();
            menu.append (create_submenu_for_open_in (info, file_type));
            menu.append (new Gtk.SeparatorMenuItem ());
            menu.append (create_submenu_for_new ());

            if (monitored_repo != null) {
                menu.append (new ChangeBranchMenu (this));
            }

            menu.append (new Gtk.SeparatorMenuItem ());
            menu.append (close_item);
            menu.append (close_all_except_item);
            menu.append (delete_item);

            menu.show_all ();

            return menu;
        }

        public void update_item_status (FolderItem? start_folder) requires (monitored_repo != null) {
            bool is_new = false;
            string start_path = start_folder != null ? start_folder.path : "";
            visible_item_list.@foreach ((visible_item) => {
                if (start_path.has_prefix (visible_item.rel_path)) {
                    return; //Only need to update status for start_folder and its children
                }

                var item = visible_item.item;
                item.activatable = null;
                monitored_repo.non_current_entries.@foreach ((entry) => {
                    // Match non_current_path with parent folder as well as itself
                    var match = entry.key.has_prefix (visible_item.rel_path);
                    if (match) {
                        is_new = (entry.@value & (Ggit.StatusFlags.WORKING_TREE_NEW | Ggit.StatusFlags.INDEX_NEW)) > 0;
                        // Only mark folders new if only contains new items otherwise mark modified
                        if (item is FolderItem &&
                            is_new && item.activatable == null) {

                            item.activatable = added_icon;
                            item.activatable_tooltip = _("New");
                            return true;  // scan all children
                        }

                        if (!(item is FolderItem) || !item.expanded) { //No need to show status when children shown
                            item.activatable = is_new ? added_icon : modified_icon;
                            item.activatable_tooltip = is_new ? _("New") : _("Modified");
                        }
                        return false;
                    } else {
                        return true;
                    }
                });
            });
        }

        private void update_branch_name (string branch_name) requires (monitored_repo != null) {
            markup = "%s <span size='small' weight='normal'>%s</span>".printf (file.name, branch_name);
        }

        private void deprioritize_git_ignored () requires (monitored_repo != null) {
            visible_item_list.@foreach ((visible_item) => {
                var item = visible_item.item;
                try {
                    if (monitored_repo.path_is_ignored (visible_item.rel_path)) {
                        item.markup = Markup.printf_escaped ("<span fgalpha='75&#37;'><i>%s</i></span>", item.name);
                    } else {
                        item.markup = item.name;
                    }
                } catch (Error e) {
                    warning ("An error occured while checking if item '%s' is git-ignored: %s", item.name, e.message);
                }
            });
        }

        public void new_branch () {
            try {
                if (monitored_repo.head_is_branch) {
                    var new_branch_name = get_new_branch_name ();
                    if (new_branch_name != null) {
                        monitored_repo.create_new_branch (new_branch_name);
                    }
                }
            } catch (Error e) {
                warning ("Error creating branch %s", e.message);
            }
        }

        private string? get_new_branch_name () throws Error {
            string? name = null;

            var dialog = new Granite.MessageDialog.with_image_from_icon_name (
                _("Create a new local branch in “%s”").printf (file.name),
                _("The branch parent will be “%s” and it will include any uncommitted changes").printf (
                    monitored_repo.branch_name
                ),
                "applications-development",
                Gtk.ButtonsType.CANCEL) {
                // Have to get toplevel window from view as ProjectFolderItem is not a widget
                transient_for = (Gtk.Window)(view.get_toplevel ())
            };

            var create_button = new Gtk.Button.with_label (_("Create Branch"));
            create_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);

            var entry = new Granite.ValidatedEntry.from_regex (new Regex ("^[a-z]+[a-z0-9--]*$"));
            entry.bind_property (
                "is-valid", create_button, "sensitive", BindingFlags.DEFAULT | BindingFlags.SYNC_CREATE
            );

            dialog.add_action_widget (create_button, Gtk.ResponseType.APPLY);
            dialog.custom_bin.add (entry);

            dialog.show_all ();

            if (dialog.run () == Gtk.ResponseType.APPLY) {
                name = entry.text;
            }

            dialog.destroy ();

            return name;
        }

        private class ChangeBranchMenu : Gtk.MenuItem {
            public Scratch.Services.MonitoredRepository monitored_repo {
                get {
                    return project_folder.monitored_repo;
                }
            }
            public ProjectFolderItem project_folder { get; construct; }
            public ChangeBranchMenu (ProjectFolderItem project_folder) {
                 Object (
                     project_folder: project_folder
                 );

                string current_branch_name = monitored_repo.get_current_branch ();
                string[] local_branch_names = monitored_repo.get_local_branches ();
                var change_branch_menu = new Gtk.Menu ();

                foreach (var branch_name in local_branch_names) {
                    var branch_item = new Gtk.CheckMenuItem.with_label (branch_name);
                    branch_item.draw_as_radio = true;

                    if (branch_name == current_branch_name) {
                        branch_item.active = true;
                    }

                    change_branch_menu.add (branch_item);

                    branch_item.toggled.connect (() => {
                        try {
                            monitored_repo.change_branch (branch_name);
                        } catch (GLib.Error e) {
                            warning ("Failed to change branch to %s.  %s", name, e.message);
                        }
                    });
                }

                if (monitored_repo.head_is_branch) {
                    change_branch_menu.add (new Gtk.SeparatorMenuItem ());
                    var branch_item = new Gtk.MenuItem.with_label (_("New Branch…")) {
                        action_name = "win.action_new_branch"
                    };

                    change_branch_menu.add (branch_item);
                }

                label = _("Branch");
                submenu = change_branch_menu;
            }
        }
    }
}
