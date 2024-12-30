/*
 * Copyright 2019 elementary, Inc. (https://elementary.io)
 * Copyright 2012-2014 Victor Martinez <victoreduardm@gmail.com>
 * SPDX-License-Identifier: LGPL-3.0-or-later
 */

namespace Code.Widgets.SourceList {
/**
 * The model backing the SourceList tree.
 *
 * It monitors item property changes, and handles children additions and removals. It also controls
 * the visibility of the items based on their "visible" property, and on their number of children,
 * if they happen to be categories. Its main purpose is to provide an easy and practical interface
 * for sorting, adding, removing and updating items, eliminating the need of repeatedly dealing with
 * the Gtk.TreeModel API directly.
 */

 //TODO Convert to FilterListModel
 public class DataModel : Gtk.TreeModelFilter, Gtk.TreeDragSource, Gtk.TreeDragDest {

    /**
     * An object that references a particular row in a model. This class is a wrapper built around
     * Gtk.TreeRowReference, and exists with the purpose of ensuring we never use invalid tree paths
     * or iters in the model, since most of these errors provoke failures due to GTK+ assertions
     * or, even worse, unexpected behavior.
     */
    private class NodeWrapper {

        /**
         * The actual reference to the node. If is is null, it is treated as invalid.
         */
        private Gtk.TreeRowReference? row_reference;

        /**
         * A newly-created Gtk.TreeIter pointing to the node if it exists; null otherwise.
         */
        public Gtk.TreeIter? iter {
            owned get {
                Gtk.TreeIter? rv = null;

                if (valid) {
                    var _path = this.path;
                    if (_path != null) {
                        Gtk.TreeIter _iter;
                        if (row_reference.get_model ().get_iter (out _iter, _path))
                            rv = _iter;
                    }
                }

                return rv;
            }
        }

        /**
         * A newly-created Gtk.TreePath pointing to the node if it exists; null otherwise.
         */
        public Gtk.TreePath? path {
            owned get { return valid ? row_reference.get_path () : null; }
        }

        /**
         * Whether the node is valid or not. When it is not valid, no valid references are
         * returned by the object to avoid errors (null is returned instead).
         */
        public bool valid {
            get { return row_reference != null && row_reference.valid (); }
        }

        public NodeWrapper (Gtk.TreeModel model, Gtk.TreeIter iter) {
            row_reference = new Gtk.TreeRowReference (model, model.get_path (iter));
        }
    }

    /**
     * Helper object used to monitor item property changes.
     */
    private class ItemMonitor {
        public signal void changed (Item self, string prop_name);
        private Item item;

        public ItemMonitor (Item item) {
            this.item = item;
            item.notify.connect_after (on_notify);
        }

        ~ItemMonitor () {
            item.notify.disconnect (on_notify);
        }

        private void on_notify (ParamSpec prop) {
            changed (item, prop.name);
        }
    }

    private enum Column {
        ITEM,
        N_COLUMNS;

        public Type type () {
            switch (this) {
                case ITEM:
                    return typeof (Item);

                default:
                    assert_not_reached (); // a Type must be returned for every valid column
            }
        }
    }

    public signal void item_updated (Item item);

    /**
     * Used by push_parent_update() as key to associate the respective data to the objects.
     */
    private const string ITEM_PARENT_NEEDS_UPDATE = "item-parent-needs-update";

    private ExpandableItem _root;

    /**
     * Root item.
     *
     * This item is not actually part of the model. It's only used as a proxy
     * for adding and removing items.
     */
    public ExpandableItem root {
        get { return _root; }
        set {
            if (_root != null) {
                remove_children_monitor (_root);
                foreach (var item in _root.children)
                    remove_item (item);
            }

            _root = value;

            add_children_monitor (_root);
            foreach (var item in _root.children)
                add_item (item);
        }
    }

