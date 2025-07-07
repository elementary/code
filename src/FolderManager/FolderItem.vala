/*-
 * Copyright (c) 2017-2018 elementary LLC. (https://elementary.io),
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
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Authored by: Julien Spautz <spautz.julien@gmail.com>, Andrei-Costin Zisu <matzipan@gmail.com>
 */

namespace Scratch.FolderManager {
    /**
     * Expandable item in the source list, represents a folder.
     * Monitored for changes inside the directory.
     */
    public class FolderItem : Item {
        private GLib.FileMonitor monitor;
        private bool children_loaded = false;
        private bool has_dummy;
        private Code.Widgets.SourceList.Item dummy; /* Blank item for expanded empty folders */

        public bool loading_required {
            get {
                return !children_loaded && n_children <= 1 && file.children.size > 0;
            }
        }

        public signal void children_finished_loading ();

        public FolderItem (File file, FileView view) {
            Object (file: file, view: view);
        }

        ~FolderItem () {
            monitor.cancel ();
        }

        construct {
            selectable = false;

            dummy = new Code.Widgets.SourceList.Item ("");
            // Must add dummy on unexpanded folders else expander will not show
            ((Code.Widgets.SourceList.ExpandableItem)this).add (dummy);
            has_dummy = true;

            toggled.connect (on_toggled);

            try {
                monitor = file.file.monitor_directory (GLib.FileMonitorFlags.NONE);
                monitor.changed.connect (on_changed);
            } catch (GLib.Error e) {
                warning (e.message);
            }
        }


        public void load_children () {
            if (loading_required) {
                foreach (var child in file.children) {
                    add_child (child);
                }

                after_children_loaded ();
            }
        }

        private async void load_children_async () {
            if (loading_required) {
                foreach (var child in file.children) {
                    Idle.add (() => {
                        add_child (child);
                        load_children_async.callback ();
                        return Source.REMOVE;
                    });

                    yield;
                }
            }

            after_children_loaded ();
        }

        private void add_child (File child) {
            Code.Widgets.SourceList.Item item = null;
            if (child.is_valid_directory) {
                item = new FolderItem (child, view);
            } else if (child.is_valid_textfile) {
                item = new FileItem (child, view);
            }

            if (item != null) {
                add (item);
            }
        }

        private void after_children_loaded () {
            children_loaded = true;
            var root = get_root_folder ();
            if (root != null) {
                root.child_folder_loaded (this); //Updates child status emblens
            }

            children_finished_loading ();
        }

        private void on_toggled () {
            if (expanded) {
                load_children_async.begin ();
                return;
            } else {
                var root = get_root_folder ();
                if (root != null &&
                    root.monitored_repo != null) {
                    //When toggled closed, update status to reflect hidden contents
                    root.update_item_status (this);
                }
            }
        }

        public override Gtk.Menu? get_context_menu () {
            GLib.FileInfo info = null;
            try {
                info = file.file.query_info (GLib.FileAttribute.STANDARD_CONTENT_TYPE, GLib.FileQueryInfoFlags.NONE);
            } catch (Error e) {
                warning (e.message);
            }

            var file_type = info.get_content_type ();

            var contractor_items = Utils.create_contract_items_for_file (file.file);

            var rename_menu_item = new GLib.MenuItem (
                _("Rename"),
                GLib.Action.print_detailed_name (
                    FileView.ACTION_PREFIX + FileView.ACTION_RENAME_FOLDER,
                    new Variant.string (file.path)
                )
            );

            var delete_item = new GLib.MenuItem (
                _("Move to Trash"),
                GLib.Action.print_detailed_name (
                    FileView.ACTION_PREFIX + FileView.ACTION_DELETE,
                    new Variant.string (file.path)
                )
            );

            var search_item = new GLib.MenuItem (
                _("Find in Folder…"),
                GLib.Action.print_detailed_name (
                    MainWindow.ACTION_PREFIX + MainWindow.ACTION_FIND_GLOBAL,
                    new Variant.string (file.file.get_path ())
                )
            );

            var external_actions_section = new GLib.Menu ();
            external_actions_section.append_item (create_submenu_for_open_in (file_type));
            if (contractor_items.get_n_items () > 0) {
                external_actions_section.append_submenu (_("Other Actions"), contractor_items);
            }

            var direct_actions_section = new GLib.Menu ();
            direct_actions_section.append_item (create_submenu_for_new ());
            direct_actions_section.append_item (rename_menu_item);
            direct_actions_section.append_item (delete_item);

            var search_section = new GLib.Menu ();
            search_section.append_item (search_item);

            var menu_model = new GLib.Menu ();
            menu_model.append_section (null, external_actions_section);
            menu_model.append_section (null, direct_actions_section);
            menu_model.append_section (null, search_section);

            var menu = new Gtk.Menu.from_model (menu_model);
            menu.insert_action_group (FileView.ACTION_GROUP, view.actions);
            return menu;
        }

