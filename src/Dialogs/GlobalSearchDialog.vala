// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*
* Copyright (c) 2021 elementary LLC (https://elementary.io)
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 2 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA.
*
* Authored by: Jeremy Wootten <jeremy@elementaryos.org>
*/


public class Scratch.Dialogs.GlobalSearchDialog : Granite.Dialog {
    public string folder_name { get; construct; }
    private Gtk.Entry search_term_entry;
    public string search_term { get {return search_term_entry.text;} }
    public GlobalSearchDialog (Gtk.Window? parent, string folder_name) {
        Object (
            deletable: false,
            resizable: false,
            title: _("Global Search"),
            transient_for: parent,
            folder_name: folder_name
        );
    }

    construct {
        border_width = 0;
        var header = new Gtk.Label (_("Search content in folder '%s'").printf (folder_name)) {
            margin = 6
        };

        header.get_style_context ().add_class (Granite.STYLE_CLASS_H2_LABEL);
        search_term_entry = new Gtk.Entry ();

        var layout = new Gtk.Grid () {
            orientation = Gtk.Orientation.VERTICAL
        };
        layout.add (header);
        layout.add (search_term_entry);
        get_content_area ().add (layout);

        var close_button = (Gtk.Button) add_button (_("Close"), Gtk.ResponseType.CANCEL);
        var search_button = (Gtk.Button) add_button (_("Search"), Gtk.ResponseType.ACCEPT);
        search_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);
        search_term_entry.bind_property ("text", search_button, "sensitive", BindingFlags.DEFAULT,
             (binding, src_val, ref target_val) => {
                target_val.set_boolean (src_val.get_string () != "");
            }
        );

        set_default_response (Gtk.ResponseType.CLOSE);

        show_all ();
    }
 }
