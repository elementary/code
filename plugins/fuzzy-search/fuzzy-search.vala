/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2023 elementary, Inc. <https://elementary.io>
 *
 * Authored by: Marvin Ahlgrimm
 */


public class Scratch.Plugins.FuzzySearch: Peas.ExtensionBase, Peas.Activatable {
    public Object object { owned get; construct; }
    private const uint ACCEL_KEY = Gdk.Key.F;
    private const Gdk.ModifierType ACCEL_MODTYPE = Gdk.ModifierType.MOD1_MASK;

    private Scratch.Services.FuzzySearchIndexer indexer;
    private MainWindow window = null;
    private Scratch.Services.Interface plugins;
    private Gtk.EventControllerKey key_controller;
    private Gtk.MenuItem fuzzy_menuitem;
    private GLib.Cancellable cancellable;

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
            key_controller = new Gtk.EventControllerKey (window) {
                propagation_phase = BUBBLE
            };

            key_controller.key_pressed.connect (on_window_key_press_event);

            fuzzy_menuitem = new Gtk.MenuItem.with_label (_("Find Project Files"));
            var child = ((Gtk.Bin)fuzzy_menuitem).get_child ();
            if (child is Gtk.AccelLabel) {
                ((Gtk.AccelLabel)child).set_accel (ACCEL_KEY, ACCEL_MODTYPE);
            }

            fuzzy_menuitem.activate.connect (fuzzy_find);
            fuzzy_menuitem.show ();
            window.sidebar.project_menu.append (fuzzy_menuitem);
        });

        plugins.hook_folder_item_change.connect ((src, dest, event) => {
            if (indexer == null) {
                return;
            }

            indexer.handle_folder_item_change (src, dest, event);
        });
    }

    bool on_window_key_press_event (uint keyval, uint keycode, Gdk.ModifierType state) {
        /* <Alt>f shows fuzzy search dialog */
        switch (Gdk.keyval_to_upper (keyval)) {
            case ACCEL_KEY:
                if ((state & ACCEL_MODTYPE) == ACCEL_MODTYPE) {
                    fuzzy_find ();
                    return true;
                }

                break;
            default:
                return false;
        }

        return false;
    }

    private void fuzzy_find () {
        var settings = new GLib.Settings ("io.elementary.code.folder-manager");

        string[] opened_folders = settings.get_strv ("opened-folders");
        if (opened_folders == null || opened_folders.length < 1) {
            return;
        }

        var popover = new Scratch.FuzzySearchPopover (indexer, window);
        popover.open_file.connect ((filepath) => {
            var file = new Scratch.FolderManager.File (filepath);
            var doc = new Scratch.Services.Document (window.actions, file.file);

            window.open_document (doc);
            popover.popdown ();
        });

        popover.close_search.connect (() => popover.popdown ());
        popover.popup ();
    }

    public void deactivate () {
        key_controller.key_pressed.disconnect (on_window_key_press_event);
        window.sidebar.project_menu.remove (fuzzy_menuitem);
        if (cancellable != null) {
            cancellable.cancel ();
        }
    }
}

[ModuleInit]
public void peas_register_types (GLib.TypeModule module) {
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type (
        typeof (Peas.Activatable),
        typeof (Scratch.Plugins.FuzzySearch)
    );
}
