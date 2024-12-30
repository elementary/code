/*
 * Copyright 2019 elementary, Inc. (https://elementary.io)
 * Copyright 2012-2014 Victor Martinez <victoreduardm@gmail.com>
 * SPDX-License-Identifier: LGPL-3.0-or-later
 */

namespace Code.Widgets.SourceList {
/**
 * A widget that can display a list of items organized in categories.
 *
 * The source list widget consists of a collection of items, some of which are also expandable (and
 * thus can contain more items). All the items displayed in the source list are children of the widget's
 * root item. The API is meant to be used as follows:
 *
 * 1. Create the items you want to display in the source list, setting the appropriate values for their
 * properties. The desired hierarchy is achieved by creating expandable items and adding items to them.
 * These will be displayed as descendants in the widget's tree structure. The expandable items that are
 * not nested inside any other item are considered to be at root level, and should be added to
 * the widget's root item.<<BR>>
 *
 * Expandable items located at the root level are treated as categories, and only support text.
 *
 * ''Example''<<BR>>
 * The final tree will have the following structure:
 * {{{
 * Libraries
 *   Music
 * Stores
 *   My Store
 *      Music
 *      Podcasts
 * Devices
 *   Player 1
 *   Player 2
 * }}}
 *
 * {{{
 * var library_category = new Code.Widgets.SourceList.ExpandableItem ("Libraries");
 * var store_category = new Code.Widgets.SourceList.ExpandableItem ("Stores");
 * var device_category = new Code.Widgets.SourceList.ExpandableItem ("Devices");
 *
 * var music_item = new Code.Widgets.SourceList.Item ("Music");
 *
 * // "Libraries" will be the parent category of "Music"
 * library_category.add (music_item);
 *
 * // We plan to add sub-items to the store, so let's use an expandable item
 * var my_store_item = new Code.Widgets.SourceList.ExpandableItem ("My Store");
 * store_category.add (my_store_item);
 *
 * var my_store_podcast_item = new Code.Widgets.SourceList.Item ("Podcasts");
 * var my_store_music_item = new Code.Widgets.SourceList.Item ("Music");
 *
 * my_store_item.add (my_store_music_item);
 * my_store_item.add (my_store_podcast_item);
 *
 * var player1_item = new Code.Widgets.SourceList.Item ("Player 1");
 * var player2_item = new Code.Widgets.SourceList.Item ("Player 2");
 *
 * device_category.add (player1_item);
 * device_category.add (player2_item);
 * }}}
 *
 * 2. Create a source list widget.<<BR>>
 * {{{
 * var source_list = new Code.Widgets.SourceList ();
 * }}}
 *
 * 3. Add root-level items to the {@link Code.Widgets.SourceList.root} item.
 * This item only serves as a container, and all its properties are ignored by the widget.
 *
 * {{{
 * // This will add the main categories (including their children) to the source list. After
 * // having being added to be widget, any other item added to any of these items
 * // (or any other child item in a deeper level) will be automatically added too.
 * // There's no need to deal with the source list widget directly.
 *
 * var root = source_list.root;
 *
 * root.add (library_category);
 * root.add (store_category);
 * root.add (device_category);
 * }}}
 *
 * The steps mentioned above are enough for initializing the source list. Future changes to the items'
 * properties are ''automatically'' reflected by the widget.
 *
 * Final steps would involve connecting handlers to the source list events, being
 * {@link Code.Widgets.SourceList.item_selected} the most important, as it indicates that
 * the selection was modified.
 *
 * Pack the source list into the GUI using the {@link Gtk.Paned} widget.
 * This is usually done as follows:
 * {{{
 * var pane = new Gtk.Paned (Gtk.Orientation.HORIZONTAL);
 * pane.pack1 (source_list, false, false);
 * pane.pack2 (content_area, true, false);
 * }}}
 *
 * @since 0.2
 * @see Gtk.Paned
 */
public class Window : Gtk.Widget {
    static construct {
        set_layout_manager_type (typeof (Gtk.BinLayout));
    }

