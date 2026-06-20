/*
 * Copyright 2025 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
*
* Authored by: Jeremy Wootten <jeremywootten@gmail.com>
*/

public class Scratch.Dialogs.BranchCreatePage : Gtk.Box, BranchActionPage {
    public BranchAction action {
        get {
            return BranchAction.CREATE;
        }
    }

    public Ggit.Ref? branch_ref {
        get {
            return null;
        }
    }

    public string new_branch_name {
        get {
            return new_branch_name_entry.text;
        }
    }

    public BranchActionDialog dialog { get; construct; }

    private Granite.ValidatedEntry new_branch_name_entry;

    public BranchCreatePage (BranchActionDialog dialog) {
        Object (
            dialog: dialog
        );
    }

    construct {
        orientation = VERTICAL;
        vexpand = false;
        hexpand = true;
        margin_start = 24;
        spacing = 12;
        valign = CENTER;
        var label = new Granite.HeaderLabel (_("Name of branch to create"));
        new_branch_name_entry = new Granite.ValidatedEntry () {
            activates_default = true,
            placeholder_text = _("Enter new branch name")
        };

        add (label);
        add (new_branch_name_entry);

        new_branch_name_entry.bind_property ("is-valid", dialog, "can-apply");

        new_branch_name_entry.changed.connect (() => {
            unowned var new_name = new_branch_name_entry.text;
            if (!dialog.project.is_valid_new_branch_name (new_name)) {
                new_branch_name_entry.is_valid = false;
                return;
            }

            if (dialog.project.has_local_branch_name (new_name)) {
                new_branch_name_entry.is_valid = false;
                return;
            }

            //Do we need to check remote branches as well?
            new_branch_name_entry.is_valid = true;
        });
    }
}
