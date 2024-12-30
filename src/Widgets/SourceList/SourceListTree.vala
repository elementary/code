/*
 * Copyright 2019 elementary, Inc. (https://elementary.io)
 * Copyright 2012-2014 Victor Martinez <victoreduardm@gmail.com>
 * SPDX-License-Identifier: LGPL-3.0-or-later
 */

namespace Code.Widgets.SourceList {
/**
 * The tree that actually displays the items.
 *
 * All the user interaction happens here.
 */
private class Tree : Gtk.TreeView {

    public DataModel data_model { get; construct set; }

    public signal void item_selected (Item? item);

    public Item? selected_item {
        get { return selected; }
        set { set_selected (value, true); }
    }

    public bool editing {
        get { return text_cell.editing; }
    }

    public Pango.EllipsizeMode ellipsize_mode {
        get { return text_cell.ellipsize; }
        set { text_cell.ellipsize = value; }
    }

    private enum Column {
        ITEM,
        N_COLS
    }

    private Item? selected;
    private unowned Item? edited;

    private Gtk.Entry? editable_entry;
    private Gtk.CellRendererText text_cell;
    private CellRendererIcon icon_cell;
    private CellRendererIcon activatable_cell;
    private CellRendererBadge badge_cell;
    private CellRendererExpander primary_expander_cell;
    private CellRendererExpander secondary_expander_cell;
    private Gee.HashMap<int, CellRendererSpacer> spacer_cells; // cells used for left spacing
    private bool unselectable_item_clicked = false;

    private const string DEFAULT_STYLESHEET = """
        .sidebar.badge {
            border-radius: 10px;
            border-width: 0;
            padding: 1px 2px 1px 2px;
            font-weight: bold;
        }
    """;

    private const string STYLE_PROP_LEVEL_INDENTATION = "level-indentation";
    private const string STYLE_PROP_LEFT_PADDING = "left-padding";
    private const string STYLE_PROP_EXPANDER_SPACING = "expander-spacing";

    static construct {
        install_style_property (new ParamSpecInt (
            STYLE_PROP_LEVEL_INDENTATION,
            "Level Indentation",
            "Space to add at the beginning of every indentation level. Must be an even number.",
            1,
            50,
            6,
            ParamFlags.READABLE
        ));

        install_style_property (new ParamSpecInt (
            STYLE_PROP_LEFT_PADDING,
            "Left Padding",
            "Padding added to the left side of the tree. Must be an even number.",
            1,
            50,
            4,
            ParamFlags.READABLE
        ));

        install_style_property (new ParamSpecInt (
            STYLE_PROP_EXPANDER_SPACING,
            "Expander Spacing",
            "Space added between an item and its expander. Must be an even number.",
            1,
            50,
            4,
            ParamFlags.READABLE
        ));
    }

    public Tree (DataModel data_model) {
        Object (data_model: data_model);
    }