    private Gtk.ScrolledWindow scrolled_window;
    /**
     * = WORKING INTERNALS =
     *
     * In order to offer a transparent Item-based API, and avoid the need of providing methods
     * to deal with items directly on the SourceList widget, it was decided to follow a monitor-like
     * implementation, where the source list permanently monitors its root item and any other
     * child item added to it. The task of monitoring the properties of the items has been
     * divided among different objects, as shown below:
     *
     * Monitored by: Object::method that receives the signals indicating the property change.
     * Applied by: Object::method that actually updates the tree to reflect the property changes
     *             (directly or indirectly, as in the case of the tree data model).
     *
     * ---------------------------------------------------------------------------------------------
     *   PROPERTY        |  MONITORED BY                     |  APPLIED BY
     * ---------------------------------------------------------------------------------------------
     * + Item            |                                   |
     *   - parent        | Not monitored                     | N/A
     *   - name          | DataModel::on_item_prop_changed   | Tree::name_cell_data_func
     *   - editable      | DataModel::on_item_prop_changed   | Queried when needed (See Tree::start_editing_item)
     *   - visible       | DataModel::on_item_prop_changed   | DataModel::filter_visible_func
     *   - icon          | DataModel::on_item_prop_changed   | Tree::icon_cell_data_func
     *   - activatable   | Same as @icon                     | Same as @icon
     * + ExpandableItem  |                                   |
     *   - collapsible   | DataModel::on_item_prop_changed   | Tree::update_expansion
     *                   |                                   | Tree::expander_cell_data_func
     *   - expanded      | Same as @collapsible              | Same as @collapsible
     * ---------------------------------------------------------------------------------------------
     * * Only automatic properties are monitored. ExpandableItem's additions/removals are handled by
     *   DataModel::add_item() and DataModel::remove_item()
     *
     * Other features:
     * - Sorting: this happens on the tree-model level (DataModel).
     */

    /**
     * Emitted when the source list selection changes.
     *
     * @param item Selected item; //null// if nothing is selected.
     * @since 0.2
     */
    public virtual signal void item_selected (Item? item) { }

    /**
     * Root-level expandable item.
     *
     * This item contains the first-level source list items. It //only serves as an item container//.
     * It is used to add and remove items to/from the widget.
     *
     * Internally, it allows the source list to connect to its {@link Code.Widgets.SourceList.ExpandableItem.child_added}
     * and {@link Code.Widgets.SourceList.ExpandableItem.child_removed} signals in order to monitor
     * new children additions/removals.
     *
     * @since 0.2
     */
    public ExpandableItem root {
        get { return data_model.root; }
        set { data_model.root = value; }
    }

    /**
     * The current selected item.
     *
     * Setting it to //null// un-selects the previously selected item, if there was any.
     * {@link Code.Widgets.SourceList.ExpandableItem.expand_with_parents} is called on the
     * item's parent to make sure it's possible to select it.
     *
     * @since 0.2
     */
    public Item? selected {
        get { return tree.selected_item; }
        set {
            if (value != null && value.parent != null)
                value.parent.expand_with_parents ();
            tree.selected_item = value;
        }
    }

    /**
     * Text ellipsize mode.
     *
     * @since 0.2
     */
    public Pango.EllipsizeMode ellipsize_mode {
        get { return tree.ellipsize_mode; }
        set { tree.ellipsize_mode = value; }
    }

    /**
     * Whether an item is being edited.
     *
     * @see Code.Widgets.SourceList.start_editing_item
     * @since 0.2
     */
    public bool editing {
        get { return tree.editing; }
    }

    public bool activate_on_single_click {
        set {
            tree.activate_on_single_click = value;
        }
    }

    private Tree tree;
    private DataModel data_model = new DataModel ();

    /**
     * Creates a new {@link Code.Widgets.SourceList}.
     *
     * @return A new {@link Code.Widgets.SourceList}.
     * @since 0.2
     */
    public Window (ExpandableItem root = new ExpandableItem ()) {
        this.root = root;
    }

    construct {
        var lm = new Gtk.BinLayout ();
        set_layout_manager (lm);

        tree = new Tree (data_model);
        scrolled_window = new Gtk.ScrolledWindow () {
            child = tree
        };

        scrolled_window.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
        this.child = scrolled_window;

        tree.item_selected.connect ((item) => item_selected (item));
    }

