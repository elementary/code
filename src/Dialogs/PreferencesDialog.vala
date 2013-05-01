// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/***
  BEGIN LICENSE

  Copyright (C) 2011-2012 Giulio Collura <random.cpp@gmail.com>
                2013      Mario Guerriero <mario@elementaryos.org>
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

using Gtk;
using Granite.Widgets;

namespace Scratch.Dialogs {

    public class Preferences : Granite.Widgets.LightWindow {

        public StaticNotebook main_static_notebook;
        
        ComboBoxText start;
        Switch highlight_current_line;
        Switch highlight_matching_brackets;
        Switch line_break;
        Switch draw_spaces;
        Switch spaces_instead_of_tabs;
        Switch auto_indent;
        SpinButton indent_width;
        ComboBoxText style_scheme;
        Switch use_custom_font;
        FontButton select_font;
        
        public Preferences () {

            this.title = _("Preferences");
            this.type_hint = Gdk.WindowTypeHint.DIALOG;
            set_default_size (630, 330);
            resizable = false;
            
            main_static_notebook = new StaticNotebook (false);
            main_static_notebook.margin = 5;
            
            create_layout ();

            // Plugin hook function
            plugins.hook_preferences_dialog (this);

        }

        private void create_layout () {
            // Create main box
            var box = new Box (Orientation.VERTICAL, 0);
            
            //create static notebook Behavior tab
            var behavior_label = new Label (_("Behavior"));
            main_static_notebook.append_page (get_general_box (), behavior_label);
            
            //create static notebook Interface tab
            var interface_label = new Label (_("Interface"));
            main_static_notebook.append_page (get_editor_box (), interface_label);
            
            if (Peas.Engine.get_default ().get_plugin_list ().length () > 0) {
                //create static notebook Extensions tab
                var extensions_label = new Label (_("Extensions"));

                //var pbox = plugins.get_view ();
                var pbox = new Box (Orientation.HORIZONTAL, 5);
                pbox.pack_start (plugins.get_view (), true, true, 5);
                
                main_static_notebook.append_page (pbox, extensions_label);
            }
            
            // Close button
            var close = new Button.with_label (_("Close"));
            close.clicked.connect (() => {
                this.destroy ();
            });
            
            var bbox = new ButtonBox (Orientation.HORIZONTAL);
            bbox.halign = Align.END;
            bbox.margin = 5;
            bbox.add (close);
            
            // Pack everything into the dialog
            box.pack_start (main_static_notebook, true, true, 0);
            box.pack_start (bbox, true, false, 0);
            this.add (box);
        }
        
        void add_section (Gtk.Grid grid, Gtk.Label name, ref int row) {
            name.use_markup = true;
            name.set_markup ("<b>%s</b>".printf (name.get_text ()));
            name.halign = Gtk.Align.START;
            grid.attach (name, 0, row, 1, 1);
            row ++;
        }
        
        void add_option (Gtk.Grid grid, Gtk.Widget label, Gtk.Widget switcher, ref int row) {
            label.hexpand = true;
            label.halign = Align.END;
            label.margin_left = 20;
            switcher.halign = Gtk.Align.FILL;
            switcher.hexpand = true;
            
            if (switcher is Switch || switcher is Entry) { /* then we don't want it to be expanded */
                switcher.halign = Gtk.Align.START;
            }
            
            grid.attach (label, 0, row, 1, 1);
            grid.attach_next_to (switcher, label, Gtk.PositionType.RIGHT, 3, 1);
            row ++;
        }
        
        Gtk.Widget get_general_box () {
            
            start = new ComboBoxText ();
            start.append ("welcome", _("Show welcome screen"));
            start.append ("last-tabs", _("Show last open tabs"));
            Scratch.settings.schema.bind("show-at-start", start, "active-id", SettingsBindFlags.DEFAULT);
            
            var autosave = new Gtk.Switch ();
            Scratch.settings.schema.bind("autosave", autosave, "active", SettingsBindFlags.DEFAULT);
 
            var general_grid = new Gtk.Grid ();
            general_grid.row_spacing = 5;
            general_grid.column_spacing = 5;
            general_grid.margin_left = 15;
            general_grid.margin_right = 5;
            general_grid.margin_top = 15;
            general_grid.margin_bottom = 15;            
            
            int row = 0;
            // General
            var label = new Label (_("General:"));
            add_section (general_grid, label, ref row);
            
            var spacer = new Label ("");
            spacer.hexpand = true;
            
            label = new Label (_("When Scratch starts:"));
            add_option (general_grid, label, start, ref row);
            
            label = new Label (_("Save files when changed:"));
            add_option (general_grid, label, autosave, ref row);
            
            //Tabs
            
            label = new Label (_("Tabs:"));
            add_section (general_grid, label, ref row);
            
            auto_indent = new Switch ();
            Scratch.settings.schema.bind("auto-indent", auto_indent, "active", SettingsBindFlags.DEFAULT);
            add_option (general_grid, new Label (_("Automatic indentation:")), auto_indent, ref row);
            
            spaces_instead_of_tabs = new Switch ();
            var spaces_instead_of_tabs_label = new Label (_("Insert spaces instead of tabs:"));
            Scratch.settings.schema.bind("spaces-instead-of-tabs", spaces_instead_of_tabs, "active", SettingsBindFlags.DEFAULT);
            add_option (general_grid, spaces_instead_of_tabs_label, spaces_instead_of_tabs, ref row);
            
            var indent_width_label = new Label (_("Tab width:"));
            indent_width = new SpinButton.with_range (1, 24, 1);
            Scratch.settings.schema.bind("indent-width", indent_width, "value", SettingsBindFlags.DEFAULT);

            add_option (general_grid, indent_width_label, indent_width, ref row);
            
            row ++;
            
            return general_grid;
        }
        
