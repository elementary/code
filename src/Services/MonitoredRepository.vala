// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2020 elementary LLC. (https://elementary.io),
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
 * Authored by: Jeremy Wootten <jeremy@elementaryos.org>
 */

namespace Scratch.Services {
    public enum VCStatus {
        NONE,
        ADDED,
        CHANGED,
        REMOVED, // Cannot show in normal SourceView but for future use in Diff view?
        REPLACES_DELETED, // For unmodified lines that replace deleted lines
        OTHER;
    }

    public class MonitoredRepository : Object {
        public const string ORIGIN_PREFIX = "origin/";
        public Ggit.Repository git_repo { get; set construct; }
        public string branch_name {
            get {
                return _branch_name;
            }

            set {
                if (_branch_name != value) {
                    _branch_name = value;
                    branch_changed ();
                }
            }
        }

        public bool head_is_branch {
            get {
                try {
                    return git_repo.get_head ().is_branch ();
                } catch (Error e) {
                    return false;
                }
            }
        }

        public signal void branch_changed ();
        public signal void ignored_changed ();
        public signal void file_status_change ();
        public signal void file_content_changed ();

        private FileMonitor? git_monitor = null;
        private FileMonitor? gitignore_monitor = null;
        private string _branch_name = "";
        private uint update_timer_id = 0;
        private Ggit.StatusOptions status_options;

        // Need to use nullable status in order to pass Flatpak CI.
        private Gee.HashMap<string, Ggit.StatusFlags?> file_status_map;

        private Gee.ArrayList<Ggit.Ref> all_branch_refs;
        private Gee.HashSet<Ggit.Ref> recently_used_branches;

        public Gee.Set<Gee.Map.Entry<string, Ggit.StatusFlags?>> non_current_entries {
            owned get {
                return file_status_map.entries;
            }
        }

        public bool has_uncommitted {
            get {
                return file_status_map.values.any_match ((status) => {
                    switch (status) {
                        case Ggit.StatusFlags.INDEX_NEW:
                        case Ggit.StatusFlags.INDEX_MODIFIED:
                        case Ggit.StatusFlags.INDEX_RENAMED:
                        case Ggit.StatusFlags.WORKING_TREE_MODIFIED:
                            return true;

                        default:
                            return false;
                    }
                });
            }
        }

        construct {
            file_status_map = new Gee.HashMap<string, Ggit.StatusFlags?> ();
            status_options = new Ggit.StatusOptions (
                Ggit.StatusOption.INCLUDE_UNTRACKED | Ggit.StatusOption.RECURSE_UNTRACKED_DIRS,
                Ggit.StatusShow.INDEX_AND_WORKDIR,
                null
            );

            all_branch_refs = new Gee.ArrayList<Ggit.Ref> ();
            recently_used_branches = new Gee.HashSet<Ggit.Ref> (
                (v) => {
                    return v.get_name ().hash ();
                },

                (va, vb) => {
                    return va.get_name () == vb.get_name ();
                }
            );
        }

        public MonitoredRepository (Ggit.Repository _git_repo) {
            Object (
                git_repo: _git_repo
            );

            var git_folder = git_repo.get_location ();

            try {
                git_monitor = git_folder.monitor_directory (GLib.FileMonitorFlags.NONE);
                git_monitor.changed.connect (() => {
                    update_status_map ();
                });
            } catch (IOError e) {
                warning ("An error occurred setting up a file monitor on the git folder: %s", e.message);
            }

            // We will only deprioritize git-ignored files whenever the project folder is a git_repo.
            // It doesn't make sense to have a .gitignore file in a project folder that ain't a local git repo.
            var workdir = git_repo.workdir;
            var gitignore_file = workdir.get_child (".gitignore");
            if (gitignore_file.query_exists ()) {
                try {
                    gitignore_monitor = gitignore_file.monitor_file (GLib.FileMonitorFlags.NONE);
                    gitignore_monitor.changed.connect (() => {ignored_changed ();});
                } catch (IOError e) {
                    warning ("An error occurred setting up a file monitor on the gitignore file: %s", e.message);
                }
            }
        }

