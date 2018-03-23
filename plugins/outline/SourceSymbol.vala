/*-
 * Copyright (c) 2018 elementary LLC. (https://elementary.io)
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

public class Code.Plugins.Outline.SourceSymbol : Granite.Widgets.SourceList.ExpandableItem, Granite.Widgets.SourceListSortable {
    public enum Type {
        STRUCT,
        CLASS,
        ABSTRACT_CLASS,
        CONSTANT,
        ENUM,
        PROPERTY,
        INTERFACE,
        ABSTRACT_PROPERTY,
        VIRTUAL_PROPERTY,
        SIGNAL,
        CONSTRUCTOR,
        ABSTRACT_METHOD,
        VIRTUAL_METHOD,
        STATIC_METHOD,
        METHOD,
        NAMESPACE,
        ERRORDOMAIN,
        DELEGATE;

        public int get_weight () {
            switch (this) {
                case NAMESPACE:
                    return 17;
                case ENUM:
                    return 16;
                case CONSTANT:
                    return 15;
                case INTERFACE:
                    return 14;
                case CLASS:
                    return 13;
                case ABSTRACT_CLASS:
                    return 13;
                case STRUCT:
                    return 12;
                case PROPERTY:
                    return 11;
                case ABSTRACT_PROPERTY:
                    return 11;
                case VIRTUAL_PROPERTY:
                    return 11;
                case CONSTRUCTOR:
                    return 10;
                case ABSTRACT_METHOD:
                    return 9;
                case VIRTUAL_METHOD:
                    return 9;
                case STATIC_METHOD:
                    return 9;
                case METHOD:
                    return 9;
                case SIGNAL:
                    return 8;
                case ERRORDOMAIN:
                    return 7;
                case DELEGATE:
                    return 6;
            }

            return 0;
        }

        public GLib.Icon get_icon () {
            switch (this) {
                case STRUCT:
                    return new ThemedIcon ("lang-struct");
                case CLASS:
                    return new ThemedIcon ("lang-class");
                case ABSTRACT_CLASS:
                    return new ThemedIcon ("lang-class-abstract");
                case CONSTANT:
                    return new ThemedIcon ("lang-constant");
                case ENUM:
                    return new ThemedIcon ("lang-enum");
                case PROPERTY:
                    return new ThemedIcon ("lang-property");
                case INTERFACE:
                    return new ThemedIcon ("lang-interface");
                case ABSTRACT_PROPERTY:
                    return new ThemedIcon ("lang-property-abstract");
                case VIRTUAL_PROPERTY:
                    return new ThemedIcon ("lang-property-virtual");
                case SIGNAL:
                    return new ThemedIcon ("lang-signal");
                case CONSTRUCTOR:
                    return new ThemedIcon ("lang-constructor");
                case ABSTRACT_METHOD:
                    return new ThemedIcon ("lang-method-abstract");
                case VIRTUAL_METHOD:
                    return new ThemedIcon ("lang-method-virtual");
                case STATIC_METHOD:
                    return new ThemedIcon ("lang-method-static");
                case METHOD:
                    return new ThemedIcon ("lang-method");
                case NAMESPACE:
                    return new ThemedIcon ("lang-namespace");
                case ERRORDOMAIN:
                    return new ThemedIcon ("lang-errordomain");
                case DELEGATE:
                    return new ThemedIcon ("lang-delegate");
            }

            return new ThemedIcon ("lang-constant");
        }
    }

    public int line { get; construct set; }
    private SourceSymbol.Type _symbol_type;
    public SourceSymbol.Type symbol_type {
        get {
            return _symbol_type;
        }
        set {
            _symbol_type = value;
            icon = value.get_icon ();
            notify_property ("weight");
        }
    }

    public int weight {
        get {
            return symbol_type.get_weight ();
        }
    }

    public int compare (Granite.Widgets.SourceList.Item a, Granite.Widgets.SourceList.Item b) {
        var source_a = a as SourceSymbol;
        var source_b = b as SourceSymbol;
        int res = source_b.weight - source_a.weight;
        if (res != 0) {
            return res;
        }

        res = a.name.collate (b.name);
        if (res != 0) {
            return res;
        }

        return source_a.line - source_b.line;
    }

    public bool allow_dnd_sorting () {
        return false;
    }
}
