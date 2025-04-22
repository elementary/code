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
    public enum NodeType {
        ROOT,
        CHAR,
        WORD_END
    }

    private const unichar WORD_END_CHAR = '\0';
    private uint occurrences; // Only used for WORD_END nodes

    public unichar uc { get; construct; }
    public NodeType node_type { get; construct; }
    public PrefixNode? parent { get; construct; }
    public unichar value { get; construct; }

    public Gee.ArrayList<PrefixNode> children;

    public PrefixNode.from_unichar (unichar c, PrefixNode? _parent) requires (c != WORD_END_CHAR) {
        Object (
            value: c,
            parent: _parent,
            uc: c,
            node_type: NodeType.CHAR
        );
    }

    public PrefixNode.root () {
        Object (
            parent: null,
            uc: WORD_END_CHAR,
            node_type: NodeType.ROOT
        );
    }

    public PrefixNode.word_end (PrefixNode _parent) {
        Object (
            parent: _parent,
            uc: WORD_END_CHAR,
            node_type: NodeType.WORD_END
        );

        occurrences = 1;
    }

    construct {
        children = new Gee.ArrayList<PrefixNode> ();
    }
}
