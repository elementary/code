/*-
 * Copyright (c) 2017-2025 elementary LLC. (https://elementary.io)
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
    public const int PARSE_TIME_MAX_MSEC = 5000;
    private Code.Plugins.ValaSymbolResolver resolver;
    private Vala.Parser parser;
    private GLib.Cancellable cancellable;
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
        parser = new Vala.Parser ();
        resolver = new Code.Plugins.ValaSymbolResolver ();

        item_activated.connect ((item) => {
            doc.goto (((ValaSymbolItem)item).symbol.source_reference.begin.line);
        });

        doc.doc_closed.connect (doc_closed);
    }

    ~ValaSymbolOutline () {
        debug ("Destroy symbol out line");
    }

    void doc_closed (Scratch.Services.Document doc) {
        doc.doc_closed.disconnect (doc_closed);
        if (cancellable != null) {
            cancellable.cancel ();
            cancellable = null;
        }
    }

    private uint parse_timeout_id = 0;
    public override void parse_symbols () {
        before_parse ();
        var context = new Vala.CodeContext ();
#if VALA_0_50
        context.set_target_profile (Vala.Profile.GOBJECT, false);
#else
        context.profile = Vala.Profile.GOBJECT;
#endif
        context.add_source_filename (doc.file.get_path ());
        context.report = new Report ();
        if (cancellable != null && !cancellable.is_cancelled ()) {
            cancellable.cancel ();
        }

        cancellable = new GLib.Cancellable ();
        new Thread<void*> ("parse-symbols", () => {
            Vala.CodeContext.push (context);
            parser.parse (context);
            resolver.clear ();
            resolver.resolve (context);
            Vala.CodeContext.pop ();

            parse_timeout_id = Timeout.add_full (Priority.LOW, PARSE_TIME_MAX_MSEC, () => {
                parse_timeout_id = 0;
                took_too_long = true;
                cancellable.cancel ();
                return Source.REMOVE;
            });

            var new_root = construct_tree (cancellable);
            if (parse_timeout_id > 0) {
                Source.remove (parse_timeout_id);
            }

            if (!cancellable.is_cancelled () || took_too_long) {
                Idle.add (() => {
                    double adjustment_value = vadjustment.value;
                    // var root_children = root.children; // Keep reference to children for later destruction
                    // root.clear (); // This does not destroy children but disconnects signals - avoids terminal warnings
                    // foreach (var child in root_children) { // Destroy items after clearing list to avoid memory leak
                    //     destroy_all_children ((Code.TreeListItem)child);
                    // }

                    remove_all ();
                    // if (took_too_long) {
                    //     var warning_item = new Code.Widgets.SourceList.Item () {
                    //         icon = new ThemedIcon ("dialog-warning"),
                    //         markup = "<big>%s</big>".printf (_("Too Many Symbols")),
                    //         tooltip = _("%s contains too many Vala symbols.\nParsing and showing them took too long.").printf (doc.file.get_basename ()),
                    //         selectable = false
                    //     };

                    //     root.add (warning_item);
                    // } else {
                        add_root_item (new_root);
                    // }

                    // root.expand_all ();
                    // add_tooltips (root);
                    // vadjustment.set_value (adjustment_value);
                    return Source.REMOVE;
                });
            }

            after_parse ();
            return null;
        });
    }

    protected override void add_tooltips (Code.TreeListItem? root = null) {
        iterate_children (root, (child) => {
            add_tooltip ((Code.TreeListItem) parent);
            return Code.TreeList.ITERATE_CONTINUE;
        });
    }

    private void add_tooltip (Code.TreeListItem parent) {
        if (parent is ValaSymbolItem) {
            var item = ((ValaSymbolItem)parent);
            var symbol = item.symbol;
            item.tooltip = "%s%s".printf (
                doc.get_slice (
                    symbol.source_reference.begin.line,
                    symbol.source_reference.begin.column,
                    symbol.source_reference.end.line,
                    symbol.source_reference.end.column
                ),
                symbol.comment != null ? "\n" + symbol.comment.content : ""
            );
        }

        add_tooltips (parent);
    }

    // private void destroy_all_children (Code.TreeListItem parent) {
    //     foreach (var child in parent.children) {
    //         remove (child, parent);
    //     }
    // }

    // private new void remove (Code.Widgets.SourceList.Item item, Code.TreeListItem parent) {
    //     if (item is Code.TreeListItem) {
    //         destroy_all_children ((Code.TreeListItem)item);
    //     }

    //     parent.remove (item);
    // }

    // Called from separate thread
    private Code.TreeListItem construct_tree (GLib.Cancellable cancellable) {
        var fields = resolver.get_properties_fields ();
        var symbols = resolver.get_symbols ();
        // Remove fake fields created by the vala parser.
        symbols.remove_all (fields);

        var new_root = new Code.TreeListItem () { text = _("Symbols") };
        new_root.tooltip = _("Vala symbols found in %s").printf (doc.file.get_basename ());
        foreach (var symbol in symbols) {
            if (cancellable.is_cancelled ())
                break;


            if (symbol.name == null)
                continue;

            construct_child (symbol, new_root, cancellable);
            if (!cancellable.is_cancelled ()) {
                Thread.yield ();
            }
        }

        return new_root;
    }

    private ValaSymbolItem construct_child (
        Vala.Symbol symbol,
        Code.TreeListItem given_parent,
        GLib.Cancellable cancellable
    ) {

        Code.TreeListItem parent;
        if (symbol.scope.parent_scope.owner.name == null)
            parent = given_parent;
        else
            parent = find_existing (symbol.scope.parent_scope.owner, given_parent, cancellable);

        if (parent == null) {
            parent = construct_child (symbol.scope.parent_scope.owner, given_parent, cancellable);
        }


        var tree_child = new ValaSymbolItem (
            symbol,
            ""
        );

        parent.add_child (tree_child);
        return tree_child;
    }

    ValaSymbolItem? find_existing (Vala.Symbol symbol, Code.TreeListItem parent, GLib.Cancellable cancellable) {
        ValaSymbolItem match = null;
        iterate_children (null, (_child) => {
            if (cancellable.is_cancelled ()) {
                return Code.TreeList.ITERATE_STOP;
            }

            var child = _child as ValaSymbolItem;
            if (child == null) {
                return Code.TreeList.ITERATE_CONTINUE;
            }

            if (child.symbol == symbol) {
                match = child;
                return Code.TreeList.ITERATE_STOP;
            } else {
                var res = find_existing (symbol, child, cancellable);
                if (res != null) {
                    match = res;
                    return Code.TreeList.ITERATE_STOP;
                }
            }

            return Code.TreeList.ITERATE_CONTINUE;
        });

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
