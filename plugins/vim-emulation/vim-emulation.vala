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

public class Scratch.Plugins.VimEmulation : Peas.ExtensionBase, Scratch.Services.ActivatablePlugin {
    public enum Mode {
        COMMAND,
        INSERT,
        VISUAL
    }

    Mode mode = Mode.COMMAND;
    string number = "";
    string action = "";
    bool g = false;

    Gee.TreeSet<Scratch.Widgets.SourceView> views;
    Scratch.Widgets.SourceView? view = null;

    Scratch.Services.Interface plugins;
    public Object object { owned get; set construct; }

    construct {
        views = new Gee.TreeSet<Scratch.Widgets.SourceView> ();
    }

    public void update_state () {

    }

    public void activate () {
        plugins = (Scratch.Services.Interface) object;
        plugins.hook_document.connect ((doc) => {
            this.view = doc.source_view;
            this.view.key_press_event.disconnect (handle_key_press);
            this.view.key_press_event.connect (handle_key_press);
            this.views.add (view);
        });
    }

    public void deactivate () {
        foreach (var v in views) {
            v.key_press_event.disconnect (handle_key_press);
        }
    }

    private bool handle_key_press (Gdk.EventKey event) {
        //some extensions to the default navigating
        bool ctrl = (event.state & Gdk.ModifierType.CONTROL_MASK) != 0;
        bool shift = (event.state & Gdk.ModifierType.SHIFT_MASK) != 0;

        if (ctrl && event.keyval == Gdk.Key.Up) {
            move_paragraph (true, shift);
            return true;
        }

        if (ctrl && event.keyval == Gdk.Key.Down) {
            move_paragraph (false, shift);
            return true;
        }

        int old_len = number.length;
        // Firstly let's set the mode
        switch (event.keyval) {
            //mode changing
            case Gdk.Key.i:
                if (mode == Mode.INSERT) {
                    return false;
                } else {
                    // clean action string
                    action = "";
                }

                mode = Mode.INSERT;
                debug ("Vim Emulation: INSERT Mode!");
                return true;
            case Gdk.Key.Escape:
                mode = Mode.COMMAND;
                debug ("Vim Emulation: COMMAND Mode!");
                break;
        }

        if (mode == Mode.INSERT) {
            action += event.str;
            return false;
        }

        // Parse commands
        switch (event.keyval) {
            //numbers
            case Gdk.Key.@1:
                number += "1";
                break;
            case Gdk.Key.@2:
                number += "2";
                break;
            case Gdk.Key.@3:
                number += "3";
                break;
            case Gdk.Key.@4:
                number += "4";
                break;
            case Gdk.Key.@5:
                number += "5";
                break;
            case Gdk.Key.@6:
                number += "6";
                break;
            case Gdk.Key.@7:
                number += "7";
                break;
            case Gdk.Key.@8:
                number += "8";
                break;
            case Gdk.Key.@9:
                number += "9";
                break;
            //case 0, see below

            //navigation
            case Gdk.Key.Left:
            case Gdk.Key.h:
                view.move_cursor (Gtk.MovementStep.VISUAL_POSITIONS, -1, false);
                break;
            case Gdk.Key.Down:
            case Gdk.Key.j:
            case Gdk.Key.plus:
                view.move_cursor (Gtk.MovementStep.DISPLAY_LINES, 1, false);
                break;
            case Gdk.Key.Up:
            case Gdk.Key.k:
            case Gdk.Key.minus:
                view.move_cursor (Gtk.MovementStep.DISPLAY_LINES, -1, false);
                break;
            case Gdk.Key.Right:
            case Gdk.Key.l:
                view.move_cursor (Gtk.MovementStep.VISUAL_POSITIONS, 1, false);
                break;
            case Gdk.Key.End:
            case Gdk.Key.dollar:
                view.move_cursor (Gtk.MovementStep.PARAGRAPH_ENDS, 1, false);
                break;
            case Gdk.Key.u:
                view.undo ();
                break;
            case Gdk.Key.H:
                view.move_cursor (Gtk.MovementStep.BUFFER_ENDS, -1, false);
                break;
            case Gdk.Key.L:
                view.move_cursor (Gtk.MovementStep.BUFFER_ENDS, 1, false);
                break;
            case Gdk.Key.w:
                view.move_cursor (Gtk.MovementStep.WORDS, 1, false);
                break;
            case Gdk.Key.b:
                view.move_cursor (Gtk.MovementStep.WORDS, -1, false);
                break;
            case Gdk.Key.I:
                if (mode == Mode.INSERT) {
                    return false;
                }

                mode = Mode.INSERT;
                var buffer = view.buffer;
                Gtk.TextIter start, end;
                buffer.get_selection_bounds (out start, out end);
                buffer.get_iter_at_mark (out start, buffer.get_insert ());
                start.backward_sentence_start ();
                buffer.place_cursor (start);
                debug ("Vim Emulation: INSERT Mode!");
                break;
            case Gdk.Key.a:
                if (mode == Mode.INSERT) {
                    return false;
                }
                // clean action string
                action = "";

                mode = Mode.INSERT;
                view.move_cursor (Gtk.MovementStep.VISUAL_POSITIONS, number == "" ? 1 : int.parse (number), false);
                debug ("Vim Emulation: INSERT Mode!");
                return true;
            case Gdk.Key.A:
                if (mode == Mode.INSERT) {
                    return false;
                }

                mode = Mode.INSERT;
                view.move_cursor (Gtk.MovementStep.PARAGRAPH_ENDS, 1, false);
                debug ("Vim Emulation: INSERT Mode!");
                break;
            case Gdk.Key.o:
                if (mode == Mode.INSERT) {
                    return false;
                }
                mode = Mode.INSERT;
                debug ("Vim Emulation: INSERT Mode!");

                view.move_cursor (Gtk.MovementStep.PARAGRAPH_ENDS, 1, false);
                view.insert_at_cursor ("\n");
                break;
            case Gdk.Key.O:
                if (mode == Mode.INSERT) {
                    return false;
                }
                mode = Mode.INSERT;
                debug ("Vim Emulation: INSERT Mode!");

                // Move to start of current line
                view.move_cursor (Gtk.MovementStep.PARAGRAPH_ENDS, -1, false);
                view.move_cursor (Gtk.MovementStep.DISPLAY_LINE_ENDS, -1, false);
                // Insert newline before current line
                view.insert_at_cursor ("\n");
                // Move to beginning of the new line
                view.move_cursor (Gtk.MovementStep.PARAGRAPHS, -1, false);
                break;
            case 46: // Dot "."
                debug (action);
                view.insert_at_cursor (action);
                break;
            case Gdk.Key.Home:
            case Gdk.Key.@0:
                if (number == "") {
                    view.move_cursor (Gtk.MovementStep.PARAGRAPH_ENDS, -1, false);
                    view.move_cursor (Gtk.MovementStep.DISPLAY_LINE_ENDS, -1, false);
                } else {
                    number += "0";
                }

                break;
            case Gdk.Key.e:
                view.move_cursor (Gtk.MovementStep.WORDS, number == "" ? 1 : int.parse (number), false);
                break;
            case Gdk.Key.g:
                g = true;
                view.go_to_line (int.parse (number));
                break;
        }

        //if there weren't any numbers added, we probably used it, so we reset it
        if (old_len == number.length) {
            number = "";
        }

        return true;
    }

    private void move_paragraph (bool up, bool select) {
        var buffer = view.buffer;

        Gtk.TextIter iter, start, end;
        buffer.get_iter_at_offset (out iter, buffer.cursor_position);

        var search = "\n\n";
        bool success = false;
        if (up) {
            success = iter.backward_search (search, 0, out start, out end, null);
        } else {
            success = iter.forward_search (search, 0, out start, out end, null);
        }

        if (!success) {
            if (up) {
                buffer.get_start_iter (out start);
            } else {
                buffer.get_end_iter (out start);
            }
        } else {
            start.forward_char ();
        }

        if (select) {
            buffer.select_range (start, iter);
        } else {
            buffer.place_cursor (start);
        }

        view.scroll_to_iter (start, 0, false, 0, 0);
    }
}

[ModuleInit]
public void peas_register_types (GLib.TypeModule module) {
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type (typeof (Scratch.Services.ActivatablePlugin),
                                     typeof (Scratch.Plugins.VimEmulation));
}
