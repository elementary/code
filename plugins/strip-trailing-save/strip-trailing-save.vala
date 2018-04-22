/*
 * Copyright (c) 2011-2012 Mario Guerriero <mefrio.g@gmail.com>
 *               2018 elementary LLC. <https://elementary.io>
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public
 * License as published by the Free Software Foundation; either
 * version 3 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranties of
 * MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
 * PURPOSE.  See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program.  If not, see <http://www.gnu.org/licenses/>
 */

using Gtk;

public class Scratch.Plugins.StripTrailSave: Peas.ExtensionBase, Peas.Activatable {

    Scratch.Services.Interface plugins;
    public Object object {owned get; construct;}
    Scratch.MainWindow main_window;
    public void update_state () {return;}

    /*
     * Activate plugin.
     */
    public void activate () {
        plugins = (Scratch.Services.Interface) object;
        plugins.hook_window.connect ((w) => {
            this.main_window = w;
            var action = w.actions.lookup_action ("action_save") as SimpleAction;
            action.activate.connect (on_save);
        });
    }

    /*
     * Deactivate plugin.
     */
    public void deactivate () {
        var action = this.main_window.actions.lookup_action ("action_save") as SimpleAction;
        action.activate.disconnect (on_save);
    }

    /*
     * Strip trailing spaces in document.
     */
    void on_save () {
        if (main_window.get_current_document () != null) {
            var text_view = main_window.get_current_document ().source_view;
            var source_buffer = (Gtk.SourceBuffer) text_view.buffer;
            source_buffer.begin_user_action();
            strip_trailing_spaces(source_buffer);
            source_buffer.end_user_action();
        }
    }

    /*
     * Pull the buffer into an array and then work out which parts are to
     * be deleted.
     */
    void strip_trailing_spaces (Gtk.SourceBuffer buffer)
    {
        TextIter iter;

        var cursor_pos = buffer.cursor_position;
        buffer.get_iter_at_offset (out iter, cursor_pos);
        var orig_line = iter.get_line ();
        var orig_offset = iter.get_line_offset ();

        var text = buffer.text;

        string[] lines = Regex.split_simple ("""[\r\n]""", text);
        if (lines.length != buffer.get_line_count ()) {
            critical ("Mismatch between line counts when stripping trailing spaces, not continuing");
            return;
        }

        MatchInfo info;
        TextIter start_delete, end_delete;
        for (int line_no = 0; line_no < lines.length; line_no++) {
            try {
                var regex = new Regex ("[ \t]+$", 0);
                if (regex.match (lines[line_no], 0, out info)) {
                    buffer.get_iter_at_line (out start_delete, line_no);
                    start_delete.forward_to_line_end ();
                    end_delete = start_delete;
                    end_delete.backward_chars (info.fetch (0).length);

                    buffer.@delete (ref start_delete, ref end_delete);
                }
            } catch (RegexError e) {
                critical ("Error while replacing trailing whitespace: %s", e.message);
            }
        }

        buffer.get_iter_at_line_offset (out iter, orig_line, orig_offset);
        buffer.place_cursor (iter);
    }
}

[ModuleInit]
public void peas_register_types (GLib.TypeModule module) {
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type(typeof(Peas.Activatable),
                                      typeof(Scratch.Plugins.StripTrailSave));
}
