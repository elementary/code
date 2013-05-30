// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/***
  BEGIN LICENSE

  Copyright (C) 2013 Julien Spautz <spautz.julien@gmail.com>
  This program is free software: you can redistribute it and/or modify it
  under the terms of the GNU Lesser General Public License version 3, as published
  by the Free Software Foundation.

  This program is distributed in the hope that it will be useful, but
  WITHOUT ANY WARRANTY; without even the implied warranties of
  MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
  PURPOSE.  See the GNU General Public License for more details.

  You should have received a copy of the GNU General Public License along
  with this program.  If not, see <http://www.gnu.org/licenses/>

  END LICENSE
***/

namespace ProjectManager {

    Settings settings;

    /**
     * SourceList that displays projects, i.e., their file structure.
     */
    internal class FileView : Granite.Widgets.SourceList {

        public signal void select (string file);

        public FileView () {
            this.width_request = 180;

            this.item_selected.connect ((item) => {
                select ((item as FileItem).path);
            });

            settings = new Settings ();

            settings.opened_projects.foreach ((project) => {
                add_project (project, false);
            });

            this.set_sort_func ((a, b) => {
                return File.compare ((a as Item).file, (b as Item).file);
            });
        }

        public void open_project (File project) {
            if (settings.add_project (project))
                add_project (project, true);
        }

        private void add_project (File project, bool expand) {
            var project_root = new ProjectItem (project);
            this.root.add (project_root);
            project_root.expanded = expand;
            project_root.closed.connect (() => {
                settings.remove_project (project);
                root.remove (project_root);
            });
        }
    }

    internal interface Item : Granite.Widgets.SourceList.Item {
        public abstract File file { get; construct; }
        public abstract string path { get; }
    }

    internal class FileItem : Granite.Widgets.SourceList.Item, Item {

        public File file { get; construct; }
        public string path { get { return file.path; } }

        public FileItem (File file) requires (file.is_valid_textfile) {
            Object (file: file);

            this.selectable = true;
            this.name = file.name;
            this.icon = file.icon;
        }
    }

    internal class FolderItem : Granite.Widgets.SourceList.ExpandableItem, Item {

        Gtk.Menu menu;
        Gtk.MenuItem item_expand;
        Gtk.MenuItem item_collapse;
        
        private GLib.FileMonitor monitor;
        private bool children_loaded = false;

        public File file { get; construct; }
        public string path { get { return file.path; } }

        public FolderItem (File file) requires (file.is_valid_directory) {
            Object (file: file);

            this.selectable = false;
            this.name = file.name;
            this.icon = file.icon;

            this.add (new Granite.Widgets.SourceList.Item ("")); // dummy
            this.toggled.connect (() => {
                if (this.expanded && this.n_children <= 1) {
                    this.clear ();
                    this.add_children ();
                    children_loaded = true;
                }
            });

            try {
                monitor = file.file.monitor_directory (GLib.FileMonitorFlags.NONE);
                monitor.changed.connect ((s,d,e) => { on_changed (s,d,e); });
            } catch (GLib.Error e) {
                warning (e.message);
            }
        }
        
        public override Gtk.Menu? get_context_menu () {
            menu = new Gtk.Menu ();
            item_expand = new Gtk.MenuItem.with_label (_("Expand all"));
            item_collapse = new Gtk.MenuItem.with_label (_("Collapse all"));
            menu.append (item_expand);
            menu.append (item_collapse);
            item_expand.activate.connect (() => { expand_all (); });
            item_collapse.activate.connect (() => { collapse_all (); });
            menu.show_all ();
            return menu;
        }

        internal void add_children () {
            foreach (var child in file.children) {
                if (child.is_valid_directory) {
                    var item = new FolderItem (child);
                    add (item);
                } else if (child.is_valid_textfile) {
                    var item = new FileItem (child);
                    add (item);
                }
            }
        }

        private void on_changed (GLib.File source, GLib.File? dest, GLib.FileMonitorEvent event) {

            if (!children_loaded) {
                this.file.reset_cache ();
                return;
            }

            switch (event) {

                case GLib.FileMonitorEvent.DELETED:
                    foreach (var item in children)
                        if ((item as Item).path == source.get_path ())
                            remove (item);
                    break;

                case GLib.FileMonitorEvent.CREATED:
                    if (source.query_exists () == false) {
                        return;
                    }
                    var file = new File (source.get_path ());
                    var exists = false;
                    foreach (var item in children)
                        if ((item as Item).path == file.path)
                            exists = true;

                    if (!exists) {
                        if (file.is_valid_textfile)
                            this.add (new FileItem (file));
                        else if (file.is_valid_directory)
                            this.add (new FolderItem (file));
                        // this.file.reset_cache ();
                    }
                    break;
            }
        }
    }

    internal class ProjectItem : FolderItem {

        Gtk.Menu menu;
        Gtk.MenuItem item_close;
        Gtk.MenuItem item_expand;
        Gtk.MenuItem item_collapse;

        public ProjectItem (File file) requires (file.is_valid_directory) {
            base (file);
        }

        public signal void closed ();

        public override Gtk.Menu? get_context_menu () {
            menu = new Gtk.Menu ();
            item_close = new Gtk.MenuItem.with_label (_("Close Project"));
            item_expand = new Gtk.MenuItem.with_label (_("Expand all"));
            item_collapse = new Gtk.MenuItem.with_label (_("Collapse all"));
            menu.append (item_close);
            menu.append (item_expand);
            menu.append (item_collapse);
            item_close.activate.connect (() => { closed (); });
            item_expand.activate.connect (() => { expand_all (); });
            item_collapse.activate.connect (() => { collapse_all (); });
            menu.show_all ();
            return menu;
        }
    }
}



















