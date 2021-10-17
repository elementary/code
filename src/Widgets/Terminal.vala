/*-
 * Copyright 2019-2021 elementary, Inc. (https://elementary.io)
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Authored by: Michael Aaron Murphy <michael@system76.com>
 */

public class Scratch.Widgets.Terminal : Gtk.ScrolledWindow {
    public signal void toggled (bool active);
    public Gtk.TextBuffer buffer { get; construct; }

    private Gtk.TextView view;
    private double prev_upper_adj = 0;

    public string log {
        owned get {
            return view.buffer.text;
        }
    }

    public Terminal (Gtk.TextBuffer buffer) {
        Object (buffer: buffer);
    }

    construct {
        view = new Gtk.TextView.with_buffer (buffer) {
            cursor_visible = true,
            editable = false,
            margin_end = 6,
            margin_start = 6,
            monospace = true,
            pixels_below_lines = 3,
            wrap_mode = Gtk.WrapMode.WORD
        };
        view.get_style_context ().remove_class (Gtk.STYLE_CLASS_VIEW);

        hscrollbar_policy = Gtk.PolicyType.NEVER;
        expand = true;
        min_content_height = 120;
        add (view);
        get_style_context ().add_class (Granite.STYLE_CLASS_TERMINAL);

        view.size_allocate.connect (() => attempt_scroll ());
    }

    public void attempt_scroll () {
        var adj = vadjustment;

        var units_from_end = prev_upper_adj - adj.page_size - adj.value;
        var view_size_difference = adj.upper - prev_upper_adj;
        if (view_size_difference < 0) {
            view_size_difference = 0;
        }

        if (prev_upper_adj <= adj.page_size || units_from_end <= 50) {
            adj.value = adj.upper;
        }

        prev_upper_adj = adj.upper;
    }
}
