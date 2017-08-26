/*-
 * Copyright (c) 2015-2016 Adam Bieńkowski
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 2.1 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 *
 * Authored by: Adam Bieńkowski <donadigos159@gmail.com>
 */

public class ValaCodeParser : CodeParser {
    public Vala.CodeContext context;
    public Vala.Parser parser;
    public Report report;

    public bool parsing = false;

    private Vala.MemberBinding prev_binding;
    private bool prev_access;
    private ValaBlockLocator locator;
    private ValaDefinitionWriter definition_writer;

    construct {
        report = new Report ();
        locator = new ValaBlockLocator ();
        context = new Vala.CodeContext ();
        context.report = report;
        context.compile_only = true;
        context.verbose_mode = false;
        context.assert = false;
        context.profile = Vala.Profile.GOBJECT;
        context.thread = true;
        context.save_temps = false;
        context.mem_profiler = true;
        context.hide_internal = false;
        context.checking = false;

        // TODO: we need to have some kind of project system or UI to
        // automatically / manually add those packages to the CodeContext
        context.add_external_package ("glib-2.0");
        context.add_external_package ("gobject-2.0");
        context.add_external_package ("gtk+-3.0");

        definition_writer = new ValaDefinitionWriter (context);

        locator.resolve (context);

        Vala.CodeContext.push (context);

        parser = new Vala.Parser ();
        parser.parse (context);

        context.check ();

        Vala.CodeContext.pop ();
    }
    
    public void add_package (string package) {
        lock (context) {
            Vala.CodeContext.push (context);
            if (context.has_package (package)) {
                Vala.CodeContext.pop ();
                return;
            }

            context.add_external_package (package);
            Vala.CodeContext.pop ();
        }
    }
    
    public override void add_document (Scratch.Services.Document document) {
        string? filename = document.file.get_path ();
        if (filename == null) {
            return;
        }

        lock (context) {
            Vala.CodeContext.push (context);
            if (get_source_file_for_document (document) != null) {
                Vala.CodeContext.pop ();
                return;
            }

            var source_file = new Vala.SourceFile (context, Vala.SourceFileType.SOURCE, filename, document.source_view.buffer.text);

            var unres = new Vala.UnresolvedSymbol (null, "GLib");
            var udir = new Vala.UsingDirective (unres);

            source_file.add_using_directive (udir);
            source_file.context.root.add_using_directive (udir);

            context.add_source_file (source_file);
            Vala.CodeContext.pop ();
        }
    }
    
    public override void remove_document (Scratch.Services.Document document) {
        lock (context) {
            Vala.CodeContext.push (context);
            var file = get_source_file_for_document (document);
            if (file == null) {
                Vala.CodeContext.pop ();
                return;
            }        

            context.get_source_files ().remove (file);
            Vala.CodeContext.pop ();
        }
    }

    public void add_source (string source) {
        lock (context) {
            Vala.CodeContext.push (context);
            if (get_source_file_for_filename (source) != null) {
                Vala.CodeContext.pop ();
                return;
            }

            context.add_source_filename (source);
            Vala.CodeContext.pop ();
        }
    }
    
    public override ReportMessage? get_report_message_at (string? filename, int line) {
        if (filename == null) {
            return null;
        }

        foreach (var message in report.get_messages ()) {
            if (message.source != null &&
                message.source.file.filename == filename &&
                message.source.begin.line == line) {
                return message;
            }
        }

        return null;
    }

    public string write_symbol_definition (Vala.Symbol symbol) {
        lock (context) {
            Vala.CodeContext.push (context);
            string definition = definition_writer.write_symbol_definition (symbol);
            Vala.CodeContext.pop ();

            return definition.strip ();
        }   
    }

    public Vala.Symbol? lookup_symbol_at (string filename, int line, int column) {
        var file = get_source_file_for_filename (filename);
        if (file == null) {
            return null;
        }

        lock (context) {
            Vala.CodeContext.push (context);
            var symbol = locator.locate (file, line, column);
            Vala.CodeContext.pop ();

            return symbol;
        }
    }
    
