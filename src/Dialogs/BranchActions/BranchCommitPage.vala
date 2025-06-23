/*
 * Copyright 2025 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
*
* Authored by: Jeremy Wootten <jeremywootten@gmail.com>
*/

public class Scratch.Dialogs.BranchCommitPage : Gtk.Box, BranchActionPage {
    public BranchAction action {
        get {
            return BranchAction.COMMIT;
        }
    }

    public Ggit.Ref? branch_ref {
        get {
            return null;
        }
    }

    public string new_branch_name {
        get {
            return "";
        }
    }

    public BranchActionDialog dialog { get; construct; }

    private Gtk.TextView diff_textview;
    private Gtk.TextView commit_message_textview;

    public BranchCommitPage (BranchActionDialog dialog) {
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
        // var label = new Granite.HeaderLabel (_("Commit message"));
        commit_message_textview = new Gtk.TextView () {
            editable = true,
            hexpand = true,
            vexpand = true
        };
        commit_message_textview.buffer.text = "COMMIT";

        var commit_scrolledwindow = new Gtk.ScrolledWindow (null, null) {
            hscrollbar_policy = AUTOMATIC,
            vscrollbar_policy = AUTOMATIC,
            min_content_height = 200,
            min_content_width = 300,
            vexpand = true
        };
        commit_scrolledwindow.child = commit_message_textview;

        diff_textview = new Gtk.TextView () {
            editable = false,
            hexpand = true,
            vexpand = true
        };
        //TODO Include untracked files
        diff_textview.buffer.text = dialog.project.monitored_repo.get_project_diff ();

        var diff_scrolled_window = new Gtk.ScrolledWindow (null, null) {
            hscrollbar_policy = AUTOMATIC,
            vscrollbar_policy = AUTOMATIC,
            min_content_height = 200,
            min_content_width = 400,
            vexpand = true
        };
        diff_scrolled_window.child = diff_textview;

        var workingfiles_listbox = new Gtk.ListBox ();
        foreach (string path in dialog.project.monitored_repo.get_changed_files (false)) {
            var label = new Gtk.Label (path) {
                halign = START,
                ellipsize = START
            };
            workingfiles_listbox.add (label);
        }
        var working_scrolledwindow = new Gtk.ScrolledWindow (null, null) {
            hscrollbar_policy = AUTOMATIC,
            vscrollbar_policy = AUTOMATIC,
            min_content_height = 100,
            min_content_width = 200,
            vexpand = true
        };
        working_scrolledwindow.child = workingfiles_listbox;

        var stagedfiles_listbox = new Gtk.ListBox ();
        foreach (string path in dialog.project.monitored_repo.get_changed_files (true)) {
            var label = new Gtk.Label (path) {
                halign = START,
                ellipsize = START
            };
            stagedfiles_listbox.add (label);
        }
        var staged_scrolledwindow = new Gtk.ScrolledWindow (null, null) {
            hscrollbar_policy = AUTOMATIC,
            vscrollbar_policy = AUTOMATIC,
            min_content_height = 100,
            min_content_width = 200,
            vexpand = true
        };
        staged_scrolledwindow.child = stagedfiles_listbox;

        var grid = new Gtk.Grid () {
            row_spacing = 6,
            column_spacing = 6,
            hexpand = true
        };
        grid.attach (working_scrolledwindow, 0, 0);
        grid.attach (staged_scrolledwindow, 0, 1);
        grid.attach (diff_scrolled_window, 1, 0);
        grid.attach (commit_scrolledwindow, 1, 1);

        add (grid);

        show_all ();
    }
}
