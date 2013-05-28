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

namespace Scratch.Plugins {

    public class ProjectManagerPlugin : Peas.ExtensionBase, Peas.Activatable {

        ProjectManager.FileView view;
        Gtk.ToolButton tool_button;
        
        Scratch.Services.Interface plugins;
        public Object object { owned get; construct; }

        public ProjectManagerPlugin () {
        }

        public void activate () {
            plugins = (Scratch.Services.Interface) object;
            plugins.hook_notebook_sidebar.connect (on_hook_sidebar);
            plugins.hook_toolbar.connect (on_hook_toolbar);
        }

        public void deactivate () {
            if (view != null)
                view.destroy();
            if (tool_button != null) {
                //(tool_button.parent as Scratch.Widgets.Toolbar).open_button.visible = true;
                tool_button.destroy ();
            }
        }

        public void update_state () {
        }

        void on_hook_sidebar (Gtk.Notebook notebook) {
            if (view != null)
                return;
            view = new ProjectManager.FileView ();
            view.select.connect ((a) => {
                var file = GLib.File.new_for_path (a);
                plugins.open_file (file);
            });

            notebook.append_page (view, new Gtk.Label (_("Projects")));

            view.show_all ();
        }

        void on_hook_toolbar (Gtk.Toolbar toolbar) {
            if (tool_button != null)
                return;
            
            //(toolbar as Scratch.Widgets.Toolbar).open_button.visible = false;
            var icon = new Gtk.Image.from_icon_name ("folder-saved-search", Gtk.IconSize.LARGE_TOOLBAR);
            tool_button = new Gtk.ToolButton (icon, _("Open a folder"));
            tool_button.tooltip_text = _("Open a folder");
            tool_button.clicked.connect (() => {
                Gtk.FileChooserDialog chooser = new Gtk.FileChooserDialog (
                    "Select a folder.", null, Gtk.FileChooserAction.SELECT_FOLDER,
                    Gtk.Stock.CANCEL, Gtk.ResponseType.CANCEL,
                    Gtk.Stock.OPEN, Gtk.ResponseType.ACCEPT);
                chooser.select_multiple = true;

                if (chooser.run () == Gtk.ResponseType.ACCEPT) {
                    SList<string> uris = chooser.get_uris ();
                    foreach (unowned string uri in uris) {
                        var project = new ProjectManager.File (uri.replace ("file:///", "/"));
                        view.open_project (project); // emit signal
                    }
                }

                chooser.close ();
            });

            icon.show ();
            tool_button.show ();

            toolbar.insert (tool_button, 1);
        }
    }
}

[ModuleInit]
public void peas_register_types (GLib.TypeModule module) {
  var objmodule = module as Peas.ObjectModule;
  objmodule.register_extension_type (typeof (Peas.Activatable), typeof (Scratch.Plugins.ProjectManagerPlugin));
}
