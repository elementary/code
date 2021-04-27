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

            var search_item = new Gtk.MenuItem.with_label (_("Find in Project…")) {
                action_name = "win.action_find_global",
                action_target = new Variant.string (file.file.get_path ())
            };

            menu.append (new Gtk.SeparatorMenuItem ());
            menu.append (search_item);
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

        public void global_search (GLib.File start_folder = this.file.file) {
            /* For now set all options to the most inclusive (except case).
             * The ability to set these in the dialog (or by parameter) may be added later. */
            string? term = null;
            bool use_regex = false;
            bool search_tracked_only = false;
            bool recurse_subfolders = true;
            bool check_is_text = true;
            string[] path_spec = {"*.*"};
            bool modified_only = false;
            bool case_sensitive = false;
            Regex? pattern = null;

            var dialog = new Scratch.Dialogs.GlobalSearchDialog (
                null, start_folder.get_basename (), monitored_repo.git_repo != null
            ) {
                case_sensitive = case_sensitive,
                use_regex = use_regex
            };

            dialog.response.connect ((response) => {
                switch (response) {
                    case Gtk.ResponseType.ACCEPT:
                        term = dialog.search_term;
                        use_regex = dialog.use_regex;
                        case_sensitive = dialog.case_sensitive;
                        break;

                    default:
                        break;
                }

                dialog.destroy ();
            });

            dialog.run ();

            if (term != null) {
                /* Put search term in search bar to help user locate the position of the matches in each doc */
                var search_variant = new Variant.string (term);
                var app = (Gtk.Application)GLib.Application.get_default ();
                var win = (Scratch.MainWindow)(app.get_active_window ());
                win.actions.lookup_action ("action_find").activate (search_variant);

                if (!use_regex) {
                    term = Regex.escape_string (term);
                }

                try {
                    var flags = RegexCompileFlags.MULTILINE;
                    if (!case_sensitive) {
                        flags |= RegexCompileFlags.CASELESS;
                    }

                    pattern = new Regex (term, flags);
                } catch (Error e) {
                    critical ("Error creating regex from '%s': %s", term, e.message);
                    return;
                }
            } else {
                return;
            }

            var status_scope = Ggit.StatusOption.DEFAULT;
            if (!modified_only) {
                status_scope |= Ggit.StatusOption.INCLUDE_UNMODIFIED;
            }
            if (!search_tracked_only) {
                status_scope |= Ggit.StatusOption.INCLUDE_UNTRACKED;
            }
            var status_options = new Ggit.StatusOptions (
                status_scope,
                Ggit.StatusShow.WORKDIR_ONLY,
                path_spec
            );

            remove_all_badges ();
            collapse_all ();

            if (monitored_repo != null) {
                try {
                    monitored_repo.git_repo.file_status_foreach (status_options, (rel_path, status) => {
                        var target = file.file.resolve_relative_path (rel_path);
                        if (check_is_text && rel_path.has_prefix ("po/")) { // Ignore translation files
                            return 0;
                        }

                        if ((recurse_subfolders && start_folder.get_relative_path (target) != null) ||
                             start_folder.equal (target.get_parent ())) {

                            perform_match (target, pattern, check_is_text);
                        }

                        return 0; //TODO Allow cancelling?
                    });
                } catch (Error err) {
                    warning ("Error getting file status: %s", err.message);
                }
            } else {
                search_folder_children (start_folder, pattern, recurse_subfolders);
            }

            return;
        }

        private void search_folder_children (GLib.File start_folder, Regex pattern, bool recurse_subfolders) {
            try {
                var enumerator = start_folder.enumerate_children (
                    FileAttribute.STANDARD_CONTENT_TYPE + "," + FileAttribute.STANDARD_TYPE,
                    FileQueryInfoFlags.NOFOLLOW_SYMLINKS,
                    null
                );

                unowned FileInfo info = null;
                unowned GLib.File child = null;
                while (enumerator.iterate (out info, out child, null) && info != null) {
                    if (info != null && info.has_attribute (FileAttribute.STANDARD_TYPE)) {
                        if (info.get_file_type () == FileType.DIRECTORY) {
                            if (recurse_subfolders) {
                                search_folder_children (child, pattern, false); //Limit depth to 1
                            }
                        } else {
                            perform_match (child, pattern, true, info);
                        }
                    }
                }
            } catch (Error enumerate_error) {
                warning ("Error enumerating children of %s: %s", start_folder.get_path (), enumerate_error.message);
            }
        }

        private void perform_match (GLib.File target,
                                    Regex pattern,
                                    bool check_is_text = false,
                                    FileInfo? target_info = null) {
            string contents;
            string target_path = target.get_path ();
            if (check_is_text) {
                FileInfo? info = null;
                if (target_info == null) {
                    try {
                        info = target.query_info (
                            FileAttribute.STANDARD_CONTENT_TYPE,
                            FileQueryInfoFlags.NOFOLLOW_SYMLINKS,
                            null
                        );
                    } catch (Error query_error) {
                        warning (
                            "Error getting file info for %s: %s.  Ignoring.", target.get_path (), query_error.message
                        );
                    }
                } else {
                    info = target_info;
                }

                if (info == null) {
                    return;
                }

                var type = info.get_content_type ();
                if (!ContentType.is_mime_type (type, "text/*") ||
                    ContentType.is_mime_type (type, "image/*")) { //Do not search svg images

                    return;
                }
            }

            try {
                FileUtils.get_contents (target_path, out contents);
            } catch (Error e) {
                warning ("error getting contents: %s", e.message);
                return;
            }

            MatchInfo? match_info = null;
            int match_count = 0;
            try {
                for (pattern.match (contents, 0, out match_info);
                    match_info.matches ();
                    match_info.next ()) {

                    match_count++;
                }
            } catch (RegexError next_error) {
                critical ("Error getting next match: %s", next_error.message);
            }

            if (match_count > 0) {
                unowned var item = view.expand_to_path (target_path);
                if (item != null) {
                    item.badge = match_count.to_string ();
                }
            }

            return;
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

                var main_window = (MainWindow)(project_folder.view.get_toplevel ());
                Utils.action_from_group (
                    MainWindow.ACTION_NEW_BRANCH, main_window.actions
                ).set_enabled (monitored_repo.head_is_branch);

                change_branch_menu.add (new Gtk.SeparatorMenuItem ());
                var branch_item = new Gtk.MenuItem.with_label (_("New Branch…")) {
                    action_name = "win.action_new_branch"
                };

                change_branch_menu.add (branch_item);

                label = _("Branch");
                submenu = change_branch_menu;
            }
        }
    }
}