    private Gee.List<Vala.Symbol> lookup_symbol (Vala.Symbol? symbol) {
        var list = new Gee.ArrayList<Vala.Symbol> ();
        if (symbol == null) {
            return list;
        }

        prev_binding = Vala.MemberBinding.CLASS;
        prev_access = false;
        lock (context) {
            for (var sym = symbol; sym != null; sym = sym.parent_symbol) {
                list.add_all (lookup_symbol_inherited (sym));
            }

            if (symbol.source_reference != null) {
                foreach (var ns in symbol.source_reference.file.current_using_directives) {
                    list.add_all (lookup_symbol_inherited (ns.namespace_symbol));
                }
            }
        }

        return list;
    }   
    
    private Gee.List<Vala.Symbol> lookup_symbol_inherited (Vala.Symbol? sym) {
        var list = new Gee.ArrayList<Vala.Symbol> ();
        if (sym == null) {
            return list;
        }

        var symbol_table = sym.scope.get_symbol_table ();
        if (symbol_table != null) {
            foreach (string key in symbol_table.get_keys ()) {
                var child = symbol_table[key];
                if ((prev_binding != Vala.MemberBinding.STATIC || sym is Vala.Namespace) && 
                    (!prev_access || prev_access && (child.access & Vala.SymbolAccessibility.PRIVATE) == 0)) {
                    list.add (child);
                } else if (prev_binding == Vala.MemberBinding.STATIC) {
                    if ((child is Vala.Property && (child as Vala.Property).binding == Vala.MemberBinding.STATIC ||
                        child is Vala.Method && (child as Vala.Method).binding == Vala.MemberBinding.STATIC ||
                        child is Vala.Field && (child as Vala.Field).binding == Vala.MemberBinding.STATIC) && 
                        (!prev_access || prev_access && (child.access & Vala.SymbolAccessibility.PRIVATE) == 0)) {
                        list.add (child);
                    }
                }
            }
        }

        if (sym is Vala.Signal) {
            var sig = sym as Vala.Signal;
            var parameters = sig.get_parameters ();
            if (parameters != null && parameters.size > 0) {
                foreach (var param in sig.get_parameters ()) {
                    list.add (param);
                }
            }
        }

        if (sym is Vala.Method) {
            // add missing local variables.
            var method = (Vala.Method)sym;
            var body = method.body;
            if (body != null) {
                foreach (var lv in body.get_local_variables ()) {
                    list.add (lv);
                }
            }
        }

        if (sym is Vala.Class) {
            var klass = (Vala.Class)sym;
            var base_types = klass.get_base_types ();
            if (base_types != null && base_types.size > 0) {
                foreach (var bt in base_types) {
                    list.add_all (lookup_symbol_inherited (bt.data_type));
                }
            }
        }

        if (sym is Vala.Interface) {
            var iface = (Vala.Interface)sym;
            var prerequisites = iface.get_prerequisites ();
            if (prerequisites != null && prerequisites.size > 0) {
                foreach (var pre in prerequisites) {
                    list.add_all (lookup_symbol_inherited (pre.data_type));
                }
            }
        }

        if (sym is Vala.Method && !(sym.parent_symbol is Vala.Block) && prev_binding != Vala.MemberBinding.STATIC) {
            prev_binding = ((Vala.Method)sym).binding;
            prev_access = true;
        } else if (!(sym is Vala.Block) || (sym is Vala.Block) && !(sym.parent_symbol is Vala.Method)) {
            prev_access = true;
        }

        return list;
    }
    
    public Gee.Set<Vala.Symbol?> lookup_visible_symbols_at (string filename, int line, int column) {
        var symbol = lookup_symbol_at (filename, line, column);
        if (symbol == null) {
            symbol = lookup_symbol_at (filename, line - 1, column);
        }

        var hashset = new Gee.HashSet<Vala.Symbol?> (symbol_hash, symbol_equal);
        var list = lookup_symbol (symbol);
        if (symbol != null) {
            hashset.add_all (list);
        }

        /*
        lock (context) {
            foreach (var file in context.get_source_files()) {
                if (file.file_type == Vala.SourceFileType.SOURCE && file.filename != filename) {
                    foreach (var ud in file.current_using_directives)
                        append_visible_symbols (hashset, ud.namespace_symbol);
                    foreach (var node in file.get_nodes()) 
                        if (node is Vala.Symbol) {
                            var sym = node as Vala.Symbol;
                            if (symbol != null && sym.is_accessible (symbol) && (sym.parent_symbol == null || sym.parent_symbol.name == null))
                                hashset.add (sym);
                        }
                }
            }
        }
        */

        return hashset;
    }