    construct {
        unowned Gtk.StyleContext style_context = get_style_context ();
        style_context.add_class (Gtk.STYLE_CLASS_SIDEBAR);
        style_context.add_class ("source-list");

        var css_provider = new Gtk.CssProvider ();
        try {
            css_provider.load_from_data (DEFAULT_STYLESHEET, -1);
            style_context.add_provider (css_provider, Gtk.STYLE_PROVIDER_PRIORITY_FALLBACK);
        } catch (Error e) {
            warning ("Could not create CSS Provider: %s\nStylesheet:\n%s", e.message, DEFAULT_STYLESHEET);
        }

        set_model (data_model);

        halign = valign = Gtk.Align.FILL;
        expand = true;

        enable_search = false;
        headers_visible = false;
        enable_grid_lines = Gtk.TreeViewGridLines.NONE;

        // Deactivate GtkTreeView's built-in expander functionality
        expander_column = null;
        show_expanders = false;

        var item_column = new Gtk.TreeViewColumn ();
        item_column.expand = true;

        insert_column (item_column, Column.ITEM);

        // Now pack the cell renderers. We insert them in reverse order (using pack_end)
        // because we want to use TreeViewColumn.pack_start exclusively for inserting
        // spacer cell renderers for level-indentation purposes.
        // See add_spacer_cell_for_level() for more details.

        // Second expander. Used for main categories
        secondary_expander_cell = new CellRendererExpander ();
        secondary_expander_cell.is_category_expander = true;
        secondary_expander_cell.xpad = 10;
        item_column.pack_end (secondary_expander_cell, false);
        item_column.set_cell_data_func (secondary_expander_cell, expander_cell_data_func);

        activatable_cell = new CellRendererIcon ();
        activatable_cell.xpad = 6;
        activatable_cell.activated.connect (on_activatable_activated);
        item_column.pack_end (activatable_cell, false);
        item_column.set_cell_data_func (activatable_cell, icon_cell_data_func);

        badge_cell = new CellRendererBadge ();
        badge_cell.xpad = 1;
        badge_cell.xalign = 1;
        item_column.pack_end (badge_cell, false);
        item_column.set_cell_data_func (badge_cell, badge_cell_data_func);

        text_cell = new Gtk.CellRendererText ();
        text_cell.editable_set = true;
        text_cell.editable = false;
        text_cell.editing_started.connect (on_editing_started);
        text_cell.editing_canceled.connect (on_editing_canceled);
        text_cell.ellipsize = Pango.EllipsizeMode.END;
        text_cell.xalign = 0;
        item_column.pack_end (text_cell, true);
        item_column.set_cell_data_func (text_cell, name_cell_data_func);

        icon_cell = new CellRendererIcon ();
        icon_cell.xpad = 2;
        item_column.pack_end (icon_cell, false);
        item_column.set_cell_data_func (icon_cell, icon_cell_data_func);

        // First expander. Used for normal expandable items
        primary_expander_cell = new CellRendererExpander ();

        int expander_spacing;
        style_get (STYLE_PROP_EXPANDER_SPACING, out expander_spacing);
        primary_expander_cell.xpad = expander_spacing / 2;

        item_column.pack_end (primary_expander_cell, false);
        item_column.set_cell_data_func (primary_expander_cell, expander_cell_data_func);

        // Selection
        var selection = get_selection ();
        selection.mode = Gtk.SelectionMode.BROWSE;
        selection.set_select_function (select_func);

        // Monitor item changes
        enable_item_property_monitor ();

        // Add root-level indentation. New levels will be added by update_item_expansion()
        add_spacer_cell_for_level (1);

        unset_rows_drag_dest ();
        unset_rows_drag_source ();

        var key_controller = new Gtk.EventControllerKey () {
            propagation_phase = CAPTURE
        };
        add_controller (key_controller);
        key_controller.key_released.connect (on_key_release_event);

        query_tooltip.connect_after (on_query_tooltip);
        has_tooltip = true;
    }

    ~Tree () {
        disable_item_property_monitor ();
    }

    private bool on_query_tooltip (int x, int y, bool keyboard_tooltip, Gtk.Tooltip tooltip) {
        Gtk.TreePath path;
        Gtk.TreeViewColumn column = get_column (Column.ITEM);

        get_tooltip_context (ref x, ref y, keyboard_tooltip, null, out path, null);
        if (path == null) {
            return false;
        }

        var item = data_model.get_item_from_path (path);
        if (item != null) {
            bool should_show = false;

            Gdk.Rectangle start_cell_area;
            get_cell_area (path, column, out start_cell_area);

            set_tooltip_row (tooltip, path);

            if (item.tooltip == null) {
                tooltip.set_markup (item.name);
                should_show = true;
            } else if (item.tooltip != "") {
                tooltip.set_markup (item.tooltip);
                should_show = true;
            }

            if (keyboard_tooltip) {
                return should_show;
            }

            if (over_cell (column, path, text_cell, x - start_cell_area.x) ||
                over_cell (column, path, icon_cell, x - start_cell_area.x)) {

                return should_show;
            } else if (over_cell (column, path, activatable_cell, x - start_cell_area.x)) {
                if (item.activatable_tooltip == "") {
                    return false;
                } else {
                    tooltip.set_markup (item.activatable_tooltip);
                    return true;
                }
            }
        }

        return false;
    }

