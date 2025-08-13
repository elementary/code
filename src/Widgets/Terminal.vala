/*
 * SPDX-License-Identifier: LGPL-3.0-or-later
 * SPDX-FileCopyrightText: 2022 elementary, Inc. (https://elementary.io)
 *                         2011-2013 Mario Guerriero <mario@elementaryos.org>
 */

public class Code.Terminal : Gtk.Box {
    public const string ACTION_GROUP = "term";
    public const string ACTION_PREFIX = ACTION_GROUP + ".";
    public const string ACTION_COPY = "action-copy";
    public const string ACTION_PASTE = "action-paste";

    private const double MAX_SCALE = 5.0;
    private const double MIN_SCALE = 0.2;
    private const string LEGACY_SETTINGS_SCHEMA = "org.pantheon.terminal.settings";
    private const string SETTINGS_SCHEMA = "io.elementary.terminal.settings";
    private const string GNOME_DESKTOP_INTERFACE_SCHEMA = "org.gnome.desktop.interface";
    private const string GNOME_DESKTOP_WM_PREFERENCES_SCHEMA = "org.gnome.desktop.wm.preferences";
    private const string TERMINAL_FONT_KEY = "font";
    private const string TERMINAL_BELL_KEY = "audible-bell";
    private const string TERMINAL_CURSOR_KEY = "cursor-shape";
    private const string TERMINAL_FOREGROUND_KEY = "foreground";
    private const string TERMINAL_BACKGROUND_KEY = "background";
    private const string TERMINAL_PALETTE_KEY = "palette";
    private const string GNOME_FONT_KEY = "monospace-font-name";
    private const string GNOME_BELL_KEY = "audible-bell";

    public Vte.Terminal terminal { get; construct; }
    private Gtk.EventControllerKey key_controller;

    private Settings? terminal_settings = null;
    private Settings? gnome_interface_settings = null;
    private Settings? gnome_wm_settings = null;

    public SimpleActionGroup actions { get; construct; }

    private GLib.Pid child_pid;
    private Gtk.Clipboard current_clipboard;

    construct {
        terminal = new Vte.Terminal () {
            hexpand = true,
            vexpand = true,
            scrollback_lines = -1,
            cursor_blink_mode = SYSTEM  // There is no Terminal setting so follow Gnome
        };

        // Set font, allow-bold, audible-bell, background, foreground, and palette of pantheon-terminal
        var schema_source = SettingsSchemaSource.get_default ();
        var terminal_schema = schema_source.lookup (SETTINGS_SCHEMA, true);
        if (terminal_schema == null) {
            terminal_schema = schema_source.lookup (LEGACY_SETTINGS_SCHEMA, true);
        }

        if (terminal_schema != null) {
            terminal_settings = new Settings.full (terminal_schema, null, null);
            terminal_settings.changed.connect ((key) => {
                switch (key) {
                    case TERMINAL_FONT_KEY:
                        update_font ();
                        break;
                    case TERMINAL_BELL_KEY:
                        update_audible_bell ();
                        break;
                    case TERMINAL_CURSOR_KEY:
                        update_cursor ();
                        break;
                    case TERMINAL_FOREGROUND_KEY:
                    case TERMINAL_BACKGROUND_KEY:
                    case TERMINAL_PALETTE_KEY:
                        update_colors ();
                        break;
                    default:
                        //TODO Handle other relevant terminal settings?
                        // "theme"
                        // "prefer-dark-style"
                        break;
                }
            });
        } else {
            var gnome_wm_settings_schema = schema_source.lookup (GNOME_DESKTOP_WM_PREFERENCES_SCHEMA, true);
            if (gnome_wm_settings_schema != null) {
                gnome_wm_settings = new Settings.full (gnome_wm_settings_schema, null, null);
                gnome_wm_settings.changed.connect ((key) => {
                    switch (key) {
                        case GNOME_BELL_KEY:
                            update_audible_bell ();
                            break;
                        default:
                            break;
                    }
                });
            }
            //TODO monitor changes in relevant system settings?
            // "org.gnome.desktop.interface.color-scheme"
        }

        // Always monitor changes in default font as that is what Terminal usually follows
        var gnome_interface_settings_schema = schema_source.lookup (GNOME_DESKTOP_INTERFACE_SCHEMA, true);
        if (gnome_interface_settings_schema != null) {
            gnome_interface_settings = new Settings.full (gnome_interface_settings_schema, null, null);
            gnome_interface_settings.changed.connect ((key) => {
                switch (key) {
                    case GNOME_FONT_KEY:
                        update_font ();
                        break;
                    default:
                        break;
                }
            });
        }

        update_font ();
        update_audible_bell ();
        update_cursor ();
        update_colors ();

        terminal.child_exited.connect (() => {
            //Hide the exited terminal
            var win_group = get_action_group (Scratch.MainWindow.ACTION_GROUP);
            win_group.activate_action (Scratch.MainWindow.ACTION_TOGGLE_TERMINAL, null);
            //Get ready to resume at last saved location
            spawn_shell (Scratch.saved_state.get_string ("last-opened-path"));
            //Clear screen of new shell
            terminal.feed_child ("clear -x\n".data);
        });

        var copy_action = new SimpleAction (ACTION_COPY, null);
        copy_action.set_enabled (false);
        copy_action.activate.connect (() => terminal.copy_clipboard ());

        var paste_action = new SimpleAction (ACTION_PASTE, null);
        paste_action.activate.connect (() => terminal.paste_clipboard ());

        actions = new SimpleActionGroup ();
        actions.add_action (copy_action);
        actions.add_action (paste_action);

        var menu_model = new GLib.Menu ();
        menu_model.append (_("Copy"), ACTION_PREFIX + ACTION_COPY);
        menu_model.append (_("Paste"), ACTION_PREFIX + ACTION_PASTE);

        var menu = new Gtk.Menu.from_model (menu_model);
        menu.insert_action_group (ACTION_GROUP, actions);
        menu.show_all ();

        key_controller = new Gtk.EventControllerKey (terminal) {
            propagation_phase = BUBBLE
        };
        key_controller.key_pressed.connect (key_pressed);

        terminal.button_press_event.connect ((event) => {
            if (event.button == 3) {
                paste_action.set_enabled (current_clipboard.wait_is_text_available ());
                menu.select_first (false);
                menu.popup_at_pointer (event);
            }
            return false;
        });

        realize.connect (() => {
            current_clipboard = terminal.get_clipboard (Gdk.SELECTION_CLIPBOARD);
            copy_action.set_enabled (terminal.get_has_selection ());
        });

        terminal.selection_changed.connect (() => {
            copy_action.set_enabled (terminal.get_has_selection ());
        });

        spawn_shell (Scratch.saved_state.get_string ("last-opened-path"));

        var scrolled_window = new Gtk.ScrolledWindow (null, terminal.get_vadjustment ());
        scrolled_window.add (terminal);

        add (scrolled_window);

        destroy.connect (() => {
            Scratch.saved_state.set_string ("last-opened-path", get_shell_location ());
        });

        show_all ();
    }

