/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 20126 elementary, Inc. <https://elementary.io>
 */

public sealed class Code.TreeList : Granite.Bin {

    public signal void item_activated (TreeListItem item);

    // public Gtk.Adjustment vadjustment {
    //     get {
    //         return scrolled_window.vadjustment;
    //     }
    // }

    public bool activate_on_single_click { get; set; default = true;}

    // public TreeListItem? selected { get; set; } // Selection handled by SelectionModel

    // private Gtk.ScrolledWindow scrolled_window;
    private Gtk.ListView list_view;
    private GLib.ListStore root_model;
    private Gtk.TreeListModel tree_model;
    private Gtk.SingleSelection selection_model;

    construct {
        root_model = new GLib.ListStore (typeof (TreeListItem));
        // Passthrough false (create Gtk.TreeListRows), autoexpand false
        tree_model = new Gtk.TreeListModel (root_model, false, false, create_model_func);
        selection_model = new Gtk.SingleSelection (tree_model);
        selection_model.sections_changed.connect ((pos, n_items) => {
            warning ("sections changed pos %u, n items %u", pos, n_items);
        });
        var tree_list_factory = new Gtk.SignalListItemFactory ();
        // var tree_header_factory = new Gtk.SignalListItemFactory ();
        // list_view = new Gtk.ListView (selection_model, tree_list_factory) {
        //     header_factory = tree_header_factory
        // };
        list_view = new Gtk.ListView (selection_model, tree_list_factory);
        list_view.add_css_class ("compact");

        bind_property ("activate-on-single-click", list_view, "single-click-activate", BIDIRECTIONAL | SYNC_CREATE);
        list_view.activate.connect ((pos) => {
        warning ("list view activate %u", pos);
            var tree_row = ((Gtk.TreeListRow) selection_model.get_item (pos));
            var data = (Code.TreeListItem) (tree_row.item);
             //Always activate regardless of whether expandable - symbol pane works differently to foldermanager
            item_activated (data);
        });
         // LIST ITEM FACTORY HANDLERS
        tree_list_factory.setup.connect ((obj) => {
            var listitem = (Gtk.ListItem) obj;
            create_listitem_child (listitem);
           // By default just create a use a label (not expandable)
        });
        tree_list_factory.teardown.connect ((obj) => {
            var listitem = (Gtk.ListItem) obj;
            teardown_listitem_child (listitem);
        });
        tree_list_factory.bind.connect ((obj) => {
            var listitem = (Gtk.ListItem) obj;
            var treelistrow = (Gtk.TreeListRow) (listitem.get_item ());
            var data = (Code.TreeListItem) (treelistrow.get_item ());
            bind_data_to_row (data, treelistrow, listitem);
        });
        tree_list_factory.unbind.connect ((obj) => {
            var listitem = (Gtk.ListItem) obj;
            var treelistrow = (Gtk.TreeListRow) (listitem.item);
            var data = (Code.TreeListItem) (treelistrow.item);
            unbind_data_from_row (data, treelistrow, listitem);
        });

       child = list_view;
    }

    protected virtual void create_listitem_child (Gtk.ListItem item) {
        var label = new Gtk.Label ("") {
           halign = START,
           hexpand = true
        };
        // label.add_css_class (Granite.STYLE_CLASS_H4_LABEL);
        label.add_css_class (Granite.STYLE_CLASS_SMALL_LABEL);
        var primary_image = new Gtk.Image.from_icon_name (null);
        var secondary_image = new Gtk.Image.from_icon_name (null);
        var badge_label = new Gtk.Label ("");
        badge_label.add_css_class (Granite.STYLE_CLASS_MENUITEM);
        var box = new Gtk.Box (HORIZONTAL, 6) {
            hexpand = true
        };
        box.append (primary_image);
        box.append (label);
        box.append (secondary_image);
        box.append (badge_label);
        badge_label.add_css_class (Granite.STYLE_CLASS_SMALL_LABEL);
        var expander = new Gtk.TreeExpander () {
            child = box
        };

        item.child = expander;
    }
    protected virtual void teardown_listitem_child (Gtk.ListItem item) {
        // Must be paired with create_listitem child
    }
    protected virtual void bind_data_to_row (
        TreeListItem data,
        Gtk.TreeListRow row,
        Gtk.ListItem item) {
        // Must be matched with create item widget when overriding
        var expander = (Gtk.TreeExpander) (item.child);
        expander.set_list_row (row);
        expander.hide_expander = !data.is_expandable;
        data.expanded_binding = data.bind_property ("is-expanded", row, "expanded", BIDIRECTIONAL | SYNC_CREATE);
        var box = (Gtk.Box)(expander.child); //TODO use expander?
        var primary_image = (Gtk.Image)(box.get_first_child ());
        var name_label = (Gtk.Label)(primary_image.get_next_sibling ());
        var secondary_image = (Gtk.Image) (name_label.get_next_sibling ());
        var badge_label = (Gtk.Label) secondary_image.get_next_sibling ();
        primary_image.icon_name = data.is_expandable ? "folder" : "text-x-vala"; //TODO Icon based on file type
        secondary_image.icon_name = "emblem-default"; //TODO Different icon
        badge_label.label = "32"; //TODO Different icon
        name_label.label = data.text;
    }
    protected virtual void unbind_data_from_row (
        TreeListItem data,
        Gtk.TreeListRow row,
        Gtk.ListItem item
    ) {
        //Must undo any signal connections etc made in bind_data_to_row
        data.expanded_binding.unbind ();
    }

