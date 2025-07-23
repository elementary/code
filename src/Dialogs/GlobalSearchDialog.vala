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

    public string search_term {
        get {
            return search_term_entry.text;
        }

        set {
            search_term_entry.text = value;
        }
    }

    public bool case_sensitive { get; construct; }
    public bool wholeword { get; construct; }
    public bool use_regex { get; construct; }

    public GlobalSearchDialog (string folder_name, bool is_repo, bool case_sensitive, bool wholeword, bool use_regex) {
        Object (
            folder_name: folder_name,
            is_repo: is_repo,
            case_sensitive: case_sensitive,
            wholeword: wholeword,
            use_regex: use_regex
        );
    }

    construct {
        transient_for = ((Gtk.Application) GLib.Application.get_default ()).active_window;
        image_icon = new ThemedIcon ("edit-find");

        search_term_entry = new Granite.ValidatedEntry () {
            margin_bottom = 12,
            width_chars = 30 //Most searches are less than this, can expand window if required
        };

        string case_text = "", wholeword_text = "", regex_text = "";
        if (use_regex) {
            regex_text = _("The search term will be treated as a regex expression");
        } else {
            case_text = case_sensitive ? _("Search will be case sensitive") : _("Search will be case insensitive");
            wholeword_text = wholeword ? _("Search will match only whole words") : "";
        }

        primary_text = _("Search for text in “%s”").printf (folder_name);
        secondary_text = _("The search term must be at least 3 characters long.");

        var box = new Gtk.Box (VERTICAL, 0);
        if (!use_regex) {
            box.add (new Gtk.Label (case_text) { halign = START });
            if (wholeword_text != "") {
                box.add (new Gtk.Label (wholeword_text) { halign = START });
            }
        } else {
            box.add (new Gtk.Label (regex_text) { halign = START });
        }

        box.add (search_term_entry);

        custom_bin.add (box);
        custom_bin.show_all ();

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
            if (use_regex) {
                try {
                    var search_regex = new Regex (search_term_entry.text, 0);
                } catch {
                    search_term_entry.is_valid = false;
                }
            }
        });
    }
 }
