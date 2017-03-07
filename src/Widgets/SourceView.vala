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

namespace Scratch.Widgets {

    public class SourceView : Gtk.SourceView {
        public new Gtk.SourceBuffer buffer;
        public Gtk.TextMark mark;
        public Gtk.SourceLanguageManager manager;
        public Gtk.SourceStyleSchemeManager style_scheme_manager;

        // Commmon tags
        public Gtk.TextTag warning_tag;
        public Gtk.TextTag error_tag;

        // Properties
        private string font;
        private uint selection_changed_timer = 0;
        private Gtk.TextIter last_select_start_iter;
        private Gtk.TextIter last_select_end_iter;

        // Consts
        // Pause after end user highlighting to confirm select,in ms
        private const uint SELECTION_CHANGED_PAUSE = 400;


        // Signals
        public signal void style_changed (Gtk.SourceStyleScheme style);
        public signal void language_changed (Gtk.SourceLanguage? language);
        public signal void selection_changed (Gtk.TextIter start_iter, Gtk.TextIter end_iter);
        public signal void deselected ();

        public SourceView () {
            // Create general objects
            manager = Gtk.SourceLanguageManager.get_default ();
            style_scheme_manager = new Gtk.SourceStyleSchemeManager ();
            buffer = new Gtk.SourceBuffer (null);
            this.set_buffer (buffer);

            // Set some settings
            buffer.highlight_syntax = true;
            smart_home_end = Gtk.SourceSmartHomeEndType.AFTER;
            buffer.mark_set.connect (on_mark_set);
            // Create common tags
            this.warning_tag = new Gtk.TextTag ("warning_bg");
            this.warning_tag.background_rgba = Gdk.RGBA () { red = 1.0, green = 1.0, blue = 0, alpha = 0.8 };

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

            this.scroll_event.connect ((key_event) => {
                if ((Gdk.ModifierType.CONTROL_MASK in key_event.state) && key_event.delta_y < 0) {
                    Scratch.ScratchApp.instance.get_last_window ().zoom_in ();
                    return true;
                } else if ((Gdk.ModifierType.CONTROL_MASK in key_event.state) && key_event.delta_y > 0) {
                    Scratch.ScratchApp.instance.get_last_window ().zoom_out ();
                    return true;
                }

                return false;
            });

            this.key_press_event.connect ((key_event) => {
                if (Gdk.ModifierType.CONTROL_MASK in key_event.state) {
                    switch (key_event.keyval) {
                        case Gdk.Key.plus:
                            Scratch.ScratchApp.instance.get_last_window ().zoom_in ();
                            return true;
                        case Gdk.Key.minus:
                            Scratch.ScratchApp.instance.get_last_window ().zoom_out ();
                            return true;
                        case 0x30:
                            Scratch.ScratchApp.instance.get_last_window ().set_default_zoom ();
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
                set_language (null);
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
                    set_language (lang);
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
            if (!value)
                return;

            this.font = ScratchApp.instance.default_font;
        }

        public void change_syntax_highlight_from_file (File file) {
            try {
                var info = file.query_info ("standard::*", FileQueryInfoFlags.NONE, null);
                var mime_type = ContentType.get_mime_type (info.get_attribute_as_string (FileAttribute.STANDARD_CONTENT_TYPE));
                set_language (manager.guess_language (file.get_path (), mime_type));
            } catch (Error e) {
                critical (e.message);
            }

            // Fake file type detection
            // "Not all files are equal"
            if (file.get_basename () == "CMakeLists.txt") {
                set_language (manager.get_language ("cmake"));
            }

        }

        private void restore_settings () {
            auto_indent = Scratch.settings.auto_indent;
            show_right_margin = Scratch.settings.show_right_margin;
            right_margin_position = Scratch.settings.right_margin_position;
            show_line_numbers = Scratch.settings.show_line_numbers;
            highlight_current_line = Scratch.settings.highlight_current_line;
            buffer.highlight_matching_brackets = Scratch.settings.highlight_matching_brackets;
            if (settings.draw_spaces) {
                draw_spaces = Gtk.SourceDrawSpacesFlags.TAB;
                draw_spaces |= Gtk.SourceDrawSpacesFlags.SPACE;
            } else {
                draw_spaces = Gtk.SourceDrawSpacesFlags.NBSP;
            }

            insert_spaces_instead_of_tabs = Scratch.settings.spaces_instead_of_tabs;
            tab_width = (uint) Scratch.settings.indent_width;
            if (settings.line_break) {
                set_wrap_mode (Gtk.WrapMode.WORD);
            } else {
                set_wrap_mode (Gtk.WrapMode.NONE);
            }

            this.font = Scratch.settings.font;
            use_default_font (Scratch.settings.use_system_font);
            override_font (Pango.FontDescription.from_string (this.font));
            buffer.style_scheme = style_scheme_manager.get_scheme (Scratch.settings.style_scheme);
            this.style_changed (buffer.style_scheme);
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
            this.style_changed (buffer.style_scheme);
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
            this.buffer.get_selection_bounds (out start, out end);
            string selected = this.buffer.get_text (start, end, true);
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
            this.buffer.get_selection_bounds (out start, out end);

            if (selection != "") {
                this.buffer.insert (ref end, selection, -1);
            // If nothing is selected duplicate current line
            } else {
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

        public void set_language (Gtk.SourceLanguage? lang) {
            //lang can be null, in the case of *No highlight style* aka Normal text
            this.buffer.set_language (lang);
            this.language_changed (lang);
        }


        void on_mark_set (Gtk.TextIter loc, Gtk.TextMark mar) {
            // Weed out user movement for text selection changes
            Gtk.TextIter start, end;
            this.buffer.get_selection_bounds (out start,out end);

            if (start == last_select_start_iter && end == last_select_end_iter)
                return;

            if (selection_changed_timer !=0 &&
                MainContext.get_thread_default ().find_source_by_id (selection_changed_timer) != null)
                Source.remove (selection_changed_timer);

            // Fire deselected immediatly
            if (!this.buffer.get_has_selection ()) {
                deselected ();
            // Don't fire signal till we think select movement is done
            } else {
                selection_changed_timer = Timeout.add (SELECTION_CHANGED_PAUSE, selection_changed_event);
            }

        }

        bool selection_changed_event () {
            Gtk.TextIter start, end;
            bool selected = this.buffer.get_selection_bounds (out start,out end);
            if (selected) {
                selection_changed (start,end);
            } else {
                deselected ();
            }

            return false;
        }

        public override void draw_layer (Gtk.TextViewLayer layer, Cairo.Context context) {
            if (layer == Gtk.TextViewLayer.ABOVE) {
                context.save ();
                draw_tabs_and_spaces (this, context);
                context.restore ();
            }
            base.draw_layer (layer, context);
        }

/*        static void get_leading_trailing (Gtk.TextIter iter, out Gtk.TextIter leading, out Gtk.TextIter trailing)
        {    
            leading = iter;
            leading.set_line_offset (0);
            while (!leading.is_end ())
            {
	            unichar ch = leading.get_char ();

	            if (!ch.isspace ())
	            {
		            break;
	            }

	            leading.forward_char ();
            }
            
            trailing = iter;
            if (!trailing.ends_line ())
            {
	            trailing.forward_to_line_end ();
            }

            while (!trailing.starts_line ())
            {
	            Gtk.TextIter prev;
	            unichar ch;

	            prev = trailing;
	            prev.backward_char ();

	            ch = prev.get_char ();
	            if (!ch.isspace ())
	            {
		            break;
	            }

	            trailing = prev;
            }
        }*/

        static void get_end_iter (Gtk.TextView text_view,
	              Gtk.TextIter start_iter,
	              out Gtk.TextIter end_iter,
	              int         x,
	              int         y,
	              bool     is_wrapping)
        {
	        int min, max, i;
	        Gdk.Rectangle rect;

	        end_iter.assign (start_iter);
	        if (!end_iter.ends_line ())
	        {
		        end_iter.forward_to_line_end ();
	        }

	        /* check if end_iter is inside the bounding box anyway */
	        text_view.get_iter_location (end_iter, out rect);
	        if ((is_wrapping && rect.y < y) ||
	            (!is_wrapping && rect.x < x))
	        {
		        return;
	        }

	        min = start_iter.get_line_offset ();
	        max = end_iter.get_line_offset ();

	        while (max >= min)
	        {
		        i = (min + max) >> 1;
		        end_iter.set_line_offset (i);
		        text_view.get_iter_location (end_iter, out rect);

		        if ((is_wrapping && rect.y < y) ||
		            (!is_wrapping && rect.x < x))
		        {
			        min = i + 1;
		        }
		        else if (( is_wrapping && rect.y > y) ||
			         (!is_wrapping && rect.x > x))
		        {
			        max = i - 1;
		        }
		        else
		        {
			        break;
		        }
	        }
        }

        static void draw_space_at_iter (Cairo.Context cr,
		            Gtk.TextView  view,
		            Gtk.TextIter  iter,
		            Gdk.Rectangle  rect)
        {
	        int x, y;
	        double w;

	        view.buffer_to_window_coords (Gtk.TextWindowType.TEXT, rect.x, rect.y + rect.height * 2 / 3, out x, out y);

	        /* if the space is at a line-wrap position we get 0 width
	         * so we fallback to the height */
	        w = rect.width != 0 ? rect.width : rect.height;

	        cr.save ();
	        cr.move_to (x + w * 0.5, y);
	        cr.arc (x + w * 0.5, y, 0.8, 0, 2 * Math.PI);
	        cr.restore ();
        }

        static void draw_spaces_at_iter (Cairo.Context cr,
		             Gtk.TextView text_view,
		             Gtk.TextIter iter)
        {
	        unichar c;
	        Gdk.Rectangle rect;

	        text_view.get_iter_location (iter, out rect);

	        c = iter.get_char ();

	        /*if (c == '\t')
	        {
		        draw_tab_at_iter (cr, text_view, iter, rect);
	        }
	        else if (c.break_type () == UnicodeBreakType.NON_BREAKING_GLUE)
	        {
		        draw_nbsp_at_iter (cr, text_view, iter, rect,
		                           c == 0x202F);
	        }
	        else if (c.type () == UnicodeType.SPACE_SEPARATOR)
	        {
		        draw_space_at_iter (cr, text_view, iter, rect);
	        }
	        else if (iter.ends_line ())
	        {
		        draw_newline_at_iter (cr, text_view, iter, rect);
	        }*/
            if (c.type () == UnicodeType.SPACE_SEPARATOR)
	        {
		        draw_space_at_iter (cr, text_view, iter, rect);
	        }
        }

        void draw_tabs_and_spaces (Gtk.SourceView view, Cairo.Context cr)
        {
	        Gtk.TextView text_view;
	        Gdk.Rectangle clip;
	        int x1, y1, x2, y2;
	        Gtk.TextIter s, e;
	        Gtk.TextIter leading, trailing, lineend;
	        bool is_wrapping;

	        if (!Gdk.cairo_get_clip_rectangle (cr, out clip))
	        {
		        return;
	        }

	        text_view = this;

	        is_wrapping = text_view.get_wrap_mode() != Gtk.WrapMode.NONE;

	        x1 = clip.x;
	        y1 = clip.y;
	        x2 = x1 + clip.width;
	        y2 = y1 + clip.height;

            text_view.window_to_buffer_coords (Gtk.TextWindowType.TEXT, x1, y1, out x1, out y1);
            text_view.window_to_buffer_coords (Gtk.TextWindowType.TEXT, x2, y2, out x2, out y2);

            text_view.get_iter_at_location (out s, x1, y1);
	        text_view.get_iter_at_location (out e, x2, y2);

            // TODO: Load color from style
	        cr.set_source_rgba (1.0, 1.0, 1.0, 1.0);

	        cr.set_line_width (0.8);
	        cr.translate (-0.5, -0.5);

	        //get_leading_trailing (s, out leading, out trailing);
	        get_end_iter (text_view, s, out lineend, x2, y2, is_wrapping);

	        while (true)
	        {
		        unichar c = s.get_char ();
		        int ly;

		        /*if (c.isspace () && space_needs_drawing (view, &s, &leading, &trailing))
		        {
			        draw_spaces_at_iter (cr, text_view, &s);
		        }*/

                if (c.isspace ())
		        {
			        draw_spaces_at_iter (cr, text_view, s);
		        }

		        if (!s.forward_char ())
		        {
			        break;
		        }

		        if (s.compare (lineend) > 0)
		        {
			        if (s.compare (e) > 0)
			        {
				        break;
			        }

			        /* move to the first iter in the exposed area of
			         * the next line */
			        if (!s.starts_line () && !s.forward_line ())
			        {
				        break;
			        }
			        text_view.get_line_yrange (s, out ly, null);

			        text_view.get_iter_at_location (out s, x1, ly);

			        /* move back one char otherwise tabs may not
			         * be redrawn */
			        if (!s.starts_line ())
			        {
				        s.backward_char ();
			        }

			        //get_leading_trailing (s, out leading, out trailing);
			        get_end_iter (text_view, s, out lineend,
				              x2, y2, is_wrapping);
		        }
	        };

	        cr.stroke ();
        }

    }
}
