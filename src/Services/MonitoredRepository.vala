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
        private Ggit.Repository git_repo;
        private FileMonitor? git_monitor = null;
        private FileMonitor? gitignore_monitor = null;
        private string branch_name = "";

        public signal void branch_changed (string name);
        public signal void file_status_changed (string file_path, Ggit.StatusFlags status);

        // Minimum time to elapse before querying git folder again (ms)
        private const uint GIT_UPDATE_RATE_LIMIT = 300;
        private uint update_timer_id = 0;

        private Gee.HashMap<string, Ggit.StatusFlags> file_status_map;
        construct {
            file_status_map = new Gee.HashMap<string, Ggit.StatusFlags> ();
        }

        public MonitoredRepository (Ggit.Repository _git_repo) {
            git_repo = _git_repo;
            var root_path = git_repo.get_location ().get_path ();
            var git_folder = GLib.File.new_for_path (Path.build_filename (root_path, ".git"));

            if (git_folder.query_exists ()) {
                try {
                    git_monitor = git_folder.monitor_directory (GLib.FileMonitorFlags.NONE);
                    git_monitor.changed.connect (update_repo);
                } catch (IOError e) {
                    warning ("An error occured setting up a file monitor on the git folder: %s", e.message);
                }
            }

            // We will only deprioritize git-ignored files whenever the project folder is a git_repo.
            // It doesn't make sense to have a .gitignore file in a project folder that ain't a local git repo.
            var gitignore_file = GLib.File.new_for_path (Path.build_filename (root_path, ".gitignore"));
            if (gitignore_file.query_exists ()) {
                try {
                    gitignore_monitor = gitignore_file.monitor_file (GLib.FileMonitorFlags.NONE);
                    gitignore_monitor.changed.connect (update_repo);
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

        public string get_current_branch () {
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

        public void change_branch (string branch_name) throws Error {
            var branch = git_repo.lookup_branch (branch_name, Ggit.BranchType.LOCAL);
            git_repo.set_head (((Ggit.Ref)branch).get_name ());
        }

        public void update_repo () {
            if (update_timer_id != 0) {
                return;
            }

            update_timer_id = Timeout.add (GIT_UPDATE_RATE_LIMIT, () => {
                try {
                    var head = git_repo.get_head ();
                    if (head.is_branch ()) {
                        var name = ((Ggit.Branch)head).get_name ();
                        if (name != branch_name) {
                            branch_name = name;
                            branch_changed (branch_name);
                        }
                    }
                } catch (Error e) {
                    warning ("An error occured while fetching the current git branch name: %s", e.message);
                }

                var options = new Ggit.StatusOptions (Ggit.StatusOption.INCLUDE_UNTRACKED,
                                                      Ggit.StatusShow.INDEX_AND_WORKDIR,
                                                      null);
                try {
                    git_repo.file_status_foreach (options, check_each_git_status);
                } catch (Error e) {
                    critical ("Error enumerating git status: %s", e.message);
                }

                return Source.REMOVE;
            });
        }

        private int check_each_git_status (string path, Ggit.StatusFlags status) {
            if (file_status_map.has_key (path)) {
                var old_status = file_status_map.@get (path);
                if (status == old_status) {
                    return 0;
                }
            } else {
                file_status_map.@set (path, status);
                if (status == Ggit.StatusFlags.CURRENT) {
                    // On first use, clients should assume files are tracked and current unless notified otherwise
                    // We want to signal an "IGNORED" status so items can be styled accordingly.
                    return 0;
                }
            }

            file_status_changed (path, status);
            return 0;
        }
    }
}