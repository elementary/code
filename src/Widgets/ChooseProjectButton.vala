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
    private Gtk.Label label_widget;
    private Gtk.ListBox project_listbox;
    private ProjectRow? last_entry = null;
    private Scratch.Services.GitManager git_manager;

    construct {
        git_manager = Scratch.Services.GitManager.get_instance ();
        var img = new Gtk.Image () {
            gicon = new ThemedIcon ("git-symbolic"),
            icon_size = Gtk.IconSize.SMALL_TOOLBAR
        };

        label_widget = new Gtk.Label (_(NO_PROJECT_SELECTED)) {
            width_chars = 24,
            ellipsize = Pango.EllipsizeMode.MIDDLE,
            max_width_chars = 24,
            xalign = 0.0f
        };

        tooltip_text = _("Active Git project: %s").printf (_(NO_PROJECT_SELECTED));

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
            margin_top = 12,
            margin_start = 12,
            margin_end = 12,
            margin_bottom = 6,
            placeholder_text = _("Filter projects")
        };

        project_filter.changed.connect (() => {
            project_listbox.invalidate_filter ();
        });

        project_listbox.set_sort_func ((row1, row2) => {
            var pr1 = (ProjectRow)row1;
            var pr2 = (ProjectRow)row2;
            return pr1.project_folder.name.collate (pr2.project_folder.name);
        });

        project_listbox.set_filter_func ((row) => {
            var pr = (ProjectRow)row;
            return pr.project_folder.name.down ().has_prefix (project_filter.text.down ().strip ());
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

        var popover_content = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        popover_content.add (project_filter);
        popover_content.add (project_scrolled);

        popover_content.show_all ();

        var project_popover = new Gtk.Popover (this) {
            position = Gtk.PositionType.BOTTOM
        };

        project_popover.add (popover_content);

        popover = project_popover;

        git_manager.project_added.connect (create_project_row);
        git_manager.project_removed.connect (remove_project_row);
        project_listbox.row_activated.connect ((row) => {
            select_project ((ProjectRow) row);
            project_popover.popdown ();
        });
    }

    private void create_project_row (
        Scratch.FolderManager.ProjectFolderItem project_folder) {

        var project_row = new ProjectRow (project_folder);
        project_folder.bind_property ("name", project_row.project_radio, "label", BindingFlags.DEFAULT | BindingFlags.SYNC_CREATE,
            (binding, srcval, ref targetval) => {
                var label = srcval.get_string ();
                targetval.set_string (label);
                if (project_row.active) {
                    label_widget.label = label;
                }
                return true;
            }
        );

        if (last_entry != null) {
            project_row.project_radio.join_group (last_entry.project_radio);
        }

        last_entry = project_row;
        project_listbox.insert (project_row, -1);
        project_listbox.invalidate_sort ();
    }
    private void remove_project_row (Scratch.FolderManager.ProjectFolderItem project_folder) {
        foreach (Gtk.Widget child in project_listbox.get_children ()) {
            if ((child is ProjectRow) &&
                ((ProjectRow)child).project_folder == project_folder) {

                if (project_folder.path == git_manager.active_project_path) {
                    label_widget.label = _(NO_PROJECT_SELECTED);
                    label_widget.tooltip_text = _("Active Git project: %s").printf (_(NO_PROJECT_SELECTED));
                    git_manager.active_project_path = "";
                }

                remove (child);
            }
        }
    }

    private void select_project (ProjectRow project_selected) {
        label_widget.label = project_selected.project_folder.name;
        var tooltip_text = Scratch.Utils.replace_home_with_tilde (project_selected.project_folder.path);
        label_widget.tooltip_text = _("Active Git project: %s").printf (tooltip_text);
        project_selected.active = true;
        git_manager.active_project_path = project_selected.project_folder.path;
    }

    public void set_document (Scratch.Services.Document doc) {
        set_active_path (doc.file.get_path ());
    }

    public void set_active_path (string active_path) {
        project_listbox.get_children ().foreach ((child) => {
            var project_entry = ((ProjectRow) child);
            if (active_path.has_prefix (project_entry.project_folder.path)) {
                select_project (project_entry);
            }
        });
    }

    public class ProjectRow : Gtk.ListBoxRow {
        public bool active { get; set; }
        public Scratch.FolderManager.ProjectFolderItem project_folder { get; construct; }
        public Gtk.RadioButton project_radio { get; construct; }
        public string label {
            get {
                return project_radio.label;
            }
        }

        public ProjectRow (Scratch.FolderManager.ProjectFolderItem project_folder) {
            Object (
                project_folder: project_folder
            );
        }

        class construct {
            set_css_name (Gtk.STYLE_CLASS_MENUITEM);
        }

        construct {
            project_radio = new Gtk.RadioButton.with_label (null, project_folder.name);
            add (project_radio);
            show_all ();

            bind_property ("active", project_radio, "active", BindingFlags.BIDIRECTIONAL);

            project_radio.button_release_event.connect (() => {
                activate ();
                return Gdk.EVENT_PROPAGATE;
            });
        }
    }
}
