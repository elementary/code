/*
* Copyright 2021 elementary, Inc. (https://elementary.io)
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
    public bool is_repo { get; construct; }
    private Gtk.Entry search_term_entry;
    private Gtk.Switch case_switch;
    private Gtk.Switch regex_switch;

    public string search_term { get {return search_term_entry.text;} }
    public bool use_regex {
        get {
            return regex_switch.active;
        }
    }

    public bool case_sensitive {
        get {
            return case_switch.active;
        }
    }

    public GlobalSearchDialog (Gtk.Window? parent, string folder_name, bool is_repo) {
        Object (
            transient_for: parent,
            folder_name: folder_name,
            is_repo: is_repo
        );
    }

    construct {
        var header = new Gtk.Label (_("Search text in folder '%s'").printf (folder_name)) {
            margin_bottom = 12
        };
        header.get_style_context ().add_class (Granite.STYLE_CLASS_PRIMARY_LABEL);

        search_term_entry = new Gtk.Entry () {
            hexpand = true,
            width_chars = 30 //Most searches are less than this, can expand window if required
        };
        var search_term_label = new Gtk.Label (_("Search for:")) {
            valign = Gtk.Align.CENTER,
            halign = Gtk.Align.END
        };

        case_switch = new Gtk.Switch () {
            halign = Gtk.Align.START,
            active = true
        };

        var case_label = new Gtk.Label (_("Case sensitive:")) {
            halign = Gtk.Align.END
        };

        regex_switch = new Gtk.Switch () {
            halign = Gtk.Align.START,
            active = false
        };

        var regex_label = new Gtk.Label (_("Use regular expressions:")) {
            halign = Gtk.Align.END
        };

        var layout = new Gtk.Grid () {
            column_spacing = 12,
            row_spacing = 6,
            margin = 12,
            margin_top = 0,
            vexpand = true
        };
        layout.attach (header, 0, 0, 4);
        layout.attach (search_term_label, 0, 1);
        layout.attach (search_term_entry, 1, 1, 2);
        layout.attach (case_label, 0, 2);
        layout.attach (case_switch, 1, 2);
        layout.attach (regex_label, 0, 3);
        layout.attach (regex_switch, 1, 3);
        layout.show_all ();

        get_content_area ().add (layout);

        add_button (_("Cancel"), Gtk.ResponseType.CANCEL);

        var search_button = (Gtk.Button) add_button (_("Search"), Gtk.ResponseType.ACCEPT);
        search_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);

        search_term_entry.bind_property ("text", search_button, "sensitive", BindingFlags.DEFAULT,
             (binding, src_val, ref target_val) => {
                target_val.set_boolean (src_val.get_string ().length >= 3);
            }
        );

        search_term_entry.activate.connect (() => {
            response (search_term_entry.text != "" ? Gtk.ResponseType.ACCEPT : Gtk.ResponseType.CLOSE);
        });

        set_default_response (Gtk.ResponseType.CLOSE);
    }
 }
