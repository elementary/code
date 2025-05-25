/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2023 elementary, Inc. <https://elementary.io>
 *
 * Authored by: Marvin Ahlgrimm
 */


public class Scratch.Plugins.FuzzySearch: Peas.ExtensionBase, Scratch.Services.ActivatablePlugin {
    public Object object { owned get; construct; }
    private const uint ACCEL_KEY = Gdk.Key.F;
    private const Gdk.ModifierType ACCEL_MODTYPE = Gdk.ModifierType.MOD1_MASK;

    private Scratch.Services.FuzzySearchIndexer indexer;
    private MainWindow window = null;
    private Scratch.Services.Interface plugins;
    private GLib.MenuItem fuzzy_menuitem;
    private GLib.Cancellable cancellable;

    private const string ACTION_GROUP = "fuzzysearch";
    private const string ACTION_PREFIX = ACTION_GROUP + ".";
    private const string ACTION_SHOW = "action-show";
    private const ActionEntry[] ACTION_ENTRIES = {
        {ACTION_SHOW, fuzzy_find }
    };

    private SimpleActionGroup actions;
    private GLib.Settings folder_settings;

    private static Gee.MultiMap<string, string> action_accelerators = new Gee.HashMultiMap<string, string> ();

    static construct {
        action_accelerators.set (ACTION_SHOW, @"<Alt>$(Gdk.keyval_name (ACCEL_KEY))");
    }

    public void update_state () {

    }

    public void activate () {
        plugins = (Scratch.Services.Interface) object;

        plugins.hook_window.connect ((w) => {
            if (window != null) {
                return;
            }

            cancellable = new GLib.Cancellable ();
            indexer = new Scratch.Services.FuzzySearchIndexer (cancellable);

            indexer.start_async.begin ((obj, res) => {
                indexer.start_async.end (res);
            });

            window = w;

            folder_settings = new GLib.Settings (Constants.PROJECT_NAME + ".folder-manager");
            add_actions ();
            folder_settings.changed["opened-folders"].connect (handle_opened_projects_change);
        });

        plugins.hook_folder_item_change.connect ((src, dest, event) => {
            if (indexer == null) {
                return;
            }

            indexer.handle_folder_item_change (src, dest, event);
        });
    }

    private void add_actions () {
        if (actions == null) {
            actions = new SimpleActionGroup ();
            actions.add_action_entries (ACTION_ENTRIES, this);
        }

        window.insert_action_group (ACTION_GROUP, actions);

        var application = (Gtk.Application) GLib.Application.get_default ();
        var app = (Scratch.Application) application;

        foreach (var action in action_accelerators.get_keys ()) {
            var accels_array = action_accelerators[action].to_array ();
            accels_array += null;

            app.set_accels_for_action (ACTION_PREFIX + action, accels_array);
        }

        handle_opened_projects_change ();

        fuzzy_menuitem = new GLib.MenuItem (_("Find Project Files"), ACTION_PREFIX + ACTION_SHOW );

        var menu = window.sidebar.project_menu_model as GLib.Menu;
        menu.append_item (fuzzy_menuitem);
    }

    private void remove_actions () {
        var sidebar_menu = window.sidebar.project_menu_model as GLib.Menu;
        int length = sidebar_menu.get_n_items ();
        for (var i = length - 1; i >= 0; i--) {
            var action_name = sidebar_menu.get_item_attribute_value (
                i,
                GLib.Menu.ATTRIBUTE_ACTION,
                GLib.VariantType.STRING
            ).get_string ();
            if (action_name.has_prefix (ACTION_PREFIX)) {
                sidebar_menu.remove (i);
            }
        }

        var application = (Gtk.Application) GLib.Application.get_default ();
        var app = (Scratch.Application) application;
        foreach (var action in action_accelerators.get_keys ()) {
            app.set_accels_for_action (ACTION_PREFIX + action, {});
        }

        window.insert_action_group (ACTION_GROUP, null);
    }

    private void fuzzy_find () {
        string[] opened_folders = folder_settings.get_strv ("opened-folders");
        if (opened_folders == null || opened_folders.length < 1) {
            return;
        }

        var popover = new Scratch.FuzzySearchPopover (indexer, window);
        popover.open_file.connect ((filepath) => {
            var file = new Scratch.FolderManager.File (filepath);
            var doc = new Scratch.Services.Document (window.actions, file.file);

            window.open_document.begin (doc);
            popover.popdown ();
        });

        popover.close_search.connect (() => popover.popdown ());
        popover.popup ();
    }

    public void deactivate () {
        folder_settings.changed["opened-folders"].disconnect (handle_opened_projects_change);
        remove_actions ();
        if (cancellable != null) {
            cancellable.cancel ();
        }
    }


    private void handle_opened_projects_change () {
        var show_action = Utils.action_from_group (ACTION_SHOW, actions);
        string[] opened_folders = folder_settings.get_strv ("opened-folders");
        show_action.set_enabled (opened_folders != null && opened_folders.length > 0);
    }
}

[ModuleInit]
public void peas_register_types (GLib.TypeModule module) {
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type (
        typeof (Scratch.Services.ActivatablePlugin),
        typeof (Scratch.Plugins.FuzzySearch)
    );
}
