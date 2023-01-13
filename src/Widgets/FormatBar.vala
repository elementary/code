/*-
 * Copyright 2017-2023 elementary, Inc. (https://elementary.io)
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
 * Authored by: Corentin Noël <corentin@elementary.io>
 */

public class Code.FormatBar : Gtk.Box {
    private Gtk.SourceLanguageManager manager;
    private FormatButton lang_toggle;
    private Gtk.ListBox lang_selection_listbox;
    private Gtk.SearchEntry lang_selection_filter;
    private LangEntry normal_entry;

    private FormatButton tab_toggle;
    private Granite.SwitchModelButton space_tab_modelbutton;
    public bool tab_set_by_editor_config { get; set; default = false; }

    public FormatButton line_toggle;
    private Gtk.Entry goto_entry;

    private unowned Scratch.Services.Document? doc = null;

    construct {
        get_style_context ().add_class (Gtk.STYLE_CLASS_LINKED);

        manager = Gtk.SourceLanguageManager.get_default ();

        tab_toggle = new FormatButton () {
            icon = new ThemedIcon ("format-indent-more-symbolic")
        };

        bind_property ("tab-set-by-editor-config", tab_toggle, "sensitive", BindingFlags.INVERT_BOOLEAN);

        lang_toggle = new FormatButton () {
            icon = new ThemedIcon ("application-x-class-file-symbolic")
        };
        lang_toggle.tooltip_text = _("Syntax Highlighting");

        line_toggle = new FormatButton () {
            icon = new ThemedIcon ("view-continuous-symbolic")
        };
        line_toggle.tooltip_markup = Granite.markup_accel_tooltip (
            ((Scratch.Application) GLib.Application.get_default ()).get_accels_for_action (
                Scratch.MainWindow.ACTION_PREFIX + Scratch.MainWindow.ACTION_GO_TO
            ),
            _("Line number")
        );

        homogeneous = true;
        add (tab_toggle);
        add (lang_toggle);
        add (line_toggle);

        create_tabulation_popover ();
        create_language_popover ();
        create_line_popover ();
    }

    private void create_language_popover () {
        lang_selection_listbox = new Gtk.ListBox ();
        lang_selection_listbox.selection_mode = Gtk.SelectionMode.SINGLE;
        lang_selection_listbox.set_sort_func ((row1, row2) => {
            return ((LangEntry) row1).lang_name.collate (((LangEntry) row2).lang_name);
        });
        lang_selection_listbox.set_filter_func ((row) => {
            //Both are lowercased so that the case doesn't matter when comparing.
            return (((LangEntry) row).lang_name.down ().contains (lang_selection_filter.text.down ().strip ()));
        });

        lang_selection_filter = new Gtk.SearchEntry () {
            margin = 12,
            margin_bottom = 6,
            placeholder_text = _("Filter languages")
        };

        lang_selection_filter.changed.connect (() => {
            lang_selection_listbox.invalidate_filter ();
        });

        var lang_scrolled = new Gtk.ScrolledWindow (null, null);
        lang_scrolled.hscrollbar_policy = Gtk.PolicyType.NEVER;
        lang_scrolled.height_request = 350;
        lang_scrolled.expand = true;
        lang_scrolled.margin_top = lang_scrolled.margin_bottom = 3;

        lang_scrolled.add (lang_selection_listbox);

        unowned string[]? ids = manager.get_language_ids ();
        unowned SList<Gtk.RadioButton> group = null;
        foreach (unowned string id in ids) {
            weak Gtk.SourceLanguage lang = manager.get_language (id);
            var entry = new LangEntry (id, lang.name, group);
            group = entry.get_radio_group ();
            lang_selection_listbox.add (entry);
        }

        normal_entry = new LangEntry (null, _("Plain Text"), group);
        lang_selection_listbox.add (normal_entry);

        var popover_content = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        popover_content.add (lang_selection_filter);
        popover_content.add (lang_scrolled);

        popover_content.show_all ();

        var lang_popover = new Gtk.Popover (lang_toggle);
        lang_popover.position = Gtk.PositionType.BOTTOM;
        lang_popover.add (popover_content);

        lang_toggle.popover = lang_popover;

        lang_selection_listbox.row_activated.connect ((row) => {
            var lang_entry = ((LangEntry) row);
            select_language (lang_entry);
        });
    }

