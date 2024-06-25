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
        private SimpleAction change_branch_action;

        public signal void closed ();
        public signal void close_all_except ();

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
            added_icon = new ThemedIcon ("user-available");
            modified_icon = new ThemedIcon ("user-away");
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

                change_branch_action.set_state (monitored_repo.branch_name);
            }
        }

        construct {
            monitored_repo = Scratch.Services.GitManager.get_instance ().add_project (this);
            notify["name"].connect (branch_or_name_changed);
            if (monitored_repo != null) {
                change_branch_action = new SimpleAction.stateful (
                    FileView.ACTION_CHANGE_BRANCH,
                    GLib.VariantType.STRING,
                    ""
                );
                monitored_repo.branch_changed.connect (branch_or_name_changed);
                monitored_repo.ignored_changed.connect ((deprioritize_git_ignored));
                monitored_repo.file_status_change.connect (() => update_item_status (null));
                monitored_repo.update_status_map ();
                monitored_repo.branch_changed ();
                change_branch_action.activate.connect (handle_change_branch_action);

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
            var open_in_terminal_pane_item = new GLib.MenuItem (
                _("Open in Terminal Pane"),
                GLib.Action.print_detailed_name (
                    MainWindow.ACTION_PREFIX + MainWindow.ACTION_OPEN_IN_TERMINAL,
                    file.path
                )
            );

            GLib.FileInfo info = null;

            try {
                info = file.file.query_info (GLib.FileAttribute.STANDARD_CONTENT_TYPE, 0);
            } catch (Error e) {
                warning (e.message);
            }

            var file_type = info.get_attribute_string (GLib.FileAttribute.STANDARD_CONTENT_TYPE) ?? "inode/directory";
            var launch_app_action = Utils.action_from_group (FileView.ACTION_LAUNCH_APP_WITH_FILE_PATH,
                                                             view.actions) as SimpleAction;
            launch_app_action.change_state (new GLib.Variant.string (file_type));

            var open_in_menu = new GLib.Menu ();
            var open_in_top_section = new GLib.Menu ();

            var open_in_app_section = Utils.create_executable_app_items_for_file (file.file, file_type);

            var open_in_extra_section = new GLib.Menu ();
            var open_in_other_menu_item = new GLib.MenuItem (
                _("Other Application…"),
                GLib.Action.print_detailed_name (
                    FileView.ACTION_PREFIX + FileView.ACTION_SHOW_APP_CHOOSER,
                    file.path
                )
            );
            open_in_extra_section.append_item (open_in_other_menu_item);

            open_in_menu.append_section (null, open_in_top_section);
            open_in_menu.append_section (null, open_in_app_section);
            open_in_menu.append_section (null, open_in_extra_section);

            var external_actions_menu_section = new GLib.Menu ();
            external_actions_menu_section.append_item (open_in_terminal_pane_item);
            external_actions_menu_section.append_submenu (_("Open In"), open_in_menu);

            var folder_actions_menu_section = new GLib.Menu ();
            folder_actions_menu_section.append_submenu (_("New"), create_submenu_for_new ());
            if (monitored_repo != null) {
                folder_actions_menu_section.append_submenu (_("Branch"), create_submenu_for_branch ());
            }

            var close_other_folders_action = Utils.action_from_group (FileView.ACTION_CLOSE_OTHER_FOLDERS,
                                                                      view.actions) as SimpleAction;
            close_other_folders_action.set_enabled (view.root.children.size > 1);

            var close_menu_section = new GLib.Menu ();
            close_menu_section.append (
                _("Close Folder"),
                GLib.Action.print_detailed_name (
                    FileView.ACTION_PREFIX + FileView.ACTION_CLOSE_FOLDER,
                    file.path
                )
            );
            close_menu_section.append (
                _("Close Other Folders"),
                GLib.Action.print_detailed_name (
                    FileView.ACTION_PREFIX + FileView.ACTION_CLOSE_OTHER_FOLDERS,
                    file.path
                )
            );

            var n_open = Scratch.Services.DocumentManager.get_instance ().open_for_project (path);
            var open_text = ngettext ("Close %u Open Document",
                                      "Close %u Open Documents",
                                      n_open).printf (n_open);
            var close_open_documents_menu_item = new GLib.MenuItem (
                open_text,
                GLib.Action.print_detailed_name (
                    MainWindow.ACTION_PREFIX + MainWindow.ACTION_CLOSE_PROJECT_DOCS,
                    file.path
                )
            );

            var hide_text = ngettext ("Hide %u Open Document",
                                      "Hide %u Open Documents",
                                      n_open).printf (n_open);
            var hide_documents_menu_item = new GLib.MenuItem (
                hide_text,
                GLib.Action.print_detailed_name (
                    MainWindow.ACTION_PREFIX + MainWindow.ACTION_HIDE_PROJECT_DOCS,
                    file.path
                )
            );

            var n_restorable = Scratch.Services.DocumentManager.get_instance ().restorable_for_project (path);
            var restore_text = ngettext ("Restore %u Hidden Document",
                                         "Restore %u Hidden Documents",
                                         n_restorable).printf (n_restorable);
            var restore_documents_menu_item = new GLib.MenuItem (
                restore_text,
                GLib.Action.print_detailed_name (
                    MainWindow.ACTION_PREFIX + MainWindow.ACTION_RESTORE_PROJECT_DOCS,
                    file.path
                )
            );

            var delete_menu_item = new GLib.MenuItem (
                _("Move to Trash"),
                GLib.Action.print_detailed_name (
                    FileView.ACTION_PREFIX + FileView.ACTION_DELETE,
                    file.path
                )
            );

            var direct_actions_menu_section = new GLib.Menu ();
            if (n_restorable > 0) {
                direct_actions_menu_section.append_item (restore_documents_menu_item);
            }

            if (n_open > 0) {
                direct_actions_menu_section.append_item (hide_documents_menu_item);
                direct_actions_menu_section.append_item (close_open_documents_menu_item);
            }

            direct_actions_menu_section.append_item (delete_menu_item);

            var search_menu_item = new GLib.MenuItem (
                _("Find in Folder…"),
                GLib.Action.print_detailed_name (
                    MainWindow.ACTION_PREFIX + MainWindow.ACTION_FIND_GLOBAL,
                    file.path
                )
            );

            var search_menu_section = new GLib.Menu ();
            search_menu_section.append_item (search_menu_item);

            var menu_model = new GLib.Menu ();
            menu_model.append_section (null, external_actions_menu_section);
            menu_model.append_section (null, folder_actions_menu_section);
            menu_model.append_section (null, close_menu_section);
            menu_model.append_section (null, direct_actions_menu_section);
            menu_model.append_section (null, search_menu_section);

            var menu = new Gtk.Menu.from_model (menu_model);
            menu.insert_action_group (FileView.ACTION_GROUP, view.actions);
            return menu;
        }

        protected GLib.Menu create_submenu_for_branch () {
            // Ensures that action for relevant project is being used
            view.actions.add_action (change_branch_action);

            GLib.Menu top_section = new GLib.Menu ();
            GLib.Menu branch_selection_menu = new GLib.Menu ();

            top_section.append (
                _("New Branch…"),
                GLib.Action.print_detailed_name (
                    MainWindow.ACTION_PREFIX + MainWindow.ACTION_NEW_BRANCH,
                    file.path
                )
            );
            foreach (unowned var branch_name in monitored_repo.get_local_branches ()) {
                branch_selection_menu.append (
                    branch_name,
                    GLib.Action.print_detailed_name (
                        FileView.ACTION_PREFIX + FileView.ACTION_CHANGE_BRANCH,
                        branch_name
                    )
                );
            }

            var menu = new GLib.Menu ();
            menu.append_section (null, top_section);
            menu.append_section (null, branch_selection_menu);
            return menu;
        }

        private void handle_change_branch_action (GLib.Variant? parameter) {
            var branch_name = parameter.get_string ();
            try {
                monitored_repo.change_branch (branch_name);
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
                win.actions.lookup_action ("action_find").activate (search_variant);

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