    // This hash map stores items and their respective child node references. For that reason, the
    // references it contains should only be used on the child_tree model, or converted to filter
    // iters/paths using convert_child_*_to_*() before using them with the filter (i.e. this) model.
    private Gee.HashMap<Item, NodeWrapper> items = new Gee.HashMap<Item, NodeWrapper> ();

    private Gee.HashMap<Item, ItemMonitor> monitors = new Gee.HashMap<Item, ItemMonitor> ();

    private Gtk.TreeStore child_tree;
    private unowned VisibleFunc? filter_func;

    public DataModel () {

    }

    construct {
        child_tree = new Gtk.TreeStore (Column.N_COLUMNS, Column.ITEM.type ());
        child_model = child_tree;
        virtual_root = null;

        child_tree.set_default_sort_func (child_model_sort_func);
        resort ();

        set_visible_func (filter_visible_func);
    }

    public bool has_item (Item item) {
        return items.has_key (item);
    }

    public void update_item (Item item) requires (has_item (item)) {
        assert (root != null);

        // Emitting row_changed() for this item's row in the child model causes the filter
        // (i.e. this model) to re-evaluate whether a row is visible or not, calling
        // filter_visible_func() for that row again, and that's exactly what we want.
        var node_reference = items.get (item);
        if (node_reference != null) {
            var path = node_reference.path;
            var iter = node_reference.iter;
            if (path != null && iter != null) {
                child_tree.row_changed (path, iter);
                item_updated (item);
            }
        }
    }

    private void add_item (Item item) requires (!has_item (item)) {
        assert (root != null);

        // Find the parent iter
        Gtk.TreeIter? parent_child_iter = null, child_iter;
        var parent = item.parent;

        if (parent != null && parent != root) {
            // Add parent if it hasn't been added yet
            if (!has_item (parent))
                add_item (parent);

            // Try to find the parent's iter
            parent_child_iter = get_item_child_iter (parent);

            // Parent must have been added prior to adding this item
            assert (parent_child_iter != null);
        }

        child_tree.append (out child_iter, parent_child_iter);
        child_tree.set (child_iter, Column.ITEM, item, -1);

        items.set (item, new NodeWrapper (child_tree, child_iter));

        // This is equivalent to a property change. The tree still needs to update
        // some of the new item's properties through this signal's handler.
        item_updated (item);

        add_property_monitor (item);

        push_parent_update (parent);

        // If the item is expandable, also add children
        var expandable = item as ExpandableItem;
        if (expandable != null) {
            foreach (var child_item in expandable.children)
                add_item (child_item);

            // Monitor future additions/removals through signal handlers
            add_children_monitor (expandable);
        }
    }

    private void remove_item (Item item) requires (has_item (item)) {
        assert (root != null);

        remove_property_monitor (item);

        // get_item_child_iter() depends on items.get(item) for retrieving the right reference,
        // so don't unset the item from @items yet! We first get the child iter and then
        // unset the value.
        var child_iter = get_item_child_iter (item);

        // Now we remove the item from the table, because that way get_item_child_iter() and
        // all the methods that depend on it won't return invalid iters or items when
        // called. This is important because child_tree.remove() will emit row_deleted(),
        // and its handlers could potentially depend on one of the methods mentioned above.
        items.unset (item);

        if (child_iter != null)
            child_tree.remove (ref child_iter);

        push_parent_update (item.parent);

        // If the item is expandable, also remove children
        var expandable = item as ExpandableItem;
        if (expandable != null) {
            // No longer monitor future additions or removals
            remove_children_monitor (expandable);

            foreach (var child_item in expandable.children)
                remove_item (child_item);
        }
    }

    private void add_property_monitor (Item item) {
        var wrapper = new ItemMonitor (item);
        monitors[item] = wrapper;
        wrapper.changed.connect (on_item_prop_changed);
    }

    private void remove_property_monitor (Item item) {
        var wrapper = monitors[item];
        if (wrapper != null)
            wrapper.changed.disconnect (on_item_prop_changed);
        monitors.unset (item);
    }

