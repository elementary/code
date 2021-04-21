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
    private Gtk.ComboBoxText filter_combo;
    private Gtk.Switch modified_switch;
    private Gtk.Switch recurse_switch;
    private Gtk.Switch case_switch;
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

    public bool case_sensitive {
        get {
            return case_switch.active;
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

        match_mode_button = new Granite.Widgets.ModeButton ();
        literal_mode_index = match_mode_button.append_text (_("Text"));

        var literal_widget = (Gtk.Widget)(match_mode_button.get_children ().nth_data (literal_mode_index));
        literal_widget.tooltip_text = _("Treat the search entry as literal text");

        var regex_mode_index = match_mode_button.append_text (_("Regex"));
        var regex_widget = (Gtk.Widget)(match_mode_button.get_children ().nth_data (regex_mode_index));
        regex_widget.tooltip_text = _("Treat the search entry as a Regex expression");

        match_mode_button.selected = literal_mode_index;

        filter_combo = new Gtk.ComboBoxText.with_entry ();
        filter_combo.append ( "*.vala; *.vapi", _("Vala Files"));
        filter_combo.append ( "*/meson*.*;meson/*", _("Meson Files"));
        filter_combo.append ( "data/*", _("Data Files"));
        filter_combo.append ("*.c;*.h", _("C Files"));
        filter_combo.append ("*.*", _("All Text Files"));
        filter_combo.active_id = is_repo ? "*.vala; *.vapi" : "*.*";

        var filter_label = new Gtk.Label (_("Search in:")) {
            halign = Gtk.Align.END
        };

        scope_mode_button = new Granite.Widgets.ModeButton () {
            no_show_all = !is_repo
        };

        tracked_mode_index = scope_mode_button.append_text (_("Tracked"));
        var all_mode_index = scope_mode_button.append_text (_("All"));
        scope_mode_button.selected = tracked_mode_index;

        var tracked_widget = (Gtk.Widget)(scope_mode_button.get_children ().nth_data (tracked_mode_index));
        tracked_widget.tooltip_text = _("Only include files added to the git repository");

        var all_widget = (Gtk.Widget)(scope_mode_button.get_children ().nth_data (all_mode_index));
        all_widget.tooltip_text = _("Include any file in or below the folder '%s'").printf (folder_name);

        modified_switch = new Gtk.Switch () {
            halign = Gtk.Align.START, //Stop switch expanding
            active = false,
            no_show_all = !is_repo
        };

        var modified_label = new Gtk.Label (_("Modified only:")) {
            halign = Gtk.Align.END,
            no_show_all = !is_repo
        };

        recurse_switch = new Gtk.Switch () {
            halign = Gtk.Align.START,
            active = is_repo ? true : false
        };

        var recurse_label = new Gtk.Label (_("Search sub-folders:")) {
            halign = Gtk.Align.END
        };

        case_switch = new Gtk.Switch () {
            halign = Gtk.Align.START,
            active = true
        };

        var case_label = new Gtk.Label (_("Case sensitive:")) {
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
        layout.attach (match_mode_button, 3, 1);
        layout.attach (filter_label, 0, 2);
        layout.attach (filter_combo, 1, 2, 2);
        layout.attach (scope_mode_button, 3, 2);
        layout.attach (modified_label, 0, 3);
        layout.attach (modified_switch, 1, 3);
        layout.attach (recurse_label, 0, 4);
        layout.attach (recurse_switch, 1, 4);
        layout.attach (case_label, 0, 5);
        layout.attach (case_switch, 1, 5);
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
