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

public const string NAME = N_("Folder Manager");
public const string DESCRIPTION = N_("Basic folder manager with file browsing");

namespace Scratch.Plugins {
    public class FileManagerPlugin : Peas.ExtensionBase, Peas.Activatable {
        public Scratch.Services.Interface plugins;
        
        Gtk.Box box;
        FileManager.FileView view;

        public Object object { owned get; construct; }

        public FileManagerPlugin () {
            message ("Starting File Manager Plugin");
        }

        public void activate () {
            plugins = (Scratch.Services.Interface) object;
            plugins.hook_notebook_sidebar.connect (on_hook_sidebar);
        }

        public void deactivate () {
            if (box != null)
                box.destroy();
        }

        public void update_state () {
            
        }

        void on_hook_sidebar (Gtk.Notebook notebook) {
            if (view != null)
                return;

            box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);

            // File View
            view = new FileManager.FileView ();

            view.select.connect ((a) => {
                var file = GLib.File.new_for_path (a);
                plugins.open_file (file);
            });

            // Toolbar
            var toolbar = new Gtk.Toolbar ();
            toolbar.set_icon_size (Gtk.IconSize.SMALL_TOOLBAR);
            toolbar.get_style_context ().add_class ("inline-toolbar");

            var parent = new Gtk.ToolButton (null, null);
            parent.tooltip_text = _("Go to parent");
            parent.icon_name = "go-up-symbolic";
            parent.clicked.connect (() => {
                view.open_parent ();
                parent.sensitive = !(view.folder.file.file.get_path () == "/");
            });

            var spacer = new Gtk.ToolItem ();
            spacer.set_expand (true);

            var add = new Gtk.ToolButton (null, null);
            add.tooltip_text = _("Add file");
            add.icon_name = "list-add-symbolic";
            add.clicked.connect (() => {
                view.add_file ();
            });

            var remove = new Gtk.ToolButton (null, null);
            remove.tooltip_text = _("Remove file");
            remove.icon_name = "edit-delete-symbolic";
            remove.clicked.connect (() => {
                view.remove_file ();
            });

            toolbar.insert (parent, -1);
            toolbar.insert (spacer, -1);
            toolbar.insert (add, -1);
            toolbar.insert (remove, -1);

            box.pack_start (view, true, true, 0);
            box.pack_start (toolbar, false, false, 0);
            box.show_all ();

            notebook.append_page (box, new Gtk.Label (_("File Manager")));
        }
    }
}

[ModuleInit]
public void peas_register_types (GLib.TypeModule module) {
  var objmodule = module as Peas.ObjectModule;
  objmodule.register_extension_type (typeof (Peas.Activatable), typeof (Scratch.Plugins.FileManagerPlugin));
}