    private void add_children_monitor (ExpandableItem item) {
        item.child_added.connect_after (on_item_child_added);
        item.child_removed.connect_after (on_item_child_removed);
    }

    private void remove_children_monitor (ExpandableItem item) {
        item.child_added.disconnect (on_item_child_added);
        item.child_removed.disconnect (on_item_child_removed);
    }

    private void on_item_child_added (Item item) {
        add_item (item);
    }

    private void on_item_child_removed (Item item) {
        remove_item (item);
    }

    private void on_item_prop_changed (Item item, string prop_name) {
        if (prop_name != "parent")
            update_item (item);
    }

    /**
     * Pushes a call to update_item() if //parent// is not //null//.
     *
     * This is needed because the visibility of categories depends on their n_children property,
     * and also because item expansion should be updated after adding or removing items.
     * If many updates are pushed, and the item has still not been updated, only one is processed.
     * This guarantees efficiency as updating a category item could trigger expensive actions.
     */
    private void push_parent_update (ExpandableItem? parent) {
        if (parent == null)
            return;

        bool needs_update = parent.get_data<bool> (ITEM_PARENT_NEEDS_UPDATE);

        // If an update is already waiting to be processed, just return, as we
        // don't need to queue another one for the same item.
        if (needs_update)
            return;

        var path = get_item_path (parent);

        if (path != null) {
            // Let's mark this item for update
            parent.set_data<bool> (ITEM_PARENT_NEEDS_UPDATE, true);

            Idle.add (() => {
                if (parent != null) {
                    update_item (parent);

                    // Already updated. No longer needs an update.
                    parent.set_data<bool> (ITEM_PARENT_NEEDS_UPDATE, false);
                }

                return false;
            });
        }
    }

    /**
     * Returns the Item pointed by iter, or null if the iter doesn't refer to a valid item.
     */
    public Item? get_item (Gtk.TreeIter iter) {
        Item? item;
        get (iter, Column.ITEM, out item, -1);
        return item;
    }

    /**
     * Returns the Item pointed by path, or null if the path doesn't refer to a valid item.
     */
    public Item? get_item_from_path (Gtk.TreePath path) {
        Gtk.TreeIter iter;
        if (get_iter (out iter, path))
            return get_item (iter);

        return null;
    }

    /**
     * Returns a newly-created path pointing to the item, or null in case a valid path
     * is not found.
     */
    public Gtk.TreePath? get_item_path (Item item) {
        Gtk.TreePath? path = null, child_path = get_item_child_path (item);

        // We want a filter path, not a child_model path
        if (child_path != null)
            path = convert_child_path_to_path (child_path);

        return path;
    }

    /**
     * Returns a newly-created iterator pointing to the item, or null in case a valid iter
     * was not found.
     */
    public Gtk.TreeIter? get_item_iter (Item item) {
        var child_iter = get_item_child_iter (item);

        if (child_iter != null) {
            Gtk.TreeIter iter;
            if (convert_child_iter_to_iter (out iter, child_iter))
                return iter;
        }

        return null;
    }

    /**
     * External "extra" filter method.
     */
    public void set_filter_func (VisibleFunc? visible_func) {
        this.filter_func = visible_func;
    }

    /**
     * Checks whether an item is a category (i.e. a root-level expandable item).
     * The caller must pass an iter or path pointing to the item, but not both
     * (one of them must be null.)
     *
     * TODO: instead of checking the position of the iter or path, we should simply
     * check whether the item's parent is the root item and whether the item is
     * expandable. We don't do so right now because vala still allows client code
     * to access the Item.parent property, even though its setter is defined as internal.
     */
    public bool is_category (Item item, Gtk.TreeIter? iter, Gtk.TreePath? path = null) {
        bool is_category = false;
        // either iter or path has to be null
        if (item is ExpandableItem) {
            if (iter != null) {
                assert (path == null);
                is_category = is_iter_at_root_level (iter);
            } else {
                assert (iter == null);
                is_category = is_path_at_root_level (path);
            }
        }
        return is_category;
    }

