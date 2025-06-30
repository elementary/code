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

public class Scratch.Dialogs.GlobalSearchDialog : Granite.MessageDialog {
    public string folder_name { get; construct; }
    public bool is_repo { get; construct; }
    private Granite.ValidatedEntry search_term_entry;
    private Gtk.Switch regex_switch;

    public string search_term {
        get {
            return search_term_entry.text;
        }

        set {
            search_term_entry.text = value;
        }
    }

    public bool use_regex {
        get {
            return regex_switch.active;
        }

        set {
            regex_switch.active = value;
        }
    }

    public bool case_sensitive { get; construct; }

    public GlobalSearchDialog (string folder_name, bool is_repo, bool case_sensitive) {
        Object (
            folder_name: folder_name,
            is_repo: is_repo,
            case_sensitive: case_sensitive
        );
    }

    construct {
        transient_for = ((Gtk.Application) GLib.Application.get_default ()).active_window;
        image_icon = new ThemedIcon ("edit-find");

        search_term_entry = new Granite.ValidatedEntry () {
            margin_bottom = 12,
            width_chars = 30 //Most searches are less than this, can expand window if required
        };

        var case_text = case_sensitive ? _("Search will be case sensitive") : _("Search will case insensitive");

        primary_text = _("Search for text in “%s”").printf (folder_name);
        secondary_text = "%s\n\n%s".printf (
            _("The search term must be at least 3 characters long."),
            case_text
        );


        regex_switch = new Gtk.Switch () {
            active = false,
            halign = Gtk.Align.START
        };

        var regex_label = new Gtk.Label (_("Use regular expressions:")) {
            halign = Gtk.Align.END
        };

        var layout = new Gtk.Grid () {
            column_spacing = 12,
            row_spacing = 6
        };
        layout.attach (search_term_entry, 0, 0, 2);
        layout.attach (regex_label, 0, 1);
        layout.attach (regex_switch, 1, 1);
        layout.show_all ();

        custom_bin.add (layout);

        add_button (_("Cancel"), Gtk.ResponseType.CANCEL);

        var search_button = (Gtk.Button) add_button (_("Search"), Gtk.ResponseType.ACCEPT);
        search_button.can_default = true;
        search_button.has_default = true;
        search_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);

        search_term_entry.bind_property (
            "is-valid", search_button, "sensitive", BindingFlags.DEFAULT | BindingFlags.SYNC_CREATE
        );

        search_term_entry.changed.connect (() => {
            search_term_entry.is_valid = search_term_entry.text.length >= 3;
        });
    }
 }
