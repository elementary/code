/*
 * Copyright (c) {{ current_year }} {{ your_name }} (https://github.com/{{ github_username }})
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
 * Boston, MA 02110-1301 USA
 *
 * Authored by: {{ your_name }} <{{ your_email }}>
 */

 public class MainWindow : Hdy.Window {
    private Hdy.HeaderBar headerbar;

    public MyApp app { get; construct; }

    public MainWindow (MyApp app) {
        Object (
            app: app
        );
    }

    construct {
        Hdy.init ();

        set_application (app);

        headerbar = new Hdy.HeaderBar () {
            decoration_layout = "close:",
            show_close_button = true,
            title = "{{ app_name }}"
        };

        var content = new Gtk.Grid () {
            hexpand = true,
            vexpand = true,
            halign = Gtk.Align.CENTER,
            valign = Gtk.Align.CENTER
        };

        var label = new Gtk.Label (_("Hello Again World!"));
        label.get_style_context ().add_class (Granite.STYLE_CLASS_H1_LABEL);
        content.add (label);

        var main_layout = new Gtk.Grid ();
        main_layout.attach (headerbar, 0, 0);
        main_layout.attach (content, 0, 1);

        var window_handle = new Hdy.WindowHandle ();
        window_handle.add (main_layout);

        add (window_handle);
    }
}
