// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*
* Copyright (c) 2013 Mario Guerriero <mefrio.g@gmail.com>
*               2017 elementary LLC. <https://elementary.io>
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

namespace Scratch.Utils {
    public string? last_path = null;

    public Gtk.FileChooserDialog new_file_chooser_dialog (Gtk.FileChooserAction action, string title, Gtk.Window? parent, bool select_multiple = false) {
        var all_files_filter = new Gtk.FileFilter ();
        all_files_filter.set_filter_name (_("All files"));
        all_files_filter.add_pattern ("*");

        var text_files_filter = new Gtk.FileFilter ();
        text_files_filter.set_filter_name (_("Text files"));
        text_files_filter.add_mime_type ("text/*");

        var filech = new Gtk.FileChooserDialog (title, parent, action);
        filech.add_button (_("Cancel"), Gtk.ResponseType.CANCEL);
        filech.add_filter (all_files_filter);
        filech.add_filter (text_files_filter);
        filech.set_current_folder_uri (Utils.last_path ?? GLib.Environment.get_home_dir ());
        filech.set_default_response (Gtk.ResponseType.ACCEPT);
        filech.select_multiple = select_multiple;

        if (action == Gtk.FileChooserAction.OPEN) {
            filech.filter = text_files_filter;
            filech.add_button (_("Open"), Gtk.ResponseType.ACCEPT);
        } else {
            filech.add_button (_("Save"), Gtk.ResponseType.ACCEPT);
        }

        filech.key_press_event.connect ((ev) => {
            if (ev.keyval == 65307) // Esc key
                filech.destroy ();
            return false;
        });

        return filech;
    }

    public SimpleAction action_from_group (string action_name, SimpleActionGroup action_group) {
        return ((SimpleAction) action_group.lookup_action (action_name));
    }

    public void add_accel_to_label (Gtk.Widget widget, Gtk.AccelKey key) {
        Gtk.AccelLabel? label = widget as Gtk.AccelLabel;
        if (label == null) {
            return;
        }

	    label.set_accel (key.accel_key, key.accel_mods);
        label.refetch ();
    }
}
