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
    private const unichar WORD_END_CHAR = '\0';
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

    protected bool is_word_end {
        get {
            return type == WORD_END;
        }
    }

    protected string char_s {
        owned get {
            if (uc != null) {
                return uc.to_string ();
            } else {
                return "";
            }
        }
    }

    protected bool has_children {
        get {
            return type != WORD_END && children.size > 0;
        }
    }

    public PrefixNode.from_unichar (unichar c, PrefixNode? _parent) requires (c != WORD_END_CHAR) {
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

        uc = WORD_END_CHAR;
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

    // Returns true if word still occurs
    public bool decrement () requires (type == WORD_END) {
        if (occurrences == 0) {
            warning ("decrementing non-occurring node");
            return false;
        }

        lock (occurrences) {
            occurrences--;
        }

        return occurrences > 0;
    }

    public bool occurs () requires (type == WORD_END) {
        return occurrences > 0;
    }

    // Only called to add a complete word to the tree
    public void insert_word (string text) requires (type == ROOT) {
        debug ("rootnode: insert word %s", text);
        int index = 0;
        insert_word_internal (text, ref index);
    }

    public void remove_child (PrefixNode child) requires (type != WORD_END) {
        lock (children) {
            children.remove (child);
            debug ("removed child '%s'", child.char_s);
            if (children.is_empty && type != ROOT) {
                debug ("remove this from parent");
                parent.remove_child (this);
            }
        }
    }

    // We return any end_node for @text even if occurences == 0
    // because we may be re-adding it before it is reaped
    public PrefixNode? find_end_node_for (string text) {
        debug ("find_end_node_for %s", text);
        var last_node = find_last_node_for (text);
        if (last_node != null) {
            var end_node = last_node.find_or_append_char_child (WORD_END_CHAR, false);
            return end_node;
        }

        return null;
    }

    // Returns node corresponding to last char in @text (or null if not in tree)
    public PrefixNode? find_last_node_for (string text) {
        int index = 0;
        return find_last_node_for_internal (text, ref index);
    }

    //PROTECTED METHODS

    protected void insert_word_internal (string text, ref int index) {
        unichar? uc = null;
        if (text.get_next_char (ref index, out uc)) {
            var child = find_or_append_char_child (uc, true); // Appends if not found
            child.insert_word_internal (text, ref index);
        } else {
            append_or_increment_word_end ();
        }
    }

    protected PrefixNode? find_last_node_for_internal (string text, ref int index) requires (type != WORD_END) {
        unichar? uc = null;
        if (text.get_next_char (ref index, out uc)) {
            debug ("find char_child '%s'", uc.to_string ());
            var child = find_or_append_char_child (uc, false);
            if (child == null ) {
                debug ("child not found");
                return null;
            } else {
                return child.find_last_node_for_internal (text, ref index);
            }
        } else {
            debug ("end of text - current node type %s", this.type.to_string ());
            return this;
        }
    }
    //PRIVATE METHODS

    private void append_or_increment_word_end () requires (type != WORD_END && type != ROOT) {
        foreach (var child in children) {
            if (child.type == WORD_END) {
               debug ("incrementing end node occurrence");
                child.increment ();
                return;
            }
        }

        var new_child = new PrefixNode.word_end (this);
        debug ("append new word end");
        append_child (new_child);
    }

    private PrefixNode? find_or_append_char_child (unichar c, bool append_if_not_found = false)
    requires (type != WORD_END) {

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

    // Children are only appended if they do not already exist
    private void append_child (owned PrefixNode child) requires (type != WORD_END) {
        lock (children) {
            children.add (child);
        }
    }

    public void get_all_completions (ref List<string> completions, ref StringBuilder sb) {
        if (type == WORD_END) {
            return;
        }

        var initial_sb_str = sb.str;
        foreach (var child in children) {
            if (child.type == WORD_END && child.occurs ()) {
                completions.prepend (sb.str);
            } else {
                sb.append (child.char_s);
                child.get_all_completions (ref completions, ref sb);
            }

            sb.assign (initial_sb_str);
        }
    }
}
