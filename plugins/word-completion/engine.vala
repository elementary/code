/*
 * Copyright 2024 elementary, Inc. <https://elementary.io>
 *           2011 Lucas Baudin <xapantu@gmail.com>
 *  *
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
    public const uint MINIMUM_WORD_LENGTH = 4;
    public const uint MINIMUM_PREFIX_LENGTH = 1;
    private Scratch.Plugins.PrefixTree? current_tree = null;
    public Gee.HashMap<Gtk.TextView, Scratch.Plugins.PrefixTree> text_view_words;
    public bool parsing_cancelled = false;

    public Parser () {
         text_view_words = new Gee.HashMap<Gtk.TextView, Scratch.Plugins.PrefixTree> ();
    }

    public void initial_parse_buffer_text (string buffer_text) {
        parsing_cancelled = false;

        clear ();
        if (buffer_text.length > 0) {
            set_initial_parsing_completed (parse_text_and_add (buffer_text));
        } else {
            set_initial_parsing_completed (false);
        }

        debug ("initial parsing %s", get_initial_parsing_completed () ? "completed" : "INCOMPLETE");
    }

    // Returns true if text was completely parsed
    public bool parse_text_and_add (string text) {
        int start_pos = 0;
        string word = "";
        while (!parsing_cancelled && get_next_word (text, ref start_pos, out word)) {
            add_word (word);
        }

        return !parsing_cancelled;
    }

    // Returns whether text was completely parsed
    public bool parse_text_and_remove (string text) {
        int start_pos = 0;
        string word = "";
        while (!parsing_cancelled && get_next_word (text, ref start_pos, out word)) {
            remove_word (word);
        }

        return parsing_cancelled;
    }

    private bool get_next_word (string text, ref int pos, out string word) {
        word = "";
        if (forward_word_start (text, ref pos)) {
            var end_pos = pos;
            forward_word_end (text, ref end_pos);
            word = text.slice (pos, end_pos).strip ();
            pos = end_pos;
            return true;
        }

        return false;
    }

    // Returns pointing to first char of word
    public bool forward_word_start (string text, ref int pos) {
        unichar? uc;
        while (text.get_next_char (ref pos, out uc) && is_delimiter (uc)) {}
        pos--;
        return uc != null && !is_delimiter (uc);
    }
    // Returns pointing to first char of word
    public bool backward_word_start (string text, ref int pos) {
        unichar? uc;
        while (text.get_prev_char (ref pos, out uc) && !is_delimiter (uc)) {}
        return uc != null && is_delimiter (uc);
    }

    // Returns pointing to char after last char of word
    public bool forward_word_end (string text, ref int pos) {
        unichar? uc;
        while (text.get_next_char (ref pos, out uc) && is_delimiter (uc)) {
        }

        while (text.get_next_char (ref pos, out uc) && !is_delimiter (uc)) {
        }

        return uc == null || is_delimiter (uc);
    }

    private bool is_delimiter (unichar uc) {
        return Scratch.Plugins.Completion.is_delimiter (uc);
    }

    public bool match (string to_find) requires (current_tree != null) {
        return current_tree.has_prefix (to_find);
    }

    public bool select_current_tree (Gtk.TextView view) {
        bool pre_existing = true;

        if (!text_view_words.has_key (view)) {
            text_view_words.@set (view, new Scratch.Plugins.PrefixTree ());
            pre_existing = false;
        }

        lock (current_tree) {
            current_tree = text_view_words.@get (view);
        }

        return pre_existing && get_initial_parsing_completed ();
    }

    public void clear () requires (current_tree != null) {
        lock (current_tree) {
            current_tree.clear (); // Sets completed false
        }

        parsing_cancelled = false;
    }

    public void set_initial_parsing_completed (bool completed) requires (current_tree != null) {
        lock (current_tree) {
            debug ("setting current tree completed %s", completed.to_string ());
            current_tree.initial_parse_complete = completed;
        }
    }

    public bool get_initial_parsing_completed () requires (current_tree != null) {
        return current_tree.initial_parse_complete;
    }

    // Fills list with complete words having prefix
    public bool get_completions_for_prefix (string prefix, out List<string> completions) requires (current_tree != null) {
        completions = current_tree.get_all_completions (prefix);
        return completions.first () != null;
    }

    private void add_word (string word) requires (current_tree != null) {
        if (is_valid_word (word)) {
            lock (current_tree) {
                // warning ("add word %s", word);
                current_tree.insert (word);
            }
        }
    }

    private void remove_word (string word) requires (current_tree != null) {
        if (is_valid_word (word)) {
            lock (current_tree) {
                current_tree.remove (word);
            }
        }
    }

    private bool is_valid_word (string word) {
        if (word.strip ().length < MINIMUM_WORD_LENGTH) {
            return false;
        }

        // Exclude words beginning with digit
        if (word.get_char (0).isdigit ()) {
            return false;
        }

        return true;
    }

    public void cancel_parsing () {
        parsing_cancelled = true;
    }
}
