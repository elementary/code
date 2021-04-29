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
    private Gtk.Switch case_switch;
    private Gtk.Switch regex_switch;

    public string search_term { get {return search_term_entry.text;} }
    public bool use_regex {
        get {
            return regex_switch.active;
        }

        set {
            regex_switch.active = value;
        }
    }

    public bool case_sensitive {
        get {
            return case_switch.active;
        }

        set {
            case_switch.active = value;
        }
    }

    public GlobalSearchDialog (Gtk.Window? parent, string folder_name, bool is_repo) {
        Object (
            transient_for: parent,
            folder_name: folder_name,
            is_repo: is_repo,
            image_icon: new ThemedIcon ("system-search")
        );
    }

    construct {
        primary_text = _("Search for text in folder '%s'").printf (folder_name);
        secondary_text = _("The search term must be at least 3 characters long");

        search_term_entry = new Granite.ValidatedEntry () {
            width_chars = 30 //Most searches are less than this, can expand window if required
        };

        var search_term_label = new Gtk.Label (_("Search for:")) {
            margin_end = 6,
            halign = Gtk.Align.END
        };

        var search_grid = new Gtk.Grid () {
            margin_bottom = 24,
            margin_top = 12,
            orientation = Gtk.Orientation.HORIZONTAL
        };

        search_grid.add (search_term_label);
        search_grid.add (search_term_entry);

        case_switch = new Gtk.Switch () {
            active = false
        };

        var case_label = new Gtk.Label (_("Case sensitive:")) {
            margin_end = 6,
            halign = Gtk.Align.END
        };

        regex_switch = new Gtk.Switch () {
            hexpand = false,
            active = false
        };

        var regex_label = new Gtk.Label (_("Use regular expressions:")) {
            margin_end = 6,
            halign = Gtk.Align.END
        };

        var switch_grid = new Gtk.Grid ();
        switch_grid.attach (case_label, 0, 0, 1, 1);
        switch_grid.attach (case_switch, 1, 0, 1, 1);
        switch_grid.attach (regex_label, 0, 1, 1, 1);
        switch_grid.attach (regex_switch, 1, 1, 1, 1);

        var layout = new Gtk.Grid ();
        layout.attach (search_grid, 0, 0, 1, 1);
        layout.attach (switch_grid, 0, 1, 1, 1);
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
