// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/***
  BEGIN LICENSE

  Copyright (C) 2011-2012 Giulio Collura <random.cpp@gmail.com>
                2013      Mario Guerriero <mario@elementaryos.org>
                2014      Fabio Zaramella <ffabio.96.x@gmail.com>

  This program is free software: you can redistribute it and/or modify it
  under the terms of the GNU Lesser General Public License version 3, as published
  by the Free Software Foundation.

  This program is distributed in the hope that it will be useful, but
  WITHOUT ANY WARRANTY; without even the implied warranties of
  MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
  PURPOSE.  See the GNU General Public License for more details.

  You should have received a copy of the GNU General Public License along
  with this program.  If not, see <http://www.gnu.org/licenses/>

  END LICENSE
***/

namespace Scratch.Dialogs {
    public class Preferences : Gtk.Dialog {
        private Gtk.Stack main_stack;
        private Gtk.StackSwitcher main_stackswitcher;

        Gtk.ComboBoxText start;
        Gtk.Switch highlight_current_line;
        Gtk.Switch highlight_matching_brackets;
        Gtk.Switch line_break;
        Gtk.Switch draw_spaces;
        Gtk.Switch spaces_instead_of_tabs;
        Gtk.Switch auto_indent;
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
            set_default_size (630, 330);
            resizable = false;
            deletable = false;

            main_stack = new Gtk.Stack ();
            main_stackswitcher = new Gtk.StackSwitcher ();
            main_stackswitcher.set_stack (main_stack);
            main_stackswitcher.halign = Gtk.Align.CENTER;
        }

        private void create_layout (Services.PluginsManager plugins) {
            //create Behavior tab
            this.main_stack.add_titled (get_general_box (), "behavior", _("Behavior"));

            //create Interface tab
            this.main_stack.add_titled (get_editor_box (), "interface", _("Interface"));

            // Plugin hook function
            plugins.hook_preferences_dialog (this);

            if (Peas.Engine.get_default ().get_plugin_list ().length () > 0) {
                //var pbox = plugins.get_view ();
                var pbox = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
                pbox.margin_top = 12;
                pbox.margin_bottom = 12;
                pbox.pack_start (plugins.get_view (), true, true, 12);

                //create Extensions tab
                this.main_stack.add_titled (pbox, "extensions", _("Extensions"));
            }

            // Close button
            var close_button = new Gtk.Button.with_label (_("Close"));
            close_button.clicked.connect (() => {this.destroy ();});

            var button_box = new Gtk.ButtonBox (Gtk.Orientation.HORIZONTAL);
            button_box.set_layout (Gtk.ButtonBoxStyle.END);
            button_box.pack_end (close_button);
            button_box.margin_right = 12;

            // Pack everything into the dialog
            var main_grid = new Gtk.Grid ();
            main_grid.attach (this.main_stackswitcher, 0, 0, 1, 1);
            main_grid.attach (this.main_stack, 0, 1, 1, 1);
            main_grid.attach (button_box, 0, 2, 1, 1);

            ((Gtk.Container) get_content_area ()).add (main_grid);

        }

        private void add_section (Gtk.Grid grid, Gtk.Label name, ref int row) {
            name.use_markup = true;
            name.set_markup (name.get_text ());
            name.get_style_context ().add_class ("h4");
            name.halign = Gtk.Align.START;
            grid.attach (name, 0, row, 1, 1);
            row ++;
        }

         private void add_option (Gtk.Grid grid, Gtk.Widget label, Gtk.Widget switcher, ref int row) {
            label.hexpand = true;
            label.halign = Gtk.Align.END;
            label.margin_left = 20;
            switcher.halign = Gtk.Align.FILL;
            switcher.hexpand = true;

            if (switcher is Gtk.Switch || switcher is Gtk.Entry) { /* then we don't want it to be expanded */
                switcher.halign = Gtk.Align.START;
            }

            grid.attach (label, 0, row, 1, 1);
            grid.attach_next_to (switcher, label, Gtk.PositionType.RIGHT, 3, 1);
            row ++;
        }

        private Gtk.Widget get_general_box () {
            start = new Gtk.ComboBoxText ();
            start.append ("welcome", _("Show welcome screen"));
            start.append ("last-tabs", _("Show last open tabs"));
            Scratch.settings.schema.bind ("show-at-start", start, "active-id", SettingsBindFlags.DEFAULT);

            var autosave = new Gtk.Switch ();
            Scratch.settings.schema.bind ("autosave", autosave, "active", SettingsBindFlags.DEFAULT);
 
            var general_grid = new Gtk.Grid ();
            general_grid.row_spacing = 5;
            general_grid.column_spacing = 5;
            general_grid.margin_left = 12;
            general_grid.margin_right = 12;
            general_grid.margin_top = 12;
            general_grid.margin_bottom = 12;

            int row = 0;
            // General
            var label = new Gtk.Label (_("General:"));
            add_section (general_grid, label, ref row);

            var spacer = new Gtk.Label ("");
            spacer.hexpand = true;

            label = new Gtk.Label (_("When Scratch starts:"));
            add_option (general_grid, label, start, ref row);

            label = new Gtk.Label (_("Save files when changed:"));
            add_option (general_grid, label, autosave, ref row);

            //Tabs
            label = new Gtk.Label (_("Tabs:"));
            add_section (general_grid, label, ref row);

            auto_indent = new Gtk.Switch ();
            Scratch.settings.schema.bind ("auto-indent", auto_indent, "active", SettingsBindFlags.DEFAULT);
            add_option (general_grid, new Gtk.Label (_("Automatic indentation:")), auto_indent, ref row);

            spaces_instead_of_tabs = new Gtk.Switch ();
            var spaces_instead_of_tabs_label = new Gtk.Label (_("Insert spaces instead of tabs:"));
            Scratch.settings.schema.bind ("spaces-instead-of-tabs", spaces_instead_of_tabs, "active", SettingsBindFlags.DEFAULT);
            add_option (general_grid, spaces_instead_of_tabs_label, spaces_instead_of_tabs, ref row);

            var indent_width_label = new Gtk.Label (_("Tab width:"));
            indent_width = new Gtk.SpinButton.with_range (1, 24, 1);
            Scratch.settings.schema.bind ("indent-width", indent_width, "value", SettingsBindFlags.DEFAULT);

            add_option (general_grid, indent_width_label, indent_width, ref row);
            row ++;
            return general_grid;
        }

