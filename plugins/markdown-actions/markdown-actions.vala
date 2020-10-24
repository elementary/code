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

public class Code.Plugins.MarkdownActions : Peas.ExtensionBase, Peas.Activatable {
    Scratch.Widgets.SourceView current_source;
    Scratch.Services.Interface plugins;

    public Object object { owned get; construct; }

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
        if (control && !shift && evt.keyval == Gdk.Key.b) {
            add_markdown_tag ("**");
            return true;
        } else if (control && shift && evt.keyval == Gdk.Key.I) {
            add_markdown_tag ("_");
            return true;
        } else if (control && evt.keyval == Gdk.Key.k) {
            insert_link ();
        }
        return false;
    }

    private void insert_link () {
        var current_buffer = current_source.buffer;
        if (current_buffer.has_selection) {
            insert_around_selection ("[", "]");
            current_buffer.insert_at_cursor ("()", 2);
            go_back_n_chars (1);
        } else {
            current_buffer.insert_at_cursor ("[]", 2);
            current_buffer.insert_at_cursor ("()", 2);
            go_back_n_chars (3);
        }
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
        if (current_buffer.has_selection) {
            insert_around_selection (tag, tag);
        } else {
            current_buffer.insert_at_cursor (tag, tag.length);
            current_buffer.insert_at_cursor (tag, tag.length);
        }
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
    objmodule.register_extension_type (typeof (Peas.Activatable),
                                     typeof (Code.Plugins.MarkdownActions));
}