    private uint symbol_hash (Vala.Symbol? symbol) {
        if (symbol == null || symbol.name == null) {
            return 0;
        }

        return str_hash (symbol.name);
    }
    
    private bool symbol_equal (Vala.Symbol? symbol, Vala.Symbol? other) {
        if (symbol == null || other == null || symbol.name == null || other.name == null) {
            return false;
        }

        return str_equal (symbol.name, other.name);
    }
    
    // TODO: be smarter than using has_prefix for match parameter
    public Gee.Set<Vala.Symbol> get_symbols_for_name (Vala.Symbol? symbol, string name, bool match, Vala.MemberBinding binding = Vala.MemberBinding.CLASS) {
        var hashset = new Gee.HashSet<Vala.Symbol?> (symbol_hash, symbol_equal);
        if (symbol != null) {
            foreach (var sym in gsfm (symbol, name, match, binding)) {
                hashset.add (sym);
            }
        }

        return hashset;
    }
    
    private Gee.List<Vala.Symbol> gsfm (Vala.Symbol? symbol, string name, bool match, Vala.MemberBinding binding = Vala.MemberBinding.CLASS) {
        if (symbol == null) {
            return new Gee.ArrayList<Vala.Symbol> ();
        }
        
        if (symbol is Vala.Parameter) {
            return gsfm ((symbol as Vala.Parameter).variable_type.data_type, name, match, Vala.MemberBinding.INSTANCE);
        }
        if (symbol is Vala.Property) {
            return gsfm ((symbol as Vala.Property).property_type.data_type, name, match, (symbol as Vala.Property).binding);
        }

        if (symbol is Vala.Field) {
            return gsfm ((symbol as Vala.Field).variable_type.data_type, name, match, (symbol as Vala.Field).binding);
        }

        if (symbol is Vala.LocalVariable) {
            return gsfm ((symbol as Vala.LocalVariable).variable_type.data_type, name, match, Vala.MemberBinding.INSTANCE);
        }

        if (symbol is Vala.Namespace) {
            return get_symbols_for_namespace (symbol as Vala.Namespace, name, match, binding);
        }

        if (symbol is Vala.Class) {
            return get_symbols_for_class (symbol as Vala.Class, name, match, binding);
        }

        if (symbol is Vala.Struct) {
            return get_symbols_for_struct (symbol as Vala.Struct, name, match, binding);
        }

        if (symbol is Vala.Enum) {
            return get_symbols_for_enum (symbol as Vala.Enum, name, match, binding);
        }

        if (symbol is Vala.ErrorDomain) {
            return get_symbols_for_error_domain (symbol as Vala.ErrorDomain, name, match, binding);
        }

        if (symbol is Vala.Interface) {
            return get_symbols_for_interface (symbol as Vala.Interface, name, match, binding);
        }

        if (symbol is Vala.Method) {
            return gsfm ((symbol as Vala.Method).return_type.data_type, name, match, (symbol as Vala.Method).binding);
        }

        if (symbol is Vala.Signal) {
            return get_symbols_for_signal (symbol as Vala.Signal, name, match, binding);
        }

        return new Gee.ArrayList<Vala.Symbol>();
    }
    
    private Gee.List<Vala.Symbol> get_symbols_for_signal (Vala.Signal sig, string name, bool match, Vala.MemberBinding binding) {
        var list = new Gee.ArrayList<Vala.Symbol> ();
        if (match && name == "connect" || "connect".has_prefix (name)) {
            var m = new Vala.Method ("connect", new Vala.SignalType (sig));
            list.add (m);
        }

        if (match && name == "disconnect" || "disconnect".has_prefix (name)) {
            var m = new Vala.Method ("disconnect", new Vala.VoidType());
            list.add (m);
        }

        return list;
    }
    
