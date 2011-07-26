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
        
        private string current_font;
    
        public SourceView () {
            
            use_default_font (true);
            modify_font (Pango.FontDescription.from_string (current_font));
            
            buffer = new Buffer (null);
            set_buffer (buffer);
            
            // Simple default configuration
            show_line_numbers =  true;
            auto_indent = true;
            set_insert_spaces_instead_of_tabs (true);
            set_indent_width (4);
            set_wrap_mode (Gtk.WrapMode.WORD);
            highlight_current_line = true;
            
            buffer.highlight_syntax = true;
            
            // TODO: use color scheme
            
        }
        
        public void use_default_font (bool value) {
            
            if (!value) // if false, simply return null
                return;
            
            try { // if true, try to get the corrent font
                var settings = new GLib.Settings ("org.gnome.desktop.interface");
                current_font = settings.get_string ("monospace-font-name");
            } catch (Error e) {
                stdout.printf ("SourceView error: %s", e.message);
            }
            
        }

    }
    
} // Namespace 