        Gtk.Widget get_editor_box () {
            //create general settings

            var content = new Gtk.Grid ();
            content.row_spacing = 5;
            content.column_spacing = 5;
            content.margin_left = 15;
            content.margin_right = 5;
            content.margin_top = 15;
            content.margin_bottom = 15;
            
            int row = 0;
            
            var spacer = new Label ("");
            spacer.hexpand = true;
            
            // Editor
            var section_l = new Label (_("Editor:"));
            add_section (content, section_l, ref row);            
            
            var line_numbers = new Switch ();
            Scratch.settings.schema.bind("show-line-numbers", line_numbers, "active", SettingsBindFlags.DEFAULT);
            
            highlight_current_line = new Switch ();
            Scratch.settings.schema.bind("highlight-current-line", highlight_current_line, "active", SettingsBindFlags.DEFAULT);

            highlight_matching_brackets = new Switch ();
            Scratch.settings.schema.bind("highlight-matching-brackets", highlight_matching_brackets, "active", SettingsBindFlags.DEFAULT);
            
            line_break = new Switch ();
            Scratch.settings.schema.bind("line-break", line_break, "active", SettingsBindFlags.DEFAULT);
            
            draw_spaces = new Switch ();
            Scratch.settings.schema.bind("draw-spaces", draw_spaces, "active", SettingsBindFlags.DEFAULT);

            add_option (content, new Label (_("Highlight current line:")), highlight_current_line, ref row);
            add_option (content, new Label (_("Highlight matching brackets:")), highlight_matching_brackets, ref row);           
            add_option (content, new Label (_("Split long text in many lines:")), line_break, ref row);    
            add_option (content, new Label (_("Draw spaces:")), draw_spaces, ref row);           
            add_option (content, new Label (_("Show line numbers:")), line_numbers, ref row);

            
            var label = new Label (_("Line width guide:"));
            var show_right_margin = new Switch ();
            Scratch.settings.schema.bind("show-right-margin", show_right_margin, "active", SettingsBindFlags.DEFAULT);
            var right_margin_position = new SpinButton.with_range (1, 250, 1);
            Scratch.settings.schema.bind("right-margin-position", right_margin_position, "value", SettingsBindFlags.DEFAULT);
            Scratch.settings.schema.bind("show-right-margin", right_margin_position, "sensitive", SettingsBindFlags.DEFAULT);
            //add_option (content, label, show_right_margin, ref row);
            //label = new Label (_("Margin width:"));
            //Scratch.settings.schema.bind("show-right-margin", label, "sensitive", SettingsBindFlags.DEFAULT);
            var margin_grid = new Gtk.Grid ();
            margin_grid.add (show_right_margin);
            margin_grid.add (right_margin_position);
            right_margin_position.hexpand = true;
            add_option (content, label, margin_grid, ref row);
            
            // Font and Color Scheme
            section_l = new Label (_("Font and Color Scheme:"));
            add_section (content, section_l, ref row);
            
            style_scheme = new ComboBoxText ();
            populate_style_scheme ();
            Scratch.settings.schema.bind("style-scheme", style_scheme, "active-id", SettingsBindFlags.DEFAULT);

            use_custom_font = new Switch ();

            select_font = new FontButton ();
            
            Scratch.settings.schema.bind("font", select_font, "font-name", SettingsBindFlags.DEFAULT);
            Scratch.settings.schema.bind("use-system-font", use_custom_font, "active", SettingsBindFlags.INVERT_BOOLEAN);
            Scratch.settings.schema.bind("use-system-font", select_font, "sensitive", SettingsBindFlags.INVERT_BOOLEAN);
            var select_font_l = new Label (_("Select font:"));
            Scratch.settings.schema.bind("use-system-font", select_font_l, "sensitive", SettingsBindFlags.INVERT_BOOLEAN);

            add_option (content, new Label (_("Color scheme:")), style_scheme, ref row);
            var font_grid = new Gtk.Grid ();
            font_grid.add (use_custom_font);
            font_grid.add (select_font);
            select_font.hexpand = true;
            add_option (content, new Label (_("Custom font:")), font_grid, ref row);
            
            return content;
        }
/*
        private string default_font () {

            var settings = new GLib.Settings ("org.gnome.desktop.interface");
            var default_font = settings.get_string ("monospace-font-name");
            return default_font;
        }
*/
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

} // Namespace