    private Gee.List<Vala.Symbol> get_symbols_for_error_domain (Vala.ErrorDomain ed, string name, bool match, Vala.MemberBinding binding) {
        var list = new Gee.ArrayList<Vala.Symbol>();
        if (binding == Vala.MemberBinding.CLASS) {
            foreach (var code in ed.get_codes ()) {
                if ((match && name == code.name) || code.name.has_prefix (name)) {
                    list.add (code);
                }
            }
        } 

        foreach (var m in ed.get_methods ()) {
            if (m.binding == Vala.MemberBinding.INSTANCE && binding != Vala.MemberBinding.CLASS ||
                binding == Vala.MemberBinding.CLASS && m.binding == Vala.MemberBinding.STATIC) {
                if ((match && name == m.name) || m.name.has_prefix (name)) {
                    list.add (m);
                }
            }
        }

        return list;
    }
    
    private Gee.List<Vala.Symbol> get_symbols_for_enum (Vala.Enum e, string name, bool match, Vala.MemberBinding binding) {
        var list = new Gee.ArrayList<Vala.Symbol>();
        if (binding == Vala.MemberBinding.CLASS) {
            foreach (var c in e.get_constants ()) {
                if ((match && name == c.name) || c.name.has_prefix (name)) {
                    list.add (c);
                }
            }

            foreach (var ev in e.get_values ()) {
                if ((match && name == ev.name) || ev.name.has_prefix (name)) {
                    list.add (ev);
                }
            }
        }

        foreach (var m in e.get_methods ()) {
            if (m.binding == Vala.MemberBinding.INSTANCE && binding != Vala.MemberBinding.CLASS ||
                binding == Vala.MemberBinding.CLASS && m.binding == Vala.MemberBinding.STATIC) {
                if ((match && name == m.name) || m.name.has_prefix (name)) {
                    list.add (m);
                }
            }
        }

        return list;
    }
    
    private Gee.List<Vala.Symbol> get_symbols_for_namespace (Vala.Namespace ns, string name, bool match, Vala.MemberBinding binding) {
        var list = new Gee.ArrayList<Vala.Symbol>();
        foreach (var cls in ns.get_classes ()) {
            if ((match && name == cls.name) || cls.name.has_prefix (name)) {
                list.add (cls);
            }
        }

        foreach (var c in ns.get_constants ()) {
            if ((match && name == c.name) || c.name.has_prefix (name)) {
                list.add (c);
            }
        }

        foreach (var d in ns.get_delegates ()) {
            if ((match && name == d.name) || d.name.has_prefix (name)) {
                list.add (d);
            }
        }

        foreach (var e in ns.get_enums ()) {
            if ((match && name == e.name) || e.name.has_prefix (name)) {
                list.add (e);
            }
        }

        foreach (var ed in ns.get_error_domains ()) {
            if ((match && name == ed.name) || ed.name.has_prefix (name)) {
                list.add (ed);
            }
        }

        foreach (var f in ns.get_fields ()) {
            if ((match && name == f.name) || f.name.has_prefix (name)) {
                list.add (f);
            }
        }

        foreach (var i in ns.get_interfaces ()) {
            if ((match && name == i.name) || i.name.has_prefix (name)) {
                list.add (i);
            }
        }

        foreach (var n in ns.get_namespaces ()) {
            if ((match && name == n.name) || n.name.has_prefix (name)) {
                list.add (n);
            }
        }

        foreach (var m in ns.get_methods ()) {
            if ((match && name == m.name) || m.name.has_prefix (name)) {
                list.add (m);
            }
        }

        foreach (var s in ns.get_structs ()) {
            if ((match && name == s.name) || s.name.has_prefix (name)) {
                list.add (s);
            }
        }

        return list;
    }

