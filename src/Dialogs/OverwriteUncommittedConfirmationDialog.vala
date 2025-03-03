/*
* Copyright 2025 elementary, Inc. (https://elementary.io)
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

public class Scratch.Dialogs.OverwriteUncommittedConfirmationDialog : Granite.MessageDialog {

    public string branch_name { get; construct; }
    public OverwriteUncommittedConfirmationDialog (
        Gtk.Window parent,
        string new_branch_name,
        string details
    ) {
        Object (
            buttons: Gtk.ButtonsType.NONE,
            transient_for: parent,
            branch_name: new_branch_name
        );

        show_error_details (details);
    }

    construct {
        modal = true;
        image_icon = new ThemedIcon ("dialog-warning");

        primary_text = _("There are uncommitted changes in the current branch");
        ///TRANSLATORS '%s' is a placeholder for the name of the branch to be checked out
        secondary_text = _("Uncommitted changes will be permanently lost if <b>'%s'</b> is checked out now.\n\n<i>It is recommended that uncommitted changes are stashed, committed, or reverted before proceeding.</i>").printf (branch_name);

        var cancel_button = add_button (_("Do not Checkout"), Gtk.ResponseType.REJECT);
        var proceed_button = (Gtk.Button) add_button (_("Checkout and Overwrite"), Gtk.ResponseType.ACCEPT);
        proceed_button.get_style_context ().add_class (Gtk.STYLE_CLASS_DESTRUCTIVE_ACTION);
    }
}
