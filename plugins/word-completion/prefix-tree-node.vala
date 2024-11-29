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

    public bool is_root {
        get {
            return type == ROOT;
        }
    }

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

    public bool has_char (unichar c) {
        return uc == c;
    }

    private void increment () requires (type == WORD_END) {
        occurrences++;
    }

    private void decrement () requires (type == WORD_END && occurrences > 0) {
        occurrences--;
        if (occurrences == 0) {
            parent.remove_child (this);
        }
    }

    private void append_child (owned PrefixNode child) requires (type != WORD_END) {
        children.add (child);
    }

    private void remove_child (PrefixNode child) requires (type != WORD_END) {
        children.remove (child);
    }

    public void remove_word_end () requires (this.has_children) {
        foreach (var child in children) {
            if (child.is_word_end) {
                child.decrement ();
                return;
            }
        }
    }

    public void insert_word_end () requires (!this.is_word_end && !this.is_root) {
        foreach (var child in children) {
            if (child.type == WORD_END) {
                child.increment ();
                return;
            }
        }

        var new_child = new PrefixNode.word_end (this);
        append_child (new_child);
    }

    public PrefixNode append_char_child (unichar c) requires (!this.is_word_end) {
        foreach (var child in children) {
            if (child.has_char (c)) {
                return child;
            }
        }

        var new_child = new PrefixNode.from_unichar (c, this);
        append_child (new_child);
        return new_child;
    }

    public PrefixNode? has_char_child (unichar c) requires (!this.is_word_end) {
        foreach (var child in children) {
            if (child.has_char (c)) {
                return child;
            }
        }

        return null;
    }

    // First could with node at the last char of the prefix
    public void get_all_completions (ref List<string> completions, ref StringBuilder sb) {
        var initial_sb_str = sb.str;
        warning ("get all completions for %s", initial_sb_str);
        foreach (var child in children) {
            if (child.is_word_end) {
                if (sb.str.length > 0) {
                    warning ("word end - appending completion %s", sb.str);
                    completions.prepend (sb.str);
                }
            } else {
                sb.append (child.char_s);
                child.get_all_completions (ref completions, ref sb);
            }

            sb.assign (initial_sb_str);
        }
    }
}
