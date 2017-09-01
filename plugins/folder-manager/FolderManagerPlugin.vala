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
        FolderManager.FileView view;
        Gtk.ToolButton tool_button;

        Scratch.Services.Interface plugins;
        public Object object { owned get; construct; }

        public FolderManagerPlugin () {
            message ("Starting Folder Manager Plugin");
        }

        public void activate () {
            plugins = (Scratch.Services.Interface) object;
            plugins.hook_sidebar.connect (on_hook_sidebar);
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

        void on_hook_sidebar (Gtk.Stack sidebar) {
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
                    sidebar.add_titled (view, "folders", _("Folders"));
                    sidebar.child_set_property (view, "icon-name", "folder-symbolic");
                    sidebar.child_set_property (view, "position", 0);
                    sidebar.show_all ();
                }
            });

            view.root.child_removed.connect (() => {
                if (view.get_n_visible_children (view.root) == 1) {
                    sidebar.remove (view);
                }
            });

            view.restore_saved_state ();
        }

        void on_hook_toolbar (Gtk.HeaderBar toolbar) {
            if (tool_button != null)
                return;

            //(toolbar as Scratch.Widgets.Toolbar).open_button.visible = false;
            var icon = new Gtk.Image.from_icon_name ("folder-saved-search", Gtk.IconSize.LARGE_TOOLBAR);
            tool_button = new Gtk.ToolButton (icon, _("Open a folder"));
            tool_button.tooltip_text = _("Open a folder");
            tool_button.clicked.connect (() => {
                Gtk.Window window = plugins.manager.window;
                Gtk.FileChooserDialog chooser = new Gtk.FileChooserDialog (
                    "Select a folder.", window, Gtk.FileChooserAction.SELECT_FOLDER,
                    _("_Cancel"), Gtk.ResponseType.CANCEL,
                    _("_Open"), Gtk.ResponseType.ACCEPT);
                chooser.select_multiple = true;

                if (chooser.run () == Gtk.ResponseType.ACCEPT) {
                    SList<string> uris = chooser.get_uris ();
                    foreach (unowned string uri in uris) {
                        var folder = new FolderManager.File (uri.replace ("file:///", "/"));
                        view.open_folder (folder); // emit signal
                    }
                }

                chooser.close ();
            });

            icon.show ();
            tool_button.show ();

            toolbar.pack_start (tool_button);
            //toolbar.insert (tool_button, 1);
        }
    }
}

[ModuleInit]
public void peas_register_types (GLib.TypeModule module) {
  var objmodule = module as Peas.ObjectModule;
  objmodule.register_extension_type (typeof (Peas.Activatable), typeof (Scratch.Plugins.FolderManagerPlugin));
}
