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
        static Gee.HashMap<string, MonitoredRepository> project_gitrepo_map;
        static GitManager? instance;

        static construct {
            Ggit.init ();
            instance = null;
            project_gitrepo_map = new Gee.HashMap<string, MonitoredRepository> ();
        }

        public static GitManager get_instance () {
            if (instance == null) {
                instance = new GitManager ();
            }

            return instance;
        }

        private GitManager () {}

        public MonitoredRepository? add_project (GLib.File root_folder) {
            var root_path = root_folder.get_path ();
            try {
                var git_repo = Ggit.Repository.open (root_folder);
                if (project_gitrepo_map.has_key (root_path)) {
                    return project_gitrepo_map.@get (root_path);
                }

                var monitored_repo = new MonitoredRepository (git_repo);

                project_gitrepo_map.@set (root_path, monitored_repo);
                return project_gitrepo_map.@get (root_path);
            } catch (Error e) {
                warning ("Error opening git repo for %s, means this probably isn't one: %s", root_path, e.message);
                return null;
            }
        }

        public void remove_project (GLib.File root_folder) {
            var root_path = root_folder.get_path ();
            if (project_gitrepo_map.has_key (root_path)) {
                project_gitrepo_map.unset (root_path);
            }
        }
    }
}