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

public class Code.Plugins.Outline.CSymbolItem : Code.Plugins.Outline.SourceSymbol {
    public string? parent_name { get; construct; }

    public CSymbolItem (string name, string? parent_name, int line, SourceSymbol.Type symbol_type) {
        Object (
            name: name,
            line: line,
            parent_name: parent_name,
            symbol_type: symbol_type
        );
    }
}
