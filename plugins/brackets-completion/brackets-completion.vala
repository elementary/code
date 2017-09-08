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

public const string NAME = _("Brackets Completion");
public const string DESCRIPTION = _("Complete brackets while typing");

public class Scratch.Plugins.BracketsCompletion : Peas.ExtensionBase,  Peas.Activatable {
    Gee.HashMap<string, string> brackets;
    const string[] opening_brackets = {"{", "[", "(", "'", "\"", "`"};
    const string[] closing_brackets = {"}", "]", ")", "'", "\"", "`"};
    Gee.HashMap<uint, string> keys;
    string current_selection = "";
    bool should_complete = false;
    string last_inserted = "";

    Gee.TreeSet<Gtk.TextBuffer> buffers;
    Gtk.TextBuffer current_buffer;
    Gtk.SourceView current_view;

    Scratch.Services.Interface plugins;
    public Object object { owned get; construct; }

    public void update_state () {

    }

    public void activate () {
        buffers = new Gee.TreeSet<Gtk.TextBuffer> ();
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
        keys[Gdk.Key.quoteright] = "'";
        keys[Gdk.Key.quotedbl] = "\"";
        keys[Gdk.Key.grave] = "`";

        plugins = (Scratch.Services.Interface) object;

        plugins.hook_document.connect ((doc) => {
            current_buffer = doc.source_view.buffer;
            current_view = doc.source_view;
            buffers.add (current_buffer);
            doc.source_view.key_press_event.connect (on_key_press);
            doc.source_view.backspace.connect (on_backspace);
        });
    }

    public void deactivate () {
    }

    string get_next_char () { // This breaks on the last character
        Gtk.TextIter start, end;

        current_buffer.get_selection_bounds (out start, out end);
        end.forward_char ();
        string current_text = current_buffer.get_text (start, end, true) ;
        int len = current_text.length;
        return current_text[len - 1:len];
    }

    string get_previous_char () { // This breaks when it is first character
        Gtk.TextIter start, end;

        current_buffer.get_selection_bounds (out start, out end);
        start.backward_char ();
        string current_text = current_buffer.get_text (start, end, true);
        int len = current_text.length;

        return current_text[0:1];
    }

    void on_backspace () {
        if (!current_buffer.has_selection) {
            var left_char = get_previous_char ();
            var right_char = get_next_char ();

            if (left_char in opening_brackets && right_char in closing_brackets) {
                Gtk.TextIter start, end;

                current_buffer.get_selection_bounds (out start, out end);
                start.backward_char ();
                end.forward_char ();
                current_buffer.select_range (start, end);
            }
        }
    }

    void complete_brackets (string opening_bracket) {
        Gtk.TextIter start, end;

        current_buffer.get_selection_bounds (out start, out end);
        current_selection = current_buffer.get_text (start, end, true);

        string closing_bracket = brackets[opening_bracket];
        string text = opening_bracket + current_selection + closing_bracket;

        current_buffer.begin_user_action();
        current_buffer.delete (ref start, ref end);
        current_buffer.insert (ref start, text, text.length);

        current_buffer.get_selection_bounds (out start, out end);
        end.backward_char ();
        start.backward_chars (current_selection.length + 1);
        current_buffer.select_range (start, end);

        current_buffer.end_user_action();
    }

    bool on_key_press (Gdk.EventKey event) {
        if (current_view.has_focus && event.keyval in keys) {
            string bracket = keys[event.keyval];
            if (bracket in opening_brackets) {
                complete_brackets (bracket);
            } else if (bracket in closing_brackets) {
                print("nope");
            }

            return true;
        }

        return false;
    }

    void on_insert_text (ref Gtk.TextIter pos, string new_text, int new_text_length) {
        print("This never happened");
        if (last_inserted == new_text) {
            return;
        }

        if (should_complete && new_text in brackets.keys) {
            string text = current_selection + brackets[new_text];
            int len = text.length;
            last_inserted = text;

            current_buffer.insert (ref pos, text, len);

            last_inserted = null;
            pos.backward_chars (len);
            current_buffer.place_cursor (pos);
        } else if (new_text in brackets.values) { // Handle matching closing brackets.
            var end_pos = pos;
            end_pos.forward_chars (1);

            if (new_text == current_buffer.get_text (pos, end_pos, true)) {
                current_buffer.delete (ref pos, ref end_pos);
                current_buffer.place_cursor (pos);
            }
        }
    }
}

[ModuleInit]
public void peas_register_types (GLib.TypeModule module) {
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type (typeof (Peas.Activatable),
                                     typeof (Scratch.Plugins.BracketsCompletion));
}
