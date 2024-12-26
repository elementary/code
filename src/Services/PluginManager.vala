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
    // public abstract PluginBase module_init (PluginInfo plugin_info);
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
    // Peas.Engine engine;
    // Peas.ExtensionSet exts;

    // string settings_field;

    public Scratch.Plugins.Interface plugin_iface { private set; public get; }

    public weak MainWindow window;

    // Signals
    public signal void hook_window (Scratch.MainWindow window);
    public signal void hook_share_menu (GLib.MenuModel menu);
    public signal void hook_toolbar (Scratch.HeaderBar toolbar);
    public signal void hook_document (Scratch.Services.Document doc);
    public signal void hook_preferences_dialog (Scratch.Dialogs.Preferences dialog);
    public signal void hook_folder_item_change (File file, File? other_file, FileMonitorEvent event_type);

    public signal void extension_added (Scratch.Plugins.PluginInfo info);
    public signal void extension_removed (Scratch.Plugins.PluginInfo info);

    /* FROM FILES PLUGIN SYSTEM */


    Gee.HashMap<string,Scratch.Plugins.PluginBase> plugin_hash;
    Gee.List<string> names;
    // bool in_available = false;
    bool update_queued = false;
    // bool is_admin = false;
    public Gee.List<Gtk.Widget> menuitem_references { get; private set; }

    public PluginsManager (MainWindow window) {
        this.window = window;

        // settings_field = "plugins-enabled";

        plugin_iface = new Scratch.Plugins.Interface (this);

        /* From Files PluginManager construct */
        plugin_hash = new Gee.HashMap<string, Scratch.Plugins.PluginBase> ();
        names = new Gee.ArrayList<string> ();
        menuitem_references = new Gee.LinkedList<Gtk.Widget> ();

        // Code has only one plugin directory.

        // if (!is_admin) {
        // plugin_dirs += Path.build_filename (plugin_dir, "core");
        // plugin_dirs += plugin_dir;

        // load_plugins ();
        load_modules_from_dir (Constants.PLUGINDIR);

        // No need to monitor plugin directory - we do not allow third party plugins

        // /* Monitor plugin dirs */
        // foreach (string path in plugin_dirs) {
        //     set_directory_monitor (path);
        // }
        // }

        // /* Let's init the engine */
        // engine = Peas.Engine.get_default ();
        // engine.enable_loader ("python");
        // engine.add_search_path (Constants.PLUGINDIR, null);
        // Scratch.settings.bind ("plugins-enabled", engine, "loaded-plugins", SettingsBindFlags.DEFAULT);

        // /* Our extension set */
        // exts = new Peas.ExtensionSet (engine, typeof (Peas.Activatable), "object", plugin_iface, null);

        // exts.extension_added.connect ((info, ext) => {
        //     ((Peas.Activatable)ext).activate ();
        //     extension_added (info);
        // });

        // exts.extension_removed.connect ((info, ext) => {
        //     ((Peas.Activatable)ext).deactivate ();
        //     extension_removed (info);
        // });

        // exts.foreach (on_extension_foreach);

        // // Connect managers signals to interface's signals
        // this.hook_window.connect ((w) => {
        //     plugin_iface.hook_window (w);
        // });

        // this.hook_share_menu.connect ((m) => {
        //     plugin_iface.hook_share_menu (m);
        // });

        // this.hook_toolbar.connect ((t) => {
        //     plugin_iface.hook_toolbar (t);
        // });

        // this.hook_document.connect ((d) => {
        //     plugin_iface.hook_document (d);
        // });

        // this.hook_preferences_dialog.connect ((d) => {
        //     plugin_iface.hook_preferences_dialog (d);
        // });

        // this.hook_folder_item_change.connect ((source, dest, event) => {
        //     plugin_iface.hook_folder_item_change (source, dest, event);
        // });
    }

    // void on_extension_foreach (Peas.ExtensionSet set, Peas.PluginInfo info, Peas.Extension extension) {
    //     ((Peas.Activatable)extension).activate ();
    // }

    public Gtk.Widget get_view () {
        // var view = new PeasGtk.PluginManager (engine);
        // var bottom_box = view.get_children ().nth_data (1);
        // bottom_box.no_show_all = true;
        return new Gtk.Frame (null);
    }



