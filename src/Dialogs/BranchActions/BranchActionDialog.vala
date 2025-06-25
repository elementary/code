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
    public abstract Ggit.Ref? branch_ref { get; }
    public abstract string new_branch_name { get; }
    public virtual void focus_start_widget () {}
}

public class Scratch.Dialogs.BranchActionDialog : Granite.MessageDialog {
    public signal void page_activated ();

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

    public string new_branch_name {
        get {
            return ((BranchActionPage)stack.get_visible_child ()).new_branch_name;
        }
    }

    public bool can_apply { get; set; default = false; }
    public FolderManager.ProjectFolderItem project { get; construct; }

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
            primary_label.can_focus = false;
            image_icon = new ThemedIcon ("git");
            var apply_button = add_button (_("Apply"), Gtk.ResponseType.APPLY);
            bind_property ("can-apply", apply_button, "sensitive", SYNC_CREATE);
            stack = new Gtk.Stack ();
            var checkout_page = new BranchCheckoutPage (this);
            var create_page = new BranchCreatePage (this);
            stack.add_titled (checkout_page, BranchAction.CHECKOUT.to_string (), _("Checkout"));

            stack.add_titled (new Gtk.Label (_("Commit not implemented yet")), BranchAction.COMMIT.to_string (), _("Commit"));
            stack.add_titled (new Gtk.Label (_("Push not implemented yet")), BranchAction.PUSH.to_string (), _("Push"));
            stack.add_titled (new Gtk.Label (_("Pull not implemented yet")), BranchAction.PULL.to_string (), _("Pull"));
            stack.add_titled (new Gtk.Label (_("Merge not implemented yet")), BranchAction.MERGE.to_string (), _("Merge"));
            stack.add_titled (new Gtk.Label (_("Delete not implemented yet")), BranchAction.DELETE.to_string (), _("Delete"));
            stack.add_titled (create_page, BranchAction.CREATE.to_string (), _("Create"));

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

        realize.connect (() => {
            ((BranchActionPage)stack.get_visible_child ()).focus_start_widget ();
        });

        page_activated.connect (() => {
            if (can_apply) {
                response (Gtk.ResponseType.APPLY);
            }
        });
    }
}
