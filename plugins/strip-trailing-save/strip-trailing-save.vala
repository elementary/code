/*
 * Copyright (C) 2011-2012 Mario Guerriero <mefrio.g@gmail.com> This program
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

public class Scratch.Plugins.StripTrailSave: Peas.ExtensionBase, Peas.Activatable {

    Scratch.Services.Interface plugins;
    public Object object {owned get; construct;}
    Scratch.MainWindow main_window;
    Gtk.Action action_save;
    public void update_state () {return;}

    /*
     * Activate plugin.
     */
    public void activate () {
        plugins = (Scratch.Services.Interface) object;   
        plugins.hook_window.connect ((w) => {
            this.main_window = w;
            main_actions.pre_activate.connect (on_save);
            action_save = main_actions.get_action ("SaveFile");
        });
    }

    /*
     * Deactivate plugin.
     */
    public void deactivate () {
        main_actions.pre_activate.disconnect(on_save);
    }

    /*
     * Strip trailing spaces in document.
     */
    void on_save (Gtk.Action action) {
        if (action==action_save) {
            var text_view = main_window.get_current_document ().source_view;
            var buffer = text_view.buffer;
            buffer.begin_user_action();
            strip_trailing_spaces(buffer);
            buffer.end_user_action();
        }
    }

    /*
     * Pull the buffer into an array and then work out which parts are to
     * be deleted.
     * NOTE: there are other implementations of this method that use regular
     * expressions.
     */
    void strip_trailing_spaces(Gtk.SourceBuffer buffer)
    {
        char* ini, end, ptr;
        int line_idx=0, whitespace=0, counter=0;
        TextIter ini_iter, end_iter;

        buffer.get_start_iter(out ini_iter);
        buffer.get_end_iter(out end_iter);
        var text = buffer.get_text(ini_iter, end_iter, true);
        line_idx = buffer.get_line_count();
        ini = text.data;
        ptr = end = ini+text.length;

        while (ini<=ptr) {
            if (*ptr=='\n' || ptr==end) {
                line_idx--;
                whitespace = counter = 0;
                for (ptr--; ((*ptr).isspace() && (*ptr)!='\n') && ini<=ptr;
                     ptr--)
                {
                    whitespace++;
                    counter++;
                }
                for (; (*ptr)!='\n' && ini<=ptr; ptr--) {
                    counter++;
                }
                if (whitespace==0) {
                    continue;
                }
                ini_iter.set_line(line_idx);
                end_iter.set_line(line_idx);
                ini_iter.set_line_offset(counter-whitespace);
                end_iter.set_line_offset(counter);
                buffer.delete(ref ini_iter, ref end_iter);
            }
            else {
                ptr--;
            }
        }
    }
}

[ModuleInit]
public void peas_register_types (GLib.TypeModule module) {
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type(typeof(Peas.Activatable),
                                      typeof(Scratch.Plugins.StripTrailSave));
}
