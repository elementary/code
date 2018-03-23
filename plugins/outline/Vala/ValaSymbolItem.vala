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

public class Code.Plugins.Outline.ValaSymbolItem : Code.Plugins.Outline.SourceSymbol {
    public Vala.Symbol symbol { get; construct; }

    public ValaSymbolItem (Vala.Symbol symbol) {
        Object (symbol: symbol);
    }

    construct {
        line = symbol.source_reference.begin.line;
        name = symbol.name;
        if (symbol is Vala.CreationMethod) {
            if (symbol.name == ".new") {
                name = ((Vala.CreationMethod)symbol).class_name;
            } else {
                name = "%s.%s".printf (((Vala.CreationMethod)symbol).class_name, symbol.name);
            }
        }

        if (symbol is Vala.Struct) {
            symbol_type = Outline.SourceSymbol.Type.STRUCT;
        } else if (symbol is Vala.Class) {
            if (((Vala.Class) symbol).is_abstract) {
                symbol_type = Outline.SourceSymbol.Type.ABSTRACT_CLASS;
            } else {
                symbol_type = Outline.SourceSymbol.Type.CLASS;
            }
        } else if (symbol is Vala.Constant) {
            symbol_type = Outline.SourceSymbol.Type.CONSTANT;
        } else if (symbol is Vala.Enum) {
            symbol_type = Outline.SourceSymbol.Type.ENUM;
        } else if (symbol is Vala.Field) {
            symbol_type = Outline.SourceSymbol.Type.PROPERTY;
        } else if (symbol is Vala.Interface) {
            symbol_type = Outline.SourceSymbol.Type.INTERFACE;
        } else if (symbol is Vala.Property) {
            if (((Vala.Property) symbol).is_abstract) {
                symbol_type = Outline.SourceSymbol.Type.ABSTRACT_PROPERTY;
            } else if (((Vala.Property) symbol).is_virtual) {
                symbol_type = Outline.SourceSymbol.Type.VIRTUAL_PROPERTY;
            } else {
                symbol_type = Outline.SourceSymbol.Type.PROPERTY;
            }
        } else if (symbol is Vala.Signal) {
            symbol_type = Outline.SourceSymbol.Type.SIGNAL;
        } else if (symbol is Vala.CreationMethod) {
            symbol_type = Outline.SourceSymbol.Type.CONSTRUCTOR;
        } else if (symbol is Vala.Method) {
            if (((Vala.Method) symbol).is_abstract) {
                symbol_type = Outline.SourceSymbol.Type.ABSTRACT_METHOD;
            } else if (((Vala.Method) symbol).is_virtual) {
                symbol_type = Outline.SourceSymbol.Type.VIRTUAL_METHOD;
            } else if (((Vala.Method) symbol).binding == Vala.MemberBinding.STATIC) {
                symbol_type = Outline.SourceSymbol.Type.STATIC_METHOD;
            } else {
                symbol_type = Outline.SourceSymbol.Type.METHOD;
            }
        } else if (symbol is Vala.Namespace) {
            symbol_type = Outline.SourceSymbol.Type.NAMESPACE;
        } else if (symbol is Vala.ErrorDomain) {
            symbol_type = Outline.SourceSymbol.Type.ERRORDOMAIN;
        } else if (symbol is Vala.Delegate) {
            symbol_type = Outline.SourceSymbol.Type.DELEGATE;
        } else {
            warning (symbol.type_name);
        }
    }
}
