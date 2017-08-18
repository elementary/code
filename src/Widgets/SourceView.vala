// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*
* Copyright (c) 2013 Mario Guerriero <mefrio.g@gmail.com>
*               2017 elementary LLC. <https://elementary.io>
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
        public new Gtk.SourceBuffer buffer;
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
        public signal void language_changed (Gtk.SourceLanguage? language);
        public signal void selection_changed (Gtk.TextIter start_iter, Gtk.TextIter end_iter);
        public signal void deselected ();

        //lang can be null, in the case of *No highlight style* aka Normal text
        private Gtk.SourceLanguage? language {
            set {
                buffer.language = value;
                language_changed (value);
            }
        }

        public SourceView () {
            Object (
                show_line_numbers: true,
                wrap_mode: Gtk.WrapMode.WORD
            );
        }

        construct {
            manager = Gtk.SourceLanguageManager.get_default ();
            style_scheme_manager = new Gtk.SourceStyleSchemeManager ();

            buffer = new Gtk.SourceBuffer (null);
            buffer.highlight_syntax = true;
            buffer.mark_set.connect (on_mark_set);

            set_buffer (buffer);
            smart_home_end = Gtk.SourceSmartHomeEndType.AFTER;

            // Create common tags
            warning_tag = new Gtk.TextTag ("warning_bg");
            warning_tag.background_rgba = Gdk.RGBA () { red = 1.0, green = 1.0, blue = 0, alpha = 0.8 };

            error_tag = new Gtk.TextTag ("error_bg");
            error_tag.underline = Pango.Underline.ERROR;

            restore_settings ();

            populate_popup.connect (on_populate_menu);

            Gtk.drag_dest_add_uri_targets (this);

            restore_settings ();
            settings.changed.connect (restore_settings);

            scroll_event.connect ((key_event) => {
                if ((Gdk.ModifierType.CONTROL_MASK in key_event.state) && key_event.delta_y < 0) {
                    Application.instance.get_last_window ().zoom_in ();
                    return true;
                } else if ((Gdk.ModifierType.CONTROL_MASK in key_event.state) && key_event.delta_y > 0) {
                    Application.instance.get_last_window ().zoom_out ();
                    return true;
                }

                return false;
            });

            key_press_event.connect ((key_event) => {
                if (Gdk.ModifierType.CONTROL_MASK in key_event.state) {
                    switch (key_event.keyval) {
                        case Gdk.Key.plus:
                            Application.instance.get_last_window ().zoom_in ();
                            return true;
                        case Gdk.Key.minus:
                            Application.instance.get_last_window ().zoom_out ();
                            return true;
                        case 0x30:
                            Application.instance.get_last_window ().set_default_zoom ();
                            return true;
                    }
                }

                return false;
            });
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

                //"No highlight style"
                language = null;
            });

            submenu.add (item);

            // Language entries
            var ids = manager.get_language_ids ();
            foreach (var id in ids) {
                var lang = manager.get_language (id);
                group = item.get_group ();
                item = new Gtk.RadioMenuItem (group);
                item.set_label (lang.name);

                submenu.add (item);
                item.toggled.connect (() => {
                    language = lang;
                });
                // Active item
                if (buffer.language != null && id == buffer.language.id) {
                    item.active = true;
                }
            }

            menu.add (syntax_menu);
            menu.show_all ();
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
            highlight_current_line = Scratch.settings.highlight_current_line;
            buffer.highlight_matching_brackets = Scratch.settings.highlight_matching_brackets;
            if (settings.draw_spaces == ScratchDrawSpacesState.ALWAYS) {
                draw_spaces = Gtk.SourceDrawSpacesFlags.TAB;
                draw_spaces |= Gtk.SourceDrawSpacesFlags.SPACE;
            } else {
                // Ensure we change the draw_spaces variable at least once to trigger redraw
                draw_spaces = Gtk.SourceDrawSpacesFlags.TAB;
                draw_spaces = Gtk.SourceDrawSpacesFlags.NBSP;
            }

            insert_spaces_instead_of_tabs = Scratch.settings.spaces_instead_of_tabs;
            tab_width = (uint) Scratch.settings.indent_width;

            font = Scratch.settings.font;
            use_default_font (Scratch.settings.use_system_font);
            override_font (Pango.FontDescription.from_string (font));
            buffer.style_scheme = style_scheme_manager.get_scheme (Scratch.settings.style_scheme);
            style_changed (buffer.style_scheme);
        }

        private void update_settings () {
            Scratch.settings.show_right_margin = show_right_margin;
            Scratch.settings.right_margin_position = (int) right_margin_position;
            Scratch.settings.highlight_current_line = highlight_current_line;
            Scratch.settings.highlight_matching_brackets = buffer.highlight_matching_brackets;
            Scratch.settings.spaces_instead_of_tabs = insert_spaces_instead_of_tabs;
            Scratch.settings.indent_width = (int) tab_width;
            Scratch.settings.font = font;
            Scratch.settings.style_scheme = buffer.style_scheme.id;
            style_changed (buffer.style_scheme);
        }

        // Move cursor to a given line
        public void go_to_line (int line) {
            Gtk.TextIter it;
            buffer.get_iter_at_line (out it, line-1);
            scroll_to_iter (it, 0, false, 0, 0);
            buffer.place_cursor (it);
            set_highlight_current_line (true);
        }

        // Get selected text
        public string get_selected_text (bool replace_new_line = true) {
            Gtk.TextIter start, end;
            buffer.get_selection_bounds (out start, out end);
            string selected = buffer.get_text (start, end, true);
            if (replace_new_line) {
                return selected.chomp ().replace ("\n", " ");
            }

            return selected;
        }

        // Duplicate selected text if exists, else duplicate current line
        public void duplicate_selection () {
            // Selection
            var selection = get_selected_text ();
            // Iters
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

        public void set_text (string text, bool opening = true) {
            if (opening) {
                buffer.begin_not_undoable_action ();
            }

            buffer.text = text;

            if (opening) {
                buffer.end_not_undoable_action ();
            }

            Gtk.TextIter? start = null;
            buffer.get_start_iter (out start);
            buffer.place_cursor (start);
        }

        void on_mark_set (Gtk.TextIter loc, Gtk.TextMark mar) {
            // Weed out user movement for text selection changes
            Gtk.TextIter start, end;
            buffer.get_selection_bounds (out start,out end);

            if (start == last_select_start_iter && end == last_select_end_iter)
                return;

            if (selection_changed_timer !=0 &&
                MainContext.get_thread_default ().find_source_by_id (selection_changed_timer) != null)
                Source.remove (selection_changed_timer);

            // Fire deselected immediatly
            if (!buffer.get_has_selection ()) {
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

            return false;
        }

        public override void draw_layer (Gtk.TextViewLayer layer, Cairo.Context context) {
            if (layer == Gtk.TextViewLayer.ABOVE && buffer.get_has_selection () && settings.draw_spaces == ScratchDrawSpacesState.FOR_SELECTION) {
                context.save ();
                Utils.draw_tabs_and_spaces (this, context);
                context.restore ();
            }
            base.draw_layer (layer, context);
        }
    }
}
