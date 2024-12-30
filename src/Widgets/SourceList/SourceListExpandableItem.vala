/*
 * Copyright 2019 elementary, Inc. (https://elementary.io)
 * Copyright 2012-2014 Victor Martinez <victoreduardm@gmail.com>
 * SPDX-License-Identifier: LGPL-3.0-or-later
 */

namespace Code.Widgets.SourceList {
/**
 * A {@link Code.Widgets.SourceList.VisibleFunc} should return true if the item should be
 * visible; false otherwise. If //item//'s {@link Code.Widgets.SourceList.Item.visible}
 * property is set to //false//, then it won't be displayed even if this method returns //true//.
 *
 * It is important to note that the method ''must not modify any property of //item//''.
 * Doing so would result in an infinite loop, freezing the application's user interface.
 * This happens because the source list invokes this method to "filter" an item after
 * any of its properties changes, so by modifying a property this method would be invoking
 * itself again.
 *
 * For most use cases, modifying the {@link Code.Widgets.SourceList.Item.visible} property is enough.
 *
 * The advantage of using this method is that its nature is non-destructive, and the
 * changes it makes can be easily reverted (see {@link Code.Widgets.SourceList.refilter}).
 *
 * @param item Item to be checked.
 * @return Whether //item// should be visible or not.
 * @since 0.2
 */
public delegate bool VisibleFunc (Item item);

/**
 * An item that can contain more items.
 *
 * It supports all the properties inherited from {@link Code.Widgets.SourceList.Item},
 * and behaves like a normal item, except when it is located at the root level; in that case,
 * the following properties are ignored by the widget:
 *
 * * {@link Code.Widgets.SourceList.Item.selectable}
 * * {@link Code.Widgets.SourceList.Item.editable}
 * * {@link Code.Widgets.SourceList.Item.icon}
 * * {@link Code.Widgets.SourceList.Item.activatable}
 * * {@link Code.Widgets.SourceList.Item.badge}
 *
 * Root-level expandable items (i.e. Main Categories) are ''not'' displayed when they contain
 * zero visible children.
 *
 * @since 0.2
 */

 /**
 * An interface for sorting items.
 *
 * @since 0.3
 */
public interface Sortable : ExpandableItem {
    /**
     * Emitted after a user has re-ordered an item via DnD.
     *
     * @param moved The item that was moved to a different position by the user.
     * @since 0.3
     */
    public signal void user_moved_item (SourceList.Item moved);

    /**
     * Whether this item will allow users to re-arrange its children via DnD.
     *
     * This feature can co-exist with a sort algorithm (implemented
     * by {@link Code.Widgets.SourceListSortable.compare}), but
     * the actual order of the items in the list will always
     * honor that method. The sort function has to be compatible with
     * the kind of DnD reordering the item wants to allow, since the user can
     * only reorder those items for which //compare// returns 0.
     *
     * @return Whether the item's children can be re-arranged by users.
     * @since 0.3
     */
    public abstract bool allow_dnd_sorting ();

    /**
     * Should return a negative integer, zero, or a positive integer if ''a''
     * sorts //before// ''b'', ''a'' sorts //with// ''b'', or ''a'' sorts
     * //after// ''b'' respectively. If two items compare as equal, their
     * order in the sorted source list is undefined.
     *
     * In order to ensure that the source list behaves as expected, this
     * method must define a partial order on the source list tree; i.e. it
     * must be reflexive, antisymmetric and transitive. Not complying with
     * those requirements could make the program fall into an infinite loop
     * and freeze the user interface.
     *
     * Should return //0// to allow any pair of items to be sortable via DnD.
     *
     * @param a First item.
     * @param b Second item.
     * @return A //negative// integer if //a// sorts before //b//,
     *         //zero// if //a// equals //b//, or a //positive//
     *         integer if //a// sorts after //b//.
     * @since 0.3
     */
    public abstract int compare (SourceList.Item a, SourceList.Item b);
}

public class ExpandableItem : Item {
    /**
     * Emitted when an item is added.
     *
     * @param item Item added.
     * @see Code.Widgets.SourceList.ExpandableItem.add
     * @since 0.2
     */
    public signal void child_added (Item item);

