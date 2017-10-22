/*-
 * Copyright (c) 2017 elementary LLC. (https://elementary.io),
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

public const string NAME = _("Folder Manager");
public const string DESCRIPTION = _("Basic folder manager with file browsing");

namespace Scratch.Plugins {
    public class FolderManagerPlugin : Peas.ExtensionBase, Peas.Activatable {
        Gtk.ToolButton folder_open_button;
        FolderManager.FileView view;

        Scratch.Services.Interface plugins;
        public Object object { owned get; construct; }

        public FolderManagerPlugin () {
            message ("Starting Folder Manager Plugin");
        }

        public void activate () {
            plugins = (Scratch.Services.Interface) object;
            plugins.hook_window.connect (on_hook_window);
            plugins.hook_toolbar.connect (on_hook_toolbar);
        }

        public void deactivate () {
            if (view != null) {
                view.destroy();
            }

            if (folder_open_button != null) {
                folder_open_button.destroy();
                folder_open_button = null;
            }

            plugins.hook_toolbar.disconnect (on_hook_toolbar);
        }
        
        public void update_state () { }

        void on_hook_window (Scratch.MainWindow window) {
            if (view != null) {
                return;
            }

            view = new FolderManager.FileView ();

            view.select.connect ((a) => {
                var file = GLib.File.new_for_path (a);
                plugins.open_file (file);
            });

            view.root.child_added.connect (() => {
                if (view.get_n_visible_children (view.root) == 0) {
                    window.project_pane.add_tab (view);
                    view.show_all ();
                }
            });

            view.root.child_removed.connect (() => {
                if (view.get_n_visible_children (view.root) == 1) {
                    view.parent.remove (view);
                }
            });

            view.restore_saved_state ();
        }

        private void on_hook_toolbar (Gtk.HeaderBar toolbar) {
            if (folder_open_button != null) {
                return;
            }

            var icon = new Gtk.Image.from_icon_name ("folder-saved-search", Gtk.IconSize.LARGE_TOOLBAR);
            folder_open_button = new Gtk.ToolButton (icon, _("Open a folder"));
            folder_open_button.tooltip_text = _("Open a folder");
            folder_open_button.clicked.connect (open_dialog);
            folder_open_button.show_all ();
            toolbar.pack_start (folder_open_button);
        }


        private void open_dialog () {
            Gtk.Window window = plugins.manager.window;
            Gtk.FileChooserDialog chooser = new Gtk.FileChooserDialog (
                "Select a folder.", window, Gtk.FileChooserAction.SELECT_FOLDER,
                _("_Cancel"), Gtk.ResponseType.CANCEL,
                _("_Open"), Gtk.ResponseType.ACCEPT);
            chooser.select_multiple = true;

            if (chooser.run () == Gtk.ResponseType.ACCEPT) {
                chooser.get_files ().foreach ((glib_file) => {
                    var foldermanager_file = new FolderManager.File (glib_file.get_path ());
                    view.open_folder (foldermanager_file);
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
