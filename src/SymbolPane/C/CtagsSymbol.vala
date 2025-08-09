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

public class Scratch.Services.CtagsSymbol : Code.Widgets.SourceList.ExpandableItem, Scratch.Services.SymbolItem {
    public Scratch.Services.Document doc { get; construct set; }
    public SymbolType symbol_type { get; set; default = SymbolType.OTHER; }
    public int line { get; construct set; }

    public CtagsSymbol (
        Scratch.Services.Document doc,
        string name,
        int line,
        Icon? _icon,
        SymbolType? s_type = null) {

        Object (
            doc: doc,
            name: name,
            line: line
        );

        icon = _icon;
        if (s_type != null) {
            symbol_type = s_type;
        }
    }
}
