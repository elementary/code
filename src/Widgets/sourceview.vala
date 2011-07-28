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
        
        public GtkSource.Buffer buffer;
        public LanguageManager manager;
        
        private string current_font;
    
        public SourceView () {
            
            manager = new LanguageManager ();
            
            use_default_font (true);
            modify_font (Pango.FontDescription.from_string (current_font));
            
            buffer = new Buffer (null);
            set_buffer (buffer);
            //buffer.set_language (manager.get_language ("c"));
            
            restore_settings ();

            // Simple default configuration
            auto_indent = true;
            set_wrap_mode (Gtk.WrapMode.WORD);
            
            buffer.highlight_syntax = true;
            
            // TODO: use color scheme

            Scratch.settings.changed.connect (restore_settings);

        }

        ~SourceView () {

            // Update settings when an instance is deleted
            update_settings ();

        }

        public void use_default_font (bool value) {
            
            if (!value) // if false, simply return null
                return;
            
            try { // if true, try to get the corrent font
                var settings = new GLib.Settings ("org.gnome.desktop.interface");
                current_font = settings.get_string ("monospace-font-name");
            } catch (Error e) {
                warning ("SourceView error: %s", e.message);
            }
            
        }

        public void set_file (string filename, string text) {

            Language lang;
            lang = manager.guess_language (filename, null);
            buffer.set_language (lang);
            buffer.text = text;

        }

        public void restore_settings () {
            
            show_line_numbers = Scratch.settings.show_line_numbers;
            highlight_current_line = Scratch.settings.highlight_current_line;
            insert_spaces_instead_of_tabs = Scratch.settings.spaces_instead_of_tabs;
            indent_width = Scratch.settings.indent_width;

        }

        private void update_settings () {

            Scratch.settings.show_line_numbers = show_line_numbers;
            Scratch.settings.highlight_current_line = highlight_current_line;
            Scratch.settings.spaces_instead_of_tabs = insert_spaces_instead_of_tabs;
            Scratch.settings.indent_width = indent_width;
            

        }

    }
    
} // Namespace 
