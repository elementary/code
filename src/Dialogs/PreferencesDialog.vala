// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/***
  BEGIN LICENSE

  Copyright (C) 2011 Giulio Collura <random.cpp@gmail.com>
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

    public class Preferences : Dialog {

        private MainWindow window;

        public StaticNotebook main_static_notebook;
        
        ComboBoxText start;
        CheckButton show_right_margin;
        CheckButton line_numbers;
        Switch highlight_current_line;
        Switch highlight_matching_brackets;
        Switch spaces_instead_of_tabs;
        Switch auto_indent;
        SpinButton indent_width;
        ComboBoxText style_scheme;
        Switch use_system_font;
        FontButton select_font;

        public Preferences (string? title, MainWindow? window) {

            this.window = window;
            this.title = title;
            this.type_hint = Gdk.WindowTypeHint.DIALOG;
            this.set_transient_for (window);
            set_default_size (600, 300);
            //resizable = false;

            main_static_notebook = new StaticNotebook ();

            create_layout ();

            Scratch.plugins.hook_preferences_dialog (this);

        }

        private void create_layout () {


            //create static notebook
            var general = new Label (_("Behavior"));
            main_static_notebook.append_page (get_general_box (), general);
            
            //create static notebook
            var editor = new Label (_("Interface"));
            main_static_notebook.append_page (get_editor_box (), editor);
            
            //create static notebook
            var plugins_label = new Label (_("Exstensions"));

            
            /* Plugin management, might be better in PluginManager */
            var view = new Gtk.TreeView();
            var listmodel = new Gtk.ListStore (2, typeof (string), typeof (bool));
            view.set_model (listmodel);
            view.set_headers_visible (false);
            var column = new Gtk.TreeViewColumn();

            var text_renderer = new Gtk.CellRendererText();
            column.pack_start(text_renderer, true);
            column.set_attributes(text_renderer, "text", 0);
            var toggle = new Gtk.CellRendererToggle();
            toggle.toggled.connect_after ((toggle, path) =>
            {
                var tree_path = new Gtk.TreePath.from_string (path);
                Gtk.TreeIter iter;
                listmodel.get_iter (out iter, tree_path);
                var name = Value(typeof(string));
                var active = Value(typeof(bool));
                listmodel.get_value(iter, 0, out name);
                listmodel.get_value(iter, 1, out active);
                listmodel.set (iter, 1, !active.get_boolean());
                if(active.get_boolean() == false)
                {
                    enable_plugin(name.get_string());
                }
                else
                {
                    disable_plugin(name.get_string());
                }
            });
            column.pack_start(toggle, false);
            column.set_attributes(toggle, "active", 1);

            view.insert_column(column, -1);

            Gtk.TreeIter iter;

            int count = 0;
            List<string> plugin_lists = plugins.get_available_plugins ();
            foreach(string plugin_name in plugin_lists)
            {
                count ++;
                listmodel.append (out iter);
                listmodel.set (iter, 0, plugin_name, 1, plugin_name in settings.schema.get_strv("plugins-enabled"));
            }

            //pbox is only for fix the padding
            var pbox = new HBox (false, 0);
            pbox.pack_start (view, true, true, 5);

            if(count > 0) main_static_notebook.append_page (pbox, plugins_label);

            ((Gtk.Box)get_content_area()).add (main_static_notebook);
            
            add_button (Stock.CLOSE, ResponseType.ACCEPT);
        }
        
        void add_section (Gtk.Grid grid, Gtk.Label name, ref int row) {
            name.use_markup = true;
            name.set_markup ("<b>%s</b>".printf (name.get_text ()));
            grid.attach (name, 1, row, 1, 1);
            row ++;
        }
        
        void add_option (Gtk.Grid grid, Gtk.Widget label, Gtk.Widget switcher, ref int row, bool expand_switcher = false, Gtk.Widget? third_child) {
            if (!expand_switcher) {
                label.halign = Align.END;
                switcher.halign = Gtk.Align.END;
            }
            else if (expand_switcher) {
                label.halign = Gtk.Align.END;
                switcher.hexpand = true;
            }
            var spacer = new Label ("\t\t\t"); //TODO: it needs a more elegant fix
            grid.attach (spacer, 1, row, 1, 1);
            grid.attach_next_to (label, spacer, Gtk.PositionType.RIGHT, 1, 1);
            grid.attach_next_to (switcher, label, Gtk.PositionType.RIGHT, 1, 1);
            
            if (!expand_switcher) {
                 label.halign = Align.END;
                 switcher.halign = Gtk.Align.END;
                 grid.attach_next_to (third_child, switcher, Gtk.PositionType.RIGHT, 1, 1);
             }
             else if (expand_switcher) {
                 label.halign = Gtk.Align.END;
                 switcher.hexpand = false;
                 switcher.halign = Gtk.Align.START;
             }
            
            row ++;
        }
        
        void add_combo_option (Gtk.Grid grid, Gtk.Widget label, Gtk.Widget combo, ref int row) {
            var spacer = new Label ("\t\t\t"); //TODO: it need a more elegant fix
            label.halign = Gtk.Align.END;
            combo.hexpand = true;
            grid.attach (spacer, 1, row, 1, 1);
            grid.attach_next_to (label, spacer, Gtk.PositionType.RIGHT, 1, 1);
            grid.attach_next_to (combo, label, Gtk.PositionType.RIGHT, 2, 1);
        
            row++;
        }
        
        Gtk.Widget get_general_box () {
            
            start = new ComboBoxText ();
            start.append ("welcome", _("Show welcome screen"));
            start.append ("last-tabs", _("Show last open tabs"));
            Scratch.settings.schema.bind("show-at-start", start, "active-id", SettingsBindFlags.DEFAULT);
            
            var case_sensitive = new Gtk.Switch ();
            Scratch.settings.schema.bind("search-sensitive", case_sensitive, "active", SettingsBindFlags.DEFAULT);
 
            var general_grid = new Gtk.Grid ();
            general_grid.row_spacing = 5;
            general_grid.column_spacing = 5;
            general_grid.margin_left = 12;
            general_grid.margin_right = 12;
            general_grid.margin_top = 12;
            general_grid.margin_bottom = 12;            
            
            int row = 0;
            // General
            var label = new Label (_("General") + ":");
            add_section (general_grid, label, ref row);
            
            var spacer = new Label ("");
            spacer.hexpand = true;
            
            label = new Label (_("When Scratch starts") + ":");
            add_combo_option (general_grid, label, start, ref row);
            
            label = new Label (_("Case sensitive search") + ":");
            add_option (general_grid, label, case_sensitive, ref row, true, spacer);
            
            //Tabs
            
            label = new Label (_("Tabs") + ":");
            add_section (general_grid, label, ref row);
            
            auto_indent = new Switch ();
            Scratch.settings.schema.bind("auto-indent", auto_indent, "active", SettingsBindFlags.DEFAULT);
            add_option (general_grid, new Label (_("Automatic indentation") + ":"), auto_indent, ref row, true, spacer);
            
            spaces_instead_of_tabs = new Switch ();
            Scratch.settings.schema.bind("spaces-instead-of-tabs", spaces_instead_of_tabs, "active", SettingsBindFlags.DEFAULT);
            add_option (general_grid, new Label (_("Insert spaces instead of tabs") + ":"), spaces_instead_of_tabs, ref row, true, spacer);

            indent_width = new SpinButton.with_range (1, 24, 1);
            Scratch.settings.schema.bind("indent-width", indent_width, "value", SettingsBindFlags.DEFAULT);
            add_option (general_grid, new Label (_("Tab width") + ":"), indent_width, ref row, true, spacer);
            
            row ++;
            
            return general_grid;
        }
        
        Gtk.Widget get_editor_box () {
            //create general settings

            var content = new Gtk.Grid ();
            content.row_spacing = 5;
            content.column_spacing = 5;
            content.margin_left = 12;
            content.margin_right = 12;
            content.margin_top = 12;
            content.margin_bottom = 12;
            
            int row = 0;
            
            var spacer = new Label ("");
            spacer.hexpand = true;
            
            // Editor
            var section_l = new Label (_("Editor") + ":");
            add_section (content, section_l, ref row);            
            
            line_numbers = new CheckButton ();
            Scratch.settings.schema.bind("show-line-numbers", line_numbers, "active", SettingsBindFlags.DEFAULT);
            
            highlight_current_line = new Switch ();
            Scratch.settings.schema.bind("highlight-current-line", highlight_current_line, "active", SettingsBindFlags.DEFAULT);

            highlight_matching_brackets = new Switch ();
            Scratch.settings.schema.bind("highlight-matching-brackets", highlight_matching_brackets, "active", SettingsBindFlags.DEFAULT);

            add_option (content, new Label (_("Highlight current line") + ":"), highlight_current_line, ref row, false, null);
            add_option (content, new Label (_("Highlight matching brackets") + ":"), highlight_matching_brackets, ref row, false, null);           
            add_option (content, new Label (_("Show line numbers") + ":"), line_numbers, ref row, true, spacer);
            
            var label = new Label (_("Right margin"));
            add_option (content, label, show_right_margin, ref row, true, spacer);
            

            
            label = new Label (_("Show margin on right") + ":");
            Scratch.settings.schema.bind("show-right-margin", label, "sensitive", SettingsBindFlags.DEFAULT);
            show_right_margin = new CheckButton ();
            Scratch.settings.schema.bind("show-right-margin", show_right_margin, "active", SettingsBindFlags.DEFAULT);
            var right_margin_position = new SpinButton.with_range (1, 250, 1);
            Scratch.settings.schema.bind("right-margin-position", right_margin_position, "value", SettingsBindFlags.DEFAULT);
            Scratch.settings.schema.bind("show-right-margin", right_margin_position, "sensitive", SettingsBindFlags.DEFAULT);
            add_option (content, label, show_right_margin, ref row, true, spacer);
            label = new Label (_("Margin width") + ":");
            add_option (content, label, right_margin_position, ref row, true, spacer);
            
            // Font and Colors
            section_l = new Label (_("Font and colors") + ":");
            add_section (content, section_l, ref row);
            
            style_scheme = new ComboBoxText ();
            populate_style_scheme ();
            Scratch.settings.schema.bind("style-scheme", style_scheme, "active-id", SettingsBindFlags.DEFAULT);

            use_system_font = new Switch ();

            select_font = new FontButton ();
            
            Scratch.settings.schema.bind("font", select_font, "font-name", SettingsBindFlags.DEFAULT);
            Scratch.settings.schema.bind("use-system-font", use_system_font, "active", SettingsBindFlags.DEFAULT);
            Scratch.settings.schema.bind("use-system-font", select_font, "sensitive", SettingsBindFlags.INVERT_BOOLEAN);
            var select_font_l = new Label (_("Select font:"));
            Scratch.settings.schema.bind("use-system-font", select_font_l, "sensitive", SettingsBindFlags.INVERT_BOOLEAN);

            add_combo_option (content, new Label (_("Color scheme:")), style_scheme, ref row);
            add_option (content, new Label (_("System fixed width font (%s):").printf(default_font())), use_system_font, ref row, false, select_font);
            
            return content;
        }

        void disable_plugin(string name)
        {

            if(!plugins.disable_plugin(name))
            {
                critical("Can't properly disable the plugin %s!", name);
            }
        }

        void enable_plugin(string name)
        {
            plugins.enable_plugin(name);
        }

        private string default_font () {

            var settings = new GLib.Settings ("org.gnome.desktop.interface");
            var default_font = settings.get_string ("monospace-font-name");
            return default_font;
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

} // Namespace
