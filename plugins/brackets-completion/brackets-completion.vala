/*
 * SPDX-License-Identifier: LGPL-3.0-or-later
 * SPDX-FileCopyrightText: 2025 elementary, Inc. (https://elementary.io)
 *                         2013 Mario Guerriero <mario@elementaryos.org>
 */

public class Scratch.Plugins.BracketsCompletion : Peas.ExtensionBase, Scratch.Services.ActivatablePlugin {
    private const string[] VALID_NEXT_CHARS = {
        "", " ", "\b", "\r", "\n", "\t", ",", ".", ";", ":"
    };

    public Object object { owned get; set construct; }

    private Gee.HashMap<string, string> brackets;
    private Gee.HashMap<uint, string> keys;
    private Gtk.TextBuffer current_buffer;
    private Scratch.Services.Interface plugins;
    private Scratch.Widgets.SourceView current_source_view;
    private string previous_selection = "";

    public void activate () {
        brackets = new Gee.HashMap<string, string> ();
        brackets["("] = ")";
        brackets["["] = "]";
        brackets["{"] = "}";
        brackets["'"] = "'";
        brackets["\""] = "\"";
        brackets["`"] = "`";

        keys = new Gee.HashMap<uint, string> ();
        keys[Gdk.Key.braceleft] = "{";
        keys[Gdk.Key.bracketleft] = "[";
        keys[Gdk.Key.parenleft] = "(";
        keys[Gdk.Key.braceright] = "}";
        keys[Gdk.Key.bracketright] = "]";
        keys[Gdk.Key.parenright] = ")";
        keys[Gdk.Key.quoteright] = "'";
        keys[Gdk.Key.quotedbl] = "\"";
        keys[Gdk.Key.grave] = "`";

        plugins = (Scratch.Services.Interface) object;
        plugins.hook_document.connect (on_hook_document);
    }

    public void deactivate () {
        plugins.hook_document.disconnect (on_hook_document);
    }

    public void update_state () {}

    private void on_hook_document (Scratch.Services.Document doc) {
        current_buffer = doc.source_view.buffer;

        if (current_source_view != null) {
            current_source_view.key_press_event.disconnect (on_key_down);
            current_source_view.event_after.disconnect (on_event_after);
            current_source_view.backspace.disconnect (on_backspace);
        }

        current_source_view = doc.source_view;

        current_source_view.key_press_event.connect (on_key_down);
        current_source_view.event_after.connect (on_event_after);
        current_source_view.backspace.connect (on_backspace);
    }

    private string get_next_char () {
        Gtk.TextIter start, end;

        current_buffer.get_selection_bounds (null, out end);
        start = end;
        end.forward_char ();

        if (start == end) {
            return "";
        }

        return current_buffer.get_text (start, end, true) ;
    }

    private string get_previous_char () {
        Gtk.TextIter start, end;

        current_buffer.get_selection_bounds (out start, null);
        end = start;
        start.backward_char ();

        if (start == end) {
            return "";
        }

        return current_buffer.get_text (start, end, true) ;
    }

    private void on_backspace () {
        if (!current_buffer.has_selection) {
            string left_char = get_previous_char ();
            string right_char = get_next_char ();

            if (brackets.has_key (left_char) && right_char in brackets.values && brackets[left_char] == right_char) {
                Gtk.TextIter start, end;

                current_buffer.get_selection_bounds (out start, out end);
                start.backward_char ();
                end.forward_char ();
                current_buffer.select_range (start, end);
            }
        }
    }

    private void complete_brackets (string opening_bracket) {
        Gtk.TextIter start, end;

        if (opening_bracket == "'" || opening_bracket == "\"") {
            current_buffer.get_selection_bounds (out start, null);
            end = start;
            start.backward_chars (2);
            end.backward_char ();

            var before_bracket_char = current_buffer.get_text (start, end, false);
            if (before_bracket_char.get_char ().isalpha ()) {
                return;
            }
        }

        current_buffer.get_selection_bounds (out start, out end);

        string closing_bracket = brackets[opening_bracket];
        string text = previous_selection + closing_bracket;

        current_buffer.begin_user_action ();
        current_buffer.insert (ref start, text, -1);

        current_buffer.get_selection_bounds (out start, out end);
        end.backward_char ();
        start.backward_chars (previous_selection.char_count () + 1);
        current_buffer.select_range (start, end);

        current_buffer.end_user_action ();
    }

