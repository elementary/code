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

    private Gtk.FileChooserNative new_file_chooser_dialog (Gtk.FileChooserAction action, string title, Gtk.Window? parent, bool select_multiple = false) {
        var all_files_filter = new Gtk.FileFilter ();
        all_files_filter.set_filter_name (_("All files"));
        all_files_filter.add_pattern ("*");

        var text_files_filter = new Gtk.FileFilter ();
        text_files_filter.set_filter_name (_("Text files"));
        text_files_filter.add_mime_type ("text/*");

        Gtk.FileChooserNative file_chooser;

        if (action == Gtk.FileChooserAction.OPEN) {
            file_chooser = new Gtk.FileChooserNative (
                title,
                parent,
                Gtk.FileChooserAction.OPEN,
                _("Open"),
                _("Cancel")
            );
            file_chooser.filter = text_files_filter;
        } else {
            file_chooser = new Gtk.FileChooserNative (
                title,
                parent,
                action,
                _("Save"),
                _("Cancel")
            );
        }

        file_chooser.add_filter (all_files_filter);
        file_chooser.add_filter (text_files_filter);
        file_chooser.set_current_folder_uri (Utils.last_path ?? GLib.Environment.get_home_dir ());
        file_chooser.select_multiple = select_multiple;

        return file_chooser;
    }

    public SimpleAction action_from_group (string action_name, SimpleActionGroup action_group) {
        return ((SimpleAction) action_group.lookup_action (action_name));
    }
}
