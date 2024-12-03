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

public class Scratch.Plugins.PrefixNode : Object {
    private enum NodeType {
        ROOT,
        CHAR,
        WORD_END
    }

    private Gee.ArrayList<PrefixNode> children;
    private unichar? uc = null;
    private NodeType type = ROOT;
    public uint occurrences { get; set construct; default = 0; }
    public PrefixNode? parent { get; construct; default = null; }

    public bool is_word_end {
        get {
            return type == WORD_END;
        }
    }

    // public bool is_root {
    //     get {
    //         return type == ROOT;
    //     }
    // }

    public uint length {
        get {
            return char_s.length;
        }
    }

    public string char_s {
        owned get {
            if (uc != null) {
                return uc.to_string ();
            } else {
                return "";
            }
        }
    }

    public bool has_children {
        get {
            return type != WORD_END && children.size > 0;
        }
    }

    public PrefixNode.from_unichar (unichar c, PrefixNode? _parent) requires (c != '\0') {
        Object (
            parent: _parent,
            occurrences: 1
        );

        uc = c;
        type = CHAR;
    }

    public PrefixNode.root () {
        Object (
            parent: null,
            occurrences: 0
        );

        type = ROOT;
    }

    public PrefixNode.word_end (PrefixNode _parent) {
        Object (
            parent: _parent,
            occurrences: 1
        );

        uc = '\0';
        type = WORD_END;
    }

    construct {
        children = new Gee.ArrayList<PrefixNode> ();
    }

    private bool has_char (unichar c) {
        return uc == c;
    }

    private void increment () requires (type == WORD_END) {
        lock (occurrences) {
            occurrences++;
        }
    }

    public void decrement () requires (type == WORD_END) {
        if (occurrences == 0) {
            warning ("decrementing non-occurring node");
            return;
        }

        lock (occurrences) {
            occurrences--;
        }
    }
    
    public bool occurs () requires (type == WORD_END) {
        return occurrences > 0;
    }

    private void append_child (owned PrefixNode child) requires (type != WORD_END) {
        lock (children) {
            children.add (child);
        }
    }

    public void remove_child (PrefixNode child) requires (type != WORD_END) {
        lock (children) {
            children.remove (child);
            if (children.is_empty && type != ROOT) {
                parent.remove_child (this);
            }
        }
    }

//     private bool remove_or_decrement_word_end () requires (this.has_children) {
//         foreach (var child in children) {
//             if (child.type == WORD_END) {
// //                warning ("found word end - occurrences %u - decrementing", child.occurrences);
//                 child.decrement ();

//                 return true;
//             }
//         }

//         critical ("No word end node found when removing");

//         return false;
//     }

    private void append_or_increment_word_end () requires (type != WORD_END && type != ROOT) {
        foreach (var child in children) {
            if (child.type == WORD_END) {
               debug ("incrementing child occurrence");
                child.increment ();
                return;
            }
        }

        var new_child = new PrefixNode.word_end (this);
        append_child (new_child);
    }

    private PrefixNode? find_or_append_char_child (
        unichar c,
        bool append_if_not_found = false
    ) requires (type != WORD_END) {

        foreach (var child in children) {
            if (child.has_char (c)) {
                return child;
            }
        }

        if (append_if_not_found) {
            var new_child = new PrefixNode.from_unichar (c, this);
            append_child (new_child);
            return new_child;
        } else {
            return null;
        }
    }

    public void insert_word (string text) requires (type == ROOT) {
        int index = 0;
        insert_word_internal (text, ref index);
    }

    protected void insert_word_internal (string text, ref int index) {
        unichar? uc = null;
        if (text.get_next_char (ref index, out uc)) {
            var child = find_or_append_char_child (uc, true); // Appends if not found
            child.insert_word_internal (text, ref index);
        } else {
            append_or_increment_word_end ();
        }
    }

    public PrefixNode? find_last_node_for (string text) {
        int index = 0;
        var res = find_last_node_for_internal (text, ref index);
        return res;
    }

    protected PrefixNode? find_last_node_for_internal (string text, ref int index) requires (type != WORD_END) {
        unichar? uc = null;
        if (text.get_next_char (ref index, out uc)) {
            var child = find_or_append_char_child (uc, false);
            if (child == null ) {
                return null;
            } else {
                return child.find_last_node_for_internal (text, ref index);
            }
        } else {
            return this;
        }
    }

    // public bool remove_word (string text) {
    //     var node = find_last_node_for (text);
    //     var res = node.remove_or_decrement_word_end ();
    //     // warning ("remove %s result %s", text, res.to_string ());
    //     return res;
    // }

    public PrefixNode? has_char_child (unichar c) requires (type != WORD_END) {
        foreach (var child in children) {
            if (child.has_char (c)) {
                return child;
            }
        }

        return null;
    }

    // First could with node at the last char of the prefix
    public void get_all_completions (ref List<string> completions, ref StringBuilder sb) {
        if (type == WORD_END) {
            return;
        }

        var initial_sb_str = sb.str;
        foreach (var child in children) {
            if (child.type == WORD_END) {
                completions.prepend (sb.str);
            } else {
                sb.append (child.char_s);
                child.get_all_completions (ref completions, ref sb);
            }

            sb.assign (initial_sb_str);
        }
    }
}
