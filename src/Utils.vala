// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/***
  BEGIN LICENSE

  Copyright (C) 2013 Mario Guerriero <mario@elementaryos.org>
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

namespace Scratch.Utils {
    public const string UI_PATH = Constants.DATADIR + "/scratch-ui.xml";
    public string? last_path = null;
    
    // Create a GtkFileChooserDialog to perform the action desired
    public Gtk.FileChooserDialog new_file_chooser_dialog (Gtk.FileChooserAction action, string title, bool select_multiple = false) {
        var filech = new Gtk.FileChooserDialog (title, null, action);
        filech.set_select_multiple (select_multiple);
        filech.add_button (Gtk.Stock.CANCEL, Gtk.ResponseType.CANCEL);
        if (action == Gtk.FileChooserAction.OPEN)
            filech.add_button (Gtk.Stock.OPEN, Gtk.ResponseType.ACCEPT);
        else
            filech.add_button (Gtk.Stock.SAVE, Gtk.ResponseType.ACCEPT);
        filech.set_default_response (Gtk.ResponseType.ACCEPT);
        filech.set_current_folder_uri (Utils.last_path ?? GLib.Environment.get_home_dir ());
        filech.key_press_event.connect ((ev) => {
            if (ev.keyval == 65307) // Esc key
                filech.destroy ();
            return false;
        });
        var all_files_filter = new Gtk.FileFilter ();
        all_files_filter.set_filter_name (_("All files"));
        all_files_filter.add_pattern ("*");
        var text_files_filter = new Gtk.FileFilter ();
        text_files_filter.set_filter_name (_("Text files"));
        text_files_filter.add_mime_type ("text/*");
        filech.add_filter (all_files_filter);
        filech.add_filter (text_files_filter);
        filech.set_filter (text_files_filter);
        return filech;
    }
}
