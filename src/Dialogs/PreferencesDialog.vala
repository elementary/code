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
        
        private Switch modal_dialog;
        private Switch show_right_margin;
        private Switch line_numbers;
        private Switch highlight_current_line;
        private Switch highlight_matching_brackets;
        private Switch spaces_instead_of_tabs;
        private Switch auto_indent;
        private SpinButton indent_width;
        private ComboBoxText style_scheme;
        private Switch use_system_font;
        private FontButton select_font;

        public Preferences (string? title, MainWindow? window) {

            this.window = window;
            this.title = title;
            this.type_hint = Gdk.WindowTypeHint.DIALOG;
            this.set_modal (Scratch.settings.modal_dialog);
            this.set_transient_for (window);
            set_default_size (600, 300);
            //resizable = false;

            main_static_notebook = new StaticNotebook ();

            create_layout ();

            Scratch.plugins.hook_preferences_dialog (this);

        }

        private void create_layout () {


            //create static notebook
            var general = new Label (_("General"));
            main_static_notebook.append_page (get_general_box (), general);
            
            //create static notebook
            var editor = new Label (_("Editor"));
            main_static_notebook.append_page (get_editor_box (), editor);

            //create static notebook
            var fonts = new Label (_("Fonts and colors"));
            main_static_notebook.append_page (get_fonts_box (), fonts);
            
            //create static notebook
            var plugins_label = new Label ("Plugins");

            
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
        
        void add_option (Gtk.Grid grid, Gtk.Widget label, Gtk.Widget switcher, ref int row) {
            label.hexpand = true;
            label.halign = Gtk.Align.START;
            switcher.halign = Gtk.Align.END;
            grid.attach (label, 0, row, 1, 1);
            grid.attach_next_to (switcher, label, Gtk.PositionType.RIGHT, 1, 1);
            row ++;
        }
        
        Gtk.Widget get_general_box () {
            
            modal_dialog = new Switch ();
            Scratch.settings.schema.bind("modal-dialog", modal_dialog, "active", SettingsBindFlags.DEFAULT);
            
            show_right_margin = new Switch ();
            Scratch.settings.schema.bind("show-right-margin", show_right_margin, "active", SettingsBindFlags.DEFAULT);
            var right_margin_position = new SpinButton.with_range (1, 250, 1);
            Scratch.settings.schema.bind("right-margin-position", right_margin_position, "value", SettingsBindFlags.DEFAULT);
            Scratch.settings.schema.bind("show-right-margin", right_margin_position, "sensitive", SettingsBindFlags.DEFAULT);
            
            var general_grid = new Gtk.Grid ();
            general_grid.row_spacing = 5;
            general_grid.column_spacing = 5;
            general_grid.margin_left = 12;
            general_grid.margin_right = 12;
            general_grid.margin_top = 12;
            general_grid.margin_bottom = 12;
            
            int row = 0;
            var label = new Label (_("Right margin"));
            add_option (general_grid, label, show_right_margin, ref row);
            
            label = new Label (_("Right margin at column"));
            add_option (general_grid, label, right_margin_position, ref row);
            Scratch.settings.schema.bind("show-right-margin", label, "sensitive", SettingsBindFlags.DEFAULT);
            
            label = new Label (_("Modal dialogs"));
            add_option (general_grid, label, modal_dialog, ref row);
            
            var cycle_search = new Gtk.Switch ();
            var case_sensitive = new Gtk.Switch ();
            Scratch.settings.schema.bind("search-loop", cycle_search, "active", SettingsBindFlags.DEFAULT);
            Scratch.settings.schema.bind("search-sensitive", case_sensitive, "active", SettingsBindFlags.DEFAULT);
            
            row ++;
            
            label = new Label (_("Search loop"));
            add_option (general_grid, label, cycle_search, ref row);
            
            label = new Label (_("Case sensitive search"));
            add_option (general_grid, label, case_sensitive, ref row);
            
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

            line_numbers = new Switch ();
            Scratch.settings.schema.bind("show-line-numbers", line_numbers, "active", SettingsBindFlags.DEFAULT);
            
            highlight_current_line = new Switch ();
            Scratch.settings.schema.bind("highlight-current-line", highlight_current_line, "active", SettingsBindFlags.DEFAULT);

            highlight_matching_brackets = new Switch ();
            Scratch.settings.schema.bind("highlight-matching-brackets", highlight_matching_brackets, "active", SettingsBindFlags.DEFAULT);

            spaces_instead_of_tabs = new Switch ();
            Scratch.settings.schema.bind("spaces-instead-of-tabs", spaces_instead_of_tabs, "active", SettingsBindFlags.DEFAULT);
            
            auto_indent = new Switch ();
            Scratch.settings.schema.bind("auto-indent", auto_indent, "active", SettingsBindFlags.DEFAULT);

            indent_width = new SpinButton.with_range (1, 24, 1);
            Scratch.settings.schema.bind("indent-width", indent_width, "value", SettingsBindFlags.DEFAULT);
            Scratch.settings.schema.bind("spaces-instead-of-tabs", indent_width, "sensitive", SettingsBindFlags.DEFAULT);

            int row = 0;
            add_option (content, new Label (_("Line numbers")), line_numbers, ref row);
            add_option (content, new Label (_("Highlight current line")), highlight_current_line, ref row);
            add_option (content, new Label (_("Highlight matching brackets")), highlight_matching_brackets, ref row);
            add_option (content, new Label (_("Spaces instead of tabs")), spaces_instead_of_tabs, ref row);
            add_option (content, new Label (_("Tab width")), indent_width, ref row);
            add_option (content, new Label (_("Auto indent")), auto_indent, ref row);
            
            return content;
        }

        Gtk.Grid get_fonts_box () {
            //create general settings

            var content = new Gtk.Grid ();
            content.row_spacing = 5;
            content.column_spacing = 5;
            content.margin_left = 12;
            content.margin_right = 12;
            content.margin_top = 12;
            content.margin_bottom = 12;

            int row = 0;

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

            add_option (content, new Label (_("Color scheme:")), style_scheme, ref row);
            add_option (content, new Label (_("System fixed width font (%s):").printf(default_font())), use_system_font, ref row);
            add_option (content, select_font_l, select_font, ref row);
            
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
