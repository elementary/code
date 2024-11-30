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
    private GLib.StringBuilder sb;
    public bool initial_parse_complete = false;

    construct {
        clear ();
        sb = new GLib.StringBuilder ("");
    }

    public void clear () {
        root = new PrefixNode.root ();
        initial_parse_complete = false;
    }

    public void insert (string word) {
        if (word.length == 0) {
            return;
        }

        root.insert_word (word);
    }

    public void remove (string word) requires (word.length > 0) {
        if (word.length == 0) {
            return;
        }

        root.remove_word (word);
    }

    public bool has_prefix (string prefix) {
        return root.find_last_node_for (prefix) != null ? true : false;
    }

    // private PrefixNode? find_prefix_at (string prefix, PrefixNode node, int i = 0) {
    //     unichar curr;

    //     if (!prefix.get_next_char (ref i, out curr)) {
    //         return node;
    //     }

    //     var child = node.has_char_child (curr);
    //     if (child != null) {
    //         return find_prefix_at (prefix, child, i);
    //     }

    //     return null;
    // }

    public List<string> get_all_completions (string prefix) {
warning ("prefix tree get_all_completions for %s", prefix);
        var list = new List<string> ();
        // var node = find_prefix_at (prefix, root, 0);
        var node = root.find_last_node_for (prefix);
        warning ("node found is %s null", node != null ? "NOT" : "");
        if (node != null && !node.is_word_end) {
            warning ("erase string builder");
            sb.erase ();
            node.get_all_completions (ref list, ref sb);
        } else {
            warning ("node is word end %s", node.is_word_end.to_string ());
        }

        warning ("returning list length %u", list.length ());
        return list;
    }
}