    /**
     * Emitted when an item is removed.
     *
     * @param item Item removed.
     * @see Code.Widgets.SourceList.ExpandableItem.remove
     * @since 0.2
     */
    public signal void child_removed (Item item);

    /**
     * Emitted when the item is expanded or collapsed.
     *
     * @since 0.2
     */
    public virtual signal void toggled () { }

    /**
     * Whether the item is collapsible or not.
     *
     * When set to //false//, the item is //always// expanded and the expander is
     * not shown. Please note that this will also affect the value returned by the
     * {@link Code.Widgets.SourceList.ExpandableItem.expanded} property.
     *
     * @see Code.Widgets.SourceList.ExpandableItem.expanded
     * @since 0.2
     */
    public bool collapsible { get; set; default = true; }

    /**
     * Whether the item is expanded or not.
     *
     * The source list widget will obey the value of this property when possible.
     *
     * This property has no effect when {@link Code.Widgets.SourceList.ExpandableItem.collapsible}
     * is set to //false//. Also keep in mind that, __when set to //true//__, this property
     * doesn't always represent the actual expansion state of an item. For example, it might
     * be the case that an expandable item is collapsed because it has zero visible children,
     * but its //expanded// property value is still //true//; in such case, once one of the
     * item's children becomes visible, the item will be expanded again. Same applies to items
     * hidden behind a collapsed parent item.
     *
     * If obtaining the ''actual'' expansion state of an item is important,
     * use {@link Code.Widgets.SourceList.is_item_expanded} instead.
     *
     * @see Code.Widgets.SourceList.ExpandableItem.collapsible
     * @see Code.Widgets.SourceList.is_item_expanded
     * @since 0.2
     */
    private bool _expanded = false;
    public bool expanded {
        get { return _expanded || !collapsible; } // if not collapsible, always return true
        set {
            if (value != _expanded) {
                _expanded = value;
                toggled ();
            }
        }
    }

    /**
     * Number of children contained by the item.
     *
     * @since 0.2
     */
    public uint n_children {
        get { return children_list.size; }
    }

    /**
     * The item's children.
     *
     * This returns a newly-created list containing the children.
     * It's safe to iterate it while removing items with
     * {@link Code.Widgets.SourceList.ExpandableItem.remove}
     *
     * @since 0.2
     */
    public Gee.Collection<Item> children {
        owned get {
            // Create a copy of the children so that it's safe to iterate it
            // (e.g. by using foreach) while removing items.
            var children_list_copy = new Gee.ArrayList<Item> ();
            children_list_copy.add_all (children_list);
            return children_list_copy;
        }
    }

    private Gee.Collection<Item> children_list = new Gee.ArrayList<Item> ();

    /**
     * Creates a new {@link Code.Widgets.SourceList.ExpandableItem}
     *
     * @param name Title of the item.
     * @return (transfer full) A new {@link Code.Widgets.SourceList.ExpandableItem}.
     * @since 0.2
     */
    public ExpandableItem (string name = "") {
        base (name);
    }

    construct {
        editable = false;
    }

    /**
     * Checks whether the item contains the specified child.
     *
     * This method only considers the item's immediate children.
     *
     * @param item Item to search.
     * @return Whether the item was found or not.
     * @since 0.2
     */
    public bool contains (Item item) {
        return item in children_list;
    }

