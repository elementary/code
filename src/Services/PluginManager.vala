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

namespace Scratch.Services {
    // Interface implemented by all plugins
    public interface ActivatablePlugin : Object {
        // Migrated from Peas.Activatable
        public virtual void activate () {}
        public virtual void deactivate () {}
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

        public Scratch.TemplateManager template_manager { private set; get; }
        public Scratch.Services.PluginsManager manager { private set; get; }

        public Interface (PluginsManager manager) {
            this.manager = manager;

            template_manager = new Scratch.TemplateManager ();
        }

        public Document open_file (File file) {
            var doc = new Document (manager.window.actions, file);
            manager.window.open_document (doc);
            return doc;
        }

        public void close_document (Document doc) {
            manager.window.close_document (doc);
        }
    }

    public class PluginsManager : GLib.Object {
        Peas.Engine engine;
        Peas.ExtensionSet exts;

        string settings_field;

        public Interface plugin_iface { private set; public get; }

        public weak MainWindow window;

        // Signals
        public signal void hook_window (Scratch.MainWindow window);
        public signal void hook_share_menu (GLib.MenuModel menu);
        public signal void hook_toolbar (Scratch.HeaderBar toolbar);
        public signal void hook_document (Scratch.Services.Document doc);
        public signal void hook_preferences_dialog (Scratch.Dialogs.Preferences dialog);
        public signal void hook_folder_item_change (File file, File? other_file, FileMonitorEvent event_type);

        public signal void extension_added (Peas.PluginInfo info);
        public signal void extension_removed (Peas.PluginInfo info);

        public PluginsManager (MainWindow window) {
            this.window = window;

            settings_field = "plugins-enabled";

            plugin_iface = new Interface (this);

            /* Let's init the engine */
            engine = Peas.Engine.get_default ();
            engine.enable_loader ("python");
            engine.add_search_path (Constants.PLUGINDIR, null);
            Scratch.settings.bind ("plugins-enabled", engine, "loaded-plugins", SettingsBindFlags.DEFAULT);

            /* Our extension set */
            exts = new Peas.ExtensionSet.with_properties (
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

        void on_extension_foreach (Peas.ExtensionSet exts, Peas.PluginInfo info, Object ext, void* data) {
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

            var index = 0;
            while (index < engine.get_n_items ()) {
                var info = (Peas.PluginInfo) engine.get_item (index);
                var row = new Gtk.ListBoxRow () {
                    margin_start = 6,
                    margin_end = 6
                };
                var content = new Gtk.Box (HORIZONTAL, 6);
                var checkbox = new Gtk.CheckButton () {
                    valign = Gtk.Align.CENTER
                };
                var image = new Gtk.Image.from_icon_name (info.get_icon_name (), MENU) {
                    valign = Gtk.Align.CENTER
                };
                var description_box = new Gtk.Box (VERTICAL, 0);
                var name_label = new Granite.HeaderLabel (info.name);
                //TODO In Granite-7 we can use secondary text property but emulate for now
                var description_label = new Gtk.Label (info.get_description ()) {
                    use_markup = true,
                    wrap = true,
                    xalign = 0,
                    margin_start = 6
                };
                description_label.get_style_context ().add_class (Granite.STYLE_CLASS_SMALL_LABEL);
                description_label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);
                description_box.add (name_label);
                description_box.add (description_label);
                content.add (name_label);
                content.add (checkbox);
                content.add (image);
                content.add (description_box);
                row.child = content;
                list_box.add (row);
                index++;
            }

            frame.show_all ();
            return frame;
        }

        public uint get_n_plugins () {
            return engine.get_n_items ();
        }
    }
}