    private void spawn_shell (string dir = GLib.Environment.get_current_dir ()) {
        try {
            terminal.spawn_sync (
                Vte.PtyFlags.DEFAULT,
                dir,
                { Vte.get_user_shell () },
                null,
                SpawnFlags.SEARCH_PATH,
                null,
                out this.child_pid,
                null
            );
        } catch (Error e) {
            warning (e.message);
        }
    }

    public void change_location (string dir) {
        Posix.kill (child_pid, Posix.Signal.TERM);
        terminal.reset (true, true);
        spawn_shell (dir);
        Scratch.saved_state.set_string ("last-opened-path", dir);
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

    private void update_font () {
        var font_name = "";
        if (terminal_settings != null) {
            font_name = terminal_settings.get_string (TERMINAL_FONT_KEY);
        }

        if (font_name == "" && gnome_interface_settings != null) {
            font_name = gnome_interface_settings.get_string (GNOME_FONT_KEY);
        }

        var fd = Pango.FontDescription.from_string (font_name);
        terminal.set_font (fd);
    }

    private void update_audible_bell () {
        var audible_bell = false;
        if (terminal_settings != null) {
            audible_bell = terminal_settings.get_boolean (TERMINAL_BELL_KEY);
        } else if (gnome_wm_settings != null) {
            audible_bell = gnome_wm_settings.get_boolean (GNOME_BELL_KEY);
        }

        terminal.set_audible_bell (audible_bell);
    }

    private void update_cursor () {
        if (terminal_settings != null) {
            var cursor_shape_setting = terminal_settings.get_string (TERMINAL_CURSOR_KEY);
            switch (cursor_shape_setting) {
                case "Block":
                    terminal.cursor_shape = Vte.CursorShape.BLOCK;
                    break;
                case "I-Beam":
                    terminal.cursor_shape = Vte.CursorShape.IBEAM;
                    break;
                case "Underline":
                    terminal.cursor_shape = Vte.CursorShape.UNDERLINE;
                    break;
            }
        } //No corresponding system keymap
    }

    private void update_colors () {
        if (terminal_settings != null) {
            string background_setting = terminal_settings.get_string (TERMINAL_BACKGROUND_KEY);
            Gdk.RGBA background_color = Gdk.RGBA ();
            background_color.parse (background_setting);

            string foreground_setting = terminal_settings.get_string (TERMINAL_FOREGROUND_KEY);
            Gdk.RGBA foreground_color = Gdk.RGBA ();
            foreground_color.parse (foreground_setting);

            string palette_setting = terminal_settings.get_string (TERMINAL_PALETTE_KEY);

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

            terminal.set_colors (foreground_color, background_color, palette);
        } //No suitable system keys
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

    private bool key_pressed (uint keyval, uint keycode, Gdk.ModifierType modifiers) {
        // Use hardware keycodes so the key used is unaffected by internationalized layout
        bool match_keycode (uint keyval, uint code) {
            Gdk.KeymapKey[] keys;

            var keymap = Gdk.Keymap.get_for_display (get_display ());
            if (keymap.get_entries_for_keyval (keyval, out keys)) {
                foreach (var key in keys) {
                    if (code == key.keycode) {
                        return Gdk.EVENT_STOP;
                    }
                }
            }

            return Gdk.EVENT_PROPAGATE;
        }

        if (CONTROL_MASK in modifiers && (SHIFT_MASK in modifiers ||
            terminal_settings != null && terminal_settings.get_boolean ("natural-copy-paste"))) {

            if (match_keycode (Gdk.Key.c, keycode) && terminal.get_has_selection ()) {
                actions.activate_action (ACTION_COPY, null);
                return Gdk.EVENT_STOP;
            } else if (match_keycode (Gdk.Key.v, keycode) && current_clipboard.wait_is_text_available ()) {
                actions.activate_action (ACTION_PASTE, null);
                return Gdk.EVENT_STOP;
            }
        }


        return Gdk.EVENT_PROPAGATE;
    }
}
