/*
 * SPDX-License-Identifier: LGPL-3.0-or-later
 * SPDX-FileCopyrightText: 2022 elementary, Inc. (https://elementary.io)
 *                         2011-2013 Mario Guerriero <mario@elementaryos.org>
 */

public class Code.Terminal : Gtk.Box {
    private const double MAX_SCALE = 5.0;
    private const double MIN_SCALE = 0.2;
    private const string LEGACY_SETTINGS_SCHEMA = "org.pantheon.terminal.settings";
    private const string SETTINGS_SCHEMA = "io.elementary.terminal.settings";

    private GLib.Pid child_pid;
    public Vte.Terminal terminal { get; construct; }

    construct {
        terminal = new Vte.Terminal () {
            hexpand = true,
            vexpand = true,
            scrollback_lines = -1
        };

        // Set font, allow-bold, audible-bell, background, foreground, and palette of pantheon-terminal
        var schema_source = SettingsSchemaSource.get_default ();
        var terminal_schema = schema_source.lookup (SETTINGS_SCHEMA, true);
        if (terminal_schema != null) {
            update_terminal_settings (SETTINGS_SCHEMA);
        } else {
            var legacy_terminal_schema = schema_source.lookup (LEGACY_SETTINGS_SCHEMA, true);
            if (legacy_terminal_schema != null) {
                update_terminal_settings (LEGACY_SETTINGS_SCHEMA);
            }
        }

        terminal.child_exited.connect (() => {
            GLib.Application.get_default ().activate_action (Scratch.MainWindow.ACTION_PREFIX + Scratch.MainWindow.ACTION_TOGGLE_TERMINAL, null);
        });

        var copy = new Gtk.MenuItem.with_label (_("Copy"));
        copy.activate.connect (() => {
            terminal.copy_clipboard ();
        });

        var paste = new Gtk.MenuItem.with_label (_("Paste"));
        paste.activate.connect (() => {
            terminal.paste_clipboard ();
        });

        var menu = new Gtk.Menu ();
        menu.append (copy);
        menu.append (paste);
        menu.show_all ();

        terminal.button_press_event.connect ((event) => {
            if (event.button == 3) {
                menu.select_first (false);
                menu.popup_at_pointer (event);
            }
            return false;
        });

        var settings = new Settings (Constants.PROJECT_NAME + ".saved-state");
        try {
            var last_path_setting = settings.get_string ("last-opened-path");
            //FIXME Replace with the async method once the .vapi is fixed upstream.
            terminal.spawn_sync (
                Vte.PtyFlags.DEFAULT,
                last_path_setting == "" ? "~/" : last_path_setting,
                { Vte.get_user_shell () },
                null,
                GLib.SpawnFlags.SEARCH_PATH,
                null,
                out child_pid
            );
        } catch (GLib.Error e) {
            warning (e.message);
        }

        var scrolled_window = new Gtk.ScrolledWindow (null, terminal.get_vadjustment ());
        scrolled_window.add (terminal);

        add (scrolled_window);

        destroy.connect (() => {
            settings.set_string ("last-opened-path", get_shell_location ());
        });

        show_all ();
    }

    private string get_shell_location () {
        int pid = (!) (this.child_pid);
        try {
            return GLib.FileUtils.read_link ("/proc/%d/cwd".printf (pid));
        } catch (GLib.FileError error) {
            warning ("An error occurred while fetching the current dir of shell: %s", error.message);
            return "";
        }
    }

    private void update_terminal_settings (string settings_schema) {
        var pantheon_terminal_settings = new GLib.Settings (settings_schema);

        var font_name = pantheon_terminal_settings.get_string ("font");
        if (font_name == "") {
            var system_settings = new GLib.Settings ("org.gnome.desktop.interface");
            font_name = system_settings.get_string ("monospace-font-name");
        }

        var fd = Pango.FontDescription.from_string (font_name);
        terminal.set_font (fd);

        bool audible_bell_setting = pantheon_terminal_settings.get_boolean ("audible-bell");
        this.terminal.set_audible_bell (audible_bell_setting);

        string cursor_shape_setting = pantheon_terminal_settings.get_string ("cursor-shape");

        switch (cursor_shape_setting) {
            case "Block":
                this.terminal.cursor_shape = Vte.CursorShape.BLOCK;
                break;
            case "I-Beam":
                this.terminal.cursor_shape = Vte.CursorShape.IBEAM;
                break;
            case "Underline":
                this.terminal.cursor_shape = Vte.CursorShape.UNDERLINE;
                break;
        }

        string background_setting = pantheon_terminal_settings.get_string ("background");
        Gdk.RGBA background_color = Gdk.RGBA ();
        background_color.parse (background_setting);

        string foreground_setting = pantheon_terminal_settings.get_string ("foreground");
        Gdk.RGBA foreground_color = Gdk.RGBA ();
        foreground_color.parse (foreground_setting);

        string palette_setting = pantheon_terminal_settings.get_string ("palette");

        string[] hex_palette = {"#000000", "#FF6C60", "#A8FF60", "#FFFFCC", "#96CBFE",
                                "#FF73FE", "#C6C5FE", "#EEEEEE", "#000000", "#FF6C60",
                                "#A8FF60", "#FFFFB6", "#96CBFE", "#FF73FE", "#C6C5FE",
                                "#EEEEEE"};

        string current_string = "";
        int current_color = 0;
        for (var i = 0; i < palette_setting.length; i++) {
            if (palette_setting[i] == ':') {
                hex_palette[current_color] = current_string;
                current_string = "";
                current_color++;
            } else {
                current_string += palette_setting[i].to_string ();
            }
        }

        Gdk.RGBA[] palette = new Gdk.RGBA[16];

        for (int i = 0; i < hex_palette.length; i++) {
            Gdk.RGBA new_color = Gdk.RGBA ();
            new_color.parse (hex_palette[i]);
            palette[i] = new_color;
        }

        this.terminal.set_colors (foreground_color, background_color, palette);
    }

    public void increment_size () {
        terminal.font_scale = (terminal.font_scale + 0.1).clamp (MIN_SCALE, MAX_SCALE);
    }

    public void decrement_size () {
        terminal.font_scale = (terminal.font_scale - 0.1).clamp (MIN_SCALE, MAX_SCALE);
    }

    public void set_default_font_size () {
        terminal.font_scale = 1.0;
    }
}
