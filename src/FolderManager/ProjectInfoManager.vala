/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2026 elementary, Inc. <https://elementary.io>
 *
 * Authored by: Jeremy Wootten <jeremywootten@gmail.com>
 */

// Using static methods unless we find we require singleton
// We keep a separate list of project infos for future use in e.g. recently closed project list
// and for re-opening projects without recreating info object
public class Scratch.FolderManager.ProjectInfoManager : Object {
    private class ProjectInfo : Object {
        const string PROJECT_INFO_SCHEMA_ID = "io.elementary.code.Projects";
        const string PROJECT_INFO_SCHEMA_PATH_PREFIX = "/io/elementary/code/Projects/";
        public string path {
            owned get {
                return project.path;
            }
        }

        public ProjectFolderItem project { get; construct; }
        private Settings settings;

        public ProjectInfo (ProjectFolderItem project) {
            Object (
                project: project
            );
        }

        construct {
            var settings_path = PROJECT_INFO_SCHEMA_PATH_PREFIX +
                                schema_name_from_path (path) +
                                Path.DIR_SEPARATOR_S;

            settings = new Settings.with_path (
                PROJECT_INFO_SCHEMA_ID,
                settings_path
            );

            settings.bind ("expanded", project, "expanded", DEFAULT);
        }

        //Combine basename and parent folder name and convert to camelcase
        private string schema_name_from_path (string path) {
            var dir = Path.get_basename (Path.get_dirname (path)).normalize ();
            var basename = Path.get_basename (path).normalize ();
            var name = dir.substring (0, 1).up () +
                       dir.substring (1, -1).down () +
                       basename.substring (0, 1).up () +
                       basename.substring (1, -1).down ();

            return name;
        }
    }

    private static Gee.HashMap<string, ProjectInfo>? map = null;
    private static Gee.HashMap<string, ProjectInfo> project_info_map {
        get {
            if (map == null) {
                map = new Gee.HashMap<string, ProjectInfo> ();
            }

            return map;
        }
    }

    //Called when folder created
    public static void get_project_info (ProjectFolderItem project_folder) {
        var info = project_info_map[project_folder.path];
        if (info == null) {
            info = new ProjectInfo (project_folder);
            project_info_map[project_folder.path] = info;
        }
    }
}
