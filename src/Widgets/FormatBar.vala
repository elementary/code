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

    private FormatBox line_formatbox;
    private FormatBox lang_formatbox;
    private FormatBox tab_formatbox;
    private Granite.SwitchModelButton space_tab_modelbutton;
    private Gtk.Entry goto_entry;
    private Gtk.InfoBar editorconfig_infobar;
    private Gtk.ListBox lang_selection_listbox;
    private Gtk.MenuButton line_menubutton;
    private Gtk.SourceLanguageManager manager;
    private Gtk.SpinButton width_spinbutton;
    private LangEntry normal_entry;

    private unowned Scratch.Services.Document? doc = null;

    construct {
        get_style_context ().add_class (Gtk.STYLE_CLASS_LINKED);

        manager = Gtk.SourceLanguageManager.get_default ();

        editorconfig_infobar = new Gtk.InfoBar () {
            margin_top = 9,
            margin_end = 9,
            margin_start = 9
        };
        editorconfig_infobar.get_content_area ().add (new Gtk.Label (_("Some settings set by EditorConfig file")));
        editorconfig_infobar.get_style_context ().add_class (Gtk.STYLE_CLASS_FRAME);

        var autoindent_modelbutton = new Granite.SwitchModelButton (_("Automatic Indentation"));

        space_tab_modelbutton = new Granite.SwitchModelButton (_("Insert Spaces Instead Of Tabs"));

        width_spinbutton = new Gtk.SpinButton.with_range (2, 16, 1);

        var width_label = new Gtk.Label (_("Tab width")) {
            halign = START,
            hexpand = true,
            mnemonic_widget = width_spinbutton
        };

        var tab_box = new Gtk.Box (HORIZONTAL, 12) {
            margin_top = 6,
            margin_end = 12,
            margin_start = 12,
        };
        tab_box.add (width_label);
        tab_box.add (width_spinbutton);

        var box = new Gtk.Box (VERTICAL, 0) {
            margin_bottom = 12
        };
        box.add (editorconfig_infobar);
        box.add (autoindent_modelbutton);
        box.add (space_tab_modelbutton);
        box.add (tab_box);
        box.show_all ();

        var tab_popover = new Gtk.Popover (null) {
            position = BOTTOM,
            child = box
        };

        tab_formatbox = new FormatBox ("format-indent-more-symbolic");

        var tab_menubutton = new Gtk.MenuButton () {
            child = tab_formatbox,
            popover = tab_popover
        };

        var lang_selection_filter = new Gtk.SearchEntry () {
            margin_top = 12,
            margin_bottom = 6,
            margin_start = 12,
            margin_end = 12,
            placeholder_text = _("Filter languages")
        };

        lang_selection_listbox = new Gtk.ListBox () {
            selection_mode = SINGLE
        };
        lang_selection_listbox.set_sort_func ((row1, row2) => {
            return ((LangEntry) row1).lang_name.collate (((LangEntry) row2).lang_name);
        });
        lang_selection_listbox.set_filter_func ((row) => {
            //Both are lowercased so that the case doesn't matter when comparing.
            return (((LangEntry) row).lang_name.down ().contains (lang_selection_filter.text.down ().strip ()));
        });

        unowned SList<Gtk.RadioButton> group = null;
        foreach (unowned string id in manager.get_language_ids ()) {
            weak Gtk.SourceLanguage lang = manager.get_language (id);
            var entry = new LangEntry (id, lang.name, group);
            group = entry.get_radio_group ();
            lang_selection_listbox.add (entry);
        }

        normal_entry = new LangEntry (null, _("Plain Text"), group);

        lang_selection_listbox.add (normal_entry);

        var lang_scrolled = new Gtk.ScrolledWindow (null, null) {
            child = lang_selection_listbox,
            hscrollbar_policy = NEVER,
            height_request = 350,
            hexpand = true,
            vexpand = true,
            margin_top = 3,
            margin_bottom = 3
        };

        var popover_content = new Gtk.Box (VERTICAL, 0);
        popover_content.add (lang_selection_filter);
        popover_content.add (lang_scrolled);
        popover_content.show_all ();

        var lang_popover = new Gtk.Popover (null) {
            position = BOTTOM,
            child = popover_content
        };

        lang_formatbox = new FormatBox ("application-x-class-file-symbolic");

        var lang_menubutton = new Gtk.MenuButton () {
            child = lang_formatbox,
            popover = lang_popover,
            tooltip_text = _("Document language")
        };

        goto_entry = new Gtk.Entry ();

        var goto_label = new Gtk.Label (_("Go To Line:")) {
            mnemonic_widget = goto_entry
        };

        var line_box = new Gtk.Box (HORIZONTAL, 12) {
            margin_top = 12,
            margin_bottom = 12,
            margin_start = 12,
            margin_end = 12
        };
        line_box.add (goto_label);
        line_box.add (goto_entry);
        line_box.show_all ();

        var line_popover = new Gtk.Popover (null) {
            position = BOTTOM,
            child = line_box
        };

        line_formatbox = new FormatBox ("view-continuous-symbolic");

        line_menubutton = new Gtk.MenuButton () {
            child = line_formatbox,
            popover = line_popover
        };
        line_menubutton.tooltip_markup = Granite.markup_accel_tooltip (
            ((Scratch.Application) GLib.Application.get_default ()).get_accels_for_action (
                Scratch.MainWindow.ACTION_PREFIX + Scratch.MainWindow.ACTION_GO_TO
            ),
            _("Line number")
        );

        homogeneous = true;
        add (tab_menubutton);
        add (lang_menubutton);
        add (line_menubutton);

        lang_selection_listbox.row_activated.connect ((row) => {
            var lang_entry = ((LangEntry) row);
            select_language (lang_entry);
        });

        lang_selection_filter.changed.connect (() => {
            lang_selection_listbox.invalidate_filter ();
        });

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

        // We need to connect_after because otherwise, the text isn't parsed into the "value" property and we only get the previous value
        goto_entry.activate.connect_after (() => {
            int line, column;
            goto_entry.text = goto_entry.text.replace (":", ".");
            goto_entry.text.scanf ("%i.%i", out line, out column);
            doc.source_view.go_to_line (line, column - 1);
            // Focuses parent to the source view, so that the cursor, which indicates line and column is actually visible.
            doc.source_view.grab_focus ();
        });

        Scratch.settings.changed["indent-width"].connect (format_tab_header_from_global_settings);
        Scratch.settings.changed["spaces-instead-of-tabs"].connect (format_tab_header_from_global_settings);
        Scratch.settings.bind ("auto-indent", autoindent_modelbutton, "active", DEFAULT);

        bind_property ("tab-width-set-by-editor-config", tab_box, "sensitive", INVERT_BOOLEAN | SYNC_CREATE);
    }

    public void activate_line_menubutton () {
        line_menubutton.active = true;
    }

    private void select_language (LangEntry lang, bool update_source_view = true) {
        lang_selection_listbox.select_row (lang);
        lang_formatbox.text = lang.lang_name;
        if (update_source_view) {
            lang.active = true;
            doc.source_view.language = lang.lang_id != null ? manager.get_language (lang.lang_id) : null;
        } else {
            lang.selected = true;
        }
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
    }

    private void format_line_header () {
        var buffer = doc.source_view.buffer;
        var position = buffer.cursor_position;
        Gtk.TextIter iter;
        buffer.get_iter_at_offset (out iter, position);
        var line = iter.get_line () + 1;
        line_formatbox.text = "%d.%d".printf (line, iter.get_line_offset () + 1);
        goto_entry.text = "%d.%d".printf (line, iter.get_line_offset () + 1);
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
            tab_formatbox.text = ngettext ("%d Space", "%d Spaces", indent_width).printf (indent_width);
        } else {
            tab_formatbox.text = ngettext ("%d Tab", "%d Tabs", indent_width).printf (indent_width);
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

    private class FormatBox : Gtk.Box {
        public unowned string text {
            set {
                label_widget.label = "<span font-features='tnum'>%s</span>".printf (value);
            }
        }

        public string icon_name { get; construct; }

        private Gtk.Label label_widget;

        public FormatBox (string icon_name) {
            Object (icon_name: icon_name);
        }

        construct {
            var img = new Gtk.Image.from_icon_name (icon_name, SMALL_TOOLBAR);

            label_widget = new Gtk.Label (null) {
                ellipsize = END,
                use_markup = true
            };

            halign = CENTER;
            add (img);
            add (label_widget);
        }
    }

    private class LangEntry : Gtk.ListBoxRow {
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
