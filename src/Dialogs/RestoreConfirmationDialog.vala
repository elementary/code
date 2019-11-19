/*
* Copyright 2011-2019 elementary, Inc. (https://elementary.io)
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

public class Scratch.Dialogs.RestoreConfirmationDialog : Granite.MessageDialog {

    public RestoreConfirmationDialog (MainWindow parent) {
        Object (
            buttons: Gtk.ButtonsType.NONE,
            transient_for: parent
        );
    }

    construct {
        image_icon = new ThemedIcon ("dialog-warning");

        primary_text = _("Are You Sure You Want to Restore This File?");
        secondary_text = _("Restoring a file will undo all changes made since opening it");

        add_button (_("Don't Restore"), Gtk.ResponseType.REJECT);

        var ignore_button = (Gtk.Button) add_button (_("Restore Anyway"), Gtk.ResponseType.ACCEPT);
        ignore_button.get_style_context ().add_class (Gtk.STYLE_CLASS_DESTRUCTIVE_ACTION);
    }
}