    public bool is_iter_at_root_level (Gtk.TreeIter iter) {
        return is_path_at_root_level (get_path (iter));
    }

    public bool is_path_at_root_level (Gtk.TreePath path) {
        return path.get_depth () == 1;
    }

    private void resort () {
        child_tree.set_sort_column_id (Gtk.SortColumn.UNSORTED, Gtk.SortType.ASCENDING);
        child_tree.set_sort_column_id (Gtk.SortColumn.DEFAULT, Gtk.SortType.ASCENDING);
    }

    private int child_model_sort_func (Gtk.TreeModel model, Gtk.TreeIter a, Gtk.TreeIter b) {
        int order = 0;

        Item? item_a, item_b;
        child_tree.get (a, Column.ITEM, out item_a, -1);
        child_tree.get (b, Column.ITEM, out item_b, -1);

        // code should only compare items at same hierarchy level
        assert (item_a.parent == item_b.parent);

        var parent = item_a.parent as Sortable;
        if (parent != null)
            order = parent.compare (item_a, item_b);

        return order;
    }

    private Gtk.TreeIter? get_item_child_iter (Item item) {
        Gtk.TreeIter? child_iter = null;

        var child_node_wrapper = items.get (item);
        if (child_node_wrapper != null)
            child_iter = child_node_wrapper.iter;

        return child_iter;
    }

    private Gtk.TreePath? get_item_child_path (Item item) {
        Gtk.TreePath? child_path = null;

        var child_node_wrapper = items.get (item);
        if (child_node_wrapper != null)
            child_path = child_node_wrapper.path;

        return child_path;
    }

    /**
     * Filters the child-tree items based on their "visible" property.
     */
    private bool filter_visible_func (Gtk.TreeModel child_model, Gtk.TreeIter iter) {
        bool item_visible = false;

        Item? item;
        child_tree.get (iter, Column.ITEM, out item, -1);

        if (item != null) {
           item_visible = item.visible;

            // If the item is a category, also query the number of visible children
            // because empty categories should not be displayed.
            var expandable = item as ExpandableItem;
            if (expandable != null && child_tree.iter_depth (iter) == 0) {
                uint n_visible_children = 0;
                foreach (var child_item in expandable.children) {
                    if (child_item.visible)
                        n_visible_children++;
                }
                item_visible = item_visible && n_visible_children > 0;
            }
        }

        if (filter_func != null)
            item_visible = item_visible && filter_func (item);

        return item_visible;
    }

    // /**
    //  * TreeDragDest implementation
    //  */

    // public bool drag_data_received (Gtk.TreePath dest, Gtk.SelectionData selection_data) {
    //     Gtk.TreeModel model;
    //     Gtk.TreePath src_path;

    //     // Check if the user is dragging a row:
    //     //
    //     // Due to Gtk.TreeModelFilter's implementation of drag_data_get the values returned by
    //     // tree_row_drag_data for GtkModel and GtkPath correspond to the child model and not the filter.
    //     if (Gtk.tree_get_row_drag_data (selection_data, out model, out src_path) && model == child_tree) {
    //         // get a child path representation of dest
    //         var child_dest = convert_path_to_child_path (dest);

    //         if (child_dest != null) {
    //             // New GtkTreeIters will be assigned to the rows at child_dest and its children.
    //             if (child_tree_drag_data_received (child_dest, src_path))
    //                 return true;
    //         }
    //     }

    //     // no new row inserted
    //     return false;
    // }

