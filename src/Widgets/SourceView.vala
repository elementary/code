// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*
* Copyright (c) 2013 Mario Guerriero <mefrio.g@gmail.com>
*               2017–2020 elementary, Inc. <https://elementary.io>
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
        public Gtk.SourceLanguageManager manager;
        public Gtk.SourceStyleSchemeManager style_scheme_manager;
        public Gtk.CssProvider font_css_provider;
        public Gtk.TextTag warning_tag;
        public Gtk.TextTag error_tag;

        public GLib.File location { get; set; }
        public FolderManager.ProjectFolderItem project { get; set; default = null; }

        private string font;
        private uint selection_changed_timer = 0;
        private uint size_allocate_timer = 0;
        private Gtk.TextIter last_select_start_iter;
        private Gtk.TextIter last_select_end_iter;
        private string selected_text = "";
        private GitGutterRenderer git_diff_gutter_renderer;
        private NavMarkGutterRenderer navmark_gutter_renderer;

        private const uint THROTTLE_MS = 400;
        private double total_delta = 0;
        private const double SCROLL_THRESHOLD = 1.0;

        public signal void style_changed (Gtk.SourceStyleScheme style);
        // "selection_changed" signal now only emitted when the selected text changes (position ignored).
        // Listened to by searchbar and highlight word selection plugin
        public signal void selection_changed (Gtk.TextIter start_iter, Gtk.TextIter end_iter);

        //lang can be null, in the case of *No highlight style* aka Normal text
        public Gtk.SourceLanguage? language {
            set {
                ((Gtk.SourceBuffer) buffer).language = value;
            }
            get {
                return ((Gtk.SourceBuffer) buffer).language;
            }
        }

        public int cursor_position {
            get {
                return buffer.cursor_position;
            }

            set {
                Gtk.TextIter iter;
                buffer.get_iter_at_offset (out iter, value);
                buffer.place_cursor (iter); //Assume invalid offset handled correctly for now
                Idle.add (() => {
                    scroll_to_iter (iter, 0.25, false, 0, 0);
                    return Source.REMOVE;
                });
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

            font_css_provider = new Gtk.CssProvider ();
            get_style_context ().add_provider (font_css_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

            var source_buffer = new Gtk.SourceBuffer (null);
            set_buffer (source_buffer);
            source_buffer.highlight_syntax = true;
            source_buffer.mark_set.connect (on_mark_set);
            source_buffer.mark_deleted.connect (on_mark_deleted);
            highlight_current_line = true;

            var draw_spaces_tag = new Gtk.SourceTag ("draw_spaces");
            draw_spaces_tag.draw_spaces = true;
            source_buffer.tag_table.add (draw_spaces_tag);

            // Make the gutter renderer and insert into the left side of the source view.
            git_diff_gutter_renderer = new GitGutterRenderer ();
            navmark_gutter_renderer = new NavMarkGutterRenderer (source_buffer);

            get_gutter (Gtk.TextWindowType.LEFT).insert (git_diff_gutter_renderer, 10);
            get_gutter (Gtk.TextWindowType.LEFT).insert (navmark_gutter_renderer, -48);

            smart_home_end = Gtk.SourceSmartHomeEndType.AFTER;

            // Create common tags
            warning_tag = new Gtk.TextTag ("warning_bg");
            warning_tag.underline = Pango.Underline.ERROR;
            warning_tag.underline_rgba = Gdk.RGBA () { red = 0.13, green = 0.55, blue = 0.13, alpha = 1.0 };

            error_tag = new Gtk.TextTag ("error_bg");
            error_tag.underline = Pango.Underline.ERROR;

            source_buffer.tag_table.add (error_tag);
            source_buffer.tag_table.add (warning_tag);

            Gtk.drag_dest_add_uri_targets (this);

            restore_settings ();
            settings.changed.connect (restore_settings);

            var granite_settings = Granite.Settings.get_default ();
            granite_settings.notify["prefers-color-scheme"].connect (restore_settings);

            scroll_event.connect ((key_event) => {
                var handled = false;
                if (Gdk.ModifierType.CONTROL_MASK in key_event.state) {
                    total_delta += key_event.delta_y;
                    if (total_delta < -SCROLL_THRESHOLD) {
                        get_action_group (MainWindow.ACTION_GROUP).activate_action (MainWindow.ACTION_ZOOM_IN, null);
                        total_delta = 0.0;
                    } else if (total_delta > SCROLL_THRESHOLD) {
                        get_action_group (MainWindow.ACTION_GROUP).activate_action (MainWindow.ACTION_ZOOM_OUT, null);
                        total_delta = 0.0;
                    }

                    return true;
                }

                return false;
            });

            cut_clipboard.connect (() => {
                if (!Scratch.settings.get_boolean ("smart-cut-copy")) {
                    return;
                }

                /* If no text is selected, cut the current line */
                if (!buffer.has_selection) {
                    Gtk.TextIter iter_start, iter_end;

                    if (get_current_line (out iter_start, out iter_end)) {
                        var clipboard = Gtk.Clipboard.get_for_display (get_display (), Gdk.SELECTION_CLIPBOARD);
                        string cut_text = iter_start.get_slice (iter_end);

                        buffer.begin_user_action ();
                        clipboard.set_text (cut_text, -1);
                        buffer.delete_range (iter_start, iter_end);
                        buffer.end_user_action ();
                    }
                }
            });

            copy_clipboard.connect (() => {
                if (!Scratch.settings.get_boolean ("smart-cut-copy")) {
                    return;
                }

                /* If no text is selected, copy the current line */
                if (!buffer.has_selection) {
                    Gtk.TextIter iter_start, iter_end;

                    if (get_current_line (out iter_start, out iter_end)) {
                        var clipboard = Gtk.Clipboard.get_for_display (get_display (), Gdk.SELECTION_CLIPBOARD);
                        string copy_text = iter_start.get_slice (iter_end);

                        clipboard.set_text (copy_text, -1);
                    }
                }
            });

            populate_popup.connect_after (on_context_menu);

            size_allocate.connect ((allocation) => {
                // Throttle for performance
                if (size_allocate_timer == 0) {
                    size_allocate_timer = Timeout.add (THROTTLE_MS, () => {
                        size_allocate_timer = 0;
                        bottom_margin = calculate_bottom_margin (allocation.height);
                        return GLib.Source.REMOVE;
                    });
                }
            });
        }

        private bool get_current_line (out Gtk.TextIter start, out Gtk.TextIter end) {
            buffer.get_iter_at_offset (out start, buffer.cursor_position);
            start.backward_chars (start.get_line_offset ());
            end = start;
            end.forward_line ();

            // Have we returned valid iters?
            return !start.equal (end);
        }

        public void change_syntax_highlight_from_file (File file) {
            try {
                var info = file.query_info ("standard::*", FileQueryInfoFlags.NONE, null);
                var mime_type = ContentType.get_mime_type (
                    info.get_attribute_as_string (FileAttribute.STANDARD_CONTENT_TYPE)
                );
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
            auto_indent = Scratch.settings.get_boolean ("auto-indent");
            show_right_margin = Scratch.settings.get_boolean ("show-right-margin");
            right_margin_position = Scratch.settings.get_int ("right-margin-position");
            insert_spaces_instead_of_tabs = Scratch.settings.get_boolean ("spaces-instead-of-tabs");
            var source_buffer = (Gtk.SourceBuffer) buffer;
            source_buffer.highlight_matching_brackets = Scratch.settings.get_boolean ("highlight-matching-brackets");
            space_drawer.enable_matrix = false;
            switch ((ScratchDrawSpacesState) Scratch.settings.get_enum ("draw-spaces")) {
                case ScratchDrawSpacesState.ALWAYS:
                    space_drawer.set_types_for_locations (
                        Gtk.SourceSpaceLocationFlags.ALL,
                        Gtk.SourceSpaceTypeFlags.SPACE | Gtk.SourceSpaceTypeFlags.TAB
                    );
                    break;
                case ScratchDrawSpacesState.FOR_SELECTION:
                case ScratchDrawSpacesState.CURRENT:
                    space_drawer.set_types_for_locations (
                        Gtk.SourceSpaceLocationFlags.ALL,
                        Gtk.SourceSpaceTypeFlags.NONE
                    );
                    space_drawer.set_types_for_locations (
                        Gtk.SourceSpaceLocationFlags.TRAILING,
                        Gtk.SourceSpaceTypeFlags.SPACE | Gtk.SourceSpaceTypeFlags.TAB
                    );
                    break;
                default:
                    space_drawer.set_types_for_locations (
                        Gtk.SourceSpaceLocationFlags.ALL,
                        Gtk.SourceSpaceTypeFlags.NONE
                    );
                    break;
            }

            space_drawer.enable_matrix = true;
            update_draw_spaces ();


            tab_width = (uint) Scratch.settings.get_int ("indent-width");
            if (Scratch.settings.get_boolean ("line-wrap")) {
                set_wrap_mode (Gtk.WrapMode.WORD);
            } else {
                set_wrap_mode (Gtk.WrapMode.NONE);
            }

            if (Scratch.settings.get_boolean ("use-system-font")) {
                font = ((Scratch.Application) GLib.Application.get_default ()).default_font;
            } else {
                font = Scratch.settings.get_string ("font");
            }

            /* Convert font description to css equivalent and apply to the .view node */
            var font_css = string.join (" ",
                ".view {",
                Scratch.Utils.pango_font_description_to_css (Pango.FontDescription.from_string (font)),
                "}"
            );

            try {
                font_css_provider.load_from_data (font_css);
            } catch (Error e) {
                critical (e.message);
            }

            if (settings.get_boolean ("follow-system-style")) {
                var system_prefers_dark = Granite.Settings.get_default ().prefers_color_scheme == Granite.Settings.ColorScheme.DARK;
                if (system_prefers_dark) {
                    source_buffer.style_scheme = style_scheme_manager.get_scheme ("elementary-dark");
                } else {
                    source_buffer.style_scheme = style_scheme_manager.get_scheme ("elementary-light");
                }
            } else {
                var scheme = style_scheme_manager.get_scheme (Scratch.settings.get_string ("style-scheme"));
                source_buffer.style_scheme = scheme ?? style_scheme_manager.get_scheme ("elementary-highcontrast-light");
            }

            git_diff_gutter_renderer.set_style_scheme (source_buffer.style_scheme);
            style_changed (source_buffer.style_scheme);
        }

        public void go_to_line (int line, int offset = 0) {
            Gtk.TextIter it;
            buffer.get_iter_at_line (out it, line - 1);
            // Ensures offset is set to start of line when column is not set
            // offset = column - 1
            it.forward_chars (offset == -1 ? 0 : offset);
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

        // If selected text does not exists duplicate current line.
        // If selected text is only in one line duplicate in place.
        // If selected text covers more than one line, duplicate all lines complete.
        public void duplicate_selection () {
            Gtk.TextIter? start = null;
            Gtk.TextIter? end = null;
            int selection_start_offset = 0;
            int selection_end_offset = 0;
            int start_line, end_line;
            var selection = get_selected_text ();

            if (selection != "") {
                buffer.get_selection_bounds (out start, out end);
                start_line = start.get_line ();
                end_line = end.get_line ();
                if (start_line != end_line) {
                    buffer.get_iter_at_line (out start, start_line);
                    buffer.get_iter_at_line (out end, end_line);
                    end.forward_to_line_end ();
                    //We do it this way to ensure creation of new line if selected lines include the last in buffer
                    selection = "\n" + buffer.get_text (start, end, true);
                }

                selection_start_offset = start.get_offset ();
                selection_end_offset = end.get_offset ();
            } else {
                buffer.get_iter_at_mark (out start, buffer.get_insert ());
                start.backward_chars (start.get_line_offset ());
                end = start.copy ();
                end.forward_chars (end.get_chars_in_line ());
                if (end.get_line () != start.get_line ()) { // Line lacked final return character
                    end.backward_char ();
                }

                selection = "\n" + buffer.get_text (start, end, true);
            }

            buffer.insert (ref end, selection, -1);
            // Re-establish any pre-exising selection (we do not want duplicate text selected)
            if (selection_start_offset > 0 || selection_end_offset > 0) {
                buffer.get_iter_at_offset (out start, selection_start_offset);
                buffer.get_iter_at_offset (out end, selection_end_offset);
                buffer.select_range (start, end);
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

        public void clear_selected_lines () {
            buffer.begin_user_action ();
            bool has_selection = buffer.has_selection;

            if (has_selection) {
                //Delete selected lines
                buffer.delete_selection (true, true);
            }

            //Clear current line.
            Gtk.TextIter start, end;
            get_current_line (out start, out end);
            end.backward_char ();

            //If line was empty to begin with, remove it entirely
            if (!has_selection && end.equal (start)) {
                end.forward_char ();
            }

            buffer.@delete (ref start, ref end);
            buffer.end_user_action ();
        }

        public void select_range (SelectionRange range) {
            if (range.start_line < 0) {
                return;
            }

            Gtk.TextIter start_iter;
            buffer.get_start_iter (out start_iter);
            start_iter.set_line (range.start_line - 1);

            if (range.start_column > 0) {
                start_iter.set_visible_line_offset (range.start_column - 1);
            }

            Gtk.TextIter end_iter = start_iter.copy ();
            if (range.end_line > 0) {
                end_iter.set_line (range.end_line - 1);

                if (range.end_column > 0) {
                    end_iter.set_visible_line_offset (range.end_column - 1);
                }
            }

            buffer.select_range (start_iter, end_iter);
            Idle.add (() => {
                scroll_to_iter (end_iter, 0.25, false, 0, 0);
                return Source.REMOVE;
            });
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

        public void add_mark_at_cursor () {
            Gtk.TextIter? cur_iter = null;
            buffer.get_iter_at_offset (out cur_iter, cursor_position);
            var cur_line = cur_iter.get_line ();
            navmark_gutter_renderer.add_mark_at_line (cur_line);
        }

        public void goto_previous_mark () {
            goto_nearest_mark (true);
        }

        public void goto_next_mark () {
            goto_nearest_mark (false);
        }

        private void goto_nearest_mark (bool before) {
            Gtk.TextIter? start, end;
            int line;
            if (get_current_line (out start, out end)) {
                navmark_gutter_renderer.get_nearest_marked_line (start.get_line (), before, out line);
                    Gtk.TextIter? iter;
                    buffer.get_iter_at_line (out iter, line);
                    if (iter != null) {
                        cursor_position = iter.get_offset ();
                    }
            }
        }

        private void update_draw_spaces () {
            Gtk.TextIter doc_start, doc_end;
            buffer.get_start_iter (out doc_start);
            buffer.get_end_iter (out doc_end);
            buffer.remove_tag_by_name ("draw_spaces", doc_start, doc_end);

            Gtk.TextIter start, end;
            var selection = buffer.get_selection_bounds (out start, out end);
            var draw_spaces_state = (ScratchDrawSpacesState) Scratch.settings.get_enum ("draw-spaces");
            /* Draw spaces in selection the same way if drawn at all */
            if (selection &&
                draw_spaces_state in (ScratchDrawSpacesState.FOR_SELECTION | ScratchDrawSpacesState.CURRENT | ScratchDrawSpacesState.ALWAYS)) {

                    buffer.apply_tag_by_name ("draw_spaces", start, end);
                    return;
            }

            if (draw_spaces_state == ScratchDrawSpacesState.CURRENT &&
                get_current_line (out start, out end)) {

                    buffer.apply_tag_by_name ("draw_spaces", start, end);
            }
        }

        private void on_context_menu (Gtk.Menu menu) {
            scroll_mark_onscreen (buffer.get_mark ("insert"));

            var sort_item = new Gtk.MenuItem ();
            sort_item.sensitive = get_selected_line_count () > 1;
            sort_item.add (new Granite.AccelLabel.from_action_name (
                _("Sort Selected Lines"),
                MainWindow.ACTION_PREFIX + MainWindow.ACTION_SORT_LINES
            ));
            sort_item.activate.connect (sort_selected_lines);

            menu.add (sort_item);

            var add_edit_item = new Gtk.MenuItem () {
                action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_ADD_MARK
            };
            add_edit_item.add (new Granite.AccelLabel.from_action_name (
                _("Mark Current Line"),
                add_edit_item.action_name

            ));
            menu.add (add_edit_item);

            var previous_edit_item = new Gtk.MenuItem () {
                sensitive = navmark_gutter_renderer.has_marks,
                action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_PREVIOUS_MARK
            };
            previous_edit_item.add (new Granite.AccelLabel.from_action_name (
                _("Goto Previous Edit Mark"),
                previous_edit_item.action_name

            ));
            menu.add (previous_edit_item);

            var next_edit_item = new Gtk.MenuItem () {
                sensitive = navmark_gutter_renderer.has_marks,
                action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_NEXT_MARK
            };
            next_edit_item.add (new Granite.AccelLabel.from_action_name (
                _("Goto Next Edit Mark"),
                next_edit_item.action_name

            ));
            menu.add (next_edit_item);

            if (!navmark_gutter_renderer.has_marks) {
                previous_edit_item.action_name = "";
                previous_edit_item.sensitive = false;
                next_edit_item.action_name = "";
                next_edit_item.sensitive = false;
            }

            if (buffer is Gtk.SourceBuffer) {
                var can_comment = CommentToggler.language_has_comments (((Gtk.SourceBuffer) buffer).get_language ());

                var comment_item = new Gtk.MenuItem ();
                comment_item.sensitive = can_comment;
                comment_item.add (new Granite.AccelLabel.from_action_name (
                    _("Toggle Comment"),
                    MainWindow.ACTION_PREFIX + MainWindow.ACTION_TOGGLE_COMMENT
                ));
                comment_item.activate.connect (() => {
                    CommentToggler.toggle_comment ((Gtk.SourceBuffer) buffer);
                });

                menu.add (comment_item);
            }

            menu.show_all ();
        }

        private static int calculate_bottom_margin (int height_in_px) {
            const int LINES_TO_KEEP = 3;
            const double PT_TO_PX = 1.6667; // Normally 1.3333, but this accounts for line-height

            // Use a default size of 10pt
            double px_per_line = 10 * PT_TO_PX;

            var last_window = ((Scratch.Application) GLib.Application.get_default ()).get_last_window ();
            if (last_window != null) {
                // Get the actual font size
                px_per_line = last_window.get_current_font_size () * PT_TO_PX;
            }

            return (int) (height_in_px - (LINES_TO_KEEP * px_per_line));
        }

        private void on_mark_set (Gtk.TextIter loc, Gtk.TextMark mar) {
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

            selection_changed_timer = Timeout.add (THROTTLE_MS, selection_changed_event);
        }

        private void on_mark_deleted (Gtk.TextMark mark) {
            var name = mark.get_name ();
            if (name != null && name.has_prefix ("NavMark")) {
                warning ("NavMark deleted");
                navmark_gutter_renderer.remove_mark (mark);
            }
        }

        private bool selection_changed_event () {
            Gtk.TextIter start, end;
            buffer.get_selection_bounds (out start, out end);
            // No selection now treated as a potential selection change
            var prev_selected_text = selected_text;
            selected_text = buffer.get_text (start, end, true);
            if (selected_text != prev_selected_text) {
                selection_changed (start, end);
            }

            selection_changed_timer = 0;
            return false;
        }

        uint refresh_timeout_id = 0;
        public void schedule_refresh () {
            if (refresh_timeout_id > 0) {
                Source.remove (refresh_timeout_id);
            }

            refresh_timeout_id = Timeout.add (250, () => {
                refresh_timeout_id = 0;
                if (project != null && project.is_git_repo) {
                    git_diff_gutter_renderer.line_status_map.clear ();
                    project.refresh_diff (ref git_diff_gutter_renderer.line_status_map, location.get_path ());
                    git_diff_gutter_renderer.queue_draw ();
                }

                if (navmark_gutter_renderer.has_marks) {
                    navmark_gutter_renderer.queue_draw ();
                }

                return Source.REMOVE;
            });
        }
    }
}