    private static GLib.Value[] append_row_target_entry (GLib.Value[]? orig) {
        const GLib.Value row_target_entry = { // vala-lint=naming-convention
            "GTK_TREE_MODEL_ROW",
            Gtk.TargetFlags.SAME_WIDGET,
            0
        };

        var entries = new GLib.Value[0];
        entries += row_target_entry;

        if (orig != null) {
            foreach (var target_entry in orig)
                entries += target_entry;
        }

        return entries;
    }

    private void enable_item_property_monitor () {
        data_model.item_updated.connect_after (on_model_item_updated);
    }

    private void disable_item_property_monitor () {
        data_model.item_updated.disconnect (on_model_item_updated);
    }

    private void on_model_item_updated (Item item) {
        // Currently, all the other properties are updated automatically by the
        // cell-data functions after a change in the model.
        var expandable_item = item as ExpandableItem;
        if (expandable_item != null)
            update_expansion (expandable_item);
    }

    private void add_spacer_cell_for_level (
        int level,
        bool check_previous = true
    ) requires (level > 0) {
        if (spacer_cells == null)
            spacer_cells = new Gee.HashMap<int, CellRendererSpacer> ();

        if (!spacer_cells.has_key (level)) {
            var spacer_cell = new CellRendererSpacer ();
            spacer_cell.level = level;
            spacer_cells[level] = spacer_cell;

            uint cell_xpadding;

            // The primary expander is not visible for root-level (i.e. first level)
            // items, so for the second level of indentation we use a low padding
            // because the primary expander will add enough space. For the root level,
            // we use left_padding, and level_indentation for the remaining levels.
            // The value of cell_xpadding will be allocated *twice* by the cell renderer,
            // so we set the value to a half of actual (desired) value.
            switch (level) {
                case 1: // root
                    int left_padding;
                    style_get (STYLE_PROP_LEFT_PADDING, out left_padding);
                    cell_xpadding = left_padding / 2;
                break;

                case 2: // second level
                    cell_xpadding = 0;
                break;

                default: // remaining levels
                    int level_indentation;
                    style_get (STYLE_PROP_LEVEL_INDENTATION, out level_indentation);
                    cell_xpadding = level_indentation / 2;
                break;
            }

            spacer_cell.xpad = cell_xpadding;

            var item_column = get_column (Column.ITEM);
            item_column.pack_start (spacer_cell, false);
            item_column.set_cell_data_func (spacer_cell, spacer_cell_data_func);

            // Make sure that the previous indentation levels also exist
            if (check_previous) {
                for (int i = level - 1; i > 0; i--)
                    add_spacer_cell_for_level (i, false);
            }
        }
    }

    /**
     * Evaluates whether the item at the specified path can be selected or not.
     */
    private bool select_func (
        Gtk.TreeSelection selection,
        Gtk.TreeModel model,
        Gtk.TreePath path,
        bool path_currently_selected
    ) {
        bool selectable = false;
        var item = data_model.get_item_from_path (path);

        if (item != null) {
            // Main categories ARE NOT selectable, so check for that
            if (!data_model.is_category (item, null, path))
                selectable = item.selectable;
        }

        return selectable;
    }

    private Gtk.TreePath? get_selected_path () {
        Gtk.TreePath? selected_path = null;
        Gtk.TreeSelection? selection = get_selection ();

        if (selection != null) {
            Gtk.TreeModel? model;
            var selected_rows = selection.get_selected_rows (out model);
            if (selected_rows.length () == 1)
                selected_path = selected_rows.nth_data (0);
        }

        return selected_path;
    }

