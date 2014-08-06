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
    
    Gtk.Notebook? bottombar = null;
    Vte.Terminal terminal;
    Gtk.Grid grid;
    
    Scratch.Services.Interface plugins;
    public Object object { owned get; construct; }
   
    public void update_state () {
    }

    public void activate () {
        plugins = (Scratch.Services.Interface) object;        
        plugins.hook_notebook_bottom.connect ((n) => { 
            if (bottombar == null) {
                this.bottombar = n;
                on_hook (this.bottombar);
            }
        });
        if (bottombar != null)
            on_hook (this.bottombar);
    }

    public void deactivate () {
        if (terminal != null)
            grid.destroy ();
    }
    
    void on_hook (Gtk.Notebook notebook) {
        this.terminal = new Vte.Terminal ();
        this.terminal.scrollback_lines = -1;
        
        // Set terminal font to system default font
        var system_settings = new GLib.Settings ("org.gnome.desktop.interface");
        string font_name = system_settings.get_string ("monospace-font-name");
        this.terminal.set_font_from_string (font_name);

        // Set background, foreground, opacity and palette of pantheon-terminal
        var pantheon_terminal_settings = new GLib.Settings ("org.pantheon.terminal.settings");

        string background_setting = pantheon_terminal_settings.get_string ("background");
        Gdk.Color background_color;
        Gdk.Color.parse (background_setting, out background_color);

        string foreground_setting = pantheon_terminal_settings.get_string ("foreground");
        Gdk.Color foreground_color;
        Gdk.Color.parse (foreground_setting, out foreground_color);

        int opacity_setting = pantheon_terminal_settings.get_int ("opacity") * 65535;
        this.terminal.set_background_image (null); // allows background and foreground settings to take effect
        this.terminal.set_opacity ((uint16) (opacity_setting / 100));

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

        Gdk.Color[] palette = new Gdk.Color[16];

        for (int i = 0; i < hex_palette.length; i++) {
            Gdk.Color new_color;
            Gdk.Color.parse (hex_palette[i], out new_color);

            palette[i] = new_color;
        }

        this.terminal.set_colors (foreground_color, background_color, palette);

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
           this.terminal.fork_command_full (Vte.PtyFlags.DEFAULT, "~/", { Vte.get_user_shell () }, null, GLib.SpawnFlags.SEARCH_PATH, null, null);
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
            
        notebook.append_page (grid, new Gtk.Label (_("Terminal")));
        
        grid.show_all ();

    }
}

[ModuleInit]
public void peas_register_types (GLib.TypeModule module) {
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type (typeof (Peas.Activatable),
                                     typeof (Scratch.Plugins.Terminal));
}
