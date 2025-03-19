public class Scratch.Widgets.NavMarkGutterRenderer : Gtk.SourceGutterRendererPixbuf {
    static int navmark_number = 0;
    static int get_next_navmark_number () {
        return navmark_number++;
    }

    private Gee.ArrayList<Gtk.TextMark> mark_list;
    private Gee.List<int> sorted_line_list;
    public Gtk.TextBuffer buffer { get; construct; }
    public bool has_marks {
        get {
            purge_and_sort_mark_list ();
            return mark_list.size > 0;
        }
    }

    public NavMarkGutterRenderer (Gtk.TextBuffer buffer) {
        Object (
            buffer: buffer
        );
    }

    construct {
        mark_list = new Gee.ArrayList<Gtk.TextMark> ();
        sorted_line_list = new Gee.ArrayList<int> ();
        set_size (16);
        set_visible (true);
    }

    private void add_mark (Gtk.TextMark mark) {
        mark_list.add (mark);
        purge_and_sort_mark_list ();
    }

    public void remove_mark (Gtk.TextMark mark) {
        buffer.delete_mark (mark);
        mark_list.remove (mark);
        purge_and_sort_mark_list ();
    }

    public void get_nearest_marked_line (int current_line, bool before, out int nearest_line) {
        nearest_line = before ? -1 : int.MAX;
        Gtk.TextIter? iter;

        purge_and_sort_mark_list ();
        foreach (var mark in mark_list) {
            buffer.get_iter_at_mark (out iter, mark);
            if (iter != null) {
                var line = iter.get_line ();
                if ((before && line < current_line && line > nearest_line) ||
                    (!before && line > current_line && line < nearest_line)) {

                        nearest_line = line;
                }
            }
        }

        if (nearest_line < 0 || nearest_line == int.MAX) {
            nearest_line = current_line;
        }
    }

    public bool has_mark_at_line (int line) {
        return sorted_line_list.contains (line);
    }

    private int get_line_from_mark (Gtk.TextMark mark) requires (!mark.get_deleted ()) {
        Gtk.TextIter? iter = null;
        buffer.get_iter_at_mark (out iter, mark);
        return iter.get_line ();
    }

    // Ensure the list only contains valid marks, one per marked line
    private void purge_and_sort_mark_list () {
        GLib.List<unowned Gtk.TextMark> to_delete = null;
        foreach (var mark in mark_list) {
            if (mark.get_deleted ()) {
                to_delete.append (mark);
            }
        }

        // Remove deleted marks
        foreach (var mark in to_delete) {
            mark_list.remove (mark);
        }

        sorted_line_list.clear ();
        to_delete = null;
        foreach (var mark in mark_list) {
            var line = get_line_from_mark (mark);
            if (!sorted_line_list.contains (line)) {
                sorted_line_list.add (line);
            } else {
                to_delete.append (mark);
            }
        }

        // Remove duplicates (editing can bring two NavMarks onto the same line)
        foreach (var mark in to_delete) {
            buffer.delete_mark (mark);
            mark_list.remove (mark);
        }

        sorted_line_list.sort ();
    }

    public void delete_mark_at_line (int line) {
        foreach (var mark in mark_list) {
            if (line == get_line_from_mark (mark)) {
                buffer.delete_mark (mark);
                mark_list.remove (mark);
                queue_draw ();
                break;
            }
        }
    }

    public void add_mark_at_line (int line) {
        if (has_mark_at_line (line)) {
                return;
        }

        Gtk.TextIter? iter = null;
        buffer.get_iter_at_line_offset (out iter, line, 0);
        var mark = buffer.create_mark ("NavMark%i".printf (get_next_navmark_number ()), iter, true);
        add_mark (mark);
        queue_draw ();
    }

    public override void query_data (
        Gtk.TextIter start,
        Gtk.TextIter end,
        Gtk.SourceGutterRendererState state
    ) {
        var line = start.get_line ();
        if (sorted_line_list.contains (line)) {
            icon_name = "edit-symbolic";
        } else {
            icon_name = "";
        }
    }

    public override void activate (Gtk.TextIter iter, Gdk.Rectangle rect, Gdk.Event event) {
        if (has_mark_at_line (iter.get_line ())) {
            delete_mark_at_line (iter.get_line ());
        } else {
            add_mark_at_line (iter.get_line ());
        }

        queue_draw ();
    }

    public override bool query_activatable (Gtk.TextIter iter, Gdk.Rectangle rect, Gdk.Event event) {
        return true;
    }
}
