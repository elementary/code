
public class Report : Vala.Report
{
    // just mute everything
    public override void err (Vala.SourceReference? ref, string msg) {}
    public override void warn (Vala.SourceReference? ref, string msg) {}
    public override void note (Vala.SourceReference? ref, string msg) {}
    public override void depr (Vala.SourceReference? ref, string msg) {}
}

public class SymbolItem : Granite.Widgets.SourceList.ExpandableItem, Granite.Widgets.SourceListSortable
{
    public Scratch.Services.Document doc { get; construct set; }
    public Vala.Symbol symbol { get; construct set; }

    public SymbolItem (Scratch.Services.Document doc, Vala.Symbol symbol)
    {
        string given_name = symbol.name;
        if (symbol is Vala.CreationMethod) {
            if (symbol.name == ".new")
                given_name = ((Vala.CreationMethod)symbol).class_name;
            else
                given_name = "%s.%s".printf (((Vala.CreationMethod)symbol).class_name, symbol.name);
        }

        Object (symbol: symbol, name: given_name, doc: doc);
    }

    public int compare (Granite.Widgets.SourceList.Item a, Granite.Widgets.SourceList.Item b) {
        return Comparison.sort_function (a, b);
    }

    public bool allow_dnd_sorting () {
        return false;
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

    public ValaSymbolOutline (Scratch.Services.Document _doc)
    {
        doc = _doc;
        doc.doc_closed.connect (doc_closed);

        store = new Granite.Widgets.SourceList ();
        store.item_selected.connect ((selected) => {
            goto (doc, (selected as SymbolItem).symbol.source_reference.begin.line);
        });

        root = new Granite.Widgets.SourceList.ExpandableItem (_("Symbols"));
        store.root.add (root);

        parser = new Vala.Parser ();
        resolver = new SymbolResolver ();

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
    
    ~ValaSymbolOutline ()
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

    public void parse_symbols ()
    {
        init_context ();

        store.root.clear ();
        Thread<void*> thread = new Thread<void*>("parse-symbols", () => {
            lock (context)
            {
                Vala.CodeContext.push (context);

                parser.parse (context);
                resolver.clear ();
                resolver.resolve (context);

                Vala.CodeContext.pop ();
            }

            construct_tree ();
            Idle.add (() => {
                store.root.add (root);
                store.root.expand_all ();
                return false;
            });
            return null;
        });
    }

    void construct_tree ()
    {
        var fields = resolver.get_properties_fields ();
        var symbols = resolver.get_symbols ();
        foreach (var symbol in symbols) {
            var exist = find_existing (symbol);
            if (exist != null)
                continue;

            if (symbol.name == null)
                continue;

            if (symbol is Vala.Field && fields.contains ((Vala.Field)symbol))
                continue;

            construct_child (symbol);
            this.n_symbols++;
        }
    }

    private SymbolItem construct_child (Vala.Symbol symbol)
    {
        Granite.Widgets.SourceList.ExpandableItem parent;
        if (symbol.scope.parent_scope.owner.name == null)
            parent = root;
        else
            parent = find_existing (symbol.scope.parent_scope.owner);

        if (parent == null) {
            parent = construct_child (symbol.scope.parent_scope.owner);
        }

        var tree_child = new SymbolItem (doc, symbol);
        if (symbol is Vala.Struct) {
            tree_child.icon = new ThemedIcon ("structure-symbolic");
        } else if (symbol is Vala.Class) {
            tree_child.icon = new ThemedIcon ("class-symbolic");
        } else if (symbol is Vala.Constant) {
            tree_child.icon = new ThemedIcon ("constant-symbolic");
        } else if (symbol is Vala.Enum) {
            tree_child.icon = new ThemedIcon ("enum-symbolic");
        } else if (symbol is Vala.Field) {
            tree_child.icon = new ThemedIcon ("field-symbolic");
        } else if (symbol is Vala.Interface) {
            tree_child.icon = new ThemedIcon ("interface-symbolic");
        } else if (symbol is Vala.Property) {
            tree_child.icon = new ThemedIcon ("property-symbolic");
        } else if (symbol is Vala.Signal) {
            tree_child.icon = new ThemedIcon ("signal-symbolic");
        }

        parent.add (tree_child);
        return tree_child;
    }

    SymbolItem? find_existing (Vala.Symbol symbol, Granite.Widgets.SourceList.ExpandableItem parent = root)
    {
        SymbolItem match = null;
        foreach (var _child in parent.children) {
            var child = _child as SymbolItem;
            if (child == null)
                continue;

            if (child.symbol == symbol) {
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
}

public class SymbolResolver : Vala.SymbolResolver
{
    private Gee.TreeSet<Vala.Property> properties = new Gee.TreeSet<Vala.Property> ();
    private Gee.TreeSet<Vala.Symbol> symbols = new Gee.TreeSet<Vala.Symbol> ();

    public Gee.TreeSet<Vala.Field> get_properties_fields () {
        var return_fields = new Gee.TreeSet<Vala.Field> ();
        foreach (var prop in properties) {
            if (prop.field != null) {
                return_fields.add (prop.field);
            }
        }

        return return_fields;
    }

    public Gee.TreeSet<Vala.Symbol> get_symbols () {
        var return_symbols = new Gee.TreeSet<Vala.Symbol> ();
        return_symbols.add_all (symbols);
        return return_symbols;
    }

    public void clear () {
        properties.clear ();
        symbols.clear ();
    }

    public override void visit_class (Vala.Class s)
    {
        symbols.add (s);
        base.visit_class (s);
    }
    public override void visit_constant (Vala.Constant s)
    {
        symbols.add (s);
        base.visit_constant (s);
    }
    public override void visit_delegate (Vala.Delegate s)
    {
        symbols.add (s);
        base.visit_delegate (s);
    }
    //FIXME both constructor and destructor are currently not added for some reason
    public override void visit_constructor (Vala.Constructor s)
    {
        symbols.add (s);
        base.visit_constructor (s);
    }
    public override void visit_destructor (Vala.Destructor s)
    {
        symbols.add (s);
        base.visit_destructor (s);
    }
    public override void visit_creation_method (Vala.CreationMethod s)
    {
        symbols.add (s);
        base.visit_creation_method (s);
    }
    public override void visit_enum (Vala.Enum s)
    {
        symbols.add (s);
        base.visit_enum (s);
    }
    public override void visit_field (Vala.Field s)
    {
        symbols.add (s);
        base.visit_field (s);
    }
    public override void visit_interface (Vala.Interface s)
    {
        symbols.add (s);
        base.visit_interface (s);
    }
    public override void visit_method (Vala.Method s)
    {
        symbols.add (s);
        base.visit_method (s);
    }
    public override void visit_namespace (Vala.Namespace s)
    {
        symbols.add (s);
        base.visit_namespace (s);
    }
    public override void visit_property (Vala.Property s)
    {
        symbols.add (s);
        properties.add (s);
        base.visit_property (s);
    }
    public override void visit_signal (Vala.Signal s)
    {
        symbols.add (s);
        base.visit_signal (s);
    }
    public override void visit_struct (Vala.Struct s)
    {
        symbols.add (s);
        base.visit_struct (s);
    }
}
