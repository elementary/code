// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/***
  BEGIN LICENSE

  Copyright (C) 2013 Mario Guerriero <mario@elementaryos.org>
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

// namespace Scratch.Plugins {
public abstract class Scratch.Plugins.PluginBase : GLib.Object {
    public PluginInfo plugin_info { get; construct; }
    public Interface plugin_iface { get; construct; }
    public abstract void activate ();
    public abstract void deactivate ();
    public virtual void update_state () {}

    protected PluginBase (PluginInfo info, Interface iface) {
        Object (
            plugin_info: info,
            plugin_iface: iface
        );
    }
}

public struct Scratch.Plugins.PluginInfo {
    string name;
    string module_name;
    string description;
    string icon_name;
    bool is_active;
}

public class Scratch.Plugins.Interface : GLib.Object {
    public Scratch.Services.PluginsManager manager;
    // Signals
    public signal void hook_window (Scratch.MainWindow window);
    public signal void hook_share_menu (GLib.MenuModel menu);
    public signal void hook_toolbar (Scratch.HeaderBar toolbar);
    public signal void hook_document (Scratch.Services.Document doc);
    public signal void hook_preferences_dialog (Scratch.Dialogs.Preferences dialog);
    public signal void hook_folder_item_change (File file, File? other_file, FileMonitorEvent event_type);

    public Scratch.TemplateManager template_manager { private set; get; }

    public Interface (Scratch.Services.PluginsManager manager) {
        this.manager = manager;

        template_manager = new Scratch.TemplateManager ();
    }

    public Scratch.Services.Document open_file (File file) {
        var doc = new Scratch.Services.Document (manager.window.actions, file);
        manager.window.open_document (doc);
        return doc;
    }

    public void close_document (Scratch.Services.Document doc) {
        manager.window.close_document (doc);
    }
}

delegate Scratch.Plugins.PluginBase ModuleInitFunc (
    Scratch.Plugins.PluginInfo info,
    Scratch.Plugins.Interface iface
);

public class Scratch.Services.PluginsManager : GLib.Object {
    public const string ACTIVE_PLUGINS_KEY = "plugins-enabled";
    public const string KEYFILE_FILE_EXTENSION = ".plugin";
    public const string MODULE_FILE_EXTENSION = ".so";

    public Scratch.Plugins.Interface plugin_iface { private set; public get; }
    public weak MainWindow window;

    // Signals
    public signal void hook_window (Scratch.MainWindow window);
    public signal void hook_share_menu (GLib.MenuModel menu);
    public signal void hook_toolbar (Scratch.HeaderBar toolbar);
    public signal void hook_document (Scratch.Services.Document doc);
    public signal void hook_preferences_dialog (Scratch.Dialogs.Preferences dialog);
    public signal void hook_folder_item_change (File file, File? other_file, FileMonitorEvent event_type);

    public signal void extension_added ();
    public signal void extension_removed (Scratch.Plugins.PluginInfo info);

    Gee.HashMap<string,Scratch.Plugins.PluginBase> plugin_hash; // all plugins
    public Gee.HashSet<string> active_plugin_set; //active plugin names
    public Gee.List<Gtk.Widget> menuitem_references { get; private set; }

    public PluginsManager (MainWindow window) {
        this.window = window;
        plugin_iface = new Scratch.Plugins.Interface (this);

        /* From Files PluginManager construct */
        plugin_hash = new Gee.HashMap<string, Scratch.Plugins.PluginBase> ();
        active_plugin_set = new Gee.HashSet<string> ();
        menuitem_references = new Gee.LinkedList<Gtk.Widget> ();
        // Code has only one plugin directory.
        load_modules_from_dir (Constants.PLUGINDIR);

        // Connect managers signals to interface's signals
        this.hook_window.connect ((w) => {
            plugin_iface.hook_window (w);
        });

        this.hook_share_menu.connect ((m) => {
            plugin_iface.hook_share_menu (m);
        });

        this.hook_toolbar.connect ((t) => {
            plugin_iface.hook_toolbar (t);
        });

        this.hook_document.connect ((d) => {
            plugin_iface.hook_document (d);
        });

        this.hook_preferences_dialog.connect ((d) => {
            plugin_iface.hook_preferences_dialog (d);
        });

        this.hook_folder_item_change.connect ((source, dest, event) => {
            plugin_iface.hook_folder_item_change (source, dest, event);
        });

        // Activate plugins according to setting
        foreach (var plugin_name in settings.get_strv (ACTIVE_PLUGINS_KEY)) {
            if (plugin_hash.has_key (plugin_name)) {
                var plugin = plugin_hash.@get (plugin_name);
                activate_plugin (plugin);
            }
        }
    }

    private void activate_plugin (Scratch.Plugins.PluginBase plugin) {
        var info = plugin.plugin_info;
        if (!info.is_active) {
            plugin.activate ();
            info.is_active = true;
            active_plugin_set.add (info.name);
            extension_added (); // Signals Window to run initial hook function
            update_active_plugin_settings ();
        }
    }

    private void deactivate_plugin (Scratch.Plugins.PluginBase plugin) {
        var info = plugin.plugin_info;
        if (info.is_active) {
            plugin.deactivate ();
            info.is_active = false;
            active_plugin_set.remove (info.name);
            extension_removed (info);
            update_active_plugin_settings ();
        }
    }

    private void update_active_plugin_settings () {
        settings.set_strv (ACTIVE_PLUGINS_KEY, active_plugin_set.to_array ());
    }

