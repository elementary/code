/*
 * Copyright 2025 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
*
* Authored by: Jeremy Wootten <jeremywootten@gmail.com>
*/
public enum Scratch.BranchAction {
    CHECKOUT,
    COMMIT,
    PUSH,
    PULL,
    MERGE,
    DELETE,
    CREATE
}

public class Scratch.Dialogs.BranchActionDialog : Granite.MessageDialog {
    public FolderManager.ProjectFolderItem project { get; construct; }
    public BranchAction action { get; set; }
    public string branch { get; set; }

    public bool can_apply { get; private set; default = false; }

    private Gtk.Label local_header;
    private Gtk.Label remote_header;
    private Gtk.Stack stack;

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

            local_header = new Granite.HeaderLabel (_("Local Branches"));
            remote_header = new Granite.HeaderLabel (_("Remote Branches"));
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
            list_box.set_header_func (listbox_header_func);

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

            stack = new Gtk.Stack ();
            stack.add_titled (search_box, BranchAction.CHECKOUT.to_string (), _("Checkout"));
            stack.add_titled (new Gtk.Label (_("Commit not implemented yet")), BranchAction.COMMIT.to_string (), _("Commit"));
            stack.add_titled (new Gtk.Label (_("Push not implemented yet")), BranchAction.PUSH.to_string (), _("Push"));
            stack.add_titled (new Gtk.Label (_("Pull not implemented yet")), BranchAction.PULL.to_string (), _("Pull"));
            stack.add_titled (new Gtk.Label (_("Merge not implemented yet")), BranchAction.MERGE.to_string (), _("Merge"));
            stack.add_titled (new Gtk.Label (_("Delete not implemented yet")), BranchAction.DELETE.to_string (), _("Delete"));
            stack.add_titled (new Gtk.Label (_("Create not implemented yet")), BranchAction.CREATE.to_string (), _("Create"));


            var sidebar = new Gtk.StackSidebar () {
                stack = stack
            };

            var content_box = new Gtk.Box (HORIZONTAL, 12);
            content_box.add (sidebar);
            content_box.add (stack);

            custom_bin.add (content_box);
            custom_bin.show_all ();
        } else {
            primary_text = _("'%s' is not a git repository").printf (
                project.file.file.get_basename ()
            );
            secondary_text = _("Unable to perform branch actions");
            image_icon = new ThemedIcon ("dialog-error");
        }
    }

    private void on_toggle_button_toggled (Gtk.Widget src) {
        var action_button = (ActionRadioButton)src;
        if (action_button.active) {
            stack.set_visible_child_name (action_button.branch_action.to_string ());
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

    private void listbox_header_func (Gtk.ListBoxRow row, Gtk.ListBoxRow? row_before) {
        var a = (BranchNameRow)row;
        var b = (BranchNameRow)row_before;
        if (b == null && a.get_header () != local_header) {
            a.set_header (local_header);
        } else if (a.is_remote && !b.is_remote && a.get_header () != remote_header) {
            a.set_header (remote_header);
        } else {
            a.set_header (null);
        }
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
                halign = START,
                margin_start = 24
            };

            this.child = label;
        }
    }

    private class ActionRadioButton : Gtk.RadioButton {
        public BranchAction branch_action { get; construct; }

        public ActionRadioButton (BranchAction action, Gtk.RadioButton? sibling, string text) {
            Object (
                branch_action: action
            );

            join_group (sibling);
            label = text;
        }

        construct {
            halign = Gtk.Align.START;
            valign = Gtk.Align.START;
            vexpand = true;
        }
    }
}
