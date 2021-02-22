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
    public class MonitoredRepository : Object {
        public Ggit.Repository git_repo { get; set construct; }

        public string current_branch_name { get; private set; }

        public bool is_detached_head {
            get {
                return current_branch_name == "";
            }
        }

        public signal void branch_changed (string new_branch_name);
        public signal void ignored_changed ();
        public signal void file_status_change ();

        private FileMonitor? git_monitor = null;
        private FileMonitor? gitignore_monitor = null;
        private uint update_timer_id = 0;
        private Ggit.StatusOptions status_options;

        // Need to use nullable status in order to pass Flatpak CI.
        private Gee.HashMap<string, Ggit.StatusFlags?> file_status_map;

        public Gee.Set<Gee.Map.Entry<string, Ggit.StatusFlags?>> non_current_entries {
            owned get {
                return file_status_map.entries;
            }
        }

        construct {
            file_status_map = new Gee.HashMap<string, Ggit.StatusFlags?> ();
            status_options = new Ggit.StatusOptions (Ggit.StatusOption.INCLUDE_UNTRACKED | Ggit.StatusOption.RECURSE_UNTRACKED_DIRS,
                                                     Ggit.StatusShow.INDEX_AND_WORKDIR,
                                                     null);
        }

        public MonitoredRepository (Ggit.Repository _git_repo) {
            git_repo = _git_repo;
            var git_folder = git_repo.get_location ();

            try {
                git_monitor = git_folder.monitor_directory (GLib.FileMonitorFlags.NONE);
                git_monitor.changed.connect (update);
            } catch (IOError e) {
                warning ("An error occured setting up a file monitor on the git folder: %s", e.message);
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
                    warning ("An error occured setting up a file monitor on the gitignore file: %s", e.message);
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

        public string[] get_local_branches () {
            string[] branches = {};
            try {
                var branch_enumerator = git_repo.enumerate_branches (Ggit.BranchType.LOCAL);
                foreach (Ggit.Ref branch_ref in branch_enumerator) {
                    if (branch_ref is Ggit.Branch) {
                        branches += ((Ggit.Branch)branch_ref).get_name ();
                    }
                }
            } catch (Error e) {
                warning ("Could not enumerate branches %s", e.message);
            }

            return branches;
        }

        public void change_branch (string new_branch_name) throws Error {
            var branch = git_repo.lookup_branch (new_branch_name, Ggit.BranchType.LOCAL);
            git_repo.set_head (((Ggit.Ref)branch).get_name ());
            //Change of branch will be picked up by the monitor of the .git folder and "branch-changed" signal emitted
        }

        public void create_new_branch (string name) throws Error {
            Ggit.Object git_object = git_repo.get_head ().lookup ();
            var new_branch = git_repo.create_branch (name, git_object, Ggit.CreateFlags.NONE);
            git_repo.set_head (((Ggit.Ref)new_branch).get_name ());
        }

        public void commit_all_to_head () throws Ggit.Error, Error {
            //TODO Provide means to set various commit information
            //TODO Warn of untracked files - at present these will be committed and tracked without warning
            //Use automatic commit message for now
            var message = ("Commit made at %s").printf (new DateTime.now_local ().to_string ());

            Ggit.Ref? head_ref = git_repo.get_head ();
            Ggit.Object? head_object = head_ref.lookup ();
            if (head_object is Ggit.Commit) {
                //Get default commit info from config


                // Stage all modified files
                var idx = git_repo.get_index ();
                List<File> paths_to_stage = null;
                file_status_map.entries.@foreach ((entry) => {
                    if (entry.@value != Ggit.StatusFlags.CURRENT) {
                        paths_to_stage.prepend (git_repo.workdir.get_child (entry.key));
                    }

                    return true;
                });

                foreach (File file in paths_to_stage) {
                    //TODO Check the file exists?
                    idx.add_file (file);
                }

                var tree_oid = idx.write_tree ();
                var git_tree = git_repo.lookup_tree (tree_oid);
                var signature = get_signature ();
                //For now assume user is both author and committer
                var commit_oid = git_repo.create_commit (
                    "HEAD",
                    signature,
                    signature,
                    null,
                    message,
                    git_tree,
                    {(Ggit.Commit)head_object}
                );

                var commit = git_repo.lookup_commit (commit_oid);
                var options = new Ggit.CheckoutOptions ();
                git_repo.checkout_tree (commit, options);
            } else {
                throw new Ggit.Error.GIT_ERROR ("Head is not a commit");
            }
        }

        private bool do_update = false;
        public void update () {
            if (update_timer_id == 0) {
                update_timer_id = Timeout.add (150, () => {
                    if (do_update) {
                        try {
                            var head = git_repo.get_head ();
                            if (head.is_branch ()) {
                                unowned string name = ((Ggit.Branch)head).get_name ();
                                if (name != current_branch_name) {
                                    current_branch_name = name;
                                    branch_changed (name);
                                }
                            }
                        } catch (Error e) {
                            warning ("Could not get current branch name - %s", e.message);
                        }

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
            } else {
                do_update = false;
            }
        }

        public bool path_is_ignored (string path) throws Error {
            return git_repo.path_is_ignored (path);
        }

        public bool has_uncommitted_changes () {
            return non_current_entries.size > 0;
        }

        private Ggit.Signature? get_signature () throws Error {
            var config = (new Ggit.Config.from_file (Ggit.Config.find_global ())).snapshot ();
            return new Ggit.Signature.now (
                config.get_string ("user.name"),
                config.get_string ("user.email")
            );
        }
    }
}