    public ListModel? create_model_func (Object item) {
        var data = (TreeListItem) item;
        if (data.is_expandable && data.child_model == null) {
            warning ("data %s is expandable and no model", data.text);
            data.child_model = new GLib.ListStore (typeof (TreeListItem));
        }

        return data.child_model;
    }

    // protected virtual void create_headeritem_child (Gtk.ListHeader item) {
    //     warning ("create headeritem child pos");
    //    var text_label = new Gtk.Label ("") {
    //        halign = START,
    //    };
    //    text_label.add_css_class (Granite.STYLE_CLASS_H3_LABEL);
    //    var subtext_label = new Gtk.Label ("") {
    //        halign = START
    //    };
    //    subtext_label.add_css_class (Granite.STYLE_CLASS_SMALL_LABEL);
    //    var box = new Gtk.Box (VERTICAL, 0);
    //    box.append (text_label);
    //    box.append (subtext_label);
    //    var expander = new Gtk.TreeExpander () {
    //        child = box,
    //    };
    //    item.child = expander;
    // }
    // protected virtual void teardown_headeritem_child () {
    //     // Must be paired with create_listitem child
    // }
    // protected virtual void bind_data_to_header (
    //     TreeListItem data,
    //     Gtk.TreeListRow row,
    //     Gtk.ListHeader item
    //  ) {

    //     var expander = (Gtk.TreeExpander) item.child;
    //     var box = (Gtk.Box) expander.get_child ();
    //     var text_label = (Gtk.Label) box.get_first_child ();
    //     var subtext_label = (Gtk.Label) text_label.get_next_sibling ();
    //     text_label.label = data.text;
    //     subtext_label.label = data.sub_text;
    //  warning ("bind data to header %s", text_label.label);
    // }

    // protected virtual void unbind_data_from_headerrow (
    //     TreeListItem data,
    //     Gtk.TreeListRow row,
    //     Gtk.ListItem item
    // ) {
    //     //Must undo any signal connections etc made in bind_data_to_row
    // }

    // Root items must generally be expandable
    public TreeListItem add_root_item (
        TreeListItem item
    ) {
        root_model.append (item);
        return item;
    }

    public void remove_root_item (TreeListItem item) {
        uint pos;
        if (root_model.find (item, out pos)) {
            root_model.remove (pos);
        }
    }

    public void remove_root_children (List<TreeListItem> to_remove) {
        foreach (TreeListItem item in to_remove) {
            uint pos;
            if (root_model.find (item, out pos)) {
                root_model.remove (pos);
            }
        }
    }

    public void remove_all () {
        root_model.remove_all ();
    }

    public void sort_root_children (CompareDataFunc sort_func) {
        root_model.sort (sort_func);
    }

    public uint n_root_items () {
        return root_model.get_n_items ();
    }

    public delegate bool ListIteratorCallback (TreeListItem item);
    public static bool ITERATE_CONTINUE = true;
    public static bool ITERATE_STOP = false;
    public void iterate_children (TreeListItem?  start, ListIteratorCallback cb) {
        ListModel model;
        if (start == null) {
            model = root_model;
        } else {
            model = start.child_model;
        }

        TreeListItem? item = null;
        uint pos = 0;
        do {
            item = (TreeListItem?) (model.get_object (pos++));
        } while (item != null && cb (item));
    }

    public void expand_all (TreeListItem? start) {
        iterate_children (start, expand_callback);
    }

    public void unselect_all () {
        selection_model.unselect_all ();
    }

    private bool expand_callback (TreeListItem item) {
        if (item.is_expandable) {
            iterate_children (item, expand_callback);
        }

        return TreeList.ITERATE_CONTINUE;
    }
 }
