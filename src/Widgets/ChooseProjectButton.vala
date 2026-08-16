/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2021-2026 elementary Inc. (https://elementary.io)
 */

public class Code.ChooseProjectButton : Gtk.Bin {
    public bool cloning_in_progress { get; set; }

    private const string NO_PROJECT_SELECTED = N_("No Project Selected");
    private const string PROJECT_TOOLTIP = N_("Active Git Project: %s");
    private Gtk.Label label_widget;
    private Gtk.ListBox project_listbox;
    private Gtk.SearchEntry project_filter;
    private ListStore project_liststore;
    private Scratch.Services.GitManager git_manager;

    public signal void project_chosen ();

    construct {
        var img = new Gtk.Image.from_icon_name ("git-symbolic", SMALL_TOOLBAR);

        label_widget = new Gtk.Label (_(NO_PROJECT_SELECTED)) {
            ellipsize = MIDDLE,
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
        box.add (img);
        box.add (label_widget);
        box.add (cloning_spinner);

        project_liststore = new ListStore (typeof (ProjectRow));
        project_listbox = new Gtk.ListBox () {
            selection_mode = SINGLE
        };

        project_listbox.bind_model (project_liststore, (obj) => (ProjectRow) obj);

        project_filter = new Gtk.SearchEntry () {
            margin_top = 12,
            margin_bottom = 6,
            margin_start = 12,
            margin_end = 12,
            placeholder_text = _("Filter projects")
        };

        project_filter.changed.connect (() => {
            insert_project_rows ();
        });

        var project_scrolled = new Gtk.ScrolledWindow (null, null) {
            child = project_listbox,
            hscrollbar_policy = NEVER,
            hexpand = true,
            vexpand = true,
            margin_top = 3,
            margin_bottom = 3,
            max_content_height = 350,
            propagate_natural_height = true
        };

        var add_folder_button = new PopoverMenuItem (_("Open Folder…")) {
            action_name = Scratch.MainWindow.ACTION_PREFIX + Scratch.MainWindow.ACTION_OPEN_PROJECT,
            icon_name = "folder-open-symbolic",
        };

        var clone_button = new PopoverMenuItem (_("Clone Git Repository…")) {
            action_name = Scratch.MainWindow.ACTION_PREFIX + Scratch.MainWindow.ACTION_CLONE_REPO,
            icon_name = "git-symbolic"
        };

        var popover_content = new Gtk.Box (VERTICAL, 0);
        popover_content.add (project_filter);
        popover_content.add (project_scrolled);
        popover_content.add (new Gtk.Separator (HORIZONTAL));
        popover_content.add (add_folder_button);
        popover_content.add (clone_button);
        popover_content.show_all ();

        var project_popover = new Gtk.Popover (null) {
            position = BOTTOM,
            child = popover_content
        };

        var menu_button = new Gtk.MenuButton () {
            child = box,
            popover = project_popover
        };

        child = menu_button;

        // Initialise with any pre-existing projects (needed for second and subsequent window)
        insert_project_rows ();
        git_manager = Scratch.Services.GitManager.get_instance ();
        git_manager.project_liststore.items_changed.connect ((src, pos, n_removed, n_added) => {
            insert_project_rows ();
        });

        git_manager.notify["active-project-path"].connect (update_active_project);
        update_active_project ();
    }

    private bool filter_func (Scratch.FolderManager.ProjectFolderItem project) {
        var project_name = Path.get_basename (project.path);
        //Both are lowercased so that the case doesn't matter when comparing.
        return project_name.down ().contains (project_filter.text.down ().strip ());
    }

    // Set appearance (only) of project chooser button and list according to active path
    private void update_active_project () {
        unowned var active_path = git_manager.active_project_path;
        if (active_path != "") {
            label_widget.label = Path.get_basename (active_path);
            tooltip_text = _(PROJECT_TOOLTIP).printf (Scratch.Utils.replace_home_with_tilde (active_path));
        } else {
            label_widget.label = Path.get_basename (_(NO_PROJECT_SELECTED));
            tooltip_text = _(PROJECT_TOOLTIP).printf (_(NO_PROJECT_SELECTED));
        }

        for (int index = 0; index < project_liststore.n_items; index++) {
            var project_row = (ProjectRow) project_liststore.get_item (index);
            project_row.update_active (active_path);
        }
    }

    // Throttle rebuilding the list as gitmanager emits multiple changed signals on startup
    uint insert_timeout_id = 0;
    bool insert_wait = false;
    private void insert_project_rows () {
        if (insert_timeout_id == 0) {
            insert_wait = false;
            Timeout.add (200, () => {
                if (insert_wait) {
                    insert_wait = false;
                    return Source.CONTINUE;
                }

                project_liststore.remove_all ();

                var src = git_manager.project_liststore;
                unowned var active_path = git_manager.active_project_path;
                for (int index = 0; index < src.n_items; index++) {
                    var item = src.get_object (index);
                    if (item is Scratch.FolderManager.ProjectFolderItem) {
                        var project = (Scratch.FolderManager.ProjectFolderItem) item;
                        if (filter_func (project)) {
                            var row = new ProjectRow (project.path);
                            // The GitManager project store is already sorted so just add.
                            project_liststore.append (row);
                            row.update_active (active_path);
                        }
                    }
                }

                return Source.REMOVE;
            });
        } else {
            insert_wait = true;
        }
    }

    public class ProjectRow : Gtk.ListBoxRow {
        public string project_path { get; construct; }
        private Gtk.CheckButton check_button;
        private Gtk.GestureMultiPress button_controller;

        public ProjectRow (string project_path) {
            Object (
                project_path: project_path
            );
        }

        class construct {
            set_css_name (Gtk.STYLE_CLASS_MENUITEM);
        }

        construct {
            can_focus = true;
            action_name = Scratch.MainWindow.ACTION_PREFIX + Scratch.MainWindow.ACTION_SET_ACTIVE_PROJECT;
            action_target = new Variant.string (project_path);

            check_button = new Gtk.CheckButton.with_label (Path.get_basename (project_path)) {
                can_focus = false
            };

            child = check_button;

            button_controller = new Gtk.GestureMultiPress (check_button) {
                propagation_phase = CAPTURE,
                button = 0
            };
            button_controller.released.connect (() => {
                activate ();
            });

            show_all ();
        }

        public void update_active (string active_path) {
            check_button.active = active_path == project_path;
        }
    }
}
