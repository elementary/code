// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/***
  BEGIN LICENSE
  
  Copyright (C) 2013 Mario Guerriero <mefrio.g@gmail.com>
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

    public class Interface : GLib.Object {
        
        private PluginsManager manager;
        
        public Gtk.Notebook context {internal set; get; }
        public Gtk.Notebook sidebar {internal set; get; }
        public Gtk.Notebook bottombar {internal set; get; }
        public Scratch.ScratchApp scratch_app {internal set; get; }
        public Gtk.Menu main_menu {private set; get; }
        public Gtk.Menu addons_menu {private set; get; }
        public Gtk.Toolbar toolbar {internal set; get; }
        public Gtk.Toolbar statusbar {internal set; get; }
        public Gtk.Window window {private set; get; }
        public string set_name {internal set; get; }
        
        //public Scratch.TemplateManager template_manager { private set; get; }
        
        public Interface (PluginsManager manager) {
            this.manager = manager;
        }    
    }


    public class PluginsManager : GLib.Object {
        
        public signal void hook_main_menu (Gtk.Menu menu);
        public signal void hook_toolbar ();
        public signal void hook_statusbar ();
        public signal void hook_set_arg (string set_name, string? set_arg);
        public signal void hook_notebook_bottom (Gtk.Notebook notebook);
        public signal void hook_source_view(Gtk.TextView view);
        public signal void hook_new_window(Gtk.Window window);
        public signal void hook_preferences_dialog(Gtk.Dialog dialog);
        public signal void hook_toolbar_context_menu(Gtk.Menu menu);

        Peas.Engine engine;
        Peas.ExtensionSet exts;
        
        Peas.Engine engine_core;
        Peas.ExtensionSet exts_core;
        
        public Gtk.Toolbar toolbar { set { plugin_iface.toolbar = value; } }
        public Gtk.Toolbar statusbar { set { plugin_iface.statusbar = value; } }
        public Scratch.ScratchApp scratch_app { set { plugin_iface.scratch_app = value;  }}

        GLib.Settings settings;
        string settings_field;
        
        public Interface plugin_iface { private set; public get; }

        public PluginsManager (ScratchApp app, string? set_name = null) {
            settings = Scratch.settings.schema;
            settings_field = "plugins-enabled";

            plugin_iface = new Interface (this);
            plugin_iface.set_name = set_name ?? "Scratch";

            /* Let's init the engine */
            engine = Peas.Engine.get_default ();
            engine.enable_loader ("python");
            engine.enable_loader ("gjs");
            engine.add_search_path (Constants.PLUGINDIR, null);
            settings.bind("plugins-enabled", engine, "loaded-plugins", SettingsBindFlags.DEFAULT);
            
            /* Our extension set */
            Parameter param = Parameter ();
            param.value = plugin_iface;
            param.name = "object";
            exts = new Peas.ExtensionSet (engine, typeof (Peas.Activatable), "object", plugin_iface, null);

            exts.extension_added.connect( (info, ext) => {  
                ((Peas.Activatable)ext).activate();
            });
            exts.extension_removed.connect(on_extension_removed);
            exts.foreach (on_extension_added);
            
            if (set_name != null) {
                /* The core now */
                engine_core = new Peas.Engine ();
                engine_core.enable_loader ("python");
                engine_core.enable_loader ("gjs");
                engine_core.add_search_path (Constants.PLUGINDIR + "/" + set_name + "/", null);

                var core_list = engine_core.get_plugin_list ().copy ();
                string[] core_plugins = new string[core_list.length()];
                for (int i = 0; i < core_list.length(); i++) {
                    core_plugins[i] = core_list.nth_data (i).get_module_name ();
                    
                }
                engine_core.loaded_plugins = core_plugins;

                /* Our extension set */
                exts_core = new Peas.ExtensionSet (engine_core, typeof(Peas.Activatable), "object", plugin_iface, null);

                exts_core.foreach (on_extension_added);
            }
        }
        
        void on_extension_added (Peas.ExtensionSet set, Peas.PluginInfo info, Peas.Extension extension) {
            ((Peas.Activatable)extension).activate ();
        }
        void on_extension_removed (Peas.PluginInfo info, Object extension) {
            ((Peas.Activatable)extension).deactivate ();
        }
        
        public Gtk.Widget get_view () {
            var view = new PeasGtk.PluginManager (engine);
            var bottom_box = view.get_children ().nth_data (1) as Gtk.Box;
            bottom_box.remove (bottom_box.get_children ().nth_data(0));
            
            view.view.populate_popup.connect ((menu) => {
                foreach (Gtk.Widget item in menu.get_children ()) {
                    menu.remove (item);
                    if (((Gtk.MenuItem)item).get_label () == "gtk-about") {
                        ((Gtk.MenuItem)item).destroy ();
                    }
                    else if (((Gtk.MenuItem)item).get_label () == "gtk-preferences") {
                        menu.remove (item);
                    }
                    else if (((Gtk.MenuItem)item) is Gtk.SeparatorMenuItem) {
                        var sep = new Gtk.SeparatorMenuItem ();
                        menu.append (sep);
                    }
                    else {
                        menu.append (((Gtk.MenuItem)item));
                    }
                }
            });
            return view;
        }
    }
}
