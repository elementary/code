// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*
* Copyright (c) 2013 Mario Guerriero <mefrio.g@gmail.com>
*               2017-2018 elementary LLC. <https://elementary.io>
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 3 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*/

namespace Scratch.Widgets {
    public class SourceView : Gtk.SourceView {
        public Gtk.TextMark mark;
        public Gtk.SourceLanguageManager manager;
        public Gtk.SourceStyleSchemeManager style_scheme_manager;
        public Gtk.TextTag warning_tag;
        public Gtk.TextTag error_tag;

        private string font;
        private uint selection_changed_timer = 0;
        private Gtk.TextIter last_select_start_iter;
        private Gtk.TextIter last_select_end_iter;

        // Pause after end user highlighting to confirm select,in ms
        private const uint SELECTION_CHANGED_PAUSE = 400;

        public signal void style_changed (Gtk.SourceStyleScheme style);
        public signal void selection_changed (Gtk.TextIter start_iter, Gtk.TextIter end_iter);
        public signal void deselected ();

        //lang can be null, in the case of *No highlight style* aka Normal text
        public Gtk.SourceLanguage? language {
            set {
                ((Gtk.SourceBuffer) buffer).language = value;
            }
            get {
                return ((Gtk.SourceBuffer) buffer).language;
            }
        }

        public SourceView () {
            Object (
                show_line_numbers: true,
                smart_backspace: true,
                smart_home_end: Gtk.SourceSmartHomeEndType.BEFORE,
                wrap_mode: Gtk.WrapMode.WORD
            );
        }

        construct {
            space_drawer.enable_matrix = true;

            expand = true;
            manager = Gtk.SourceLanguageManager.get_default ();
            style_scheme_manager = new Gtk.SourceStyleSchemeManager ();

            var source_buffer = new Gtk.SourceBuffer (null);
            set_buffer (source_buffer);
            source_buffer.highlight_syntax = true;
            source_buffer.mark_set.connect (on_mark_set);
            highlight_current_line = true;

            var draw_spaces_tag = new Gtk.SourceTag ("draw_spaces");
            draw_spaces_tag.draw_spaces = true;
            source_buffer.tag_table.add (draw_spaces_tag);

            smart_home_end = Gtk.SourceSmartHomeEndType.AFTER;

            // Create common tags
            warning_tag = new Gtk.TextTag ("warning_bg");
            warning_tag.underline = Pango.Underline.ERROR;
            warning_tag.underline_rgba = Gdk.RGBA () { red = 0.13, green = 0.55, blue = 0.13, alpha = 1.0 };

            error_tag = new Gtk.TextTag ("error_bg");
            error_tag.underline = Pango.Underline.ERROR;

            source_buffer.tag_table.add (error_tag);
            source_buffer.tag_table.add (warning_tag);

            restore_settings ();

            Gtk.drag_dest_add_uri_targets (this);

            restore_settings ();
            settings.changed.connect (restore_settings);

            scroll_event.connect ((key_event) => {
                if ((Gdk.ModifierType.CONTROL_MASK in key_event.state) && key_event.delta_y < 0) {
                    Application.instance.get_last_window ().action_zoom_in ();
                    return true;
                } else if ((Gdk.ModifierType.CONTROL_MASK in key_event.state) && key_event.delta_y > 0) {
                    Application.instance.get_last_window ().action_zoom_out ();
                    return true;
                }

                return false;
            });

            cut_clipboard.connect (() => {
                /* If no text is selected, cut the current line */
                if (!buffer.has_selection) {
                    Gtk.TextIter iter_start;
                    buffer.get_iter_at_offset (out iter_start, buffer.cursor_position);
                    iter_start.backward_chars (iter_start.get_line_offset ());
                    Gtk.TextIter iter_end = iter_start;
                    iter_end.forward_line ();

                    if (!iter_start.equal (iter_end)) {
                        var clipboard = Gtk.Clipboard.get_for_display (get_display (), Gdk.SELECTION_CLIPBOARD);
                        string cut_text = iter_start.get_slice (iter_end);

                        buffer.begin_user_action ();
                        clipboard.set_text (cut_text, -1);
                        buffer.delete_range (iter_start, iter_end);
                        buffer.end_user_action ();
                    }
                }
            });

            populate_popup.connect_after (on_context_menu);
        }

        ~SourceView () {
            // Update settings when an instance is deleted
            update_settings ();
        }

        public void use_default_font (bool value) {
            if (!value) {
                return;
            }

            font = Application.instance.default_font;
        }