        ~MonitoredRepository () {
            if (git_monitor != null) {
                git_monitor.cancel ();
            }

            if (gitignore_monitor != null) {
                gitignore_monitor.cancel ();
            }
        }

        public unowned string get_current_branch () {
            try {
                var head = git_repo.get_head ();
                if (head.is_branch ()) {
                    return ((Ggit.Branch)head).get_name ();
                }
            } catch (Error e) {
                warning ("Could not get current branch name - %s", e.message);
            }

            return "";
        }

        public Gee.ArrayList<Ggit.Ref> get_all_branch_refs () {
            all_branch_refs = new Gee.ArrayList<Ggit.Ref> ();
            try {
                var branch_enumerator = git_repo.enumerate_branches (Ggit.BranchType.LOCAL);
                foreach (Ggit.Ref branch_ref in branch_enumerator) {
                    all_branch_refs.add (branch_ref);
                }

                branch_enumerator = git_repo.enumerate_branches (Ggit.BranchType.REMOTE);
                foreach (Ggit.Ref branch_ref in branch_enumerator) {
                    var remote_name = branch_ref.get_shorthand ();
                    if (!remote_name.has_suffix ("HEAD") &&
                        !has_local_branch_name (remote_name.substring (ORIGIN_PREFIX.length))) {

                        all_branch_refs.add (branch_ref);
                    }
                }
            } catch (Error e) {
                warning ("Could not enumerate local branches %s", e.message);
            }

            return all_branch_refs;
        }

        public bool is_recent_ref (Ggit.Ref bref) {
            return bref.is_branch () && recently_used_branches.contains (bref);
        }

        public bool has_local_branch_name (string name) {
            try {
                git_repo.lookup_branch (name, Ggit.BranchType.LOCAL);
                return true;
            } catch (Error e) {}

            return false;
        }

        public bool has_remote_branch_name (string name) {
            try {
                git_repo.lookup_branch (name, Ggit.BranchType.REMOTE);
                return true;
            } catch (Error e) {}

            return false;
        }

        public bool is_valid_new_local_branch_name (string new_name) {
            if (!Ggit.Ref.is_valid_name ("refs/heads/" + new_name) ||
                has_local_branch_name (new_name) ) {
                return false;
            }

            return true;
        }

        public bool change_local_branch (string new_branch_name)
        requires (!new_branch_name.has_prefix (ORIGIN_PREFIX)) {

            Ggit.Branch branch;
            try {
                branch = git_repo.lookup_branch (new_branch_name, Ggit.BranchType.LOCAL);
            } catch (Error e) {
                warning ("failed to lookup branch %s", new_branch_name);
                return false;
            }

            return checkout_branch (branch);
        }

        public bool checkout_remote_branch (string target_shorthand)
        requires (target_shorthand.has_prefix (ORIGIN_PREFIX)) {

            Ggit.Ref? branch_ref = null;
            //Assume list is up to date as this is called from context menu
            foreach (var bref in all_branch_refs) {
                // Can assume that all brefs in this list have a non-null shorthand
                if (bref.get_shorthand () == target_shorthand) {
                    branch_ref = bref;
                    break;
                }
            }

            if (branch_ref == null) {
                var dialog = new Granite.MessageDialog.with_image_from_icon_name (
                    _("Remote Branch '%s' not found").printf (target_shorthand),
                    _("The requested branch was not found in any remote linked to this repository"),
                    "dialog-warning"
                ) {
                    modal = true
                };

                dialog.response.connect (() => {dialog.destroy ();});
                dialog.present ();
                return false;
            }

            Ggit.Object commit;
            try {
                commit = branch_ref.lookup ();
            } catch (Error e) {
                warning ("Failed to lookup commit. %s", e.message);
                return false;
            }

            var local_name = target_shorthand.substring (ORIGIN_PREFIX.length);
            Ggit.Branch local_branch;
            try {
                local_branch = git_repo.create_branch (local_name, commit, NONE);
            } catch (Error e) {
                warning ("Failed to create branch. %s", e.message);
                return false;
            }

            if (checkout_branch (local_branch)) {
                try {
                    local_branch.set_upstream (target_shorthand);
                    return true;
                } catch (Error e) {
                    warning ("Failed to set upstream. %s", e.message);
                }
            }

            return false;
        }

