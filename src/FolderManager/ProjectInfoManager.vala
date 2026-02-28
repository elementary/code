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
    public class ProjectInfo : Object {
        const string PROJECT_INFO_SCHEMA_ID = "io.elementary.code.Projects";
        const string PROJECT_INFO_SCHEMA_PATH_PREFIX = "/io/elementary/code/Projects/";
        public string path {
            owned get {
                return project.path;
            }
        }

        public ProjectFolderItem project { get; construct; }
        private Settings project_settings;

        public ProjectInfo (ProjectFolderItem project) {
            Object (
                project: project
            );
        }

        construct {
            var settings_path = PROJECT_INFO_SCHEMA_PATH_PREFIX +
                                schema_name_from_path (path) +
                                Path.DIR_SEPARATOR_S;

            project_settings = new Settings.with_path (
                PROJECT_INFO_SCHEMA_ID,
                settings_path
            );

            settings.bind ("expanded", project, "expanded", DEFAULT);
        }

        public void save_doc_info () {
            var doc_manager = Scratch.Services.DocumentManager.get_instance ();
            var vb = new VariantBuilder (new VariantType ("a(si)"));
            // This will erase any existing open-files setting if history is off
            if (privacy_settings.get_boolean ("remember-recent-files")) {
                //NOTE `foreach (var x in y) {}` syntax does not work here!
                doc_manager.get_open_paths (path).@foreach ((path) => {
                    //Need to save cursor position in Document Manager
                    //Default to 0 for now
                    //Assume path exists for now (do we need check - it might disappear later anyway)
                    vb.add ("(si)", path, 0);
                    return true;
                });

                doc_manager.take_restorable_paths (path).@foreach ((path) => {
                    //Need to save cursor position in Document Manager
                    //Default to 0 for now
                    //Assume path exists for now (do we need check - it might disappear later anyway)
                    vb.add ("(si)", path, 0);
                    return true;
                });
            }

            project_settings.set_value ("open-files", vb.end ());
        }

        //Combine basename and parent folder name and convert to camelcase
        public delegate void OpenFileCallback (string uri, uint pos);
        public void get_open_file_infos (OpenFileCallback cb) {
            if (privacy_settings.get_boolean ("remember-recent-files")) {
                var doc_infos = project_settings.get_value ("open-files");
                var doc_info_iter = new VariantIter (doc_infos);
                //TODO Restore focused doc per project
                string uri;
                int pos;
                while (doc_info_iter.next ("(si)", out uri, out pos)) {
                    cb (uri, pos);
                }
            }
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
    public static ProjectInfo get_project_info (ProjectFolderItem project_folder) {
        //TODO Should we only store info for code (git) projects?
        var info = project_info_map[project_folder.path];
        if (info == null) {
            info = new ProjectInfo (project_folder);
            project_info_map[project_folder.path] = info;
        }

        return info;
    }

    //Called when a project closed
    //We do not bind open doc info so update settings here
    //TODO closed doc info too?
    public static void prepare_close_project (ProjectFolderItem project_folder) {
        var info = project_info_map[project_folder.path];
        if (info != null) {
            info.save_doc_info ();
        }

        //We keep info in case project re-opened
    }

    public static void prepare_to_quit () {
        foreach (var info in project_info_map.values) {
            info.save_doc_info ();
        }

        //Assume destructor will take care of map when app closes?
    }
}
