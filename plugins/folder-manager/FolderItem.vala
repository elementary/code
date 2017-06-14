/*-
 * Copyright (c) 2017 elementary LLC. (https://elementary.io)
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Authored by: Julien Spautz <spautz.julien@gmail.com>, Andrei-Costin Zisu <matzipan@gmail.com>
 */

namespace Scratch.Plugins.FolderManager {
    /**
     * Expandable item in the source list, represents a folder.
     * Monitored for changes inside the directory.
     */
    internal class FolderItem : Item {
        private GLib.FileMonitor monitor;
        private bool children_loaded = false;
        private string? newly_created_path = null;

        public FolderItem (File file, FileView view) requires (file.is_valid_directory) {
            Object (file: file, view: view);        
        }
        
        construct {
            if (file.children.length () > 0) {
                add (new Granite.Widgets.SourceList.Item ("")); // dummy
            }
            
            toggled.connect (() => {
                if (expanded && n_children <= 1) {
                    clear ();
                    add_children ();
                    children_loaded = true;
                }
            });
            
            try {
                monitor = file.file.monitor_directory (GLib.FileMonitorFlags.NONE);
                monitor.changed.connect (on_changed);
            } catch (GLib.Error e) {
                warning (e.message);
            }
        }

        public override Gtk.Menu? get_context_menu () {
            var menu = new Gtk.Menu ();
            
            if (parent == view.root) {
                var item = new Gtk.MenuItem.with_label (_("Close Folder"));
                item.activate.connect (do_close);
                menu.append (item);
            } else {
                var item = new Gtk.MenuItem.with_label (_("Open"));
                item.activate.connect (() => { view.open_folder (file.path); });
                menu.append (item);
            }
            
            var rename_item = new Gtk.MenuItem.with_label (_("Rename"));
            rename_item.activate.connect (() => view.start_editing_item (this));
            menu.append (rename_item);

            var new_file_item = new Gtk.MenuItem.with_label (_("Add File"));
            new_file_item.activate.connect (() => add_file ());
            menu.append (new_file_item);

            var new_folder_item = new Gtk.MenuItem.with_label (_("Add Folder"));
            new_folder_item.activate.connect(() => add_folder ());
            menu.append (new_folder_item);

            var delete_item = new Gtk.MenuItem.with_label (_("Move to Trash"));
            delete_item.activate.connect (() => do_remove ());
            menu.append (delete_item);
            
            menu.show_all ();
            return menu;
        }

        private void add_children () {
            foreach (var child in file.children) {
                if (child.is_valid_directory) {
                    var item = new FolderItem (child, view);
                    add (item);
                } else if (child.is_valid_textfile) {
                    var item = new FileItem (child, view);
                    add (item);
                }
            }
        }
        
        private void do_close () {
            monitor.cancel ();
            view.close_folder (path);
        }

        private new void do_remove () {
            if (parent == view.root) {
                do_close ();
            }

            base.do_remove ();
        }

        private void on_changed (GLib.File source, GLib.File? dest, GLib.FileMonitorEvent event) {
            if (!children_loaded) {
                switch (event) {
                    case GLib.FileMonitorEvent.DELETED:
                        // This is a pretty intensive operation. For each file deleted, the cache will be
                        // invalidated and recreated again, from disk. If it turns out users are seeing 
                        // slugishness or slowness when deleting a lot of files, then it might be worth
                        // doing some sort of timer deferred action.
                        file.invalidate_cache ();
                        if (file.children.length () == 0) {
                            clear ();
                        }
                        break;
                    case GLib.FileMonitorEvent.CREATED:
                        if (source.query_exists () == false) {
                            return;
                        }
                        
                        if (n_children == 0) {
                            add (new Granite.Widgets.SourceList.Item ("")); // dummy
                        }
                        break;
                }
            } else {
                switch (event) {
                    case GLib.FileMonitorEvent.DELETED:
                        var children_tmp = new Gee.ArrayList<Granite.Widgets.SourceList.Item> ();
                        children_tmp.add_all (children);
                        foreach (var item in children_tmp) {
                            if ((item as Item).path == source.get_path ()) {
                                // This is a workaround for SourceList silliness: you cannot remove an item 
                                // without it automatically selecting another one.
                                view.ignore_next_select = true;
                                remove (item);
                                view.selected = null;
                            }
                        }

                        break;
                    case GLib.FileMonitorEvent.CREATED:
                        if (source.query_exists () == false) {
                            return;
                        }

                        var file = new File (source.get_path ());
                        var exists = false;
                        foreach (var item in children) {
                            if ((item as Item).path == file.path) {
                                exists = true;
                            }
                        }

                        Item? item = null;

                        if (!exists) {
                            if (file.is_valid_textfile) {
                                item = new FileItem (file, view);
                            } else if (file.is_valid_directory) {
                                item = new FolderItem (file, view);
                            }
                        }

                        if (item != null) {
                            add (item);

                            if (source.get_path () == newly_created_path) {
                                newly_created_path = null;

                                /* 
                                 * Avoid race condition between adding and editing folder item
                                 * (not required for file items).
                                 */
                                GLib.Idle.add(() => { 
                                    view.start_editing_item (item);
                                    return false;
                                });
                            }
                        }

                        break;
                }
            }    
        }
        
        private void add_folder () {
            if (!file.is_executable) {
                // This is necessary to avoid infinite loop below
                warning("Unable to open parent folder");
                return;
            }

            var new_folder = file.file.get_child (_("untitled folder"));

            var n = 1;
            while (new_folder.query_exists ()) {
                new_folder = file.file.get_child (_("untitled folder %d").printf (n));
                n++;
            }

            try {
                expanded = true;

                new_folder.make_directory ();

                newly_created_path = new_folder.get_path ();
            } catch (Error e) {
                warning (e.message);
            }
        }

        private void add_file () {
            if (!file.is_executable) {
                // This is necessary to avoid infinite loop below
                warning("Unable to open parent folder");
                return;
            }

            var new_file = file.file.get_child (_("new file"));

            var n = 1;
            while (new_file.query_exists ()) {
                new_file = file.file.get_child (_("new file %d").printf (n));
                n++;
            }

            try {
                expanded = true;

                new_file.create (FileCreateFlags.NONE);

                newly_created_path = new_file.get_path ();
            } catch (Error e) {
                warning (e.message);
            }
        }
    }
}