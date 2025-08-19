/*
 * Copyright 2025 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
*
* Authored by: Jeremy Wootten <jeremywootten@gmail.com>
*/
private class Scratch.Dialogs.BranchNameRow : Gtk.ListBoxRow {
    public Ggit.Ref bref { get; construct; }
    public bool is_remote { get; private set; }
    public bool is_recent { get; set; default = false; }

    public string branch_name {
        get {
            return label.label;
        }
    }

    private Gtk.Label label;

    public BranchNameRow (Ggit.Ref bref) {
        Object (
            bref: bref
        );
    }

    construct {
        is_remote = !bref.is_branch ();
        label = new Gtk.Label (bref.get_shorthand ()) {
            halign = START,
            margin_start = 24
        };

        child = label;
    }
}
