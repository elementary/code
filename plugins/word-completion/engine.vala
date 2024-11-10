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
    public const int MAX_TOKENS = 1000000;

    private Scratch.Plugins.PrefixTree prefix_tree;

    public const string DELIMITERS = " .,;:?{}[]()0123456789+=&|<>*\\/\r\n\t\'\"`";
    public static bool is_delimiter (unichar c) {
        return DELIMITERS.index_of_char (c) >= 0;
    }

    public static void back_to_word_start (ref Gtk.TextIter iter) {
        iter.backward_find_char (is_delimiter, null);
        iter.forward_char ();
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

    public bool parse_string (string text) {
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

    public void delete_word (string word, string text) requires (word.length > 0) {
        bool match_found = false;
        uint word_end_index = word.length - 1;

        // Figure out if another instance of a word in another position before trying to delete it
        // from the prefix tree
        while (word_end_index > -1 && !match_found) {
            match_found = prefix_in_text (word[0:word_end_index], text);
            word_end_index--;
        }

        // All possible prefixes of the word exist in the source view
        if (match_found && word_end_index == word.length - 1) {
            return;
        }

        uint deletion_depth_level = word.length - word_end_index;
        // TODO: Now delete word (prefix) from prefix tree with deletion_
        // depth level
    }

    private bool prefix_in_text (string word, string text) {
        // If there are at least two matches then the prefix
        // still exists after the modifications made to the source view

        try {
            var search_regex = new Regex ("\\b$word\\b");
            GLib.MatchInfo match_info;
            search_regex.match_all (text, 0, out match_info);
            return match_info.get_match_count () > 1;
        } catch (GLib.Error err) {
            critical ("Error while attempting regex search of prefix in document text: %s", err.message);
        }

        return false;
    }
}
