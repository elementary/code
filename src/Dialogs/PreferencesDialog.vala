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
        private Switch line_numbers;
        private Switch highlight_current_line;
        private Switch spaces_instead_of_tabs;
        private Switch auto_indent;
        private SpinButton indent_width;
        private ComboBoxText style_scheme;
        private Switch use_system_font;
        private FontButton select_font;

        //private Button close_button;

        public Preferences (string? title, MainWindow? window) {

            this.window = window;
            this.title = title;
            this.type_hint = Gdk.WindowTypeHint.DIALOG;
            this.set_modal (Scratch.settings.modal_dialog);
            this.set_transient_for (window);

            main_static_notebook = new StaticNotebook ();

            set_default_size (550, 250);

            create_layout ();
            
            response.connect (on_response);

            Scratch.plugins.hook_preferences_dialog(this);

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
            
            //show_all();
            //run ();
            //destroy ();

        }
        
        Gtk.HBox get_general_box () {
            //create general settings

            var content = new VBox (false, 10);
            var padding = new HBox (false, 10);
            
            var search_label = new Label (_("Search Manager"));
            search_label.set_markup ("<b>Search Manager</b>");
            
            modal_dialog = new Switch ();
            modal_dialog.set_active (Scratch.settings.modal_dialog);
            
            content.pack_start (wrap_alignment (create_switcher_box (new Label (_("Show dialogs as modal")), modal_dialog), 0, 0, 0, 10), false, false, 0);
            
            var cycle_search = new Gtk.Switch ();
            var case_sensitive = new Gtk.Switch ();
            Scratch.settings.schema.bind("search-loop", cycle_search, "active", SettingsBindFlags.DEFAULT);
            Scratch.settings.schema.bind("search-sensitive", case_sensitive, "active", SettingsBindFlags.DEFAULT);
            
            content.pack_start (wrap_alignment (search_label, 0, 0, 0, 10), false, false, 0);
            content.pack_start(wrap_alignment (create_switcher_box (new Label (_("Search Loop")), cycle_search), 0, 0, 0, 0), false, false);
            content.pack_start(wrap_alignment (create_switcher_box (new Label (_("Case Sensitive Search")), case_sensitive), 0, 0, 0, 0), false, false);

            padding.pack_start (content, false, false, 12);
            
            return padding;
        }
        
        Gtk.HBox get_editor_box () {
            //create general settings

            var content = new VBox (false, 10);
            var padding = new HBox (false, 10);
            
            line_numbers = new Switch ();
            line_numbers.set_active (Scratch.settings.show_line_numbers);
            
            highlight_current_line = new Switch ();
            highlight_current_line.set_active (Scratch.settings.highlight_current_line);

            spaces_instead_of_tabs = new Switch ();
            spaces_instead_of_tabs.set_active (Scratch.settings.spaces_instead_of_tabs);
            
            auto_indent = new Switch ();
            auto_indent.set_active (Scratch.settings.auto_indent);

            var indent_width = new SpinButton.with_range (1, 24, 1);
            indent_width.set_value (Scratch.settings.indent_width);
            var indent_width_l = new Label (_("Tab width:"));
            indent_width_l.xalign = 0.0f;
            var indent_width_box = new HBox (false, 32);
            indent_width_box.pack_start (indent_width_l, true, true, 0);
            indent_width_box.pack_start (indent_width, false, true, 0);

            content.pack_start (wrap_alignment (create_switcher_box (new Label (_("Show line numbers")), line_numbers), 0, 0, 0, 10), false, true, 0);
            content.pack_start (wrap_alignment (create_switcher_box (new Label (_("Highlight current line")), highlight_current_line), 0, 0, 0, 10), false, true, 0);
            content.pack_start (wrap_alignment (create_switcher_box (new Label (_("Use spaces instead of tabs")), spaces_instead_of_tabs), 0, 0, 0, 10), false, true, 0);
            content.pack_start (wrap_alignment (indent_width_box, 0, 0, 0, 10), false, true, 0);
            content.pack_start (wrap_alignment (create_switcher_box (new Label (_("Use auto indent")), auto_indent), 0, 0, 0, 10), false, true, 0);
            
            padding.pack_start (content, false, false, 12);
            
            return padding;
        }

        Gtk.HBox get_fonts_box () {
            //create general settings

            var content = new VBox (false, 10);
            var padding = new HBox (false, 10);

            style_scheme = new ComboBoxText ();
            populate_style_scheme ();
            var style_scheme_l = new Label (_("Style scheme:"));
            style_scheme_l.xalign = 0.0f;
            var style_scheme_box = new HBox (false, 13);
            style_scheme_box.pack_start (style_scheme_l, true, true, 0);
            style_scheme_box.pack_start (style_scheme, true, true, 0);

            use_system_font = new Switch ();

            select_font = new FontButton ();
            select_font.sensitive = !(use_system_font.get_active ());
            select_font.set_font_name (Scratch.settings.font);
            Scratch.settings.schema.bind("use-system-font", use_system_font, "active", SettingsBindFlags.DEFAULT);
            Scratch.settings.schema.bind("use-system-font", select_font, "sensitive", SettingsBindFlags.INVERT_BOOLEAN);
            var select_font_l = new Label (_("Select font:"));
            Scratch.settings.schema.bind("use-system-font", select_font_l, "sensitive", SettingsBindFlags.INVERT_BOOLEAN);
            select_font_l.xalign = 0.0f;
            var select_font_box = new HBox (false, 24);
            select_font_box.pack_start (select_font_l, true, true, 0);
            select_font_box.pack_start (select_font, true, true, 0);

            content.pack_start (wrap_alignment (style_scheme_box, 0, 0, 0, 10), false, true, 0);
            content.pack_start (wrap_alignment (create_switcher_box (new Label (_("Use the system fixed width font (") + default_font () + ")"), use_system_font), 0, 0, 0, 10), false, false, 0);
            content.pack_start (wrap_alignment (select_font_box, 0, 0, 0, 10), false, true, 0);

            padding.pack_start (content, true, true, 12);
            
            return padding;
        }
        
        HBox create_switcher_box (Label label, Switch switcher) {
            var h = new HBox (false, 32);
            h.pack_start (wrap_alignment (label, 0, 0, 0, 10), true, true, 0);
            h.pack_start (wrap_alignment (switcher, 0, 10, 0, 0), false, true, 0);
            return h;
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

        private static Alignment wrap_alignment (Widget widget, int top, int right,
                                                 int bottom, int left) {

            var alignment = new Alignment (0.0f, 0.0f, 1.0f, 1.0f);
            alignment.top_padding = top;
            alignment.right_padding = right;
            alignment.bottom_padding = bottom;
            alignment.left_padding = left;

            alignment.add(widget);
            return alignment;

        }

        private void on_response (int response_id) {
            
            Scratch.settings.modal_dialog = modal_dialog.get_active ();
            Scratch.settings.show_line_numbers = line_numbers.get_active ();
            Scratch.settings.highlight_current_line = highlight_current_line.get_active ();
            Scratch.settings.spaces_instead_of_tabs = spaces_instead_of_tabs.get_active ();
            Scratch.settings.auto_indent = auto_indent.get_active ();
            Scratch.settings.indent_width = (int) indent_width.value;
            Scratch.settings.style_scheme = style_scheme.active_id;
            Scratch.settings.use_system_font = use_system_font.get_active ();
            Scratch.settings.font = select_font.font_name;

            this.hide ();
            //this.destroy ();

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

            style_scheme.set_active_id (Scratch.settings.style_scheme);

        }

    }

} // Namespace
