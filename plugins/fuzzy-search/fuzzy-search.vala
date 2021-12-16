public class Scratch.Services.SearchProject {
    public string root_path { get; private set; }
    public Gee.ArrayList<string> relative_file_paths { get; private set; }
    private MonitoredRepository? monitored_repo;

    public SearchProject (string root, MonitoredRepository? repo) {
        root_path = root;
        monitored_repo = repo;
        relative_file_paths = new Gee.ArrayList<string> ();

        parse (root_path);
    }

    private void parse (string path) {
        try {
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
                if (path.has_suffix ("/")) {
                    new_search_path = path.substring (0, path.length - 1);
                } else {
                    new_search_path = path;
                }
                parse (new_search_path + "/" + name);
                name = dir.read_name ();
            }
        } catch (FileError e) {
            // This adds branch is reached when a non-directory was reached, i.e. is a file
            // If a file was reached, add it's relative path (starting after the project root path)
            // to the list.
            // Relativ paths are used because the longer the path is the less accurate are the results
            var subpath = path.replace (root_path, "");
            relative_file_paths.add (subpath.substring (1, subpath.length-1));
        }
    }
}

public class Scratch.Plugins.FuzzySearch: Peas.ExtensionBase, Peas.Activatable {
    MainWindow window = null;
    private Gee.ArrayList<string> paths;
    private Gee.HashMap<string, Services.SearchProject> project_paths;

    Scratch.Services.Interface plugins;
    public Object object {owned get; construct;}

    public void update_state () {
    }

    public void activate () {
        plugins = (Scratch.Services.Interface) object;
        paths = new Gee.ArrayList<string> ();
        project_paths = new Gee.HashMap<string, Services.SearchProject> ();

        plugins.hook_window.connect ((w) => {
            if (window != null)
                return;

            var settings = new GLib.Settings ("io.elementary.code.folder-manager");
            window = w;
            window.key_press_event.connect (on_window_key_press_event);

            foreach (unowned string path in settings.get_strv ("opened-folders")) {
                project_paths[path] = new Services.SearchProject(path, Services.GitManager.get_monitored_repository (path));
            }

            var git_manager = Services.GitManager.get_instance ();

            //Todo: also listen for non-git projects
            git_manager.opened_project.connect ((root_path) => {
                project_paths[root_path] = new Services.SearchProject(root_path, Services.GitManager.get_monitored_repository (root_path));
            });

            //Todo: also listen for non-git projects
            git_manager.removed_project.connect ((root_path) => {
                var project = project_paths[root_path];
                project_paths.unset  (root_path, out project);
            });
        });
    }

    bool on_window_key_press_event (Gdk.EventKey event) {
        /* <Control>p shows fuzzy search dialog */
        if (event.keyval == Gdk.Key.p
            && Gdk.ModifierType.CONTROL_MASK in event.state) {
                int diag_x;
                int diag_y;
                int window_x;
                int window_y;
                int window_height;
                int window_width;
                window.get_position (out window_x, out window_y);
                window.get_size (out window_width, out window_height);
                var dialog = new Scratch.Dialogs.FuzzySearchDialog (project_paths, window_height);
                dialog.get_position(out diag_x, out diag_y);

                dialog.open_file.connect ((filepath) => {
                    // Open the file
                    var file = File.new_for_uri (filepath);
                    plugins.open_file (file);
                    dialog.destroy ();
                });

                dialog.close_search.connect (() => dialog.destroy ());
                // Move the dialog a bit under the top of the application window
                dialog.move(diag_x, window_y + 50);

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
