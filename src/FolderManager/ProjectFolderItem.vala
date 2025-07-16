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
    public class ProjectFolderItem : FolderItem {
        struct VisibleItem {
            public string rel_path;
            public Item item;
        }

        private static Icon added_icon;
        private static Icon modified_icon;
        private SimpleAction checkout_local_branch_action;
        private SimpleAction checkout_remote_branch_action;

        public signal void closed ();

        public Scratch.Services.MonitoredRepository? monitored_repo { get; private set; default = null; }
        // Cache the visible item in the project.
        private List<VisibleItem?> visible_item_list = null;

        public bool is_git_repo {
            get {
                return monitored_repo != null;
            }
        }

        private Ggit.Repository? git_repo {
            get {
                return (is_git_repo ? monitored_repo.git_repo : null);
            }
        }

        public ProjectFolderItem (File file, FileView view) requires (file.is_valid_directory) {
            Object (file: file, view: view);
        }

        static construct {
            added_icon = new ThemedIcon ("emblem-git-new-symbolic");
            modified_icon = new ThemedIcon ("emblem-git-modified-symbolic");
        }

        private void branch_or_name_changed () {
            if (monitored_repo != null) {
                //As SourceList items are not widgets we have to use markup to change appearance of text.
                if (monitored_repo.head_is_branch) {
                    markup = "%s\n<span size='small' weight='normal'>%s</span>".printf (
                        name, monitored_repo.branch_name
                    );
                } else { //Distinguish detached heads visually
                    markup = "%s\n <span size='small' weight='normal' style='italic'>%s</span>".printf (
                        name, monitored_repo.branch_name
                    );
                }

                checkout_local_branch_action.set_state (monitored_repo.branch_name);
            }
        }

        construct {
            monitored_repo = Scratch.Services.GitManager.get_instance ().add_project (this);
            notify["name"].connect (branch_or_name_changed);
            if (monitored_repo != null) {
                checkout_local_branch_action = new SimpleAction.stateful (
                    FileView.ACTION_CHECKOUT_LOCAL_BRANCH,
                    GLib.VariantType.STRING,
                    ""
                );
                checkout_remote_branch_action = new SimpleAction.stateful (
                    FileView.ACTION_CHECKOUT_REMOTE_BRANCH,
                    GLib.VariantType.STRING,
                    ""
                );
                monitored_repo.branch_changed.connect (branch_or_name_changed);
                monitored_repo.ignored_changed.connect ((deprioritize_git_ignored));
                monitored_repo.file_status_change.connect (() => update_item_status (null));
                monitored_repo.update_status_map ();
                monitored_repo.branch_changed ();
                checkout_local_branch_action.activate.connect (handle_checkout_local_branch_action);
                checkout_remote_branch_action.activate.connect (handle_checkout_remote_branch_action);
            }
        }

        protected override void on_changed (GLib.File source, GLib.File? dest, GLib.FileMonitorEvent event) {
            if (source.equal (file.file) && event == DELETED) {
                closed ();
            } else {
                base.on_changed (source, dest, event);
            }
        }

        public void child_folder_changed (FolderItem folder) {
            if (monitored_repo != null) {
                monitored_repo.update_status_map ();
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
                monitored_repo.update_status_map ();
                update_item_status (folder);
                deprioritize_git_ignored ();
            }
        }

        public override Gtk.Menu? get_context_menu () {
            string file_type = "";
            try {
                var info = file.file.query_info (GLib.FileAttribute.STANDARD_CONTENT_TYPE, GLib.FileQueryInfoFlags.NONE);
                if (info.has_attribute (GLib.FileAttribute.STANDARD_CONTENT_TYPE)) {
                    file_type = info.get_content_type ();
                }
            } catch (Error e) {
                warning (e.message);
            }

            MenuItem set_active_folder_item;
            if (is_git_repo) {
                set_active_folder_item = new GLib.MenuItem (
                    _("Set as Active Project"),
                    GLib.Action.print_detailed_name (
                        FileView.ACTION_PREFIX + FileView.ACTION_SET_ACTIVE_PROJECT,
                        new Variant.string (file.path)
                    )
                );
            } else {
                set_active_folder_item = new GLib.MenuItem (
                    _("Open in Terminal Pane"),
                    GLib.Action.print_detailed_name (
                        MainWindow.ACTION_PREFIX + MainWindow.ACTION_OPEN_IN_TERMINAL,
                        new Variant.string (
                            Services.GitManager.get_instance ().get_default_build_dir (path)
                        )
                    )
                );
            }

            set_active_folder_item.set_attribute_value (
                "accel",
                Utils.get_accel_for_action (
                    GLib.Action.print_detailed_name (
                        MainWindow.ACTION_PREFIX + MainWindow.ACTION_OPEN_IN_TERMINAL,
                        ""
                    )
                )
            );

            var external_actions_section = new GLib.Menu ();
            external_actions_section.append_item (set_active_folder_item);
            external_actions_section.append_item (create_submenu_for_open_in (file_type));

            var folder_actions_section = new GLib.Menu ();
            folder_actions_section.append_item (create_submenu_for_new ());
            if (monitored_repo != null) {
                folder_actions_section.append_item (create_submenu_for_branch ());
            }

            var close_folder_item = new GLib.MenuItem (
                _("Close Folder"),
                GLib.Action.print_detailed_name (
                    FileView.ACTION_PREFIX + FileView.ACTION_CLOSE_FOLDER,
                    new Variant.string (file.path)
                )
            );

            var close_all_except_item = new GLib.MenuItem (
                _("Close Other Folders"),
                GLib.Action.print_detailed_name (
                    FileView.ACTION_PREFIX + FileView.ACTION_CLOSE_OTHER_FOLDERS,
                    new Variant.string (file.path)
                )
            );
            var close_other_folders_action = Utils.action_from_group (
                FileView.ACTION_CLOSE_OTHER_FOLDERS,
                view.actions
            );
            close_other_folders_action.set_enabled (view.root.children.size > 1);

            var close_actions_section = new GLib.Menu ();
            close_actions_section.append_item (close_folder_item);
            close_actions_section.append_item (close_all_except_item);

            var n_open = Scratch.Services.DocumentManager.get_instance ().open_for_project (path);
            var open_text = ngettext ("Close %u Open Document",
                                      "Close %u Open Documents",
                                      n_open).printf (n_open);

            var close_item = new GLib.MenuItem (
                open_text,
                GLib.Action.print_detailed_name (
                    MainWindow.ACTION_PREFIX + MainWindow.ACTION_CLOSE_PROJECT_DOCS,
                    new Variant.string (file.file.get_path ())
                )
            );

            var hide_text = ngettext ("Hide %u Open Document",
                                      "Hide %u Open Documents",
                                      n_open).printf (n_open);

            var hide_item = new GLib.MenuItem (
                hide_text,
                GLib.Action.print_detailed_name (
                    MainWindow.ACTION_PREFIX + MainWindow.ACTION_HIDE_PROJECT_DOCS,
                    new Variant.string (file.file.get_path ())
                )
            );

            hide_item.set_attribute_value (
                "accel",
                Utils.get_accel_for_action (
                    GLib.Action.print_detailed_name (
                        MainWindow.ACTION_PREFIX + MainWindow.ACTION_HIDE_PROJECT_DOCS,
                        ""
                    )
                )
            );

            var n_restorable = Scratch.Services.DocumentManager.get_instance ().restorable_for_project (path);
            var restore_text = ngettext ("Restore %u Hidden Document",
                                         "Restore %u Hidden Documents",
                                         n_restorable).printf (n_restorable);

            var restore_item = new GLib.MenuItem (
                restore_text,
                GLib.Action.print_detailed_name (
                    MainWindow.ACTION_PREFIX + MainWindow.ACTION_RESTORE_PROJECT_DOCS,
                    new Variant.string (file.file.get_path ())
                )
            );

            restore_item.set_attribute_value (
                "accel",
                Utils.get_accel_for_action (
                    GLib.Action.print_detailed_name (
                        MainWindow.ACTION_PREFIX + MainWindow.ACTION_RESTORE_PROJECT_DOCS,
                        ""
                    )
                )
            );

            var direct_actions_section = new GLib.Menu ();
            if (n_restorable > 0) {
                direct_actions_section.append_item (restore_item);
            }

            if (n_open > 0) {
                direct_actions_section.append_item (hide_item);
                direct_actions_section.append_item (close_item);
            }

            var search_item = new GLib.MenuItem (
                _("Find in Project…"),
                GLib.Action.print_detailed_name (
                    MainWindow.ACTION_PREFIX + MainWindow.ACTION_FIND_GLOBAL,
                    new Variant.string (file.file.get_path ())
                )
            );

            search_item.set_attribute_value (
                "accel",
                Utils.get_accel_for_action (
                    GLib.Action.print_detailed_name (
                        MainWindow.ACTION_PREFIX + MainWindow.ACTION_FIND_GLOBAL,
                        ""
                    )
                )
            );

            var search_actions_section = new GLib.Menu ();
            search_actions_section.append_item (search_item);

            var menu_model = new GLib.Menu ();
            menu_model.append_section (null, external_actions_section);
            menu_model.append_section (null, folder_actions_section);
            menu_model.append_section (null, close_actions_section);
            menu_model.append_section (null, direct_actions_section);
            menu_model.append_section (null, search_actions_section);

            var menu = new Gtk.Menu.from_model (menu_model);
            menu.insert_action_group (FileView.ACTION_GROUP, view.actions);
            return menu;
        }

        protected GLib.MenuItem create_submenu_for_branch () {
            // Ensures that action for relevant project is being used
            view.actions.add_action (checkout_local_branch_action);
            view.actions.add_action (checkout_remote_branch_action);

            unowned var local_branches = monitored_repo.get_local_branches ();
            var local_branch_submenu = new Menu ();
            var local_branch_menu = new Menu ();
            if (local_branches.length () > 0) {
                local_branch_submenu.append_submenu (_("Local"), local_branch_menu);
                foreach (unowned var branch_name in local_branches) {
                    local_branch_menu.append (
                        branch_name,
                        GLib.Action.print_detailed_name (
                            FileView.ACTION_PREFIX + FileView.ACTION_CHECKOUT_LOCAL_BRANCH,
                            branch_name
                        )
                    );
                }
            }


            unowned var remote_branches = monitored_repo.get_remote_branches ();
            var remote_branch_submenu = new Menu ();
            var remote_branch_menu = new Menu ();
            if (remote_branches.length () > 0) {
                remote_branch_submenu.append_submenu (_("Remote"), remote_branch_menu);
                foreach (unowned var branch_name in remote_branches) {
                    remote_branch_menu.append (
                        branch_name,
                        GLib.Action.print_detailed_name (
                            FileView.ACTION_PREFIX + FileView.ACTION_CHECKOUT_REMOTE_BRANCH,
                            branch_name
                        )
                    );
                }


            }

            var new_branch_item = new GLib.MenuItem (
                _("New Branch…"),
                GLib.Action.print_detailed_name (
                    MainWindow.ACTION_PREFIX + MainWindow.ACTION_NEW_BRANCH,
                    file.path
                )
            );

            new_branch_item.set_attribute_value (
                "accel",
                Utils.get_accel_for_action (
                    GLib.Action.print_detailed_name (
                        MainWindow.ACTION_PREFIX + MainWindow.ACTION_NEW_BRANCH,
                        ""
                    )
                )
            );

            GLib.Menu bottom_section = new GLib.Menu ();
            bottom_section.append_item (new_branch_item);

            var menu = new GLib.Menu ();
            menu.append_section (null, local_branch_submenu);
            menu.append_section (null, remote_branch_submenu);
            menu.append_section (null, bottom_section);

            var menu_item = new GLib.MenuItem.submenu (_("Branch"), menu);
            return menu_item;
        }

        private void handle_checkout_local_branch_action (GLib.Variant? param) {
            var branch_name = param != null ? param.get_string () : "";
            try {
                monitored_repo.change_local_branch (branch_name);
            } catch (GLib.Error e) {
                warning ("Failed to change branch to %s. %s", branch_name, e.message);
            }
        }

        private void handle_checkout_remote_branch_action (GLib.Variant? param) {
            var branch_name = param != null ? param.get_string () : "";
            if (branch_name == "") {
                return;
            }

            try {
                monitored_repo.checkout_remote_branch (branch_name);
            } catch (GLib.Error e) {
                warning ("Failed to change branch to %s. %s", branch_name, e.message);
            }
        }

        public void update_item_status (FolderItem? start_folder) {
            if (monitored_repo == null) {
                debug ("Ignore non-git folders");
                return;
            }
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

        public bool contains_file (GLib.File descendant) {
            return file.file.get_relative_path (descendant) != null;
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
                    warning ("An error occurred while checking if item '%s' is git-ignored: %s", item.name, e.message);
                }
            });
        }

        public void new_branch (string branch_name) {
            try {
                if (monitored_repo.head_is_branch) {
                    monitored_repo.create_new_branch (branch_name);
                } else {
                    throw new IOError.NOT_FOUND ("Cannot create a new branch when head is detached");
                }
            } catch (Error e) {
                var dialog = new Granite.MessageDialog (
                    _("Error while creating new branch: “%s”").printf (branch_name),
                    e.message,
                    new ThemedIcon ("git"),
                    Gtk.ButtonsType.CLOSE
                ) {
                    badge_icon = new ThemedIcon ("dialog-error")
                };
                dialog.transient_for = (Gtk.Window)(view.get_toplevel ());
                dialog.response.connect (() => {
                    dialog.destroy ();
                });
                dialog.run ();
            }
        }

        public unowned List<string> get_branch_names () {
            return is_git_repo ? monitored_repo.get_local_branches () : null;
        }

        public bool has_local_branch_name (string name) {
            return is_git_repo ? monitored_repo.has_local_branch_name (name) : false;
        }

        public string get_current_branch_name () {
            return is_git_repo ? monitored_repo.branch_name : "";
        }

        public bool is_valid_new_branch_name (string new_name) {
            return is_git_repo ? monitored_repo.is_valid_new_local_branch_name (new_name) : false;
        }

        public void global_search (
            GLib.File start_folder = this.file.file,
            string? term = null,
            bool is_explicit = false
        ) {
            /* For now set all options to the most inclusive (except case).
             * The ability to set these in the dialog (or by parameter) may be added later. */
            string? search_term = null;
            bool use_regex = false;
            bool search_tracked_only = false;
            bool recurse_subfolders = true;
            bool check_is_text = true;
            string[] path_spec = {"*.*"};
            bool modified_only = false;
            bool case_sensitive = false;
            Regex? pattern = null;

            var folder_name = start_folder.get_basename ();
            if (this.file.file.equal (start_folder)) {
                folder_name = name;
            }

            var dialog = new Scratch.Dialogs.GlobalSearchDialog (
                folder_name,
                monitored_repo != null && monitored_repo.git_repo != null
            ) {
                case_sensitive = case_sensitive,
                use_regex = use_regex,
                search_term = term
            };

            dialog.response.connect ((response) => {
                switch (response) {
                    case Gtk.ResponseType.ACCEPT:
                        search_term = dialog.search_term;
                        use_regex = dialog.use_regex;
                        case_sensitive = dialog.case_sensitive;
                        break;

                    default:
                        term = null;
                        break;
                }

                dialog.destroy ();
            });

            dialog.run ();

            if (search_term != null) {
                /* Put search term in search bar to help user locate the position of the matches in each doc */
                var search_variant = new Variant.string (search_term);
                var app = (Gtk.Application)GLib.Application.get_default ();
                var win = (Scratch.MainWindow)(app.get_active_window ());
                win.actions.lookup_action ("action-find").activate (search_variant);

                if (!use_regex) {
                    search_term = Regex.escape_string (search_term);
                }

                try {
                    var flags = RegexCompileFlags.MULTILINE;
                    if (!case_sensitive) {
                        flags |= RegexCompileFlags.CASELESS;
                    }

                    pattern = new Regex (search_term, flags);
                } catch (Error e) {
                    critical ("Error creating regex from '%s': %s", search_term, e.message);
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

            if (monitored_repo != null && !is_explicit) {
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
                                search_folder_children (child, pattern, recurse_subfolders);
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

        public void refresh_diff (ref Gee.HashMap<int, Services.VCStatus> line_status_map, string doc_path) {
            monitored_repo.refresh_diff (doc_path, ref line_status_map);
        }
    }
}
