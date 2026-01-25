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

public class Scratch.Services.ValaSymbolItem : Code.Widgets.SourceList.ExpandableItem, Code.Widgets.SourceListSortable, Scratch.Services.SymbolItem {
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
                name = klass;
            } else {
                name = "%s.%s".printf (klass, symbol.name);
            }
        } else {
            name = symbol.name;
        }

        if (symbol is Vala.Struct) {
            icon = new ThemedIcon ("lang-struct");
            symbol_type = SymbolType.STRUCT;
        } else if (symbol is Vala.Class) {
            if (((Vala.Class) symbol).is_abstract) {
                icon = new ThemedIcon ("lang-class-abstract");
            } else {
                icon = new ThemedIcon ("lang-class");
            }

            symbol_type = SymbolType.CLASS;
        } else if (symbol is Vala.Constant) {
            icon = new ThemedIcon ("lang-constant");
            symbol_type = SymbolType.CONSTANT;
        } else if (symbol is Vala.Enum) {
            icon = new ThemedIcon ("lang-enum");
            symbol_type = SymbolType.ENUM;
        } else if (symbol is Vala.Field) {
            icon = new ThemedIcon ("lang-property");
            symbol_type = SymbolType.PROPERTY;
        } else if (symbol is Vala.Interface) {
            icon = new ThemedIcon ("lang-interface");
            symbol_type = SymbolType.INTERFACE;
        } else if (symbol is Vala.Property) {
            if (((Vala.Property) symbol).is_abstract) {
                icon = new ThemedIcon ("lang-property-abstract");
            } else if (((Vala.Property) symbol).is_virtual) {
                icon = new ThemedIcon ("lang-property-virtual");
            } else {
                icon = new ThemedIcon ("lang-property");
            }

            symbol_type = SymbolType.PROPERTY;
        } else if (symbol is Vala.Signal) {
            icon = new ThemedIcon ("lang-signal");
            symbol_type = SymbolType.SIGNAL;
        } else if (symbol is Vala.CreationMethod) {
            icon = new ThemedIcon ("lang-constructor");
            symbol_type = SymbolType.CONSTRUCTOR;
        } else if (symbol is Vala.Method) {
            if (((Vala.Method) symbol).is_abstract) {
                icon = new ThemedIcon ("lang-method-abstract");
            } else if (((Vala.Method) symbol).is_virtual) {
                icon = new ThemedIcon ("lang-method-virtual");
            } else if (((Vala.Method) symbol).binding == Vala.MemberBinding.STATIC) {
                icon = new ThemedIcon ("lang-method-static");
            } else {
                icon = new ThemedIcon ("lang-method");
            }

            symbol_type = SymbolType.METHOD;
        } else if (symbol is Vala.Namespace) {
            icon = new ThemedIcon ("lang-namespace");
            symbol_type = SymbolType.NAMESPACE;
        } else if (symbol is Vala.ErrorDomain) {
            icon = new ThemedIcon ("lang-errordomain");
        } else if (symbol is Vala.Delegate) {
            icon = new ThemedIcon ("lang-delegate");
        } else {
            warning (symbol.type_name);
        }
    }

    ~ValaSymbolItem () {
        debug ("Destroy Vala symbol");
    }

    public int compare (Code.Widgets.SourceList.Item a, Code.Widgets.SourceList.Item b) {
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
