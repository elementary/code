/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 20126 elementary, Inc. <https://elementary.io>
 */

// Subclass to provide additional functions required for project list, symbol list etc
public class Code.TreeListItem : Object {
    public string text { get; set; default = ""; } //This can include markup
    public string sub_text { get; set; default = ""; } //This can include markup?
    public string tooltip { get; set; default = ""; }
    public Icon? icon { get; set; default = null;}
    public Icon? secondary_icon { get; set; default = null;}
    public string secondary_icon_tooltip { get; set; default = ""; }
    public string badge = ""; // Use label styled with Granite.STYLE_CLASS_BADGE?

    public ListStore? child_model { get; set; default = null; }
    public TreeListItem? parent { get; set; default = null; }
    public bool is_expandable { get; set construct; }
    public bool is_expanded { get; set; } // gets bound to the ListItem (temporarily)
    public Binding expanded_binding { get; set; } // Need to save bind so we can unbind
    public bool is_activatable { get; set; default = true; }
    public bool is_selectable { get; set; default = true; }
    public bool is_editable { get; set; default = false; }
    public bool is_dummy { get; construct; }
    public uint n_children {
        get {
            return child_model == null ? 0 : child_model.get_n_items ();
        }
    }

    public signal void child_added (TreeListItem item); // To emulate source list

    public TreeListItem () {
        Object (
            is_dummy: false
        );
    }

    public TreeListItem.dummy () {
        Object (
            is_dummy: true
        );
    }

    public TreeListItem.expandable () {
        Object (
            is_dummy: false,
            is_expandable: true
        );
    }

    public ListModel create_child_model () {
         child_model = new ListStore (typeof (TreeListItem));
         return child_model;
    }

    public virtual void add_child (TreeListItem child) {
        if (child_model == null) {
            create_child_model ();
        }

        child_model.insert_sorted (child, (a, b) => {
            return strcmp (((TreeListItem) a).text, ((TreeListItem) b).text);
        });

        child_added (child);
    }

    public virtual void remove_child (TreeListItem child) requires (child_model != null) {
        uint pos;
        if (child_model.find (child, out pos)) {
            child_model.remove (pos);
        }
    }

    public void remove_all_children () {
        if (child_model != null) {
            child_model.remove_all ();
        }
    }

    public bool has_no_children () requires (child_model != null) {
        return child_model.n_items == 0;
    }

    public TreeListItem? get_nth_child (uint pos) {
        return (TreeListItem?) child_model.get_object (pos);
    }

    /**
     * Collapses the item and/or its children.
     *
     * @param inclusive Whether to also collapse this item (true), or only its children (false).
     * @param recursive Whether to recursively collapse all the children (true), or only
     * immediate children (false).
     */
    public void collapse_all (
        bool inclusive,
        bool recursive,
        uint level = 0
    ) requires (child_model != null){
        TreeListItem? child = null;
        uint pos = 0;
        do {
            child = (TreeListItem?) (child_model.get_object (pos++));
            if (child.is_expandable) {
                if (recursive) {
                    child.collapse_all (true, true, level++);
                } else {
                    child.is_expanded = false;
                }
            }
        } while (child != null);

        if (level == 0 && inclusive) {
            is_expanded = false;
        } else {
            level--;
        }
    }
}
