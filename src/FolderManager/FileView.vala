/*-
 * Copyright (c) 2017-2026 elementary LLC. (https://elementary.io),
 *               2013 Julien Spautz <spautz.julien@gmail.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License version 3
 * as published by the Free Software Foundation, either version 3 of the
 * License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranties of
 * MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
 * PURPOSE. See the GNU General Public License for more details.

 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Authored by: Julien Spautz <spautz.julien@gmail.com>, Andrei-Costin Zisu <matzipan@gmail.com>
 */

/**
 * SourceList that displays folders and their contents.
 */
public class Scratch.FolderManager.FileView : Code.TreeList, Code.PaneSwitcher {
    public const string ACTION_GROUP = "file-view";
    public const string ACTION_PREFIX = ACTION_GROUP + ".";
    public const string ACTION_LAUNCH_APP_WITH_FILE_PATH = "launch-app-with-file-path";
    public const string ACTION_SHOW_APP_CHOOSER = "show-app-chooser";
    public const string ACTION_EXECUTE_CONTRACT_WITH_FILE_PATH = "execute-contract-with-file-path";
    public const string ACTION_RENAME_FILE = "rename-file";
    public const string ACTION_RENAME_FOLDER = "rename-folder";
    public const string ACTION_DELETE = "delete";
    public const string ACTION_NEW_FILE = "new-file";
    public const string ACTION_NEW_FROM_TEMPLATE = "new-from-template";
    public const string ACTION_NEW_FOLDER = "new-folder";
    public const string ACTION_CLOSE_FOLDER = "close-folder";
    public const string ACTION_CLOSE_OTHER_FOLDERS = "close-other-folders";

    private const ActionEntry[] ACTION_ENTRIES = {
        { ACTION_LAUNCH_APP_WITH_FILE_PATH, action_launch_app_with_file_path, "as" },
        { ACTION_SHOW_APP_CHOOSER, action_show_app_chooser, "s" },
        { ACTION_EXECUTE_CONTRACT_WITH_FILE_PATH, action_execute_contract_with_file_path, "as" },
        { ACTION_RENAME_FILE, action_rename_file, "s" },
        { ACTION_RENAME_FOLDER, action_rename_folder, "s" },
        { ACTION_DELETE, action_delete, "s" },
        { ACTION_NEW_FILE, add_new_file, "s" },
        { ACTION_NEW_FROM_TEMPLATE, add_new_from_template, "(ss)" },
        { ACTION_NEW_FOLDER, add_new_folder, "s"},
        { ACTION_CLOSE_FOLDER, action_close_folder, "s"},
        { ACTION_CLOSE_OTHER_FOLDERS, action_close_other_folders, "s"}
    };

    private GLib.Settings settings;
    private Scratch.Services.GitManager git_manager;
    private Scratch.Services.PluginsManager plugins;

    public signal void file_activate (string file);
    public signal bool rename_request (File file);

    public SimpleActionGroup actions { get; private set; }
    public string icon_name { get; set; }
    public string title { get; set; }

    public FileView (Scratch.Services.PluginsManager plugins_manager) {
        plugins = plugins_manager;
    }

    construct {
        activate_on_single_click = true;
        icon_name = "folder-symbolic";
        title = _("Folders");

        settings = new GLib.Settings ("io.elementary.code.folder-manager");

        git_manager = Scratch.Services.GitManager.get_instance ();

        actions = new SimpleActionGroup ();
        actions.add_action_entries (ACTION_ENTRIES, this);
        insert_action_group (ACTION_GROUP, actions);

        Scratch.saved_state.changed["order-folders"].connect (() => {
            order_folders ();
        });

        // Convert ListView signal into file_activate
        activate.connect ((pos) => {
            var item = model.get_item (pos);
            if (item is FileItem) {
                activate_file (((FileItem) item).file);
            }
        });
    }

    private void action_close_folder (SimpleAction action, GLib.Variant? parameter) {
        var path = parameter.get_string ();
        if (path == null || path == "") {
            return;
        }

        var project_item = find_path (null, path) as ProjectFolderItem;
        if (project_item == null) {
            return;
        }

        project_item.closed ();
    }

