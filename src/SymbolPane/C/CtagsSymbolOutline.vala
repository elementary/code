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

public class Scratch.Services.CtagsSymbolOutline : Scratch.Services.SymbolOutline {
    private GLib.Subprocess current_subprocess;

    public CtagsSymbolOutline (Scratch.Services.Document _doc) {
        Object (
            orientation: Gtk.Orientation.VERTICAL,
            hexpand: true,
            doc: _doc
        );
    }

    static construct {
        // Array of symbol types that could be assigned to a CtagsSymbol
        // by parse output ()
        filters = {
            SymbolType.CLASS,
            SymbolType.CONSTRUCTOR,
            SymbolType.PROPERTY,
            SymbolType.METHOD,
            SymbolType.STRUCT,
            SymbolType.ENUM,
            SymbolType.CONSTANT
        };
    }
    construct {
        store.item_selected.connect ((selected) => {
            if (selected == null) {
                return;
            }
            doc.goto (((CtagsSymbol)selected).line);
            store.selected = null;
        });
    }

    ~CtagsSymbolOutline () {
        debug ("Destroy Ctags outline");
    }

    public override void parse_symbols () {
        before_parse ();
        if (current_subprocess != null)
            current_subprocess.force_exit ();

        try {
            current_subprocess = new GLib.Subprocess (
                GLib.SubprocessFlags.STDOUT_PIPE | GLib.SubprocessFlags.STDERR_SILENCE,
                "ctags", "-f", "-", "--format=2", "--excmd=n", "--fields=nstK", "--extra=", "--sort=no", doc.file.get_path ()
            );

            parse_output.begin (current_subprocess, (obj, res) => {
                after_parse ();
            });
        } catch (GLib.Error e) {
            critical (e.message);
            after_parse ();
        }
    }

