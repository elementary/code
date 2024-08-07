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
    public Vala.Symbol symbol { get; set; }
    public SymbolType symbol_type { get; set; default = SymbolType.OTHER; }
    public ValaSymbolItem (Vala.Symbol symbol) {
        this.symbol = symbol;
        this.name = symbol.name;
        if (symbol is Vala.CreationMethod) {
            if (symbol.name == ".new")
                this.name = ((Vala.CreationMethod)symbol).class_name;
            else
                this.name = "%s.%s".printf (((Vala.CreationMethod)symbol).class_name, symbol.name);
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
