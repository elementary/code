/*-
 * Copyright (c) 2021-2026 elementary Inc. (https://elementary.io)
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

public class Code.ChooseProjectButton : Gtk.MenuButton {
    public bool cloning_in_progress { get; set; }

    private const string NO_PROJECT_SELECTED = N_("No Project Selected");
    private const string PROJECT_TOOLTIP = N_("Active Git Project: %s");
    private Gtk.Label label_widget;
    private Gtk.ListBox project_listbox;

    public signal void project_chosen ();

    construct {

        var img = new Gtk.Image.from_gicon (new ThemedIcon ("git-symbolic")) {
            icon_size = Gtk.IconSize.NORMAL
        };

        label_widget = new Gtk.Label (_(NO_PROJECT_SELECTED)) {
            ellipsize = Pango.EllipsizeMode.MIDDLE,
            xalign = 0.0f,
            hexpand = true
        };

        var cloning_spinner = new Gtk.Spinner () {
            halign = END
        };
        bind_property ("cloning-in-progress", cloning_spinner, "active");

        var box = new Gtk.Box (HORIZONTAL, 3) {
            hexpand = true,
            vexpand = false
        };
        box.append (img);
        box.append (label_widget);
        box.append (cloning_spinner);
        child = box;

        project_listbox = new Gtk.ListBox () {
            selection_mode = Gtk.SelectionMode.SINGLE
        };
        var project_filter = new Gtk.SearchEntry () {
            margin_top = 12,
            margin_bottom = 6,
            margin_start = 12,
            margin_end = 12,
            placeholder_text = _("Filter projects")
        };

        project_listbox.set_filter_func ((row) => {
            //Both are lowercased so that the case doesn't matter when comparing.
            return (((ProjectRow) row).project_name.down ().contains (project_filter.text.down ().strip ()));
        });

        project_filter.changed.connect (() => {
            project_listbox.invalidate_filter ();
        });

        var project_scrolled = new Gtk.ScrolledWindow () {
            hscrollbar_policy = Gtk.PolicyType.NEVER,
            hexpand = true,
            vexpand = true,
            margin_top = 3,
            margin_bottom = 3,
            max_content_height = 350,
            propagate_natural_height = true,
            child = project_listbox
        };

        var add_folder_button = new PopoverMenuItem (_("Open Folder…")) {
            action_name = Scratch.MainWindow.ACTION_PREFIX + Scratch.MainWindow.ACTION_OPEN_PROJECT,
            icon_name = "folder-open-symbolic",
        };

        var clone_button = new PopoverMenuItem (_("Clone Git Repository…")) {
            action_name = Scratch.MainWindow.ACTION_PREFIX + Scratch.MainWindow.ACTION_CLONE_REPO,
            icon_name = "git-symbolic"
        };

        var popover_content = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        popover_content.append (project_filter);
        popover_content.append (project_scrolled);
        popover_content.append (new Gtk.Separator (HORIZONTAL));
        popover_content.append (add_folder_button);
        popover_content.append (clone_button);

        var project_popover = new Gtk.Popover () {
            position = Gtk.PositionType.BOTTOM,
            child = popover_content
        };

        popover = project_popover;

        // Initialise with any pre-existing projects (needed for second and subsequent window)
        var git_manager = Scratch.Services.GitManager.get_instance ();
        var src = git_manager.project_liststore;
        for (int index = 0; index < src.n_items; index++) {
            var item = src.get_object (index);
            if (item is Scratch.FolderManager.ProjectFolderItem) {
                var row = create_project_row ((Scratch.FolderManager.ProjectFolderItem)item);
                project_listbox.insert (row, index);
            }
        }

        git_manager.project_liststore.items_changed.connect ((src, pos, n_removed, n_added) => {
            var child = project_listbox.get_first_child ();
            while (child != null) {
                child.destroy ();
                child = project_listbox.get_first_child ();
            }

            for (int index = (int)pos; index < pos + n_added; index++) {
                var item = src.get_object (index);
                if (item is Scratch.FolderManager.ProjectFolderItem) {
                    var row = create_project_row ((Scratch.FolderManager.ProjectFolderItem)item);
                    project_listbox.insert (row, index);
                }
            }
        });

        activate.connect (() => {
            if (active) {
                unowned var active_path = Scratch.Services.GitManager.get_instance ().active_project_path;
                var child = project_listbox.get_first_child ();
                while (child != null) {
                    var project_row = ((ProjectRow) child);
                    // All paths must not end in directory separator so can be compared directly
                    project_row.active = active_path == project_row.project_path;
                    child = child.get_next_sibling ();
                }
            }
        });

        git_manager.notify["active-project-path"].connect (update_button);
        update_button ();
    }

    // Set appearance (only) of project chooser button and list according to active path
    private void update_button () {
        unowned var active_path = Scratch.Services.GitManager.get_instance ().active_project_path;
        if (active_path != "") {
            label_widget.label = Path.get_basename (active_path);
            tooltip_text = _(PROJECT_TOOLTIP).printf (Scratch.Utils.replace_home_with_tilde (active_path));
        } else {
            label_widget.label = Path.get_basename (_(NO_PROJECT_SELECTED));
            tooltip_text = _(PROJECT_TOOLTIP).printf (_(NO_PROJECT_SELECTED));
        }
    }

    private Gtk.Widget create_project_row (Scratch.FolderManager.ProjectFolderItem project_folder) {
        var project_path = project_folder.file.file.get_path ();
        return new ProjectRow (project_path);
    }

    public class ProjectRow : Gtk.ListBoxRow {
        private Gtk.CheckButton check_button;
        public bool active {
            get {
                return check_button.active;
            }

            set {
                    check_button.active = value;
            }
        }

        public string project_path { get; construct; }
        public string project_name {
            get {
                return check_button.label;
            }
        }

        public ProjectRow (string project_path) {
            Object (
                project_path: project_path
            );
        }

        class construct {
            set_css_name (Granite.STYLE_CLASS_MENUITEM);
        }

        construct {
            action_name = Scratch.MainWindow.ACTION_PREFIX + Scratch.MainWindow.ACTION_SET_ACTIVE_PROJECT;
            action_target = new Variant.string (project_path);

            check_button = new Gtk.CheckButton.with_label (Path.get_basename (project_path));
            child = check_button;

            var button_controller = new Gtk.GestureClick () {
                propagation_phase = CAPTURE,
                button = 0
            };

            check_button.add_controller (button_controller);
            button_controller.released.connect ((n, dx, dy) => {
                activate ();
            });
            check_button = new Gtk.CheckButton.with_label (Path.get_basename (project_path));
        }
    }
}