    /**
     * Checks whether //item// is part of the source list.
     *
     * @param item The item to query.
     * @return //true// if the item belongs to the source list; //false// otherwise.
     * @since 0.2
     */
    public bool has_item (Item item) {
        return data_model.has_item (item);
    }

    /**
     * Sets the method used for filtering out items.
     *
     * @param visible_func The method to use for filtering items.
     * @param refilter Whether to call {@link Code.Widgets.SourceList.refilter} using the new function.
     * @see Code.Widgets.SourceList.VisibleFunc
     * @see Code.Widgets.SourceList.refilter
     * @since 0.2
     */
    public void set_filter_func (VisibleFunc? visible_func, bool refilter) {
        data_model.set_filter_func (visible_func);
        if (refilter)
            this.refilter ();
    }

    /**
     * Applies the filter method set by {@link Code.Widgets.SourceList.set_filter_func}
     * to all the items that are part of the current tree.
     *
     * @see Code.Widgets.SourceList.VisibleFunc
     * @see Code.Widgets.SourceList.set_filter_func
     * @since 0.2
     */
    public void refilter () {
        data_model.refilter ();
    }

    /**
     * Queries the actual expansion state of //item//.
     *
     * @see Code.Widgets.SourceList.ExpandableItem.expanded
     * @return Whether //item// is expanded or not.
     * @since 0.2
     */
    public bool is_item_expanded (Item item) requires (has_item (item)) {
        var path = data_model.get_item_path (item);
        return path != null && tree.is_row_expanded (path);
    }

    /**
     * If //item// is editable, this activates the editor; otherwise, it does nothing.
     * If an item was already being edited, this will fail.
     *
     * @param item Item to edit.
     * @see Code.Widgets.SourceList.Item.editable
     * @see Code.Widgets.SourceList.editing
     * @see Code.Widgets.SourceList.stop_editing
     * @return true if the editing started successfully; false otherwise.
     * @since 0.2
     */
    public bool start_editing_item (Item item) requires (has_item (item)) {
        return tree.start_editing_item (item);
    }

    /**
     * Cancels any editing operation going on.
     *
     * @see Code.Widgets.SourceList.editing
     * @see Code.Widgets.SourceList.start_editing_item
     * @since 0.2
     */
    public void stop_editing () {
        if (editing)
            tree.stop_editing ();
    }

    /**
     * Turns Source List into a //drag source//.
     *
     * This enables items that implement {@link Code.Widgets.SourceListDragSource}
     * to be dragged outside the Source List and drop data into external widgets.
     *
     * @param src_entries an array of {@link GLib.Value}s indicating the targets
     * that the drag will support.
     * @see Code.Widgets.SourceListDragSource
     * @see Code.Widgets.SourceList.disable_drag_source
     * @since 0.3
     */
    public void enable_drag_source (GLib.Value[] src_entries) {
        tree.configure_drag_source (src_entries);
    }

    /**
     * Undoes the effect of {@link Code.Widgets.SourceList.enable_drag_source}
     *
     * @see Code.Widgets.SourceList.enable_drag_source
     * @since 0.3
     */
    public void disable_drag_source () {
        tree.configure_drag_source (null);
    }

    /**
     * Turns Source List into a //drop destination//.
     *
     * This enables items that implement {@link Code.Widgets.SourceListDragDest}
     * to receive data from external widgets via drag-and-drop.
     *
     * @param dest_entries an array of {@link GLib.Value}s indicating the drop
     * types that Source List items will accept.
     * @param actions a bitmask of possible actions for a drop onto Source List items.
     * @see Code.Widgets.SourceListDragDest
     * @see Code.Widgets.SourceList.disable_drag_dest
     * @since 0.3
     */
    public void enable_drag_dest (GLib.Value[] dest_entries, Gdk.DragAction actions) {
        tree.configure_drag_dest (dest_entries, actions);
    }

