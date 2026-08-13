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
    private Gtk.MenuButton line_menubutton;
    private FormatBox lang_formatbox;
    private FormatBox tab_formatbox;
    private Granite.SwitchModelButton space_tab_modelbutton;
    private Gtk.Entry goto_entry;
    private Gtk.InfoBar editorconfig_infobar;
    private Gtk.SourceLanguageManager manager;
    private Gtk.SpinButton width_spinbutton;
    private SimpleAction language_action;

    private unowned Scratch.Services.Document? current_doc = null;

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

        var lang_selection_listbox = new Gtk.ListBox () {
            selection_mode = SINGLE
        };
        lang_selection_listbox.set_sort_func ((row1, row2) => {
            return ((LangEntry) row1).lang_name.collate (((LangEntry) row2).lang_name);
        });
        lang_selection_listbox.set_filter_func ((row) => {
            //Both are lowercased so that the case doesn't matter when comparing.
            return (((LangEntry) row).lang_name.down ().contains (lang_selection_filter.text.down ().strip ()));
        });

        foreach (unowned string id in manager.get_language_ids ()) {
            weak Gtk.SourceLanguage lang = manager.get_language (id);
            var entry = new LangEntry (id, lang.name);
            lang_selection_listbox.add (entry);
        }

        var normal_entry = new LangEntry ("", _("Plain Text"));
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

        language_action = new SimpleAction.stateful ("language", VariantType.STRING, new Variant.string (""));
        language_action.change_state.connect ((parameter) => {
            language_action.set_state (parameter);
            var lang_id = parameter.get_string ();

            if (current_doc.source_view.language.id != lang_id) { // Avoids loop
                current_doc.source_view.language = lang_id != "" ? manager.get_language (lang_id) : null;
            }

            if (lang_id != "") {
                unowned var lang = manager.get_language (lang_id);
                lang_formatbox.text = lang.name;
            } else {
                lang_formatbox.text = _("Plain Text");
                current_doc.source_view.language = null;
            }
        });

        var action_group = new SimpleActionGroup ();
        action_group.add_action (language_action);
        insert_action_group ("format", action_group);

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

        // We need to connect_after because otherwise, the text isn't parsed into the "value" property
        // and we only get the previous value
        goto_entry.activate.connect_after (() => {
            int line, column;
            goto_entry.text = goto_entry.text.replace (":", ".");
            goto_entry.text.scanf ("%i.%i", out line, out column);
            current_doc.source_view.go_to_line (line, column - 1);
            // Focuses parent to the source view, so that the cursor, which indicates line and column
            // is actually visible.
            current_doc.source_view.grab_focus ();
        });

        Scratch.settings.changed["indent-width"].connect (format_tab_header_from_global_settings);
        Scratch.settings.changed["spaces-instead-of-tabs"].connect (format_tab_header_from_global_settings);
        Scratch.settings.bind ("auto-indent", autoindent_modelbutton, "active", DEFAULT);

        bind_property ("tab-width-set-by-editor-config", tab_box, "sensitive", INVERT_BOOLEAN | SYNC_CREATE);
    }

    public void activate_line_menubutton () {
        line_menubutton.active = true;
    }

    public void set_document (Scratch.Services.Document doc) requires (doc != null) {
        current_doc = doc;
        if (doc.loading) {
            Timeout.add (200, () => {
                if (doc.loading) {
                    return Source.CONTINUE;
                } else {
                    update_widgets ();
                    return Source.REMOVE;
                }
            });
        } else {
            update_widgets ();
        }
    }

    public void set_insert_spaces_instead_of_tabs (bool use_spaces) requires (current_doc != null) {
        space_tab_modelbutton.active = use_spaces;
        current_doc.source_view.insert_spaces_instead_of_tabs = use_spaces;
    }

    public void set_tab_width (int indent_width) requires (current_doc != null) {
        width_spinbutton.@value = indent_width;
        if (space_tab_modelbutton.active) {
            tab_formatbox.text = ngettext ("%d Space", "%d Spaces", indent_width).printf (indent_width);
        } else {
            tab_formatbox.text = ngettext ("%d Tab", "%d Tabs", indent_width).printf (indent_width);
        }

        current_doc.source_view.indent_width = indent_width;
        current_doc.source_view.tab_width = indent_width;
    }

    private void update_widgets () requires (current_doc != null) {
        update_current_lang ();
        format_tab_header_from_global_settings ();
        format_line_header ();
        current_doc.source_view.buffer.notify["cursor-position"].connect (format_line_header);
    }

    private void format_line_header () requires (current_doc != null) {
        var buffer = current_doc.source_view.buffer;
        var position = buffer.cursor_position;
        Gtk.TextIter iter;
        buffer.get_iter_at_offset (out iter, position);
        var line = iter.get_line () + 1;
        line_formatbox.text = "%d.%d".printf (line, iter.get_line_offset () + 1);
        goto_entry.text = "%d.%d".printf (line, iter.get_line_offset () + 1);
    }

    private void update_current_lang () requires (current_doc != null) {
        var language = current_doc.source_view.language;
        var lang_id = language != null ? language.id : "";
        language_action.change_state (new Variant.string (lang_id));
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
        public string lang_id { get; construct; }
        public string lang_name { get; construct; }

        public LangEntry (string lang_id, string lang_name) {
            Object (lang_id: lang_id, lang_name: lang_name);
        }

        class construct {
            set_css_name (Gtk.STYLE_CLASS_MENUITEM);
        }

        construct {
            var lang_checkbutton = new Gtk.CheckButton.with_label (lang_name) {
                action_name = "format.language",
                action_target = new Variant.string (lang_id)
            };

            child = lang_checkbutton;
        }
    }
}
