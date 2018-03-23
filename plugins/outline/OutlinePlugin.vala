/*-
 * Copyright (c) 2013-2018 elementary LLC. (https://elementary.io)
 * Copyright (C) 2013 Tom Beckmann <tomjonabc@gmail.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

namespace Code.Plugins {
    public class Outline.Plugin : Peas.ExtensionBase, Peas.Activatable {
        private const string PLUGIN_PANE_NAME = "io.elementary.code.plugins.outline";
        public Object object { owned get; construct; }

        Scratch.Services.Interface scratch_interface;

        construct {
            weak Gtk.IconTheme default_theme = Gtk.IconTheme.get_default ();
            default_theme.add_resource_path ("/io/elementary/code/plugin/outline");
        }

        public void activate () {
            scratch_interface = (Scratch.Services.Interface)object;
            scratch_interface.hook_document.connect (on_hook_document);
        }

        public void deactivate () {
            
        }

        public void update_state () {

        }

        void on_hook_document (Scratch.Services.Document doc) {
            var pane_stack = doc.pane.stack;
            var view = pane_stack.get_child_by_name (PLUGIN_PANE_NAME) as Outline.SidePane;
            if (view == null && doc.file != null) {
                var mime_type = doc.mime_type;
                switch (mime_type) {
                    case "text/x-vala":
                        view = new ValaSidePane (doc);
                        break;
                    case "text/x-csrc":
                    case "text/x-chdr":
                    case "text/x-c++src":
                    case "text/x-c++hdr":
                        view = new CSidePane (doc);
                        break;
                }

                if (view != null) {
                    doc.pane.add_tab (view);
                    pane_stack.child_set_property (view, "name", PLUGIN_PANE_NAME);
                    view.show_all ();
                }
            }
        }
    }
}

[ModuleInit]
public void peas_register_types (GLib.TypeModule module) {
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type (typeof (Peas.Activatable), typeof (Code.Plugins.Outline.Plugin));
}
