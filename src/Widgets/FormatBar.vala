/*-
 * Copyright (c) 2017 elementary LLC. (https://elementary.io)
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

public class Code.FormatBar : Gtk.Grid {
    private Gtk.SourceLanguageManager manager;
    private FormatButton lang_toggle;
    private Gtk.ListBox lang_selection_listbox;
    private Gtk.SearchEntry lang_selection_filter;
    private LangEntry normal_entry;

    private FormatButton tab_toggle;
    private Gtk.SpinButton tab_width;
    private Gtk.Switch space_tab_switch;
    private Gtk.Switch autoindent_switch;

    public FormatButton line_toggle;
    private Gtk.Entry goto_entry;

    private unowned Scratch.Services.Document? doc = null;

    private const string CSS = """
        .format-bar {
            background-color: @bg_color;
            border-radius: 3px;
        }
    """;

    static construct {
       var provider = new Gtk.CssProvider ();
        try {
            provider.load_from_data (CSS, CSS.length);
            Gtk.StyleContext.add_provider_for_screen (Gdk.Screen.get_default (), provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        } catch (Error e) {
            critical (e.message);
        }
    }

    construct {
        var style_context = get_style_context ();
        style_context.add_class ("format-bar");
        style_context.add_class (Gtk.STYLE_CLASS_LINKED);

        manager = Gtk.SourceLanguageManager.get_default ();

        tab_toggle = new FormatButton ();
        tab_toggle.icon = new ThemedIcon ("format-indent-more-symbolic");
        tab_toggle.tooltip_text = _("Tabs");

        lang_toggle = new FormatButton ();
        lang_toggle.icon = new ThemedIcon ("application-x-class-file-symbolic");
        lang_toggle.tooltip_text = _("Syntax Highlighting");

        line_toggle = new FormatButton ();
        line_toggle.icon = new ThemedIcon ("view-continuous-symbolic");
        line_toggle.tooltip_text = _("Line number");

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
        
        lang_selection_filter = new Gtk.SearchEntry ();
        lang_selection_filter.margin = 6;
        lang_selection_filter.placeholder_text = _("Filter languages");
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
        lang_toggle.bind_property ("active", lang_popover, "visible", GLib.BindingFlags.BIDIRECTIONAL);

        lang_selection_listbox.row_activated.connect ((row) => {
            var lang_entry = ((LangEntry) row);
            lang_entry.active = true;
            lang_selection_listbox.select_row (lang_entry);
            lang_toggle.text = lang_entry.lang_name;
            doc.source_view.language = lang_entry.lang_id != null ? manager.get_language (lang_entry.lang_id) : null;
        });
    }

    private void create_tabulation_popover () {
        var space_tab_label = new Gtk.Label (_("Insert spaces instead of tabs:"));
        space_tab_label.xalign = 1;

        var width_label = new Gtk.Label (_("Tab width:"));
        width_label.xalign = 1;

        var autoindent_label = new Gtk.Label (_("Automatic indentation:"));
        autoindent_label.xalign = 1;

        autoindent_switch = new Gtk.Switch ();
        autoindent_switch.halign = Gtk.Align.START;
        Scratch.settings.schema.bind ("auto-indent", autoindent_switch, "active", SettingsBindFlags.DEFAULT);

        tab_width = new Gtk.SpinButton.with_range (1, 24, 1);
        Scratch.settings.schema.bind ("indent-width", tab_width, "value", SettingsBindFlags.DEFAULT);

        space_tab_switch = new Gtk.Switch ();
        space_tab_switch.halign = Gtk.Align.START;
        Scratch.settings.schema.bind ("spaces-instead-of-tabs", space_tab_switch, "active", SettingsBindFlags.DEFAULT);

        var tab_grid = new Gtk.Grid ();
        tab_grid.margin = 12;
        tab_grid.column_spacing = 12;
        tab_grid.row_spacing = 12;
        tab_grid.attach (autoindent_label, 0, 0, 1, 1);
        tab_grid.attach (autoindent_switch, 1, 0, 1, 1);
        tab_grid.attach (space_tab_label, 0, 1, 1, 1);
        tab_grid.attach (space_tab_switch, 1, 1, 1, 1);
        tab_grid.attach (width_label, 0, 2, 1, 1);
        tab_grid.attach (tab_width, 1, 2, 1, 1);
        tab_grid.show_all ();

        var tab_popover = new Gtk.Popover (tab_toggle);
        tab_popover.position = Gtk.PositionType.BOTTOM;
        tab_popover.add (tab_grid);

        tab_toggle.bind_property ("active", tab_popover, "visible", GLib.BindingFlags.BIDIRECTIONAL);
        Scratch.settings.schema.changed["indent-width"].connect (() => format_tab_header ());
        Scratch.settings.schema.changed["spaces-instead-of-tabs"].connect (() => format_tab_header ());
    }

    private void format_tab_header () {
        var indent_width = Scratch.settings.schema.get_int ("indent-width");
        var spaces_instead_of_tabs = Scratch.settings.schema.get_boolean ("spaces-instead-of-tabs");
        if (doc != null) {
            indent_width = (int)doc.source_view.tab_width;
            spaces_instead_of_tabs = doc.source_view.insert_spaces_instead_of_tabs;
        }
        
        if (spaces_instead_of_tabs) {
            tab_toggle.text = ngettext ("%d Space", "%d Spaces", indent_width).printf (indent_width);
        } else {
            tab_toggle.text = ngettext ("%d Tab", "%d Tabs", indent_width).printf (indent_width);
        }
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

        line_toggle.bind_property ("active", line_popover, "visible", GLib.BindingFlags.BIDIRECTIONAL);
        // We need to connect_after because otherwise, the text isn't parsed into the "value" property and we only get the previous value
        goto_entry.activate.connect_after (() => {
            int line, offset;

            try {
                var regex = new GLib.Regex (":");
                goto_entry.text = regex.replace_literal (goto_entry.text, -1, 0, ".");
            } catch (Error e) {
                critical (e.message);
            }

            goto_entry.text.scanf("%i.%i", out line, out offset);
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
        format_tab_header ();
        format_line_header ();
        this.doc.source_view.buffer.notify["cursor-position"].connect (format_line_header);
    }

    private void update_current_lang () {
        var language = doc.source_view.language;
        if (language != null) {
            var lang_id = language.id;
            lang_selection_listbox.get_children ().foreach ((child) => {
                var lang_entry = ((LangEntry) child);
                if (lang_entry.lang_id == lang_id) {
                    lang_entry.active = true;
                }
            });
        } else {
            normal_entry.active = true;
        }
    }

    public class FormatButton : Gtk.ToggleButton {
        public unowned string text {
            set {
                label_widget.label = value;
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
            width_request = 100;

            img = new Gtk.Image ();
            img.icon_size = Gtk.IconSize.SMALL_TOOLBAR;

            label_widget = new Gtk.Label (null);

            var grid = new Gtk.Grid ();
            grid.halign = Gtk.Align.CENTER;
            grid.add (img);
            grid.add (label_widget);
            add (grid);
        }
    }

    public class LangEntry : Gtk.ListBoxRow {
        public string? lang_id { get; construct; }
        public string lang_name { get; construct; }

        public bool active {
            get {
                return lang_radio.active;
            }

            set {
                lang_radio.active = value;
            }
        }

        private Gtk.RadioButton lang_radio;
        public LangEntry (string? lang_id, string lang_name, SList<Gtk.RadioButton> group) {
            Object (lang_id: lang_id, lang_name: lang_name);

            get_style_context ().add_class ("menuitem");

            lang_radio = new Gtk.RadioButton.with_label (group, lang_name);
            lang_radio.margin_start = 4;
            add (lang_radio);
            lang_radio.toggled.connect (() => {
                if (lang_radio.active) {
                    activate ();
                }
            });
        }

        public unowned SList<Gtk.RadioButton> get_radio_group () {
            return lang_radio.get_group ();
        }
    }
}
