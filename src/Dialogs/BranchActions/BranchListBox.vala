/*
 * Copyright 2025 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
*
* Authored by: Jeremy Wootten <jeremywootten@gmail.com>
*/
private class Scratch.Dialogs.BranchListBox : Gtk.Bin {
    public signal void branch_changed (string branch_name);
    public string text {
        get {
            return search_entry.text;
        }
    }

    public bool show_remotes { get; construct;}
    public BranchActionDialog dialog { get; construct;}

    private Gtk.ListBox list_box;
    private Gtk.SearchEntry search_entry;
    private Gtk.Label local_header;
    private Gtk.Label remote_header;
    private Gtk.Label recent_header;

    public BranchListBox (BranchActionDialog dialog, bool show_remotes) {
        Object (
            dialog: dialog,
           show_remotes: show_remotes
        );
    }

    construct {
        list_box = new Gtk.ListBox () {
            activate_on_single_click = false
        };
        var scrolled_window = new Gtk.ScrolledWindow (null, null) {
            hscrollbar_policy = NEVER,
            vscrollbar_policy = AUTOMATIC,
            min_content_height = 200,
            vexpand = true
        };
        scrolled_window.child = list_box;
        search_entry = new Gtk.SearchEntry () {
            placeholder_text = _("Enter search term")
        };
        var box = new Gtk.Box (VERTICAL, 6);
        box.add (search_entry);
        box.add (scrolled_window);
        child = box;

        recent_header = new Granite.HeaderLabel (_("Recent Branches"));
        local_header = new Granite.HeaderLabel (_("Local Branches"));
        remote_header = new Granite.HeaderLabel (_("Remote Branches"));
        var branch_refs = dialog.project.get_all_branch_refs ();

        foreach (var branch_ref in branch_refs) {
            if (branch_ref.is_branch () || show_remotes) {
                var row = new BranchNameRow (branch_ref);
                if (dialog.project.is_recent_ref (branch_ref)) {
                    row.is_recent = true;
                }
                list_box.add (row);
            }
        }
        list_box.set_sort_func (listbox_sort_func);
        list_box.set_header_func (listbox_header_func);
        list_box.row_selected.connect ((listboxrow) => {
            //We want cursor to end up after the inserted text
            search_entry.text = ((BranchNameRow)(listboxrow)).branch_name;
            search_entry.grab_focus_without_selecting ();
            search_entry.move_cursor (DISPLAY_LINE_ENDS, 1, false);
        });
        list_box.row_activated.connect ((listboxrow) => {
            dialog.page_activated ();
        });
        list_box.set_filter_func ((listboxrow) => {
            return (((BranchNameRow)(listboxrow)).branch_name.contains (search_entry.text));
        });
        search_entry.changed.connect (() => {
            list_box.invalidate_filter ();
            // recent_header.unparent ();
            // local_header.unparent ();
            // remote_header.unparent ();
            // list_box.invalidate_headers ();
            branch_changed (text);
        });
        search_entry.activate.connect (() => {
            dialog.page_activated ();
        });
    }

    public BranchNameRow? get_selected_row () {
        int index = 0;
        var row = list_box.get_row_at_index (index);
        while (row != null &&
              ((BranchNameRow)row).branch_name != search_entry.text) {

            row = list_box.get_row_at_index (++index);
        }

        return (BranchNameRow)row;
    }


    private int listbox_sort_func (Gtk.ListBoxRow rowa, Gtk.ListBoxRow rowb) {
        var a = (BranchNameRow)(rowa);
        var b = (BranchNameRow)(rowb);

        if (a.is_recent && !b.is_recent) {
            return -1;
        } else if (b.is_recent && !a.is_recent) {
            return 1;
        }

        if (a.is_remote && !b.is_remote) {
            return 1;
        } else if (b.is_remote && !a.is_remote) {
            return -1;
        }

        return (a.branch_name.collate (b.branch_name));
    }

    private void listbox_header_func (Gtk.ListBoxRow row, Gtk.ListBoxRow? row_before) {
        var a = (BranchNameRow)row;
        var b = (BranchNameRow?)row_before;
        a.set_header (null);
        if (b == null) {
            if (a.is_recent) {
                a.set_header (recent_header);
            } else if (!a.is_remote) {
                a.set_header (local_header);
            } else {
                a.set_header (remote_header);
            }
        } else if (b.is_recent) {
            if (!a.is_remote) {
                a.set_header (local_header);
            } else if (a.is_remote) {
                a.set_header (remote_header);
            }
        } else if (!b.is_remote) {
            if (a.is_remote) {
                a.set_header (remote_header);
            }
        }
    }

    public new void grab_focus () {
        search_entry.grab_focus ();
    }
}