// [Version (deprecated = true, deprecated_since = "0.2", replacement = "Files.PluginManager.menuitem_references")]
// public GLib.List<Gtk.Widget>? menus; /* this doesn't manage GObject references properly */


// private void load_plugins () {
//     in_available = true;
//     load_modules_from_dir (plugin_dirs[1]);
//     in_available = false;
// }

// private void set_directory_monitor (string path) {
//     var dir = GLib.File.new_for_path (path);

//     try {
//         var monitor = dir.monitor_directory (FileMonitorFlags.NONE, null);
//         monitor.changed.connect (on_plugin_directory_change);
//         monitor.ref (); /* keep alive */
//     } catch (IOError e) {
//         critical ("Could not setup monitor for '%s': %s", dir.get_path (), e.message);
//     }
// }

// private async void on_plugin_directory_change (GLib.File file, GLib.File? other_file, FileMonitorEvent event) {
//     if (update_queued) {
//         return;
//     }

//     update_queued = true;

//     Idle.add_full (Priority.LOW, on_plugin_directory_change.callback);
//     yield;

//     load_plugins ();
//     update_queued = false;
// }

    private void load_modules_from_dir (string path) {
        string attributes = FileAttribute.STANDARD_NAME + "," +
                            FileAttribute.STANDARD_TYPE;

        FileInfo info;
        FileEnumerator enumerator;

        try {
            var dir = GLib.File.new_for_path (path);

            enumerator = dir.enumerate_children
                                        (attributes,
                                         FileQueryInfoFlags.NONE);

            info = enumerator.next_file ();

            while (info != null) {
                string file_name = info.get_name ();
                var plugin_file = dir.get_child_for_display_name (file_name);

                if (file_name.has_suffix (".plug")) {
                    load_plugin_keyfile (plugin_file.get_path (), path);
                }

                info = enumerator.next_file ();
            }
        } catch (Error error) {
            critical ("Error listing contents of folder '%s': %s", path, error.message);
        }
    }

    private bool load_module (string file_path, Scratch.Plugins.PluginInfo plugin_info) {
        if (plugin_hash.has_key (file_path)) {
            debug ("plugin for %s already loaded. Not adding again", file_path);
            return false;
        }

        debug ("Loading plugin for %s", file_path);

        Module module = Module.open (file_path, ModuleFlags.LOCAL);
        if (module == null) {
            warning ("Failed to load module from path '%s': %s",
                     file_path,
                     Module.error ());
            return false;
        }

        void* function;

        if (!module.symbol ("module_init", out function)) {
            warning ("Failed to find entry point function '%s' in '%s': %s",
                     "module_init",
                     file_path,
                     Module.error ());
            return false;
        }

        unowned ModuleInitFunc module_init = (ModuleInitFunc) function;
        assert (module_init != null);

        //TODO Reconsider for Code plugins
        /* We don't want our modules to ever unload */
        module.make_resident ();
        Scratch.Plugins.PluginBase plug = module_init (plugin_info, plugin_iface);
        
        debug ("Loaded module source: '%s'", module.name ());

        if (plug != null) {
            plugin_hash.set (file_path, plug);
            return true;
        }

        // if (in_available) {
        //     names.add (name);
        // }
        return false;
    }

    // Load the .plugin file from each plugin folder
    private void load_plugin_keyfile (string path, string parent) {
        var keyfile = new KeyFile ();
        var plugin_info = Scratch.Plugins.PluginInfo ();
        try {
            keyfile.load_from_file (path, KeyFileFlags.NONE);
            plugin_info.name = keyfile.get_string ("Plugin", "Name");
            plugin_info.module_name = keyfile.get_string ("Plugin", "Module");
            plugin_info.description = keyfile.get_string ("Plugin", "Description");
            plugin_info.icon_name = keyfile.get_string ("Plugin", "Icon");
            // Should we expose the author(s)?
            var plug_path = Path.build_filename (parent, keyfile.get_string ("Plugin", "File"));
            load_module (plug_path, plugin_info);
        } catch (Error e) {
            warning ("Couldn't open the keyfile '%s': %s", path, e.message);

        }
    }

    public Gee.List<string> get_available_plugins () {
        return names;
    }
}
// }
