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
		
        private VBox content;
        private HBox padding;

        private Label editor_label;
        private Label font_label;

        private CheckButton line_numbers;
        private CheckButton highlight_current_line;
        private CheckButton spaces_instead_of_tabs;
        private SpinButton indent_width;
        private ComboBoxText style_scheme;
        private CheckButton use_system_font;
        private FontButton select_font;

        //private Button close_button;

        public Preferences (string? title, MainWindow? window) {
            
            this.window = window;
            this.title = title;
            this.type_hint = Gdk.WindowTypeHint.DIALOG;
            this.set_modal (true);
            this.set_transient_for (window);
            
            main_static_notebook = new StaticNotebook ();
            
            set_default_size (400, 300);
            
            create_layout ();

            response.connect (on_response);
            
            Scratch.plugins.hook_preferences_dialog(this);

        }

        private void create_layout () {
			
			//create general settings
			
            content = new VBox (false, 10);
            padding = new HBox (false, 10);

            editor_label = new Label ("Editor");
            editor_label.xalign = 0.0f;
            editor_label.set_markup ("<b>Editor</b>");

            font_label = new Label ("Font");
            font_label.xalign = 0.0f;
            font_label.set_markup ("<b>Font</b>");
            
            line_numbers = new CheckButton.with_label (_("Show line numbers"));
            line_numbers.set_active (Scratch.settings.show_line_numbers);

            highlight_current_line = new CheckButton.with_label (_("Highlight current line"));
            highlight_current_line.set_active (Scratch.settings.highlight_current_line);

            spaces_instead_of_tabs = new CheckButton.with_label (_("Use spaces instead of tabs"));
            spaces_instead_of_tabs.set_active (Scratch.settings.spaces_instead_of_tabs);

            indent_width = new SpinButton.with_range (1, 24, 1);
            indent_width.set_value (Scratch.settings.indent_width);
            var indent_width_l = new Label (_("Tab width:"));
            indent_width_l.xalign = 0.0f;
            var indent_width_box = new HBox (false, 32);
            indent_width_box.pack_start (indent_width_l, true, true, 0);
            indent_width_box.pack_start (indent_width, false, true, 0);

            style_scheme = new ComboBoxText ();
            populate_style_scheme ();
            var style_scheme_l = new Label (_("Style scheme:"));
            style_scheme_l.xalign = 0.0f;
            var style_scheme_box = new HBox (false, 13);
            style_scheme_box.pack_start (style_scheme_l, true, true, 0);
            style_scheme_box.pack_start (style_scheme, true, true, 0);

            use_system_font = new CheckButton.with_label (_("Use the system fixed width font (")
                                                            + default_font () + ")");
            use_system_font.set_active (Scratch.settings.use_system_font);

            select_font = new FontButton ();
            select_font.sensitive = !(use_system_font.get_active ());
            select_font.set_font_name (Scratch.settings.font);
            use_system_font.toggled.connect (() => {
                select_font.sensitive = !(use_system_font.get_active ());});
            var select_font_l = new Label (_("Select font:"));
            select_font_l.xalign = 0.0f;
            var select_font_box = new HBox (false, 24);
            select_font_box.pack_start (select_font_l, true, true, 0);
            select_font_box.pack_start (select_font, true, true, 0);

            //close_button = new Button.with_label (_("Close"));
            add_button (Stock.CLOSE, ResponseType.ACCEPT);
                        
            var bottom_buttons = new HButtonBox ();
            bottom_buttons.set_layout (ButtonBoxStyle.END);
            bottom_buttons.set_spacing (10);
            //bottom_buttons.pack_end (close_button);

            content.pack_start (wrap_alignment (editor_label, 10, 0, 0, 0), false, true, 0);
            content.pack_start (wrap_alignment (line_numbers, 0, 0, 0, 10), false, true, 0);
            content.pack_start (wrap_alignment (highlight_current_line, 0, 0, 0, 10), false, true, 0);
            content.pack_start (wrap_alignment (spaces_instead_of_tabs, 0, 0, 0, 10), false, true, 0);
            content.pack_start (wrap_alignment (indent_width_box, 0, 0, 0, 10), false, true, 0);
            content.pack_start (wrap_alignment (style_scheme_box, 0, 0, 0, 10), false, true, 0);
            
            /* Search management */
            var cycle_search = new Gtk.CheckButton.with_label(_("Search Loop"));
            var case_sensitive = new Gtk.CheckButton.with_label(_("Case Sensitive Search"));
            Scratch.settings.schema.bind("search-loop", cycle_search, "active", SettingsBindFlags.DEFAULT);
            Scratch.settings.schema.bind("search-sensitive", case_sensitive, "active", SettingsBindFlags.DEFAULT);
            content.pack_start(wrap_alignment (cycle_search, 0, 0, 0, 10));
            content.pack_start(wrap_alignment (case_sensitive, 0, 0, 0, 10));

            content.pack_start (font_label, false, true, 0);
            content.pack_start (wrap_alignment (use_system_font, 0, 0, 0, 10), false, true, 0);
            content.pack_start (wrap_alignment (select_font_box, 0, 0, 0, 10), false, true, 0);
            
            
            content.pack_end (bottom_buttons, false, true, 12);

            padding.pack_start (content, true, true, 12);
			
		    //create static notebook
			var general = new Label (_("General"));
			main_static_notebook.append_page (padding, general);
			
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

            //show_all();
            //run ();
            //destroy ();

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

            Scratch.settings.show_line_numbers = line_numbers.get_active ();
            Scratch.settings.highlight_current_line = highlight_current_line.get_active ();
            Scratch.settings.spaces_instead_of_tabs = spaces_instead_of_tabs.get_active ();
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