    private void load_modules_from_dir (string path) {


        FileInfo info;
        FileEnumerator enumerator;
        try {
            string attributes = FileAttribute.STANDARD_NAME + "," +
                                FileAttribute.STANDARD_TYPE;
            var dir = GLib.File.new_for_path (path);
            enumerator = dir.enumerate_children (
                attributes,
                FileQueryInfoFlags.NONE
            );

            info = enumerator.next_file ();
            while (info != null) {
                if (info.get_file_type () == DIRECTORY) {
                    load_modules_from_dir (Path.build_filename (path, info.get_name ()));
                } else {
                    string file_name = info.get_name ();
                    var plugin_file = dir.get_child_for_display_name (file_name);
                    if (file_name.has_suffix (KEYFILE_FILE_EXTENSION)) {
                        load_plugin_keyfile (plugin_file, path);
                    }
                }

                info = enumerator.next_file ();
            }
        } catch (Error error) {
            critical ("Error listing contents of folder '%s': %s", path, error.message);
        }
    }

    private bool load_module (File dir, Scratch.Plugins.PluginInfo info) {
        if (plugin_hash.has_key (info.name)) {
            warning ("plugin for %s already loaded. Not adding again", info.name);
            return false;
        }

        //TODO Add a File key in the same way that Files does so we do not
        // have to construct the module path
        var file_path = dir.get_path ().concat (
            Path.DIR_SEPARATOR_S,
            "lib",
            info.module_name,
            MODULE_FILE_EXTENSION
        );
        debug ("Loading plugin for %s", file_path);

        Module module = Module.open (file_path, ModuleFlags.LOCAL);
        if (module == null) {
            warning (
                "Failed to load module from path '%s': %s",
                file_path,
                Module.error ()
            );
            return false;
        }

        void* function;
        if (!module.symbol ("module_init", out function)) {
            warning (
                "Failed to find entry point function '%s' in '%s': %s",
                "module_init",
                file_path,
                Module.error ()
            );
            return false;
        }

        unowned ModuleInitFunc module_init = (ModuleInitFunc) function;
        assert (module_init != null);

        //TODO Reconsider making all plugins resident for Code
        module.make_resident ();
        Scratch.Plugins.PluginBase plug = module_init (info, plugin_iface);
        debug ("Loaded module source: '%s'", module.name ());

        if (plug != null) {
            plugin_hash.set (info.name, plug);
            info.is_active = false;
            // Plugins only become active via initial settings or preferences dialog
            return true;
        } else {
            critical ("Module init failed for %s, it will not be available", module.name ());
        }

        return false;
    }

    // Load the keyfile from specified location
    private void load_plugin_keyfile (File keyfile_file, string parent) {
        var keyfile = new KeyFile ();
        var plugin_info = Scratch.Plugins.PluginInfo ();
        try {
            keyfile.load_from_file (keyfile_file.get_path (), KeyFileFlags.NONE);
            plugin_info.name = keyfile.get_string ("Plugin", "Name");
            plugin_info.module_name = keyfile.get_string ("Plugin", "Module");
            plugin_info.description = keyfile.get_string ("Plugin", "Description");
            if (keyfile.has_key ("Plugin", "Icon")) {
                plugin_info.icon_name = keyfile.get_string ("Plugin", "Icon");
            } else {
                plugin_info.icon_name = "extension";
            }
            // Should we expose the author(s)?
            load_module (keyfile_file.get_parent (), plugin_info);
        } catch (Error e) {
            warning ("Couldn't open the keyfile '%s': %s", keyfile_file.get_path (), e.message);

        }
    }

    // Return an emulation of the libpeas-1.0 widget
    public Gtk.Widget get_view () {
        var list_box = new Gtk.ListBox ();
        var scrolled_window = new Gtk.ScrolledWindow (null, null) {
            hscrollbar_policy = NEVER,
            vscrollbar_policy = AUTOMATIC,
            max_content_height = 300,
            child = list_box
        };
        var frame = new Gtk.Frame (null) {
            child = scrolled_window
        };

        foreach (var plugin in plugin_hash.values) {
            var content = get_widget_for_plugin (plugin);
            var row = new Gtk.ListBoxRow () {
                child = content
            };

            list_box.add (row);
        }

        // Could use a TreeMap (sortable)
        list_box.set_sort_func ((r1, r2) => {
            return strcmp (
                r1.get_child ().get_data<string> ("name"),
                r2.get_child ().get_data<string> ("name")
            );
        });
        frame.show_all ();
        return frame;
    }

    private Gtk.Widget get_widget_for_plugin (Scratch.Plugins.PluginBase plugin) {
        var info = plugin.plugin_info;
        var content = new Gtk.Box (HORIZONTAL, 6);
        var checkbox = new Gtk.CheckButton () {
            valign = Gtk.Align.CENTER,
            active = info.is_active,
            margin_start = 6
        };

        checkbox.toggled.connect (() => {
            if (checkbox.active) {
                activate_plugin (plugin);
            } else {
                deactivate_plugin (plugin);
            }
        });
        var image = new Gtk.Image.from_icon_name (info.icon_name, LARGE_TOOLBAR) {
            valign = Gtk.Align.CENTER
        };
        var description_box = new Gtk.Box (VERTICAL, 0);
        var name_label = new Granite.HeaderLabel (info.name);
        //TODO In Granite-7 we can use secondary text property but emulate for now
        var description_label = new Gtk.Label (info.description) {
            use_markup = true,
            wrap = true,
            xalign = 0,
            margin_start = 6,
            margin_bottom = 6
        };
        description_label.get_style_context ().add_class (Granite.STYLE_CLASS_SMALL_LABEL);
        description_label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);
        description_box.add (name_label);
        description_box.add (description_label);
        content.add (checkbox);
        content.add (image);
        content.add (description_box);
        content.set_data<string> ("name", info.name);

        return content;
    }

    public uint get_n_plugins () {
        warning ("get n plugins  %u", plugin_hash.size);
        return plugin_hash.size;
    }
}
