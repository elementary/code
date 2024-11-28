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
    private Gtk.TextView current_view;
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

    public void select_prefix_tree (Gtk.TextView view) {
       // lock (prefix_tree) {
            if (!text_view_words.has_key (view)) {
            warning ("creating new prefix tree for view");
                text_view_words.@set (view, new Scratch.Plugins.PrefixTree ());
            }
       // }
        prefix_tree = text_view_words.@get (view);
        current_view = view;
    }

    public void clear () requires (prefix_tree != null) {
        prefix_tree.clear ();
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

        if (!is_valid_word (word)) {
            return;
        }

        if (word.length < MINIMUM_WORD_LENGTH) {
            return;
        }

        lock (prefix_tree) {
warning ("add word %s", word);
            prefix_tree.insert (word);
        }
    }

    private bool is_valid_word (string word) {
        // Exclude words beginning with digit
        if (word.get_char (0).isdigit ()) {
            return false;
        }

        return true;
    }

    public void cancel_parsing () {
        parsing_cancelled = true;
    }

    public void remove_word (string word) requires (word.length > 0) {
        lock (prefix_tree) {
            warning ("remove %s", word);
            prefix_tree.remove (word);
        }
    }
}
