// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/***
  BEGIN LICENSE

  Copyright (C) 2020 Igor Montagner <igordsm@gmail.com>
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

public class Code.Plugins.MarkdownActions : Peas.ExtensionBase, Scratch.Services.ActivatablePlugin {
    Scratch.Widgets.SourceView current_source;
    Scratch.Services.Interface plugins;

    public Object object { owned get; set construct; }

    public void update_state () {}

    public void activate () {
        plugins = (Scratch.Services.Interface) object;
        plugins.hook_document.connect ((doc) => {
            if (current_source != null) {
                current_source.key_press_event.disconnect (shortcut_handler);
                current_source.notify["language"].disconnect (configure_shortcuts);
            }

            current_source = doc.source_view;
            configure_shortcuts ();

            current_source.notify["language"].connect (configure_shortcuts);
        });
    }

    private void configure_shortcuts () {
        var lang = current_source.language;
        if (lang != null && lang.id == "markdown") {
            current_source.key_press_event.connect (shortcut_handler);
        } else {
            current_source.key_press_event.disconnect (shortcut_handler);
        }
    }

    private bool shortcut_handler (Gdk.EventKey evt) {
        var control = (evt.state & Gdk.ModifierType.CONTROL_MASK) != 0;
        var shift = (evt.state & Gdk.ModifierType.SHIFT_MASK) != 0;
        var other_mods = (evt.state & Gtk.accelerator_get_default_mod_mask () &
                          ~Gdk.ModifierType.SHIFT_MASK &
                          ~Gdk.ModifierType.CONTROL_MASK) != 0;

        if (evt.is_modifier == 1 || other_mods == true) {
            return false;
        }

        if (control && shift) {
            switch (evt.keyval) {
                case Gdk.Key.B:
                    add_markdown_tag ("**");
                    return true;
                case Gdk.Key.I:
                    add_markdown_tag ("_");
                    return true;
                case Gdk.Key.K:
                    insert_link ();
                    break;
            }
        }

        if (evt.keyval == Gdk.Key.Return) {
            // Get line text on which return was pressed
            var line = get_current_line ();
            if (line.strip () == "") {
                return false;
            }

            string ul_marker;
            int indent_spaces, ol_number;
            string item_text = "";
            if (parse_unordered_list_item (line, out ul_marker, out item_text)) {
                if (item_text.strip () == "") { // empty list item
                    delete_empty_item ();
                } else {
                    string to_insert = "\n%s".printf (ul_marker);
                    current_source.buffer.insert_at_cursor (to_insert, to_insert.length);
                }

                return true;
            } else if (parse_ordered_list_item (line, out ol_number, out item_text, out indent_spaces, null)) {
                if (item_text.length == 0) {
                    delete_empty_item ();
                } else {
                    string to_insert = "\n%s%d. ".printf (string.nfill (indent_spaces, ' '), ++ol_number);
                    current_source.buffer.insert_at_cursor (to_insert, to_insert.length);
                    // Check following lines to see if renumbering required
                    fix_ordered_list_numbering (indent_spaces, ol_number);
                }
                return true;
            }
        }
        return false;
    }

    private void delete_empty_item () {
        Gtk.TextIter start, end;
        var current_buffer = current_source.buffer;
        current_buffer.get_iter_at_offset (out start, current_buffer.cursor_position);
        start.backward_chars (start.get_line_offset ());
        end = start;
        end.forward_to_line_end ();
        current_buffer.delete (ref start, ref end);
        current_buffer.insert_at_cursor ("\n", 1);
        current_buffer.get_iter_at_offset (out start, current_buffer.cursor_position);
    }

    // Starting on the line where a numered list item was inserted, check if renumbering required
    private void fix_ordered_list_numbering (int indent_spaces, int inserted_number) {
        Gtk.TextIter next;
        var current_buffer = current_source.buffer;

        current_buffer.get_iter_at_offset (out next, current_buffer.cursor_position);
        int point_offset = 0, next_indent_spaces = 0, count = inserted_number, next_count = 0;
        string item_text = "";
        // Search for ordered list lines at the same level until level falls below or end of doc
        while (next.forward_line () &&
               parse_ordered_list_item (
                    get_current_line (next),
                    out next_count,
                    out item_text,
                    out next_indent_spaces,
                    out point_offset
                ) &&
               next_indent_spaces >= indent_spaces
        ) {
            // Only update lines at same indent within same block
            if (next_indent_spaces == indent_spaces) {
                count++;
                next.forward_chars (indent_spaces);
                var next_mark = current_buffer.create_mark (null, next, true);
                var start = next;
                var end = start;
                end.forward_chars (point_offset);

                current_buffer.delete (ref start, ref end);
                current_buffer.get_iter_at_mark (out next, next_mark);

                var to_insert = "%d".printf (count);
                current_buffer.insert (ref next, to_insert, to_insert.length);
            }
        }
    }

