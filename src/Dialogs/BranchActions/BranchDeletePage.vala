/*
 * Copyright 2025-2026 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
*
* Authored by: Jeremy Wootten <jeremywootten@gmail.com>
*/

public class Scratch.Dialogs.BranchDeletePage : Gtk.Box, BranchActionPage {
    public BranchAction action {
        get {
            return BranchAction.DELETE;
        }
    }

    public Ggit.Ref? branch_ref {
        get {
            return list_box.get_selected_row ().bref;
        }
    }

    public string target_branch_name {
        get {
            return "";
        }
    }

    public BranchActionDialog dialog { get; construct; }

    private BranchListBox list_box;
    private Gtk.CheckButton delete_unmerged_check;

    public BranchDeletePage (BranchActionDialog dialog) {
        Object (
            dialog: dialog
        );
    }

    construct {
        orientation = VERTICAL;
        list_box = new BranchListBox (dialog, false) {
            margin_bottom = 12
        }; // No remotes
        add (list_box);
        delete_unmerged_check = new Gtk.CheckButton.with_label (_("Delete even if unmerged into default branch")) {
            active = false,
            valign = CENTER
        };


        var action_bar = new Gtk.ActionBar ();
        action_bar.pack_start (delete_unmerged_check);
        add (action_bar);

        list_box.branch_changed.connect (() => {
            delete_unmerged_check.active = false;
        });

        delete_unmerged_check.toggled.connect (() => {
            update_can_apply ();
        });


    }

    public override void focus_start_widget () {
        list_box.grab_focus ();
    }

    private void update_can_apply () {
        var text = list_box.text;
        var exists = dialog.project.has_branch_name (text, null);
        var is_current = dialog.project.get_current_branch_name () == text;
        var is_merged = dialog.project.branch_name_is_merged (text);
        dialog.can_apply = exists && !is_current && (is_merged || delete_unmerged_check.active);
    }
}
