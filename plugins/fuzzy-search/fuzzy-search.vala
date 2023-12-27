/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2023 elementary, Inc. <https://elementary.io>
 *
 * Authored by: Marvin Ahlgrimm
 */

public class Scratch.Services.SearchProject {
    public string root_path { get; private set; }
    public Gee.ArrayList<string> relative_file_paths { get; private set; }
    private MonitoredRepository? monitored_repo;

    public SearchProject (string root, MonitoredRepository? repo) {
        root_path = root;
        monitored_repo = repo;
        relative_file_paths = new Gee.ArrayList<string> ();
    }

    public async void parse_async (string path) {
        new Thread<void> (null, () => {
            parse_async_internal.begin (path, (obj, res) => {
                parse_async_internal.end (res);
            });

            Idle.add (parse_async.callback);
        });

        yield;
    }

    private async void parse_async_internal (string path) {
        try {
            // Ignore dot-prefixed directories
            string path_basename = Path.get_basename (path);
            if (FileUtils.test (path, GLib.FileTest.IS_DIR) && path_basename.has_prefix (".")) {
                return;
            }

            try {
                // Don't use paths which are ignored from .gitignore
                if (monitored_repo != null && monitored_repo.path_is_ignored (path)) {
                    return;
                }
            } catch (Error e) {
                warning ("An error occurred while checking if item '%s' is git-ignored: %s", path, e.message);
            }

            var dir = Dir.open (path);
            var name = dir.read_name ();

            while (name != null) {
                var new_search_path = "";
                if (path.has_suffix (GLib.Path.DIR_SEPARATOR_S)) {
                    new_search_path = path.substring (0, path.length - 1);
                } else {
                    new_search_path = path;
                }

                parse_async_internal.begin (new_search_path + GLib.Path.DIR_SEPARATOR_S + name, (obj, res) => {
                    parse_async_internal.end (res);
                });

                name = dir.read_name ();
            }
        } catch (FileError e) {
            // This adds branch is reached when a non-directory was reached, i.e. is a file
            // If a file was reached, add it's relative path (starting after the project root path)
            // to the list.

            // Relative paths are used because the longer the path is the less accurate are the results
            if (check_if_valid_path_to_add (path)) {
                var subpath = path.replace (root_path, "");
                relative_file_paths.add (subpath.substring (1, subpath.length - 1));
            }
        }
    }

    private bool check_if_valid_path_to_add (string path) {
        try {
            File file = File.new_for_path (path);
            var file_info = file.query_info ("standard::*", 0);
            return Utils.check_if_valid_text_file (path, file_info);
        } catch (Error e) {
            return false;
        }
    }
}

public class Scratch.Plugins.FuzzySearch: Peas.ExtensionBase, Peas.Activatable {
    public Object object { owned get; construct; }

    private Gee.HashMap<string, Services.SearchProject> project_paths;
    private MainWindow window = null;
    private Scratch.Services.Interface plugins;
    private Gtk.EventControllerKey key_controller;

    public void update_state () {

    }

    public void activate () {
        plugins = (Scratch.Services.Interface) object;

        plugins.hook_window.connect ((w) => {
            if (window != null)
                return;

            window = w;
            key_controller = new Gtk.EventControllerKey (window);
            key_controller.key_pressed.connect (on_window_key_press_event);
        });
    }

    bool on_window_key_press_event (uint keyval, uint keycode, Gdk.ModifierType state) {
        /* <Alt>f shows fuzzy search dialog */
        switch (Gdk.keyval_to_upper (keyval)) {
            case Gdk.Key.F:
                if (state == Gdk.ModifierType.MOD1_MASK) {
                    var settings = new GLib.Settings ("io.elementary.code.folder-manager");

                    string[] opened_folders = settings.get_strv ("opened-folders");
                    if (opened_folders == null || opened_folders.length < 1) {
                        return false;
                    }

                    project_paths = new Gee.HashMap<string, Services.SearchProject> ();

                    foreach (unowned string path in settings.get_strv ("opened-folders")) {
                        var monitor = Services.GitManager.get_monitored_repository (path);
                        var project_path = new Services.SearchProject (path, monitor);
                        project_path.parse_async.begin (path, (obj, res) => {
                            project_path.parse_async.end (res);
                        });

                        project_paths[path] = project_path;
                    }

                    var popover = new Scratch.FuzzySearchPopover (project_paths, window);
                    popover.open_file.connect ((filepath) => {
                        var file = new Scratch.FolderManager.File (filepath);
                        var doc = new Scratch.Services.Document (window.actions, file.file);

                        window.open_document (doc);
                        popover.popdown ();
                    });

                    popover.close_search.connect (() => popover.popdown ());
                    popover.popup ();

                    return true;
                }

                break;
            default:
                return false;
        }

        return false;
    }

    public void deactivate () {
        key_controller.key_pressed.disconnect (on_window_key_press_event);
    }
}

[ModuleInit]
public void peas_register_types (GLib.TypeModule module) {
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type (
        typeof (Peas.Activatable),
        typeof (Scratch.Plugins.FuzzySearch)
    );
}