    private void action_close_other_folders (SimpleAction action, GLib.Variant? parameter) {
        var path = parameter.get_string ();
        if (path == null || path == "") {
            return;
        }

        var folder_root = find_path (null, path) as ProjectFolderItem;
        if (folder_root == null) {
            return;
        }

        List<Code.TreeListItem> to_remove = null;
        iterate_children (null, (child) => {
            var project_folder_item = (ProjectFolderItem) child;
            if (project_folder_item != folder_root) {
                activate_action (
                    MainWindow.ACTION_PREFIX + MainWindow.ACTION_CLOSE_PROJECT_DOCS,
                    "s",
                    project_folder_item.path
                );
                to_remove.prepend (project_folder_item);
                git_manager.remove_project (project_folder_item);
            }

            return Code.TreeList.ITERATE_CONTINUE;
        });

        remove_root_children (to_remove);
        //Make remaining project the active one
        set_project_active (path);
    }

    private void action_set_active_project (SimpleAction action, GLib.Variant? parameter) {
        var path = parameter.get_string ();
        if (path == null || path == "") {
            return;
        }

        set_active_project (path);
    }

    private ProjectFolderItem? set_active_project (string path) {
        var folder_root = find_path (null, path) as ProjectFolderItem;
        if (folder_root == null) {
            return null;
        }

        git_manager.active_project_path = path;

        write_settings ();

        return folder_root;
    }

    private void set_project_active (string path) {
        activate_action (
            MainWindow.ACTION_PREFIX + MainWindow.ACTION_SET_ACTIVE_PROJECT,
            "s",
            path
        );
    }

    public async void restore_saved_state () {
        foreach (unowned string path in settings.get_strv ("opened-folders")) {
            yield add_folder (new File (path), false, true);
        }
    }

    public void open_folder (File folder) {
        if (is_open (folder)) {
            var existing = find_path (null, folder.path);
            if (existing is Code.Widgets.SourceList.ExpandableItem) {
                ((Code.Widgets.SourceList.ExpandableItem)existing).expanded = true;
            }

            return;
        }

        add_folder.begin (folder, true);
    }

    public void collapse_all () {
        iterate_children (null, (child) => {
            child.collapse_all (true, true);
        });
    }

    public void order_folders () {
        if (!Scratch.saved_state.get_boolean ("order-folders")) {
            return;
        }

        sort_root_children ((a, b) => {
            return strcmp (
                ((ProjectFolderItem)a).name.down (),
                ((ProjectFolderItem)b).name.down ()
            );
        });
    }

    public void select_path (string path) {
        find_path (null, path);
    }

    public void unselect_all () {
        selected = null;
    }

    public void collapse_other_projects () {
        unowned string path;
        path = git_manager.active_project_path;

        iterate_children (null, (child) => {
            var project_folder = ((ProjectFolderItem) child);
            if (project_folder.path != path) {
                project_folder.expanded = false;
                activate_action (
                    MainWindow.ACTION_PREFIX + MainWindow.ACTION_HIDE_PROJECT_DOCS,
                    "s",
                    project_folder.path
                );
            } else if (project_folder.path == path) {
                project_folder.expanded = true;
                activate_action (
                    MainWindow.ACTION_PREFIX + MainWindow.ACTION_RESTORE_PROJECT_DOCS,
                    "s",
                    project_folder.path
                );
            }

            return Code.TreeList.ITERATE_CONTINUE;
        });
    }

    public void branch_actions (string path) {
        // Must only carry out branch actions on active project so switch if necessary.
        //TODO Warn before switching active project?
        var active_project = set_active_project (path);
        if (active_project == null || !active_project.is_git_repo) {
            Gdk.Display.get_default ().beep ();
            return;
        }

        var dialog = new Dialogs.BranchActionDialog (active_project);
        dialog.response.connect ((res) => {
            if (res == Gtk.ResponseType.APPLY) {
                perform_branch_action (dialog);
            }

            dialog.destroy ();
        });

        dialog.present ();
    }

    private void perform_branch_action (
        Scratch.Dialogs.BranchActionDialog dialog
    ) {
        switch (dialog.action) {
            case CHECKOUT:
                dialog.project.checkout_branch_ref (dialog.branch_ref);
                break;
            case COMMIT:
                break;
            case PUSH:
                break;
            case PULL:
                break;
            case MERGE:
                break;
            case DELETE:
                break;
            case CREATE:
                dialog.project.new_branch (dialog.new_branch_name);
                break;
            default:
                assert_not_reached ();
        }
    }

