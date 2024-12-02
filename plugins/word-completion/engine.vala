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
    private class WordOccurrences {
        private int occurrences;

        public WordOccurrences () {
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
    public const uint MINIMUM_WORD_LENGTH = 3;
    public const uint MINIMUM_PREFIX_LENGTH = 1;
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

        return 1;
    }

    private Gee.TreeMap<string, WordOccurrences>? current_tree = null;
    public Gee.HashMap<Gtk.TextView, Gee.TreeMap> text_view_words;
    public bool parsing_cancelled = false;

    public Parser () {
         text_view_words = new Gee.HashMap<Gtk.TextView, Gee.TreeMap> ();

    }

    public bool select_current_tree (Gtk.TextView view) {
        bool pre_existing = true;

        if (!text_view_words.has_key (view)) {
            var new_treemap = new Gee.TreeMap<string, WordOccurrences> (compare_words, null);
            new_treemap.set_data<bool> (COMPLETED, false);
            new_treemap.set_data<Gee.LinkedList<string>> (WORDS_TO_REMOVE, new Gee.LinkedList<string> ());
            text_view_words.@set (view, new_treemap);
            pre_existing = false;
        }

        lock (current_tree) {
            current_tree = text_view_words.@get (view);
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
            set_initial_parsing_completed (parse_text_and_add (buffer_text));
        } else {
            // Assume any buffer text has been loaded when this is called
            set_initial_parsing_completed (true);
        }

        debug ("initial parsing %s", get_initial_parsing_completed () ? "completed" : "INCOMPLETE");
    }

    // Returns true if text was completely parsed
    public bool parse_text_and_add (string text) {
        int index = 0;
        string word = "";
        while (!parsing_cancelled && get_next_word (text, ref index, out word)) {
            add_word (word);
        }

        return !parsing_cancelled;
    }

    public bool parse_text_and_remove (string text) {
        if (text.length < MINIMUM_WORD_LENGTH) {
            return false;
        }

        // Ensure text starts and ends with delimiter - easier to parse;
        string to_parse = " " + text + " ";
        int start_pos = 0;
        string word = "";
        while (!parsing_cancelled && get_next_word (to_parse, ref start_pos, out word)) {
            remove_word (word);
        }

        return parsing_cancelled;
    }

    public void get_words_before_and_after_pos (
        string text,
        int offset,
        out string word_before,
        out string word_after
    ) {
        var pos = offset;
        word_before = "";
        word_after = "";

        // Words must be contiguous with start point
        if (backward_word_start (text, ref pos, true) && offset >= pos) {
            word_before = text.slice (pos, offset);
        }

        if (forward_word_end (text, ref pos, true) && pos >= offset) {
            word_after = text.slice (offset, pos);
        }
    }

    public string get_word_immediately_before (string text, int end_pos) {
        int start_pos = end_pos;
        if (backward_word_start (text, ref start_pos, true) && end_pos > start_pos) {
            return text.slice (start_pos, end_pos);
        }

        return "";
    }

    public string get_word_immediately_after (string text, int start_pos) {
        int end_pos = start_pos;
        if (forward_word_start (text, ref end_pos, true) && end_pos > start_pos) {
            return text.slice (start_pos, end_pos);
        }

        return "";
    }

    private bool get_next_word (string text, ref int pos, out string word) {
        word = "";
        // May be delimiters after start point
        if (forward_word_start (text, ref pos)) {
            var start = pos;
            forward_word_end (text, ref pos);
            word = text.slice (start, pos).strip ();
            return true;
        }

        return false;
    }

    // Pos could point to beginning, middle or end of text and point
    // at a delimiter or non-delimiter. Moves pointer forward to start of next
    // Returns pointing BEFORE first char of next word
    // Offset is in bytes NOT unichars!
    private bool forward_word_start (string text, ref int offset, bool immediate = false) {
        if (offset >= text.length - MINIMUM_WORD_LENGTH) {
            return false;
        }

        unichar? uc = null;
        bool found = false;
        int delimiters = -1;

        // Skip delimiters before word
        do {
            found = text.get_next_char (ref offset, out uc);
            delimiters++;
        } while (found && is_delimiter (uc));

        if (immediate && delimiters > 0) {
            return false;
        }

        if (!found) {
            // Unable to find next non-delimiter in text - must be end of text
            return false;
        }

        // Skip back
        text.get_prev_char (ref offset, out uc);
        return true;
    }

    // Pos could point to middle or end of text and point
    // at a delimiter or non-delimiter. Moves pointer forward to next word end
    // Returns pointing after last char of word
    // Offset is in bytes NOT unichars!
    private bool forward_word_end (string text, ref int offset, bool immediate = false) {
        if (offset >= text.length) {
            return false;
        }

        unichar? uc = null;
        bool found = false;
        int delimiters = -1;

        // Skip delimiters before word
        do {
            found = text.get_next_char (ref offset, out uc);
            delimiters++;
        } while (found && is_delimiter (uc));

        if (immediate && delimiters > 0) {
            warning ("found following delimiters - not immediate");
            return false;
        }

        if (!found) { // Reached end of text without finding target
            return false;
        }

        // Skip chars in word
        do {
            found = text.get_next_char (ref offset, out uc);
        } while (found && !is_delimiter (uc));

        if (!found) { // Reached end of text without finding target
            return true;
        }

        // Pointing after first delimiter after word end - back up if not text end
        text.get_prev_char (ref offset, out uc);
        return true;
    }

    // Returns pointing to first char of word
    // Offset is in bytes NOT unichars!
    private bool backward_word_start (string text, ref int offset, bool immediate = false) requires (offset > 0) {
        unichar? uc = null;
        bool found = false;
        int delimiters = -1;

        // Skip delimiters before start point
        do {
            found = text.get_prev_char (ref offset, out uc);
            delimiters++;
        } while (found && is_delimiter (uc));

        if (immediate && delimiters > 0) {
            return false;
        }

        if (!found) {
            // Unable to find next non-delimiter before
            return false;
        }

        // Skip chars before in word
        do {
            found = text.get_prev_char (ref offset, out uc);
        } while (found && !is_delimiter (uc));

        if (!found) {
            // Reached start of text without finding target - must be word start
            return true;
        }

        // Pointing before delimiter before word - skip forward to word start
        text.get_next_char (ref offset, out uc);
        return true;
    }

    public void clear () requires (current_tree != null) {
        lock (current_tree) {
            current_tree.clear (); // Sets completed false
            set_initial_parsing_completed (false);

        }

        parsing_cancelled = false;
    }

    Gee.SortedMap<string, WordOccurrences> sub_map;
    public bool match (string prefix) requires (current_tree != null) {
        // Keep sub map so do not need to reconstruct in get_completions_for_prefix.
        sub_map = current_tree.tail_map (prefix);
        bool found = false;
        sub_map.map_iterator ().foreach ((word, occurrences) => {
            if (word.has_prefix (prefix)) {
                if (occurrences.occurs ()) {
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
        var list = new List<string> ();
        var prefix_length = prefix.length;
        // Sub map should always have been constructed in `match ()` function before coming here
        assert (sub_map != null); 
        var count = 0;
        sub_map.map_iterator ().@foreach ((word, occurrences) => {
            // Submap (tail_map) sometimes contains unexpected word *before* prefix_length
            // Possibly a bug in Gee? It also contains words that do not start with prefix,
            // but required words will be contiguous.
            if (word.has_prefix (prefix)) {
                if (occurrences.occurs ()) {
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
                var word_occurrences = current_tree.@get (word_to_add);
                word_occurrences.increment ();
            } else {
                current_tree.@set (word_to_add, new WordOccurrences ());
            }
        }
    }

    private uint reaper_timeout_id = 0;
    private bool delay_reaping = false;
    private const uint REAPING_THROTTLE_MS = 500;
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

    private bool reaping_cancelled = false;
    private void cancel_reaping () {
        if (reaper_timeout_id > 0) {
            Source.remove (reaper_timeout_id);
        }

        reaping_cancelled = true;
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

                        var occurrences = current_tree.@get (word);
                        if (occurrences != null && !occurrences.occurs ()) {
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

    public void cancel_parsing () {
        parsing_cancelled = true;
    }
}
