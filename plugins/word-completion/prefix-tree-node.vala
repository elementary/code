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

    private const unichar WORD_END_CHAR = '\0';
    private unichar? uc = null;
    private NodeType type = ROOT;
    public Gee.ArrayList<PrefixNode> children;
    public PrefixNode? parent { get; construct; default = null; }
    public unichar value { get; construct; }
    public uint occurrences { get; set construct; default = 0; }

    public PrefixNode.from_unichar (unichar c, PrefixNode? _parent) requires (c != WORD_END_CHAR) {
        Object (
            value: c,
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
}
