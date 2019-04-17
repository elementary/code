// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/***
  BEGIN LICENSE

  Copyright (C) 2013 Madelynn May <madelynnmay@madelynnmay.com>
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

public class Scratch.Plugins.HighlightSelectedWords : Peas.ExtensionBase,  Peas.Activatable {
    Scratch.Widgets.SourceView current_source;
    Gtk.SourceSearchContext current_search_context;

    // Consts
    // Pneumonoultramicroscopicsilicovolcanoconiosis longest word in a major dictionary @ 45
    private const uint SELECTION_HIGHLIGHT_MAX_CHARS = 45;

    Scratch.Services.Interface plugins;
    public Object object { owned get; construct; }

    public void update_state () {}

    public void activate () {
        plugins = (Scratch.Services.Interface) object;
        plugins.hook_document.connect ((doc) => {
            if (current_source != null) {
                current_source.deselected.disconnect (on_deselection);
                current_source.selection_changed.disconnect (on_selection_changed);
            }

            current_source = doc.source_view;
            current_source.deselected.connect (on_deselection);
            current_source.selection_changed.connect (on_selection_changed);
        });
    }

    public void on_selection_changed (ref Gtk.TextIter start, ref Gtk.TextIter end) {
        if (!start.equal (end)) {
            // Expand highlight to current word
            if (!start.starts_word ()) {
                start.backward_word_start ();
            }

            if (!end.ends_word ()) {
                end.forward_word_end ();
            }

            string selected_text = start.get_buffer ().get_text (start, end, false);
            if (selected_text.char_count () > SELECTION_HIGHLIGHT_MAX_CHARS) {
                return;
            }

            current_search_context = new Gtk.SourceSearchContext ((Gtk.SourceBuffer)current_source.buffer, null);
            current_search_context.settings.search_text = selected_text;
            current_search_context.set_highlight (true);
        }
    }

    public void on_deselection () {
        if (current_search_context != null) {
            current_search_context.settings.search_text = null;
        }
    }

    public void deactivate () {
        if (current_source != null) {
            current_source.deselected.disconnect (on_deselection);
            current_source.selection_changed.disconnect (on_selection_changed);
        }
    }
}

[ModuleInit]
public void peas_register_types (TypeModule module) {
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type (typeof (Peas.Activatable),
                                     typeof (Scratch.Plugins.HighlightSelectedWords));
}
