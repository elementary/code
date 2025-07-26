/*
 * SPDX-License-Identifier: LGPL-3.0-or-later
 * SPDX-FileCopyrightText: 2019-2025 elementary, Inc. (https://elementary.io)
 *                         2013 Mario Guerriero <mario@elementaryos.org>
 */

    // Interface implemented by all plugins  (Migrated from Peas.Activatable)
public interface Scratch.Services.ActivatablePlugin : Object {
    public abstract void activate ();
    public abstract void deactivate ();
    public virtual void update_state () {}
    public abstract GLib.Object object { owned get; set construct; }
}

// Object shared with plugins providing signals and methods to interface with application
public class Scratch.Services.Interface : GLib.Object {
    // Signals
    public signal void hook_window (Scratch.MainWindow window);
    public signal void hook_share_menu (GLib.MenuModel menu);
    public signal void hook_toolbar (Scratch.HeaderBar toolbar);
    public signal void hook_document (Scratch.Services.Document doc);
    public signal void hook_preferences_dialog (Scratch.Dialogs.Preferences dialog);
    public signal void hook_folder_item_change (File file, File? other_file, FileMonitorEvent event_type);

    public Scratch.TemplateManager template_manager { get; private set; }
    public Scratch.Services.PluginsManager manager { get; construct; }

    public Interface (Scratch.Services.PluginsManager _manager) {
        Object (
            manager: _manager
        );
    }

    construct {
        template_manager = new Scratch.TemplateManager ();
    }

    public Scratch.Services.Document open_file (File file) {
        var doc = new Scratch.Services.Document (manager.window.actions, file);
        manager.window.open_document.begin (doc);
        return doc;
    }

    public void close_document (Scratch.Services.Document doc) {
        manager.window.close_document (doc);
    }
}

public class Scratch.Services.PluginsManager : GLib.Object {
    public signal void hook_window (Scratch.MainWindow window);
    public signal void hook_share_menu (GLib.MenuModel menu);
    public signal void hook_toolbar (Scratch.HeaderBar toolbar);
    public signal void hook_document (Scratch.Services.Document doc);
    public signal void hook_preferences_dialog (Scratch.Dialogs.Preferences dialog);
    public signal void hook_folder_item_change (File file, File? other_file, FileMonitorEvent event_type);

    public signal void extension_added (Peas.PluginInfo info);
    public signal void extension_removed (Peas.PluginInfo info);

    private Peas.Engine engine;
    private Peas.ExtensionSet extension_set;

    public Scratch.Services.Interface plugin_iface { get; private set; }
    public weak Scratch.MainWindow window { get; construct; }

    public PluginsManager (Scratch.MainWindow _window) {
        Object (window: _window);
    }

    construct {
        plugin_iface = new Scratch.Services.Interface (this);

        /* Let's init the engine */
        engine = Peas.Engine.get_default ();
        engine.enable_loader ("python");
        engine.add_search_path (Constants.PLUGINDIR, null);
        Scratch.settings.bind ("plugins-enabled", engine, "loaded-plugins", SettingsBindFlags.DEFAULT);

        /* Our extension set. We need to keep a reference to this after migrating to libpeas-2 */
        extension_set = new Peas.ExtensionSet.with_properties (
            engine,
            typeof (Scratch.Services.ActivatablePlugin),
            {"object"},
            {plugin_iface}
        );

        extension_set.extension_added.connect ((info, ext) => {
            ((Scratch.Services.ActivatablePlugin)ext).activate ();
            extension_added (info);
        });

        extension_set.extension_removed.connect ((info, ext) => {
            ((Scratch.Services.ActivatablePlugin)ext).deactivate ();
            extension_removed (info);
        });

        extension_set.@foreach ((exts, info, ext) => {
            ((Scratch.Services.ActivatablePlugin)ext).activate ();
        }, null);

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
    }

    // Return an emulation of the discontinued libpeas-1.0 widget
    public Gtk.Widget get_view () {
        var list_box = new Gtk.ListBox ();
        list_box.get_accessible ().accessible_name = _("Extensions");

        var scrolled_window = new Gtk.ScrolledWindow (null, null) {
            hscrollbar_policy = NEVER,
            child = list_box
        };

        var frame = new Gtk.Frame (null) {
            child = scrolled_window
        };

        // Bind the engine ListModel and use a row factory
        list_box.bind_model (engine, get_widget_for_plugin_info);

        // Cannot sort a ListModel so sort the ListBox (is there a better way?)
        // Gtk warns the function will be ignored but it does in fact work, at least
        // on initial display. We know the model will not change while the view is used
        // In Gtk4 could use SortListModel
        list_box.set_sort_func ((r1, r2) => {
            return strcmp (
                r1.get_child ().get_data<string> ("name"),
                r2.get_child ().get_data<string> ("name")
            );
        });

        frame.show_all ();
        return frame;
    }

    private Gtk.Widget get_widget_for_plugin_info (Object obj) {
        var info = (Peas.PluginInfo)obj;

        var load_switch = new Gtk.Switch () {
            valign = CENTER,
            state = info.is_loaded ()
        };

        var image = new Gtk.Image.from_icon_name (info.get_icon_name (), LARGE_TOOLBAR) {
            valign = START
        };

        var name_label = new Gtk.Label (info.name) {
            ellipsize = MIDDLE,
            xalign = 0
        };

        var description_label = new Gtk.Label (info.get_description ()) {
            ellipsize = END,
            lines = 2,
            wrap = true,
            xalign = 0
        };
        description_label.get_style_context ().add_class (Granite.STYLE_CLASS_SMALL_LABEL);
        description_label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);

        var description_box = new Gtk.Box (VERTICAL, 0) {
            hexpand = true
        };
        description_box.add (name_label);
        description_box.add (description_label);

        var content = new Gtk.Box (HORIZONTAL, 6) {
            margin_top = 6,
            margin_end = 12,
            margin_bottom = 6,
            margin_start = 6
        };
        content.add (image);
        content.add (description_box);
        content.add (load_switch);
        content.set_data<string> ("name", info.get_name ());

            load_switch.notify["active"].connect (() => {
                if (load_switch.active) {
                engine.load_plugin (info);
            } else {
                engine.unload_plugin (info);
            }
        });

        return content;
    }

    public uint get_n_plugins () {
        return engine.get_n_items ();
    }
}
