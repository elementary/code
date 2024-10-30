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
 */

public class Scratch.Services.ValaSymbolOutline : Scratch.Services.SymbolOutline {
    private GLib.Cancellable cancellable;
    private GLib.Thread<void*> current_thread;
    public ValaSymbolOutline (Scratch.Services.Document _doc) {
        Object (
            orientation: Gtk.Orientation.VERTICAL,
            hexpand: true,
            doc: _doc
        );
    }

    static construct {
        // Array of symbol types that could be assigned to a ValaSymbolItem
        // by construct_child output ()
        filters = {
            SymbolType.CLASS,
            SymbolType.CONSTRUCTOR,
            SymbolType.PROPERTY,
            SymbolType.METHOD,
            SymbolType.STRUCT,
            SymbolType.ENUM,
            SymbolType.CONSTANT,
            SymbolType.INTERFACE
        };
    }

    construct {
        store.item_selected.connect ((selected) => {
            doc.goto (((ValaSymbolItem)selected).symbol.source_reference.begin.line);
        });

        doc.doc_closed.connect (doc_closed);
    }

    ~ValaSymbolOutline () {
        debug ("Destruct ValaSymbolOutline");
    }

    void doc_closed (Scratch.Services.Document doc) {
        doc.doc_closed.disconnect (doc_closed);
        cancel ();
    }

    private void cancel () {
        if (cancellable != null && !cancellable.is_cancelled ()) {
            cancellable.cancel ();
        }

        cancellable = null;
    }

    public override void parse_symbols () {
        cancel ();
        if (current_thread != null) {
            warning ("THREAD NOT FINISHED");
            // TODO Show something in symbol pane to indicate parser stalled
            // TODO Provide a way of resetting parser
            return;
        }

        cancellable = new GLib.Cancellable ();
warning ("parse vala symbols in %s", doc.file.get_basename ());
        current_thread = new Thread<void*> ("parse-symbols", () => {
            var context = new Vala.CodeContext ();
    #if VALA_0_50
            context.set_target_profile (Vala.Profile.GOBJECT, false);
    #else
            context.profile = Vala.Profile.GOBJECT;
    #endif
            context.add_source_filename (doc.file.get_path ());
            context.report = new Report ();

            Vala.CodeContext.push (context);

            var parser = new Vala.Parser ();
            var resolver = new Code.Plugins.ValaSymbolResolver ();

            parser.parse (context);

            resolver.resolve (context);
            Vala.CodeContext.pop ();

            var new_root = construct_tree (resolver, cancellable);
            if (!cancellable.is_cancelled ()) {
                cancellable = null;
                Idle.add (() => {
                    double adjustment_value = store.vadjustment.value;
                    var root_children = store.root.children; // Keep reference to children for later destruction
                    store.root.clear (); // This does not destroy children but disconnects signals - avoids terminal warnings
                    foreach (var child in root_children) { // Destroy items after clearing list to avoid memory leak
                        destroy_all_children ((Code.Widgets.SourceList.ExpandableItem)child);
                    }

                    store.root.add (new_root);
                    store.root.expand_all ();
                    store.vadjustment.set_value (adjustment_value);

                    return false;
                });
            } else {
                destroy_all_children (new_root);
            }

            current_thread = null;
            return null;
        });
    }

    private void destroy_all_children (Code.Widgets.SourceList.ExpandableItem parent) {
        foreach (var child in parent.children) {
            remove (child, parent);
        }
    }

    private new void remove (Code.Widgets.SourceList.Item item, Code.Widgets.SourceList.ExpandableItem parent) {
        if (item is Code.Widgets.SourceList.ExpandableItem) {
            destroy_all_children ((Code.Widgets.SourceList.ExpandableItem)item);
        }

        parent.remove (item);
    }

