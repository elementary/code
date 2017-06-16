/*-
 * Copyright (c) 2017 elementary LLC. (https://elementary.io),
 *               2013 Julien Spautz <spautz.julien@gmail.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License version 3
 * as published by the Free Software Foundation, either version 3 of the 
 * License, or (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranties of
 * MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR 
 * PURPOSE. See the GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Authored by: Julien Spautz <spautz.julien@gmail.com>, Andrei-Costin Zisu <matzipan@gmail.com>
 */

namespace Scratch.Plugins.FolderManager {
    /**
     * Common abstract class for file and folder items.
     */
    internal abstract class Item: Granite.Widgets.SourceList.ExpandableItem, Granite.Widgets.SourceListSortable {
        public File file { get; construct; }
        public string path {
            owned get { return file.path; }
            set { file.path = value; }
        }
        public FileView view { get; construct; }
        
        construct {
            selectable = true;
            editable = true;
            name = file.name;
            icon = file.icon;
            
            edited.connect (rename);
        }
        
        protected void rename (string new_name) {
            file.rename (new_name);
        }

        protected void trash () {
            file.trash ();
        }

        public int compare (Granite.Widgets.SourceList.Item a, Granite.Widgets.SourceList.Item b) {
            if (a is FolderItem && b is FileItem) {
                return -1;
            } else if (a is FileItem && b is FolderItem) {
                return 1;
            }

            return File.compare ((a as Item).file, (b as Item).file);
        }

        public bool allow_dnd_sorting () { 
            return false;
        }
    }
}
