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
    Gee.HashMap<uint, string> keys;
    const string[] valid_next_chars = {"", " ", "\b", "\r", "\n", "\t"};

    Gtk.TextBuffer current_buffer;
    Gtk.SourceView current_view;

    Scratch.Services.Interface plugins;
    public Object object { owned get; construct; }

    public void update_state () {}

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

        plugins.hook_document.connect ((doc) => {
            current_buffer = doc.source_view.buffer;
            current_view = doc.source_view;

            current_view.backspace.connect (on_backspace);
            current_view.key_press_event.connect (on_key_press);
        });
    }

    public void deactivate () {
        current_view.backspace.disconnect (on_backspace);
        current_view.key_press_event.disconnect (on_key_press);
    }

    string get_next_char () {
        Gtk.TextIter start, end;

        current_buffer.get_selection_bounds (out start, out end);
        end.forward_char ();

        return current_buffer.get_text (start, end, true) ;
    }

    string get_previous_char () {
        Gtk.TextIter start, end;

        current_buffer.get_selection_bounds (out start, out end);
        start.backward_char ();

        return current_buffer.get_text (start, end, true);
    }

    void on_backspace () {
        if (!current_buffer.has_selection) {
            string left_char = get_previous_char ();
            string right_char = get_next_char ();

            if (left_char in brackets && right_char in brackets.values) {
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

        string current_selection = current_buffer.get_text (start, end, true);
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

    void skip_char () {
        Gtk.TextIter start, end;

        current_buffer.get_selection_bounds (out start, out end);
        end.forward_char ();
        current_buffer.place_cursor (end);
    }

    bool on_key_press (Gdk.EventKey event) {
        if (event.keyval in keys &&
            !(Gdk.ModifierType.MOD1_MASK in event.state) &&
            !(Gdk.ModifierType.CONTROL_MASK in event.state)) {

            string bracket = keys[event.keyval];
            string next_char = get_next_char ();

            if (bracket in brackets &&
                (current_buffer.has_selection ||
                next_char in valid_next_chars ||
                next_char in brackets.values)) {
                complete_brackets (bracket);
                return true;
            } else if (bracket in brackets.values && next_char == bracket) {
                skip_char ();
                return true;
            }
        }

        return false;
    }
}

[ModuleInit]
public void peas_register_types (GLib.TypeModule module) {
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type (typeof (Peas.Activatable),
                                     typeof (Scratch.Plugins.BracketsCompletion));
}
