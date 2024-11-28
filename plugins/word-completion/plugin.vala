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
namespace Scratch {
    // DELIMITERS used for word completion are not necessarily the same Pango word breaks
    // Therefore, we reimplement some iter functions to move between words here below
    public const string DELIMITERS = " .,;:?{}[]()+=&|<>*\\/\r\n\t\'\"`";
    public const int MAX_TOKENS = 1000000;
}

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
        current_view.buffer.delete_range.connect (on_delete_range);
        current_view.buffer.delete_range.connect_after (after_delete_range);
        current_view.buffer.notify["cursor-position"].connect (on_cursor_moved);

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
        // try {
            // new Thread<void*>.try ("word-completion-thread", () => {
                if (current_view != null) {
                    warning ("parsing text view");
                    parse_text_view ();
                    warning ("finished parsing");
                }

                // return null;
        //     });
        // } catch (Error e) {
        //     warning (e.message);
        // }

        timeout_id = 0;
        return Source.REMOVE;
    }

    private void on_cursor_moved () {
        var insert_offset = current_view.buffer.cursor_position;
        Gtk.TextIter cursor_iter;
        current_view.buffer.get_iter_at_offset (out cursor_iter, insert_offset);
        var temp_iter = cursor_iter;
        temp_iter.backward_char ();

        if (current_insertion_line > -1 && (current_insertion_line != cursor_iter.get_line ())) {
            Gtk.TextIter line_start_iter, line_end_iter;
            current_view.buffer.get_iter_at_line (out line_start_iter, current_insertion_line);
            line_end_iter = line_start_iter;
            line_end_iter.forward_to_line_end ();
            var line_text = line_start_iter.get_text (line_end_iter);

            warning ("NEW LINE TEXT %s", line_text);
            var split_s = line_text.split_set (DELIMITERS, MAX_TOKENS);
            foreach (string s in split_s) {
                if (s.length > 0) {
                    parser.add_word (s);
                }
            }

            warning ("original_text %s", original_text);
            var orig_split_s = retrieve_original_text ().split_set (DELIMITERS, MAX_TOKENS);
            foreach (string s in orig_split_s) {
                if (s.length > 0) {
                    parser.remove_word (s);
                }
            }
        }
    }
    // Runs before default handler so buffer text not yet modified. @pos must not be invalidated
    private void on_insert_text (Gtk.TextIter pos, string new_text, int new_text_length) {
        // We need to process spaces and other delimiters too
        // pos points to char immediately after where text will be inserted
        if (contains_only_delimiters (new_text)) {
            return;
        }

        if (current_insertion_line == -1) {
            record_original_line_at (pos);
        }
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
        warning ("record original text %s", original_text);
    }

    private string retrieve_original_text () {
        var return_s = original_text;
        original_text = "";
        current_insertion_line = -1;
        // warning ("retrieved %s", return_s);
        return return_s;
    }

    int start_del_line = -1;
    int end_del_line = -1;
    private void on_delete_range (Gtk.TextIter del_start_iter, Gtk.TextIter del_end_iter) {
        var del_text = del_start_iter.get_text (del_end_iter);

        if (contains_only_delimiters (del_text)) {
            return;
        }

        start_del_line = del_start_iter.get_line ();
        end_del_line = del_end_iter.get_line ();
        if (end_del_line == start_del_line && current_insertion_line == -1) {
            record_original_line_at (del_start_iter); //TODO Handle multiline delete ? rebuild
        }
    }

    private void after_delete_range  (Gtk.TextIter del_start_iter, Gtk.TextIter del_end_iter) {
        if (end_del_line > start_del_line) {
            current_insertion_line = -1;
            original_text = "";
           // warning ("parse view");
            // parse_text_view ();
        }

        start_del_line = -1;
        end_del_line = -1;

    }

    private void handle_continue_word (Gtk.TextIter pos, string new_text, int new_text_length) {
        // if (!contains_delimiter (new_text)) {
        //     return;
        // }

        // // At least one complete word has been formed
        // var split_s = new_text.split_set (DELIMITERS, MAX_TOKENS);
        // assert (split_s.length > 1);

        // var text_start_iter = Gtk.TextIter ();
        // text_start_iter = pos;
        // backward_word_start (ref text_start_iter);

        // var new_word = text_start_iter.get_text (pos) + split_s[0];
        // parser.add_word (new_word);
        // // Add any other definitely complete words in new text
        // for (int i = 1; i < split_s.length - 1; i++) {
        //     parser.add_word (split_s[i]);
        // }

        // var temp = pos;
        // temp.forward_char ();
        // if (ends_with_delimiter (new_text) || is_delimiter (temp)) {
        //     parser.add_word (split_s[split_s.length - 1]);
        // }

        // current_insertion_line = -1;
    }

    private void handle_insert_not_at_word_boundary (Gtk.TextIter pos, string new_text, int new_text_length) {
// warning ("insert alone or at start");
//         parser.add_word (new_text);
    }

    private void handle_insert_between_phrase (Gtk.TextIter pos, string new_text, int new_text_length) {
        // warning ("word-completion: Text inserted between word.\n");
        // var word_start_iter = pos;
        // word_start_iter.backward_word_start ();

        // var word_end_iter = pos;
        // word_end_iter.forward_word_end ();

        // var old_word_to_delete = word_start_iter.get_text (word_end_iter);
        // parser.delete_word (old_word_to_delete);

        // // Check if new text ends with whitespace
        // if (ends_with_whitespace (new_text)) {
        //     // The text from the insert postiion to the end of the word needs to be added as its own word
        //     var final_word_end_iter = pos;
        //     final_word_end_iter.forward_word_end ();

        //     var extra_word_to_add = pos.get_text (final_word_end_iter);
        //     parser.add_word (extra_word_to_add);
        // }

        // var full_phrases = word_start_iter.get_text (pos) + new_text;
        // parser.add_word (full_phrases);
    }

    private bool ends_with_delimiter (string str) {
        if (str.length == 0) {
            return false;
        }

        if (DELIMITERS.contains (str.slice (-1, str.length))) {
            return true;
        }

        return false;
    }

    private bool contains_delimiter (string str) {
        int i = 0;
        unichar curr;
        bool found_delimiter = false;
        bool has_next_character = false;
        do {
            has_next_character = str.get_next_char (ref i, out curr);
            if (has_next_character) {
                if (DELIMITERS.contains (curr.to_string ())) {
                    found_delimiter = true;
                }
            }
        } while (has_next_character && !found_delimiter);

        return found_delimiter;
    }

    private bool contains_only_delimiters (string str) {
        int i = 0;
        unichar curr;
        bool found_char = false;
        bool has_next_character = false;
        do {
            has_next_character = str.get_next_char (ref i, out curr);
            if (has_next_character) {
                if (!(DELIMITERS.contains (curr.to_string ()))) {
                    found_char = true;
                }
            }
        } while (has_next_character && !found_char);

        return !found_char;
    }

    private string provider_name_from_document (Scratch.Services.Document doc) {
        return _("%s - Word Completion").printf (doc.get_basename ());
    }

    // Returns pointing to first char of word
    private bool backward_word_start (ref Gtk.TextIter iter) {
        while (is_delimiter (iter) && !iter.is_start ()) {
            iter.backward_char ();
        }

        while (!is_delimiter (iter) && !iter.is_start ()) {
            iter.backward_char ();
        }

        iter.forward_char ();
        return !is_delimiter (iter);
    }

    // Returns pointing to first char of word
    private bool forward_word_start (ref Gtk.TextIter iter) {
        while (is_delimiter (iter) && !iter.is_end ()) {
            iter.forward_char ();
        }

        return !is_delimiter (iter);
    }

    // Returns pointing to char after word
    private bool forward_word_end (ref Gtk.TextIter iter) {
        while (is_delimiter (iter) && !iter.is_end ()) {
            iter.forward_char ();
        }

        while (!is_delimiter (iter)) {
            iter.forward_char ();
        }

        return is_delimiter (iter);
    }

    // Returns if pointing to pos immediately after possibly incomplete word
    private bool is_immediate_word_end (Gtk.TextIter iter) {
        var temp = iter;
        temp.backward_char ();

        return !is_delimiter (temp);
    }

    private bool is_delimiter (Gtk.TextIter iter) {
        return DELIMITERS.index_of_char (iter.get_char ()) > -1;
    }

    private void parse_text_view (Gtk.TextView view = current_view) {
        /* If this view has already been parsed, restore the word list */
        warning ("parse text view");
        parser.select_prefix_tree (view);
        parser.clear ();
        if (view.buffer.text.length > 0) {
            parse_buffer (view.buffer);
            // parser.set_view_words (view);
        }
    }

    private void parse_buffer (Gtk.TextBuffer buff) {
    warning ("parse buffer");
        Gtk.TextIter start_iter;
        buff.get_start_iter (out start_iter);
        string word;
        while (get_next_word (ref start_iter, out word)) {
            warning ("found word %s", word);
            parser.add_word (word);
        }
        
        warning ("finished parse buffer");
    }

    private bool get_next_word (ref Gtk.TextIter iter, out string word) {
        word = "";
        warning ("called with letter %s", iter.get_char ().to_string ());
        if (forward_word_start (ref iter)) {
            warning ("first letter of word is %s", iter.get_char ().to_string ());
            var end_iter = iter;
            forward_word_end (ref end_iter);
            word = iter.get_text (end_iter);
            iter.assign (end_iter); // skip past found word
            return true;
        }

        warning ("next word returned false");
        return false;
    }

    private void cleanup (Gtk.SourceView view) {
        current_view.buffer.insert_text.disconnect (on_insert_text);
        current_view.buffer.delete_range.disconnect (on_delete_range);
        current_view.buffer.delete_range.disconnect (after_delete_range);
        current_view.buffer.notify["cursor-position"].disconnect (on_cursor_moved);
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
