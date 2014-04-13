
public class Report : Vala.Report
{
    // just mute everything
    public override void err (Vala.SourceReference? ref, string msg) {}
    public override void warn (Vala.SourceReference? ref, string msg) {}
    public override void note (Vala.SourceReference? ref, string msg) {}
    public override void depr (Vala.SourceReference? ref, string msg) {}
}

public class Symbol : Granite.Widgets.SourceList.ExpandableItem
{
    public Scratch.Services.Document doc { get; construct set; }
    public Vala.Symbol symbol { get; construct set; }

    public Symbol (Scratch.Services.Document doc, Vala.Symbol symbol)
    {
        Object (symbol: symbol, name: symbol.name, doc: doc);
    }
}

class SymbolIter : Object
{
    public Vala.Symbol? symbol { get; construct set; default = null; }
    public Icon? icon { get; construct set; default = null; }
    public Gee.LinkedList<SymbolIter> children { get; private set; }

    public SymbolIter (Vala.Symbol? symbol = null, Icon? icon = null)
    {
        Object(symbol: symbol, icon: icon);
        children = new Gee.LinkedList<SymbolIter> ();
    }
}

public class ValaSymbolOutline : Object, SymbolOutline
{
    public Scratch.Services.Document doc { get; protected set; }
    public Granite.Widgets.SourceList store { get; private set; }
    Granite.Widgets.SourceList.ExpandableItem root;
    Vala.CodeContext context;
    Vala.Parser parser;
    SymbolResolver resolver;
    
    public int n_symbols { get; protected set; }
    
    SymbolIter cache;

    Gee.List<Vala.Field> field_blacklist;

    public ValaSymbolOutline (Scratch.Services.Document _doc)
    {
        doc = _doc;
        doc.doc_closed.connect (doc_closed);

        field_blacklist = new Gee.LinkedList<Vala.Field> ();
        cache = new SymbolIter ();

        store = new Granite.Widgets.SourceList ();
        store.get_style_context ().add_class ("sidebar");
        store.item_selected.connect ((selected) => {
            if (selected == null) return;
            goto (doc, (selected as Symbol).symbol.source_reference.begin.line);
            store.selected = null;
        });
        root = new Granite.Widgets.SourceList.ExpandableItem (_("Symbols"));
        store.root.add (root);

        parser = new Vala.Parser ();
        resolver = new SymbolResolver ();
        resolver.add_symbol.connect (add_symbol);
        resolver.blacklist.connect ((f) => {
            field_blacklist.add (f);
        });

        this.n_symbols = 0;

        init_context ();
    }

    void init_context ()
    {
        context = new Vala.CodeContext ();
        context.profile = Vala.Profile.GOBJECT;
        context.add_source_filename (doc.file.get_path ());
        context.report = new Report ();
    }
    
    ~ValaSymbolResolver ()
    {
        doc.doc_closed.disconnect (doc_closed);
    }

    void doc_closed (Scratch.Services.Document doc)
    {
        closed ();
    }

    public Granite.Widgets.SourceList get_source_list ()
    {
        return store;
    }

    async void parse_symbols_async ()
    {
        field_blacklist.clear ();

        lock (context)
        {
            Vala.CodeContext.push (context);

            parser.parse (context);
            resolver.resolve (context);

            Vala.CodeContext.pop ();
        }
    }

    public void parse_symbols ()
    {
        cache.children.clear ();
        init_context ();
        
        Thread<void*> thread = new Thread<void*>("parse-symbols", () => {
            parse_symbols_async ();
            return null;
        });

        thread.join ();

        root.clear ();
        construct_tree (cache, root);

        store.root.expand_all ();
    }

    void construct_tree (SymbolIter iter_parent,
        Granite.Widgets.SourceList.ExpandableItem tree_parent)
    {
        foreach (var iter_child in iter_parent.children) {
            if (iter_child == null)
                continue;
            var tree_child = new Symbol (doc, iter_child.symbol);
            tree_child.icon = iter_child.icon;
            tree_parent.add (tree_child);

            construct_tree (iter_child, tree_child);
            this.n_symbols++;
        }
    }

