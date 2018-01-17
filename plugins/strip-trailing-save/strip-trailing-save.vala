/*
 * Copyright (C) 2011-2018 Mario Guerriero <mefrio.g@gmail.com> This program
 * is free software: you can redistribute it and/or modify it under the
 * terms of the GNU Lesser General Public License version 3, as published by
 * the Free Software Foundation.
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

public const string NAME = _("Strip trailing whitespace");
public const string DESCRIPTION = _("Strip trailing whitespace on save");

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
        TextIter start_iter, end_iter, temp_iter;

        var cursor_pos = buffer.cursor_position;
        buffer.get_iter_at_offset (out temp_iter, cursor_pos);
        var orig_line = temp_iter.get_line ();
        var orig_offset = temp_iter.get_line_offset ();

        buffer.get_start_iter (out start_iter);
        buffer.get_end_iter (out end_iter);
        var text = buffer.get_text (start_iter, end_iter, true);

        try {
            var regex = new Regex ("[ \t]+$", RegexCompileFlags.MULTILINE);
            text = regex.replace (text, -1, 0, "");
        } catch (RegexError e) {
            warning ("Error while replacing trailing whitespace: %s", e.message);
        }

        buffer.set_text (text);

        buffer.get_iter_at_line_offset (out temp_iter, orig_line, orig_offset);
        buffer.place_cursor (temp_iter);
    }
}

[ModuleInit]
public void peas_register_types (GLib.TypeModule module) {
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type(typeof(Peas.Activatable),
                                      typeof(Scratch.Plugins.StripTrailSave));
}
