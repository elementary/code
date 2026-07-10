/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 20126 elementary, Inc. <https://elementary.io>
 */

public class Code.TreeList : Gtk.Box {
    private Gtk.ListView list_view;
    protected GLib.ListStore root_model;
    private Gtk.TreeListModel tree_model;
    protected Gtk.SelectionModel selection_model;

    construct {
        root_model = new GLib.ListStore (typeof (TreeListItem));
        tree_model = new Gtk.TreeListModel (root_model, false, false, create_model_func);
        selection_model = new Gtk.SingleSelection (tree_model);
        var tree_list_factory = new Gtk.SignalListItemFactory ();
        var tree_header_factory = new Gtk.SignalListItemFactory ();
        list_view = new Gtk.ListView (selection_model, tree_list_factory) {
            header_factory = tree_header_factory
        };

         // LIST ITEM FACTORY HANDLERS
        tree_list_factory.setup.connect ((obj) => {
           var row = (Gtk.ListItem) obj;
           var label = new Gtk.Label ("") {
               halign = START
           };
           label.add_css_class (Granite.STYLE_CLASS_H4_LABEL);
           var expander = new Gtk.TreeExpander () {
               child = label,
               use_markup = true
           };
           row.child = expander;
           //TODO Show icon, secondary icon and badge
       });

        tree_list_factory.bind.connect ((obj) => {
            var row = (Gtk.ListItem) obj;
            var treelistrow = (Gtk.TreeListRow) (row.get_item ());
            var data = (Code.TreeListItem) (treelistrow.get_item ());
            var expander = (Gtk.TreeExpander) (row.get_child ());
            var label = (Gtk.Label) (expander.get_child ());
            label.label = data.text;
            // expander.hide_expander = !data.expandable;
            expander.set_list_row (treelistrow);
            row.activatable = data.is_activatable;
            // Is there a better way
            data.expanded_binding = data.bind_property (
                "is_expanded",
                treelistrow, "expanded",
                BIDIRECTIONAL | SYNC_CREATE
            );
       });

       tree_list_factory.unbind.connect ((obj) => {
           var row = (Gtk.ListItem) obj;
           var treelistrow = (Gtk.TreeListRow) (row.get_item ());
           var data = (Code.TreeListItem) (treelistrow.get_item ());
           data.expanded_binding.unbind ();
       });
       tree_list_factory.teardown.connect (() => {});

       // HEADER FACTORY HANDLERS
       tree_header_factory.setup.connect ((obj) => {
           var row = (Gtk.ListItem) obj;
           var text_label = new Gtk.Label ("") {
               halign = START,
           };
           text_label.add_css_class (Granite.STYLE_CLASS_H3_LABEL);
           var subtext_label = new Gtk.Label ("") {
               halign = START
           };
           subtext_label.add_css_class (Granite.STYLE_CLASS_SMALL_LABEL);
           var box = new Gtk.Box (VERTICAL, 0);
           box.append (text_label);
           box.append (subtext_label);
           var expander = new Gtk.TreeExpander () {
               child = box,
           };
           row.child = expander;
       });

       tree_header_factory.bind.connect ((obj) => {
           var row = (Gtk.ListItem) obj;
           var data = (Code.TreeListItem) (row.get_item ());
           var expander = (Gtk.TreeExpander) (row.get_child ());
           var box = (Gtk.Box) (expander.get_child ());
           var text_label = (Gtk.Label) (box.get_first_child ());
           var subtext_label = (Gtk.Label) (text_label.get_next_sibling ());
           text_label.label = data.text;
           subtext_label.label = data.sub_text;
           expander.hide_expander = false;
       });
       tree_header_factory.unbind.connect (() => {});
       tree_header_factory.teardown.connect (() => {});

       append (list_view);
    }

    public ListModel? create_model_func (Object item) {
        var data = (TreeListItem) item;
        if (data.is_expandable && data.child_model == null) {
            data.child_model = new GLib.ListStore (typeof (TreeListItem));
        }

        return data.child_model;
    }

    // Root items must generally be expandable
    public TreeListItem add_root_item (
        TreeListItem item
    ) {
        root_model.append (item);
        return item;
    }
    // // Root items must generally be expandable
    // public TreeListItem create_root_item (
    //     string text,
    //     bool expandable = true
    // ) {
    //     TreeListItem item;
    //     if (expandable) {
    //         item = new TreeListItem.expandable ();
    //     } else {
    //         item = new TreeListItem ();
    //     }

    //     root_model.append (item);
    //     return item;
    // }

    public void remove_root_item (TreeListItem item) {
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

        item.destroy (); // Do we need this?
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
    public bool iterate_children (TreeListItem?  start, ListIteratorCallback cb) {
        ListModel model;
        if (start == null) {
            model = root_model;
        } else {
            model = start.child_model;
        }

        TreeListItem? item;
        uint pos = 0;
        do {
            item = (TreeListItem?) (model.get_object (pos++));
        } while (item != null && cb (item));
    }
 }
