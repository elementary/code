// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*
* Copyright (c) 2011-2016 elementary LLC (http://launchpad.net/scratch)
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 2 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 59 Temple Place - Suite 330,
* Boston, MA 02111-1307, USA.
*
* Authored by: Giulio Collura <random.cpp@gmail.com>
*              Mario Guerriero <mario@elementaryos.org>
*              Fabio Zaramella <ffabio.96.x@gmail.com>
*/

namespace Scratch.Dialogs {
    public class Preferences : Gtk.Dialog {
        private Gtk.Stack main_stack;
        private Gtk.StackSwitcher main_stackswitcher;

        Gtk.ComboBoxText start_combo;
        Gtk.Switch highlight_current_line;
        Gtk.Switch highlight_matching_brackets;
        Gtk.Switch line_break;
        Gtk.Switch spaces_instead_of_tabs_switch;
        Gtk.Switch autoindent_switch;

#if GTKSOURCEVIEW_3_18
        Gtk.Switch show_mini_map;
#endif

        Gtk.SpinButton indent_width;
        Gtk.ComboBoxText style_scheme;
        Gtk.Switch use_custom_font;
        Gtk.FontButton select_font;

        public Preferences (Gtk.Window? parent, Services.PluginsManager plugins) {
            if (parent != null) {
                set_transient_for (parent);
            }

            create_layout (plugins);
        }

        construct {
            title = _("Preferences");
            set_default_size (630, 430);
            resizable = false;
            deletable = false;

            main_stack = new Gtk.Stack ();
            main_stackswitcher = new Gtk.StackSwitcher ();
            main_stackswitcher.set_stack (main_stack);
            main_stackswitcher.halign = Gtk.Align.CENTER;
        }

        private void create_layout (Services.PluginsManager plugins) {
            this.main_stack.add_titled (get_general_box (), "behavior", _("Behavior"));
            this.main_stack.add_titled (get_editor_box (), "interface", _("Interface"));

            // Plugin hook function
            plugins.hook_preferences_dialog (this);

            if (Peas.Engine.get_default ().get_plugin_list ().length () > 0) {
                var pbox = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
                pbox.margin_top = 12;
                pbox.margin_bottom = 12;
                pbox.pack_start (plugins.get_view (), true, true, 12);

                this.main_stack.add_titled (pbox, "extensions", _("Extensions"));
            }

            // Close button
            var close_button = new Gtk.Button.with_label (_("Close"));
            close_button.clicked.connect (() => {this.destroy ();});

            var button_box = new Gtk.ButtonBox (Gtk.Orientation.HORIZONTAL);
            button_box.set_layout (Gtk.ButtonBoxStyle.END);
            button_box.pack_end (close_button);
            button_box.margin = 12;
            button_box.margin_bottom = 0;

            // Pack everything into the dialog
            var main_grid = new Gtk.Grid ();
            main_grid.attach (this.main_stackswitcher, 0, 0, 1, 1);
            main_grid.attach (this.main_stack, 0, 1, 1, 1);
            main_grid.attach (button_box, 0, 2, 1, 1);

            ((Gtk.Container) get_content_area ()).add (main_grid);

        }

        private Gtk.Widget get_general_box () {
            var general_grid = new Gtk.Grid ();
            general_grid.row_spacing = 6;
            general_grid.column_spacing = 12;
            general_grid.margin = 12;

            var general_header = new SettingsHeader (_("General"));

            var start_label = new SettingsLabel (_("When Scratch starts:"));
            start_combo = new Gtk.ComboBoxText ();
            start_combo.append ("welcome", _("Show welcome screen"));
            start_combo.append ("last-tabs", _("Show last open tabs"));
            Scratch.settings.schema.bind ("show-at-start", start_combo, "active-id", SettingsBindFlags.DEFAULT);

            var autosave_label = new SettingsLabel (_("Save files when changed:"));
            var autosave_switch = new SettingsSwitch ("autosave");

            var tabs_header = new SettingsHeader (_("Tabs"));

            var autoindent_label = new SettingsLabel (_("Automatic indentation:"));
            autoindent_switch = new SettingsSwitch ("auto-indent");

            var spaces_instead_of_tabs_label = new SettingsLabel (_("Insert spaces instead of tabs:"));
            spaces_instead_of_tabs_switch = new SettingsSwitch ("spaces-instead-of-tabs");

            var indent_width_label = new SettingsLabel (_("Tab width:"));
            indent_width = new Gtk.SpinButton.with_range (1, 24, 1);
            Scratch.settings.schema.bind ("indent-width", indent_width, "value", SettingsBindFlags.DEFAULT);

            general_grid.attach (general_header, 0, 0, 2, 1);
            general_grid.attach (start_label, 0, 1, 1, 1);
            general_grid.attach (start_combo, 1, 1, 1, 1);
            general_grid.attach (autosave_label, 0, 2, 1, 1);
            general_grid.attach (autosave_switch, 1, 2, 1, 1);
            general_grid.attach (tabs_header, 0, 3, 2, 1);
            general_grid.attach (autoindent_label, 0, 4, 1, 1);
            general_grid.attach (autoindent_switch, 1, 4, 1, 1);
            general_grid.attach (spaces_instead_of_tabs_label, 0, 5, 1, 1);
            general_grid.attach (spaces_instead_of_tabs_switch, 1, 5, 1, 1);
            general_grid.attach (indent_width_label, 0, 6, 1, 1);
            general_grid.attach (indent_width, 1, 6, 1, 1);

            return general_grid;
        }

        private Gtk.Widget get_editor_box () {
            var content = new Gtk.Grid ();
            content.row_spacing = 6;
            content.column_spacing = 12;
            content.margin = 12;

            var editor_header = new SettingsHeader (_("Editor"));

            var highlight_current_line_label = new SettingsLabel (_("Highlight current line:"));
            highlight_current_line = new SettingsSwitch ("highlight-current-line");

            var highlight_matching_brackets_label = new SettingsLabel (_("Highlight matching brackets:"));
            highlight_matching_brackets = new SettingsSwitch ("highlight-matching-brackets");

            var line_break_label = new SettingsLabel (_("Line wrap:"));
            line_break = new SettingsSwitch ("line-break");

            var draw_spaces_label = new SettingsLabel (_("Draw Spaces:"));
            var draw_spaces_combo = new Gtk.ComboBoxText ();
            draw_spaces_combo.append ("Never", _("Never"));
            draw_spaces_combo.append ("For Selection", _("For selected text"));
            draw_spaces_combo.append ("Always", _("Always"));
            Scratch.settings.schema.bind ("draw-spaces", draw_spaces_combo, "active-id", SettingsBindFlags.DEFAULT);

            var line_numbers_label = new SettingsLabel (_("Show line numbers:"));
            var line_numbers = new SettingsSwitch ("show-line-numbers");

#if GTKSOURCEVIEW_3_18
            var show_mini_map_label = new SettingsLabel (_("Show Mini Map:"));
            show_mini_map = new SettingsSwitch ("show-mini-map");
#endif

            var show_right_margin_label = new SettingsLabel (_("Line width guide:"));
            var show_right_margin = new SettingsSwitch ("show-right-margin");

            var right_margin_position = new Gtk.SpinButton.with_range (1, 250, 1);
            right_margin_position.hexpand = true;
            Scratch.settings.schema.bind ("right-margin-position", right_margin_position, "value", SettingsBindFlags.DEFAULT);
            Scratch.settings.schema.bind ("show-right-margin", right_margin_position, "sensitive", SettingsBindFlags.DEFAULT);

            var font_header = new SettingsHeader (_("Font and Color Scheme"));

            var style_scheme_label = new SettingsLabel (_("Color scheme:"));
            style_scheme = new Gtk.ComboBoxText ();
            populate_style_scheme ();
            Scratch.settings.schema.bind ("style-scheme", style_scheme, "active-id", SettingsBindFlags.DEFAULT);

            var use_custom_font_label = new SettingsLabel (_("Custom font:"));
            use_custom_font = new Gtk.Switch ();
            use_custom_font.halign = Gtk.Align.START;
            Scratch.settings.schema.bind ("use-system-font", use_custom_font, "active", SettingsBindFlags.INVERT_BOOLEAN);

            select_font = new Gtk.FontButton ();
            select_font.hexpand = true;
            Scratch.settings.schema.bind ("font", select_font, "font-name", SettingsBindFlags.DEFAULT);
            Scratch.settings.schema.bind ("use-system-font", select_font, "sensitive", SettingsBindFlags.INVERT_BOOLEAN);

            content.attach (editor_header, 0, 0, 3, 1);
            content.attach (highlight_current_line_label, 0, 1, 1, 1);
            content.attach (highlight_current_line, 1, 1, 1, 1);
            content.attach (highlight_matching_brackets_label, 0, 2, 1, 1);
            content.attach (highlight_matching_brackets, 1, 2, 1, 1);
            content.attach (line_break_label, 0, 3, 1, 1);
            content.attach (line_break, 1, 3, 1, 1);
            content.attach (draw_spaces_label, 0, 4, 1, 1);
            content.attach (draw_spaces_combo, 1, 4, 1, 1);
            content.attach (line_numbers_label, 0, 5, 1, 1);
            content.attach (line_numbers, 1, 5, 1, 1);
#if GTKSOURCEVIEW_3_18
            content.attach (show_mini_map_label, 0, 6, 1, 1);
            content.attach (show_mini_map, 1, 6, 1, 1);
#endif
            content.attach (show_right_margin_label, 0, 7, 1, 1);
            content.attach (show_right_margin, 1, 7, 1, 1);
            content.attach (right_margin_position, 2, 7, 1, 1);
            content.attach (font_header, 0, 8, 3, 1);
            content.attach (style_scheme_label, 0, 9, 1, 1);
            content.attach (style_scheme, 1, 9, 2, 1);
            content.attach (use_custom_font_label , 0, 10, 1, 1);
            content.attach (use_custom_font, 1, 10, 1, 1);
            content.attach (select_font, 2, 10, 1, 1);

            return content;
        }

        private void populate_style_scheme () {
            string[] scheme_ids;
            var scheme_manager = new Gtk.SourceStyleSchemeManager ();
            scheme_ids = scheme_manager.get_scheme_ids ();

            foreach (string scheme_id in scheme_ids) {
                var scheme = scheme_manager.get_scheme (scheme_id);
                style_scheme.append (scheme.id, scheme.name);
            }
        }

        private class SettingsHeader : Gtk.Label {
            public SettingsHeader (string text) {
                label = text;
                get_style_context ().add_class ("h4");
                halign = Gtk.Align.START;
            }
        }

        private class SettingsLabel : Gtk.Label {
            public SettingsLabel (string text) {
                label = text;
                halign = Gtk.Align.END;
                margin_start = 12;
            }
        }

        private class SettingsSwitch : Gtk.Switch {
            public SettingsSwitch (string setting) {
                halign = Gtk.Align.START;
                Scratch.settings.schema.bind (setting, this, "active", SettingsBindFlags.DEFAULT);
            }
        }
    }
}