    private void set_selected (Item? item, bool scroll_to_item) {
        if (item == null) {
            Gtk.TreeSelection? selection = get_selection ();
            if (selection != null)
                selection.unselect_all ();

            // As explained in cursor_changed(), we cannot emit signals for this special
            // case from there because that wouldn't allow us to implement the behavior
            // we want (i.e. restoring the old selection after expanding a previously
            // collapsed category) without emitting the undesired item_selected() signal
            // along the way. This special case is handled manually, because it *should*
            // only happen in response to client code requests and never in response to
            // user interaction. We do that here because there's no way to determine
            // whether the cursor change came from code (i.e. this method) or user
            // interaction from cursor_changed().
            this.selected = null;
            item_selected (null);
        } else if (item.selectable) {
            if (scroll_to_item)
                this.scroll_to_item (item);

            var to_select = data_model.get_item_path (item);
            if (to_select != null)
                set_cursor_on_cell (to_select, get_column (Column.ITEM), text_cell, false);
        }
    }

    public override void cursor_changed () {
        var path = get_selected_path ();
        Item? new_item = path != null ? data_model.get_item_from_path (path) : null;

        // Don't do anything if @new_item is null.
        //
        // The only way 'this.selected' can be null is by setting it explicitly to
        // that value from client code, and thus we handle that case in set_selected().
        // THIS CANNOT HAPPEN IN RESPONSE TO USER INTERACTION. For example, if an
        // item is un-selected because its parent category has been collapsed, then it will
        // remain as the current selected item (not in reality, just as the value of
        // this.selected) and will be re-selected after the parent is expanded again.
        // THIS ALL HAPPENS SILENTLY BEHIND THE SCENES, so client code will never know
        // it ever happened; the value of selected_item remains unchanged and item_selected()
        // is not emitted.
        if (new_item != null && new_item != this.selected) {
            this.selected = new_item;
            item_selected (new_item);
        }
    }

    public bool scroll_to_item (Item item, bool use_align = false, float row_align = 0) {
        bool scrolled = false;

        var path = data_model.get_item_path (item);
        if (path != null) {
            scroll_to_cell (path, null, use_align, row_align, 0);
            scrolled = true;
        }

        return scrolled;
    }

    public bool start_editing_item (Item item) requires (item.editable) requires (item.selectable) {
        if (editing && item == edited) // If same item again, simply return.
            return false;

        var path = data_model.get_item_path (item);
        if (path != null) {
            edited = item;
            text_cell.editable = true;
            set_cursor_on_cell (path, get_column (Column.ITEM), text_cell, true);
        } else {
            warning ("Could not edit \"%s\": path not found", item.name);
        }

        return editing;
    }

    public void stop_editing () {
        if (editing && edited != null) {
            var path = data_model.get_item_path (edited);

            // Setting the cursor on the same cell without starting an edit cancels any
            // editing operation going on.
            if (path != null)
                set_cursor_on_cell (path, get_column (Column.ITEM), text_cell, false);
        }
    }

    private void on_editing_started (Gtk.CellEditable editable, string path) {
        editable_entry = editable as Gtk.Entry;
        if (editable_entry != null) {
            editable_entry.editing_done.connect (on_editing_done);
            editable_entry.editable = true;
        }
    }

    private void on_editing_canceled () {
        if (editable_entry != null) {
            editable_entry.editable = false;
            editable_entry.editing_done.disconnect (on_editing_done);
        }

        text_cell.editable = false;
        edited = null;
    }

    private void on_editing_done () {
        if (edited != null && edited.editable && editable_entry != null)
            edited.edited (editable_entry.get_text ());

        // Same actions as when canceling editing
        on_editing_canceled ();
    }

    private void on_activatable_activated (string item_path_str) {
        var item = get_item_from_path_string (item_path_str);
        if (item != null)
            item.action_activated ();
    }

    private Item? get_item_from_path_string (string item_path_str) {
        var item_path = new Gtk.TreePath.from_string (item_path_str);
        return data_model.get_item_from_path (item_path);
    }

    private bool toggle_expansion (ExpandableItem item) {
        if (item.collapsible) {
            item.expanded = !item.expanded;
            return true;
        }
        return false;
    }

