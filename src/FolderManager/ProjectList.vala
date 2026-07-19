/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2026 elementary, Inc. <https://elementary.io>
 */

// //TODO Can we just use ProjectFolderItems direct?
// public class Code.ProjectListItem : Object {
//     public ProjectFolderItem project_folder { get; set construct; }
//     public ProjectList view { get; set construct; } // Needed to activate actions
//     public string path { get; construct; }
//     public GLib.File gfile { get { return project_folder.file.file; }}

//     private Code.FolderTree folder_tree;
//     private Scratch.Services.GitManager git_manager;
//     private bool is_expanded { get; set; }
//     private bool is_active_project { get { return git_manager.active_project_path == path; } }

//     public ProjectListItem (string path, ProjectList view) {
//         Object (
//             path: path,
//             view: view
//         );
//     }

//     construct {
//         folder_tree = new FolderTree (path);
//         git_manager = Scratch.Services.GitManager.get_instance ();

//         // ProjectFolderItem constructor adds project to GitManager
//         var project_folder = new ProjectFolderItem (new Code.File (path), folder_tree);

//         // Closed signal emitted when project folder is externally deleted
//         project_folder.deleted.connect (() => {
//             folder_tree.remove_all ();
//             view.item_deleted (this);
//         });

//     }

//     public bool is_or_contains_file (GLib.File gfile) {
//         return path == gfile.get_path () || folder_tree.contains_file (gfile);
//     }

//     public void collapse_all () {
//         // folder_tree.collapse_all ();
//         is_expanded = false;
//     }

//     public void expand_all () {
//         // folder_tree.expand_all ();
//         is_expanded = true;
//     }

//     // Does not remove from liststore - that is up to ProjectList
//     public void close () {
//         folder_tree.remove_all ();
//         git_manager.remove_project (project_folder); // Takes care of active_project?
//     }

//     public void set_as_active_project () {
//         git_manager.active_project_path = path;
//     }

//     public FolderManagerItem? find_path (
//         string path, // File path to search fod
//         bool expand = false // Whether to expsnd to show found item
//         // GLib.File? target_file = null // Alternatively find this file
//     ) {
//         return folder_tree.find_path (null, path, expand);
//     }
// }

namespace Code {
    // All project related actions handled in ProjectFolderItem
    public const string PROJECT_ACTION_GROUP = "project";
    public const string PROJECT_ACTION_PREFIX = "project.";
    public const string ACTION_CLOSE_PROJECT_FOLDER = "close-project-folder";
    public const string ACTION_CLOSE_OTHER_PROJECT_FOLDERS = "close-other-project-folders";
    public const string ACTION_EXECUTE_CONTRACT_WITH_FILE_PATH = "execute-contract-with-file-path";
    public const string ACTION_NEW_FILE = "new-file";
    public const string ACTION_NEW_FROM_TEMPLATE = "new-from-template";
    public const string ACTION_NEW_FOLDER = "new-folder";

    // All fileitem related actions handled in FolderTree
    public const string ITEM_ACTION_GROUP = "item";
    public const string ITEM_ACTION_PREFIX = "item.";
    public const string ACTION_RENAME_FILE = "rename-file";
    public const string ACTION_RENAME_FOLDER = "rename-folder";
    public const string ACTION_LAUNCH_APP_WITH_FILE_PATH = "launch-app-with-file-path";
    public const string ACTION_SHOW_APP_CHOOSER = "show-app-chooser";
    public const string ACTION_DELETE = "delete";
}
/* ProjectList is a flat list of FolderTrees each representing a single project */
public class Code.ProjectList : Granite.Bin, Code.PaneSwitcher {
    // Moved from folder tree to shared top widget
    // public signal bool rename_request (Code.File file);

    private const ActionEntry[] ACTION_ENTRIES = {
        { ACTION_CLOSE_PROJECT_FOLDER, action_close_project_folder, "s"},
        { ACTION_CLOSE_OTHER_PROJECT_FOLDERS, action_close_other_project_folders, "s"}
    };

    public const string CLOSE_PROJECT_DOCS_ACTION_NAME = Scratch.MainWindow.ACTION_PREFIX + Scratch.MainWindow.ACTION_CLOSE_PROJECT_DOCS;

