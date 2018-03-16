/*
* Copyright (c) 2018 pantor (https://github.com/pantor)
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 3 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*/

public class Scratch.Plugins.EditorConfig: Peas.ExtensionBase, Peas.Activatable {
    Scratch.Services.Interface plugins;
    public Object object {owned get; construct;}

    public void update_state () {

    }

    public void activate () {
        plugins = (Scratch.Services.Interface) object;

        plugins.hook_document.connect ((d) => {
            Gtk.SourceView view = d.source_view;
            File file = d.file;

            if (file == null) {
                return;
            }

            EditorConfigCore.Handle handle = new EditorConfigCore.Handle ();
            if (EditorConfigCore.parse (file.get_path (), handle) != 0) {
                return;
            }

            for (int i = 0; i < handle.get_name_value_count (); i++) {
                string name, val;
                handle.get_name_value (i, out name, out val);

                /* These are all properties (https://github.com/editorconfig/editorconfig/wiki/EditorConfig-Properties) */
                switch (name) {
                    case "indent_style":
                        if (val == "space") {
                            view.set_insert_spaces_instead_of_tabs (true);
                        } else if (val == "tab") {
                            view.set_insert_spaces_instead_of_tabs (false);
                        }
                        break;
                    case "indent_size":
                        view.tab_width = int.parse (val);
                        break;
                    case "tab_width":
                        view.tab_width = int.parse (val);
                        break;
                    case "end_of_line":
                        break;
                    case "charset":
                        break;
                    case "trim_trailing_whitespace":
                        break;
                    case "insert_final_newline":
                        break;
                    case "max_line_length":
                        view.right_margin_position = int.parse (val);
                        break;
                }
            }
        });
    }

    public void deactivate () {

    }
}

[ModuleInit]
public void peas_register_types (GLib.TypeModule module) {
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type (typeof(Peas.Activatable),
                                      typeof(Scratch.Plugins.EditorConfig));
}
