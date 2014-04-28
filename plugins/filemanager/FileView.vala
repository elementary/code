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

namespace Scratch.Plugins.FileManager {

    Settings settings;

    /**
     * SourceList that displays folders and their contents.
     */
    internal class FileView : Granite.Widgets.SourceList {

        public FolderItem? folder = null;

        public signal void select (string file);

        public FileView () {
            this.width_request = 180;

            this.item_selected.connect ((item) => {
                select ((item as FileItem).path);
            });
            this.root.child_removed.connect (() => {
                this.selected = null;
            });
            
            settings = new Settings ();

            this.set_sort_func ((a, b) => {
                return File.compare ((a as Item).file, (b as Item).file);
            });
            
            restore_settings ();
        }

        /*public void open_folder (File folder) {
            if (is_open (folder)) {
                warning ("Folder '%s' is already open.", folder.path);
                return;
            } else if (!folder.is_valid_directory) {
                warning ("Cannot open invalid directory.");
                return;
            }

            add_folder (folder, true);
            write_settings ();
        }*/

        public void open_parent () {
            GLib.File parent = this.folder.file.file.get_parent ();
            this.root.remove (this.folder);
            open_folder (new File (parent.get_path ()));
        } 
        
        public void open_folder (File folder, bool expand = true) {
            if (is_open (folder)) {
                warning ("Folder '%s' is already open.", folder.path);
                return;
            } else if (!folder.is_valid_directory) {
                warning ("Cannot open invalid directory.");
                return;
            }
            
            // Clean the SourceList before start adding something
            if (this.folder != null)
                this.root.remove (this.folder);
            
            this.folder = new FolderItem (folder, this);
            this.root.add (this.folder);

            this.folder.expanded = expand;
            
            write_settings ();
        }
        
        public void add_file () {
            string path = folder.file.file.get_path () + _("/New File");
            var file = GLib.File.new_for_path (path);
            int n = 1;
            for (;;) {
                if (file.query_exists ())
                    file = GLib.File.new_for_path (path + n.to_string ());
                else
                    break;
                n++;
            }
            try {
                file.create (FileCreateFlags.NONE);
            } catch (Error e) { warning (e.message); }
            
            var item = new FileItem (new File (file.get_path ()));
            this.folder.add (item);
        }
        
        public void remove_file () {
            if (this.selected is FileItem) {
                var file = GLib.File.new_for_path (((FileItem)selected).file.file.get_path ());
                try {
                    file.delete ();
                    this.root.remove (selected);
                } catch (Error e) {warning (e.message); }
            }
            this.selected = null;
        }
        
        private bool is_open (File folder) {
            foreach (var child in root.children)
                if (folder.path == (child as Item).path)
                    return true;
            return false;
        }

        private void write_settings () {
            settings.opened_folder = this.folder.file.file.get_path ();
        }
        
        private void restore_settings () {
            if (settings.opened_folder == "" || settings.opened_folder == null)
                settings.opened_folder = GLib.Environment.get_home_dir ();
            open_folder (new File (settings.opened_folder));
        }
    }

    internal class IconLoader {
        private static IconLoader instance;

        private int icon_size;
        private Gee.HashMap<string, unowned Gdk.Pixbuf> icon_cache;
        private Gtk.StyleContext style;

        private IconLoader () {
            icon_cache = new Gee.HashMap<string, unowned Gdk.Pixbuf> ();
            style = new Gtk.StyleContext ();

            int width, height;
            Gtk.icon_size_lookup (Gtk.IconSize.MENU, out width, out height);
            icon_size = int.max (width, height);
        }

        public static IconLoader get_default () {
            if (instance == null)
                instance = new IconLoader ();
            return instance;
        }

        public Gdk.Pixbuf get_rendered_icon (GLib.Icon icon) {
            string key = icon.to_string ();

            var cached_pixbuf = icon_cache.get (key);

            if (cached_pixbuf != null)
                return cached_pixbuf;

            var factory = Granite.Services.IconFactory.get_default ();
            var new_pixbuf = factory.load_symbolic_icon_from_gicon (style, icon, icon_size);
            icon_cache.set (key, new_pixbuf);

            return new_pixbuf;
        }
    }

    /**
     * Common interface for normal and expandable items.
     */
    internal interface Item : Granite.Widgets.SourceList.Item {
        public abstract File file { get; construct; }
        public abstract string path { get; }
    }

    /**
     * Normal item in the source list, represents a textfile.
     * TODO Remove, Rename
     */
    internal class FileItem : Granite.Widgets.SourceList.Item, Item {

        //Gtk.Menu menu;
        //Gtk.MenuItem item_trash;

        public File file { get; construct; }
        public string path { get { return file.path; } }

        public FileItem (File file) requires (file.is_valid_textfile) {
            Object (file: file);

            this.selectable = true;
            this.editable = true;
            this.name = file.name;
            this.icon = IconLoader.get_default ().get_rendered_icon (file.icon);
        }

        public void rename (string new_name) {
            string new_uri = file.file.get_parent ().get_uri () + "/" + new_name;
            debug (new_uri);
            file.rename (new_name);
        }

        /*public override Gtk.Menu? get_context_menu () {
            menu = new Gtk.Menu ();
            item_trash = new Gtk.MenuItem.with_label (_("Move to Trash"));
            menu.append (item_trash);
            item_trash.activate.connect (() => { file.trash (); });
            menu.show_all ();
            return menu;
        }*/
    }

    /**
     * Expandable item in the source list, represents a folder.
     * Monitored for changes inside the directory.
     * TODO remove, rename, create new file
     */
    internal class FolderItem : Granite.Widgets.SourceList.ExpandableItem, Item {

        //Gtk.Menu menu;
        //Gtk.MenuItem item_trash;
        //Gtk.MenuItem item_create;

        private GLib.FileMonitor monitor;
        private bool children_loaded = false;
        
        public FileView view { get; construct; }
        
        public File file { get; construct; }
        public string path { get { return file.path; } }
        
        public signal void folder_open (GLib.File folder);
        
        public FolderItem (File file, FileView view) requires (file.is_valid_directory) {
            Object (file: file,
                    view: view);

            this.editable = false;
            this.selectable = false;
            this.name = file.name;
            this.icon = IconLoader.get_default ().get_rendered_icon (file.icon);

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
            if (this == this.view.root.children.to_array ()[0])
                return null;
                
            var menu = new Gtk.Menu ();
            
            var item = new Gtk.MenuItem.with_label (_("Open"));
            item.activate.connect (() => { this.folder_open (this.file.file); });
            
            menu.append (item);
            menu.show_all ();
            
            return menu;
        }

        internal void add_children () {
            foreach (var child in file.children) {
                if (child.is_valid_directory) {
                    var item = new FolderItem (child, view);
                    item.folder_open.connect (() => {
                        this.view.open_folder (child);
                    });
                    add (item);
                } else if (child.is_valid_textfile) {
                    var item = new FileItem (child);
                    add (item);
                    item.edited.connect (item.rename);
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
                    var children_tmp = new Gee.ArrayList<Granite.Widgets.SourceList.Item> ();
                    children_tmp.add_all (children);
                    foreach (var item in children_tmp) {
                        if ((item as Item).path == source.get_path ()) {
                            remove (item);
                        }
                    }
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
                            this.add (new FolderItem (file, view));
                        // this.file.reset_cache ();
                    }
                    break;
            }
        }
    }

}