    private Gee.List<Vala.Symbol> get_symbols_for_interface (Vala.Interface intf, string name, bool match, Vala.MemberBinding binding) {
        var list = new Gee.ArrayList<Vala.Symbol>();
        if (binding == Vala.MemberBinding.CLASS) {
            foreach (var cls in intf.get_classes ()) {
                if ((match && name == cls.name) || cls.name.has_prefix (name)) {
                    list.add (cls);
                }
            }

            foreach (var c in intf.get_constants ()) {
                if ((match && name == c.name) || c.name.has_prefix (name)) {
                    list.add (c);
                }
            }

            foreach (var d in intf.get_delegates ()) {
                if ((match && name == d.name) || d.name.has_prefix (name)) {
                    list.add (d);
                }
            }

            foreach (var e in intf.get_enums ()) {
                if ((match && name == e.name) || e.name.has_prefix (name)) {
                    list.add (e);
                }
            }

            foreach (var s in intf.get_structs ()) {
                if ((match && name == s.name) || s.name.has_prefix (name)) {
                    list.add (s);
                }
            }
        }

        foreach (var f in intf.get_fields ()) {
            if (f.binding == Vala.MemberBinding.INSTANCE && binding != Vala.MemberBinding.CLASS ||
                binding == Vala.MemberBinding.CLASS && f.binding == Vala.MemberBinding.STATIC) {
                if ((match && name == f.name) || f.name.has_prefix (name)) {
                    list.add (f);
                }
            }
        }

        foreach (var m in intf.get_methods ()) {
            if (m.binding == Vala.MemberBinding.INSTANCE && binding != Vala.MemberBinding.CLASS && !(m is Vala.CreationMethod) ||
                binding == Vala.MemberBinding.CLASS && (m.binding == Vala.MemberBinding.STATIC || m is Vala.CreationMethod)) {
                if ((match && name == m.name) || m.name.has_prefix (name)) {
                    list.add (m);
                }
            }
        }

        foreach (var p in intf.get_properties ()) {
            if (p.binding == Vala.MemberBinding.INSTANCE && binding != Vala.MemberBinding.CLASS ||
                binding == Vala.MemberBinding.CLASS && p.binding == Vala.MemberBinding.STATIC) {
                if ((match && name == p.name) || p.name.has_prefix (name)) {
                    list.add (p);
                }
            }
        }

        foreach (var s in intf.get_signals ()) {
            if (binding != Vala.MemberBinding.CLASS) {
                if ((match && name == s.name) || s.name.has_prefix (name)) {
                    list.add (s);
                }
            }
        }

        if (binding == Vala.MemberBinding.INSTANCE) {
            foreach (var dt in intf.get_prerequisites ()) {
                foreach (var sym in gsfm (dt.data_type, name, match, binding)) {
                    list.add (sym);
                }
            }
        }

        return list;
    }
    
    private Gee.List<Vala.Symbol> get_symbols_for_class (Vala.Class klass, string name, bool match, Vala.MemberBinding binding) {
        var list = new Gee.ArrayList<Vala.Symbol>();
        if (binding == Vala.MemberBinding.CLASS) {
            foreach (var cls in klass.get_classes ()) {
                if ((match && name == cls.name) || cls.name.has_prefix (name)) {
                    list.add (cls);
                }
            }

            foreach (var c in klass.get_constants ()) {
                if ((match && name == c.name) || c.name.has_prefix (name)) {
                    list.add (c);
                }
            }

            foreach (var d in klass.get_delegates ()) {
                if ((match && name == d.name) || d.name.has_prefix (name)) {
                    list.add (d);
                }
            }

            foreach (var e in klass.get_enums ()) {
                if ((match && name == e.name) || e.name.has_prefix (name)) {
                    list.add (e);
                }
            }

            foreach (var s in klass.get_structs ()) {
                if ((match && name == s.name) || s.name.has_prefix (name)) {
                    list.add (s);
                }
            }
        }

        foreach (var f in klass.get_fields ()) {
            if (f.binding == Vala.MemberBinding.INSTANCE && binding != Vala.MemberBinding.CLASS ||
                binding == Vala.MemberBinding.CLASS && f.binding == Vala.MemberBinding.STATIC) {
                if ((match && name == f.name) || f.name.has_prefix (name)) {
                    list.add (f);
                }
            }
        }

        foreach (var m in klass.get_methods ()) {
            if (m.binding == Vala.MemberBinding.INSTANCE && binding != Vala.MemberBinding.CLASS && !(m is Vala.CreationMethod) ||
                binding == Vala.MemberBinding.CLASS && (m.binding == Vala.MemberBinding.STATIC || m is Vala.CreationMethod)) {
                if ((match && name == m.name) || m.name.has_prefix (name)) {
                    list.add (m);
                }
            }
        }

        foreach (var p in klass.get_properties ()) {
            if (p.binding == Vala.MemberBinding.INSTANCE && binding != Vala.MemberBinding.CLASS ||
                binding == Vala.MemberBinding.CLASS && p.binding == Vala.MemberBinding.STATIC) {
                if ((match && name == p.name) || p.name.has_prefix (name)) {
                    list.add (p);
                }
            }
        }

        foreach (var s in klass.get_signals ()) {
            if (binding != Vala.MemberBinding.CLASS) {
                if ((match && name == s.name) || s.name.has_prefix (name)) {
                    list.add (s);
                }
            }
        }

        if (binding == Vala.MemberBinding.INSTANCE) {
            foreach (var dt in klass.get_base_types ()) {
                foreach (var sym in gsfm (dt.data_type, name, match, binding)) {
                    list.add (sym);
                }
            }
        }

        return list;
    }
    
