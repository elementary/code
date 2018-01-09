
public class ValaSymbolOutline : Object, SymbolOutline {
    public const string OUTLINE_RESOURCE_URI = "resource:///io/elementary/code/plugin/outline/";
    public Scratch.Services.Document doc { get; protected set; }
    public Granite.Widgets.SourceList store { get; private set; }
    Granite.Widgets.SourceList.ExpandableItem root;
    SymbolResolver resolver;
    Vala.Parser parser;
    GLib.Cancellable cancellable;

    public ValaSymbolOutline (Scratch.Services.Document _doc) {
        doc = _doc;
        doc.doc_saved.connect (() => {parse_symbols ();});
        doc.doc_closed.connect (doc_closed);

        store = new Granite.Widgets.SourceList ();
        store.item_selected.connect ((selected) => {
            goto (doc, (selected as SymbolItem).symbol.source_reference.begin.line);
        });

        root = new Granite.Widgets.SourceList.ExpandableItem (_("Symbols"));
        store.root.add (root);

        parser = new Vala.Parser ();
        resolver = new SymbolResolver ();
    }

    ~ValaSymbolOutline () {
        doc.doc_closed.disconnect (doc_closed);
    }

    void doc_closed (Scratch.Services.Document doc) {
        if (cancellable != null) {
            cancellable.cancel ();
            cancellable = null;
        }

        closed ();
    }

    public Granite.Widgets.SourceList get_source_list () {
        return store;
    }

    public void parse_symbols () {
        var context = new Vala.CodeContext ();
        context.profile = Vala.Profile.GOBJECT;
        context.add_source_filename (doc.file.get_path ());
        context.report = new Report ();
        if (cancellable != null)
            cancellable.cancel ();
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

    private Gee.TreeSet<SymbolItem> iterate_children (Granite.Widgets.SourceList.ExpandableItem parent) {
        var result = new Gee.TreeSet<SymbolItem> ();
        foreach (var child in parent.children) {
            result.add_all (iterate_children ((SymbolItem)child));
        }
        return result;
    }

    private SymbolItem construct_child (Vala.Symbol symbol, Granite.Widgets.SourceList.ExpandableItem given_parent, GLib.Cancellable cancellable) {
        Granite.Widgets.SourceList.ExpandableItem parent;
        if (symbol.scope.parent_scope.owner.name == null)
            parent = given_parent;
        else
            parent = find_existing (symbol.scope.parent_scope.owner, given_parent, cancellable);

        if (parent == null) {
            parent = construct_child (symbol.scope.parent_scope.owner, given_parent, cancellable);
        }

        var tree_child = new SymbolItem (symbol);
        if (symbol is Vala.Struct) {
            tree_child.icon = new ThemedIcon ("lang-struct");
        } else if (symbol is Vala.Class) {
            if (((Vala.Class) symbol).is_abstract) {
                tree_child.icon = new ThemedIcon ("lang-class-abstract");
            } else {
                tree_child.icon = new ThemedIcon ("lang-class");
            }
        } else if (symbol is Vala.Constant) {
            tree_child.icon = new ThemedIcon ("lang-constant");
        } else if (symbol is Vala.Enum) {
            tree_child.icon = new ThemedIcon ("lang-enum");
        } else if (symbol is Vala.Field) {
            tree_child.icon = new ThemedIcon ("lang-property");
        } else if (symbol is Vala.Interface) {
            tree_child.icon = new ThemedIcon ("lang-interface");
        } else if (symbol is Vala.Property) {
            if (((Vala.Property) symbol).is_abstract) {
                tree_child.icon = new ThemedIcon ("lang-property-abstract");
            } else if (((Vala.Property) symbol).is_virtual) {
                tree_child.icon = new ThemedIcon ("lang-property-virtual");
            } else {
                tree_child.icon = new ThemedIcon ("lang-property");
            }
        } else if (symbol is Vala.Signal) {
            tree_child.icon = new ThemedIcon ("lang-signal");
        } else if (symbol is Vala.CreationMethod) {
            tree_child.icon = new ThemedIcon ("lang-constructor");
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
        } else if (symbol is Vala.Namespace) {
            tree_child.icon = new ThemedIcon ("lang-namespace");
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

    SymbolItem? find_existing (Vala.Symbol symbol, Granite.Widgets.SourceList.ExpandableItem parent, GLib.Cancellable cancellable) {
        SymbolItem match = null;
        foreach (var _child in parent.children) {
            if (cancellable.is_cancelled ())
                break;

            var child = _child as SymbolItem;
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
