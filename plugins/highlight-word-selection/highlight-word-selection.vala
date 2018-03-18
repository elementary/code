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
    // Properties
    Gee.TreeSet<Scratch.Widgets.SourceView> source_views;
    Gee.HashMap<Scratch.Widgets.SourceView, Gtk.SourceSearchContext> search_contexts;
    Scratch.Widgets.SourceView current_source;

    // Consts
    // Pneumonoultramicroscopicsilicovolcanoconiosis longest word in a major dictionary @ 45
    private const uint SELECTION_HIGHLIGHT_MAX_CHARS = 45;

    Scratch.Services.Interface plugins;
    public Object object { owned get; construct; }

    public void update_state () {

    }

    public void activate () {
        this.source_views = new Gee.TreeSet<Scratch.Widgets.SourceView> ();
        this.search_contexts = new Gee.HashMap<Scratch.Widgets.SourceView, Gtk.SourceSearchContext> ();

        plugins = (Scratch.Services.Interface) object;
        plugins.hook_document.connect ((doc) => {
            var src = doc.source_view;
            var source_buffer = (Gtk.SourceBuffer) src.buffer;
            src.deselected.disconnect (on_deselection);
            src.deselected.connect (on_deselection);
            src.selection_changed.disconnect (on_selection_changed);
            src.selection_changed.connect (on_selection_changed);
            this.source_views.add (src);
            this.search_contexts.set (src, new Gtk.SourceSearchContext (source_buffer,null));
            this.current_source = src;
        });
    }

    public void on_selection_changed (Gtk.TextIter start,Gtk.TextIter end) {
        if (this.current_source.buffer.get_has_selection ()) {
            // Expand highlight to current word on
            if (!start.starts_word ()) {
                start.backward_word_start ();
            }

            if (!end.ends_word ()) {
                end.forward_word_end ();
            }

            string selected_text = this.current_source.buffer.get_text (start,end,false);
            if (selected_text.length > SELECTION_HIGHLIGHT_MAX_CHARS) {
                return;
            }

            var context = search_contexts.get (this.current_source);
            context.settings.search_text = selected_text;
            context.set_highlight (true);
        }
    }

    public void on_deselection () {
        var context = search_contexts.get (this.current_source);
        context.settings.search_text = null;
        context.set_highlight (false);
    }

    public void deactivate () {
        foreach (var src in source_views) {
            src.deselected.disconnect (on_deselection);
            src.selection_changed.disconnect (on_selection_changed);
            var context = search_contexts.get (src);
            context.settings.search_text = null;
            context.set_highlight (false);
        }
    }
}

[ModuleInit]
public void peas_register_types (TypeModule module) {
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type (typeof (Peas.Activatable),
                                     typeof (Scratch.Plugins.HighlightSelectedWords));
}
