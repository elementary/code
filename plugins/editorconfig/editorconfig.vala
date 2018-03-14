

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
                        view.indent_width = val.to_int ();
                        break;
                    case "tab_width":
                        view.tab_width = val.to_int ();
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
                        view.right_margin_position = val.to_int ();
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
