/*
 * Copyright (c) 2021 elementary, Inc. (https://elementary.io)
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
 *
 * Authored by: Marius Meisenzahl <mariusmeisenzahl@gmail.com>
 */

public class Scratch.Widgets.NewAppDialog : Granite.Dialog {
    private Gtk.Entry app_name_entry;
    private Gtk.Entry your_name_entry;
    private Gtk.Entry your_email_entry;
    private Gtk.Entry your_github_entry;
    private Gtk.Button create_button;

    public NewAppDialog (Gtk.Window parent) {
        Object (transient_for: parent);
    }

    construct {
        var app_name_label = new Granite.HeaderLabel (_("App Name"));

        app_name_entry = new Gtk.Entry () {
            hexpand = true
        };

        var license_label = new Granite.HeaderLabel (_("License Type"));

        var license_combobox = new Gtk.ComboBoxText ();
        license_combobox.append_text ("GNU General Public License v2.0");
        license_combobox.append_text ("GNU General Public License v3.0");
        license_combobox.append_text ("MIT");
        license_combobox.set_active (1);

        var location_label = new Granite.HeaderLabel (_("Location"));

        var location_chooser = new Gtk.FileChooserButton (_("Select the folder where your app should be located"), Gtk.FileChooserAction.SELECT_FOLDER) {
            hexpand = true
        };
        try {
            location_chooser.set_file (File.new_for_path (Environment.get_home_dir ()));
        } catch (Error e) {
            warning ("The folder path is invalid: %s", e.message);
        }

        var your_name_label = new Granite.HeaderLabel (_("Your Name"));

        your_name_entry = new Gtk.Entry () {
            hexpand = true
        };

        var your_email_label = new Granite.HeaderLabel (_("Your Email"));

        your_email_entry = new Gtk.Entry () {
            hexpand = true
        };

        var your_github_label = new Granite.HeaderLabel (_("Your GitHub Account"));

        your_github_entry = new Gtk.Entry () {
            hexpand = true
        };

        var form_grid = new Gtk.Grid ();
        form_grid.margin_start = form_grid.margin_end = 12;
        form_grid.orientation = Gtk.Orientation.VERTICAL;
        form_grid.row_spacing = 3;
        form_grid.valign = Gtk.Align.CENTER;
        form_grid.vexpand = true;
        form_grid.add (app_name_label);
        form_grid.add (app_name_entry);
        form_grid.add (license_label);
        form_grid.add (license_combobox);
        form_grid.add (location_label);
        form_grid.add (location_chooser);
        form_grid.add (your_name_label);
        form_grid.add (your_name_entry);
        form_grid.add (your_email_label);
        form_grid.add (your_email_entry);
        form_grid.add (your_github_label);
        form_grid.add (your_github_entry);
        form_grid.show_all ();

        deletable = false;
        modal = true;
        resizable= false;
        width_request = 560;
        window_position = Gtk.WindowPosition.CENTER_ON_PARENT;
        get_content_area ().add (form_grid);

        var cancel_button = add_button (_("Cancel"), Gtk.ResponseType.CANCEL);
        cancel_button.margin_bottom = 6;
        cancel_button.margin_top = 14;

        create_button = (Gtk.Button) add_button (_("Create App"), Gtk.ResponseType.OK);
        create_button.margin = 6;
        create_button.margin_start = 0;
        create_button.margin_top = 14;
        create_button.can_default = true;
        create_button.sensitive = false;
        create_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);

        app_name_entry.changed.connect (() => {
            update_create_button ();
        });

        your_name_entry.changed.connect (() => {
            update_create_button ();
        });

        your_email_entry.changed.connect (() => {
            update_create_button ();
        });

        your_github_entry.changed.connect (() => {
            update_create_button ();
        });

        response.connect ((response_id) => {
            destroy ();
        });
    }

    private void update_create_button () {
        if (app_name_entry.text.length > 0 &&
            your_name_entry.text.length > 0 &&
            your_email_entry.text.length > 0 &&
            your_github_entry.text.length > 0) {
            create_button.sensitive = true;
            create_button.has_default = true;
        } else {
            create_button.sensitive = false;
        }
    }
}
