/*
 * Copyright {{ current_year }} {{ your_name }} (https://github.com/{{ github_username }})
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
 * Authored by: {{ your_name }} <{{ your_email }}>
 */

public class {{ app_namespace }}.MainWindow : Hdy.ApplicationWindow {
    private uint configure_id;

    public MainWindow (Application app) {
        Object (
            application: app
        );
    }

    construct {
        Hdy.init ();

        var headerbar = new Hdy.HeaderBar () {
            show_close_button = true,
            title = "{{ app_name }}",
            hexpand = true
        };

        var main_layout = new Gtk.Grid ();
        main_layout.attach (headerbar, 0, 0);

        var window_handle = new Hdy.WindowHandle ();
        window_handle.add (main_layout);

        add (window_handle);
    }

    public override bool configure_event (Gdk.EventConfigure event) {
        if (configure_id != 0) {
            GLib.Source.remove (configure_id);
        }

        configure_id = Timeout.add (100, () => {
            configure_id = 0;

            if (is_maximized) {
                {{ app_namespace }}.Application.settings.set_boolean ("window-maximized", true);
            } else {
                {{ app_namespace }}.Application.settings.set_boolean ("window-maximized", false);

                Gdk.Rectangle rect;
                get_allocation (out rect);
                {{ app_namespace }}.Application.settings.set ("window-size", "(ii)", rect.width, rect.height);

                int root_x, root_y;
                get_position (out root_x, out root_y);
                {{ app_namespace }}.Application.settings.set ("window-position", "(ii)", root_x, root_y);
            }

            return false;
        });

        return base.configure_event (event);
    }
}
