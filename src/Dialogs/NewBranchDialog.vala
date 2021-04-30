/*
* Copyright 2021 elementary, Inc. (https://elementary.io)
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 2 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA.
*
* Authored by: Jeremy Wootten <jeremy@elementaryos.org>
*/

public class Scratch.Dialogs.NewBranchDialog : Granite.MessageDialog {
    public FolderManager.ProjectFolderItem? active_project { get; construct; }
    public unowned List<FolderManager.ProjectFolderItem> project_list { get; construct; }
    private Granite.ValidatedEntry new_branch_name_entry;
    public string new_branch_name {
        get {
            return new_branch_name_entry.text;
        }
    }

    public NewBranchDialog (FolderManager.ProjectFolderItem? project, List<FolderManager.ProjectFolderItem> project_list) {
        Object (
            transient_for: ((Gtk.Application)(GLib.Application.get_default ())).get_active_window (),
            active_project: project,
            project_list: project_list,
            image_icon: new ThemedIcon ("git")
        );
    }

    construct {
        unowned List<string> branch_names = null;
        if (active_project != null) {
            assert (active_project.is_git_repo);
            branch_names = active_project.get_branch_names ();
            primary_text = _("Create a new branch of “%s”").printf (active_project.file.file.get_basename ());
            secondary_text = _("The branch name must be lower-case, start with a letter, and be at least 3 characters. The name must not already exist.");
            badge_icon = new ThemedIcon ("list-add");
        } else {
            primary_text = _("You must have an active git project before creating a new branch.");
            badge_icon = new ThemedIcon ("dialog-warning");
            if (project_list.length () == 0) {
                secondary_text = _("Open a git project folder in the sidebar.");
            } else {
                secondary_text = _("Open a document in a git project folder in the sidebar or use a project context menu.");
            }
        }

        try {
            //Branch name must be lower-case, start with a letter and be at least 3 characters long
            // new_branch_name_entry = new Granite.ValidatedEntry.from_regex (new Regex ("^[a-z].(?=[a-z0-9--]{2,}$)"));
            new_branch_name_entry = new Granite.ValidatedEntry.from_regex (new Regex ("^[a-z].[a-z0-9--]{2,}$")) {
                activates_default = true,
                no_show_all = active_project == null
            };

            new_branch_name_entry.changed.connect (() => {
                unowned var new_name = new_branch_name_entry.text;
                foreach (unowned var name in branch_names) {
                    if (new_name != name) {
                        continue;
                    }

                    new_branch_name_entry.is_valid = false;
                }
            });
        } catch (GLib.Error e) {
            critical ("NewBranchDialog invalid Regex");
            assert_not_reached ();
        }

        custom_bin.add (new_branch_name_entry);

        add_button (_("Cancel"), Gtk.ResponseType.CANCEL);

        var create_button = (Gtk.Button) add_button (_("Create Branch"), Gtk.ResponseType.APPLY);
        create_button.can_default = true;
        create_button.has_default = true;
        create_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);

        new_branch_name_entry.bind_property (
            "is-valid", create_button, "sensitive", BindingFlags.DEFAULT | BindingFlags.SYNC_CREATE
        );
    }
}