        private bool checkout_branch (Ggit.Branch new_head_branch, bool confirm = true) {
            var new_branch_name = ((Ggit.Ref) new_head_branch).get_name ();
            if (new_branch_name == null) {
                return false;
            }

            if (confirm && has_uncommitted) {
                var parent = ((Gtk.Application)(GLib.Application.get_default ())).get_active_window ();
                // var new_branch_name = new_head_branch.get_name ();
                string project_diff;
                try {
                    project_diff = get_project_diff ();
                } catch (Error e) {
                    warning ("Failed to get project diff. %s", e.message);
                    return false;
                }

                var dialog = new Scratch.Dialogs.OverwriteUncommittedConfirmationDialog (
                    parent,
                    new_branch_name,
                    project_diff
                );
                dialog.response.connect ((res) => {
                    dialog.destroy ();
                    if (res == Gtk.ResponseType.ACCEPT) {
                        checkout_branch (new_head_branch, false);
                    }
                });

                dialog.present ();
                // confirm_checkout_branch (new_head_branch);
                return false;
            }

            try {
                git_repo.set_head (new_branch_name);
                var options = new Ggit.CheckoutOptions () {
                    //Ensure documents match checked out branch (deal with potential conflicts/losses beforehand)
                    strategy = Ggit.CheckoutStrategy.FORCE
                };

                git_repo.checkout_head (options);
                branch_name = new_branch_name;
                //TODO limit recent to ? branches and persist
                recently_used_branches.add ((Ggit.Ref)new_head_branch);
            } catch (Error e) {
                var dialog = new Granite.MessageDialog.with_image_from_icon_name (
                    _("An error occurred while checking out the requested branch"),
                    e.message,
                    "dialog-warning"
                );

                dialog.response.connect (dialog.destroy);
                dialog.present ();
                return false;
            }

            return true;
        }

        public bool create_new_branch (string name) {
            try {
                Ggit.Object git_object = git_repo.get_head ().lookup ();
                var new_branch = git_repo.create_branch (name, git_object, Ggit.CreateFlags.NONE);
                git_repo.set_head (((Ggit.Ref)new_branch).get_name ());
            } catch (Error e) {
                warning ("Failed to create new branch. %s", e.message);
            }

            return true;
        }

        private bool do_update = false;
        public void update_status_map () {
            if (update_timer_id == 0) {
                update_timer_id = Timeout.add (150, () => {
                    if (do_update) {
                        var target_name = ""; //Do we need a user visible indication if no target?
                        try {
                            var head = git_repo.get_head ();
                            if (head.is_branch ()) {
                                target_name = ((Ggit.Branch)head).get_name ();
                            } else {
                                var target = head.get_target ();
                                if (target != null) {
                                    ///TRANSLATORS "%.8s" is a placeholder for the first 8 characters of a commit reference
                                    target_name = _("%.8s (detached)").printf (target.to_string ());
                                    // Do we need to expose a warning regarding the detached-head state like Git does?
                                }
                            }
                        } catch (Error e) {
                            warning ("An error occurred while fetching the current git branch name: %s", e.message);
                        }

                        branch_name = target_name;

                        // SourceList shows files in working dir so only want status for those for now.
                        // No callback generated for current files.
                        // TODO Distinguish new untracked files from new tracked files
                        try {
                            file_status_map.clear ();

                            git_repo.file_status_foreach (status_options, (path, status) => {
                                file_status_map.@set (path, status);
                                return 0;
                            });

                            file_status_change ();
                        } catch (Error e) {
                            critical ("Error enumerating git status: %s", e.message);
                        }

                        do_update = false;
                        update_timer_id = 0;
                        return Source.REMOVE;
                    } else {
                        do_update = true;
                        return Source.CONTINUE;
                    }
                });

                file_content_changed (); //If displayed in SourceView signal update of gutter
            } else {
                do_update = false;
            }
        }

