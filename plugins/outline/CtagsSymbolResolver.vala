
public class CtagsSymbol : Granite.Widgets.SourceList.ExpandableItem
{
    public Scratch.Services.Document doc { get; construct set; }
    public int line { get; construct set; }

    public CtagsSymbol (Scratch.Services.Document doc, string name, int line, Icon? _icon)
    {
        Object (doc: doc, name: name, line: line);
        icon = _icon;
    }
}

class CtagsSymbolIter : Object
{
    public string name { get; construct set; }
    public string parent { get; construct set; }
    public int line { get; construct set; }
    public Icon icon { get; construct set; }

    public CtagsSymbolIter (string name, string parent, int line, Icon icon)
    {
        Object(name: name, parent: parent, line: line, icon: icon);
    }
}

public class CtagsSymbolOutline : Object, SymbolOutline
{
    public Scratch.Services.Document doc { get; protected set; }
    Granite.Widgets.SourceList store;
    Granite.Widgets.SourceList.ExpandableItem root;

    public CtagsSymbolOutline (Scratch.Services.Document _doc)
    {
        doc = _doc;
        doc.doc_closed.connect (doc_closed);

        root = new Granite.Widgets.SourceList.ExpandableItem (_("Symbols"));

        store = new Granite.Widgets.SourceList ();
        store.get_style_context ().add_class ("sidebar");
        store.item_selected.connect ((selected) => {
            if (selected == null) return;
            goto (doc, (selected as CtagsSymbol).line);
            store.selected = null;
        });
        store.root.add (root);
    }

    ~CtagsSymbolOutline ()
    {
        doc.doc_closed.disconnect (doc_closed);
    }

    void doc_closed (Scratch.Services.Document doc)
    {
        closed ();
    }

    public void parse_symbols ()
    {
        var command = new Granite.Services.SimpleCommand (Environment.get_home_dir (),
            "/usr/bin/ctags -f - --format=2 --excmd=n --fields=nsK --extra= "+
            "--sort=no " + doc.file.get_path ());
        command.done.connect (parse_output);
        command.run ();
    }

    void parse_output (Granite.Services.SimpleCommand command, int status)
    {
        root.clear ();
        var parent_dependent = new Gee.LinkedList<CtagsSymbolIter> ();

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
                case "struct":
                    icon = new ThemedIcon.from_names ({"user-home-symbolic", "go-home-symbolic", "user-home", "go-home", "home"});
                    break;
                case "field":
                case "constant":
                case "enumerator":
                case "member":
                case "variable":
                    icon = new ThemedIcon.with_default_fallbacks ("view-grid-symbolic");
                    break;
                case "constructor":
                    icon = new ThemedIcon.with_default_fallbacks ("media-playback-start-symbolic");
                    break;
                case "desctructor":
                    icon = new ThemedIcon.with_default_fallbacks ("edit-delete-symbolic");
                    break;
                case "enum":
                case "typedef":
                    icon = new ThemedIcon.with_default_fallbacks ("view-list-compact-symbolic");
                    break;
                case "method":
                case "function":
                    icon = new ThemedIcon.with_default_fallbacks ("document-properties-symbolic");
                    break;
                case "namespace":
                case "package":
                    icon = new ThemedIcon.with_default_fallbacks ("view-fullscreen-symbolic");
                    break;
                case "property":
                    icon = new ThemedIcon.with_default_fallbacks ("format-indent-more-symbolic");
                    break;
                case "macro":
                    icon = new ThemedIcon.with_default_fallbacks ("mail-attachment-symbolic");
                    break;
            }

            if (parent == null) {
                var s = new CtagsSymbol (doc, name, line, icon);
                root.add (s);
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

                var parent = find_existing (i.parent, root);
                if (parent != null) {
                    found_something = true;
                    parent.add (new CtagsSymbol (doc, i.name, i.line, i.icon));
                    iter.remove ();
                } else {
                    // anonymous enum
                    if (i.parent.substring (0, 6) == "__anon") {
                        var e = new CtagsSymbol (doc, i.parent, i.line - 1,
                            new ThemedIcon.with_default_fallbacks ("view-list-compact-symbolic"));
                        root.add (e);

                        e.add (new CtagsSymbol (doc, i.name, i.line, i.icon));
                        iter.remove ();
                    }
                }
            }
        }
        // just add the rest
        foreach (var symbol in parent_dependent) {
            root.add (new CtagsSymbol (doc, symbol.name, symbol.line, symbol.icon));
        }

        store.root.expand_all ();
        store.show_all ();
        store.get_parent ().show_all ();
    }

    void parse_fields (string fields, out int line, out string parent)
    {
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

    CtagsSymbol? find_existing (string name, Granite.Widgets.SourceList.ExpandableItem parent)
    {
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

    public static string[] get_supported_types ()
    {
        string stdout;
        try {
        Process.spawn_sync (null, {"/usr/bin/ctags", "--list-languages"}, null, 0, null, out stdout);
        } catch (Error e) { error (e.message); }
        return stdout.split ("\n");
    }

    public Granite.Widgets.SourceList get_source_list ()
    {
        return store;
    }
}
