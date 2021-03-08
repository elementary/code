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
    private Gtk.ComboBoxText filter_combo;
    private Gtk.Switch modified_switch;
    private Gtk.Switch recurse_switch;
    private Granite.Widgets.ModeButton match_mode_button;
    private Granite.Widgets.ModeButton scope_mode_button;
    private int literal_mode_index;
    private int tracked_mode_index;

    public string search_term { get {return search_term_entry.text;} }
    public bool use_literal {
        get { return match_mode_button.selected == literal_mode_index; }
    }

    public bool tracked_only {
        get { return scope_mode_button.selected == tracked_mode_index; }
    }

    public bool modified_only {
        get {
            return modified_switch.active;
        }
    }

    public bool recurse {
        get {
            return recurse_switch.active;
        }
    }

    public string [] path_spec {
        owned get {
            if (filter_combo.active < 0) {
                return ((Gtk.Entry)(filter_combo.get_child ())).text.split (";");
            } else {
                return filter_combo.active_id.split (";");
            }
        }
    }

    public GlobalSearchDialog (Gtk.Window? parent, string folder_name) {
        Object (
            deletable: false,
            resizable: false,
            transient_for: parent,
            folder_name: folder_name
        );
    }

    construct {
        border_width = 0;
        var header = new Gtk.Label (_("Search text in folder '%s'").printf (folder_name)) {
            margin_bottom = 24,
            halign = Gtk.Align.CENTER
        };

        header.get_style_context ().add_class (Granite.STYLE_CLASS_H3_LABEL);
        search_term_entry = new Gtk.Entry () {
            margin = 6
        };
        var search_term_label = new Gtk.Label (_("Search for:")) {
            valign = Gtk.Align.CENTER,
            halign = Gtk.Align.END
        };


        match_mode_button = new Granite.Widgets.ModeButton () {
            margin = 6
        };

        literal_mode_index = match_mode_button.append_text (_("Text"));
        match_mode_button.append_text (_("Regex"));
        match_mode_button.selected = literal_mode_index;

        filter_combo = new Gtk.ComboBoxText.with_entry () {
            margin = 6
        };

        filter_combo.append ( "*.vala; *.vapi", _("Vala Files"));
        filter_combo.append ( "*/meson*.*;meson/*", _("Meson Files"));
        filter_combo.append ( "data/*", _("Data Files"));
        filter_combo.append ("*.c;*.h", _("C Files"));
        filter_combo.append ("*.*", _("All Files"));
        filter_combo.active = 0;

        var filter_label = new Gtk.Label (_("Search in:")) {
            halign = Gtk.Align.END,
            margin_start = 6
        };

        scope_mode_button = new Granite.Widgets.ModeButton () {
            margin = 6
        };

        tracked_mode_index = scope_mode_button.append_text (_("Tracked"));
        scope_mode_button.append_text (_("All"));
        scope_mode_button.selected = tracked_mode_index;

        modified_switch = new Gtk.Switch () {
            margin = 6,
            halign = Gtk.Align.START, //Stop switch expanding
            active = true
        };

        var modified_label = new Gtk.Label (_("Modified only")) {
            halign = Gtk.Align.END,
            margin_start = 6
        };

        recurse_switch = new Gtk.Switch () {
            margin = 6,
            halign = Gtk.Align.START, //Stop switch expanding
            active = true
        };

        var recurse_label = new Gtk.Label (_("Search sub-folders")) {
            halign = Gtk.Align.END,
            margin_start = 6
        };

        var layout = new Gtk.Grid ();
        layout.attach (header, 0, 0, 4, 1);
        layout.attach (search_term_label, 0, 1, 1, 1);
        layout.attach (search_term_entry, 1, 1, 2, 1);
        layout.attach (match_mode_button, 3, 1, 1, 1);
        layout.attach (filter_label, 0, 2, 1, 1 );
        layout.attach (filter_combo, 1, 2, 2, 1);
        layout.attach (scope_mode_button, 3, 2, 1, 1);
        layout.attach (modified_label, 0, 3, 1, 1);
        layout.attach (modified_switch, 1, 3, 1, 1);
        layout.attach (recurse_label, 0, 4, 1, 1);
        layout.attach (recurse_switch, 1, 4, 1, 1);
        get_content_area ().add (layout);

        var close_button = (Gtk.Button) add_button (_("Cancel"), Gtk.ResponseType.CANCEL);
        var search_button = (Gtk.Button) add_button (_("Search"), Gtk.ResponseType.ACCEPT);
        search_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);
        search_term_entry.bind_property ("text", search_button, "sensitive", BindingFlags.DEFAULT,
             (binding, src_val, ref target_val) => {
                target_val.set_boolean (src_val.get_string () != "");
            }
        );

        search_term_entry.activate.connect (() => {
            response (search_term_entry.text != "" ? Gtk.ResponseType.ACCEPT : Gtk.ResponseType.CLOSE);
        });

        set_default_response (Gtk.ResponseType.CLOSE);

        show_all ();
    }
 }