    SymbolIter? find_existing (Vala.Symbol symbol, SymbolIter parent = cache)
    {
        SymbolIter match = null;
        foreach (var child in parent.children) {
            if (child.symbol== symbol) {
                match = child;
                break;
            } else {
                var res = find_existing (symbol, child);
                if (res != null)
                    return res;
            }
        }
        return match;
    }

    // vala generates for each property a field which we do not want to display
    void filter_generated_fields (Granite.Widgets.SourceList.ExpandableItem parent)
    {
        foreach (var child in parent.children) {
            var child_symbol = child as Symbol;
            if (field_blacklist.contains (child_symbol.symbol as Vala.Field)) {
                parent.remove (child);
            }
            filter_generated_fields (child_symbol);
        }
    }

    void add_symbol (Vala.Symbol symbol, string icon = "", Icon? real_icon = null)
    {
        if (symbol.name == null)
            return;

        SymbolIter parent;
        if (symbol.scope.parent_scope.owner.name == null)
            parent = cache;
        else
            parent = find_existing (symbol.scope.parent_scope.owner);

        if (parent == null) {
            warning ("Could not find parent scope of symbol");
            return;
        }

        var i = real_icon != null ? real_icon : new ThemedIcon.with_default_fallbacks (icon);
        var s = new SymbolIter (symbol, i);
        parent.children.add (s);
    }
}

public class SymbolResolver : Vala.SymbolResolver
{
    public signal void add_symbol (Vala.Symbol s, string icon = "", Icon? real_icon = null);
    public signal void blacklist (Vala.Field f);

    public override void visit_class (Vala.Class s)
    {
        add_symbol (s, "user-home-symbolic",
            new ThemedIcon.from_names ({"user-home-symbolic", "go-home-symbolic", "user-home", "go-home", "home"}));
        base.visit_class (s);
    }
    public override void visit_constant (Vala.Constant s)
    {
        add_symbol (s, "view-grid-symbolic");
        base.visit_constant (s);
    }
    public override void visit_delegate (Vala.Delegate s)
    {
        add_symbol (s);
        base.visit_delegate (s);
    }
    //FIXME both constructor and destructor are currently not added for some reason
    public override void visit_constructor (Vala.Constructor s)
    {
        add_symbol (s, "media-playback-start-symbolic");
        base.visit_constructor (s);
    }
    public override void visit_destructor (Vala.Destructor s)
    {
        add_symbol (s, "edit-delete-symbolic");
        base.visit_destructor (s);
    }
    public override void visit_enum (Vala.Enum s)
    {
        add_symbol (s, "view-list-compact-symbolic");
        base.visit_enum (s);
    }
    public override void visit_field (Vala.Field s)
    {
        add_symbol (s, "view-grid-symbolic");
        base.visit_field (s);
    }
    public override void visit_interface (Vala.Interface s)
    {
        add_symbol (s, "", 
            new ThemedIcon.from_names ({"dialog-information-symbolic", "help-info-symbolic", "dialog-information", "help-info", "information", "info"}));
        base.visit_interface (s);
    }
    public override void visit_method (Vala.Method s)
    {
        add_symbol (s, "document-properties-symbolic");
        base.visit_method (s);
    }
    public override void visit_namespace (Vala.Namespace s)
    {
        add_symbol (s, "view-fullscreen-symbolic");
        base.visit_namespace (s);
    }
    public override void visit_property (Vala.Property s)
    {
        add_symbol (s, "format-indent-more-symbolic");
        blacklist (s.field);
        base.visit_property (s);
    }
    public override void visit_signal (Vala.Signal s)
    {
        add_symbol (s);
        base.visit_signal (s);
    }
    public override void visit_struct (Vala.Struct s)
    {
        add_symbol (s, "user-home-symbolic",
            new ThemedIcon.from_names ({"user-home-symbolic", "go-home-symbolic", "user-home", "go-home", "home"}));
        base.visit_struct (s);
    }
}