    private Code.Widgets.SourceList.ExpandableItem construct_tree (
        Code.Plugins.ValaSymbolResolver resolver,
        GLib.Cancellable cancellable
    ) {
        var fields = resolver.get_properties_fields ();
        var symbols = resolver.get_symbols ();
        // Remove fake fields created by the vala parser.
        symbols.remove_all (fields);

        var new_root = new Code.Widgets.SourceList.ExpandableItem (_("Symbols"));
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

    private ValaSymbolItem construct_child (Vala.Symbol symbol, Code.Widgets.SourceList.ExpandableItem given_parent, GLib.Cancellable cancellable) {
        Code.Widgets.SourceList.ExpandableItem parent;
        if (symbol.scope.parent_scope.owner.name == null)
            parent = given_parent;
        else
            parent = find_existing (symbol.scope.parent_scope.owner, given_parent, cancellable);

        if (parent == null) {
            parent = construct_child (symbol.scope.parent_scope.owner, given_parent, cancellable);
        }

        var tree_child = new ValaSymbolItem (symbol);
        if (symbol is Vala.Struct) {
            tree_child.icon = new ThemedIcon ("lang-struct");
            tree_child.symbol_type = SymbolType.STRUCT;
        } else if (symbol is Vala.Class) {
            if (((Vala.Class) symbol).is_abstract) {
                tree_child.icon = new ThemedIcon ("lang-class-abstract");
            } else {
                tree_child.icon = new ThemedIcon ("lang-class");
            }

            tree_child.symbol_type = SymbolType.CLASS;
        } else if (symbol is Vala.Constant) {
            tree_child.icon = new ThemedIcon ("lang-constant");
            tree_child.symbol_type = SymbolType.CONSTANT;
        } else if (symbol is Vala.Enum) {
            tree_child.icon = new ThemedIcon ("lang-enum");
            tree_child.symbol_type = SymbolType.ENUM;
        } else if (symbol is Vala.Field) {
            tree_child.icon = new ThemedIcon ("lang-property");
            tree_child.symbol_type = SymbolType.PROPERTY;
        } else if (symbol is Vala.Interface) {
            tree_child.icon = new ThemedIcon ("lang-interface");
            tree_child.symbol_type = SymbolType.INTERFACE;
        } else if (symbol is Vala.Property) {
            if (((Vala.Property) symbol).is_abstract) {
                tree_child.icon = new ThemedIcon ("lang-property-abstract");
            } else if (((Vala.Property) symbol).is_virtual) {
                tree_child.icon = new ThemedIcon ("lang-property-virtual");
            } else {
                tree_child.icon = new ThemedIcon ("lang-property");
            }

            tree_child.symbol_type = SymbolType.PROPERTY;
        } else if (symbol is Vala.Signal) {
            tree_child.icon = new ThemedIcon ("lang-signal");
            tree_child.symbol_type = SymbolType.SIGNAL;
        } else if (symbol is Vala.CreationMethod) {
            tree_child.icon = new ThemedIcon ("lang-constructor");
            tree_child.symbol_type = SymbolType.CONSTRUCTOR;
        } else if (symbol is Vala.Method) {
            if (((Vala.Method) symbol).is_abstract) {
                tree_child.icon = new ThemedIcon ("lang-method-abstract");
            } else if (((Vala.Method) symbol).is_virtual) {
                tree_child.icon = new ThemedIcon ("lang-method-virtual");
            } else if (((Vala.Method) symbol).binding == Vala.MemberBinding.STATIC) {
                tree_child.icon = new ThemedIcon ("lang-method-static");
            } else {
                tree_child.icon = new ThemedIcon ("lang-method");
            }

            tree_child.symbol_type = SymbolType.METHOD;
        } else if (symbol is Vala.Namespace) {
            tree_child.icon = new ThemedIcon ("lang-namespace");
            tree_child.symbol_type = SymbolType.NAMESPACE;
        } else if (symbol is Vala.ErrorDomain) {
            tree_child.icon = new ThemedIcon ("lang-errordomain");
        } else if (symbol is Vala.Delegate) {
            tree_child.icon = new ThemedIcon ("lang-delegate");
        } else {
            warning (symbol.type_name);
        }

        parent.add (tree_child);
        return tree_child;
    }

    ValaSymbolItem? find_existing (Vala.Symbol symbol, Code.Widgets.SourceList.ExpandableItem parent, GLib.Cancellable cancellable) {
        ValaSymbolItem match = null;
        foreach (var _child in parent.children) {
            if (cancellable.is_cancelled ())
                break;

            var child = _child as ValaSymbolItem;
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
}

public class Report : Vala.Report {
    // just mute everything
    public override void err (Vala.SourceReference? ref, string msg) {}
    public override void warn (Vala.SourceReference? ref, string msg) {}
    public override void note (Vala.SourceReference? ref, string msg) {}
    public override void depr (Vala.SourceReference? ref, string msg) {}
}