    private Code.TreeListItem? find_path (
        Code.TreeListItem? list,  // Starting point for search
        string path, // File path to search fod
        bool expand = false, // Whether to expsnd to show found item
        GLib.File? target_file = null // Alternatively find this file
    ) {

        var model = list != null ? list.child_model : root_model;
        var target = target_file ?? GLib.File.new_for_path (path);
        Code.TreeListItem? matched_item = null;

        iterate_children (null, (item) => {
            if ((item is Item) && item.path == path) {
                matched_item = item;
                return Code.TreeList.ITERATE_STOP;
            }

            if (item is FolderItem) {
                var folder = item as FolderItem;
                var folder_root = folder.file.file;
                if (folder_root.get_relative_path (target) == null) {
                    return Code.TreeList.ITERATE_CONTINUE;
                }

                if (!folder.is_expanded) {
                     if (expand) {
                         folder.load_children (); //Synchronous
                         folder.is_expanded = true;
                     } else {
                         return Code.TreeList.ITERATE_CONTINUE;
                     }
                 }

                var recurse_item = find_path (folder, path, expand, target);
                if (recurse_item != null) {
                    matched_item = recurse_item;
                    return Code.TreeList.ITERATE_STOP;
                }
            }

            return Code.TreeList.ITERATE_CONTINUE;
        });

        return matched_item;
    }

    public bool project_is_open (string project_path) {
        return get_project_for_file (GLib.File.new_for_path (project_path)) != null;
    }

    public ProjectFolderItem? get_project_for_file (GLib.File file) {
        ProjectFolderItem? matched_project = null;
        iterate_children (null, (item) => {
            if (item is ProjectFolderItem) {
                var folder = (ProjectFolderItem) item;
                if (folder.file.file.equal (file) || folder.contains_file (file)) {
                    matched_project = folder;
                    return Code.TreeList.ITERATE_STOP;
                }
            }

            return Code.TreeList.ITERATE_CONTINUE;
        });

        return matched_project;
    }

    public Code.TreeListItem? expand_to_path (string path) {
         return find_path (null, path, true);
    }

    /* Do global search on project containing the file path supplied in parameter */
    public void search_global (string path, string? term = null) {
        var item_for_path = (Item?)(expand_to_path (path));
        if (item_for_path != null) {
            var search_root = item_for_path.get_root_folder ();
            if (search_root is ProjectFolderItem) {
                GLib.File start_folder = (item_for_path is FolderItem)
                    ? item_for_path.file.file
                    : search_root.file.file;

                bool is_explicit = !(item_for_path is ProjectFolderItem);
                search_root.global_search.begin (start_folder, term, is_explicit);
            }
        }
    }

    public void clear_badges () {
        iterate_children (null, (child) => {
            if (child is ProjectFolderItem) {
                ((FolderItem)child).remove_all_badges ();
            }

            return Code.TreeList.ITERATE_CONTINUE;
        });
    }

    public void folder_item_update_hook (GLib.File source, GLib.File? dest, GLib.FileMonitorEvent event) {
        plugins.hook_folder_item_change (source, dest, event);
    }

    // This only works when the list is stable (nothing being added, expanded etc)
    private void rename_file (string path) {
        this.select_path (path);
        if (this.start_editing_item (selected)) {
            ulong once = 0;
            once = selected.edited.connect ((new_name) => {
                selected.disconnect (once);
                var new_path = Path.get_dirname (path) + Path.DIR_SEPARATOR_S + new_name;
                activate_action (
                    MainWindow.ACTION_PREFIX + MainWindow.ACTION_CLOSE_TAB,
                    "s",
                    path
                );

                // RecentManager requires valid URI
                var new_uri = "file://" + new_path; // Code only edits local files
                Gtk.RecentManager.get_default ().add_item (new_uri);

                activate (new_path);
            });
        }

        // Handle cancelled rename (which does not produce signal)
        Timeout.add (200, () => {
            if (this.editing) {
                return Source.CONTINUE;
            } else {
                // Avoid selected but unopened item if rename cancelled (they would not open if clicked on)
                this.unselect_all ();
                return Source.REMOVE;
            }
        });
    }

