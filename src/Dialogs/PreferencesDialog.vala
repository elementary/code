// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*
* Copyright (c) 2011-2017 elementary LLC (https://elementary.io)
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
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA.
*
* Authored by: Giulio Collura <random.cpp@gmail.com>
*              Mario Guerriero <mario@elementaryos.org>
*              Fabio Zaramella <ffabio.96.x@gmail.com>
*/

namespace Scratch.Dialogs {
    public class Preferences : Gtk.Dialog {
        private Gtk.Stack main_stack;
        private Gtk.Switch highlight_current_line;
        private Gtk.Switch highlight_matching_brackets;
        private Gtk.ComboBoxText style_scheme;
        private Gtk.Switch use_custom_font;
        private Gtk.FontButton select_font;

#if GTKSOURCEVIEW_3_18
        private Gtk.Switch show_mini_map;
#endif

        public Preferences (Gtk.Window? parent, Services.PluginsManager plugins) {
            Object (
                border_width: 5,
                deletable: false,
                resizable: false,
                title: _("Preferences"),
                transient_for: parent
            );

            create_layout (plugins);
        }

        construct {
            var indent_width = new Gtk.SpinButton.with_range (1, 24, 1);
            Scratch.settings.schema.bind ("indent-width", indent_width, "value", SettingsBindFlags.DEFAULT);

            var general_grid = new Gtk.Grid ();
            general_grid.column_spacing = 12;
            general_grid.row_spacing = 6;
            general_grid.attach (new Granite.HeaderLabel (_("General")), 0, 0, 2, 1);
            general_grid.attach (new SettingsLabel (_("Save files when changed:")), 0, 1, 1, 1);
            general_grid.attach (new SettingsSwitch ("autosave"), 1, 1, 1, 1);
            general_grid.attach (new Granite.HeaderLabel (_("Tabs")), 0, 2, 2, 1);
            general_grid.attach (new SettingsLabel (_("Automatic indentation:")), 0, 3, 1, 1);
            general_grid.attach (new SettingsSwitch ("auto-indent"), 1, 3, 1, 1);
            general_grid.attach (new SettingsLabel (_("Insert spaces instead of tabs:")), 0, 4, 1, 1);
            general_grid.attach (new SettingsSwitch ("spaces-instead-of-tabs"), 1, 4, 1, 1);
            general_grid.attach (new SettingsLabel (_("Tab width:")), 0, 5, 1, 1);
            general_grid.attach (indent_width, 1, 5, 1, 1);

            main_stack = new Gtk.Stack ();
            main_stack.margin = 6;
            main_stack.margin_bottom = 18;
            main_stack.margin_top = 24;
            main_stack.add_titled (general_grid, "behavior", _("Behavior"));
            main_stack.add_titled (get_editor_box (), "interface", _("Interface"));

            var main_stackswitcher = new Gtk.StackSwitcher ();
            main_stackswitcher.set_stack (main_stack);
            main_stackswitcher.halign = Gtk.Align.CENTER;

            var main_grid = new Gtk.Grid ();
            main_grid.attach (main_stackswitcher, 0, 0, 1, 1);
            main_grid.attach (main_stack, 0, 1, 1, 1);

            get_content_area ().add (main_grid);

            var close_button = new Gtk.Button.with_label (_("Close"));
            close_button.clicked.connect (() => {
                destroy ();
            });

            add_action_widget (close_button, 0);
        }

        private void create_layout (Services.PluginsManager plugins) {
            // Plugin hook function
            plugins.hook_preferences_dialog (this);

            if (Peas.Engine.get_default ().get_plugin_list ().length () > 0) {
                var pbox = plugins.get_view ();
                pbox.vexpand = true;

                main_stack.add_titled (pbox, "extensions", _("Extensions"));
            }
        }

        private Gtk.Widget get_editor_box () {
            var content = new Gtk.Grid ();
            content.row_spacing = 6;
            content.column_spacing = 12;

            var editor_header = new Granite.HeaderLabel (_("Editor"));

            var highlight_current_line_label = new SettingsLabel (_("Highlight current line:"));
            highlight_current_line = new SettingsSwitch ("highlight-current-line");

            var highlight_matching_brackets_label = new SettingsLabel (_("Highlight matching brackets:"));
            highlight_matching_brackets = new SettingsSwitch ("highlight-matching-brackets");

            var draw_spaces_label = new SettingsLabel (_("Draw Spaces:"));
            var draw_spaces_combo = new Gtk.ComboBoxText ();
            draw_spaces_combo.append ("Never", _("Never"));
            draw_spaces_combo.append ("For Selection", _("For selected text"));
            draw_spaces_combo.append ("Always", _("Always"));
            Scratch.settings.schema.bind ("draw-spaces", draw_spaces_combo, "active-id", SettingsBindFlags.DEFAULT);


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

            var font_header = new Granite.HeaderLabel (_("Font and Color Scheme"));

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
            content.attach (draw_spaces_label, 0, 3, 1, 1);
            content.attach (draw_spaces_combo, 1, 3, 2, 1);

#if GTKSOURCEVIEW_3_18
            content.attach (show_mini_map_label, 0, 5, 1, 1);
            content.attach (show_mini_map, 1, 5, 1, 1);
#endif

            content.attach (show_right_margin_label, 0, 6, 1, 1);
            content.attach (show_right_margin, 1, 6, 1, 1);
            content.attach (right_margin_position, 2, 6, 1, 1);
            content.attach (font_header, 0, 7, 3, 1);
            content.attach (style_scheme_label, 0, 8, 1, 1);
            content.attach (style_scheme, 1, 8, 2, 1);
            content.attach (use_custom_font_label , 0, 9, 1, 1);
            content.attach (use_custom_font, 1, 9, 1, 1);
            content.attach (select_font, 2, 9, 1, 1);

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
                valign = Gtk.Align.CENTER;
                Scratch.settings.schema.bind (setting, this, "active", SettingsBindFlags.DEFAULT);
            }
        }
    }
}
