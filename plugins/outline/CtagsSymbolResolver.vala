
public class CtagsSymbol : Granite.Widgets.SourceList.ExpandableItem {
    public Scratch.Services.Document doc { get; construct set; }
    public int line { get; construct set; }

    public CtagsSymbol (Scratch.Services.Document doc, string name, int line, Icon? _icon) {
        Object (doc: doc, name: name, line: line);
        icon = _icon;
    }
}

class CtagsSymbolIter : Object {
    public string name { get; construct set; }
    public string parent { get; construct set; }
    public int line { get; construct set; }
    public Icon icon { get; construct set; }

    public CtagsSymbolIter (string name, string parent, int line, Icon icon) {
        Object(name: name, parent: parent, line: line, icon: icon);
    }
}

public class CtagsSymbolOutline : Object, SymbolOutline {
    public const string OUTLINE_RESOURCE_URI = "resource:///org/pantheon/scratch/plugin/outline/";
    public Scratch.Services.Document doc { get; protected set; }
    Granite.Widgets.SourceList store;
    Granite.Widgets.SourceList.ExpandableItem root;
    GLib.Cancellable cancellable;

    public CtagsSymbolOutline (Scratch.Services.Document _doc) {
        doc = _doc;
        doc.doc_saved.connect (() => {parse_symbols ();});
        doc.doc_closed.connect (doc_closed);

        root = new Granite.Widgets.SourceList.ExpandableItem (_("Symbols"));

        store = new Granite.Widgets.SourceList ();
        store.root.add (root);
        store.item_selected.connect ((selected) => {
            if (selected == null) return;
            goto (doc, (selected as CtagsSymbol).line);
            store.selected = null;
        });
    }

    ~CtagsSymbolOutline () {
        doc.doc_closed.disconnect (doc_closed);
    }

    void doc_closed (Scratch.Services.Document doc) {
        closed ();
    }

    public void parse_symbols () {
        if (cancellable != null)
            cancellable.cancel ();
        cancellable = new GLib.Cancellable ();
        var command = new Granite.Services.SimpleCommand (Environment.get_home_dir (),
            "/usr/bin/ctags -f - --format=2 --excmd=n --fields=nsK --extra= "+
            "--sort=no " + doc.file.get_path ());
        command.done.connect ((command, status) => {parse_output (command, status, cancellable);});
        command.run ();
    }

    void parse_output (Granite.Services.SimpleCommand command, int status, GLib.Cancellable _cancellable) {
        new Thread<void*>("parse-symbols", () => {
            var parent_dependent = new Gee.LinkedList<CtagsSymbolIter> ();
            var new_root = new Granite.Widgets.SourceList.ExpandableItem (_("Symbols"));

            if (status != 0)
                error ("Ctags failed\n");

            var symbols = command.standard_output_str.split ("\n");
            foreach (var symbol in symbols) {
                if (symbol == "")
                    continue;

                var parts = symbol.split ("\t");
                var name = parts[0];
                // 1 => filename
                // 2 => line number with weird trailing chars
                var type = parts[3];
                int line = 0;
                string? parent = null;
                parse_fields (string.joinv (" ", parts[4:parts.length]), out line, out parent);

                Icon? icon = null;
                switch (type) {
                    case "class":
                        icon = new FileIcon (File.new_for_uri (OUTLINE_RESOURCE_URI + "class-symbolic.svg"));
                        break;
                    case "struct":
                        icon = new FileIcon (File.new_for_uri (OUTLINE_RESOURCE_URI + "structure-symbolic.svg"));
                        break;
                    case "field":
                    case "enumerator":
                    case "member":
                    case "variable":
                        icon = new FileIcon (File.new_for_uri (OUTLINE_RESOURCE_URI + "field-symbolic.svg"));
                        break;
                    case "enum":
                        icon = new FileIcon (File.new_for_uri (OUTLINE_RESOURCE_URI + "enum-symbolic.svg"));
                        break;
                    case "macro":
                    case "constant":
                    case "typedef":
                        icon = new FileIcon (File.new_for_uri (OUTLINE_RESOURCE_URI + "constant-symbolic.svg"));
                        break;
                    case "constructor":
                    case "destructor":
                    case "method":
                    case "function":
                    case "namespace":
                    case "package":
                        break;
                    case "property":
                        icon = new FileIcon (File.new_for_uri (OUTLINE_RESOURCE_URI + "property-symbolic.svg"));
                        break;
                }

                if (parent == null) {
                    var s = new CtagsSymbol (doc, name, line, icon);
                    new_root.add (s);
                } else
                    parent_dependent.add (new CtagsSymbolIter (name, parent, line, icon));
            }

            var found_something = true;
            while (found_something && parent_dependent.size > 0) {
                found_something = false;
                var iter = parent_dependent.iterator ();
                while (iter.has_next ()) {
                    iter.next ();
                    var i = iter.get ();

                    var parent = find_existing (i.parent, new_root);
                    if (parent != null) {
                        found_something = true;
                        parent.add (new CtagsSymbol (doc, i.name, i.line, i.icon));
                        iter.remove ();
                    } else {
                        // anonymous enum
                        if (i.parent.substring (0, 6) == "__anon") {
                            var e = new CtagsSymbol (doc, i.parent, i.line - 1, new FileIcon (File.new_for_uri (OUTLINE_RESOURCE_URI + "enum-symbolic.svg")));
                            new_root.add (e);

                            e.add (new CtagsSymbol (doc, i.name, i.line, i.icon));
                            iter.remove ();
                        }
                    }
                }
            }
            // just add the rest
            foreach (var symbol in parent_dependent) {
                new_root.add (new CtagsSymbol (doc, symbol.name, symbol.line, symbol.icon));
            }

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

    private Gee.TreeSet<CtagsSymbol> iterate_children (Granite.Widgets.SourceList.ExpandableItem parent) {
        var result = new Gee.TreeSet<CtagsSymbol> ();
        foreach (var child in parent.children) {
            result.add_all (iterate_children ((CtagsSymbol)child));
        }
        return result;
    }

    void parse_fields (string fields, out int line, out string parent) {
        var index = -1;
        line = -1;
        parent = null;
        if ((index = fields.index_of ("line:")) > -1) {
            line = int.parse (fields.substring (index + 5, int.max (fields.index_of (" ", index + 6) - index, -1)));
        }
        if ((index = fields.index_of ("class:")) > -1) {
            parent = fields.substring (index + 6, int.max (fields.index_of (" ", index + 7) - index, -1));
        }
        if ((index = fields.index_of ("struct:")) > -1) {
            parent = fields.substring (index + 7, int.max (fields.index_of (" ", index + 7) - index, -1));
        }
        if ((index = fields.index_of ("enum:")) > -1) {
            parent = fields.substring (index + 5, int.max (fields.index_of (" ", index + 7) - index, -1));
        }
    }

    CtagsSymbol? find_existing (string name, Granite.Widgets.SourceList.ExpandableItem parent) {
        CtagsSymbol match = null;
        foreach (var child in parent.children) {
            var child_symbol = child as CtagsSymbol;
            if (child_symbol.name == name) {
                match = child_symbol;
                break;
            } else {
                var res = find_existing (name, child_symbol);
                if (res != null)
                    return res;
            }
        }

        return match;
    }

    public static string[] get_supported_types () {
        string stdout;
        try {
            Process.spawn_sync (null, {"/usr/bin/ctags", "--list-languages"}, null, 0, null, out stdout);
        } catch (Error e) {
            error (e.message);
        }

        return stdout.split ("\n");
    }

    public Granite.Widgets.SourceList get_source_list () {
        return store;
    }
}
