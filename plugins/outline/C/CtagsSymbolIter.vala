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

public class Code.Plugins.CtagsSymbolIter : Object {
    public string name { get; construct set; }
    public string parent { get; construct set; }
    public int line { get; construct set; }
    public Icon? icon { get; construct set; }

    public CtagsSymbolIter (string name, string parent, int line, Icon? icon) {
        Object(name: name, parent: parent, line: line, icon: icon);
    }
}
