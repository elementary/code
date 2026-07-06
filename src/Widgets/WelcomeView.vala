/*-
 * Copyright (c) 2017-2026 elementary LLC. (https://elementary.io)
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

public class Code.WelcomeView : Granite.Placeholder {
    public unowned Scratch.MainWindow window { get; construct; }

    public WelcomeView (Scratch.MainWindow window) {
        Object (
            window: window,
            title: _("No Files Open"),
            description: _("Open a file to begin editing.")
        );
    }

    construct {
        var new_button = append_button (new ThemedIcon ("document-new"), _("New File"), _("Create a new empty file."));
        var open_button = append_button (new ThemedIcon ("document-open"), _("Open File"), _("Open a saved file."));
        var project_button = append_button (new ThemedIcon ("open-project"), _("Open Folder"), _("Add a project folder to the sidebar."));

        new_button.activated.connect (() => {
            Scratch.Utils.action_from_group (Scratch.MainWindow.ACTION_NEW_TAB, window.actions).activate (null);
        });

        open_button.activated.connect (() => {
            Scratch.Utils.action_from_group (Scratch.MainWindow.ACTION_OPEN, window.actions).activate (null);
        });

        project_button.activated.connect (() => {
            Scratch.Utils.action_from_group (Scratch.MainWindow.ACTION_OPEN_PROJECT, window.actions).activate (null);
        });
    }
}
