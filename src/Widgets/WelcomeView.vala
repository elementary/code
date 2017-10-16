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
 * Authored by: Corentin Noël <corentin@elementary.io>
 */

public class Code.WelcomeView : Granite.Widgets.Welcome {
    public unowned Scratch.MainWindow window { get; construct; }

    public WelcomeView (Scratch.MainWindow window) {
        Object (
            window: window,
            title: _("No Files Open"),
            subtitle: _("Open a file to begin editing.")
        );
    }

    construct {
        valign = Gtk.Align.FILL;
        halign = Gtk.Align.FILL;
        vexpand = true;
        append ("document-new", _("New file"), _("Create a new empty file."));
        append ("document-open", _("Open file"), _("Open a saved file."));
        append ("edit-paste", _("New file from clipboard"), _("Create a new file from the contents of your clipboard."));
        set_item_visible (2, window.clipboard.wait_is_text_available ());

        activated.connect ((i) => {
            // New file
            if (i == 0) {
                Scratch.Utils.action_from_group (Scratch.MainWindow.ACTION_NEW_TAB, window.actions).activate (null);
            } else if (i == 1) {
                Scratch.Utils.action_from_group (Scratch.MainWindow.ACTION_OPEN, window.actions).activate (null);
            } else if (i == 2) {
                Scratch.Utils.action_from_group (Scratch.MainWindow.ACTION_NEW_FROM_CLIPBOARD, window.actions).activate (null);
            }
        });
    }
}
