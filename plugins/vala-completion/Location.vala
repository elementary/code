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


public class Location {
    public int line;
    public int column;

    public Location (int line, int column) {
        this.line = line;
        this.column = column;
    }

    public bool inside (Location begin, Location end) {
        return begin.before (this) && this.before (end);
    }
    
    public bool before (Location other) {
        if (line > other.line) {
            return false;
        }

        if (line == other.line && column > other.column) {
            return false;
        }

        return true;
    }
}
