// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/***
  BEGIN LICENSE

  Copyright (C) 2019–2024 elementary, Inc. <https://elementary.io>
                2013 Mario Guerriero <mario@elementaryos.org>

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

namespace Scratch.Services {
    // Interface implemented by all plugins
    public interface ActivatablePlugin : Object {
        // Migrated from Peas.Activatable
        public abstract void activate ();
        public abstract void deactivate ();
        public virtual void update_state () {}
        public abstract GLib.Object object { owned get; construct; }
    }

    // Object shared with plugins providing signals and methods to interface with application
    public class Interface : GLib.Object {
        // Signals
        public signal void hook_window (Scratch.MainWindow window);
        public signal void hook_share_menu (GLib.MenuModel menu);
        public signal void hook_toolbar (Scratch.HeaderBar toolbar);
        public signal void hook_document (Scratch.Services.Document doc);
        public signal void hook_preferences_dialog (Scratch.Dialogs.Preferences dialog);
        public signal void hook_folder_item_change (File file, File? other_file, FileMonitorEvent event_type);

        public Scratch.TemplateManager template_manager { get; construct; }
        public Scratch.Services.PluginsManager manager { get; construct; }

        public Interface (PluginsManager _manager) {
            Object (
                manager: _manager
            );
        }

        construct {
            template_manager = new Scratch.TemplateManager ();
        }

        public Document open_file (File file) {
            var doc = new Document (manager.window.actions, file);
            manager.window.open_document.begin (doc);
            return doc;
        }

        public void close_document (Document doc) {
            manager.window.close_document (doc);
        }
    }

    public class PluginsManager : GLib.Object {
        public signal void hook_window (Scratch.MainWindow window);
        public signal void hook_share_menu (GLib.MenuModel menu);
        public signal void hook_toolbar (Scratch.HeaderBar toolbar);
        public signal void hook_document (Scratch.Services.Document doc);
        public signal void hook_preferences_dialog (Scratch.Dialogs.Preferences dialog);
        public signal void hook_folder_item_change (File file, File? other_file, FileMonitorEvent event_type);

        public signal void extension_added (Peas.PluginInfo info);
        public signal void extension_removed (Peas.PluginInfo info);

        private Peas.Engine engine;

        public weak MainWindow window { get; construct; }
        public Interface plugin_iface { get; private set; }

        public PluginsManager (MainWindow _window) {
            Object (window: _window);
        }

        construct {
            plugin_iface = new Interface (this);

            /* Let's init the engine */
            engine = Peas.Engine.get_default ();
            engine.enable_loader ("python");
            engine.add_search_path (Constants.PLUGINDIR, null);
            Scratch.settings.bind ("plugins-enabled", engine, "loaded-plugins", SettingsBindFlags.DEFAULT);

            /* Our extension set */
            var exts = new Peas.ExtensionSet.with_properties (
                engine,
                typeof (ActivatablePlugin),
                {"object"},
                {plugin_iface}
            );

            exts.extension_added.connect ((info, ext) => {
                ((ActivatablePlugin)ext).activate ();
                extension_added (info);
            });

            exts.extension_removed.connect ((info, ext) => {
                ((ActivatablePlugin)ext).deactivate ();
                extension_removed (info);
            });

            exts.@foreach ((Peas.ExtensionSetForeachFunc) on_extension_foreach, null);

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

        private void on_extension_foreach (Peas.ExtensionSet exts, Peas.PluginInfo info, Object ext, void* data) {
            ((ActivatablePlugin)ext).activate ();
        }

        // Return an emulation of the discontinued libpeas-1.0 widget
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
            var content = new Gtk.Box (HORIZONTAL, 6);
            var checkbox = new Gtk.CheckButton () {
                valign = Gtk.Align.CENTER,
                active = info.is_loaded (),
                margin_start = 6
            };
            checkbox.toggled.connect (() => {
                if (checkbox.active) {
                    engine.load_plugin (info);
                } else {
                    engine.unload_plugin (info);
                }
            });
            var image = new Gtk.Image.from_icon_name (info.get_icon_name (), LARGE_TOOLBAR) {
                valign = Gtk.Align.CENTER
            };
            var description_box = new Gtk.Box (VERTICAL, 0);
            var name_label = new Granite.HeaderLabel (info.name);
            //TODO In Granite-7 we can use secondary text property but emulate for now
            var description_label = new Gtk.Label (info.get_description ()) {
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
            content.set_data<string> ("name", info.get_name ());

            return content;
        }

        public uint get_n_plugins () {
            return engine.get_n_items ();
        }
    }
}