    /**
     * Adds an item.
     *
     * {@link Code.Widgets.SourceList.ExpandableItem.child_added} is fired after the item is added.
     *
     * While adding a child item, //the item it's being added to will set itself as the parent//.
     * Please note that items are required to have their //parent// property set to //null// before
     * being added, so make sure the item is removed from its previous parent before attempting
     * to add it to another item. For instance:
     * {{{
     * if (item.parent != null)
     *     item.parent.remove (item); // this will set item's parent to null
     * new_parent.add (item);
     * }}}
     *
     * @param item The item to add. Its parent __must__ be //null//.
     * @see Code.Widgets.SourceList.ExpandableItem.child_added
     * @see Code.Widgets.SourceList.ExpandableItem.remove
     * @since 0.2
     */
    public void add (Item item) requires (item.parent == null) {
        item.parent = this;
        children_list.add (item);
        child_added (item);
    }

    /**
     * Removes an item.
     *
     * The {@link Code.Widgets.SourceList.ExpandableItem.child_removed} signal is fired
     * //after removing the item//. Finally (i.e. after all the handlers have been invoked),
     * the item's {@link Code.Widgets.SourceList.Item.parent} property is set to //null//.
     * This has the advantage of letting signal handlers know the parent from which //item//
     * is being removed.
     *
     * @param item The item to remove. This will fail if item has a different parent.
     * @see Code.Widgets.SourceList.ExpandableItem.child_removed
     * @see Code.Widgets.SourceList.ExpandableItem.clear
     * @since 0.2
     */
    public void remove (Item item) requires (item.parent == this) {
        children_list.remove (item);
        child_removed (item);
        item.parent = null;
    }

    /**
     * Removes all the items contained by the item. It works similarly to
     * {@link Code.Widgets.SourceList.ExpandableItem.remove}.
     *
     * @see Code.Widgets.SourceList.ExpandableItem.remove
     * @see Code.Widgets.SourceList.ExpandableItem.child_removed
     * @since 0.2
     */
    public void clear () {
        foreach (var item in children)
            remove (item);
    }

    /**
     * Expands the item and/or its children.
     *
     * @param inclusive Whether to also expand this item (true), or only its children (false).
     * @param recursive Whether to recursively expand all the children (true), or only
     * immediate children (false).
     * @see Code.Widgets.SourceList.ExpandableItem.expanded
     * @since 0.2
     */
    public void expand_all (bool inclusive = true, bool recursive = true) {
        set_expansion (this, inclusive, recursive, true);
    }

    /**
     * Collapses the item and/or its children.
     *
     * @param inclusive Whether to also collapse this item (true), or only its children (false).
     * @param recursive Whether to recursively collapse all the children (true), or only
     * immediate children (false).
     * @see Code.Widgets.SourceList.ExpandableItem.expanded
     * @since 0.2
     */
    public void collapse_all (bool inclusive = true, bool recursive = true) {
        set_expansion (this, inclusive, recursive, false);
    }

    private static void set_expansion (ExpandableItem item, bool inclusive, bool recursive, bool expanded) {
        if (inclusive)
            item.expanded = expanded;

        foreach (var child_item in item.children) {
            var child_expandable_item = child_item as ExpandableItem;
            if (child_expandable_item != null) {
                if (recursive)
                    set_expansion (child_expandable_item, true, true, expanded);
                else
                    child_expandable_item.expanded = expanded;
            }
        }
    }

    /**
     * Recursively expands the item along with its parent(s).
     *
     * @see Code.Widgets.SourceList.ExpandableItem.expanded
     * @since 0.2
     */
    public void expand_with_parents () {
        // Update parent items first due to GtkTreeView's working internals:
        // Expanding children before their parents would not always work, because
        // they could be obscured behind a collapsed row by the time the treeview
        // tries to expand them, obviously failing.
        if (parent != null)
            parent.expand_with_parents ();
        expanded = true;
    }

    /**
     * Recursively collapses the item along with its parent(s).
     *
     * @see Code.Widgets.SourceList.ExpandableItem.expanded
     * @since 0.2
     */
    public void collapse_with_parents () {
        if (parent != null)
            parent.collapse_with_parents ();
        expanded = false;
    }
}
}
