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

public class Scratch.Plugins.HighlightSelectedWords : Scratch.Plugins.PluginBase {
    Scratch.Widgets.SourceView current_source;
    Scratch.MainWindow? main_window = null;
    Gtk.SourceSearchContext? current_search_context = null;

    // Consts
    // Pneumonoultramicroscopicsilicovolcanoconiosis longest word in a major dictionary @ 45
    private const uint SELECTION_HIGHLIGHT_MAX_CHARS = 45;

    Scratch.Plugins.Interface plugins;
    // public Object object { owned get; construct; }

    // public void update_state () {}
    public HighlightSelectedWords (PluginInfo info, Interface iface) {
        base (info, iface);
    }
    
    public override void activate () {
        // plugins = (Scratch.Plugins.Interface) object;
        plugins.hook_document.connect ((doc) => {
            if (current_source != null) {
                current_source.deselected.disconnect (on_deselection);
                current_source.selection_changed.disconnect (on_selection_changed);
            }

            current_source = doc.source_view;
            current_source.deselected.connect (on_deselection);
            current_source.selection_changed.connect (on_selection_changed);
        });

        plugins.hook_window.connect ((w) => {
            main_window = w;
        });
    }


    public override void deactivate () {
        if (current_source != null) {
            current_source.deselected.disconnect (on_deselection);
            current_source.selection_changed.disconnect (on_selection_changed);
        }
    }

    public void on_selection_changed (ref Gtk.TextIter start, ref Gtk.TextIter end) {
        var window_search_context = main_window != null ? main_window.search_bar.search_context : null;

        if (window_search_context == null ||
            window_search_context.settings.search_text == "" ||
            window_search_context.get_occurrences_count () == 0) {
            // Perform plugin selection when there is no ongoing and successful search 
            current_search_context = new Gtk.SourceSearchContext (
                (Gtk.SourceBuffer)current_source.buffer,
                null
            );
            current_search_context.settings.search_text = "";
            current_search_context.set_highlight (false);

            var original_start = start.copy ();

            // Ignore leading space
            start.forward_find_char (
                (uc) => {
                    return !uc.isspace ();
                },
                end
            );

            // Extend backwards to start of word
            start.backward_find_char (
                (uc) => {
                    var break_type = uc.break_type ();
                    if (break_type == UnicodeBreakType.ALPHABETIC ||
                        break_type == UnicodeBreakType.WORD_JOINER) {

                        return false;
                    } else {
                        return true;
                    }
                },
                null
            );

            // Do not include leading punctuation unless originally selected by user
            if (start.compare (original_start) < 0) {
                start.forward_char ();
            }

            // Ignore trailing spaces
            end.backward_find_char (
                (uc) => {
                    return !uc.isspace ();
                },
                start
            );

            // Extend forward to end of word
            end.forward_find_char (
                (uc) => {
                    var break_type = uc.break_type ();
                    if (break_type == UnicodeBreakType.ALPHABETIC ||
                        break_type == UnicodeBreakType.WORD_JOINER) {

                        return false;
                    } else {
                        return true;
                    }
                },
                null
            );

            // Ensure no leading or trailing space
            var selected_text = start.get_text (end).strip ();

            if (selected_text.char_count () > SELECTION_HIGHLIGHT_MAX_CHARS) {
                return;
            }

            current_search_context.settings.search_text = selected_text;
            current_search_context.set_highlight (true);
        } else if (current_search_context != null) {
            // Cancel existing search
            current_search_context.set_highlight (false);
            current_search_context = null;
        }
    }

    public void on_deselection () {
        if (current_search_context != null) {
            current_search_context.set_highlight (false);
            current_search_context = null;
        }
    }
}

public Scratch.Plugins.PluginBase module_init (
    Scratch.Plugins.PluginInfo info,
    Scratch.Plugins.Interface iface
) {
    return new Scratch.Plugins.HighlightSelectedWords (info, iface);
}

// [ModuleInit]
// public void peas_register_types (TypeModule module) {
//     var objmodule = module as Peas.ObjectModule;
//     objmodule.register_extension_type (typeof (Peas.Activatable),
//                                      typeof (Scratch.Plugins.HighlightSelectedWords));
// }
