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

public class Code.ChooseProjectButton : Gtk.ToggleButton {
    private const string NO_PROJECT_SELECTED = N_("No Project Selected");
    private Scratch.Services.GitManager manager;
    private Gtk.Image img;
    private Gtk.Label label_widget;
    private Gtk.ListBox project_selection_listbox;
    private ProjectEntry? last_entry = null;

    private Scratch.Services.Document? current_doc = null;

    construct {
        margin_top = margin_bottom = 6;

        img = new Gtk.Image () {
            gicon = new ThemedIcon ("git-symbolic"),
            icon_size = Gtk.IconSize.SMALL_TOOLBAR
        };

        label_widget = new Gtk.Label (_(NO_PROJECT_SELECTED)) {
            width_chars = 24,
            ellipsize = Pango.EllipsizeMode.END,
            max_width_chars = 24,
            xalign = 0.0f
        };

        tooltip_text = _("Active Git project");

        var grid = new Gtk.Grid () {
            halign = Gtk.Align.START
        };
        grid.add (img);
        grid.add (label_widget);
        add (grid);

        project_selection_listbox = new Gtk.ListBox () {
            selection_mode = Gtk.SelectionMode.SINGLE
        };
        var project_selection_filter = new Gtk.SearchEntry () {
            margin = 12,
            margin_bottom = 6,
            placeholder_text = _("Filter projects")
        };
        project_selection_listbox.set_sort_func ((row1, row2) => {
            return ((ProjectEntry) row1).project_name.collate (((ProjectEntry) row2).project_name);
        });

        project_selection_listbox.set_filter_func ((row) => {
            //Both are lowercased so that the case doesn't matter when comparing.
            return (((ProjectEntry) row).project_name.down ().contains (project_selection_filter.text.down ().strip ()));
        });

        project_selection_filter.changed.connect (() => {
            project_selection_listbox.invalidate_filter ();
        });

        var project_scrolled = new Gtk.ScrolledWindow (null, null) {
            hscrollbar_policy = Gtk.PolicyType.NEVER,
            height_request = 350,
            expand = true,
            margin_top = 3,
            margin_bottom = 3
        };

        project_scrolled.add (project_selection_listbox);

        var popover_content = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        popover_content.add (project_selection_filter);
        popover_content.add (project_scrolled);

        popover_content.show_all ();

        var project_popover = new Gtk.Popover (this) {
            position = Gtk.PositionType.BOTTOM
        };

        project_popover.add (popover_content);
        this.bind_property ("active", project_popover, "visible", GLib.BindingFlags.BIDIRECTIONAL);

        project_selection_listbox.row_activated.connect ((row) => {
            var project_entry = ((ProjectEntry) row);
            select_project (project_entry);
        });

        manager = Scratch.Services.GitManager.get_instance ();
        manager.project_added.connect (add_project);

        manager.project_removed.connect ((project_path) => {
            project_selection_listbox.get_children ().foreach ((child) => {
                project_selection_listbox.remove (child);
            });

            label_widget.label = _(NO_PROJECT_SELECTED);
            foreach (string path in manager.get_project_paths ()) {
                add_project (path);
            }

            set_document (current_doc);
        });
    }

    private void add_project (string project_path) {
        var project_entry = new ProjectEntry (project_path);
        if (last_entry != null) {
            project_entry.project_radio.join_group (last_entry.project_radio);
        }

        last_entry = project_entry;
        project_selection_listbox.add (project_entry);
        select_project (project_entry);
    }

    private void select_project (ProjectEntry project_entry) {
        project_selection_listbox.select_row (project_entry);
        label_widget.label = project_entry.project_name;
        project_entry.selected = true;
    }

    public void set_document (Scratch.Services.Document doc) {
        var path = doc.file.get_path ();
        project_selection_listbox.get_children ().foreach ((child) => {
            var project_entry = ((ProjectEntry) child);
            if (path.has_prefix (project_entry.project_path)) {
                select_project (project_entry);
            }
        });
    }

    public void set_active_path (string active_path) {
        project_selection_listbox.get_children ().foreach ((child) => {
            var project_entry = ((ProjectEntry) child);
            if (active_path.has_prefix (project_entry.project_path)) {
                select_project (project_entry);
            }
        });
    }

    public string? get_active_path () {
        string? active_path = null;
        project_selection_listbox.get_children ().foreach ((child) => {
            var project_entry = ((ProjectEntry) child);
            if (project_entry.active) {
                active_path = project_entry.project_path;
            }
        });

        return active_path;
    }

    public class ProjectEntry : Gtk.ListBoxRow {
        public string project_path { get; construct; }
        public string project_name {
            owned get {
                return Path.get_basename (project_path);
            }
        }

        public Gtk.RadioButton project_radio { get; construct; }

        public bool active {
            get {
                return project_radio.active;
            }

            set {
                project_radio.active = value;
            }
        }

        public bool selected {
            get {
                return project_radio.active;
            }

            set {
                project_radio.toggled.disconnect (radio_toggled);
                project_radio.active = value;
                project_radio.toggled.connect (radio_toggled);
            }
        }

        public ProjectEntry (string project_path) {
            Object (
                project_path: project_path
            );
        }

        class construct {
            set_css_name (Gtk.STYLE_CLASS_MENUITEM);
        }

        construct {
            project_radio = new Gtk.RadioButton.with_label (null, project_name);
            add (project_radio);
            project_radio.toggled.connect (radio_toggled);
            show_all ();
        }

        private void radio_toggled () {
            if (project_radio.active) {
                activate ();
            }
        }

        public unowned SList<Gtk.RadioButton> get_radio_group () {
            return project_radio.get_group ();
        }
    }
}