        protected GLib.MenuItem create_submenu_for_open_in (string? file_type) {
            var open_in_terminal_pane_item = new GLib.MenuItem (
                (_("Terminal Pane")),
                GLib.Action.print_detailed_name (
                    MainWindow.ACTION_PREFIX + MainWindow.ACTION_OPEN_IN_TERMINAL,
                    new Variant.string (file.path)
                )
            );
            open_in_terminal_pane_item.set_icon (new ThemedIcon ("panel-bottom-symbolic"));

            var other_menu_item = new GLib.MenuItem (
                _("Other Application…"),
                GLib.Action.print_detailed_name (
                    FileView.ACTION_PREFIX + FileView.ACTION_SHOW_APP_CHOOSER,
                    file.path
                )
            );

            var extra_section = new GLib.Menu ();
            extra_section.append_item (other_menu_item);

            var terminal_pane_section = new Menu ();
            terminal_pane_section.append_item (open_in_terminal_pane_item);

            file_type = file_type ?? "inode/directory";

            var open_in_menu = new GLib.Menu ();
            open_in_menu.append_section (null, terminal_pane_section);
            open_in_menu.append_section (null, Utils.create_executable_app_items_for_file (file.file, file_type));
            open_in_menu.append_section (null, extra_section);

            var open_in_menu_item = new GLib.MenuItem.submenu (_("Open In"), open_in_menu);
            return open_in_menu_item;
        }

        protected GLib.MenuItem create_submenu_for_new () {
            var new_folder_item = new GLib.MenuItem (
                _("Folder"),
                GLib.Action.print_detailed_name (
                    FileView.ACTION_PREFIX + FileView.ACTION_NEW_FOLDER,
                    new Variant.string (file.path)
                )
            );

            var new_file_item = new GLib.MenuItem (
                _("Empty File"),
                GLib.Action.print_detailed_name (
                    FileView.ACTION_PREFIX + FileView.ACTION_NEW_FILE,
                    new Variant.string (file.path)
                )
            );

            var new_menu = new GLib.Menu ();
            new_menu.append_item (new_folder_item);
            new_menu.append_item (new_file_item);

            string? template_path = null;
            var app_template_path = Scratch.Utils.replace_tilde_with_home (settings.get_string ("default-file-templates-directory"));
            var app_template_file = GLib.File.new_for_path (app_template_path);
            if (!app_template_file.query_exists ()) {
                unowned var user_template_path = GLib.Environment.get_user_special_dir (GLib.UserDirectory.TEMPLATES);
                if (user_template_path != null) {
                    template_path = user_template_path;
                }
            } else {
                template_path = app_template_path;
            }

            //Append any templates/template folders.
            if (template_path != null) {
                load_templates_from_folder (GLib.File.new_for_path (template_path), new_menu);
            }

            var new_item = new GLib.MenuItem.submenu (_("New"), new_menu);
            new_item.set_submenu (new_menu);

            return new_item;
        }

        //Adapted from Files app code
        const int MAX_TEMPLATES = 2048;
        private void load_templates_from_folder (GLib.File template_folder, Menu new_submenu, uint count = 0) {
            GLib.List<GLib.File> template_list = null;
            GLib.List<GLib.File> folder_list = null;

            GLib.FileEnumerator enumerator;
            var flags = GLib.FileQueryInfoFlags.NOFOLLOW_SYMLINKS;
            try {
                enumerator = template_folder.enumerate_children ("standard::*", flags, null);
                GLib.File location;
                GLib.FileInfo? info = enumerator.next_file (null);

                while (count < MAX_TEMPLATES && (info != null)) {
                    if (!info.get_attribute_boolean (GLib.FileAttribute.STANDARD_IS_BACKUP)) {
                        location = template_folder.get_child (info.get_name ());
                        if (info.get_file_type () == GLib.FileType.DIRECTORY) {
                            folder_list.prepend (location);
                        } else {
                            template_list.prepend (location);
                            count ++;
                        }
                    }

                    info = enumerator.next_file (null);
                }
            } catch (GLib.Error error) {
                return;
            }

            if (folder_list.length () > 0) {
                folder_list.sort ((a, b) => {
                    return strcmp (a.get_basename ().down (), b.get_basename ().down ());
                });

                folder_list.@foreach ((folder) => {
                    var folder_submenu = new Menu ();
                    var folder_submenuitem = new MenuItem.submenu (
                        folder.get_basename (),
                        folder_submenu
                    );

                    new_submenu.append_item (folder_submenuitem);
                    load_templates_from_folder (folder, folder_submenu, count);
                });
            }

            if (template_list.length () > 0) {
                template_list.sort ((a, b) => {
                    return strcmp (a.get_basename ().down (), b.get_basename ().down ());
                });

                template_list.@foreach ((template) => {
                    var template_menuitem = new MenuItem (
                        template.get_basename (),
                        GLib.Action.print_detailed_name (
                            FileView.ACTION_PREFIX + FileView.ACTION_NEW_FROM_TEMPLATE,
                            new Variant ("(ss)", this.path, template.get_path ())
                        )
                    );

                    new_submenu.append_item (template_menuitem);
                });
            }
        }

