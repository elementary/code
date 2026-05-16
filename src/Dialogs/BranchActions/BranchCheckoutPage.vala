/*
 * Copyright 2025 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
*
* Authored by: Jeremy Wootten <jeremywootten@gmail.com>
*/

public class Scratch.Dialogs.BranchCheckoutPage : Gtk.Box, BranchActionPage {
    public BranchAction action {
        get {
            return BranchAction.CHECKOUT;
        }
    }

    public Ggit.Ref? branch_ref {
        get {
            return list_box.get_selected_row ().bref;
        }
    }

    public string new_branch_name {
        get {
            return "";
        }
    }

    public BranchActionDialog dialog { get; construct; }

    private BranchListBox list_box;

    public BranchCheckoutPage (BranchActionDialog dialog) {
        Object (
            dialog: dialog
        );
    }

    construct {
        list_box = new BranchListBox (dialog, true);
        add (list_box);
        list_box.branch_changed.connect ((text) => {
            dialog.can_apply = dialog.project.has_branch_name (text, null);
        });
    }

    public override void focus_start_widget () {
        list_box.grab_focus ();
    }
}