        public bool path_is_ignored (string path) throws Error {
            return git_repo.path_is_ignored (path);
        }

        public string get_project_diff () throws GLib.Error {
            var sb = new StringBuilder ("");
            var repo_diff_list = new Ggit.Diff.index_to_workdir (git_repo, null, null);
            repo_diff_list.print (Ggit.DiffFormatType.PATCH, (delta, hunk, line) => {
                unowned var file_diff = delta.get_old_file ();
                if (file_diff == null) {
                    return 0;
                }

                if (line != null) {
                    var delta_type = line.get_origin ();
                    string prefix = "?";
                    switch (delta_type) {
                        case Ggit.DiffLineType.ADDITION:
                            prefix = "+";
                            break;
                        case Ggit.DiffLineType.DELETION:
                            prefix = "-";
                            break;
                        case Ggit.DiffLineType.CONTEXT:
                            prefix = " ";
                            break;
                        default:
                            break;
                    }
                    //TODO Add color according to linetype
                    sb.append (prefix + line.get_text ());
                }
                return 0;
            });

            return sb.str;
        }


        private bool refreshing = false;
        public void refresh_diff (string file_path, ref Gee.HashMap<int, VCStatus> line_status_map) {
            if (refreshing) {
                return;
            } else {
                refreshing = true;
            }

            // Need to have our own map since the callback closures cannot capture
            // a reference to the ref parameter. Vala bug??
            var status_map = line_status_map;

            int prev_deletions = 0;
            int prev_additions = 0;
            try {
                var repo_diff_list = new Ggit.Diff.index_to_workdir (git_repo, null, null);
                repo_diff_list.foreach (null, null, null,
                    (delta, hunk, line) => {
                        unowned var file_diff = delta.get_old_file ();
                        if (file_diff == null) {
                            return 0;
                        }

                        unowned var diff_file_path = file_diff.get_path ();
                        // Only process the diff if its for the file in focus.
                        if (diff_file_path == null ||
                            !(file_path.has_suffix (diff_file_path))) {

                            return 0;
                        }

                        process_diff_line (line.get_origin (),
                                           line.get_new_lineno (),
                                           line.get_old_lineno (),
                                           ref status_map,
                                           ref prev_deletions,
                                           ref prev_additions
                        );

                        return 0;
                    }
                );
            } catch (Error e) {
                critical ("Error getting diff list %s", e.message);
            } finally {
                refreshing = false;
            }

            line_status_map = status_map;
        }

        private void process_diff_line (Ggit.DiffLineType line_type, int new_line_no, int old_line_no,
                                        ref Gee.HashMap<int, VCStatus> line_status_map,
                                        ref int prev_deletions,
                                        ref int prev_additions) {

            if (line_type == Ggit.DiffLineType.CONTEXT) {
                if (prev_deletions > 0) {
                    line_status_map.set (new_line_no, VCStatus.REPLACES_DELETED);
                }

                prev_deletions = 0;
                prev_additions = 0;
                return;
            }

            if (new_line_no < 0) {
                prev_deletions++;
                prev_additions = 0;
                return;
            } else {
                if (line_type == Ggit.DiffLineType.ADDITION) { //Line added
                    prev_additions++;
                    if (prev_deletions >= prev_additions) {
                        line_status_map.set (new_line_no, VCStatus.CHANGED);
                        prev_deletions--;
                    } else {
                        line_status_map.set (new_line_no, VCStatus.ADDED);
                        prev_deletions = 0;
                    }
                } else {
                    line_status_map.set (new_line_no, VCStatus.OTHER);
                }
            }
        }
    }
}