        public void remove_all_badges () {
            foreach (var child in children) {
                remove_badge (child);
            }
        }

        private void remove_badge (Code.Widgets.SourceList.Item item) {
            if (item is FolderItem) {
                ((FolderItem) item).remove_all_badges ();
            }

            item.badge = "";
        }

        public new void add (Code.Widgets.SourceList.Item item) {
            if (has_dummy && n_children == 1) {
                ((Code.Widgets.SourceList.ExpandableItem)this).remove (dummy);
                has_dummy = false;
            }

            base.add (item);
        }

        public new void remove (Code.Widgets.SourceList.Item item) {
            if (item is FolderItem) {
                var folder = (FolderItem)item;
                foreach (var child in folder.children) {
                    folder.remove (child);
                }
            }

            ((Code.Widgets.SourceList.ExpandableItem)this).remove (item);
            // Add back dummy if empty
            if (!(has_dummy || n_children > 0)) {
                ((Code.Widgets.SourceList.ExpandableItem)this).add (dummy);
                has_dummy = true;
            }
        }

        public new void clear () {
            ((Code.Widgets.SourceList.ExpandableItem)this).clear ();
            has_dummy = false;
        }

        protected virtual void on_changed (GLib.File source, GLib.File? dest, GLib.FileMonitorEvent event) {
            if (source.get_basename ().has_prefix (".goutputstream")) {
                return; // Ignore changes due to temp files and streams
            }

            view.folder_item_update_hook (source, dest, event);

            if (!children_loaded) { // No child items except dummy, child never expanded
                /* Empty folder with dummy item will come here even if expanded */
                switch (event) {
                    case GLib.FileMonitorEvent.DELETED:
                        file.invalidate_cache (); //TODO Throttle if required
                        if (expanded) {
                            toggled ();
                        }
                        break;
                    case GLib.FileMonitorEvent.CREATED:
                        file.invalidate_cache ();  //TODO Throttle if required
                        if (expanded) {
                            toggled ();
                        }
                        break;
                    case FileMonitorEvent.RENAMED:
                    case FileMonitorEvent.PRE_UNMOUNT:
                    case FileMonitorEvent.UNMOUNTED:
                    case FileMonitorEvent.CHANGED:
                    case FileMonitorEvent.CHANGES_DONE_HINT:
                    case FileMonitorEvent.MOVED:
                    case FileMonitorEvent.MOVED_IN:
                    case FileMonitorEvent.MOVED_OUT:
                    case FileMonitorEvent.ATTRIBUTE_CHANGED:

                        break;
                }
            } else { // Child has been expanded ( but could be closed now) and items loaded (or dummy)
                // No cache invalidation is needed here because the entire state is kept in the tree
                switch (event) {
                    case GLib.FileMonitorEvent.DELETED:
                        // Find item corresponding to deleted file
                        // Note may not be found if deleted file is not valid for display
                        var path_item = find_item_for_path (source.get_path ());
                        if (path_item != null) {
                            remove (path_item);
                        }

                        break;
                    case GLib.FileMonitorEvent.CREATED:
                        if (source.query_exists () == false) {
                            return;
                        }
                        var path_item = find_item_for_path (source.get_path ());
                        if (path_item == null) {
                            var file = new File (source.get_path ());
                            if (file.is_valid_directory) {
                                path_item = new FolderItem (file, view);
                            } else if (file.is_valid_textfile) {
                                path_item = new FileItem (file, view);
                            }

                            add (path_item); // null parameter is silently ignored
                        }

                        break;
                    case FileMonitorEvent.RENAMED:
                    case FileMonitorEvent.PRE_UNMOUNT:
                    case FileMonitorEvent.UNMOUNTED:
                    case FileMonitorEvent.CHANGED:
                    case FileMonitorEvent.CHANGES_DONE_HINT:
                    case FileMonitorEvent.MOVED:
                    case FileMonitorEvent.MOVED_IN:
                    case FileMonitorEvent.MOVED_OUT:
                    case FileMonitorEvent.ATTRIBUTE_CHANGED:
                        break;
                }
            }

            // Reduce spamming of root (still results in multiple signals per change in file being edited
            //TODO Throttle this signal?
            if (event == FileMonitorEvent.CHANGES_DONE_HINT) {
                //TODO Get root folder once as it will not change for the life of this folder
                var root = get_root_folder (this);
                if (root != null) {
                    root.child_folder_changed (this);
                }
            }
        }

