/*-
 * Copyright (c) 2017 elementary LLC. (https://elementary.io)
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
 * Authored by: Julien Spautz <spautz.julien@gmail.com>
 */

namespace Scratch.Plugins.FolderManager {

    /**
     * Class for interacting with gsettings.
     */
    internal class Settings : Granite.Services.Settings {

        private const string SCHEMA = "org.pantheon.scratch.plugins.folder-manager";

        public string[] opened_folders { get; set; }

        public Settings () {
            base (SCHEMA);
        }
    }
}