    private Gee.List<Vala.Symbol> get_symbols_for_struct (Vala.Struct st, string name, bool match, Vala.MemberBinding binding) {
        var list = new Gee.ArrayList<Vala.Symbol>();
        if (binding == Vala.MemberBinding.CLASS) {
            foreach (var c in st.get_constants ()) {
                if ((match && name == c.name) || c.name.has_prefix (name)) {
                    list.add (c);
                }
            }
        }

        foreach (var f in st.get_fields ()) {
            if (f.binding == Vala.MemberBinding.INSTANCE && binding != Vala.MemberBinding.CLASS ||
                binding == Vala.MemberBinding.CLASS && f.binding == Vala.MemberBinding.STATIC) {
                if ((match && name == f.name) || f.name.has_prefix (name)) {
                    list.add (f);
                }
            }
        }

        foreach (var m in st.get_methods ()) {
            if (m.binding == Vala.MemberBinding.INSTANCE && binding != Vala.MemberBinding.CLASS && !(m is Vala.CreationMethod) ||
                binding == Vala.MemberBinding.CLASS && (m.binding == Vala.MemberBinding.STATIC || m is Vala.CreationMethod)) {
                if ((match && name == m.name) || m.name.has_prefix (name)) {
                    list.add (m);
                }
            }
        }

        foreach (var p in st.get_properties ()) {
            if (p.binding == Vala.MemberBinding.INSTANCE && binding != Vala.MemberBinding.CLASS ||
                binding == Vala.MemberBinding.CLASS && p.binding == Vala.MemberBinding.STATIC) {
                if ((match && name == p.name) || p.name.has_prefix (name)) {
                    list.add (p);
                }
            }
        }

        return list;
    }

    private Vala.SourceFile? get_source_file_for_filename (string filename) {
        foreach (var file in context.get_source_files ()) {
            if (file.filename == filename) {
                return file;
            }
        }

        return null;            
    }

    private Vala.SourceFile? get_source_file_for_document (Scratch.Services.Document document) {
        string? filename = document.file.get_path ();
        if (filename == null) {
            return null;
        }

        return get_source_file_for_filename (filename);
    }

    private void clear_source_file (Vala.SourceFile file) {
        report.reset_file (file);

        var nodes = new Vala.ArrayList<Vala.CodeNode> ();
        foreach (var node in file.get_nodes ()) {
            nodes.add (node);
        }

        // TODO: this segfaults when trying to declare a symbol without an owner in the editor
        lock (context) {
            Vala.CodeContext.push (context);
            var entry_point = file.context.entry_point;
            foreach (var node in nodes) {
                file.remove_node (node);

                if (node is Vala.Symbol) {
                    var symbol = (Vala.Symbol)node;
                    if (symbol.owner != null) {
                        symbol.owner.remove (symbol.name);
                    }

                    symbol.name = null;
                }            
            }   

            if (entry_point != null) {
                file.context.entry_point = null;
            }
            
            Vala.CodeContext.pop ();
        }
    }

    public void update_document_content (Scratch.Services.Document document) {
        var file = get_source_file_for_document (document);
        if (file != null) {
            file.content = document.source_view.buffer.text;
            clear_source_file (file);
        }
    }

    public override void parse () {
        begin_parsing ();
        parsing = true;

        report.clear ();
        lock (context) {
            Vala.CodeContext.push (context);
            int visisted = 0;
            foreach (var file in context.get_source_files ()) {
                if (file.get_nodes ().size == 0) {
                    parser.visit_source_file (file);
                    visisted++;
                }
            }

            if (visisted > 0) {
                context.check ();
                context.analyzer.analyze (context);
            }
            
            Vala.CodeContext.pop ();
        }

        parsing = false;
        Idle.add (() => {
            end_parsing ();
            return false;
        });
    }
}