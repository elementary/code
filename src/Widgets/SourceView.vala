// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/***
  BEGIN LICENSE

  Copyright (C) 2013 Mario Guerriero <mario@elementaryos.org>
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

        public new SourceBuffer buffer;
        public Gtk.TextMark mark;
        public SourceLanguageManager manager;
        public SourceStyleSchemeManager style_scheme_manager;

        // Commmon tags
        public Gtk.TextTag warning_tag;
        public Gtk.TextTag error_tag;

        // Properties
        private string font;

        public SourceView () {
            // Create general objects
            manager = SourceLanguageManager.get_default ();
            style_scheme_manager = new SourceStyleSchemeManager ();
            buffer = new SourceBuffer (null);

            this.set_buffer (buffer);

            // Set some settings
            buffer.highlight_syntax = true;
            smart_home_end = SourceSmartHomeEndType.AFTER;

            // Create common tags
            this.warning_tag = new Gtk.TextTag ("warning_bg");
            this.warning_tag.background_rgba = Gdk.RGBA() { red = 1.0, green = 1.0, blue = 0, alpha = 0.8 };

            this.error_tag = new Gtk.TextTag ("error_bg");
            this.error_tag.underline = Pango.Underline.ERROR;

            // Restore user settings
            restore_settings ();

            // Popup menu
            populate_popup.connect (on_populate_menu);

            // Allow files to be dragged into the widgets
            Gtk.drag_dest_add_uri_targets (this);

            // Settings
            restore_settings ();
            settings.changed.connect (restore_settings);
        }

        ~SourceView () {
            // Update settings when an instance is deleted
            update_settings ();
        }

        void on_populate_menu (Gtk.Menu menu) {

            var syntax_menu = new Gtk.MenuItem ();
            syntax_menu.set_label (_("Syntax Highlighting"));

            var submenu = new Gtk.Menu ();
            syntax_menu.set_submenu (submenu);

            // Create menu
            unowned SList<Gtk.RadioMenuItem> group = null;
            Gtk.RadioMenuItem? item = null;

            // "No Language" entry
            item = new Gtk.RadioMenuItem (group);
            item.set_label (_("Normal Text"));
            item.toggled.connect (() => {
                var lang = manager.get_language ("normal");
                buffer.set_language (lang);
            });

            submenu.add (item);

            // Language entries
            var ids = manager.get_language_ids ();
            for (int n = 0; n < ids.length; n++) {
                // Lang
                var lang = manager.get_language (ids[n]);

                group = item.get_group ();
                item = new Gtk.RadioMenuItem (group);
                item.set_label (lang.name);

                submenu.add (item);

                item.toggled.connect (() => {
                    buffer.set_language (lang);
                });
                // Active item
                if (buffer.language != null && lang.id == buffer.language.id)
                    item.active = true;
            }

            menu.add (syntax_menu);

            menu.show_all ();
        }

        public void use_default_font (bool value) {

            if (!value) // if false, simply return null
                return;

            var settings = new GLib.Settings ("org.gnome.desktop.interface");
            this.font = settings.get_string ("monospace-font-name");

        }

        public void change_syntax_highlight_from_file (File file) {

            Gtk.SourceLanguage lang = null;

            FileInfo? info = null;

            try {
                info = file.query_info ("standard::*", FileQueryInfoFlags.NONE, null);
            } catch (Error e) {
                warning (e.message);
                return;
            }
            var mime_type = ContentType.get_mime_type (info.get_attribute_as_string (FileAttribute.STANDARD_CONTENT_TYPE));

            lang = manager.guess_language (file.get_path (), mime_type);

            buffer.set_language (lang);

            // Fake file type detection
            // "Not all files are equal"
            string display_name = file.get_basename ();

            if (display_name == "CMakeLists.txt") {
                lang = manager.get_language ("cmake");
                buffer.set_language (lang);
            }

        }

        private void restore_settings () {

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
            if (settings.line_break) set_wrap_mode (Gtk.WrapMode.CHAR);
            else set_wrap_mode (Gtk.WrapMode.NONE);

            this.font = Scratch.settings.font;
            use_default_font (Scratch.settings.use_system_font);
            modify_font (Pango.FontDescription.from_string (this.font));

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
            Scratch.settings.font = this.font;
            Scratch.settings.style_scheme = buffer.style_scheme.id;
        }

        // Move cursor to a given line
        public void go_to_line (int line) {
            TextIter it;
            buffer.get_iter_at_line (out it, line-1);
            scroll_to_iter (it, 0, false, 0, 0);
            buffer.place_cursor (it);
            set_highlight_current_line (true);
        }

        // Get selected text
        public string get_selected_text () {
            TextIter start, end;
            this.buffer.get_selection_bounds (out start, out end);
            string selected = this.buffer.get_text (start, end, true);
            selected = selected.chomp ().replace ("\n", " ");
            return selected;
        }

        // Duplicate selected text if exists, else duplicate current line
        public void duplicate_selection () {
            // Selection
            var selection = get_selected_text ();
            // Iters
            Gtk.TextIter start, end;
            this.buffer.get_selection_bounds (out start, out end);

            if (selection != "")
                this.buffer.insert (ref end, selection, -1);
            // If nothing is selected duplicate current line
            else {
                this.buffer.get_iter_at_mark (out start, this.buffer.get_insert ());
                start.backward_line ();
                start.forward_line ();

                this.buffer.get_iter_at_mark (out end, this.buffer.get_insert ());
                end.forward_line ();

                string line = this.buffer.get_text (start, end, true);
                this.buffer.insert (ref end, line, -1);
            }
        }

        public void set_text (string text, bool opening = true) {
            GLib.Idle.add (() => {
                if (opening) buffer.begin_not_undoable_action ();
                buffer.text = text;
                if (opening) buffer.end_not_undoable_action ();
                Gtk.TextIter? start = null;
                buffer.get_start_iter (out start);
                buffer.place_cursor (start);
                return false;
            });
        }

    }

}
