/*-
 * Copyright (c) 2021 elementary Inc. (https://elementary.io)
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
    private const string NO_PROJECT_SELECTED = N_("No Project Selected");
    private const string PROJECT_TOOLTIP = N_("Active Git Project: %s");
    private Gtk.Label label_widget;
    private Gtk.ListBox project_listbox;

    public ActionGroup toplevel_action_group { get; construct; }
    public signal void project_chosen ();

    construct {
        realize.connect (() => {
            toplevel_action_group = get_action_group (Scratch.MainWindow.ACTION_GROUP);
            assert_nonnull (toplevel_action_group);
        });

        var img = new Gtk.Image () {
            gicon = new ThemedIcon ("git-symbolic"),
            icon_size = Gtk.IconSize.SMALL_TOOLBAR
        };

        label_widget = new Gtk.Label (_(NO_PROJECT_SELECTED)) {
            ellipsize = Pango.EllipsizeMode.MIDDLE,
            xalign = 0.0f
        };

        var grid = new Gtk.Grid () {
            halign = Gtk.Align.START
        };
        grid.add (img);
        grid.add (label_widget);
        add (grid);

        project_listbox = new Gtk.ListBox () {
            selection_mode = Gtk.SelectionMode.SINGLE
        };
        var project_filter = new Gtk.SearchEntry () {
            margin = 12,
            margin_bottom = 6,
            placeholder_text = _("Filter projects")
        };

        project_listbox.set_filter_func ((row) => {
            //Both are lowercased so that the case doesn't matter when comparing.
            return (((ProjectRow) row).project_name.down ().contains (project_filter.text.down ().strip ()));
        });

        project_filter.changed.connect (() => {
            project_listbox.invalidate_filter ();
        });

        var project_scrolled = new Gtk.ScrolledWindow (null, null) {
            hscrollbar_policy = Gtk.PolicyType.NEVER,
            expand = true,
            margin_top = 3,
            margin_bottom = 3,
            max_content_height = 350,
            propagate_natural_height = true
        };

        project_scrolled.add (project_listbox);

        var add_folder_button = new PopoverMenuItem (_("Open Folder…")) {
            action_name = Scratch.MainWindow.ACTION_PREFIX + Scratch.MainWindow.ACTION_OPEN_FOLDER,
            action_target = new Variant.string (""),
            icon_name = "folder-open-symbolic",
        };

        var clone_button = new PopoverMenuItem (_("Clone Git Repository…")) {
            action_name = Scratch.MainWindow.ACTION_PREFIX + Scratch.MainWindow.ACTION_CLONE_REPO,
            icon_name = "git-symbolic"
        };

        var popover_content = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        popover_content.add (project_filter);
        popover_content.add (project_scrolled);
        popover_content.add (new Gtk.Separator (HORIZONTAL));
        popover_content.add (add_folder_button);
        popover_content.add (clone_button);

        popover_content.show_all ();

        var project_popover = new Gtk.Popover (this) {
            position = Gtk.PositionType.BOTTOM
        };

        project_popover.add (popover_content);

        popover = project_popover;

        var git_manager = Scratch.Services.GitManager.get_instance ();

        git_manager.project_liststore.items_changed.connect ((src, pos, n_removed, n_added) => {
            var rows = project_listbox.get_children ();
            for (int index = (int)pos; index < pos + n_removed; index++) {
                var row = rows.nth_data (index);
                row.destroy ();
            }

            for (int index = (int)pos; index < pos + n_added; index++) {
                var item = src.get_object (index);
                if (item is Scratch.FolderManager.ProjectFolderItem) {
                    var row = create_project_row ((Scratch.FolderManager.ProjectFolderItem)item);
                    project_listbox.insert (row, index);
                }
            }
        });

        project_listbox.remove.connect ((row) => {
            var project_row = row as ProjectRow;
            var current_project = Scratch.Services.GitManager.get_instance ().active_project_path;
            if (project_row.project_path == current_project) {
                Scratch.Services.GitManager.get_instance ().active_project_path = "";
                // Label and active_path will be updated automatically
            }
        });

        project_listbox.row_activated.connect ((row) => {
            var project_entry = ((ProjectRow) row);
            toplevel_action_group.activate_action (
                Scratch.MainWindow.ACTION_SET_ACTIVE_PROJECT,
                new Variant.string (project_entry.project_path)
            );
        });

        toggled.connect (() => {
            if (active) {
                unowned var active_path = Scratch.Services.GitManager.get_instance ().active_project_path;
                foreach (var child in project_listbox.get_children ()) {
                    var project_row = ((ProjectRow) child);
                    // All paths must not end in directory separator so can be compared directly
                    project_row.active = active_path == project_row.project_path;
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
        var project_row = new ProjectRow (project_path);
        // Project folder items cannot be renamed in UI, no need to handle

        return project_row;
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
            set_css_name (Gtk.STYLE_CLASS_MENUITEM);
        }

        construct {
            check_button = new Gtk.CheckButton.with_label (Path.get_basename (project_path));
            add (check_button);
            check_button.button_release_event.connect (() => {
                activate ();
                return Gdk.EVENT_PROPAGATE;
            });

            show_all ();
        }
    }
}
