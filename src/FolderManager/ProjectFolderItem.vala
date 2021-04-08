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
        // Minimum time to elapse before querying git folder again (ms)
        private const uint GIT_UPDATE_RATE_LIMIT = 300;

        public signal void closed ();
        public signal void close_all_except ();

        // Static source IDs for each instance of a top level folder, ensures we don't check for git updates too much
        private static Gee.HashMap<string, uint> git_update_timer_ids;
        private string top_level_path;
        private Ggit.Repository? git_repo = null;
        private GLib.FileMonitor git_monitor;
        private GLib.FileMonitor gitignore_monitor;

        private static Icon added_icon;
        private static Icon modified_icon;

        public ProjectFolderItem (File file, FileView view) requires (file.is_valid_directory) {
            Object (file: file, view: view);
        }

        ~ProjectFolderItem () {
            if (git_monitor != null) {
                git_monitor.cancel ();
            }

            if (gitignore_monitor != null) {
                gitignore_monitor.cancel ();
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

                // We will only deprioritize git-ignored files whenever the project folder is a git_repo.
                // It doesn't make sense to have a .gitignore file in a project folder that ain't a local git repo.
                var gitignore_file = GLib.File.new_for_path (Path.build_filename (top_level_path, ".gitignore"));
                if (gitignore_file.query_exists ()) {
                    try {
                        gitignore_monitor = gitignore_file.monitor_file (GLib.FileMonitorFlags.NONE);
                        gitignore_monitor.changed.connect (() => update_git_deprioritized_files ());
                    } catch (IOError e) {
                        warning ("An error occured setting up a file monitor on the gitignore file: %s", e.message);
                    }
                }
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

            try {
                if (git_repo != null && git_repo.get_head ().is_branch ()) {
                    var change_branch_item = new ChangeBranchMenu (git_repo);
                    if (change_branch_item != null) {
                        menu.append (change_branch_item);
                    }
                }
            } catch (Error e) {
                critical (e.message);
            }

            menu.append (new Gtk.SeparatorMenuItem ());
            menu.append (close_item);
            menu.append (close_all_except_item);
            menu.append (delete_item);

            var search_item = new Gtk.MenuItem.with_label (_("Search Project"));
            search_item.activate.connect (() => { global_search (); });

            menu.append (new Gtk.SeparatorMenuItem ());
            menu.append (search_item);

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
            var options = new Ggit.StatusOptions (
                Ggit.StatusOption.INCLUDE_UNTRACKED, Ggit.StatusShow.INDEX_AND_WORKDIR, null
            );
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
                    modified_item.tooltip = _("%s, Modified").printf (modified_item.name);
                }
            } else if (Ggit.StatusFlags.WORKING_TREE_NEW in status || Ggit.StatusFlags.INDEX_NEW in status) {
                var new_items = new Gee.ArrayList<Item> ();
                find_items (this, path, ref new_items);
                foreach (var new_item in new_items) {
                    // Only show an added indicator on items that aren't already showing modified state
                    if (new_item.activatable == null) {
                        new_item.activatable = added_icon;
                        new_item.tooltip = _("%s, New").printf (new_item.name);
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
                item.activatable = null;

                if (item is Granite.Widgets.SourceList.ExpandableItem) {
                    reset_all_children (item);
                }
            }

            deprioritize_gitignored_files (toplevel_item);
        }

        private void update_git_deprioritized_files () {
            deprioritize_gitignored_files (this);
        }

        private void deprioritize_gitignored_files (Item top_level_item) {
            foreach (var child in top_level_item.children) {
                if (child == null || !(child is Item)) {
                    continue;
                }

                var item = child as Item;

                if (is_file_gitignored (item)) {
                    /* 75% opacity and italic */
                    item.markup = Markup.printf_escaped ("<span fgalpha='75&#37;'><i>%s</i></span>", item.name);
                }

                if (item is Granite.Widgets.SourceList.ExpandableItem) {
                    deprioritize_gitignored_files (item);
                }
            }
        }

        public bool is_file_gitignored (Item item) {
            try {
                if (git_repo.path_is_ignored (item.path)) {
                    return true;
                }
            } catch (Error e) {
                warning ("An error occured while checking if item '%s' is git-ignored: %s", item.name, e.message);
            }

            return false;
        }

        public void global_search (GLib.File? start_folder = file.file) {
            string? term = null;
            bool term_is_literal = true;
            bool search_tracked_only = true;
            bool recurse_subfolders = true;
            bool check_is_text = false;
            string[] path_spec = {"*.*"};
            bool modified_only = true;
            bool case_sensitive = true;
            Regex? pattern = null;

            var dialog = new Scratch.Dialogs.GlobalSearchDialog (
                null, start_folder.get_basename (), git_repo != null
            );

            dialog.response.connect ((response) => {
                switch (response) {
                    case Gtk.ResponseType.ACCEPT:
                        term = dialog.search_term;
                        term_is_literal = dialog.use_literal;
                        search_tracked_only = dialog.tracked_only;
                        recurse_subfolders = dialog.recurse;
                        path_spec = dialog.path_spec;
                        modified_only = dialog.modified_only;
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

                if (term_is_literal) {
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

            check_is_text = path_spec[0] == "*.*" ; //Assume otherwise path spec will exclude non-text

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

            if (git_repo != null) {
                try {
                    git_repo.file_status_foreach (status_options, (rel_path, status) => {
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
            public Ggit.Repository git_repo { get; construct; }

            public ChangeBranchMenu (Ggit.Repository git_repo) {
                Object (git_repo: git_repo);
            }

            construct {
                Ggit.Branch? cur_branch;
                Ggit.BranchEnumerator? branches;

                try {
                    cur_branch = (Ggit.Branch?)(git_repo.get_head ());
                    branches = git_repo.enumerate_branches (Ggit.BranchType.LOCAL);
                } catch (GLib.Error e) {
                    critical ("Failed to create change branch menu. %s", e.message);
                    sensitive = false;
                }

                if (branches == null || cur_branch == null) {
                    sensitive = false;
                }

                var change_branch_menu = new Gtk.Menu ();

                foreach (var ref_branch in branches) {
                    var branch = ref_branch as Ggit.Branch;
                    string? branch_name = null;
                    try {
                        branch_name = branch.get_name ();
                        if (branch_name != null) {
                            var ref_name = ref_branch.get_name ();
                            if (ref_name != null) {
                                var branch_item = new Gtk.CheckMenuItem.with_label (branch_name);
                                branch_item.draw_as_radio = true;

                                if (branch_name == cur_branch.get_name ()) {
                                    branch_item.active = true;
                                }

                                change_branch_menu.add (branch_item);

                                branch_item.toggled.connect (() => {
                                    try {
                                        git_repo.set_head (ref_name);
                                    } catch (GLib.Error e) {
                                        warning ("Failed to change branch to %s.  %s", name, e.message);
                                    }
                                });
                            }
                        }
                    } catch (GLib.Error e) {
                        warning ("Failed to create menuitem for branch %s. %s", branch_name ?? "unknown", e.message);
                    }
                }

                label = _("Branch");
                submenu = change_branch_menu;
            }
        }
    }
}
