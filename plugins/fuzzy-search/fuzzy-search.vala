

public class Scratch.Services.SearchProject {
    public string root_path { get; private set; }
    public Gee.ArrayList<string> relative_file_paths { get; private set; }

    public SearchProject (string root) {
        root_path = root;
        relative_file_paths = new Gee.ArrayList<string> ();
        parse (root_path);
    }

    private void parse (string path) {
        try {
            if (path.contains ("node_modules")) {
                return;
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

        var settings = new GLib.Settings ("io.elementary.code.folder-manager");
        foreach (unowned string path in settings.get_strv ("opened-folders")) {
            var project = new Services.SearchProject(path);
            project_paths[path] = project;
        }

        plugins.hook_window.connect ((w) => {
            if (window != null)
                return;

            window = w;
            window.key_press_event.connect (on_window_key_press_event);
        });
    }

    bool on_window_key_press_event (Gdk.EventKey event) {
        /* <Control>p shows fuzzy search dialog */
        if (event.keyval == Gdk.Key.p
            && Gdk.ModifierType.CONTROL_MASK in event.state) {
                var dialog = new Scratch.Dialogs.FuzzySearchDialog (project_paths);

                dialog.open_file.connect ((filepath) => {
                    // Open the file
                    var file = File.new_for_uri (filepath);
                    plugins.open_file (file);
                    dialog.destroy ();
                });

                dialog.close_search.connect (() => dialog.destroy ());

                int diag_x;
                int diag_y;
                int window_x;
                int window_y;
                window.get_position (out window_x, out window_y);
                dialog.get_position(out diag_x, out diag_y);
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