    /**
     * Updates the tree to reflect the ''expanded'' property of expandable_item.
     */
    public void update_expansion (ExpandableItem expandable_item) {
        var path = data_model.get_item_path (expandable_item);

        if (path != null) {
            // Make sure that the indentation cell for the item's level exists.
            // We use +1 because the method will make sure that the previous
            // indentation levels exist too.
            add_spacer_cell_for_level (path.get_depth () + 1);

            if (expandable_item.expanded) {
                expand_row (path, false);

                // Since collapsing an item un-selects any child item previously selected,
                // we need to restore the selection. This will be done silently because
                // set_selected checks for equality between the previously "selected"
                // item and the newly selected, and only emits the item_selected() signal
                // if they are different. See cursor_changed() for a better explanation
                // of this behavior.
                if (selected != null && selected.parent == expandable_item)
                    set_selected (selected, true);

                // Collapsing expandable_item's row also collapsed all its children,
                // and thus we need to update the "expanded" property of each of them
                // to reflect their previous state.
                foreach (var child_item in expandable_item.children) {
                    var child_expandable_item = child_item as ExpandableItem;
                    if (child_expandable_item != null)
                        update_expansion (child_expandable_item);
                }
            } else {
                collapse_row (path);
            }
        }
    }

    public override void row_expanded (Gtk.TreeIter iter, Gtk.TreePath path) {
        var item = data_model.get_item (iter) as ExpandableItem;
        return_if_fail (item != null);

        disable_item_property_monitor ();
        item.expanded = true;
        enable_item_property_monitor ();
    }

    public override void row_collapsed (Gtk.TreeIter iter, Gtk.TreePath path) {
        var item = data_model.get_item (iter) as ExpandableItem;
        return_if_fail (item != null);

        disable_item_property_monitor ();
        item.expanded = false;
        enable_item_property_monitor ();
    }

    public override void row_activated (Gtk.TreePath path, Gtk.TreeViewColumn column) {
        if (column == get_column (Column.ITEM)) {
            var item = data_model.get_item_from_path (path);
            if (item != null)
                item.activated ();
        }
    }

    public bool on_key_release_event (uint keyval, uint keycode, Gdk.ModifierType state) {
       if (selected_item != null) {
            switch (event.keyval) {
                case Gdk.Key.F2:
                   var modifiers = Gtk.accelerator_get_default_mod_mask ();
                    // try to start editing selected item
                    if ((event.state & modifiers) == 0 && selected_item.editable)
                        start_editing_item (selected_item);
                break;
            }
        }

        return Gdk.EVENT_PROPAGATE;
        // return base.key_release_event (event);
    }

    public override bool button_release_event (Gdk.EventButton event) {
        if (unselectable_item_clicked && event.window == get_bin_window ()) {
            unselectable_item_clicked = false;

            Gtk.TreePath path;
            Gtk.TreeViewColumn column;
            int x = (int) event.x, y = (int) event.y, cell_x, cell_y;

            if (get_path_at_pos (x, y, out path, out column, out cell_x, out cell_y)) {
                var item = data_model.get_item_from_path (path) as ExpandableItem;

                if (item != null) {
                    if (!item.selectable || data_model.is_category (item, null, path))
                        toggle_expansion (item);
                }
            }
        }

        return base.button_release_event (event);
    }

