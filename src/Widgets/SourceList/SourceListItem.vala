/*
 * Copyright 2019 elementary, Inc. (https://elementary.io)
 * Copyright 2012-2014 Victor Martinez <victoreduardm@gmail.com>
 * SPDX-License-Identifier: LGPL-3.0-or-later
 */

namespace Code.Widgets.SourceList {
/**
 * A source list entry.
 *
 * Any change made to any of its properties will be ''automatically'' reflected
 * by the {@link Code.Widgets.SourceList} widget.
 *
 * @since 0.2
 */

public class Item : Object {

    /**
     * Emitted when the user has finished editing the item's name.
     *
     * By default, if the name doesn't consist of white space, it is automatically assigned
     * to the {@link Code.Widgets.SourceList.Item.name} property. The default behavior can
     * be changed by overriding this signal.
     * @param new_name The item's new name (result of editing.)
     * @since 0.2
     */
    public virtual signal void edited (string new_name) {
        if (editable && new_name.strip () != "")
            this.name = new_name;
    }

    /**
     * The {@link Code.Widgets.SourceList.Item.activatable} icon was activated.
     *
     * @see Code.Widgets.SourceList.Item.activatable
     * @since 0.2
     */
    public virtual signal void action_activated () { }

    /**
     * Emitted when the item is double-clicked or when it is selected and one of the keys:
     * Space, Shift+Space, Return or Enter is pressed. This signal is //also// for
     * editable items.
     *
     * @since 0.2
     */
    public virtual signal void activated () { }

    /**
     * Parent {@link Code.Widgets.SourceList.ExpandableItem} of the item.
     * ''Must not'' be modified.
     *
     * @since 0.2
     */
    public ExpandableItem parent { get; internal set; }

    /**
     * The item's name. Primary and most important information.
     *
     * @since 0.2
     */
    public string name { get; set; default = ""; }

    /**
     * The item's tooltip. If set to null (default), the tooltip for the item will be the
     * contents of the {@link Code.Widgets.SourceList.Item.name} property.
     *
     * @since 5.3
     */
    public string? tooltip { get; set; default = null; }

    /**
     * Markup to be used instead of {@link Code.Widgets.SourceList.ExpandableItem.name}
     * This would mean that &, <, etc have to be escaped in the text, but basic formatting
     * can be done on the item with HTML style tags.
     *
     * Note: Only the {@link Code.Widgets.SourceList.ExpandableItem.name} property
     * is modified for editable items. So this property will be need to updated and
     * reformatted with editable items.
     *
     * @since 5.0
     */
     public string? markup { get; set; default = null; }

    /**
     * A badge shown next to the item's name.
     *
     * It can be used for displaying the number of unread messages in the "Inbox" item,
     * for instance.
     *
     * @since 0.2
     */
    public string badge { get; set; default = ""; }

    /**
     * Whether the item's name can be edited from within the source list.
     *
     * When this property is set to //true//, users can edit the item by pressing
     * the F2 key, or by double-clicking its name.
     *
     * ''This property only works for selectable items''.
     *
     * @see Code.Widgets.SourceList.Item.selectable
     * @see Code.Widgets.SourceList.start_editing_item
     * @since 0.2
     */
    public bool editable { get; set; default = false; }

    /**
     * Whether the item should appear in the source list's tree or not.
     *
     * @since 0.2
     */
    public bool visible { get; set; default = true; }

    /**
     * Whether the item can be selected or not.
     *
     * Setting this property to true doesn't guarantee that the item will actually be
     * selectable, since there are other external factors to take into account, like the
     * item's {@link Code.Widgets.SourceList.Item.visible} property; whether the item is
     * a category; the parent item is collapsed, etc.
     *
     * @see Code.Widgets.SourceList.Item.visible
     * @since 0.2
     */
    public bool selectable { get; set; default = true; }

    /**
     * Primary icon.
     *
     * This property should be used to give the user an idea of what the item represents
     * (i.e. content type.)
     *
     * @since 0.2
     */
    public Icon icon { get; set; }

    /**
     * An activatable icon that works like a button.
     *
     * It can be used for e.g. showing an //"eject"// icon on a device's item.
     *
     * @see Code.Widgets.SourceList.Item.action_activated
     * @since 0.2
     */
    public Icon activatable { get; set; }

    /**
     * The tooltip for the activatable icon.
     *
     * @since 5.0
     */
    public string activatable_tooltip { get; set; default = ""; }

    /**
     * Creates a new {@link Code.Widgets.SourceList.Item}.
     *
     * @param name Name of the item.
     * @return (transfer full) A new {@link Code.Widgets.SourceList.Item}.
     * @since 0.2
     */
    public Item (string name = "") {
        this.name = name;
    }

    /**
     * Invoked when the item is secondary-clicked or when the usual menu keys are pressed.
     *
     * Note that since Granite 5.0, right clicking on an item no longer selects/activates it, so
     * any context menu items should be actioned on the item instance rather than the selected item
     * in the SourceList
     *
     * @return A {@link Gtk.Menu} or //null// if nothing should be displayed.
     * @since 0.2
     */
    public virtual GLib.Menu? get_context_menu () {
        return null;
    }
}
}
