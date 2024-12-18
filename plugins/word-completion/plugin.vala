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

    public const int MAX_TOKENS = 1000000;
    public const uint INTERACTIVE_DELAY = 500;
    public const int INITIAL_PARSE_DELAY_MSEC = 1000;

    private const uint [] ACTIVATE_KEYS = {
        Gdk.Key.Return,
        Gdk.Key.KP_Enter,
        Gdk.Key.ISO_Enter,
        Gdk.Key.Tab,
        Gdk.Key.KP_Tab,
        Gdk.Key.ISO_Left_Tab,
    };

    private const uint REFRESH_SHORTCUT = Gdk.Key.bar; //"|" in combination with <Ctrl> will cause refresh


    public Object object { owned get; construct; }

    private List<Gtk.SourceView> text_view_list = new List<Gtk.SourceView> ();
    private Euclide.Completion.Parser parser;
    private Gtk.SourceView? current_view;
    private Gtk.SourceCompletion? current_completion;
    private Scratch.Plugins.CompletionProvider current_provider;
    private Scratch.Services.Document current_document {get; private set;}
    private MainWindow main_window;
    private Scratch.Services.Interface plugins;
    private bool completion_in_progress = false;

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
        debug ("new source_view %s", doc != null ? doc.title : "null");
        if (current_view != null) {
            if (current_view == doc.source_view) {
                return;
            }

            parser.cancel_parsing ();
            cleanup ();
        }

        current_document = doc;
        current_view = doc.source_view;
        current_completion = current_view.completion;

        if (text_view_list.find (current_view) == null) {
            text_view_list.append (current_view);
        }

        current_provider = new Scratch.Plugins.CompletionProvider (parser, doc);

        try {
            current_completion.add_provider (current_provider);
            current_completion.show_headers = true;
            current_completion.show_icons = true;
            current_completion.accelerators = 9;
            current_completion.select_on_show = true;
        } catch (Error e) {
            critical (
                "Could not add completion provider to %s. %s\n",
                current_document.title,
                e.message
            );
            cleanup ();
            return;
        }

        /* Wait a bit to allow text to load then run parser*/
        if (!parser.select_current_tree (current_view)) { // Returns false if prefix tree new or parsing not completed
            // Start initial parsing  after timeout to ensure text loaded
            timeout_id = Timeout.add (INITIAL_PARSE_DELAY_MSEC, () => {
                timeout_id = 0;
                try {
                    new Thread<void*>.try ("word-completion-thread", () => {
                        if (current_view != null) {
                            parser.initial_parse_buffer_text (current_view.buffer.text);
                            //
                            current_view.buffer.insert_text.connect (on_insert_text);
                            current_view.buffer.delete_range.connect (on_delete_range);

                            current_completion.show.connect (() => {
                                completion_in_progress = true;
                            });

                            current_completion.hide.connect (() => {
                                completion_in_progress = false;
                            });
                        }

                        return null;
                    });
                } catch (Error e) {
                    warning (e.message);
                }

                return Source.REMOVE;
            });
        }
    }

    // Runs before default handler so buffer text not yet modified. @pos must not be invalidated
    private void on_insert_text (Gtk.TextIter iter, string new_text, int new_text_length) {
        if (!parser.get_initial_parsing_completed ()) {
            // Ignore spurious insertions when doc loading
            return;
        }
        // Determine whether insertion point ends and/or starts a word
        var text = current_view.buffer.text;
        var insert_pos = iter.get_offset ();
        var word_before = parser.get_word_immediately_before (text, insert_pos);
        var word_after = parser.get_word_immediately_after (text, insert_pos);
        var text_to_add = (word_before + new_text + word_after).strip ();
        var text_to_remove = (word_before + word_after).strip ();

        // Only update if words have changed
        if (text_to_add != text_to_remove) {
            debug ("adding %s, removing %s", text_to_add, text_to_remove);
            // Text to add may contain delimiters so parse
            parser.parse_text_and_add (text_to_add);
            debug ("after insert remove %s", text_to_remove);
            // We know text to remove does not contain delimiters
            parser.remove_word (text_to_remove);
        }
    }

    private void on_delete_range (Gtk.TextIter del_start_iter, Gtk.TextIter del_end_iter) {
        var del_text = del_start_iter.get_text (del_end_iter);
        var text = current_view.buffer.text;
        var delete_start_pos = del_start_iter.get_offset ();
        var delete_end_pos = del_end_iter.get_offset ();
        var word_before = parser.get_word_immediately_before (text, delete_start_pos);
        var word_after = parser.get_word_immediately_after (text, delete_end_pos);

        var to_remove = word_before + del_text + word_after;
        debug ("delete range: remove %s", to_remove);
        parser.parse_text_and_remove (to_remove);

        // A new word could have been created
        var to_add = word_before + word_after;
        debug ("delete range: new word created %s", to_add);
        parser.add_word (to_add);
        if (del_text.length == 1) {
            // Wait until after buffer has been amended then trigger completion
            Timeout.add (current_provider.interactive_delay, () => {
                warning ("showing completion");
                current_view.show_completion ();
                return Source.REMOVE;
            });
        }

    }

    private void cleanup () {
        if (timeout_id > 0) {
            GLib.Source.remove (timeout_id);
        }

        current_view.buffer.insert_text.disconnect (on_insert_text);
        current_view.buffer.delete_range.disconnect (on_delete_range);
        // Disconnect show completion??

        current_completion.get_providers ().foreach ((p) => {
            try {
                /* Only remove provider added by this plug in */
                current_completion.remove_provider (current_provider);
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