    public override bool button_press_event (Gdk.EventButton event) {
        if (event.window != get_bin_window ())
            return base.button_press_event (event);

        Gtk.TreePath path;
        Gtk.TreeViewColumn column;
        int x = (int) event.x, y = (int) event.y, cell_x, cell_y;

        if (get_path_at_pos (x, y, out path, out column, out cell_x, out cell_y)) {
            var item = data_model.get_item_from_path (path);

            // This is needed because the treeview adds an offset at the beginning of every level
            Gdk.Rectangle start_cell_area;
            get_cell_area (path, get_column (0), out start_cell_area);
            cell_x -= start_cell_area.x;

            if (item != null && column == get_column (Column.ITEM)) {
                // Cancel any editing operation going on
                stop_editing ();

                if (event.button == Gdk.BUTTON_SECONDARY) {
                    popup_context_menu (item, event);
                    return true;
                } else if (event.button == Gdk.BUTTON_PRIMARY) {
                    // Check whether an expander (or an equivalent area) was clicked.
                    bool is_expandable = item is ExpandableItem;
                    bool is_category = is_expandable && data_model.is_category (item, null, path);

                    if (event.type == Gdk.EventType.BUTTON_PRESS) {
                        if (is_expandable) {
                            // Checking for secondary_expander_cell is not necessary because the entire row
                            // serves for this purpose when the item is a category or when the item is a
                            // normal expandable item that is not selectable (special care is taken to
                            // not break the activatable/action icons for such cases).
                            // The expander only works like a visual indicator for these items.
                            unselectable_item_clicked = is_category
                                || (!item.selectable && !over_cell (column, path, activatable_cell, cell_x));

                            if (!unselectable_item_clicked
                                && over_primary_expander (column, path, cell_x)
                                && toggle_expansion (item as ExpandableItem))
                                return true;
                        }
                    } else if (
                        event.type == Gdk.EventType.2BUTTON_PRESS
                        && !is_category // Main categories are *not* editable
                        && item.editable
                        && item.selectable
                        && over_cell (column, path, text_cell, cell_x)
                        && start_editing_item (item)
                    ) {
                        // The user double-clicked over the text cell, and editing started successfully.
                        return true;
                    }
                }
            }
        }

        return base.button_press_event (event);
    }

    private bool over_primary_expander (Gtk.TreeViewColumn col, Gtk.TreePath path, int x) {
        Gtk.TreeIter iter;
        if (!model.get_iter (out iter, path))
            return false;

        // Call the cell-data function and make it assign the proper visibility state to the cell
        expander_cell_data_func (col, primary_expander_cell, model, iter);

        if (!primary_expander_cell.visible)
            return false;

        // We want to return false if the cell is not expandable (i.e. the arrow is hidden)
        if (model.iter_n_children (iter) < 1)
            return false;

        // Now that we're sure that the item is expandable, let's see if the user clicked
        // over the expander area. We don't do so directly by querying the primary expander
        // position because it's not fixed, yielding incorrect coordinates depending on whether
        // a different area was re-drawn before this method was called. We know that the last
        // spacer cell precedes (in a LTR fashion) the expander cell. Because the position
        // of the spacer cell is fixed, we can safely query it.
        int indentation_level = path.get_depth ();
        var last_spacer_cell = spacer_cells[indentation_level];

        if (last_spacer_cell != null) {
            int cell_x, cell_width;

            if (col.cell_get_position (last_spacer_cell, out cell_x, out cell_width)) {
                // Add a pixel so that the expander area is a bit wider
                int expander_width = get_cell_width (primary_expander_cell) + 1;

                var dir = get_direction ();
                if (dir == Gtk.TextDirection.NONE) {
                    dir = Gtk.Widget.get_default_direction ();
                }

                if (dir == Gtk.TextDirection.LTR) {
                    int indentation_offset = cell_x + cell_width;
                    return x >= indentation_offset && x <= indentation_offset + expander_width;
                }

                return x <= cell_x && x >= cell_x - expander_width;
            }
        }

        return false;
    }

    private bool over_cell (Gtk.TreeViewColumn col, Gtk.TreePath path, Gtk.CellRenderer cell, int x) {
        int cell_x, cell_width;
        bool found = col.cell_get_position (cell, out cell_x, out cell_width);
        return found && x > cell_x && x < cell_x + cell_width;
    }

    private int get_cell_width (Gtk.CellRenderer cell_renderer) {
        Gtk.Requisition min_req;
        cell_renderer.get_preferred_size (this, out min_req, null);
        return min_req.width;
    }

    public override bool popup_menu () {
        return popup_context_menu (null, null);
    }

    private bool popup_context_menu (Item? item, Gdk.EventButton? event) {
        if (item == null)
            item = selected_item;

        if (item != null) {
            var menu = item.get_context_menu ();
            if (menu != null) {
                menu.attach_widget = this;
                menu.popup_at_pointer (event);
                if (event == null) {
                    menu.select_first (false);
                }

                return true;
            }
        }

        return false;
    }

