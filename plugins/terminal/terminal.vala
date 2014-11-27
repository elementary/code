// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/***
  BEGIN LICENSE

  Copyright (C) 2011-2013 Mario Guerriero <mario@elementaryos.org>
  This program is free software: you can redistribute it and/or modify it
  under the terms of the GNU Lesser General Public License version 3, as published
  by the Free Software Foundation.

  This program is distributed in the hope that it will be useful, but
  WITHOUT ANY WARRANTY; without even the implied warranties of
  MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
  PURPOSE.  See the GNU General Public License for more details.

  You should have received a copy of the GNU General Public License along
  with this program.  If not, see <http://www.gnu.org/licenses/>

  END LICENSE
***/

using Vte;

public const string NAME = N_("Terminal");
public const string DESCRIPTION = N_("A terminal in your text editor");

public class Scratch.Plugins.Terminal : Peas.ExtensionBase,  Peas.Activatable {

    MainWindow window = null;
    Gtk.Notebook? bottombar = null;
    Scratch.Widgets.Toolbar? toolbar = null;
    Gtk.ToggleToolButton? tool_button = null;
    Vte.Terminal terminal;
    Gtk.Grid grid;

    Scratch.Services.Interface plugins;
    public Object object { owned get; construct; }

    public void update_state () {
    }

    public void activate () {
        plugins = (Scratch.Services.Interface) object;

        plugins.hook_window.connect ((w) => {
            if (window != null)
                return;

            window = w;
            window.key_press_event.connect (switch_focus);
        });

        plugins.hook_notebook_bottom.connect ((n) => {
            if (bottombar == null) {
                this.bottombar = n;
                on_hook_notebook (this.bottombar);
            }
        });
        plugins.hook_toolbar.connect ((n) => { 
            if (toolbar == null) {
                this.toolbar = n;
                on_hook_toolbar (this.toolbar);
            }
        });
        if (bottombar != null)
            on_hook_notebook (this.bottombar);
        if (toolbar != null)
            on_hook_toolbar (this.toolbar);
    }

    public void deactivate () {
        if (terminal != null)
            grid.destroy ();
        if (tool_button != null)
            tool_button.destroy ();
        if (window != null)
            window.key_press_event.disconnect (switch_focus);
    }

    bool switch_focus (Gdk.EventKey event) {
        if (event.keyval == Gdk.Key.t
            && Gdk.ModifierType.MOD1_MASK in event.state
            && Gdk.ModifierType.CONTROL_MASK in event.state) {
            if (terminal.has_focus && window.get_current_document () != null) {
                window.get_current_document ().focus ();
                debug ("Move focus: EDITOR.");
                return true;
            } else if (window.get_current_document () != null && window.get_current_document ().source_view.has_focus) {
                terminal.grab_focus ();
                debug ("Move focus: TERMINAL.");
                return true;
            }
        }
        return false;
    }
    
    void on_hook_toolbar (Scratch.Widgets.Toolbar toolbar) {
        if (tool_button != null)
            return;

        var icon = new Gtk.Image.from_icon_name ("utilities-terminal", Gtk.IconSize.LARGE_TOOLBAR);
        tool_button = new Gtk.ToggleToolButton ();
        tool_button.set_icon_widget (icon);
        tool_button.set_label (_("Show Terminal"));
        tool_button.set_active (false);
        tool_button.tooltip_text = _("Show Terminal");
        tool_button.toggled.connect (() => {
        	if (!this.tool_button.get_active ()) {
        		this.bottombar.remove (this.grid);
        	} else {
		        this.bottombar.append_page (grid, new Gtk.Label (_("Terminal")));
        	}
        });

        icon.show ();
        tool_button.show ();

        toolbar.pack_start (tool_button);
    }