    /**
     * Undoes the effect of {@link Code.Widgets.SourceList.enable_drag_dest}
     *
     * @see Code.Widgets.SourceList.enable_drag_dest
     * @since 0.3
     */
    public void disable_drag_dest () {
        tree.configure_drag_dest (null, 0);
    }

    /**
     * Scrolls the source list tree to make //item// visible.
     *
     * {@link Code.Widgets.SourceList.ExpandableItem.expand_with_parents} is called
     * for the item's parent if //expand_parents// is //true//, to make sure it's not
     * hidden behind a collapsed row.
     *
     * If use_align is //false//, then the row_align argument is ignored, and the tree
     * does the minimum amount of work to scroll the item onto the screen. This means that
     * the item will be scrolled to the edge closest to its current position. If the item
     * is currently visible on the screen, nothing is done.
     *
     * @param item Item to scroll to.
     * @param expand_parents Whether to recursively expand item's parent in case they are collapsed.
     * @param use_align Whether to use the //row_align// argument.
     * @param row_align The vertical alignment of //item//. 0.0 means top, 0.5 center, and 1.0 bottom.
     * @return //true// if successful; //false// otherwise.
     * @since 0.2
     */
    public bool scroll_to_item (
        Item item,
        bool expand_parents = true,
        bool use_align = false,
        float row_align = 0
    ) requires (has_item (item)) {
        if (expand_parents && item.parent != null)
            item.parent.expand_with_parents ();

        return tree.scroll_to_item (item, use_align, row_align);
    }

    /**
     * Gets the previous item with respect to //reference//.
     *
     * @param reference Item to use as reference.
     * @return The item that appears before //reference//, or //null// if there's none.
     * @since 0.2
     */
    public Item? get_previous_item (Item reference) requires (has_item (reference)) {
        // this will return null for root, so iter_n_children() will always work fine
        var iter = data_model.get_item_iter (reference);
        if (iter != null) {
            Gtk.TreeIter new_iter = iter; // workaround for valac 0.18
            if (data_model.iter_previous (ref new_iter))
                return data_model.get_item (new_iter);
        }

        return null;
    }

    /**
     * Gets the next item with respect to //reference//.
     *
     * @param reference Item to use as reference.
     * @return The item that appears after //reference//, or //null// if there's none.
     * @since 0.2
     */
    public Item? get_next_item (Item reference) requires (has_item (reference)) {
        // this will return null for root, so iter_n_children() will always work fine
        var iter = data_model.get_item_iter (reference);
        if (iter != null) {
            Gtk.TreeIter new_iter = iter; // workaround for valac 0.18
            if (data_model.iter_next (ref new_iter))
                return data_model.get_item (new_iter);
        }

        return null;
    }

    /**
     * Gets the first visible child of an expandable item.
     *
     * @param parent Parent of the child to look up.
     * @return The first visible child of //parent//, or null if it was not found.
     * @since 0.2
     */
    public Item? get_first_child (ExpandableItem parent) {
        return get_nth_child (parent, 0);
    }

    /**
     * Gets the last visible child of an expandable item.
     *
     * @param parent Parent of the child to look up.
     * @return The last visible child of //parent//, or null if it was not found.
     * @since 0.2
     */
    public Item? get_last_child (ExpandableItem parent) {
        return get_nth_child (parent, (int) get_n_visible_children (parent) - 1);
    }

    /**
     * Gets the number of visible children of an expandable item.
     *
     * @param parent Item to query.
     * @return Number of visible children of //parent//.
     * @since 0.2
     */
    public uint get_n_visible_children (ExpandableItem parent) {
        // this will return null for root, so iter_n_children() will always work properly.
        var parent_iter = data_model.get_item_iter (parent);
        return data_model.iter_n_children (parent_iter);
    }

    private Item? get_nth_child (ExpandableItem parent, int index) {
        if (index < 0)
            return null;

        // this will return null for root, so iter_nth_child() will always work properly.
        var parent_iter = data_model.get_item_iter (parent);

        Gtk.TreeIter child_iter;
        if (data_model.iter_nth_child (out child_iter, parent_iter, index))
            return data_model.get_item (child_iter);

        return null;
    }
}
}