    private bool child_tree_drag_data_received (Gtk.TreePath dest, Gtk.TreePath src_path) {
        bool retval = false;
        Gtk.TreeIter src_iter, dest_iter;

        if (!child_tree.get_iter (out src_iter, src_path))
            return false;

        var prev = dest;

        // Get the path to insert _after_ (dest is the path to insert _before_)
        if (!prev.prev ()) {
            // dest was the first spot at the current depth; which means
            // we are supposed to prepend.

            var parent = dest;
            Gtk.TreeIter? dest_parent = null;

            if (parent.up () && parent.get_depth () > 0)
                child_tree.get_iter (out dest_parent, parent);

            child_tree.prepend (out dest_iter, dest_parent);
            retval = true;
        } else if (child_tree.get_iter (out dest_iter, prev)) {
            var tmp_iter = dest_iter;
            child_tree.insert_after (out dest_iter, null, tmp_iter);
            retval = true;
        }

        // If we succeeded in creating dest_iter, walk src_iter tree branch,
        // duplicating it below dest_iter.
        if (retval) {
            recursive_node_copy (src_iter, dest_iter);

            // notify that the item was moved
            Item item;
            child_tree.get (src_iter, Column.ITEM, out item, -1);
            return_val_if_fail (item != null, retval);

            // XXX Workaround:
            // GtkTreeView automatically collapses expanded items that
            // are dragged to a new location. Oddly, GtkTreeView doesn't fire
            // 'row-collapsed' for the respective path, so we cannot keep track
            // of that behavior via standard means. For now we'll just have
            // our tree view check the properties of item again and ensure
            // they're honored
            update_item (item);

            var parent = item.parent as Sortable;
            return_val_if_fail (parent != null, retval);

            parent.user_moved_item (item);
        }

        return retval;
    }

    private void recursive_node_copy (Gtk.TreeIter src_iter, Gtk.TreeIter dest_iter) {
        move_item (src_iter, dest_iter);

        Gtk.TreeIter child;
        if (child_tree.iter_children (out child, src_iter)) {
            // Need to create children and recurse. Note our dependence on
            // persistent iterators here.
            do {
                Gtk.TreeIter copy;
                child_tree.append (out copy, dest_iter);
                recursive_node_copy (child, copy);
            } while (child_tree.iter_next (ref child));
        }
    }

    private void move_item (Gtk.TreeIter src_iter, Gtk.TreeIter dest_iter) {
        Item item;
        child_tree.get (src_iter, Column.ITEM, out item, -1);
        return_if_fail (item != null);

        // update the row reference of item with the new location
        child_tree.set (dest_iter, Column.ITEM, item, -1);
        items.set (item, new NodeWrapper (child_tree, dest_iter));
    }

    // public bool row_drop_possible (Gtk.TreePath dest, Gtk.SelectionData selection_data) {
    //     Gtk.TreeModel model;
    //     Gtk.TreePath src_path;

    //     // Check if the user is dragging a row:
    //     // Due to Gtk.TreeModelFilter's implementation of drag_data_get the values returned by
    //     // tree_row_drag_data for GtkModel and GtkPath correspond to the child model and not the filter.
    //     if (!Gtk.tree_get_row_drag_data (selection_data, out model, out src_path) || model != child_tree)
    //         return false;

    //     // get a representation of dest in the child model
    //     var child_dest = convert_path_to_child_path (dest);

    //     // don't allow dropping an item into itself
    //     if (child_dest == null || src_path.compare (child_dest) == 0)
    //         return false;

    //     // Only allow DnD between items at the same depth (indentation level)
    //     // This doesn't mean their parent is the same.
    //     int src_depth = src_path.get_depth ();
    //     int dest_depth = child_dest.get_depth ();

    //     if (src_depth != dest_depth)
    //         return false;

    //     // no need to check dest_depth since we know its equal to src_depth
    //     if (src_depth < 1)
    //         return false;

    //     Item? parent = null;

