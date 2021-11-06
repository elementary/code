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

    construct {
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

        var popover_content = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        popover_content.add (project_filter);
        popover_content.add (project_scrolled);

        popover_content.show_all ();

        var project_popover = new Gtk.Popover (this) {
            position = Gtk.PositionType.BOTTOM
        };

        project_popover.add (popover_content);

        popover = project_popover;

        project_listbox.bind_model (
            Scratch.Services.GitManager.get_instance ().project_liststore,
            create_project_row
        );

        project_listbox.remove.connect ((row) => {
            var project_row = row as ProjectRow;
            var current_project = Scratch.Services.GitManager.get_instance ().active_project_path;
            if (project_row.project_path == current_project) {
                label_widget.label = _(NO_PROJECT_SELECTED);
                label_widget.tooltip_text = _("Active Git project: %s").printf (_(NO_PROJECT_SELECTED));
                Scratch.Services.GitManager.get_instance ().active_project_path = "";
                Scratch.Services.ProjectManager.get_instance ().project_path = null;
            }
        });

        project_listbox.row_activated.connect ((row) => {
            var project_entry = ((ProjectRow) row);
            select_project (project_entry);
        });
    }

    private Gtk.Widget create_project_row (GLib.Object object) {
        unowned var project_folder = (Scratch.FolderManager.ProjectFolderItem) object;

        var project_row = new ProjectRow (project_folder.file.file.get_path ());
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

        return project_row;
    }

    private void select_project (ProjectRow project_entry) {
        project_listbox.select_row (project_entry);
        label_widget.label = project_entry.project_name;
        label_widget.tooltip_text = _("Active Git project: %s").printf (project_entry.project_path);
        project_entry.active = true;
        Scratch.Services.GitManager.get_instance ().active_project_path = project_entry.project_path;
        Scratch.Services.ProjectManager.get_instance ().project_path = project_entry.project_path;
    }

    public void set_document (Scratch.Services.Document doc) {
        set_active_path (doc.file.get_path ());
    }

    public void set_active_path (string active_path) {
        project_listbox.get_children ().foreach ((child) => {
            var project_entry = ((ProjectRow) child);
            if (active_path.has_prefix (project_entry.project_path)) {
                select_project (project_entry);
            }
        });
    }

    public class ProjectRow : Gtk.ListBoxRow {
        public bool active { get; set; }
        public string project_path { get; construct; }
        public string project_name {
            get {
                return project_radio.label;
            }
        }

        public Gtk.RadioButton project_radio { get; construct; }

        public ProjectRow (string project_path) {
            Object (
                project_path: project_path
            );
        }

        class construct {
            set_css_name (Gtk.STYLE_CLASS_MENUITEM);
        }

        construct {
            project_radio = new Gtk.RadioButton.with_label (null, Path.get_basename (project_path));
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
