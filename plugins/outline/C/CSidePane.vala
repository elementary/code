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

public class Code.Plugins.Outline.CSidePane : Code.Plugins.Outline.SidePane {
    private Granite.Widgets.SourceList.ExpandableItem root;
    private GLib.Cancellable cancellable;

    public CSidePane (Scratch.Services.Document doc) {
        Object (doc: doc);
    }

    construct {
        root = new Granite.Widgets.SourceList.ExpandableItem (_("Symbols"));
        store.root.add (root);

        fetching = true;
        parse_symbols ();
        doc.doc_saved.connect (() => parse_symbols ());
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
            var parent_dependent = new Gee.LinkedList<Outline.CSymbolItem> ();
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

                Outline.SourceSymbol.Type symbol_type = Outline.SourceSymbol.Type.CONSTANT;
                switch (type) {
                    case "class":
                        symbol_type = Outline.SourceSymbol.Type.CLASS;
                        break;
                    case "struct":
                        symbol_type = Outline.SourceSymbol.Type.STRUCT;
                        break;
                    case "field":
                    case "enumerator":
                    case "member":
                    case "variable":
                    case "property":
                        symbol_type = Outline.SourceSymbol.Type.PROPERTY;
                        break;
                    case "enum":
                        symbol_type = Outline.SourceSymbol.Type.ENUM;
                        break;
                    case "macro":
                    case "constant":
                    case "typedef":
                        symbol_type = Outline.SourceSymbol.Type.CONSTANT;
                        break;
                    case "constructor":
                        symbol_type = Outline.SourceSymbol.Type.CONSTRUCTOR;
                        break;
                    case "destructor":
                    case "method":
                    case "function":
                        symbol_type = Outline.SourceSymbol.Type.METHOD;
                        break;
                    case "package":
                    case "namespace":
                        symbol_type = Outline.SourceSymbol.Type.NAMESPACE;
                        break;
                }

                var source_symbol = new Outline.CSymbolItem (name, parent, line, symbol_type);
                if (parent == null) {
                    new_root.add (source_symbol);
                } else
                    parent_dependent.add (source_symbol);
            }

            var found_something = true;
            while (found_something && parent_dependent.size > 0) {
                found_something = false;
                var iter = parent_dependent.iterator ();
                while (iter.has_next ()) {
                    iter.next ();
                    var i = iter.get ();
                    var parent = find_existing (i.parent_name, new_root);
                    if (parent != null) {
                        found_something = true;
                        parent.add (i);
                        iter.remove ();
                    } else {
                        // anonymous enum
                        if (i.parent_name.substring (0, 6) == "__anon") {
                            var i_parent = new Outline.CSymbolItem (i.parent_name, i.parent_name, i.line - 1, Outline.SourceSymbol.Type.ENUM);
                            new_root.add (i_parent);
                            i_parent.add (i);
                            iter.remove ();
                        }
                    }
                }
            }

            // just add the rest
            foreach (var symbol in parent_dependent) {
                new_root.add (symbol);
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

    private Gee.TreeSet<Outline.CSymbolItem> iterate_children (Granite.Widgets.SourceList.ExpandableItem parent) {
        var result = new Gee.TreeSet<Outline.CSymbolItem> ();
        foreach (var child in parent.children) {
            result.add_all (iterate_children ((Outline.CSymbolItem)child));
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

    Outline.CSymbolItem? find_existing (string name, Granite.Widgets.SourceList.ExpandableItem parent) {
        Outline.CSymbolItem match = null;
        foreach (var child in parent.children) {
            var child_symbol = child as Outline.CSymbolItem;
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
}