    public SimpleActionGroup actions { get; private set; }
    public bool is_empty { get { return list_store.n_items == 0; } }

    // PaneSwitcher interface
    public string icon_name { get; set; }
    public string title { get; set; }

    private Gtk.ScrolledWindow scrolled_window;
    private Gtk.ListBox list_box;
    private GLib.ListStore list_store;
    private Gtk.NoSelection selection_model;

    private GLib.Settings settings;
    private Scratch.Services.PluginsManager plugins;


    // public ProjectList (Scratch.Services.PluginsManager plugins_manager) {
    //     plugins = plugins_manager;
    // }

    construct {
        actions = new SimpleActionGroup ();
        actions.add_action_entries (ACTION_ENTRIES, this);
        insert_action_group (PROJECT_ACTION_GROUP, actions);

        //For Code.PaneSwitcher iterface
        icon_name = "not-exist";
        title = "Projects";
        settings = new GLib.Settings ("io.elementary.code.folder-manager");
        list_store = new ListStore (typeof (ProjectFolderItem));
        selection_model = new Gtk.NoSelection (list_store);
        list_box = new Gtk.ListBox ();
        list_box.add_css_class (Granite.STYLE_CLASS_SIDEBAR);
        list_box.bind_model (
            selection_model,
            (obj) => {
                var project_item = (ProjectFolderItem) obj;
                return new ProjectListRowWidget (project_item);
            }
        );

        Scratch.saved_state.changed["order-folders"].connect (() => {
            order_folders ();
        });

        scrolled_window = new Gtk.ScrolledWindow () {
            child = list_box,
        };
        child = scrolled_window;

        list_box.activate_on_single_click = true;
        list_box.row_activated.connect ((row) => {
            var project_widget = (ProjectListRowWidget) (row.child);
            project_widget.toggle_expanded ();
        });
    }

    public async void restore_saved_state () {
        foreach (unowned string path in settings.get_strv ("opened-folders")) {
            yield add_new_project_folder (path, false, true);
        }
    }

    public void open_project_folder (File folder) {
        warning ("open project folder");
        ProjectFolderItem? listitem;
        if (is_existing_project_path (folder.path, out listitem)) {
            warning ("exists - expanding");
            listitem.expand ();
            return; //TODO Should we expand here?
        }

        add_new_project_folder.begin (folder.path, true, false);
    }

    public void collapse_all () {
        iterate_children ((listitem) => {
            // For now just collapse the top level
            listitem.is_expanded = false;
            return Code.TreeList.ITERATE_CONTINUE;
        });
    }

    public void order_folders () {
        if (!Scratch.saved_state.get_boolean ("order-folders")) {
            return;
        }

        //TODO Sorting
    }

    public void select_path (string path) {
        //TODO write find_path
        // find_path (null, path);
    }

    public void unselect_file (GLib.File file) { // Needed?
        //TODO Complete this
    }

    public void unselect_all () { // Needed??
    //TODO Call unselect all on all children.
        // tree_list.unselect_all ();
    }

    public void collapse_other_projects (string active_project_path) {
        iterate_children ((listitem) => {
            if (listitem.path != active_project_path) {
                listitem.collapse ();
                activate_action (
                    Scratch.MainWindow.ACTION_PREFIX + Scratch.MainWindow.ACTION_HIDE_PROJECT_DOCS,
                    "s",
                    listitem.path
                );
            } else {
                listitem.expand ();
                activate_action (
                    Scratch.MainWindow.ACTION_PREFIX + Scratch.MainWindow.ACTION_RESTORE_PROJECT_DOCS,
                    "s",
                    listitem.path
                );
            }

            return Code.TreeList.ITERATE_CONTINUE;
        });
    }

    public void branch_actions (string path) {
        // // Must only carry out branch actions on active project so switch if necessary.
        // //TODO Warn before switching active project?
        // var active_project = set_active_project (path);
        // if (active_project == null || !active_project.is_git_repo) {
        //     Gdk.Display.get_default ().beep ();
        //     return;
        // }

        // var dialog = new Dialogs.BranchActionDialog (active_project);
        // dialog.response.connect ((res) => {
        //     if (res == Gtk.ResponseType.APPLY) {
        //         perform_branch_action (dialog);
        //     }

        //     dialog.destroy ();
        // });

        // dialog.present ();
    }

