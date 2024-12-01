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
    private Euclide.Completion.Parser parser {get; private set;}
    private Gtk.SourceView? current_view {get; private set;}
    private Scratch.Services.Document current_document {get; private set;}
    private MainWindow main_window;
    private Scratch.Services.Interface plugins;
    private bool completion_in_progress = false;


    // Gtk.TextMark start_del_mark = new Gtk.TextMark ("StartDelete", true);

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
        // warning ("new source_view %s", doc.title);
        if (current_view != null) {
            if (current_view == doc.source_view) {
                return;
            }

            parser.cancel_parsing ();
            cleanup ();
        }

        current_document = doc;
        current_view = doc.source_view;
        current_view.buffer.insert_text.connect (on_insert_text);
        current_view.buffer.delete_range.connect (on_delete_range);
        current_view.buffer.delete_range.connect_after (after_delete_range);
        // current_view.buffer.notify["cursor-position"].connect (on_cursor_moved);

        current_view.completion.show.connect (() => {
            completion_in_progress = true;
        });

        current_view.completion.hide.connect (() => {
            completion_in_progress = false;
        });

        if (text_view_list.find (current_view) == null) {
            text_view_list.append (current_view);
        }

        var comp_provider = new Scratch.Plugins.CompletionProvider (parser, current_view);
        comp_provider.priority = 1;
        comp_provider.name = provider_name_from_document (doc);

        try {
            current_view.completion.add_provider (comp_provider);
            current_view.completion.show_headers = true;
            current_view.completion.show_icons = true;
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
            timeout_id = Timeout.add (1000, () => {
                timeout_id = 0;
                try {
                    new Thread<void*>.try ("word-completion-thread", () => {
                        if (current_view != null) {
                            parser.initial_parse_buffer_text (current_view.buffer.text);
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
    // warning ("on insert text %s", new_text);
        if (!parser.get_initial_parsing_completed ()) {
            // warning ("ignore spurious insertions when doc loading");
            return;
        }
        // Determine whether insertion point ends and/or starts a word
        var text = current_view.buffer.text;
        var insert_pos = iter.get_offset ();
        string word_before, word_after;
        parser.get_words_before_and_after_pos (text, insert_pos, out word_before, out word_after);

        var text_to_add = (word_before + new_text + word_after).strip ();
        // warning ("add text to parse %s", text_to_parse);
        // Inserted text could contain delimiters so parse before adding

        var text_to_remove = (word_before + word_after).strip ();
        // Only update if words have changed
        if (text_to_add != text_to_remove) {
            // warning ("after insert remove %s", to_remove);
            // We know this does not contain delimiters
            // warning ("adding %s, removing %s", text_to_add, text_to_remove);
            // Text to add may contain delimiters so parse
            parser.parse_text_and_add (text_to_add);
            // We know text to remove does not contain delimiters
            parser.remove_word (text_to_remove);
        }
    }

    // Used by both insertions and deletion handlers


    private void on_delete_range (Gtk.TextIter del_start_iter, Gtk.TextIter del_end_iter) {
        var del_text = del_start_iter.get_text (del_end_iter);
        var text = current_view.buffer.text;
        var delete_start_pos = del_start_iter.get_offset ();
        var delete_end_pos = del_end_iter.get_offset ();

        // string before, after;
        // parser.get_words_before_and_after_pos (text, delete_start_pos, out before, out after);
        var word_before = parser.get_word_immediately_before (text, delete_start_pos);

        // // We do not want word in deleted text so get word after delete end separately
        // parser.get_words_before_and_after_pos (text, delete_end_pos, out before, out after);
        var word_after = parser.get_word_immediately_after (text, delete_end_pos);

        var to_remove = word_before + del_text + word_after;
        parser.parse_text_and_remove (to_remove);

        // A new word could have been created
        var to_add = word_before + word_after;
        parser.add_word (to_add);

        // // Mark for after_delete handler where deletion occurred
        // current_view.buffer.add_mark (start_del_mark, del_start_iter);
    }

    private void after_delete_range () {
        // Gtk.TextIter? iter = null;
        // if (start_del_mark.get_deleted ()) {
        //     critical ("No DeleteMark after deletion");
        //     return;
        // }

        // // The deleted text has already been parsed and removed from prefix tree
        // // Need to check whether a new word has been created by deletion
        // current_view.buffer.get_iter_at_mark (out iter, start_del_mark);
        // if (iter == null) {
        //     critical ("Unable to get iter from deletion mark");
        //     return;
        // }

        // var delete_pos = iter.get_offset ();
        // string word_before, word_after;
        // parser. get_words_before_and_after_pos (
        //     current_view.buffer.text,
        //     delete_pos,
        //     out word_before,
        //     out word_after
        // );

        // // A new word could have been created
        // var to_add = word_before + word_after;
        // parser.parse_text_and_add (to_add);
        // current_view.buffer.delete_mark (start_del_mark);
    }

    private int current_insertion_line = -1;
    private string original_text = "";
    private void record_original_line_at (Gtk.TextIter iter) requires (current_insertion_line < 0) {
        current_insertion_line = iter.get_line ();
        var start_iter = iter;
        var end_iter = iter;
        while (!start_iter.starts_line ()) {
            start_iter.backward_char ();
        }

        end_iter.forward_to_line_end ();
        original_text = start_iter.get_text (end_iter);
    }

    private string retrieve_original_text () {
        var return_s = original_text;
        original_text = "";
        current_insertion_line = -1;
        return return_s;
    }

    private string provider_name_from_document (Scratch.Services.Document doc) {
        return _("%s - Word Completion").printf (doc.get_basename ());
    }

    private void cleanup () {
        if (timeout_id > 0) {
            GLib.Source.remove (timeout_id);
        }

        current_view.buffer.insert_text.disconnect (on_insert_text);
        current_view.buffer.delete_range.disconnect (on_delete_range);
        current_view.buffer.delete_range.disconnect (after_delete_range);
        // Disconnect show completion??

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
