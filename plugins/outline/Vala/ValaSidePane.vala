/*-
 * Copyright (c) 2017-2018 elementary LLC. (https://elementary.io)
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Authored by: Corentin Noël <corentin@elementary.io>
 */

public class Code.Plugins.Outline.ValaSidePane : Code.Plugins.Outline.SidePane {
    private Granite.Widgets.SourceList.ExpandableItem root;
    private Outline.ValaSymbolResolver resolver;
    private Vala.Parser parser;
    private GLib.Cancellable cancellable;

    public ValaSidePane (Scratch.Services.Document doc) {
        Object (doc: doc);
    }

    construct {
        parser = new Vala.Parser ();
        resolver = new Outline.ValaSymbolResolver ();

        root = new Granite.Widgets.SourceList.ExpandableItem (_("Symbols"));
        store.root.add (root);

        fetching = true;
        parse_symbols ();
        doc.doc_saved.connect (() => parse_symbols ());
        doc.doc_closed.connect (doc_closed);
    }

    void doc_closed (Scratch.Services.Document doc) {
        if (cancellable != null) {
            cancellable.cancel ();
            cancellable = null;
        }
    }

    public void parse_symbols () {
        var context = new Vala.CodeContext ();
        context.profile = Vala.Profile.GOBJECT;
        context.add_source_filename (doc.file.get_path ());
        context.report = new Report ();
        if (cancellable != null) {
            cancellable.cancel ();
        }

        cancellable = new GLib.Cancellable ();
        new Thread<void*>("parse-symbols", () => {
            Vala.CodeContext.push (context);
            parser.parse (context);
            resolver.clear ();
            resolver.resolve (context);
            Vala.CodeContext.pop ();

            var new_root = construct_tree (cancellable);
            if (cancellable.is_cancelled () == false) {
                Idle.add (() => {
                    double adjustment_value = store.vadjustment.value;
                    store.root.clear ();
                    store.root.add (new_root);
                    store.root.expand_all ();
                    store.vadjustment.set_value (adjustment_value);

                    destroy_root (root);
                    root = new_root;
                    fetching = false;

                    return false;
                });
            } else {
                destroy_root (new_root);
            }
            return null;
        });
    }

    private void destroy_root (Granite.Widgets.SourceList.ExpandableItem to_destroy) {
        var children = iterate_children (to_destroy);
        to_destroy.clear ();
        foreach (var item in children) {
            item.clear ();
            var parent = item.parent;
            if (parent != null) {
                parent.remove (item);
            }
        }
    }

    private Granite.Widgets.SourceList.ExpandableItem construct_tree (GLib.Cancellable cancellable) {
        var fields = resolver.get_properties_fields ();
        var symbols = resolver.get_symbols ();
        // Remove fake fields created by the vala parser.
        symbols.remove_all (fields);

        var new_root = new Granite.Widgets.SourceList.ExpandableItem (_("Symbols"));
        foreach (var symbol in symbols) {
            if (cancellable.is_cancelled ())
                break;

            var exist = find_existing (symbol, new_root, cancellable);
            if (exist != null)
                continue;

            if (symbol.name == null)
                continue;

            construct_child (symbol, new_root, cancellable);
        }
        return new_root;
    }

    private Gee.TreeSet<Outline.ValaSymbolItem> iterate_children (Granite.Widgets.SourceList.ExpandableItem parent) {
        var result = new Gee.TreeSet<Outline.ValaSymbolItem> ();
        foreach (var child in parent.children) {
            result.add_all (iterate_children ((Outline.ValaSymbolItem)child));
        }
        return result;
    }

    private Outline.ValaSymbolItem construct_child (Vala.Symbol symbol, Granite.Widgets.SourceList.ExpandableItem given_parent, GLib.Cancellable cancellable) {
        Granite.Widgets.SourceList.ExpandableItem parent;
        if (symbol.scope.parent_scope.owner.name == null)
            parent = given_parent;
        else
            parent = find_existing (symbol.scope.parent_scope.owner, given_parent, cancellable);

        if (parent == null) {
            parent = construct_child (symbol.scope.parent_scope.owner, given_parent, cancellable);
        }

        var tree_child = new Outline.ValaSymbolItem (symbol);
        parent.add (tree_child);
        return tree_child;
    }

    Outline.ValaSymbolItem? find_existing (Vala.Symbol symbol, Granite.Widgets.SourceList.ExpandableItem parent, GLib.Cancellable cancellable) {
        Outline.ValaSymbolItem match = null;
        foreach (var _child in parent.children) {
            if (cancellable.is_cancelled ())
                break;

            var child = _child as Outline.ValaSymbolItem;
            if (child == null)
                continue;

            if (child.symbol == symbol) {
                match = child;
                break;
            } else {
                var res = find_existing (symbol, child, cancellable);
                if (res != null)
                    return res;
            }
        }

        return match;
    }

    public class Report : Vala.Report {
        // just mute everything
        public override void err (Vala.SourceReference? ref, string msg) {}
        public override void warn (Vala.SourceReference? ref, string msg) {}
        public override void note (Vala.SourceReference? ref, string msg) {}
        public override void depr (Vala.SourceReference? ref, string msg) {}
    }
}
