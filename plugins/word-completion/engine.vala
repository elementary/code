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

public class Euclide.Completion.Parser : GLib.Object {
    public const int MINIMUM_WORD_LENGTH = 1;
    public const int MAXIMUM_WORD_LENGTH = 50;

    public const int MAX_TOKENS = 1000000;

    private Scratch.Plugins.PrefixTree prefix_tree;

    public const string DELIMITERS = " .,;:?{}[]()0123456789+=&|<>*\\/\r\n\t\'\"`";
    public static bool is_delimiter (unichar c) {
        return DELIMITERS.index_of_char (c) >= 0;
    }

    public Gee.HashMap<Gtk.TextView,Scratch.Plugins.PrefixTree> text_view_words;
    public bool parsing_cancelled = false;

    public Parser () {
         text_view_words = new Gee.HashMap<Gtk.TextView,Scratch.Plugins.PrefixTree> ();
         prefix_tree = new Scratch.Plugins.PrefixTree ();
    }

    public bool match (string to_find) {
        return prefix_tree.find_prefix (to_find);
    }

    public bool get_for_word (string to_find, out List<string> list) {
        list = prefix_tree.get_all_matches (to_find);
        return list.first () != null;
    }

    public void rebuild_word_list (Gtk.TextView view) {
        prefix_tree.clear ();
        parse_text_view (view);
    }

    public void parse_text_view (Gtk.TextView view) {
        /* If this view has already been parsed, restore the word list */
        lock (prefix_tree) {
            if (text_view_words.has_key (view)) {
                prefix_tree = text_view_words.@get (view);
            } else {
                /* Else create a new word list and parse the buffer text */
                prefix_tree = new Scratch.Plugins.PrefixTree ();
            }
        }

        if (view.buffer.text.length > 0) {
            parse_string (view.buffer.text);
            text_view_words.@set (view, prefix_tree);
        }
    }

    public void add_word (string word) {
        if (word.length < MINIMUM_WORD_LENGTH)
            return;

        lock (prefix_tree) {
            prefix_tree.insert (word);
        }
    }

    public void cancel_parsing () {
        parsing_cancelled = true;
    }

    private bool parse_string (string text) {
        parsing_cancelled = false;
        string [] word_array = text.split_set (DELIMITERS, MAX_TOKENS);
        foreach (var current_word in word_array ) {
            if (parsing_cancelled) {
                debug ("Cancelling parse");
                return false;
            }
            add_word (current_word);
        }
        return true;
    }

    public string get_word_immediately_before (Gtk.TextIter iter) {
        int end_pos;
        var text = get_sentence_at_iter (iter, out end_pos);
        var pos = end_pos;
        unichar uc;
        text.get_prev_char (ref pos, out uc);
        if (is_delimiter (uc)) {
            return "";
        }

        pos = (end_pos - MAXIMUM_WORD_LENGTH - 1).clamp (0, end_pos);
        if (pos >= end_pos) {
            critical ("pos after end_pos");
            return "";
        }

        var sliced_text = text.slice (pos, end_pos);
        var words = sliced_text.split_set (DELIMITERS);
        var previous_word = words[words.length - 1]; // Maybe ""
        return previous_word;
    }

    public string get_word_immediately_after (Gtk.TextIter iter) {
        int start_pos;
        var text = get_sentence_at_iter (iter, out start_pos);
        var pos = start_pos;
        unichar uc;
        text.get_next_char (ref pos, out uc);
        if (is_delimiter (uc)) {
            return "";
        }

        // Find end of search range
        pos = (start_pos + MAXIMUM_WORD_LENGTH + 1).clamp (start_pos, text.length);
        if (start_pos >= pos) {
            critical ("start pos after pos");
            return "";
        }

        // Find first word in range
        var words = text.slice (start_pos, pos).split_set (DELIMITERS, 2);
        var next_word = words[0]; // Maybe ""
        return next_word;
    }

    private string get_sentence_at_iter (Gtk.TextIter iter, out int iter_sentence_offset) {
        var start_iter = iter;
        var end_iter = iter;
        start_iter.backward_sentence_start ();
        end_iter.forward_sentence_end ();
        var text = start_iter.get_text (end_iter);
        iter_sentence_offset = iter.get_offset () - start_iter.get_offset ();
        return text;
    }
}
