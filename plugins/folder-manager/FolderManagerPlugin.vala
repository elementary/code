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

public const string NAME = _("Folder Manager");
public const string DESCRIPTION = _("Basic folder manager with file browsing");

namespace Scratch.Plugins {
    public class FolderManagerPlugin : Peas.ExtensionBase, Peas.Activatable {

        FolderManager.FileView view;
        Gtk.ToolButton tool_button;

        int index = 0;

        Scratch.Services.Interface plugins;
        public Object object { owned get; construct; }

        public FolderManagerPlugin () {
            message ("Starting Folder Manager Plugin");
        }

        public void activate () {
            plugins = (Scratch.Services.Interface) object;
            plugins.hook_notebook_sidebar.connect (on_hook_sidebar);
            plugins.hook_toolbar.connect (on_hook_toolbar);
        }

        public void deactivate () {
            if (view != null) {
                view.destroy();
                view = null;
            }

            if (tool_button != null) {
                tool_button.destroy();
                tool_button = null;
            }
        }

        public void update_state () {
        }

        void on_hook_sidebar (Gtk.Notebook notebook) {
            if (view != null)
                return;

            view = new FolderManager.FileView ();

            view.select.connect ((file) => plugins.open_file (file));

            view.root.child_added.connect (() => {
                if (view.get_n_visible_children (view.root) == 0) {
                    index = notebook.append_page (view, new Gtk.Label (_("Folders")));
                }
            });

            view.root.child_removed.connect (() => {
                if (view.get_n_visible_children (view.root) == 1)
                    notebook.remove_page (index);
            });

            view.restore_settings ();
        }

        void on_hook_toolbar (Gtk.HeaderBar toolbar) {
            if (tool_button != null)
                return;

            var icon = new Gtk.Image.from_icon_name ("folder-saved-search", Gtk.IconSize.LARGE_TOOLBAR);
            tool_button = new Gtk.ToolButton (icon, _("Open a folder"));
            tool_button.tooltip_text = _("Open a folder");
            tool_button.clicked.connect (open_dialog);
            tool_button.show_all ();
            toolbar.pack_start (tool_button);
        }
        
        private void open_dialog () {
            Gtk.Window window = plugins.manager.window;
            Gtk.FileChooserDialog chooser = new Gtk.FileChooserDialog (
                _("Select a folder"), window, Gtk.FileChooserAction.SELECT_FOLDER,
                _("_Cancel"), Gtk.ResponseType.CANCEL,
                _("_Open"), Gtk.ResponseType.ACCEPT);
            chooser.select_multiple = true;

            if (chooser.run () == Gtk.ResponseType.ACCEPT) {
                chooser.get_files ().foreach ((file) => {
                    view.open_folder (file.get_path ());
                });
            }

            chooser.close ();
        }
    }
}

[ModuleInit]
public void peas_register_types (GLib.TypeModule module) {
  var objmodule = module as Peas.ObjectModule;
  objmodule.register_extension_type (typeof (Peas.Activatable), typeof (Scratch.Plugins.FolderManagerPlugin));
}
