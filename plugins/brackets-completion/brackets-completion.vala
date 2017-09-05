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

    MainWindow window;
    Gee.TreeSet<Gtk.TextBuffer> buffers;
    Gtk.TextBuffer current_buffer;

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
        brackets["<"] = ">";
        brackets["⟨"] = "⟩";
        brackets["｢"] = "｣";
        brackets["⸤"] = "⸥";
        brackets["‘"] = "‘";
        brackets["'"] = "'";
        brackets["\""] = "\"";

        keys = new Gee.HashMap<uint, string> ();
        keys[Gdk.Key.braceleft] = "{";
        keys[Gdk.Key.bracketleft] = "[";
        keys[Gdk.Key.parenleft] = "(";
        keys[Gdk.Key.quoteright] = "'";
        keys[Gdk.Key.quotedbl] = "\"";
        keys[Gdk.Key.grave] = "`";

        plugins = (Scratch.Services.Interface) object;

        plugins.hook_window.connect ((w) => {
            window = w;
            window.key_press_event.disconnect (on_key_press);
            window.key_press_event.connect (on_key_press);
        });

        plugins.hook_document.connect ((doc) => {
            current_buffer = doc.source_view.buffer;
            current_buffer.insert_text.disconnect (on_insert_text);
            current_buffer.insert_text.connect (on_insert_text);
            current_buffer.end_user_action.disconnect (on_action_finished);
            current_buffer.end_user_action.connect (on_action_finished);
            buffers.add (current_buffer);

            doc.source_view.backspace.connect (() => {
                Gtk.TextIter start, end;

                current_buffer.get_selection_bounds (out start, out end);
                current_selection = current_buffer.get_text (start, end, true);

                if (current_selection.length == 0) {
                    start.backward_char ();
                    var left_char = current_buffer.get_text (start, end, true);

                    if (left_char in opening_brackets) {
                        end.forward_char ();
                        current_buffer.select_range (start, end);
                    }
                }
            });
        });
    }

    public void deactivate () {
        window.key_press_event.disconnect (on_key_press);

        foreach (var buf in buffers) {
            buf.insert_text.disconnect (on_insert_text);
            buf.end_user_action.disconnect (on_action_finished);
        }
    }

    bool on_key_press (Gdk.EventKey event) {
        var doc = window.get_current_document ();
        if (doc != null && doc.source_view.has_focus && event.keyval in keys) {
            Gtk.TextIter start, end;

            current_buffer.get_selection_bounds (out start, out end);
            current_selection = current_buffer.get_text (start, end, true);
            should_complete = true;
        }

        return false;
    }

    void on_action_finished () {
        if (should_complete) {
            int len = current_selection.length;
            Gtk.TextIter start, end;

            current_buffer.get_selection_bounds (out start, out end);
            end.forward_chars (len);
            current_buffer.select_range (start, end);

            should_complete = false;
        }
    }

    void on_insert_text (ref Gtk.TextIter pos, string new_text, int new_text_length) {
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