    private void select_language (LangEntry lang, bool update_source_view = true) {
        lang_selection_listbox.select_row (lang);
        lang_toggle.text = lang.lang_name;
        if (update_source_view) {
            lang.active = true;
            doc.source_view.language = lang.lang_id != null ? manager.get_language (lang.lang_id) : null;
        } else {
            lang.selected = true;
        }
    }

    private void create_tabulation_popover () {
        var autoindent_modelbutton = new Granite.SwitchModelButton (_("Automatic Indentation"));

        space_tab_modelbutton = new Granite.SwitchModelButton (_("Insert Spaces Instead Of Tabs"));

        var width_label = new Gtk.Label (_("Tab width")) {
            halign = Gtk.Align.START,
            hexpand = true
        };

        var tab_width = new Gtk.SpinButton.with_range (1, 24, 1);

        var tab_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12) {
            margin_top = 6,
            margin_end = 12,
            margin_start = 12,
        };
        tab_box.add (width_label);
        tab_box.add (tab_width);

        var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) {
            margin_top = 6,
            margin_bottom = 12
        };
        box.add (autoindent_modelbutton);
        box.add (space_tab_modelbutton);
        box.add (tab_box);
        box.show_all ();

        var tab_popover = new Gtk.Popover (tab_toggle) {
            position = Gtk.PositionType.BOTTOM
        };
        tab_popover.add (box);

        tab_toggle.popover = tab_popover;

        Scratch.settings.bind ("auto-indent", autoindent_modelbutton, "active", SettingsBindFlags.DEFAULT);
        Scratch.settings.bind ("indent-width", tab_width, "value", SettingsBindFlags.GET);
        Scratch.settings.bind ("spaces-instead-of-tabs", space_tab_modelbutton, "active", SettingsBindFlags.SET);
        Scratch.settings.changed["indent-width"].connect (format_tab_header_from_global_settings);
        Scratch.settings.changed["spaces-instead-of-tabs"].connect (format_tab_header_from_global_settings);
    }

    private void format_tab_header_from_global_settings () {
        if (tab_set_by_editor_config) {
            return;
        }

        var indent_width = Scratch.settings.get_int ("indent-width");
        var spaces_instead_of_tabs = Scratch.settings.get_boolean ("spaces-instead-of-tabs");

        set_tab_width (indent_width);
        set_insert_spaces_instead_of_tabs (spaces_instead_of_tabs);
    }

    private void format_line_header () {
        var buffer = doc.source_view.buffer;
        var position = buffer.cursor_position;
        Gtk.TextIter iter;
        buffer.get_iter_at_offset (out iter, position);
        var line = iter.get_line () + 1;

        line_toggle.text = "%d.%d".printf (line, iter.get_line_offset ());
        goto_entry.text = "%d.%d".printf (line, iter.get_line_offset ());
    }

    private void create_line_popover () {
        var goto_label = new Gtk.Label (_("Go To Line:"));
        goto_label.xalign = 1;

        goto_entry = new Gtk.Entry ();

        var line_grid = new Gtk.Grid ();
        line_grid.margin = 12;
        line_grid.column_spacing = 12;
        line_grid.attach (goto_label, 0, 0, 1, 1);
        line_grid.attach (goto_entry, 1, 0, 1, 1);
        line_grid.show_all ();

        var line_popover = new Gtk.Popover (line_toggle);
        line_popover.position = Gtk.PositionType.BOTTOM;
        line_popover.add (line_grid);

        line_toggle.popover = line_popover;

        // We need to connect_after because otherwise, the text isn't parsed into the "value" property and we only get the previous value
        goto_entry.activate.connect_after (() => {
            int line, offset;

            goto_entry.text = goto_entry.text.replace (":", ".");

            goto_entry.text.scanf ("%i.%i", out line, out offset);
            doc.source_view.go_to_line (line, offset);
            // Focuses parent to the source view, so that the cursor, which indicates line and column is actually visible.
            doc.source_view.grab_focus ();
        });
    }

    public void set_document (Scratch.Services.Document doc) {
        if (this.doc != null) {
            this.doc.source_view.buffer.notify["cursor-position"].disconnect (format_line_header);
        }
        this.doc = doc;
        update_current_lang ();
        format_tab_header_from_global_settings ();
        format_line_header ();
        this.doc.source_view.buffer.notify["cursor-position"].connect (format_line_header);
    }

    public void set_insert_spaces_instead_of_tabs (bool use_spaces) {
        space_tab_modelbutton.active = use_spaces;
        if (doc != null) {
            doc.source_view.insert_spaces_instead_of_tabs = use_spaces;
        }
    }

    public void set_tab_width (int indent_width) {
        if (space_tab_modelbutton.active) {
            tab_toggle.text = ngettext ("%d Space", "%d Spaces", indent_width).printf (indent_width);
        } else {
            tab_toggle.text = ngettext ("%d Tab", "%d Tabs", indent_width).printf (indent_width);
        }

        if (tab_set_by_editor_config) {
            tab_toggle.tooltip_text = _("Indent width and style set by EditorConfig file");
        }

        if (doc != null) {
            doc.source_view.indent_width = indent_width;
            doc.source_view.tab_width = indent_width;
        }
    }

    private void update_current_lang () {
        var language = doc.source_view.language;
        if (language != null) {
            var lang_id = language.id;
            lang_selection_listbox.get_children ().foreach ((child) => {
                var lang_entry = ((LangEntry) child);
                if (lang_entry.lang_id == lang_id) {
                    select_language (lang_entry, false);
                }
            });
        } else {
            select_language (normal_entry, false);
        }
    }

    public class FormatButton : Gtk.MenuButton {
        public unowned string text {
            set {
                label_widget.label = "<span font-features='tnum'>%s</span>".printf (value);
            }
        }
        public unowned GLib.Icon? icon {
            owned get {
                return img.gicon;
            }
            set {
                img.gicon = value;
            }
        }

        private Gtk.Image img;
        private Gtk.Label label_widget;

        construct {
            img = new Gtk.Image () {
                icon_size = Gtk.IconSize.SMALL_TOOLBAR
            };

            label_widget = new Gtk.Label (null) {
                ellipsize = Pango.EllipsizeMode.END,
                use_markup = true
            };

            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) {
                halign = Gtk.Align.CENTER
            };
            box.add (img);
            box.add (label_widget);

            add (box);
        }
    }

    public class LangEntry : Gtk.ListBoxRow {
        public string? lang_id { get; construct; }
        public string lang_name { get; construct; }
        public unowned SList<Gtk.RadioButton> group { get; construct; }

        public bool active {
            get {
                return lang_radio.active;
            }

            set {
                lang_radio.active = value;
            }
        }

        public bool selected {
            get {
                return lang_radio.active;
            }

            set {
                lang_radio.toggled.disconnect (radio_toggled);
                lang_radio.active = value;
                lang_radio.toggled.connect (radio_toggled);
            }
        }

        private Gtk.RadioButton lang_radio;
        public LangEntry (string? lang_id, string lang_name, SList<Gtk.RadioButton> group) {
            Object (group: group, lang_id: lang_id, lang_name: lang_name);
        }

        class construct {
            set_css_name (Gtk.STYLE_CLASS_MENUITEM);
        }

        construct {
            lang_radio = new Gtk.RadioButton.with_label (group, lang_name);

            add (lang_radio);
            lang_radio.toggled.connect (radio_toggled);
        }

        private void radio_toggled () {
            if (lang_radio.active) {
                activate ();
            }
        }

        public unowned SList<Gtk.RadioButton> get_radio_group () {
            return lang_radio.get_group ();
        }
    }
}
