// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/***
  BEGIN LICENSE

  Copyright (C) 2019-24 elementary, Inc. <https://elementary.io>
                2013 LemonBoy <thatlemon@gmail.com>
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
public class Scratch.Plugins.DetectIndent: Scratch.Plugins.PluginBase {
    const int MAX_LINES = 500;

    Scratch.Plugins.Interface plugins;

    public DetectIndent (PluginInfo info, Interface iface) {
        base (info, iface);
    }

    public override void activate () {
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

    public override void deactivate () {

    }

}

public Scratch.Plugins.PluginBase module_init (
    Scratch.Plugins.PluginInfo info,
    Scratch.Plugins.Interface iface
) {
    return new Scratch.Plugins.DetectIndent (info, iface);
}
