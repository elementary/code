/*
 * Copyright 2025 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
*
* Authored by: Jeremy Wootten <jeremywootten@gmail.com>
*/
public enum Scratch.BranchAction {
    CHECKOUT,
    CREATE,
    DELETE
}

public class Scratch.Dialogs.BranchActionDialog : Granite.MessageDialog {
    public FolderManager.ProjectFolderItem project { get; construct; }
    public BranchAction action { get; set; }
    public string branch { get; set; }

    public bool can_apply { get; private set; default = false; }

    public BranchActionDialog (FolderManager.ProjectFolderItem project) {
        Object (
            project: project
        );
    }

    construct {
        transient_for = ((Gtk.Application)(GLib.Application.get_default ())).get_active_window ();
        add_button (_("Cancel"), Gtk.ResponseType.CANCEL);
        if (project.is_git_repo) {
            primary_text = _("Perform branch action on project '%s'").printf (
                project.file.file.get_basename ()
            );
            image_icon = new ThemedIcon ("git");
            var apply_button = add_button (_("Apply"), Gtk.ResponseType.APPLY);
            bind_property ("can-apply", apply_button, "sensitive", SYNC_CREATE);
            set_default_response ( Gtk.ResponseType.CANCEL);

            var branch_refs = project.get_all_branch_refs ();
            var list_box = new Gtk.ListBox ();
            foreach (var branch_ref in branch_refs) {
                var row = new BranchNameRow (branch_ref);
                list_box.add (row);
            }

            var search_entry = new Gtk.SearchEntry ();

            list_box.set_filter_func ((row) => {
                return (((BranchNameRow)row).name.contains (search_entry.text));
            });

            list_box.set_sort_func (listbox_sort_func);

            list_box.row_activated.connect ((row) => {
                search_entry.text = ((BranchNameRow)row).name;
            });

            search_entry.changed.connect (() => {
                list_box.invalidate_filter ();
                // Checkout action
                can_apply = project.has_branch_name (search_entry.text, null);
            });

            var scrolled_window = new Gtk.ScrolledWindow (null, null) {
                hscrollbar_policy = NEVER,
                vscrollbar_policy = AUTOMATIC,
                min_content_height = 200,
                vexpand = true
            };
            scrolled_window.child = list_box;

            search_entry.changed.connect (() => {
                list_box.invalidate_filter ();
            });
            var search_box = new Gtk.Box (VERTICAL, 6);
            search_box.add (search_entry);
            search_box.add (scrolled_window);

            custom_bin.add (search_box);
            custom_bin.show_all ();
        } else {
            primary_text = _("'%s' is not a git repository").printf (
                project.file.file.get_basename ()
            );
            secondary_text = _("Unable to perform branch actions");
            image_icon = new ThemedIcon ("dialog-error");
        }
    }

    private int listbox_sort_func (Gtk.ListBoxRow rowa, Gtk.ListBoxRow rowb) {
        var a = (BranchNameRow)rowa;
        var b = (BranchNameRow)rowb;

        if (a.is_remote && !b.is_remote) {
            return 1;
        }

        if (b.is_remote && !a.is_remote) {
            return -1;
        }

        return (a.name.collate (b.name));
    }

    private class BranchNameRow : Gtk.ListBoxRow {
        public Ggit.Ref bref { get; construct; }
        public bool is_remote { get; private set; }
        public string name {
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
                halign = START
            };

            this.child = label;
        }
    }
}