    private void rename_folder (string path) {
        var folder_to_rename = find_path (null, path) as FolderItem;
        if (folder_to_rename == null) {
            critical ("Could not find folder from given path to rename: %s", path);
            return;
        }

        folder_to_rename.selectable = true;
        if (start_editing_item (folder_to_rename)) {
            // Need to poll view as no signal emited when editing cancelled and need to set
            // selectable to false anyway.
            Timeout.add (200, () => {
                if (editing) {
                    return Source.CONTINUE;
                } else {
                    unselect_all ();
                    // Must do this *after* unselecting all else sourcelist breaks
                    folder_to_rename.selectable = false;
                }

                return Source.REMOVE;
            });
        } else {
            critical ("Could not rename %s", path);
            folder_to_rename.selectable = false;
        }
    }

    private void rename_items_with_same_name (Item item) {
        string item_name = item.file.name;
        iterate_children (null, (child) => {
            string new_other_item_name, new_item_name;
            var other_item = (ProjectFolderItem) child;

            if (Utils.find_unique_path (
                    item.file.file,
                    other_item.file.file,
                    out new_item_name,
                    out new_other_item_name
                )
            ) {
                if (item_name.length < new_item_name.length) {
                    item_name = new_item_name;
                }

                if (other_item.name.length < new_other_item_name.length) {
                    other_item.name = new_other_item_name;
                }
            }

            return Code.TreeList.ITERATE_CONTINUE;
        });

        item.name = item_name;
    }

    private void add_new_folder (SimpleAction action, Variant? param) {
        // Using "path" of parent folder from params, call `on_add_new (true)` on `FolderItem`
        var path = param.get_string ();

        if (path == null || path == "") {
            return;
        }

        var folder = find_path (null, path) as FolderItem;
        if (folder == null) {
            return;
        }

        folder.on_add_new (true);
    }

    private void add_new_file (SimpleAction action, Variant? param) {
        // Using "path" of parent folder from params, call `on_add_new (false)` on `FolderItem`
        var path = param != null ? param.get_string () : null;

        if (path == null || path == "") {
            critical ("No path");
            return;
        }

        var folder = find_path (null, path) as FolderItem;
        if (folder == null) {
            return;
        }

        folder.on_add_new (false);
    }

    private void add_new_from_template (SimpleAction action, Variant? param) {
        // Using "path" of parent folder from params, call `on_add_new (false)` on `FolderItem`
        // var path = param.get_string ();
        string? parent_path = null, template_path = null;
        param.@get ("(ss)", out parent_path, out template_path);

        //Do we need this check?
        if (parent_path == null || parent_path == "") {
            return;
        }

        var folder = find_path (null, parent_path) as FolderItem;
        if (folder == null) {
            return;
        }

        folder.on_add_template (template_path);
    }

    private void action_launch_app_with_file_path (SimpleAction action, Variant? param) {
        var params = param.get_strv ();
        Utils.launch_app_with_file (params[1], params[0]);
    }

    private void action_show_app_chooser (SimpleAction action, Variant? param) {
        var path = param.get_string ();

        if (path == null || path == "") {
            return;
        }

        var file = GLib.File.new_for_path (path);
        var dialog = new Gtk.AppChooserDialog (new Gtk.Window (), Gtk.DialogFlags.MODAL, file);
        dialog.deletable = false;

        dialog.response.connect ((res) => {
            if (res == Gtk.ResponseType.OK) {
                var app_info = dialog.get_app_info ();
                if (app_info != null) {
                    Utils.launch_app_with_file (app_info.get_id (), path);
                }
            }

            dialog.destroy ();
        });

        dialog.show ();
    }

    private void action_execute_contract_with_file_path (SimpleAction action, Variant? param) {
        var params = param.get_strv ();
        var path = params[0];
        if (path == null || path == "") {
            return;
        }

        var contract_name = params[1];
        if (contract_name == null || contract_name == "") {
            return;
        }

        Utils.execute_contract_with_file_path (path, contract_name);
    }

    private void action_rename_file (SimpleAction action, Variant? param) {
        var path = param.get_string ();

        if (path == null || path == "") {
            return;
        }

        rename_file (path);
    }

    private void action_rename_folder (SimpleAction action, Variant? param) {
        var path = param.get_string ();

        if (path == null || path == "") {
            return;
        }

        rename_folder (path);
    }