    private void perform_branch_action (
        Scratch.Dialogs.BranchActionDialog dialog
    ) {
        // switch (dialog.action) {
        //     case CHECKOUT:
        //         dialog.project.checkout_branch_ref (dialog.branch_ref);
        //         break;
        //     case COMMIT:
        //         break;
        //     case PUSH:
        //         break;
        //     case PULL:
        //         break;
        //     case MERGE:
        //         break;
        //     case DELETE:
        //         break;
        //     case CREATE:
        //         dialog.project.new_branch (dialog.new_branch_name);
        //         break;
        //     default:
        //         assert_not_reached ();
        // }
    }

    //TODO do we need to return anything?
    // Call to find top level foldertree and then call find path on that.
    private Object? find_path (
        string path, // File path to search fod
        bool expand = false // Whether to expsnd to show found item
        // GLib.File? target_file = null // Alternatively find this file
    ) {
warning ("Project list find path %s", path);
        // var target = target_file ?? GLib.File.new_for_path (path);
        ProjectFolderItem? matched_project = null;
        iterate_children ((listitem) => {
            if (listitem.path == path) {
                matched_project = listitem;
                return Code.TreeList.ITERATE_STOP;
            }

            return Code.TreeList.ITERATE_CONTINUE;
        });

        if (matched_project != null) {
            return matched_project;
        }

        FolderManagerItem? matched_item = null;
        iterate_children ((listitem) => {
            if (path.has_prefix (listitem.path)) { //TODO Ensure paths are compatible
                matched_item = listitem.find_path (path, expand);
                return Code.TreeList.ITERATE_STOP;
            }

            return Code.TreeList.ITERATE_CONTINUE;
        });


        return matched_item;
        //     if (listitem is FolderItem) {
        //         var folder = item as FolderItem;
        //         var folder_root = folder.file.file;
        //         if (folder_root.get_relative_path (target) == null) {
        //             return Code.TreeList.ITERATE_CONTINUE;
        //         }

        //         if (!folder.is_expanded) {
        //              if (expand) {
        //                  folder.load_children (); //Synchronous
        //                  folder.is_expanded = true;
        //              } else {
        //                  return Code.TreeList.ITERATE_CONTINUE;
        //              }
        //          }

        //         var recurse_item = find_path (folder, path, expand, target);
        //         if (recurse_item != null) {
        //             matched_item = recurse_item;
        //             return Code.TreeList.ITERATE_STOP;
        //         }
        //     }

        //     return Code.TreeList.ITERATE_CONTINUE;
        // });

    }

    //TODO Is this needed?
    // // Which project any file is in
    // public ProjectFolderItem? get_project_for_file (GLib.File file) {
    //     ProjectFolderItem? matched_project_item = null;
    //     iterate_children ((listitem) => {
    //         if (listitem.is_or_contains_file (file)) {
    //             matched_project_item = listitem;
    //             return Code.TreeList.ITERATE_STOP;
    //         }

    //         return Code.TreeList.ITERATE_CONTINUE;
    //     });

    //     return matched_project_item;
    // }

    public FolderManagerItem? expand_to_path (string path) {
        var object = find_path (path, true);
        if (object is FolderManagerItem) {
            return (FolderManagerItem) object;
        }

        return null;
    }