        public void change_syntax_highlight_from_file (File file) {
            try {
                var info = file.query_info ("standard::*", FileQueryInfoFlags.NONE, null);
                var mime_type = ContentType.get_mime_type (info.get_attribute_as_string (FileAttribute.STANDARD_CONTENT_TYPE));
                language = manager.guess_language (file.get_path (), mime_type);
            } catch (Error e) {
                critical (e.message);
            }

            // Fake file type detection
            // "Not all files are equal"
            if (file.get_basename () == "CMakeLists.txt") {
                language = manager.get_language ("cmake");
            }

        }

        private void restore_settings () {
            auto_indent = Scratch.settings.auto_indent;
            show_right_margin = Scratch.settings.show_right_margin;
            right_margin_position = Scratch.settings.right_margin_position;
            var source_buffer = (Gtk.SourceBuffer) buffer;
            source_buffer.highlight_matching_brackets = Scratch.settings.highlight_matching_brackets;

            if (settings.draw_spaces == ScratchDrawSpacesState.ALWAYS) {
                space_drawer.set_types_for_locations (Gtk.SourceSpaceLocationFlags.ALL,
                    Gtk.SourceSpaceTypeFlags.SPACE | Gtk.SourceSpaceTypeFlags.TAB);
            } else {
                space_drawer.set_types_for_locations (Gtk.SourceSpaceLocationFlags.ALL, Gtk.SourceSpaceTypeFlags.NONE);
            }

            update_draw_spaces ();

            insert_spaces_instead_of_tabs = Scratch.settings.spaces_instead_of_tabs;
            tab_width = (uint) Scratch.settings.indent_width;

            font = Scratch.settings.font;
            use_default_font (Scratch.settings.use_system_font);
            override_font (Pango.FontDescription.from_string (font));
            source_buffer.style_scheme = style_scheme_manager.get_scheme (Scratch.settings.style_scheme);
            style_changed (source_buffer.style_scheme);
        }

        private void update_settings () {
            var source_buffer = (Gtk.SourceBuffer) buffer;
            Scratch.settings.show_right_margin = show_right_margin;
            Scratch.settings.right_margin_position = (int) right_margin_position;
            Scratch.settings.highlight_matching_brackets = source_buffer.highlight_matching_brackets;
            Scratch.settings.spaces_instead_of_tabs = insert_spaces_instead_of_tabs;
            Scratch.settings.indent_width = (int) tab_width;
            Scratch.settings.font = font;
            Scratch.settings.style_scheme = source_buffer.style_scheme.id;
            style_changed (source_buffer.style_scheme);
        }

        public void go_to_line (int line, int offset = 0) {
            Gtk.TextIter it;
            buffer.get_iter_at_line (out it, line - 1);
            it.forward_chars (offset);
            scroll_to_iter (it, 0, false, 0, 0);
            buffer.place_cursor (it);
        }

        public string get_selected_text (bool replace_new_line = true) {
            Gtk.TextIter start, end;
            buffer.get_selection_bounds (out start, out end);
            string selected = buffer.get_text (start, end, true);
            if (replace_new_line) {
                return selected.chomp ().replace ("\n", " ");
            }

            return selected;
        }

        private int get_selected_line_count () {
            Gtk.TextIter start, end;
            buffer.get_selection_bounds (out start, out end);

            if (!start.equal (end)) {
                string selected = buffer.get_text (start, end, true);
                string[] lines = Regex.split_simple ("""\R""", selected);
                return lines.length;
            }

            return 0;
        }

        // Duplicate selected text if exists, else duplicate current line
        public void duplicate_selection () {
            var selection = get_selected_text ();

            Gtk.TextIter start, end;
            buffer.get_selection_bounds (out start, out end);

            if (selection != "") {
                buffer.insert (ref end, selection, -1);
            // If nothing is selected duplicate current line
            } else {
                buffer.get_iter_at_mark (out start, buffer.get_insert ());
                start.backward_line ();
                start.forward_line ();

                buffer.get_iter_at_mark (out end, buffer.get_insert ());
                end.forward_line ();

                string line = buffer.get_text (start, end, true);
                buffer.insert (ref end, line, -1);
            }
        }