    private string get_current_line (Gtk.TextIter? start = null) {
        var current_buffer = current_source.buffer;
        Gtk.TextIter end;

        if (start == null) {
            current_buffer.get_iter_at_offset (out start, current_buffer.cursor_position);
        }

        start.backward_chars (start.get_line_offset ());
        end = start;
        end.forward_to_line_end ();

        return current_buffer.get_text (start, end, false);
    }

    private bool parse_ordered_list_item (
        string line,
        out int current_number,
        out string item_text,
        out int indent_spaces,
        out int first_point_pos
    ) {

        item_text = "";
        indent_spaces = -1;
        current_number = -1;
        first_point_pos = line.index_of_char ('.'); //TODO Handle ")"  Ignored escaped?

        if (first_point_pos < 0) {
            return false;
        }


        item_text = line.substring (first_point_pos + 1).strip ();

        var line_start = line.substring (0, first_point_pos);
        indent_spaces = line_start.last_index_of_char (' ') + 1;
        if (!int.try_parse (line_start, out current_number)) {
            return false;
        }

        return indent_spaces >= 0 && current_number >= 1;
    }

    private bool parse_unordered_list_item (string line, out string ul_marker, out string item_text) {
        var chugged_line = line.chug ();
        if ((chugged_line[0] == '*' || chugged_line[0] == '-') &&
            chugged_line[1] == ' ') {
            var ul_marker_index = line.index_of_char (chugged_line[0]);
            ul_marker = "%s%c ".printf (string.nfill (ul_marker_index, ' '), chugged_line[0]);
            item_text = chugged_line.substring (2, -1);
            return true;
        }

        ul_marker = "";
        return false;
    }

    private void insert_link () {
        var current_buffer = current_source.buffer;
        current_buffer.begin_user_action ();
        if (current_buffer.has_selection) {
            insert_around_selection ("[", "]");
            current_buffer.insert_at_cursor ("()", 2);
            go_back_n_chars (1);
        } else {
            current_buffer.insert_at_cursor ("[]", 2);
            current_buffer.insert_at_cursor ("()", 2);
            go_back_n_chars (3);
        }
        current_buffer.end_user_action ();
    }

    private void go_back_n_chars (int back_chars) {
        Gtk.TextIter insert_position;
        var current_buffer = current_source.buffer;
        current_buffer.get_iter_at_offset (out insert_position, current_buffer.cursor_position - back_chars);
        current_buffer.place_cursor (insert_position);
    }

    private void insert_around_selection (string before, string after) {
        Gtk.TextIter start, end;
        var current_buffer = current_source.buffer;
        current_buffer.get_selection_bounds (out start, out end);
        var mark_end = new Gtk.TextMark (null);
        current_buffer.add_mark (mark_end, end);
        current_buffer.place_cursor (start);
        current_buffer.insert_at_cursor (before, before.length);

        current_buffer.get_iter_at_mark (out end, mark_end);
        current_buffer.place_cursor (end);
        current_buffer.insert_at_cursor (after, after.length);
    }

    public void add_markdown_tag (string tag) {
        var current_buffer = current_source.buffer;
        current_buffer.begin_user_action ();
        if (current_buffer.has_selection) {
            insert_around_selection (tag, tag);
        } else {
            current_buffer.insert_at_cursor (tag, tag.length);
            current_buffer.insert_at_cursor (tag, tag.length);
        }
        current_buffer.end_user_action ();
        go_back_n_chars (tag.length);
    }

    public void deactivate () {
        if (current_source != null) {
            current_source.key_press_event.disconnect (shortcut_handler);
            current_source.notify["language"].disconnect (configure_shortcuts);
        }
    }
}

[ModuleInit]
public void peas_register_types (TypeModule module) {
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type (typeof (Scratch.Services.ActivatablePlugin),
                                     typeof (Code.Plugins.MarkdownActions));
}