    //     // if the depth is 1, we're talking about the items at root level,
    //     // and by definition they share the same parent (root). We don't
    //     // need to verify anything else for that specific case
    //     if (src_depth == 1) {
    //         parent = root;
    //     } else {
    //         // we verified equality above. this must be true
    //         assert (dest_depth > 1);

    //         // Only allow reordering between siblings, i.e. items with the same
    //         // parent. We don't want items to change their parent through DnD
    //         // because that would complicate our existing APIs, and may introduce
    //         // unpredictable behavior.
    //         var src_indices = src_path.get_indices ();
    //         var dest_indices = child_dest.get_indices ();

    //         // parent index is given by indices[depth-2], where depth > 1
    //         int src_parent_index = src_indices[src_depth - 2];
    //         int dest_parent_index = dest_indices[dest_depth - 2];

    //         if (src_parent_index != dest_parent_index)
    //             return false;

    //         // get parent. Note that we don't use the child path for this
    //         var dest_parent = dest;

    //         if (!dest_parent.up () || dest_parent.get_depth () < 1)
    //             return false;

    //         parent = get_item_from_path (dest_parent);
    //     }

    //     var sortable = parent as Sortable;

    //     if (sortable == null || !sortable.allow_dnd_sorting ())
    //         return false;

    //     var dest_item = get_item_from_path (dest);

    //     if (dest_item == null)
    //         return true;

    //     Item? source_item = null;
    //     var filter_src_path = convert_child_path_to_path (src_path);

    //     if (filter_src_path != null)
    //         source_item = get_item_from_path (filter_src_path);

    //     if (source_item == null)
    //         return false;

    //     // If order isn't indifferent (=0), 'dest' has to sort before 'source'.
    //     // Otherwise we'd allow the user to move the 'source_item' to a new
    //     // location before 'dest_item', but that location would be changed
    //     // later by the sort function, making the whole interaction poinless.
    //     // We better prevent such reorderings from the start by giving the
    //     // user a visual clue about the invalid drop location.
    //     if (sortable.compare (dest_item, source_item) >= 0) {
    //         if (!dest.prev ())
    //             return true;

    //         // 'source_item' also has to sort 'after' or 'equal' the item currently
    //         // preceding 'dest_item'
    //         var dest_item_prev = get_item_from_path (dest);

    //         return dest_item_prev != null
    //             && dest_item_prev != source_item
    //             && sortable.compare (dest_item_prev, source_item) <= 0;
    //     }

    //     return false;
    // }

    // /**
    //  * Override default implementation of TreeDragSource
    //  *
    //  * drag_data_delete is not overriden because the default implementation
    //  * does exactly what we need.
    //  */

    // public bool drag_data_get (Gtk.TreePath path, Gtk.SelectionData selection_data) {
    //     // If we're asked for a data about a row, just have the default implementation fill in
    //     // selection_data. Please note that it will provide information relative to child_model.
    //     if (selection_data.get_target () == Gdk.Atom.intern_static_string ("GTK_TREE_MODEL_ROW"))
    //         return base.drag_data_get (path, selection_data);

    //     // check if the item at path provides DnD source data
    //     var drag_source_item = get_item_from_path (path) as DragSource;
    //     if (drag_source_item != null && drag_source_item.draggable ()) {
    //         drag_source_item.prepare_selection_data (selection_data);
    //         return true;
    //     }

    //     return false;
    // }

    public bool row_draggable (Gtk.TreePath path) {
        if (!base.row_draggable (path))
            return false;

        var item = get_item_from_path (path);

        if (item != null) {
            // check if the item's parent allows DnD sorting
            var sortable_item = item.parent as Sortable;

            if (sortable_item != null && sortable_item.allow_dnd_sorting ())
                return true;

            // Since the parent item does not allow DnD sorting, there's no
            // reason to allow dragging it unless the row is actually draggable.
            var drag_source_item = item as DragSource;

            if (drag_source_item != null && drag_source_item.draggable ())
                return true;
        }

        return false;
    }
}
}
