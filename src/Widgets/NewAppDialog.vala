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
    public NewAppDialog (Gtk.Window parent) {
        Object (transient_for: parent);
    }

    construct {
        var app_name_label = new Granite.HeaderLabel (_("App Name"));

        var app_name_entry = new Gtk.Entry () {
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

        var create_button = (Gtk.Button) add_button (_("Create App"), Gtk.ResponseType.OK);
        create_button.margin = 6;
        create_button.margin_start = 0;
        create_button.margin_top = 14;
        create_button.can_default = true;
        create_button.sensitive = false;
        create_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);

        response.connect ((response_id) => {
            destroy ();
        });
    }
}
