/*
* Copyright 2024 elementary, Inc. (https://elementary.io)
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU Lesser General Public
* License version 3 as published by the Free Software Foundation.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU Lesser General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*/

public class Scratch.Dialogs.CloseProjectsConfirmationDialog : Granite.MessageDialog {

    public uint n_parents { get; construct; }
    public uint n_children { get; construct; }

    public CloseProjectsConfirmationDialog (MainWindow parent, uint n_parents, uint n_children) {
        Object (
            buttons: Gtk.ButtonsType.NONE,
            transient_for: parent,
            n_parents: n_parents,
            n_children: n_children
        );
    }

    construct {
        image_icon = new ThemedIcon ("dialog-warning");
        var button_label = "";
        // We can assume that either n_parents or n_children is zero (but not both).
        // We can assume n_parents is either zero or one
        if (n_children > 0) {
            primary_text = ngettext (
                "This folder is the parent of an open project",
                "This folder is the parent of open projects",
                (ulong) n_children
            );
                ;
            secondary_text = ngettext (
                "Opening this folder will close the child project",
                "Opening this folder will close all child projects",
                (ulong) n_children
            );

            button_label = ngettext (
                "Close Child Project",
                "Close Child Projects",
                (ulong) n_children
            );
        } else {
            primary_text = _("This folder is a child of an open project");
            secondary_text = _("Opening this folder will close the parent project");
            button_label = _("Close Parent Project");
        }

        add_button (_("Don't Open"), Gtk.ResponseType.REJECT);

        var ignore_button = (Gtk.Button) add_button (button_label, Gtk.ResponseType.ACCEPT);
        ignore_button.get_style_context ().add_class (Gtk.STYLE_CLASS_DESTRUCTIVE_ACTION);
    }
}