    private void action_delete (SimpleAction action, Variant? param) {
        var path = param.get_string ();

        if (path == null || path == "") {
            return;
        }

        var item = find_path (null, path);
        if (item != null) {
            var item_to_delete = item as Scratch.FolderManager.Item;

            // Wait for ProjectFolderItem closed signal handle logic to run before moving item to trash
            if (item_to_delete is Scratch.FolderManager.ProjectFolderItem) {
                item_to_delete.closed.connect_after (() => {
                    item_to_delete.trash ();
                });
                item_to_delete.closed ();
                return;
            }

            item_to_delete.trash ();
        }
    }

    private async void add_folder (File folder, bool expand, bool restoring = false) {
        if (is_open (folder)) {
            warning ("Folder '%s' is already open.", folder.path);
            return;
        } else if (!folder.is_valid_directory) {
            warning ("Cannot open invalid directory.");
            return;
        }

        var add_file = folder.file;
        // Need to deal with case where folder is parent or child of an existing project
        var parents = new List<ProjectFolderItem> ();
        var children = new List<ProjectFolderItem> ();

        iterate_children (null, (child) => {
            var item = (ProjectFolderItem) child;
            if (add_file.get_relative_path (item.file.file) != null) {
                debug ("Trying to add parent of existing project");
                children.append (item);
            } else if (item.file.file.get_relative_path (add_file) != null) {
                debug ("Trying to add child of existing project");
                parents.append (item);
            }

            return Code.TreeList.ITERATE_CONTINUE;
        });

        if (parents.length () > 0 || children.length () > 0) {
            assert (parents.length () <= 1);
            assert (parents.length () == 0 || children.length () == 0);
            var dialog = new Scratch.Dialogs.CloseProjectsConfirmationDialog (
                (MainWindow) get_root (),
                parents.length (),
                children.length ()
            );

            var close_projects = false;
            dialog.response.connect ((res) => {
                if (res == Gtk.ResponseType.ACCEPT) {
                    close_projects = true;
                }

                dialog.destroy ();
                add_folder.callback ();
            });

            dialog.show ();
            yield;

            if (close_projects) {
                foreach (var item in parents) {
                    item.closed ();
                }

                foreach (var item in children) {
                    item.closed ();
                }
            } else {
                return;
            }
        }

        // Process any closed signals emitted before proceeding
        Idle.add (() => {
            var folder_root = new ProjectFolderItem (folder, this); // Constructor adds project to GitManager
            add_root_item (folder_root);
            rename_items_with_same_name (folder_root);

            folder_root.expanded = expand;
            folder_root.closed.connect (() => {
                activate_action (
                    MainWindow.ACTION_PREFIX + MainWindow.ACTION_CLOSE_PROJECT_DOCS,
                    "s",
                    folder_root.path
                );

                remove_root_item (folder_root);

                iterate_children (null, (child) => {
                    var child_folder = (ProjectFolderItem) child;
                    if (child_folder.name != child_folder.file.name) {
                        rename_items_with_same_name (child_folder);
                    }

                    return Code.TreeList.ITERATE_CONTINUE;
                });

                Scratch.Services.GitManager.get_instance ().remove_project (folder_root);
                write_settings ();
            });

            // We do not want to rewrite settings while restoring from settings
            // This interferes with fuzzy-finder plugins_manager
            // See https://github.com/elementary/code/issues/1533
            if (!restoring) {
                write_settings ();
            }

            add_folder.callback ();
            return Source.REMOVE;
        });

        yield;

        order_folders ();
    }

    private bool is_open (File folder) {
        bool open = false;
        iterate_children (null, (child) => {
            if (folder.path == ((Item) child).path) {
                open = true;
                return Code.TreeList.ITERATE_STOP;
            }

            return Code.TreeList.ITERATE_CONTINUE;
        });

        return open;
    }

    private void write_settings () {
        string[] to_save = {};
        iterate_children (null, (item) => {
            var saved = false;
            var folder_path = ((Item) item).path;

            //Do we need to de-duplicate? Not possible to open a project twice?
            foreach (var saved_folder in to_save) {
                if (folder_path == saved_folder) {
                    saved = true;
                    break;
                }
            }

            if (!saved) {
                to_save += folder_path;
            }

            return Code.TreeList.ITERATE_CONTINUE;
        });

        settings.set_strv ("opened-folders", to_save);
    }
}
