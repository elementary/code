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

public class Scratch.Services.ValaSymbolItem : Granite.TreeListItem, Scratch.Services.SymbolItem {
    public Vala.Symbol symbol { get; construct; }
    public SymbolType symbol_type { get; set; default = SymbolType.OTHER; }
    public ValaSymbolItem (Vala.Symbol symbol, string _tooltip) {
        Object (
            symbol: symbol,
            tooltip: _tooltip
        );
    }

    construct {
        if (symbol is Vala.CreationMethod) {
            var klass = ((Vala.CreationMethod)symbol).class_name;
            if (symbol.name == ".new") {
                text = klass;
            } else {
                text = "%s.%s".printf (klass, symbol.name);
            }
        } else {
            text = symbol.name;
        }

        if (symbol is Vala.Struct) {
            icon_name = "lang-struct";
            // icon_name = "lang-struct");
            symbol_type = SymbolType.STRUCT;
        } else if (symbol is Vala.Class) {
            if (((Vala.Class) symbol).is_abstract) {
                // icon_name = "lang-class-abstract");
                icon_name = "lang-class-abstract";
            } else {
                icon_name = "lang-class";
            }

            symbol_type = SymbolType.CLASS;
        } else if (symbol is Vala.Constant) {
            icon_name = "lang-constant";
            symbol_type = SymbolType.CONSTANT;
        } else if (symbol is Vala.Enum) {
            icon_name = "lang-enum";
            symbol_type = SymbolType.ENUM;
        } else if (symbol is Vala.Field) {
            icon_name = "lang-property";
            symbol_type = SymbolType.PROPERTY;
        } else if (symbol is Vala.Interface) {
            icon_name = "lang-interface";
            symbol_type = SymbolType.INTERFACE;
        } else if (symbol is Vala.Property) {
            if (((Vala.Property) symbol).is_abstract) {
                icon_name = "lang-property-abstract";
            } else if (((Vala.Property) symbol).is_virtual) {
                icon_name = "lang-property-virtual";
            } else {
                icon_name = "lang-property";
            }

            symbol_type = SymbolType.PROPERTY;
        } else if (symbol is Vala.Signal) {
            icon_name = "lang-signal";
            symbol_type = SymbolType.SIGNAL;
        } else if (symbol is Vala.CreationMethod) {
            icon_name = "lang-constructor";
            symbol_type = SymbolType.CONSTRUCTOR;
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

            symbol_type = SymbolType.METHOD;
        } else if (symbol is Vala.Namespace) {
            icon_name = "lang-namespace";
            symbol_type = SymbolType.NAMESPACE;
        } else if (symbol is Vala.ErrorDomain) {
            icon_name = "lang-errordomain";
        } else if (symbol is Vala.Delegate) {
            icon_name = "lang-delegate";
        } else {
            warning (symbol.type_name);
        }

        warning ("new symbol text %s", text);
    }

    ~ValaSymbolItem () {
        debug ("Destroy Vala symbol");
    }

    public int compare (Granite.TreeListItem a, Granite.TreeListItem b) {
        return ValaComparison.sort_function (a, b);
    }

    public bool allow_dnd_sorting () {
        return false;
    }

    public bool compare_symbol (Vala.Symbol comp_symbol) {
        if (comp_symbol.name != symbol.name)
            return false;

        Vala.Symbol comp_parent = comp_symbol.parent_symbol;
        for (var parent = symbol.parent_symbol; parent != null; parent = parent.parent_symbol) {
            comp_parent = comp_parent.parent_symbol;
            if (comp_parent == null)
                return false;

            if (comp_parent.name != parent.name)
                return false;
        }

        if (comp_parent.parent_symbol != null)
            return false;

        return true;
    }
}
