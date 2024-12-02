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
    private class WordOccurrence {
        private int occurrences;

        public WordOccurrence () {
            occurrences = 1;
        }

        public void increment () {
            occurrences++;
        }

        public void decrement () {
            if (occurrences > 0) {
                occurrences--;
            }
        }

        public bool occurs () {
            return occurrences > 0;
        }
    }
    // DELIMITERS used for word completion are not necessarily the same Pango word breaks
    // Therefore, we reimplement some iter functions to move between words here below
    public const string DELIMITERS = " .,;:?{}[]()+=&|<>*\\/\r\n\t`\"\'";
    public const int MINIMUM_WORD_LENGTH = 3;
    public const int MAXIMUM_WORD_LENGTH = 45;
    public const int MINIMUM_PREFIX_LENGTH = 1;
    public const int MAX_TOKENS = 100000;
    public const string COMPLETED = "Completed";
    public const string WORDS_TO_REMOVE = "WordsToRemove";
    public static bool is_delimiter (unichar? uc) {
        return uc == null || DELIMITERS.index_of_char (uc) > -1;
    }

    // Custom function required so that the tail_map iterator returns all words that have
    // the target word as a prefix
    public static int compare_words (string word_a, string word_b) {
        // Only compare the first n characters
        var scomp = Posix.strncmp (word_a, word_b, word_a.length);
        // If same prefix then order by word length
        if (scomp == 0 && word_b.length > word_a.length) {
            return -1;
        }

        return scomp;
    }

    private Gee.TreeMap<string, WordOccurrence>? current_tree = null;
    public Gee.HashMap<Gtk.TextView, Gee.TreeMap> text_view_words;
    public bool parsing_cancelled = false;

    public Parser () {
         text_view_words = new Gee.HashMap<Gtk.TextView, Gee.TreeMap> ();
    }

    public bool select_current_tree (Gtk.TextView view) {
        bool pre_existing = true;
        if (!text_view_words.has_key (view)) {
            var new_treemap = new Gee.TreeMap<string, WordOccurrence> (compare_words, null);
            new_treemap.set_data<bool> (COMPLETED, false);
            new_treemap.set_data<Gee.LinkedList<string>> (WORDS_TO_REMOVE, new Gee.LinkedList<string> ());
            text_view_words.@set (view, new_treemap);
            pre_existing = false;
        }

        lock (current_tree) {
            current_tree = text_view_words.@get (view);
            parsing_cancelled = false;
        }

        return pre_existing && get_initial_parsing_completed ();
    }

    public void set_initial_parsing_completed (bool completed) requires (current_tree != null) {
        lock (current_tree) {
            current_tree.set_data<bool> (COMPLETED, completed);
        }
    }

    public bool get_initial_parsing_completed () requires (current_tree != null) {
        return current_tree.get_data<bool> (COMPLETED);
    }

    public void initial_parse_buffer_text (string buffer_text) {
        parsing_cancelled = false;
        clear ();
        if (buffer_text.length > 0) {
        var parsed = parse_text_and_add (buffer_text);
            set_initial_parsing_completed (parsed);
        } else {
            // Assume any buffer text would have been loaded when this is called
            // so definitely no initial parse needed
            set_initial_parsing_completed (true);
        }

        debug ("initial parsing %s", get_initial_parsing_completed () ? "completed" : "INCOMPLETE");
    }

    // Returns true if text was completely parsed
    public bool parse_text_and_add (string text) {
        int index = 0;
        string[] words = text.split_set (DELIMITERS);
        uint n_words = words.length;
        while (!parsing_cancelled && index < n_words) {
            add_word (words[index++]); // only valid words will be added
        }

        return index == n_words;
    }

    public void parse_text_and_remove (string text) {
        if (text.length < MINIMUM_WORD_LENGTH) {
            return;
        }

        int index = 0;
        string[] words = text.split_set (DELIMITERS);
        uint n_words = words.length;
        while (index < n_words) {
            remove_word (words[index++]);
        }

        return;
    }

    public void get_words_before_and_after_pos (
        string text,
        int offset,
        out string word_before,
        out string word_after
    ) {
        word_before = get_word_immediately_before (text, offset);
        word_after = get_word_immediately_after (text, offset);
    }

    public string get_word_immediately_before (string text, int end_pos) {
        if (end_pos < 1) {
            return "";
        }

        int pos = end_pos;
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
        debug ("previous word %s", previous_word);
        return previous_word;
    }

    public string get_word_immediately_after (string text, int start_pos) {
        if (start_pos < 0 || start_pos > text.length - 1) {
            return "";
        }

        int pos = start_pos;
        unichar uc;
        text.get_next_char (ref pos, out uc);
        if (is_delimiter (uc)) {
            return "";
        }

        pos = (start_pos + MAXIMUM_WORD_LENGTH + 1).clamp (start_pos, text.length);
        if (start_pos >= pos) {
            critical ("start pos after pos");
            return "";
        }

        var words = text.slice (start_pos, pos).split_set (DELIMITERS, 2);
        var next_word = words[0]; // Maybe ""
        debug ("next word %s", next_word);
        return next_word;
    }

    public void clear () requires (current_tree != null) {
        cancel ();
        lock (current_tree) {
            current_tree.clear (); // Sets completed false
            set_initial_parsing_completed (false);

        }

        parsing_cancelled = false;
    }

    public void cancel () {
        if (reaper_timeout_id > 0) {
            Source.remove (reaper_timeout_id);
        }

        reaping_cancelled = true;
        parsing_cancelled = true;
    }

    Gee.SortedMap<string, WordOccurrence> sub_map;
    public bool match (string prefix) requires (current_tree != null) {
        // Keep sub map so do not need to reconstruct in get_completions_for_prefix.
        sub_map = current_tree.tail_map (prefix);
        bool found = false;
        sub_map.map_iterator ().foreach ((word, wo) => {
            if (word.has_prefix (prefix)) {
                if (wo.occurs ()) {
                    found = true;
                    return Source.REMOVE; // At least one match
                }
            }

            return Source.CONTINUE;
        });

        return found;
    }

    // Fills list with complete words having prefix
    public List<string> get_completions_for_prefix (string prefix) requires (current_tree != null) {
        var completions = new List<string> ();
        debug ("completions for %s", prefix);
        var prefix_length = prefix.length;
        // Sub map should always have been constructed in `match ()` function before coming here
        assert (sub_map != null);
        var count = 0;
        sub_map.map_iterator ().@foreach ((word, wo) => {
            // Submap (tail_map) sometimes contains unexpected word *before* prefix_length
            // Possibly a bug in Gee? It also contains words that do not start with prefix,
            // but required words will be contiguous.
            if (word.has_prefix (prefix)) {
                if (wo.occurs ()) {
                    var completion = word.slice (prefix_length, word.length);
                    completions.prepend (completion);
                }

                count++;
                return Source.CONTINUE;
            }

            return count == 0; // Ignore words before prefix
        });

        sub_map = null;
        return (owned)completions;
    }

    // Only call if known that @word is a single word
    public void add_word (string word_to_add) requires (current_tree != null) {
        if (is_valid_word (word_to_add)) {
            if (current_tree.has_key (word_to_add)) {
                var wo = current_tree.@get (word_to_add);
                wo.increment ();
            } else {
                current_tree.@set (word_to_add, new WordOccurrence ());
            }
        }
    }

    private uint reaper_timeout_id = 0;
    private bool delay_reaping = false;
    private const uint REAPING_THROTTLE_MS = 500;
    private bool reaping_cancelled = false;

    // only call if known that @word is a single word
    public void remove_word (string word_to_remove) requires (current_tree != null) {
        if (is_valid_word (word_to_remove)) {
            if (current_tree.has_key (word_to_remove)) {
                var word_occurrences = current_tree.@get (word_to_remove);
                word_occurrences.decrement ();
                if (!word_occurrences.occurs ()) {
                    var words_to_remove = get_words_to_remove ();
                        words_to_remove.add (word_to_remove);
                        schedule_reaping ();
                }
            }
        }
    }

    private unowned Gee.LinkedList<string> get_words_to_remove () {
        return current_tree.get_data<Gee.LinkedList<string>> (WORDS_TO_REMOVE);
    }

    private void schedule_reaping () {
        if (reaper_timeout_id > 0) {
            delay_reaping = true;
            return;
        } else {
            reaper_timeout_id = Timeout.add (REAPING_THROTTLE_MS, () => {
                if (delay_reaping) {
                    delay_reaping = false;
                    return Source.CONTINUE;
                } else {
                    reaper_timeout_id = 0;
                    var words_to_remove = get_words_to_remove ();
                    words_to_remove.foreach ((word) => {
                        if (reaping_cancelled) {
                            return false;
                        }

                        var wo = current_tree.@get (word);
                        if (wo != null && !wo.occurs ()) {
                            current_tree.unset (word);
                        }

                        return true;
                    });

                    // Cannot remove inside @foreach loop so do it now
                    words_to_remove.clear ();
                    return Source.REMOVE;
                }
            });
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
}
