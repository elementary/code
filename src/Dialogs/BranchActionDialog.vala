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

public interface Scratch.BranchActionPage : Gtk.Widget {
    public abstract BranchAction action { get; }
    public abstract Ggit.Ref branch_ref { get; }
}

public class Scratch.Dialogs.BranchActionDialog : Granite.MessageDialog {
    public BranchAction action {
        get {
            return ((BranchActionPage)stack.get_visible_child ()).action;
        }
    }

    public Ggit.Ref branch_ref {
        get {
            return ((BranchActionPage)stack.get_visible_child ()).branch_ref;
        }
    }

    private Gtk.Stack stack;
    protected bool can_apply { get; set; default = false; }

    public FolderManager.ProjectFolderItem project { get; construct; }
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
            stack = new Gtk.Stack ();
            var checkout_page = new BranchCheckoutPage (this);
            stack.add_titled (checkout_page, BranchAction.CHECKOUT.to_string (), _("Checkout"));

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

    private class BranchCheckoutPage : Gtk.Box, BranchActionPage {
        public BranchAction action {
            get {
                return BranchAction.CHECKOUT;
            }
        }

        public Ggit.Ref branch_ref {
            get {
                return list_box.get_selected_row ().bref;
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
        }
    }

    private class BranchListBox : Gtk.Bin {
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
            list_box = new Gtk.ListBox ();
            var scrolled_window = new Gtk.ScrolledWindow (null, null) {
                hscrollbar_policy = NEVER,
                vscrollbar_policy = AUTOMATIC,
                min_content_height = 200,
                vexpand = true
            };
            scrolled_window.child = list_box;
            search_entry = new Gtk.SearchEntry ();
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
            list_box.row_activated.connect ((listboxrow) => {
                search_entry.text = ((BranchNameRow)(listboxrow)).branch_name;
            });
            list_box.set_filter_func ((listboxrow) => {
                return (((BranchNameRow)(listboxrow)).branch_name.contains (search_entry.text));
            });
            search_entry.changed.connect (() => {
                list_box.invalidate_filter ();
                list_box.invalidate_headers ();
                // Checkout action
                dialog.can_apply = dialog.project.has_branch_name (search_entry.text, null);
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
            a.set_header (null);
            if (row_before == null) {
                if (a.is_recent && a.get_header () != recent_header) {
                    a.set_header (recent_header);
                } else if (!a.is_remote && a.get_header () != local_header) {
                    a.set_header (local_header);
                } else {
                    a.set_header (remote_header);
                }

                return;
            }


            var b = (BranchNameRow)row_before;

            if (b.is_recent && !a.is_recent) {
                if (!a.is_remote && a.get_header () != local_header) {
                    a.set_header (local_header);
                } else if (a.is_remote && a.get_header () != remote_header) {
                    a.set_header (remote_header);
                }
            } else if (!b.is_remote && a.is_remote && a.get_header () != remote_header) {
                a.set_header (remote_header);
            }
        }
    }

    private class BranchNameRow : Gtk.ListBoxRow {
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
}