    /* Do global search on project containing the file path supplied in parameter */
    public void search_global (string path, string? term = null) {
        var item_for_path = expand_to_path (path);
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

    // public void clear_badges () {
    //     tree_list.iterate_children (null, (child) => {
    //         if (child is ProjectFolderItem) {
    //             ((FolderItem)child).remove_all_badges ();
    //         }

    //         return Code.TreeList.ITERATE_CONTINUE;
    //     });
    // }

    // public void folder_item_update_hook (GLib.File source, GLib.File? dest, GLib.FileMonitorEvent event) {
    //     plugins.hook_folder_item_change (source, dest, event);
    // }


    public void item_deleted (ProjectFolderItem listitem) {
        // Just remove it for now
        remove_project_item (listitem);
    }


    // private void add_new_folder (SimpleAction action, Variant? param) {
    //     // Using "path" of parent folder from params, call `on_add_new (true)` on `FolderItem`
    //     var path = param.get_string ();

    //     if (path == null || path == "") {
    //         return;
    //     }

    //     var folder = find_path (null, path);
    //     if (folder == null) {
    //         return;
    //     }


    //     folder.on_add_new (true);
    // }

    // private void add_new_file (SimpleAction action, Variant? param) {
    //     // Using "path" of parent folder from params, call `on_add_new (false)` on `FolderItem`
    //     var path = param != null ? param.get_string () : null;

    //     if (path == null || path == "") {
    //         critical ("No path");
    //         return;
    //     }

    //     var folder = find_path (null, path) as FolderItem;
    //     if (folder == null) {
    //         return;
    //     }

    //     folder.on_add_new (false);
    // }

    // private void add_new_from_template (SimpleAction action, Variant? param) {
    //     // Using "path" of parent folder from params, call `on_add_new (false)` on `FolderItem`
    //     // var path = param.get_string ();
    //     string? parent_path = null, template_path = null;
    //     param.@get ("(ss)", out parent_path, out template_path);

    //     //Do we need this check?
    //     if (parent_path == null || parent_path == "") {
    //         return;
    //     }

    //     var folder = find_path (null, parent_path) as FolderItem;
    //     if (folder == null) {
    //         return;
    //     }

    //     folder.on_add_template (template_path);
    // }

    // private void action_launch_app_with_file_path (SimpleAction action, Variant? param) {
    //     var params = param.get_strv ();
    //     Utils.launch_app_with_file (params[1], params[0]);
    // }

    // private void action_show_app_chooser (SimpleAction action, Variant? param) {
    //     var path = param.get_string ();

    //     if (path == null || path == "") {
    //         return;
    //     }

    //     var file = GLib.File.new_for_path (path);
    //     var dialog = new Gtk.AppChooserDialog (new Gtk.Window (), Gtk.DialogFlags.MODAL, file);
    //     dialog.deletable = false;

    //     dialog.response.connect ((res) => {
    //         if (res == Gtk.ResponseType.OK) {
    //             var app_info = dialog.get_app_info ();
    //             if (app_info != null) {
    //                 Utils.launch_app_with_file (app_info.get_id (), path);
    //             }
    //         }

    //         dialog.destroy ();
    //     });

    //     dialog.show ();
    // }

    // private void action_execute_contract_with_file_path (SimpleAction action, Variant? param) {
        // var params = param.get_strv ();
        // var path = params[0];
        // if (path == null || path == "") {
        //     return;
        // }

        // var contract_name = params[1];
        // if (contract_name == null || contract_name == "") {
        //     return;
        // }

        // Utils.execute_contract_with_file_path (path, contract_name);
    // }




    // private void action_delete (SimpleAction action, Variant? param) {
    //     var path = param.get_string ();

    //     if (path == null || path == "") {
    //         return;
    //     }

    //     var item = find_path (null, path);
    //     if (item != null) {
    //         var item_to_delete = item as Code.FolderManagerItem;

    //         // Wait for ProjectFolderItem closed signal handle logic to run before moving item to trash
    //         if (item_to_delete is Code.ProjectFolderItem) {
    //             item_to_delete.closed.connect_after (() => {
    //                 item_to_delete.trash ();
    //             });
    //             item_to_delete.closed ();
    //             return;
    //         }

    //         item_to_delete.trash ();
    //     }
    // }

    // Only call when path is known to be a new project
    private async void add_new_project_folder (string path, bool expand, bool restoring = false) {
        var folder = new File (path);
        if (!folder.is_valid_directory) {
            warning ("Cannot open invalid directory.");
            return;
        }

        var add_file = folder.file;
        // Need to deal with case where folder is parent or child of an existing project
        var parents = new List<ProjectFolderItem> ();
        var children = new List<ProjectFolderItem> ();

        iterate_children ((listitem) => {
            // var item = (ProjectFolderItem) child;
            if (add_file.get_relative_path (listitem.gfile) != null) {
                debug ("Trying to add parent of existing project");
                children.append (listitem);
            } else if (listitem.gfile.get_relative_path (add_file) != null) {
                debug ("Trying to add child of existing project");
                parents.append (listitem);
            }

            return Code.TreeList.ITERATE_CONTINUE;
        });

        if (parents.length () > 0 || children.length () > 0) {
            assert (parents.length () <= 1);
            assert (parents.length () == 0 || children.length () == 0);
            var dialog = new Scratch.Dialogs.CloseProjectsConfirmationDialog (
                (Scratch.MainWindow) get_root (),
                parents.length (),
                children.length ()
            );

            var close_projects = false;
            dialog.response.connect ((res) => {
                if (res == Gtk.ResponseType.ACCEPT) {
                    close_projects = true;
                }

                dialog.destroy ();
                add_new_project_folder.callback ();
            });

            dialog.show ();
            yield;

            if (close_projects) {
                foreach (var listitem in parents) {
                    listitem.close ();
                    remove_project_item (listitem);
                }

                foreach (var listitem in children) {
                    listitem.close ();
                    remove_project_item (listitem);
                }
            } else {
                return;
            }
        }

        // Process any closed signals emitted before proceeding
        Idle.add (() => {
            var new_item = new ProjectFolderItem (folder, this);
            list_store.append (new_item);
            if (expand) {
                new_item.expand ();
            }
            // rename_items_with_same_name (new_project); //TODO do this later

            // We do not want to rewrite settings while restoring from settings
            // This interferes with fuzzy-finder plugins_manager
            // See https://github.com/elementary/code/issues/1533
            if (!restoring) {
                write_open_folders_setting ();
            }

            add_new_project_folder.callback ();
            return Source.REMOVE;
        });

        yield;

        // order_folders (); //TODO do later
    }

    public bool is_existing_project_path (string path, out ProjectFolderItem? list_item) {
        bool open = false;
        list_item = null;
        ProjectFolderItem? matched_item = null;
        // Only iterate this model
        iterate_children ((listitem) => {
            if (path == listitem.path) {
                open = true;
                matched_item = listitem;
                return Code.TreeList.ITERATE_STOP;
            }

            return Code.TreeList.ITERATE_CONTINUE;
        });

        list_item = matched_item;
        return open;
    }

    private void write_open_folders_setting () {
        string[] to_save = {};
        iterate_children ((listitem) => {
            var saved = false;
            //Do we need to de-duplicate? Not possible to open a project twice?
            foreach (var saved_folder in to_save) {
                if (listitem.path == saved_folder) {
                    saved = true;
                    break;
                }
            }

            if (!saved) {
                to_save += listitem.path;
            }

            return Code.TreeList.ITERATE_CONTINUE;
        });

        settings.set_strv ("opened-folders", to_save);
    }

    private void remove_project_item (ProjectFolderItem listitem) {
        activate_action (
            CLOSE_PROJECT_DOCS_ACTION_NAME,
            "s",
            listitem.path
        );

        uint pos;
        list_store.find (listitem, out pos);
        list_store.remove (pos);

    }
    private void action_close_project_folder (SimpleAction action, GLib.Variant? parameter) {
        var path = parameter.get_string ();
        if (path == null || path == "") {
            return;
        }

        iterate_children ((listitem) => {
            if (listitem.path == path) {
                listitem.close ();
                remove_project_item (listitem); // OK to remove as we stop iterating
                return TreeList.ITERATE_STOP;
            }

            return TreeList.ITERATE_CONTINUE;
        });
    }

    private void action_close_other_project_folders (SimpleAction action, GLib.Variant? parameter) {
        var path = parameter.get_string ();
        if (path == null || path == "") {
            return;
        }

        List<ProjectFolderItem> to_remove = null;
        iterate_children ((listitem) => {
            if (listitem.path != path) {
                listitem.close ();
                to_remove.prepend (listitem); // Delay removal during iteration
            }

            return TreeList.ITERATE_CONTINUE;
        });

        // List<Code.TreeListItem> to_remove = null;
        // tree_list.iterate_children (null, (child) => {
        //     var project_folder_item = (ProjectFolderItem) child;
        //     if (project_folder_item != folder_root) {
        //         activate_action (
        //             MainWindow.ACTION_PREFIX + MainWindow.ACTION_CLOSE_PROJECT_DOCS,
        //             "s",
        //             project_folder_item.path
        //         );
        //         to_remove.prepend (project_folder_item);
        //         git_manager.remove_project (project_folder_item);
        //     }

        //     return Code.TreeList.ITERATE_CONTINUE;
        // });

        foreach (ProjectFolderItem listitem in to_remove) {
            remove_project_item (listitem);
        }
    }

    private void action_set_active_project (SimpleAction action, GLib.Variant? parameter) {
        var path = parameter.get_string ();
        if (path == null || path == "") {
            return;
        }

        set_active_project (path);
    }

    //TODO Do we need both these functions???
    private ProjectFolderItem? set_active_project (string path) {
        ProjectFolderItem? project_item;
        is_existing_project_path (path, out project_item);
        project_item.set_as_active_project ();
        return project_item;
    }

    // private void set_project_active (string path) {
    //     activate_action (
    //         MainWindow.ACTION_PREFIX + MainWindow.ACTION_SET_ACTIVE_PROJECT,
    //         "s",
    //         path
    //     );
    // }

    delegate bool ProjectListIteratorCallback (ProjectFolderItem item);
    // This iterates the model objects not the listrows
    private void iterate_children (ProjectListIteratorCallback cb) {
        ProjectFolderItem? item = null;
        uint pos = 0;
        do {
            item = (ProjectFolderItem?) (list_store.get_object (pos++));
        } while (item != null && cb (item));
    }

    private void execute_contract_with_file_path (string path, string contract_name) {
        var file = GLib.File.new_for_path (path);

        try {
            var contracts = Granite.Services.ContractorProxy.get_contracts_for_file (file);
            int length = contracts.size;
            for (int i = 0; i < length; i++) {
                var contract = contracts[i];
                if (contract.get_display_name () == contract_name) {
                    contract.execute_with_file (file);
                    break;
                }
            }
        } catch (Error e) {
            warning (e.message);
        }
    }

    private class ProjectListRowWidget : Gtk.Box {
        public ProjectFolderItem project_item { get; construct; }

        private Gtk.Expander expander;
        private bool expander_locked = false;
        private Gtk.Revealer revealer;

        public ProjectListRowWidget (ProjectFolderItem project) {
            Object (
                project_item: project
            );

        }

        construct {
            var label = new Granite.HeaderLabel ("") {
                label = project_item.name,
                secondary_text = "Branch name goes here",
                hexpand = true
            };

            expander = new Gtk.Expander ("") {
                hexpand = false,
                expanded = false,
                sensitive = false, // We do not want expander interfering with listboxrow activate
                valign = CENTER
            };

            var label_box = new Gtk.Box (HORIZONTAL, 6);
            label_box.append (label);
            label_box.append (expander);

            revealer = new Gtk.Revealer () {
                child = project_item.folder_tree,
                reveal_child = false
            };

            // We want expander arrow on right so separate expander and revealer
            // We put the label and the expander in one box (horizontal) which also
            // receives menu requests.  The revealer with folder tree goes below
            orientation = VERTICAL;
            append (label_box);
            append (revealer);

            project_item.bind_property ("is-expanded", revealer, "reveal-child", BIDIRECTIONAL | SYNC_CREATE);
            revealer.bind_property ("reveal-child", expander, "expanded", BIDIRECTIONAL | SYNC_CREATE);

            var button_controller = new Gtk.GestureClick () {
                propagation_phase = CAPTURE,
                button = 0
            };

            // Assume menu is static for now
            var menu_model = project_item.get_context_menu ();
            var menu = new Gtk.PopoverMenu.from_model (menu_model) {
                position = BOTTOM
            };

            this.append (menu);

            label_box.add_controller (button_controller);
            button_controller.pressed.connect ((n_press, x, y) => {
                var event = button_controller.get_last_event (null);
                if (event.triggers_context_menu ()) { // Only true for press events
                    menu.pointing_to = Gdk.Rectangle () {x = (int)x, y = (int)y, height = 1, width = 1};
                    menu.popup ();
                }
            });
        }

        public void toggle_expanded () {
            var show = !revealer.child_revealed;
            revealer.reveal_child = show;
        }
    }

}