    private async void parse_output (GLib.Subprocess subprocess) {
        var parent_dependent = new Gee.LinkedList<CtagsSymbolIter> ();
        var new_root = new Code.Widgets.SourceList.ExpandableItem (_("Symbols"));

        var datainput = new GLib.DataInputStream (subprocess.get_stdout_pipe ());
        try {
            string symbol;
            while ((symbol = yield datainput.read_line_async ()) != null) {
                if (symbol == "")
                    continue;

                var parts = symbol.split ("\t");
                if (parts.length < 5) {
                    continue;
                }

                var name = parts[0];
                // 1 => filename
                // 2 => line number with weird trailing chars
                var type = parts[3];
                int line = int.parse (parts[4].offset ("line:".length));
                string? parent = null;
                GLib.Icon? parent_icon = null;
                SymbolType? parent_s_type = null;
                if (parts.length > 5 && parts[5] != null) {
                    if ("typeref:" in parts[5]) {
                        parent = parts[5].offset ("typeref:".length);
                    } else if ("class:" in parts[5]) {
                        parent = parts[5].offset ("class:".length);
                        parent_icon = new ThemedIcon ("lang-class");
                        parent_s_type = SymbolType.CLASS;
                    } else if ("struct:" in parts[5]) {
                        parent = parts[5].offset ("struct:".length);
                        parent_icon = new ThemedIcon ("lang-struct");
                        parent_s_type = SymbolType.STRUCT;
                    } else if ("enum:" in parts[5]) {
                        parent = parts[5].offset ("enum:".length);
                        parent_icon = new ThemedIcon ("lang-enum");
                        parent_s_type = SymbolType.ENUM;
                    }
                }

                Icon? icon = null;
                SymbolType? s_type = null;
                switch (type) {
                    case "class":
                        icon = new ThemedIcon ("lang-class");
                        s_type = SymbolType.CLASS;
                        break;
                    case "struct":
                        icon = new ThemedIcon ("lang-struct");
                        s_type = SymbolType.STRUCT;
                        break;
                    case "field":
                    case "member":
                    case "variable":
                        icon = new ThemedIcon ("lang-property");
                        s_type = SymbolType.PROPERTY;
                        break;
                    case "enum":
                    case "enumerator":
                        icon = new ThemedIcon ("lang-enum");
                        s_type = SymbolType.ENUM;
                        break;
                    case "macro":
                    case "constant":
                    case "typedef":
                        icon = new ThemedIcon ("lang-constant");
                        s_type = SymbolType.CONSTANT;
                        break;
                    case "constructor":
                        icon = new ThemedIcon ("lang-constructor");
                        s_type = SymbolType.CONSTRUCTOR;
                        break;
                    case "destructor":
                    case "method":
                    case "function":
                        icon = new ThemedIcon ("lang-method");
                        s_type = SymbolType.METHOD;
                        break;
                    case "namespace":
                        icon = new ThemedIcon ("lang-namespace");
                        s_type = SymbolType.NAMESPACE;
                        break;
                    case "package":
                        break;
                    case "property":
                        icon = new ThemedIcon ("lang-property");
                        s_type = SymbolType.PROPERTY;
                        break;
                }

                if (parent == null) {
                    var s = new CtagsSymbol (
                        doc,
                        name,
                        line,
                        icon,
                        s_type
                    );
                    new_root.add (s);
                } else {
                    parent_dependent.add (new CtagsSymbolIter (
                        name,
                        parent,
                        line,
                        parent_icon,
                        parent_s_type
                    ));
                }
            }
        } catch (Error e) {
            critical (e.message);
            return;
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
                    parent.add (new CtagsSymbol (
                        doc,
                        i.name,
                        i.line,
                        i.icon,
                        i.symbol_type
                    ));
                    iter.remove ();
                } else {
                    if (":" in i.parent) {
                        var parent_parts = i.parent.split (":", 2);
                        parent = find_existing (parent_parts[1], new_root);
                        if (parent != null) {
                            parent.name = i.name;
                            switch (parent_parts[0]) {
                                case "class":
                                    parent.icon = new ThemedIcon ("lang-class");
                                    break;
                                case "struct":
                                    parent.icon = new ThemedIcon ("lang-struct");
                                    break;
                                case "enum":
                                    parent.icon = new ThemedIcon ("lang-enum");
                                    break;
                            }
                            iter.remove ();
                            continue;
                        }
                    }
                    // anonymous enum
                    if (i.parent.has_prefix ("__anon")) {
                        var e = new CtagsSymbol (
                            doc,
                            i.parent,
                            i.line - 1,
                            new ThemedIcon ("lang-enum"),
                            SymbolType.ENUM
                        );
                        new_root.add (e);

                        e.add (new CtagsSymbol (
                            doc,
                            i.name,
                            i.line,
                            i.icon,
                            i.symbol_type
                        ));
                        iter.remove ();
                    }
                }
            }
        }

        // just add the rest
        foreach (var symbol in parent_dependent) {
            new_root.add (new CtagsSymbol (
                doc,
                symbol.name,
                symbol.line,
                symbol.icon,
                symbol.symbol_type
            ));
        }

        Idle.add (() => {
            double adjustment_value = store.vadjustment.value;
            store.root.clear ();
            store.root.add (new_root);
            store.root.expand_all ();
            store.vadjustment.set_value (adjustment_value);

            destroy_root (root);
            root = new_root;

            add_tooltips (store.root);
            return false;
        });
    }

    protected override void add_tooltips (Code.Widgets.SourceList.ExpandableItem root) {
        foreach (var parent in root.children) {
            if (parent is Code.Widgets.SourceList.ExpandableItem) {
                add_tooltip ((Code.Widgets.SourceList.ExpandableItem) parent);
            }
        }
    }

    private void add_tooltip (Code.Widgets.SourceList.ExpandableItem parent) {
        if (parent is CtagsSymbol) {
            var item = ((CtagsSymbol)parent);
            var start = item.line;
            var end = item.line;
            // The type of a method is often on the previous line
            if (item.symbol_type == SymbolType.METHOD) {
                start = start > 0 ? start - 1 : start;
            }

            item.tooltip = Markup.escape_text ("%s".printf (
                doc.get_slice (
                    start,
                    0,
                    end,
                    0
                )
            ));
        }

        add_tooltips (parent);
    }

    private void destroy_root (Code.Widgets.SourceList.ExpandableItem to_destroy) {
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

    private Gee.TreeSet<CtagsSymbol> iterate_children (Code.Widgets.SourceList.ExpandableItem parent) {
        var result = new Gee.TreeSet<CtagsSymbol> ();
        foreach (var child in parent.children) {
            result.add_all (iterate_children ((CtagsSymbol)child));
        }
        return result;
    }

    CtagsSymbol? find_existing (string name, Code.Widgets.SourceList.ExpandableItem parent) {
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
}
