public class Scratch.Plugins.DetectIndent: Peas.ExtensionBase, Scratch.Services.ActivatablePlugin {
    const int MAX_LINES = 500;

    Scratch.Services.Interface plugins;
    public Object object {owned get; set construct;}

    public void update_state () {
    }

    public void activate () {
        plugins = (Scratch.Services.Interface) object;

        plugins.hook_document.connect ((d) => {
            var view = d.source_view;

            if (!view.get_editable ()) {
                return;
            }

            var source_buffer = (Gtk.SourceBuffer) view.buffer;
            Gtk.TextIter it;
            source_buffer.get_iter_at_line (out it, 0);

            int tabs_found = 0;
            int spaces_found = 0;
            int lines_processed = 0;

            while (lines_processed < MAX_LINES) {
                // Don't take into account the comment sections nor the lines containing only a
                // carriage return
                if (!it.ends_line () && !source_buffer.iter_has_context_class (it, "comment")) {
                    var line_end = it;
                    line_end.forward_to_line_end ();
                    var text = it.get_text (line_end);

                    bool empty = true;

                    // Avoid lines without any character
                    for (var i = 0; i < text.length && empty; i++) {
                        if (text.valid_char (i) && !text.get_char (i).isspace ()) {
                            empty = false;
                        }
                    }

                    if (!empty) {
                        if (text[0] == '\t') {
                            tabs_found += 1;
                        // Consider only two or more consecutive ' ' as indentation
                        } else if (text.length > 1 && text[0] == ' ' && text[1] == ' ') {
                            spaces_found += 1;
                        }

                        lines_processed += 1;
                    }
                }

                if (!it.forward_line ()) {
                    break;
                }
            }

            float sr = (float)spaces_found / lines_processed;
            float tr = (float)tabs_found / lines_processed;

            // Make sure we have a meaningful amount of data to do the hard decisions.
            if (Math.fabsf (tr - sr) > 0.1f) {
                view.set_insert_spaces_instead_of_tabs (sr > tr);
            }
        });
    }

    public void deactivate () {

    }

}

[ModuleInit]
public void peas_register_types (GLib.TypeModule module) {
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type (
        typeof (Scratch.Services.ActivatablePlugin),
        typeof (Scratch.Plugins.DetectIndent)
    );
}
