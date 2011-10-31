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


namespace Scratch.Widgets {

    public class SourceView : Gtk.SourceView {

        Gtk.ComboBoxText? language_combo = null;
        
        public new Gtk.SourceBuffer buffer;
        public Gtk.TextMark mark;
        public SourceLanguageManager manager;
        public SourceStyleSchemeManager style_scheme_manager;
        
        public string current_font;
        
        public bool modified {set; get;}
    
        public SourceView (Gtk.ComboBoxText? language_combo) {

        	Gtk.drag_dest_add_uri_targets (this);
            this.language_combo = language_combo;
            
            manager = new SourceLanguageManager ();
            style_scheme_manager = new SourceStyleSchemeManager ();
            
            buffer = new SourceBuffer (null);
            set_buffer (buffer);
            buffer.changed.connect (on_buffer_changed);
            
            TextIter start, end;
			buffer.get_selection_bounds (out start, out end);
            
            mark = buffer.create_mark ("selection", start, false);
            
            restore_settings ();

            // Simple default configuration
            auto_indent = true;
            set_wrap_mode (Gtk.WrapMode.WORD);
                        
            buffer.highlight_syntax = true;
            
            Scratch.settings.changed.connect (restore_settings);
			
            if(plugins != null)
                plugins.hook_source_view(this);

        }

        ~SourceView () {

            // Update settings when an instance is deleted
            update_settings ();

        }

		public override void drag_data_received (Gdk.DragContext context, int x, int y, SelectionData selection_data, uint info, uint time_) {
			foreach (string s in selection_data.get_uris ()){
			    try {
                	//window.open (Filename.from_uri (s));
				    //window.set_undo_redo ();
				}
				catch (Error e) {
				    warning ("%s doesn't seem to be a valid URI, couldn't open it.", s);
				}
			}
		}

        public void use_default_font (bool value) {
            
            if (!value) // if false, simply return null
                return;
            
            var settings = new GLib.Settings ("org.gnome.desktop.interface");
            current_font = settings.get_string ("monospace-font-name");
            
        }
        
        public void change_syntax_highlight_for_filename (string filename)
        {
			SourceLanguage lang;
			string display_name = Filename.display_basename(filename);
			string extension = display_name.split(".")[display_name.split(".").length - 1];

			if (extension == "ui") {
				lang = manager.get_language ("xml");
				buffer.set_language (lang);
				if(language_combo != null)
    				language_combo.set_active_id ("xml");
				
			}
			else if (display_name == "CMakeLists.txt") {
				lang = manager.get_language ("cmake");
				buffer.set_language (lang);
				if(language_combo != null)
    				language_combo.set_active_id ("cmake");
			}
			else {
				lang = manager.guess_language (filename, null);
				buffer.set_language (lang);
			}
        }
        
        public void on_buffer_changed () {
        	modified = true;
        }

        public void restore_settings () {
            
            show_line_numbers = Scratch.settings.show_line_numbers;
            highlight_current_line = Scratch.settings.highlight_current_line;
            insert_spaces_instead_of_tabs = Scratch.settings.spaces_instead_of_tabs;
            tab_width = (uint) Scratch.settings.indent_width;
            
            current_font = Scratch.settings.font;
            use_default_font (Scratch.settings.use_system_font);
            modify_font (Pango.FontDescription.from_string (current_font));

            buffer.style_scheme = style_scheme_manager.get_scheme (Scratch.settings.style_scheme);

        }

        private void update_settings () {

            Scratch.settings.show_line_numbers = show_line_numbers;
            Scratch.settings.highlight_current_line = highlight_current_line;
            Scratch.settings.spaces_instead_of_tabs = insert_spaces_instead_of_tabs;
            Scratch.settings.indent_width = (int) tab_width;
            Scratch.settings.font = current_font;
            Scratch.settings.style_scheme = buffer.style_scheme.id;

        }
        
        /**
         * Go to the line.
         *
         * @param line the line you want to go to
         **/
        public void go_to_line (int line) {
			TextIter it;
			buffer.get_iter_at_line (out it, line-1); 
			scroll_to_iter (it, 0, false, 0, 0);
			buffer.place_cursor (it);
        }
        

    }
    
} // Namespace 