        private FolderManager.Item? find_item_for_path (string path) {
            foreach (var item in children) {
                // Item could be dummy
                if ((item is FolderManager.Item) && ((FolderManager.Item) item).path == path) {
                    return (FolderManager.Item)item;
                }
            }

            return null;
        }

        public void on_add_new (bool is_folder, string? template_path = null) {
            if (!file.is_executable) {
                // This is necessary to avoid infinite loop below
                warning ("Unable to open parent folder");
                return;
            }

            string name;
            GLib.File? template_file = null;
            if (template_path == null) {
                name = is_folder ? _("untitled folder") : _("new file");
            } else {
                ///TRANSLATORS %s is the placeholder for the path of a template file
                name = template_file.get_basename ();
                template_file = GLib.File.new_for_path (template_path);
            }

            GLib.File new_file = file.file.get_child (name);
            var n = 1;

            while (new_file.query_exists ()) {
                new_file = file.file.get_child (("%s %d").printf (name, n));
                n++;
            }

            name = new_file.get_basename ();
            if (template_file != null) {
                //Assume templates are small and can be copied without problems
                try {
                    template_file.copy (
                        new_file,
                        TARGET_DEFAULT_MODIFIED_TIME | TARGET_DEFAULT_PERMS | NOFOLLOW_SYMLINKS,
                        null, //No cancellable
                        null  //No progress
                    );
                } catch (Error e) {
                    warning ("Error copying template %s", e.message);
                    return;
                }
            }

            if (!expanded) {
                expanded = true;  // causes async loading of children
                ulong once = 0;
                once = children_finished_loading.connect (() => {
                    this.disconnect (once);
                    rename_new (name, is_folder);
                });
            } else {
                rename_new (name, is_folder);
            }
        }

        private void rename_new (string name, bool is_folder) {
            var rename_item = new RenameItem (name, is_folder);
            add (rename_item);
            GLib.Idle.add (() => {  //wait for added item to realize
                if (view.start_editing_item (rename_item)) {
                    ulong once = 0;
                    once = rename_item.edited.connect (() => {
                        rename_item.disconnect (once);
                        // A name was accepted so create the corresponding file
                        var new_name = rename_item.name;
                        try {
                            var gfile = file.file.get_child_for_display_name (new_name);
                            if (rename_item.is_folder) {
                                gfile.make_directory ();
                            } else {
                                gfile.create (FileCreateFlags.NONE);
                                view.activate (gfile.get_path ());
                            }
                        } catch (Error e) {
                            warning (e.message);
                        }
                    });

                    /* Need to remove rename item even when editing cancelled so cannot use "edited" signal */
                    Timeout.add (200, () => {
                        if (view.editing) {
                            return Source.CONTINUE;
                        } else {
                            remove (rename_item);
                            return Source.REMOVE;
                        }
                    });
                } else {
                    critical ("Failed to rename new item");
                    remove (rename_item);
                }

            return Source.REMOVE;
        });
    }



    internal class RenameItem : Code.Widgets.SourceList.Item {
        public bool is_folder { get; construct; }

        public RenameItem (string name, bool is_folder) {
            Object (
                name: name,
                is_folder: is_folder
            );
        }

        construct {
            editable = true;
            selectable = true;
            edited.connect (on_edited);

            if (is_folder) {
                icon = GLib.ContentType.get_icon ("inode/directory");
            } else {
                icon = GLib.ContentType.get_icon ("text");
            }
        }

        private void on_edited (string new_name) {
            if (new_name != "") {
                name = new_name;
            }
        }
    }
}
