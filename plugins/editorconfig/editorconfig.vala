/*
* Copyright (c) 2018 elementary LLC. (https://github.com/elementary)
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

public class Scratch.Plugins.EditorConfigPlugin: Peas.ExtensionBase, Scratch.Services.ActivatablePlugin {
    Scratch.Services.Interface plugins;
    public Object object { owned get; set construct; }
    private Code.FormatBar format_bar;

    public void update_state () { }

    public void activate () {
        plugins = (Scratch.Services.Interface) object;

        plugins.hook_toolbar.connect ((tb) => {
            format_bar = tb.format_bar;
        });

        plugins.hook_document.connect ((d) => {
            update_config.begin (d);
        });

    }

    private async void update_config (Scratch.Services.Document d) {
        // Ensure use global settings by default
        format_bar.tab_style_set_by_editor_config = false;
        format_bar.tab_width_set_by_editor_config = false;
        format_bar.set_document (d);

        Scratch.Widgets.SourceView view = d.source_view;
        File file = d.file;

        if (file == null || !file.query_exists ()) {
            return;
        }

        var handle = new EditorConfig.Handle ();
        handle.set_conf_file_name (".editorconfig");
        if (handle.parse (file.get_path ()) != 0) {
            return;
        }

        for (int i = 0; i < handle.get_name_value_count (); i++) {
            string name, val;
            handle.get_name_value (i, out name, out val);
            /* These are all properties (https://github.com/editorconfig/editorconfig/wiki/EditorConfig-Properties) */
            switch (name) {
                case "indent_style":
                    format_bar.tab_style_set_by_editor_config = true;
                    var use_spaces = (val != "tab");
                    format_bar.set_insert_spaces_instead_of_tabs (use_spaces);
                    break;
                case "indent_size":
                case "tab_width":
                    format_bar.tab_width_set_by_editor_config = true;
                    var indent_width = (int.parse (val)).clamp (2, 16);
                    format_bar.set_tab_width (indent_width);
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
                default:
                    warning ("unrecognised name/value %s/%s", name, val);
                    break;
            }
        }
    }

    public void deactivate () { debug ("Editor config deactivate");}
}

[ModuleInit]
public void peas_register_types (GLib.TypeModule module) {
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type (typeof (Scratch.Services.ActivatablePlugin), typeof (Scratch.Plugins.EditorConfigPlugin));
}
