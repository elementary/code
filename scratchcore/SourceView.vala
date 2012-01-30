// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/***
  BEGIN LICENSE

  Copyright (C) 2011-2012 Giulio Collura <random.cpp@gmail.com>
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

using Scratch;

namespace Scratch.Widgets {

    public class SourceView : Gtk.SourceView {

        public new Gtk.SourceBuffer buffer;
        public Gtk.TextMark mark;
        public SourceLanguageManager manager;
        public SourceStyleSchemeManager style_scheme_manager;

        public string current_font;

        public bool modified {set; get;}

        public SourceView () {

            Gtk.drag_dest_add_uri_targets (this);

            manager = new SourceLanguageManager ();
            style_scheme_manager = new SourceStyleSchemeManager ();

            buffer = new SourceBuffer (null);
            set_buffer (buffer);

            TextIter start, end;
            buffer.get_selection_bounds (out start, out end);

            mark = buffer.create_mark ("selection", start, false);

            restore_settings ();

            // Simple default configuration
            set_wrap_mode (Gtk.WrapMode.WORD);

            buffer.highlight_syntax = true;
            
            smart_home_end = SourceSmartHomeEndType.AFTER;
            
            Scratch.settings.changed.connect (restore_settings);

            if (plugins != null)
                plugins.hook_source_view(this);

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

        public SourceLanguage change_syntax_highlight_for_filename (string filename)
        {
            SourceLanguage lang;
            string display_name = Filename.display_basename(filename);
            string extension = display_name.split(".")[display_name.split(".").length - 1];

            if (extension == "ui") {
                lang = manager.get_language ("xml");
                buffer.set_language (lang);

            }
            else if (display_name == "CMakeLists.txt") {
                lang = manager.get_language ("cmake");
                buffer.set_language (lang);
            }
            else {
                lang = manager.guess_language (filename, null);
                buffer.set_language (lang);
            }

            return lang;

        }

        public void restore_settings () {

            auto_indent = Scratch.settings.auto_indent;
            show_right_margin = Scratch.settings.show_right_margin;
            right_margin_position = Scratch.settings.right_margin_position;
            show_line_numbers = Scratch.settings.show_line_numbers;
            highlight_current_line = Scratch.settings.highlight_current_line;
            buffer.highlight_matching_brackets = Scratch.settings.highlight_matching_brackets;
            if (settings.draw_spaces) { draw_spaces = SourceDrawSpacesFlags.TAB; draw_spaces |= SourceDrawSpacesFlags.SPACE; }
            else draw_spaces = SourceDrawSpacesFlags.NBSP;
            insert_spaces_instead_of_tabs = Scratch.settings.spaces_instead_of_tabs;
            tab_width = (uint) Scratch.settings.indent_width;

            current_font = Scratch.settings.font;
            use_default_font (Scratch.settings.use_system_font);
            modify_font (Pango.FontDescription.from_string (current_font));

            buffer.style_scheme = style_scheme_manager.get_scheme (Scratch.settings.style_scheme);

        }

        private void update_settings () {

            Scratch.settings.show_line_numbers = show_line_numbers;
            Scratch.settings.show_right_margin = show_right_margin;
            Scratch.settings.right_margin_position = (int) right_margin_position;
            Scratch.settings.highlight_current_line = highlight_current_line;
            Scratch.settings.highlight_matching_brackets = buffer.highlight_matching_brackets;
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