    private bool has_valid_next_char (string next_char) {
        return next_char in VALID_NEXT_CHARS ||
               next_char in brackets.values ||
               brackets.has_key (next_char);
    }

    private void delete_next_char () {
        current_buffer.begin_user_action ();

        Gtk.TextIter start;
        current_buffer.get_iter_at_mark (out start, current_buffer.get_insert ());
        start.backward_char ();
        current_buffer.insert (ref start, previous_selection, -1);

        current_buffer.get_iter_at_mark (out start, current_buffer.get_insert ());
        Gtk.TextIter end = start;
        end.forward_char ();
        if (end != start) {
            current_buffer.delete (ref start, ref end);
        }

        current_buffer.end_user_action ();
    }

    private bool on_key_down (Gdk.EventKey event) {
        if (Gdk.ModifierType.MOD1_MASK in event.state || Gdk.ModifierType.CONTROL_MASK in event.state) {
            return false;
        }

        if (!current_buffer.has_selection) {
            previous_selection = "";
            return false;
        }

        if (keys.has_key (event.keyval) && current_buffer.has_selection) {
            Gtk.TextIter start, end;
            current_buffer.get_selection_bounds (out start, out end);

            previous_selection = current_buffer.get_text (start, end, false);
        }

        return false;
    }

    private void check_bracket_indent () {
        var next_char = get_next_char ();
        if (next_char in brackets.values) {
            Gtk.TextIter start, end;

            current_buffer.get_selection_bounds (out start, null);
            start.backward_line ();
            start.forward_to_line_end ();
            end = start;
            start.backward_char ();

            var prev_char = current_buffer.get_text (start, end, false);
            if (brackets[prev_char] == next_char) {
                current_buffer.begin_user_action ();

                current_buffer.get_selection_bounds (out start, out end);
                start.backward_chars (start.get_line_offset ());

                var current_indent = current_buffer.get_text (start, end, false);

                var spaces = current_source_view.insert_spaces_instead_of_tabs;
                var indent = spaces ? string.nfill (current_source_view.tab_width, ' ') : "\t";
                current_buffer.insert_at_cursor (indent, -1);

                Gtk.TextIter iter;
                current_buffer.get_iter_at_mark (out iter, current_buffer.get_insert ());
                var mark = current_buffer.create_mark (null, iter, true);
                current_buffer.insert_at_cursor ("\n" + current_indent, -1);

                current_buffer.get_iter_at_mark (out iter, mark);
                current_buffer.place_cursor (iter);
                current_buffer.delete_mark (mark);

                current_buffer.end_user_action ();
            }
        }
    }

    private void on_event_after (Gdk.Event root_event) {
        if (root_event.type != Gdk.EventType.KEY_PRESS) {
            return;
        }

        var event = root_event.key;

        if (current_source_view.auto_indent && (event.keyval == Gdk.Key.Return || event.keyval == Gdk.Key.KP_Enter)) {
            check_bracket_indent ();
        }

        if (keys.has_key (event.keyval) &&
            !(Gdk.ModifierType.MOD1_MASK in event.state) &&
            !(Gdk.ModifierType.CONTROL_MASK in event.state)) {

            string bracket = keys[event.keyval];
            string next_char = get_next_char ();
            string prev_char = get_previous_char ();
            bool brackets_match = next_char == bracket && prev_char == bracket;

            if (brackets_match && !current_buffer.has_selection && bracket in brackets.values) {
                delete_next_char ();
                return;
            }

            if (!brackets.has_key (prev_char)) {
                return;
            }

            if (brackets.has_key (bracket) &&
                (current_buffer.has_selection || has_valid_next_char (next_char))) {
                complete_brackets (bracket);
            }
        }

        return;
    }
}

[ModuleInit]
public void peas_register_types (GLib.TypeModule module) {
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type (
        typeof (Scratch.Services.ActivatablePlugin),
        typeof (Scratch.Plugins.BracketsCompletion)
    );
}
