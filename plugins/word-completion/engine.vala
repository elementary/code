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
    public const uint MINIMUM_WORD_LENGTH = 3;
    private Scratch.Plugins.PrefixTree prefix_tree;
    public Gee.HashMap<Gtk.TextView, Scratch.Plugins.PrefixTree> text_view_words;
    public bool parsing_cancelled = false;

    public Parser () {
         text_view_words = new Gee.HashMap<Gtk.TextView, Scratch.Plugins.PrefixTree> ();
         // prefix_tree = new Scratch.Plugins.PrefixTree ();
    }

    ~Parser () {
        critical ("DESTRUCT parser");
    }
    public bool match (string to_find) {
        return prefix_tree.find_prefix (to_find);
    }

    public bool select_prefix_tree (Gtk.TextView view) {
        bool pre_existing = true;

        if (!text_view_words.has_key (view)) {
            text_view_words.@set (view, new Scratch.Plugins.PrefixTree ());
            pre_existing = false;
        }

        lock (prefix_tree) {
            prefix_tree = text_view_words.@get (view);
        }

        return pre_existing;
    }

    public void clear () requires (prefix_tree != null) {
        lock (prefix_tree) {
            prefix_tree.clear ();
            prefix_tree.initial_parse_complete = false;
        }

        parsing_cancelled = false;
    }

    public void set_initial_parsing_complete () {
        lock (prefix_tree) {
            prefix_tree.initial_parse_complete = true;
        }
    }

    public bool get_initial_parsing_complete () {
        return prefix_tree.initial_parse_complete;
    }

    // public void set_view_words (Gtk.TextView view) requires (prefix_tree != null) {
    //     text_view_words.@set (view, prefix_tree);
    // }

    // Fills list with complete words having prefix
    public bool get_for_word (string to_find, out List<string> list) {
        list = prefix_tree.get_all_matches (to_find);
        // list.remove_link (list.find_custom (to_find, strcmp));
        return list.first () != null;
    }

    public void add_word (string word) {
        if (is_valid_word (word)) {
            lock (prefix_tree) {
                prefix_tree.insert (word);
            }
        }
    }

    public void remove_word (string word) requires (word.length > 0) {
        if (is_valid_word (word)) {
            lock (prefix_tree) {
                warning ("remove %s", word);
                prefix_tree.remove (word);
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
