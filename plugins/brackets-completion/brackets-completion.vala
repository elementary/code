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
    Gee.TreeSet<Gtk.TextBuffer> buffers;
    Gtk.TextBuffer current_buffer;
    MainWindow window;

    Gee.HashMap<uint, int> keys;
    const string[] opening_brackets = {"{", "[", "(", "'", "\"", "`"};
    const string[] closing_brackets = {"}", "]", ")", "'", "\"", "`"};

    Scratch.Services.Interface plugins;
    public Object object { owned get; construct; }

    public void update_state () {

    }

    public void activate () {
        buffers = new Gee.TreeSet<Gtk.TextBuffer> ();

        keys = new Gee.HashMap<uint, int> ();
        keys[Gdk.Key.braceleft] = 0;
        keys[Gdk.Key.bracketleft] = 1;
        keys[Gdk.Key.parenleft] = 2;
        keys[Gdk.Key.quoteright] = 3;
        keys[Gdk.Key.quotedbl] = 4;
        keys[Gdk.Key.grave] = 5;
        
        plugins = (Scratch.Services.Interface) object;

        plugins.hook_window.connect ((w) => {
            window = w;
            window.key_press_event.connect (on_key_press);
        });

        plugins.hook_document.connect ((doc) => {
            current_buffer = doc.source_view.buffer;
            buffers.add (current_buffer);
        });
    }

    public void deactivate () {
        window.key_press_event.disconnect (on_key_press);
    }
      
    bool on_key_press (Gdk.EventKey event) {
        var doc = window.get_current_document ();
        if (doc != null && doc.source_view.has_focus && event.keyval in keys) {
            Gtk.TextIter start, end;

            current_buffer.get_selection_bounds (out start, out end);
            var current_text = current_buffer.get_text (start, end, true);

            var index = keys[event.keyval];
            var open_bracket = opening_brackets[index];
            var close_bracket = closing_brackets[index];
            var text = open_bracket + current_text + close_bracket;

            current_buffer.delete_selection (false, false);
            current_buffer.insert_at_cursor (text, text.length);
            current_buffer.get_selection_bounds (out start, out end);
            start.backward_chars (text.length - 1);
            end.backward_char ();

            current_buffer.select_range (end, start);

            return true;
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
