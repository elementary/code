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

public class Scratch.Dialogs.ChooseProjectDialog : Granite.MessageDialog {
    public FolderManager.ProjectFolderItem? active_project { get; private set; default = null; }

    public bool only_repos { get; construct; }
    public unowned List<FolderManager.ProjectFolderItem> usable_projects { get; set construct; }
    public unowned List<FolderManager.ProjectFolderItem> projects { get; construct; }

    private Gtk.ListBox project_list;


    public ChooseProjectDialog (List<FolderManager.ProjectFolderItem> projects, bool only_repos) {
        Object (
            transient_for: ((Gtk.Application)(GLib.Application.get_default ())).get_active_window (),
            projects: projects,
            only_repos: only_repos
        );
    }

    construct {
        add_button (_("Cancel"), Gtk.ResponseType.CANCEL);
        var accept_button = (Gtk.Button) add_button (_("Accept"), Gtk.ResponseType.ACCEPT);
        accept_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);
        bind_property ("active-project", accept_button, "sensitive", BindingFlags.DEFAULT,
            (binding, src_val, ref target_val) => {
                target_val.set_boolean (src_val.get_object () != null);
            }
        );

        usable_projects = null;
        foreach (unowned var project in projects) {
            if (!only_repos || project.is_git_repo) {
                usable_projects.append (project);
            }
        }

        var n_usable = usable_projects.length ();
        switch (n_usable) {
            case 0:
                primary_text = _("There are no open projects to which this action can be applied");
                secondary_text = _("Open a suitable project in the sidebar and retry");
                //TODO Implement link to "Open Project Folder" action
                image_icon = new ThemedIcon ("dialog-warning");
                remove (accept_button);

                break;
            case 1:
                active_project = usable_projects.data;
                primary_text = _("This action can be applied to the project “%s”").printf (active_project.basename);
                secondary_text = _("");
                //TODO Implement link to "Open Project Folder" action
                image_icon = new ThemedIcon ("dialog-information");

                break;
            default:
                primary_text = _("Choose a project");
                secondary_text = _("Select a project from the list below");
                image_icon = new ThemedIcon ("dialog-question");
                project_list = new Gtk.ListBox ();

                foreach (unowned var project in usable_projects) {
                    var row = new Gtk.ListBoxRow ();
                    var label = new Gtk.Label (project.basename) {
                        halign = Gtk.Align.START
                    };
                    row.add (label);
                    project_list.add (row);
                }

                project_list.row_selected.connect ((row) => {
                    if (row != null) {
                        active_project = usable_projects.nth_data (row.get_index ());
                    } else {
                        active_project = null;
                    }
                });

                custom_bin.add (project_list);

                break;
        }

        if (only_repos) {
            badge_icon = new ThemedIcon ("git");
        }

        show_all ();
    }
 }
