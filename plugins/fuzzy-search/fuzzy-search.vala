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
                debug ("Fuzzy Search - Parsed fuzzy search path: %s\n", name);
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
            var subpath = path.replace (root_path, "");
            relative_file_paths.add (subpath.substring (1, subpath.length - 1));
        }
    }
}

public class Scratch.Plugins.FuzzySearch: Peas.ExtensionBase, Peas.Activatable {
    Gee.HashMap<string, Services.SearchProject> project_paths;

    MainWindow window = null;

    Scratch.Services.Interface plugins;
    public Object object {owned get; construct;}

    public void update_state () {
    }

    public void activate () {
        plugins = (Scratch.Services.Interface) object;

        plugins.hook_window.connect ((w) => {
            if (window != null)
                return;

            project_paths = new Gee.HashMap<string, Services.SearchProject> ();

            var settings = new GLib.Settings ("io.elementary.code.folder-manager");
            foreach (unowned string path in settings.get_strv ("opened-folders")) {
                var monitor = Services.GitManager.get_monitored_repository (path);
                var project_path = new Services.SearchProject (path, monitor);
                project_path.parse_async.begin (path, (obj, res) => {});

                project_paths[path] = project_path;
            }

            window = w;
            window.key_press_event.connect (on_window_key_press_event);

        });
    }

    bool on_window_key_press_event (Gdk.EventKey event) {
        /* <Control>p shows fuzzy search dialog */
        if (event.keyval == Gdk.Key.p
            && Gdk.ModifierType.CONTROL_MASK in event.state) {
                var settings = new GLib.Settings ("io.elementary.code.folder-manager");

                string[] opened_folders = settings.get_strv ("opened-folders");
                if (opened_folders == null || opened_folders.length < 1) {
                    return false;
                }

                int diag_x;
                int diag_y;
                int window_x;
                int window_y;
                int window_height;
                int window_width;
                window.get_position (out window_x, out window_y);
                window.get_size (out window_width, out window_height);

                var dialog = new Scratch.Dialogs.FuzzySearchDialog (project_paths, window_height);
                dialog.get_position (out diag_x, out diag_y);

                dialog.open_file.connect ((filepath) => {
                    var file = new Scratch.FolderManager.File (filepath);
                    var doc = new Scratch.Services.Document (window.actions, file.file);

                    window.open_document (doc);
                    dialog.destroy ();
                });

                dialog.close_search.connect (() => dialog.destroy ());
                // Move the dialog a bit under the top of the application window
                dialog.move (diag_x, window_y + 50);

                dialog.run ();

                return true;
        }

        return false;
    }

    public void deactivate () {}
}

[ModuleInit]
public void peas_register_types (GLib.TypeModule module) {
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type (
        typeof (Peas.Activatable),
        typeof (Scratch.Plugins.FuzzySearch)
    );
}
