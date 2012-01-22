/*
 * Copyright (C) 2011 Lucas Baudin <xapantu@gmail.com>
 *
 * Author: Zeeshan Ali (Khattak) <zeeshanak@gnome.org> (from Rygel)
 *
 * This file is part of Marlin.
 *
 * Marlin is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 * 
 * Marlin is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See the GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License along
 * with this program.  If not, see <http://www.gnu.org/licenses/>.
 */


public class Scratch.Plugins.Interface : Object {
    Manager manager;

    public enum Hook {
        SIDEBAR
    }

    public delegate void HookFunction ();

    public Gtk.Notebook sidebar { set; get; }
    public Gtk.Application scratch_app { set; get; }

    public Interface (Manager manager) {
        this.manager = manager;
    }
    
    public void register_function (Hook hook, HookFunction hook_function) {
        switch(hook) {
        case Hook.SIDEBAR:
            manager.hook_notebook_sidebar.connect (() => { hook_function(); });
            if (sidebar != null) {
                hook_function ();
            }
            break;
        }
    }
    
}


public class Scratch.Plugins.Manager : Object
{
    public signal void hook_main_menu (Gtk.Menu menu);
    public signal void hook_toolbar ();
    public signal void hook_set_arg (string set_name, string? set_arg);
    public signal void hook_notebook_bottom (Gtk.Notebook notebook);
    public signal void hook_source_view(Gtk.TextView view);
    public signal void hook_new_window(Gtk.Window window);
    public signal void hook_preferences_dialog(Gtk.Dialog dialog);
    public signal void hook_toolbar_context_menu(Gtk.Menu menu);

    Peas.Engine engine;
    Peas.ExtensionSet exts;
        
    public Gtk.Toolbar toolbar {get; set; }
    public Gtk.Application scratch_app { set { plugin_iface.scratch_app = value;  }}
    [CCode (cheader_filename = "libpeas/libpeas.h", cname = "peas_extension_set_foreach")]
    extern static void peas_extension_set_foreach (Peas.ExtensionSet extset, Peas.ExtensionSetForeachFunc option, void* data);

    Settings settings;
    string settings_field;

    Scratch.Plugins.Interface plugin_iface;

    public Manager(Settings s, string f, string d, string? e = null)
    {
        settings = s;
        settings_field = f;
        e = e == "scratch" ? null : e;

        plugin_iface = new Scratch.Plugins.Interface (this);

        /* Let's init the engine */
        engine = Peas.Engine.get_default ();
        engine.enable_loader ("python");
        engine.enable_loader ("gjs");
        engine.add_search_path (d, null);
        engine.loaded_plugins = settings.get_strv(settings_field);
        settings.bind("plugins-enabled", engine, "loaded-plugins", SettingsBindFlags.DEFAULT);

        /* Our extension set */
        exts = new Peas.ExtensionSet (engine, typeof(Peas.Activatable), "object", plugin_iface);

        exts.extension_added.connect(on_extension_added);
        exts.extension_removed.connect(on_extension_removed);
        peas_extension_set_foreach(exts, on_extension_added, null);
    }

    public Gtk.Widget get_view () {
        return new PeasGtk.PluginManager (engine);
    }

    void on_extension_added(Peas.PluginInfo info, Object extension) {
        ((Peas.Activatable)extension).activate();
    }
    void on_extension_removed(Peas.PluginInfo info, Object extension) {
        ((Peas.Activatable)extension).deactivate();
    }
    
    public void hook_app(Gtk.Application menu)
    {
    }
    
    public Gtk.Notebook sidebar { set { plugin_iface.sidebar = value; } }
    public signal void hook_notebook_sidebar (); 
    
    public void hook_notebook_context(Gtk.Notebook menu)
    {
    }
    
    public void hook_addons_menu(Gtk.Menu menu)
    {
    }
    
    public void hook_example(string arg)
    {
    }
}
public abstract class Scratch.Plugins.Base : GLib.Object
{    
    public virtual void example(string arg) { }
    public virtual void addons_menu(Gtk.Menu arg) { }
    public virtual void app(Gtk.Application app) { }
    public virtual void notebook_context(Gtk.Notebook note) { }
    public virtual void notebook_bottom(Gtk.Notebook note) { }
    public virtual void notebook_sidebar(Gtk.Notebook note) { }
    public virtual void source_view(Gtk.TextView view) { }
    public virtual void main_menu(Gtk.Menu app_menu) { }
    public virtual void toolbar(Gtk.Toolbar toolbar) { }
    public virtual void set_arg(string project_name, string? arg_set) { }
}

