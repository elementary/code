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
    public class GitManager : Object {
        public ListStore project_liststore { get; private set; }
        public string active_project_path { get; set;}

        static Gee.HashMap<string, MonitoredRepository> project_gitrepo_map;
        static GitManager? instance;

        static construct {
            Ggit.init ();
            instance = null;
            project_gitrepo_map = new Gee.HashMap<string, MonitoredRepository> ();
        }

        public static MonitoredRepository? get_monitored_repository (string root_path) {
            return project_gitrepo_map[root_path];
        }

        public static GitManager get_instance () {
            if (instance == null) {
                instance = new GitManager ();
            }

            return instance;
        }

        construct {
            // Used to populate the ChooseProject popover in sorted order
            project_liststore = new ListStore (typeof (FolderManager.ProjectFolderItem));
            settings.bind ("active-project-path", this, "active-project-path", DEFAULT);
        }

        public MonitoredRepository? add_project (FolderManager.ProjectFolderItem root_folder) {
            var root_path = root_folder.file.file.get_path ();
            MonitoredRepository? monitored_repo = null;
            try {
                var git_repo = Ggit.Repository.open (root_folder.file.file);
                if (!project_gitrepo_map.has_key (root_path)) {
                    monitored_repo = new MonitoredRepository (git_repo);
                    project_gitrepo_map.@set (root_path, monitored_repo);
                    return project_gitrepo_map.@get (root_path);
                }
            } catch (Error e) {
                debug (
                    "Error opening git repo for %s, means this probably isn't one: %s",
                    root_path,
                    e.message
                );
            } finally {
                project_liststore.insert_sorted (
                  root_folder,
                  (CompareDataFunc<GLib.Object>) project_sort_func
                );
            }

            //Ensure active_project_path always set
            active_project_path = root_path;
            return project_gitrepo_map.@get (root_path);
        }

        [CCode (instance_pos = -1)]
        private int project_sort_func (FolderManager.ProjectFolderItem a, FolderManager.ProjectFolderItem b) {
            GLib.File file_a = a.file.file;
            GLib.File file_b = b.file.file;
            return Path.get_basename (file_a.get_path ()).collate (Path.get_basename (file_b.get_path ()));
        }

        public void remove_project (FolderManager.ProjectFolderItem root_folder) {
            var root_path = root_folder.file.file.get_path ();

            uint position;
            if (project_liststore.find (root_folder, out position)) {
                project_liststore.remove (position);
            } else {
                critical ("Can't remove: %s", root_path);
            }

            if (project_gitrepo_map.has_key (root_path)) {
                project_gitrepo_map.unset (root_path);
            }
        }

        // @project_path is the root of a project or null
        public string get_default_build_dir (string? project_path) {
            string build_path = project_path != null ? project_path : active_project_path;
            var default_build_dir = Scratch.settings.get_string ("default-build-directory");
            var build_file = GLib.File.new_for_path (Path.build_filename (build_path, default_build_dir));
            if (build_file.query_exists ()) {
                build_path = build_file.get_path ();
            } else {
                warning ("build path not found %s", build_file.get_path ());
            }

            return build_path;
        }
    }
}
