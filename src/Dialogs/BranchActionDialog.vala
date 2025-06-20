/*
 * Copyright 2025 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
*
* Authored by: Jeremy Wootten <jeremywootten@gmail.com>
*/
public enum Scratch.BranchAction  {
    CHECKOUT,
    CREATE,
    DELETE
}

public class Scratch.Dialogs.BranchActionDialog : Granite.MessageDialog {
    public FolderManager.ProjectFolderItem project { get; construct; }
    public BranchAction action { get; set; }
    public string branch { get; set; }

    public BranchActionDialog (FolderManager.ProjectFolderItem project) {
        Object (
            transient_for: ((Gtk.Application)(GLib.Application.get_default ())).get_active_window (),
            project: project,
            primary_text: _("Perform branch action on project %s").printf (
            project.file.file.get_basename ()),
            image_icon: new ThemedIcon ("git"),
            buttons: Gtk.ButtonsType.CANCEL
        );
    }

    construct {
        assert (project.is_git_repo);
        var apply_button = add_button (_("Apply"), Gtk.ResponseType.APPLY);
        set_default_response ( Gtk.ResponseType.CANCEL);

        unowned var local_branches = project.get_branches ();

        var list_store = new ListStore (typeof (Ggit.Branch));
        foreach (Ggit.Branch branch in local_branches) {
            list_store.insert_sorted (branch, (a, b) => {
                return (((Ggit.Branch)a).get_name ()).collate (((Ggit.Branch)b).get_name ());
            });
        }

        var list_box = new Gtk.ListBox ();
        list_box.bind_model (list_store, (obj) => {
            var row = new Gtk.ListBoxRow ();
            var label = new Gtk.Label (((Ggit.Branch)obj).get_name ()) {
                halign = START
            };
            row.add (label);
            return row;
        });

        var search_entry = new Gtk.SearchEntry ();
        list_box.set_filter_func ((row) => {
            return (((Gtk.Label)(row.get_child ())).label.contains (search_entry.text));
        });

        list_box.row_activated.connect ((row) => {
            search_entry.text = ((Gtk.Label)(row.get_child ())).label;
        });

        var scrolled_window = new Gtk.ScrolledWindow (null, null) {
            hscrollbar_policy = NEVER,
            vscrollbar_policy = AUTOMATIC,
            min_content_height = 100
        };
        scrolled_window.child = list_box;

        search_entry.changed.connect (() => {
            list_box.invalidate_filter ();
        });
        var search_box = new Gtk.Box (VERTICAL, 6);
        search_box.add (search_entry);
        search_box.add (scrolled_window);

        custom_bin.add (search_box);
        // secondary_text = _("The branch name must be unique and follow Git naming rules.");
        // badge_icon = new ThemedIcon ("list-add");
        // new_branch_name_entry = new Granite.ValidatedEntry () {
        //     activates_default = true
        // };

        // custom_bin.add (new_branch_name_entry);

        // var apply_button = (Gtk.Button) add_button (_("Apply"), Gtk.ResponseType.APPLY);
        // apply_button.can_default = true;
        // apply_button.has_default = true;
        // apply_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);

        // new_branch_name_entry.bind_property (
        //     "is-valid", apply_button, "sensitive", BindingFlags.DEFAULT | BindingFlags.SYNC_CREATE
        // );

        // new_branch_name_entry.changed.connect (() => {
        //     unowned var new_name = new_branch_name_entry.text;
        //     if (!active_project.is_valid_new_branch_name (new_name)) {
        //         new_branch_name_entry.is_valid = false;
        //         return;
        //     }

        //     if (active_project.has_local_branch_name (new_name)) {
        //         new_branch_name_entry.is_valid = false;
        //         return;
        //     }

        //     //Do we need to check remote branches as well?
        //     new_branch_name_entry.is_valid = true;
        // });

        show_all ();
    }
}