    void on_hook_notebook (Gtk.Notebook notebook) {
        this.terminal = new Vte.Terminal ();
        this.terminal.scrollback_lines = -1;

        // Set terminal font to system default font
        var system_settings = new GLib.Settings ("org.gnome.desktop.interface");
        string font_name = system_settings.get_string ("monospace-font-name");
        #if ! VTE291
        this.terminal.set_font_from_string (font_name);
        #else
        var fd = Pango.FontDescription.from_string (font_name);
        this.terminal.set_font (fd);
        #endif

        // Set allow-bold, audible-bell, background, foreground, and palette of pantheon-terminal
        var schema_source = SettingsSchemaSource.get_default ();
        var terminal_schema = schema_source.lookup ("org.pantheon.terminal.settings", true);
        if (terminal_schema != null) {
            var pantheon_terminal_settings = new GLib.Settings ("org.pantheon.terminal.settings");

            bool allow_bold_setting = pantheon_terminal_settings.get_boolean ("allow-bold");
            this.terminal.set_allow_bold (allow_bold_setting);

            bool audible_bell_setting = pantheon_terminal_settings.get_boolean ("audible-bell");
            this.terminal.set_audible_bell (audible_bell_setting);

            #if ! VTE291
            this.terminal.set_background_image (null); // allows background and foreground settings to take effect
            #endif

            string background_setting = pantheon_terminal_settings.get_string ("background");
            #if ! VTE291
            Gdk.Color background_color;
            Gdk.Color.parse (background_setting, out background_color);
            #else
            Gdk.RGBA background_color = Gdk.RGBA ();
            background_color.parse (background_setting);
            #endif

            string foreground_setting = pantheon_terminal_settings.get_string ("foreground");
            #if ! VTE291
            Gdk.Color foreground_color;
            Gdk.Color.parse (foreground_setting, out foreground_color);
            #else
            Gdk.RGBA foreground_color = Gdk.RGBA ();
            foreground_color.parse (foreground_setting);
            #endif

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

            #if ! VTE291
            Gdk.Color[] palette = new Gdk.Color[16];
            #else
            Gdk.RGBA[] palette = new Gdk.RGBA[16];
            #endif

            for (int i = 0; i < hex_palette.length; i++) {
                #if ! VTE291
                Gdk.Color new_color;
                Gdk.Color.parse (hex_palette[i], out new_color);
                #else
                Gdk.RGBA new_color = Gdk.RGBA ();
                new_color.parse (hex_palette[i]);
                #endif

                palette[i] = new_color;
            }

            this.terminal.set_colors (foreground_color, background_color, palette);

        } // end pantheon-terminal settings

        // Popup menu
        var menu = new Gtk.Menu ();

        var copy = new Gtk.MenuItem.with_label (_("Copy"));
        copy.activate.connect (() => {
            terminal.copy_clipboard ();
        });
        menu.append (copy);
        copy.show ();

        var paste = new Gtk.MenuItem.with_label (_("Paste"));
        paste.activate.connect (() => {
            terminal.paste_clipboard ();
        });
        menu.append (paste);
        paste.show ();

        this.terminal.button_press_event.connect ((event) => {
            if (event.button == 3) {
                menu.select_first (false);
                menu.popup (null, null, null, event.button, event.time);
            }
            return false;
        });

        try {
            #if ! VTE291
            this.terminal.fork_command_full (Vte.PtyFlags.DEFAULT, "~/", { Vte.get_user_shell () }, null, GLib.SpawnFlags.SEARCH_PATH, null, null);
            #else
            this.terminal.spawn_sync (Vte.PtyFlags.DEFAULT, "~/", { Vte.get_user_shell () }, null, GLib.SpawnFlags.SEARCH_PATH, null, null, null);
            #endif
        } catch (GLib.Error e) {
            warning (e.message);
        }

        grid = new Gtk.Grid ();
        var sb = new Gtk.Scrollbar (Gtk.Orientation.VERTICAL, terminal.vadjustment);
        grid.attach (terminal, 0, 0, 1, 1);
        grid.attach (sb, 1, 0, 1, 1);

        // Make the terminal occupy the whole GUI
        terminal.vexpand = true;
        terminal.hexpand = true;

        grid.show_all ();

    }
}

[ModuleInit]
public void peas_register_types (GLib.TypeModule module) {
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type (typeof (Peas.Activatable),
                                     typeof (Scratch.Plugins.Terminal));
}
