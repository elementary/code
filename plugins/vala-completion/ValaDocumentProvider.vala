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

public class ValaDocumentProvider : Object, Gtk.SourceCompletionProvider {
    public class SymbolItem : Gtk.SourceCompletionItem {
        public Vala.Symbol symbol { get; construct; }
        public string definition { get; construct; }

        construct {
            if (symbol is Vala.Struct) {
                icon_name = "lang-struct";
            } else if (symbol is Vala.Class) {
                if (((Vala.Class) symbol).is_abstract) {
                    icon_name = "lang-class-abstract";
                } else {
                    icon_name = "lang-class";
                }
            } else if (symbol is Vala.Constant) {
                icon_name = "lang-constant";
            } else if (symbol is Vala.Enum) {
                icon_name = "lang-enum";
            } else if (symbol is Vala.Field) {
                icon_name = "lang-property";
            } else if (symbol is Vala.Interface) {
                icon_name = "lang-interface";
            } else if (symbol is Vala.Property) {
                if (((Vala.Property) symbol).is_abstract) {
                    icon_name = "lang-property-abstract";
                } else if (((Vala.Property) symbol).is_virtual) {
                    icon_name = "lang-property-virtual";
                } else {
                    icon_name = "lang-property";
                }
            } else if (symbol is Vala.Signal) {
                icon_name = "lang-signal";
            } else if (symbol is Vala.CreationMethod) {
                icon_name = "lang-constructor";
            } else if (symbol is Vala.Method) {
                if (((Vala.Method) symbol).is_abstract) {
                    icon_name = "lang-method-abstract";
                } else if (((Vala.Method) symbol).is_virtual) {
                    icon_name = "lang-method-virtual";
                } else if (((Vala.Method) symbol).binding == Vala.MemberBinding.STATIC) {
                    icon_name = "lang-method-static";
                } else {
                    icon_name = "lang-method";
                }
            } else if (symbol is Vala.Namespace) {
                icon_name = "lang-namespace";
            } else if (symbol is Vala.ErrorDomain) {
                icon_name = "lang-error-domain";
            } else if (symbol is Vala.Delegate) {
                icon_name = "lang-delegate";
            }

            label = symbol.name;
            text = symbol.name;
        }

        public SymbolItem (Vala.Symbol symbol, string definition) {
            Object (symbol: symbol, definition: definition);
        }
    }

    private ValaCodeParser code_parser { get; private set; }
    private unowned Scratch.MainWindow window;

    private SymbolDocumentationView symbol_docview;

    private static Regex member_access;
    private static Regex member_access_split;

    private Gee.Set<Vala.Symbol?>? symbols = null;
    private List<Gtk.SourceCompletionProposal> list;

    static construct {
        try {
            member_access = new Regex ("""((?:\w+(?:\s*\([^()]*\))?\.)*)(\w*)$""");
            member_access_split = new Regex ("""(\s*\([^()]*\))?\.""");
        } catch (RegexError e) {
            warning (e.message);
        }        
    }

    construct {
        symbol_docview = new SymbolDocumentationView ();
        symbol_docview.show_all ();
    }

    public ValaDocumentProvider (Scratch.MainWindow window, ValaCodeParser code_parser) {
        this.window = window;
        this.code_parser = code_parser;
    }

    public string get_name () {
        return _("Vala Completion");
    }

    public bool match (Gtk.SourceCompletionContext context) {
        return true;
    }

    public void populate (Gtk.SourceCompletionContext context) {
        Gtk.TextIter iter;
        Gtk.TextIter begin = Gtk.TextIter ();

        var document = window.get_current_document ();
        if (document == null) {
            context.add_proposals (this, null, true);
            return;
        }

        if (!context.get_iter (out iter)) {
            context.add_proposals (this, null, true);
            return;
        }
        
        begin.assign (iter);
        begin.set_line_offset (0);

        list = new List<Gtk.SourceCompletionProposal> ();
        var cancellable = new GLib.Cancellable ();
        context.cancelled.connect (() => cancellable.cancel ());

        string? line = begin.get_slice (iter);
        if (line == null) {
            context.add_proposals (this, null, true);
            return;
        }

        MatchInfo match_info;
        if (!member_access.match (line, 0, out match_info)) {
            context.add_proposals (this, null, true);
            return;
        }

        if (match_info.fetch (0).length < 2) {
            context.add_proposals (this, null, true);
            return;
        }

        string[] names = new string[0];
        foreach (string name in member_access_split.split (match_info.fetch (0))) {

            if (name[0] != '(') {
                names += name;
            }
        }

        string? prefix = match_info.fetch (2);
        if (prefix != null) {
            names += prefix;
        }

        if (names.length == 0) {
            context.add_proposals (this, null, true);
            return;
        }

        new Thread<void*> ("completion", () => {
            code_parser.parse ();

            symbols = code_parser.lookup_visible_symbols_at (document.file.get_path (), iter.get_line () + 1, iter.get_line_offset ());

            var matched = new Gee.ArrayList<Vala.Symbol> ();
            foreach (var symbol in symbols) {
                if (symbol != null && symbol.name.has_prefix (names[0])) {
                    matched.add (symbol);
                }
            }

            for (int i = 1; i < names.length; i++) {
                Vala.Symbol? current = null;
                foreach (var sym in matched) {
                    if (sym.name == names[i - 1]) {
                        current = sym;
                        break;
                    }
                }

                if (current == null) {
                    break;
                }

                matched.clear ();
                code_parser.get_symbols_for_name (current, names[i], false).foreach (symbol => {
                    matched.add (symbol);
                    return true;
                });
            }

            foreach (var symbol in matched) {
                string definition = code_parser.write_symbol_definition (symbol);
                list.append (new SymbolItem (symbol, definition));
            }

            list.sort ((a, b) => {
                var sym_a = ((SymbolItem)a).symbol;
                var sym_b = ((SymbolItem)b).symbol;
                if (sym_a.name == null || sym_b == null) {
                    return 0;
                }

                return strcmp (sym_a.name, sym_b.name);
            });

            Idle.add (() => {
                if (!cancellable.is_cancelled ()) {
                    context.add_proposals (this, list, true);
                }

                return false;
            });

            return null;
        });
    }    

    public unowned Gtk.Widget? get_info_widget (Gtk.SourceCompletionProposal proposal) {
        var symbol_item = (SymbolItem)proposal;
        string definition = symbol_item.definition;

        if (symbol_item.symbol.external_package) {
            symbol_docview.symbol = symbol_item.symbol;
        }

        return definition != "" ? symbol_docview : null;
    }

    public int get_priority () {
        return 200;
    }

    public Gtk.SourceCompletionActivation get_activation () {
        return Gtk.SourceCompletionActivation.INTERACTIVE | Gtk.SourceCompletionActivation.USER_REQUESTED;
    }
}
