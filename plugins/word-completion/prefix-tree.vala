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

 public class Scratch.Plugins.PrefixTree : Object {
    private PrefixNode? root = null;
    public bool initial_parse_complete = false;

    construct {
        clear ();
    }

    public void clear () {
        root = new PrefixNode.root ();
        initial_parse_complete = false;
    }

    public void insert (string word) {
        if (word.length == 0) {
            return;
        }

        this.insert_at (word, this.root);
    }

    private void insert_at (string word, PrefixNode node, int i = 0) requires (!node.is_word_end) {
        unichar curr = '\0';
        if (!word.get_next_char (ref i, out curr) || curr == '\0') {
            node.insert_word_end ();
            return;
        }

        var child = node.append_char_child (curr);
        insert_at (word, child, i);
    }

    public void remove (string word) requires (word.length > 0) {
        if (word.length == 0) {
            return;
        }

        var word_node = find_prefix_at (word, root);

        if (word_node != null) {
            word_node.remove_word_end (); // Will autoremove unused parents
        }
    }

    public bool find_prefix (string prefix) {
        return find_prefix_at (prefix, root) != null ? true : false;
    }

    private PrefixNode? find_prefix_at (string prefix, PrefixNode node, int i = 0) {
        unichar curr;

        if (!prefix.get_next_char (ref i, out curr)) {
            return node;
        }

        var child = node.has_char_child (curr);
        if (child != null) {
            return find_prefix_at (prefix, child, i);
        }

        return null;
    }

    public List<string> get_all_completions (string prefix) {
        var list = new List<string> ();
        var node = find_prefix_at (prefix, root, 0);
        warning ("found node for %s - letter is %s", prefix, node.char_s);
        if (node != null && !node.is_word_end) {
            warning ("looking for completions for %s", prefix);
            var sb = new StringBuilder ("");
            node.get_all_completions (ref list, ref sb);
            warning ("got %u completions",list.length ());
        }

        return list;
    }
}
