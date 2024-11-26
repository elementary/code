/*
 * Copyright (c) 2011 Lucas Baudin <xapantu@gmail.com>
 *
 * This is a free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; either version 2 of the
 * License, or (at your option) any later version.
 *
 * This is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public
 * License along with this program; see the file COPYING.  If not,
 * write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301 USA.
 *
 */

public class Scratch.Plugins.Completion : Peas.ExtensionBase, Peas.Activatable {
    public Object object { owned get; construct; }

    private List<Gtk.SourceView> text_view_list = new List<Gtk.SourceView> ();
    public Euclide.Completion.Parser parser {get; private set;}
    public Gtk.SourceView? current_view {get; private set;}
    public Scratch.Services.Document current_document {get; private set;}

    private MainWindow main_window;
    private Scratch.Services.Interface plugins;
    private bool completion_in_progress = false;

    private const uint [] ACTIVATE_KEYS = {
        Gdk.Key.Return,
        Gdk.Key.KP_Enter,
        Gdk.Key.ISO_Enter,
        Gdk.Key.Tab,
        Gdk.Key.KP_Tab,
        Gdk.Key.ISO_Left_Tab,
    };

    private const uint REFRESH_SHORTCUT = Gdk.Key.bar; //"|" in combination with <Ctrl> will cause refresh

    private uint timeout_id = 0;

    public void activate () {
        plugins = (Scratch.Services.Interface) object;
        parser = new Euclide.Completion.Parser ();
        plugins.hook_window.connect ((w) => {
            this.main_window = w;
        });

        plugins.hook_document.connect (on_new_source_view);
    }

    public void deactivate () {
        text_view_list.@foreach (cleanup);
    }

    public void update_state () {

    }

    public void on_new_source_view (Scratch.Services.Document doc) {
        if (current_view != null) {
            if (current_view == doc.source_view)
                return;

            parser.cancel_parsing ();

            if (timeout_id > 0)
                GLib.Source.remove (timeout_id);

            cleanup (current_view);
        }

        current_document = doc;
        current_view = doc.source_view;
        current_view.buffer.insert_text.connect (on_insert_text);

        current_view.completion.show.connect (() => {
            completion_in_progress = true;
        });
        current_view.completion.hide.connect (() => {
            completion_in_progress = false;
        });


        if (text_view_list.find (current_view) == null)
            text_view_list.append (current_view);

        var comp_provider = new Scratch.Plugins.CompletionProvider (this);
        comp_provider.priority = 1;
        comp_provider.name = provider_name_from_document (doc);

        try {
            current_view.completion.add_provider (comp_provider);
            current_view.completion.show_headers = true;
            current_view.completion.show_icons = true;
            /* Wait a bit to allow text to load then run parser*/
            timeout_id = Timeout.add (1000, on_timeout_update);

        } catch (Error e) {
            warning (e.message);
        }
    }

    private bool on_timeout_update () {
        try {
            new Thread<void*>.try ("word-completion-thread", () => {
                if (current_view != null)
                    parser.parse_text_view (current_view as Gtk.TextView);

                return null;
            });
        } catch (Error e) {
            warning (e.message);
        }

        timeout_id = 0;
        return false;
    }

    private void on_insert_text (Gtk.TextIter pos, string new_text, int new_text_length) {

        if (new_text.strip () == "") {
            return;
        }

        bool starts_word = pos.starts_word ();
        bool ends_word = pos.ends_word ();
        bool between_word = pos.inside_word () && !starts_word && !ends_word;

        if (ends_word) {
            this.handle_insert_at_phrase_end (pos, new_text, new_text_length);
        } else if (between_word) {
            this.handle_insert_between_phrase (pos, new_text, new_text_length);
        } else {
            this.handle_insert_not_at_word_boundary (pos, new_text, new_text_length);
        }
    }

    private void handle_insert_between_phrase (Gtk.TextIter pos, string new_text, int new_text_length) {
        debug ("word-completion: Text inserted between word.\n");
        var word_start_iter = pos;
        word_start_iter.backward_word_start ();

        var word_end_iter = pos;
        word_end_iter.forward_word_end ();

        var old_word_to_delete = word_start_iter.get_text (word_end_iter);
        parser.delete_word (old_word_to_delete, current_view.buffer.text);
        
        // Check if new text ends with whitespace
        if (ends_with_whitespace (new_text)) {
            // The text from the insert postiion to the end of the word needs to be added as its own word
            var final_word_end_iter = pos;
            final_word_end_iter.forward_word_end ();
            
            var extra_word_to_add = pos.get_text (final_word_end_iter);
            parser.parse_string (extra_word_to_add);
        }

        var full_phrases = word_start_iter.get_text (pos) + new_text;
        parser.parse_string (full_phrases);
    }
    
    private bool ends_with_whitespace (string str) {
        if (str.length == 0) {
            return false;
        }
        

        if (str.get_char (str.length - 1).isspace ()) {
            return true;
        }

        return false;
    }

    private void handle_insert_at_phrase_end (Gtk.TextIter pos, string new_text, int new_text_length) {
        var text_start_iter = Gtk.TextIter ();
        text_start_iter = pos;
        text_start_iter.backward_word_start ();

        var text_end_iter = Gtk.TextIter ();
        text_end_iter.assign (pos);
        text_end_iter.forward_chars (new_text_length - 1);

        var full_phrases = text_start_iter.get_text (text_end_iter) + new_text;
        parser.parse_string (full_phrases);
    }

    private void handle_insert_not_at_word_boundary (Gtk.TextIter pos, string new_text, int new_text_length) {
        parser.parse_string (new_text);
    }

    private string provider_name_from_document (Scratch.Services.Document doc) {
        return _("%s - Word Completion").printf (doc.get_basename ());
    }

    private void cleanup (Gtk.SourceView view) {
        current_view.buffer.insert_text.disconnect (on_insert_text);

        current_view.completion.get_providers ().foreach ((p) => {
            try {
                /* Only remove provider added by this plug in */
                if (p.get_name () == provider_name_from_document (current_document)) {
                    debug ("removing provider %s", p.get_name ());
                    current_view.completion.remove_provider (p);
                }
            } catch (Error e) {
                warning (e.message);
            }
        });
    }
}

[ModuleInit]
public void peas_register_types (GLib.TypeModule module) {
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type (typeof (Peas.Activatable),
                                       typeof (Scratch.Plugins.Completion));
}