        public void sort_selected_lines () {
            Gtk.TextIter start, end;
            buffer.get_selection_bounds (out start, out end);

            if (!start.equal (end)) {
                if (!start.starts_line ()) {
                    start.backward_chars (start.get_line_offset ());
                }

                // Go to the start of the next line so we get the newline character
                if (!end.starts_line ()) {
                    end.forward_line ();
                }

                bool end_included = end.is_end ();
                string selected = buffer.get_text (start, end, true);
                string[] lines = Regex.split_simple ("""(\R)""", selected);

                // We have two array elements for every line, don't continue if we have only 1 line
                if (lines.length <= 3) {
                    return;
                }

                // The split lines are split into pairs of the line's content and the newline character(s), so join them
                // back together as standalone lines again
                var line_array = new Gee.ArrayList<string> ();
                for (int i = 0; i < lines.length; i+= 2) {
                    if (i + 1 <= lines.length - 1) {
                        line_array.add (lines[i] + lines[i + 1]);
                    } else if (i == lines.length - 1 && end_included) {
                        // If this is the EOF line, give it a newline character copied from the line above
                        line_array.add (lines[i] + lines[i - 1]);
                    } else {
                        break;
                    }
                }

                line_array.sort ((a, b) => {
                    return a.collate (b);
                });

                // Strip the newline off the new last line in the file if we need to
                if (end_included) {
                    var orig_end = line_array[line_array.size - 1];
                    if (Regex.match_simple ("""\R""", orig_end)) {
                        line_array[line_array.size - 1] = Regex.split_simple ("""\R""", orig_end)[0];
                    }
                }

                var sorted = string.joinv ("", line_array.to_array ());
                buffer.begin_user_action ();
                buffer.@delete (ref start, ref end);
                buffer.insert_at_cursor (sorted, -1);
                buffer.end_user_action ();
            }
        }

        public void set_text (string text, bool opening = true) {
            var source_buffer = (Gtk.SourceBuffer) buffer;
            if (opening) {
                source_buffer.begin_not_undoable_action ();
            }

            source_buffer.text = text;

            if (opening) {
                source_buffer.end_not_undoable_action ();
            }

            Gtk.TextIter? start = null;
            buffer.get_start_iter (out start);
            buffer.place_cursor (start);
        }

        public string get_text () {
            return buffer.text;
        }

        private void update_draw_spaces () {
            Gtk.TextIter doc_start, doc_end;
            buffer.get_start_iter (out doc_start);
            buffer.get_end_iter (out doc_end);
            buffer.remove_tag_by_name ("draw_spaces", doc_start, doc_end);

            Gtk.TextIter start, end;
            var selection = buffer.get_selection_bounds (out start, out end);

            if (selection && settings.draw_spaces == ScratchDrawSpacesState.FOR_SELECTION) {
                buffer.apply_tag_by_name ("draw_spaces", start, end);
            }
        }

        private void on_context_menu (Gtk.Menu menu) {
            var sort_item = new Gtk.MenuItem.with_label (_("Sort Selected Lines"));
            sort_item.sensitive = get_selected_line_count () > 1;
            sort_item.activate.connect (sort_selected_lines);
            menu.add (sort_item);

            if (buffer is Gtk.SourceBuffer) {
                var can_comment = CommentToggler.language_has_comments ((buffer as Gtk.SourceBuffer).get_language ());
                var comment_item = new Gtk.MenuItem.with_label (_("Toggle Comment"));
                comment_item.sensitive = get_selected_line_count () > 0 && can_comment;
                comment_item.activate.connect (() => {
                    CommentToggler.toggle_comment (buffer as Gtk.SourceBuffer);
                });

                menu.add (comment_item);
            }

            menu.show_all ();
        }

        void on_mark_set (Gtk.TextIter loc, Gtk.TextMark mar) {
            // Weed out user movement for text selection changes
            Gtk.TextIter start, end;
            buffer.get_selection_bounds (out start, out end);

            if (start.equal (last_select_start_iter) && end.equal (last_select_end_iter)) {
                return;
            }

            last_select_start_iter.assign (start);
            last_select_end_iter.assign (end);

            update_draw_spaces ();

            if (selection_changed_timer != 0) {
                Source.remove (selection_changed_timer);
                selection_changed_timer = 0;
            }

            // Fire deselected immediatly
            if (start.equal (end)) {
                deselected ();
            // Don't fire signal till we think select movement is done
            } else {
                selection_changed_timer = Timeout.add (SELECTION_CHANGED_PAUSE, selection_changed_event);
            }

        }

        bool selection_changed_event () {
            Gtk.TextIter start, end;
            bool selected = buffer.get_selection_bounds (out start,out end);
            if (selected) {
                selection_changed (start,end);
            } else {
                deselected ();
            }

            selection_changed_timer = 0;
            return false;
        }
    }
}
