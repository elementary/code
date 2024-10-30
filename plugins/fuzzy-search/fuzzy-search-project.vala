/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2023 elementary, Inc. <https://elementary.io>
 *
 * Authored by: Marvin Ahlgrimm
 * Authored by: Colin Kiama <colinkiama@gmail.com>
 */

public class Scratch.Services.SearchProject {
    public string root_path { get; private set; }
    public Gee.HashSet<string> relative_file_paths { get; private set; }

    private MonitoredRepository? monitored_repo;

    public SearchProject (string root, MonitoredRepository? repo) {
        root_path = root;
        monitored_repo = repo;
        relative_file_paths = new Gee.HashSet<string> ();
    }

    public async void parse_async (string path, GLib.Cancellable cancellable) {
        new Thread<void> (null, () => {
            parse_async_internal.begin (path, cancellable, (obj, res) => {
                parse_async_internal.end (res);
            });

            Idle.add (parse_async.callback);
        });

        yield;
    }

    public void remove_file (string path, GLib.Cancellable cancellable) {
        if (cancellable.is_cancelled ()) {
            return;
        }

        string subpath = path.replace (root_path, "");
        string deleted_path = subpath.substring (1, subpath.length - 1);

        // Remove File
        if (relative_file_paths.contains (deleted_path)) {
            relative_file_paths.remove (deleted_path);
            return;
        }

        Gee.Iterator<string> iter = relative_file_paths.iterator ();

        // Remove directory
        while (iter.next ()) {
          var relative_path = iter.get ();
          if (relative_path.has_prefix (deleted_path)) {
            iter.remove ();
          }
        }
    }

    public void add_file (string path, GLib.Cancellable cancellable) {
        if (cancellable.is_cancelled ()) {
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

        string subpath = path.replace (root_path, "");
        relative_file_paths.add (subpath.substring (1, subpath.length - 1));
    }

    public async void add_directory_async (string path, GLib.Cancellable cancellable) {
        parse_async_internal.begin (path, cancellable, (obj, res) => {
           parse_async_internal.end (res);
        });
    }

    private async void parse_async_internal (string path, GLib.Cancellable cancellable) {
        if (cancellable.is_cancelled ()) {
            return;
        }

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
                if (cancellable.is_cancelled ()) {
                    return;
                }

                var new_search_path = "";
                if (path.has_suffix (GLib.Path.DIR_SEPARATOR_S)) {
                    new_search_path = path.substring (0, path.length - 1);
                } else {
                    new_search_path = path;
                }

                parse_async_internal.begin (
                    new_search_path + GLib.Path.DIR_SEPARATOR_S + name,
                    cancellable,
                    (obj, res) => {
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
                string subpath = path.replace (root_path, "");
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
