/*-
 * Copyright 2017-2025 elementary, Inc. (https://elementary.io)
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
    public bool tab_style_set_by_editor_config { get; set; default = false; }
    public bool tab_width_set_by_editor_config { get; set; default = false; }
    public FormatButton line_menubutton { get; private set;}
    public Gtk.InfoBar editorconfig_infobar { get; set construct; }
    public Gtk.Box tab_box { get; set construct; }
    public Gtk.SpinButton width_spinbutton { get; set construct; }

    private FormatButton lang_menubutton;
    private FormatButton tab_menubutton;
    private Granite.SwitchModelButton space_tab_modelbutton;
    private Gtk.Entry goto_entry;
    private Gtk.ListBox lang_selection_listbox;
    private Gtk.SearchEntry lang_selection_filter;
    private GtkSource.LanguageManager manager;
    private LangEntry normal_entry;

    private unowned Scratch.Services.Document? doc = null;

    construct {
        add_css_class (Granite.STYLE_CLASS_LINKED);

        manager = GtkSource.LanguageManager.get_default ();

        tab_menubutton = new FormatButton () {
            icon = new ThemedIcon ("format-indent-more-symbolic")
        };

        lang_menubutton = new FormatButton () {
            icon = new ThemedIcon ("application-x-class-file-symbolic"),
            tooltip_text = _("Document language")
        };

        line_menubutton = new FormatButton () {
            icon = new ThemedIcon ("view-continuous-symbolic")
        };
        line_menubutton.tooltip_markup = Granite.markup_accel_tooltip (
            ((Scratch.Application) GLib.Application.get_default ()).get_accels_for_action (
                Scratch.MainWindow.ACTION_PREFIX + Scratch.MainWindow.ACTION_GO_TO
            ),
            _("Line number")
        );

        homogeneous = true;
        append (tab_menubutton);
        append (lang_menubutton);
        append (line_menubutton);

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
            margin_top = 12,
            margin_bottom = 6,
            margin_start = 12,
            margin_end = 12,
            placeholder_text = _("Filter languages")
        };

        lang_selection_filter.changed.connect (() => {
            lang_selection_listbox.invalidate_filter ();
        });

        var lang_scrolled = new Gtk.ScrolledWindow () {
            hscrollbar_policy = Gtk.PolicyType.NEVER,
            height_request = 350,
            hexpand = true,
            vexpand = true,
            margin_top = margin_bottom = 3,
            child = lang_selection_listbox
        };

        normal_entry = new LangEntry (null, _("Plain Text"));
        lang_selection_listbox.append (normal_entry);

        unowned string[]? ids = manager.get_language_ids ();
        foreach (unowned string id in ids) {
            weak GtkSource.Language lang = manager.get_language (id);
            var entry = new LangEntry (id, lang.name) {
                group = (Gtk.CheckButton)normal_entry
            };
            lang_selection_listbox.append (entry);
        }

        var popover_content = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        popover_content.append (lang_selection_filter);
        popover_content.append (lang_scrolled);

        var lang_popover = new Gtk.Popover () {
            position = Gtk.PositionType.BOTTOM,
            child = popover_content
        };
        lang_menubutton.popover = lang_popover;

        lang_selection_listbox.row_activated.connect ((row) => {
            var lang_entry = ((LangEntry) row);
            select_language (lang_entry);
        });
    }

    private void select_language (LangEntry lang, bool update_source_view = true) {
        lang_selection_listbox.select_row (lang);
        lang_menubutton.text = lang.lang_name;
        if (update_source_view) {
            lang.active = true;
            doc.source_view.language = lang.lang_id != null ? manager.get_language (lang.lang_id) : null;
        } else {
            lang.selected = true;
        }
    }

    private void create_tabulation_popover () {
        editorconfig_infobar = new Gtk.InfoBar () {
            margin_top = 9,
            margin_end = 9,
            margin_start = 9
        };
        editorconfig_infobar.add_child (new Gtk.Label (_("Some settings set by EditorConfig file")));
        editorconfig_infobar.add_css_class (Granite.STYLE_CLASS_FRAME);

        var autoindent_modelbutton = new Granite.SwitchModelButton (_("Automatic Indentation"));

        space_tab_modelbutton = new Granite.SwitchModelButton (_("Insert Spaces Instead Of Tabs"));

        var width_label = new Gtk.Label (_("Tab width")) {
            halign = Gtk.Align.START,
            hexpand = true
        };

        width_spinbutton = new Gtk.SpinButton.with_range (2, 16, 1);

        tab_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12) {
            margin_top = 6,
            margin_end = 12,
            margin_start = 12,
        };
        tab_box.append (width_label);
        tab_box.append (width_spinbutton);

        var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) {
            margin_bottom = 12
        };
        box.append (editorconfig_infobar);
        box.append (autoindent_modelbutton);
        box.append (space_tab_modelbutton);
        box.append (tab_box);

        var tab_popover = new Gtk.Popover () {
            position = Gtk.PositionType.BOTTOM,
            child = box
        };
        tab_menubutton.popover = tab_popover;

        Scratch.settings.changed["indent-width"].connect (format_tab_header_from_global_settings);
        Scratch.settings.changed["spaces-instead-of-tabs"].connect (format_tab_header_from_global_settings);
        Scratch.settings.bind ("auto-indent", autoindent_modelbutton, "active", SettingsBindFlags.DEFAULT);

        format_tab_header_from_global_settings ();
        width_spinbutton.value_changed.connect (() => {
            if (!tab_width_set_by_editor_config) {
                Scratch.settings.set_int (
                    "indent-width",
                    (int)width_spinbutton.@value
                );
            }
        });

        space_tab_modelbutton.clicked.connect (() => {
            if (!tab_style_set_by_editor_config) {
                Scratch.settings.set_boolean (
                    "spaces-instead-of-tabs",
                    space_tab_modelbutton.active
                );
            }
        });
    }

    private void format_tab_header_from_global_settings () {
        if (!tab_style_set_by_editor_config) {
            set_insert_spaces_instead_of_tabs (Scratch.settings.get_boolean ("spaces-instead-of-tabs"));
        }

        if (!tab_width_set_by_editor_config) {
            set_tab_width (Scratch.settings.get_int ("indent-width"));
        }

        editorconfig_infobar.revealed = tab_style_set_by_editor_config || tab_width_set_by_editor_config;
        space_tab_modelbutton.sensitive = !tab_style_set_by_editor_config;
        tab_box.sensitive = !tab_width_set_by_editor_config;
    }

    private void format_line_header () {
        var buffer = doc.source_view.buffer;
        var position = buffer.cursor_position;
        Gtk.TextIter iter;
        buffer.get_iter_at_offset (out iter, position);
        var line = iter.get_line () + 1;
        line_menubutton.text = "%d.%d".printf (line, iter.get_line_offset () + 1);
        goto_entry.text = "%d.%d".printf (line, iter.get_line_offset () + 1);
    }

    private void create_line_popover () {
        var goto_label = new Gtk.Label (_("Go To Line:"));
        goto_label.xalign = 1;

        goto_entry = new Gtk.Entry ();

        var line_grid = new Gtk.Grid () {
            margin_top = 12,
            margin_bottom = 12,
            margin_start = 12,
            margin_end = 12
        };
        line_grid.column_spacing = 12;
        line_grid.attach (goto_label, 0, 0, 1, 1);
        line_grid.attach (goto_entry, 1, 0, 1, 1);

        var line_popover = new Gtk.Popover () {
            position = Gtk.PositionType.BOTTOM,
            child = line_grid
        };
        line_menubutton.popover = line_popover;

        // We need to connect_after because otherwise, the text isn't parsed into the "value" property and we only get the previous value
        goto_entry.activate.connect_after (() => {
            int line, column;
            goto_entry.text = goto_entry.text.replace (":", ".");
            goto_entry.text.scanf ("%i.%i", out line, out column);
            doc.source_view.go_to_line (line, column - 1);
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
        width_spinbutton.@value = indent_width;
        if (space_tab_modelbutton.active) {
            tab_menubutton.text = ngettext ("%d Space", "%d Spaces", indent_width).printf (indent_width);
        } else {
            tab_menubutton.text = ngettext ("%d Tab", "%d Tabs", indent_width).printf (indent_width);
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
            var child = lang_selection_listbox.get_first_child ();
            while (child != null) {
               var lang_entry = ((LangEntry) child);
                if (lang_entry.lang_id == lang_id) {
                    select_language (lang_entry, false);
                }

                child = child.get_next_sibling ();
            }
        } else {
            select_language (normal_entry, false);
        }
    }

    public class FormatButton : Gtk.Box {
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

        public Gtk.Popover popover { get; set; }
        public bool active { get; set; }

        private Gtk.Image img;
        private Gtk.Label label_widget;
        private Gtk.MenuButton menu_button;

        construct {
            img = new Gtk.Image () {
                icon_size = Gtk.IconSize.NORMAL
            };

            label_widget = new Gtk.Label (null) {
                ellipsize = Pango.EllipsizeMode.END,
                use_markup = true
            };

            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) {
                halign = Gtk.Align.CENTER
            };
            box.append (img);
            box.append (label_widget);

            menu_button = new Gtk.MenuButton () {
                child = box
            };

            menu_button.set_parent (this);
            bind_property ("popover", menu_button, "popover");
            bind_property ("active", menu_button, "active");
        }
    }

    public class LangEntry : Gtk.ListBoxRow {
        public string? lang_id { get; construct; }
        public string lang_name { get; construct; }
        public Gtk.CheckButton group {
            // private get {
            //     return lang_radio.group;
            // }

            set {
                lang_radio.group = value;
            }
        }
        // public unowned SList<Gtk.CheckButton> group { get; construct; }

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

        public Gtk.CheckButton lang_radio { get; private set; }

        public LangEntry (string? lang_id, string lang_name) {
            Object (lang_id: lang_id, lang_name: lang_name);
        }

        class construct {
            set_css_name (Granite.STYLE_CLASS_MENUITEM);
        }

        construct {
            lang_radio = new Gtk.CheckButton.with_label (lang_name);
            child = lang_radio;
            lang_radio.toggled.connect (radio_toggled);
        }

        private void radio_toggled () {
            if (lang_radio.active) {
                activate ();
            }
        }
    }
}
