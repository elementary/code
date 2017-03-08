namespace Scratch.Utils {
    static void get_end_iter (Gtk.TextView text_view, Gtk.TextIter start_iter, out Gtk.TextIter end_iter, int x, int y, bool is_wrapping) {
        int min, max, i;
        Gdk.Rectangle rect;

        end_iter = start_iter;

        if (!end_iter.ends_line ()) {
            end_iter.forward_to_line_end ();
        }

        text_view.get_iter_location (end_iter, out rect);

        if ((is_wrapping && rect.y < y) || (!is_wrapping && rect.x < x)) {
            return;
        }

        min = start_iter.get_line_offset ();
        max = end_iter.get_line_offset ();

        while (max >= min) {
            i = (min + max) >> 1;
            end_iter.set_line_offset (i);
            text_view.get_iter_location (end_iter, out rect);

            if ((is_wrapping && rect.y < y) || (!is_wrapping && rect.x < x)) {
                min = i + 1;
            } else if ((is_wrapping && rect.y > y) || (!is_wrapping && rect.x > x)) {
                max = i - 1;
            } else {
                break;
            }
        }
    }

    static void draw_space_at_iter (Cairo.Context cr, Gtk.TextView view, Gtk.TextIter iter, Gdk.Rectangle rect) {
        int x, y;
        double w;

        view.buffer_to_window_coords (Gtk.TextWindowType.TEXT, rect.x, rect.y + rect.height * 2 / 3, out x, out y);

        w = rect.width != 0 ? rect.width : rect.height;

        cr.save ();
        cr.move_to (x + w * 0.5, y);
        cr.arc (x + w * 0.5, y, 0.8, 0, 2 * Math.PI);
        cr.restore ();
    }

    static void draw_tab_at_iter (Cairo.Context cr, Gtk.TextView view, Gtk.TextIter iter, Gdk.Rectangle rect) {
        int x, y;
        double w, h;

        view.buffer_to_window_coords (Gtk.TextWindowType.TEXT, rect.x, rect.y + rect.height * 2 / 3, out x, out y);

        w = rect.width != 0 ? rect.width : rect.height;
        h = rect.height;

        cr.save ();
        cr.move_to (x + w * 1 / 8, y);
        cr.rel_line_to (w * 6 / 8, 0);
        cr.rel_line_to (-h * 1 / 4, -h * 1 / 4);
        cr.rel_move_to (+h * 1 / 4, +h * 1 / 4);
        cr.rel_line_to (-h * 1 / 4, +h * 1 / 4);
        cr.restore ();
    }

    static void draw_nbsp_at_iter (Cairo.Context cr, Gtk.TextView view, Gtk.TextIter iter, Gdk.Rectangle rect, bool narrowed) {
        int x, y;
        double w, h;

        view.buffer_to_window_coords (Gtk.TextWindowType.TEXT, rect.x, rect.y + rect.height / 2, out x, out y);

        w = rect.width != 0 ? rect.width : rect.height;
        h = rect.height;

        cr.save ();
        cr.move_to (x + w * 1 / 6, y);
        cr.rel_line_to (w * 4 / 6, 0);
        cr.rel_line_to (-w * 2 / 6, +h * 1 / 4);
        cr.rel_line_to (-w * 2 / 6, -h * 1 / 4);

        if (narrowed) {
            cr.fill ();
        } else {
            cr.stroke ();
        }

        cr.restore ();
    }

    static void draw_spaces_at_iter (Cairo.Context cr, Gtk.TextView text_view, Gtk.TextIter iter) {
        unichar c;
        Gdk.Rectangle rect;

        text_view.get_iter_location (iter, out rect);

        c = iter.get_char ();

        if (c == '\t') {
            draw_tab_at_iter (cr, text_view, iter, rect);
        } else if (c.break_type () == UnicodeBreakType.NON_BREAKING_GLUE) {
            draw_nbsp_at_iter (cr, text_view, iter, rect, c == 0x202F);
        } else if (c.type () == UnicodeType.SPACE_SEPARATOR) {
            draw_space_at_iter (cr, text_view, iter, rect);
        } else if (c.type () == UnicodeType.SPACE_SEPARATOR) {
            draw_space_at_iter (cr, text_view, iter, rect);
        }
    }

    static void draw_tabs_and_spaces (Gtk.SourceView view, Cairo.Context cr) {
        Gtk.TextIter selection_start, selection_end;
        view.buffer.get_selection_bounds (out selection_start, out selection_end);

        Gtk.TextView text_view;
        Gdk.Rectangle clip;
        int x1, y1, x2, y2;
        Gtk.TextIter s, e;
        Gtk.TextIter lineend;
        bool is_wrapping;

        if (!Gdk.cairo_get_clip_rectangle (cr, out clip)) {
            return;
        }

        text_view = view;

        is_wrapping = text_view.get_wrap_mode () != Gtk.WrapMode.NONE;

        x1 = clip.x;
        y1 = clip.y;
        x2 = x1 + clip.width;
        y2 = y1 + clip.height;

        text_view.window_to_buffer_coords (Gtk.TextWindowType.TEXT, x1, y1, out x1, out y1);
        text_view.window_to_buffer_coords (Gtk.TextWindowType.TEXT, x2, y2, out x2, out y2);

        text_view.get_iter_at_location (out s, x1, y1);
        text_view.get_iter_at_location (out e, x2, y2);

        cr.set_source_rgba (1.0, 1.0, 1.0, 1.0);

        cr.set_line_width (0.8);
        cr.translate (-0.5, -0.5);

        get_end_iter (text_view, s, out lineend, x2, y2, is_wrapping);

        while (true) {
            unichar c = s.get_char ();
            int ly;

            if (c.isspace () && s.compare (selection_start) >= 0 && s.compare (selection_end) < 0) {
                draw_spaces_at_iter (cr, text_view, s);
            }

            if (!s.forward_char ()) {
                break;
            }

            if (s.compare (lineend) > 0) {
                if (s.compare (e) > 0) {
                    break;
                }

                if (!s.starts_line () && !s.forward_line ()) {
                    break;
                }

                text_view.get_line_yrange (s, out ly, null);
                text_view.get_iter_at_location (out s, x1, ly);

                if (!s.starts_line ()) {
                    s.backward_char ();
                }

                get_end_iter (text_view, s, out lineend, x2, y2, is_wrapping);
            }
        }

        cr.stroke ();
    }
}