        //create general settings
        private Gtk.Widget get_editor_box () {
            var content = new Gtk.Grid ();
            content.row_spacing = 5;
            content.column_spacing = 5;
            content.margin_left = 12;
            content.margin_right = 12;
            content.margin_top = 12;
            content.margin_bottom = 12;

            int row = 0;

            var spacer = new Gtk.Label (null);
            spacer.hexpand = true;

            // Editor
            var section_l = new Gtk.Label (_("Editor:"));
            add_section (content, section_l, ref row);

            var line_numbers = new Gtk.Switch ();
            Scratch.settings.schema.bind ("show-line-numbers", line_numbers, "active", SettingsBindFlags.DEFAULT);

            highlight_current_line = new Gtk.Switch ();
            Scratch.settings.schema.bind ("highlight-current-line", highlight_current_line, "active", SettingsBindFlags.DEFAULT);

            highlight_matching_brackets = new Gtk.Switch ();
            Scratch.settings.schema.bind ("highlight-matching-brackets", highlight_matching_brackets, "active", SettingsBindFlags.DEFAULT);

            line_break = new Gtk.Switch ();
            Scratch.settings.schema.bind ("line-break", line_break, "active", SettingsBindFlags.DEFAULT);

            draw_spaces = new Gtk.Switch ();
            Scratch.settings.schema.bind ("draw-spaces", draw_spaces, "active", SettingsBindFlags.DEFAULT);

            add_option (content, new Gtk.Label (_("Highlight current line:")), highlight_current_line, ref row);
            add_option (content, new Gtk.Label (_("Highlight matching brackets:")), highlight_matching_brackets, ref row);
            add_option (content, new Gtk.Label (_("Line wrap:")), line_break, ref row);
            add_option (content, new Gtk.Label (_("Draw spaces:")), draw_spaces, ref row);
            add_option (content, new Gtk.Label (_("Show line numbers:")), line_numbers, ref row);

            var label = new Gtk.Label (_("Line width guide:"));
            var show_right_margin = new Gtk.Switch ();
            Scratch.settings.schema.bind ("show-right-margin", show_right_margin, "active", SettingsBindFlags.DEFAULT);
            var right_margin_position = new Gtk.SpinButton.with_range (1, 250, 1);
            Scratch.settings.schema.bind ("right-margin-position", right_margin_position, "value", SettingsBindFlags.DEFAULT);
            Scratch.settings.schema.bind ("show-right-margin", right_margin_position, "sensitive", SettingsBindFlags.DEFAULT);

            var margin_grid = new Gtk.Grid ();
            margin_grid.add (show_right_margin);
            margin_grid.add (right_margin_position);
            right_margin_position.hexpand = true;
            add_option (content, label, margin_grid, ref row);

            // Font and Color Scheme
            section_l = new Gtk.Label (_("Font and Color Scheme:"));
            add_section (content, section_l, ref row);

            style_scheme = new Gtk.ComboBoxText ();
            populate_style_scheme ();
            Scratch.settings.schema.bind ("style-scheme", style_scheme, "active-id", SettingsBindFlags.DEFAULT);

            use_custom_font = new Gtk.Switch ();

            select_font = new Gtk.FontButton ();

            Scratch.settings.schema.bind ("font", select_font, "font-name", SettingsBindFlags.DEFAULT);
            Scratch.settings.schema.bind ("use-system-font", use_custom_font, "active", SettingsBindFlags.INVERT_BOOLEAN);
            Scratch.settings.schema.bind ("use-system-font", select_font, "sensitive", SettingsBindFlags.INVERT_BOOLEAN);
            var select_font_l = new Gtk.Label (_("Select font:"));
            Scratch.settings.schema.bind ("use-system-font", select_font_l, "sensitive", SettingsBindFlags.INVERT_BOOLEAN);

            add_option (content, new Gtk.Label (_("Color scheme:")), style_scheme, ref row);
            var font_grid = new Gtk.Grid ();
            font_grid.add (use_custom_font);
            font_grid.add (select_font);
            select_font.hexpand = true;
            add_option (content, new Gtk.Label (_("Custom font:")), font_grid, ref row);

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
    }
}