    private static Item? get_item_from_model (Gtk.TreeModel model, Gtk.TreeIter iter) {
        var data_model = model as DataModel;
        assert (data_model != null);
        return data_model.get_item (iter);
    }

    private static void spacer_cell_data_func (
        Gtk.CellLayout layout,
        Gtk.CellRenderer renderer,
        Gtk.TreeModel model,
        Gtk.TreeIter iter
    ) {
        var spacer = renderer as CellRendererSpacer;
        assert (spacer != null);
        assert (spacer.level > 0);

        var path = model.get_path (iter);

        int level = -1;
        if (path != null)
            level = path.get_depth ();

        renderer.visible = spacer.level <= level;
    }

    private void name_cell_data_func (
        Gtk.CellLayout layout,
        Gtk.CellRenderer renderer,
        Gtk.TreeModel model,
        Gtk.TreeIter iter
    ) {
        var text_renderer = renderer as Gtk.CellRendererText;
        assert (text_renderer != null);

        var text = new StringBuilder ();
        var weight = Pango.Weight.NORMAL;
        bool use_markup = false;

        var item = get_item_from_model (model, iter);
        if (item != null) {
            if (item.markup != null) {
                text.append (item.markup);
                use_markup = true;
            } else {
                text.append (item.name);
            }

            if (data_model.is_category (item, iter))
                weight = Pango.Weight.BOLD;
        }

        text_renderer.weight = weight;
        if (use_markup) {
            text_renderer.markup = text.str;
        } else {
            text_renderer.text = text.str;
        }
    }

    private void badge_cell_data_func (
        Gtk.CellLayout layout,
        Gtk.CellRenderer renderer,
        Gtk.TreeModel model,
        Gtk.TreeIter iter
    ) {
        var badge_renderer = renderer as CellRendererBadge;
        assert (badge_renderer != null);

        string text = "";
        bool visible = false;

        var item = get_item_from_model (model, iter);
        if (item != null) {
            // Badges are not displayed for main categories
            visible = !data_model.is_category (item, iter)
                   && item.badge != null
                   && item.badge.strip () != "";

            if (visible)
                text = item.badge;
        }

        badge_renderer.visible = visible;
        badge_renderer.text = text;
    }

    private void icon_cell_data_func (
        Gtk.CellLayout layout,
        Gtk.CellRenderer renderer,
        Gtk.TreeModel model, Gtk.TreeIter iter
    ) {
        var icon_renderer = renderer as CellRendererIcon;
        assert (icon_renderer != null);

        bool visible = false;
        Icon? icon = null;

        var item = get_item_from_model (model, iter);
        if (item != null) {
            // Icons are not displayed for main categories
            visible = !data_model.is_category (item, iter);

            if (visible) {
                if (icon_renderer == icon_cell)
                    icon = item.icon;
                else if (icon_renderer == activatable_cell)
                    icon = item.activatable;
                else
                    assert_not_reached ();
            }
        }

        visible = visible && icon != null;

        icon_renderer.visible = visible;
        icon_renderer.gicon = visible ? icon : null;
    }

    /**
     * Controls expander visibility.
     */
    private void expander_cell_data_func (
        Gtk.CellLayout layout,
        Gtk.CellRenderer renderer,
        Gtk.TreeModel model,
        Gtk.TreeIter iter
    ) {
        var item = get_item_from_model (model, iter);
        if (item != null) {
            // Gtk.CellRenderer.is_expander takes into account whether the item has children or not.
            // The tree-view checks for that and sets this property for us. It also sets
            // Gtk.CellRenderer.is_expanded, and thus we don't need to check for that either.
            var expandable_item = item as ExpandableItem;
            if (expandable_item != null)
                renderer.is_expander = renderer.is_expander && expandable_item.collapsible;
        }

        if (renderer == primary_expander_cell)
            renderer.visible = !data_model.is_iter_at_root_level (iter);
        else if (renderer == secondary_expander_cell)
            renderer.visible = data_model.is_category (item, iter);
        else
            assert_not_reached ();
    }
}
}
