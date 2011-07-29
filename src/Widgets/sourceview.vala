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
using GtkSource;


namespace Scratch.Widgets {

    public class SourceView : View {

        private MainWindow window;
        
        public GtkSource.Buffer buffer;
        public LanguageManager manager;
        
        public string current_font;
    
        public SourceView (MainWindow window) {

            this.window = window;
            
            manager = new LanguageManager ();
            
            buffer = new Buffer (null);
            set_buffer (buffer);
            buffer.changed.connect (on_buffer_changed);
            
            restore_settings ();

            // Simple default configuration
            auto_indent = true;
            set_wrap_mode (Gtk.WrapMode.WORD);
            
            buffer.highlight_syntax = true;
            
            Scratch.settings.changed.connect (restore_settings);

        }

        ~SourceView () {

            // Update settings when an instance is deleted
            update_settings ();

        }

        public void use_default_font (bool value) {
            
            if (!value) // if false, simply return null
                return;
            
            var settings = new GLib.Settings ("org.gnome.desktop.interface");
            current_font = settings.get_string ("monospace-font-name");
            
        }

        public void set_file (string filename, string text) {

            Language lang;
            lang = manager.guess_language (filename, null);
            buffer.set_language (lang);
            buffer.text = text;

        }
        
        public void on_buffer_changed () {
        	var nb = window.notebook;
        	var tab = (Tab) nb.get_nth_page (nb.get_current_page());
        	var label = tab.label.label;
        	if (label.get_text().substring (0, 1) != "*"){
        		label.set_text ("* " + label.get_text());
        	}
        }

        public void restore_settings () {
            
            show_line_numbers = Scratch.settings.show_line_numbers;
            highlight_current_line = Scratch.settings.highlight_current_line;
            insert_spaces_instead_of_tabs = Scratch.settings.spaces_instead_of_tabs;
            indent_width = Scratch.settings.indent_width;
            
            current_font = Scratch.settings.font;
            use_default_font (Scratch.settings.use_system_font);
            modify_font (Pango.FontDescription.from_string (current_font));

        }

        private void update_settings () {

            Scratch.settings.show_line_numbers = show_line_numbers;
            Scratch.settings.highlight_current_line = highlight_current_line;
            Scratch.settings.spaces_instead_of_tabs = insert_spaces_instead_of_tabs;
            Scratch.settings.indent_width = indent_width;
            Scratch.settings.font = current_font;

        }

    }
    
} // Namespace 
