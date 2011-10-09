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

public class Scratch.Plugins.BaseManager : GLib.Object
{
    delegate Base ModuleInitFunc ();
    internal Gee.HashMap<string,Base> plugin_hash;
    Settings settings;
    string settings_field;
    string plugin_dir;
    List<string> names = null;
    bool in_available = false;
    string? extra_dir;
    public BaseManager(Settings settings, string field, string plugin_dir, string? extra_dir)
    {
        settings_field = field;
        this.settings = settings;
        this.plugin_dir = plugin_dir;
        this.extra_dir = extra_dir;
        plugin_hash = new Gee.HashMap<string,Base>();
        load_plugins();
    }
    
    public void load_plugins()
    {
        load_modules_from_dir(plugin_dir + "/core/", true);
        load_modules_from_dir(plugin_dir);
        if(extra_dir != null) load_modules_from_dir(plugin_dir + "/" + extra_dir, true);
    } 
    
    private void load_modules_from_dir (string path, bool force = false)
    {
        File dir = File.new_for_path(path);

        string attributes = FILE_ATTRIBUTE_STANDARD_NAME + "," +
                            FILE_ATTRIBUTE_STANDARD_TYPE + "," +
                            FILE_ATTRIBUTE_STANDARD_CONTENT_TYPE;

        FileInfo info;
        FileEnumerator enumerator;

        try
        {
            enumerator = dir.enumerate_children
                                        (attributes,
                                         FileQueryInfoFlags.NONE);

            info = enumerator.next_file ();
        }
        catch(Error error)
        {
            warning("Error listing contents of folder '%s': %s",
                      dir.get_path (),
                      error.message);

            return;
        }

        while(info != null)
        {
            string file_name = info.get_name ();
            string file_path = Path.build_filename (dir.get_path (), file_name);

            File file = File.new_for_path (file_path);

            if(file_name.has_suffix(".plug"))
            {
                load_plugin_keyfile(file_path, dir.get_path (), force);
            }
            info = enumerator.next_file ();
        }
    }

    Base? load_module(string file_path)
    {
        Module module = Module.open (file_path, ModuleFlags.BIND_LOCAL);
        if (module == null)
        {
            warning ("Failed to load module from path '%s': %s",
                     file_path,
                     Module.error ());
            return null;
        }

        void* function;

        if (!module.symbol("module_init", out function)) {
            warning ("Failed to find entry point function '%s' in '%s': %s",
                     "module_init",
                     file_path,
                     Module.error ());
            return null;
        }

        ModuleInitFunc module_init = (ModuleInitFunc) function;
        assert (module_init != null);

        /* We don't want our modules to ever unload */
        module.make_resident ();
        Plugins.Base plug = module_init();

        debug ("Loaded module source: '%s'", module.name());

        Base base_ = module_init();
        return base_;
    }
    
    public virtual void connect_signals(Base base_) {
    }
    
    void load_plugin_keyfile(string path, string parent, bool force)
    {
        var keyfile = new KeyFile();
        try
        {
            keyfile.load_from_file(path, KeyFileFlags.NONE);
            string name = keyfile.get_string("Plugin", "Name");
            if(in_available)
            {
                names.append(name);
            }
            else if(force || name in settings.get_strv(settings_field))
            {
                Base plug = load_module(Path.build_filename(parent, keyfile.get_string("Plugin", "File")));
                if(plug != null)
                {
                    connect_signals(plug);
                    plugin_hash[name] = plug;
                }
            }
        }
        catch(Error e)
        {
            warning("Couldn't open thie keyfile: %s, %s", path, e.message);
        }
    }
    
    public void add_plugin(string path)
    {
    }
    
    public void load_plugin(string path)
    {
    }
    
    public List<string> get_available_plugins()
    {
        names = new List<string>();
        in_available = true;
        load_modules_from_dir(plugin_dir, false);
        in_available = false;
        return names.copy();
    }
    
    public bool disable_plugin(string path)
    {
        string[] plugs = settings.get_strv(settings_field);
        string[] plugs_ = new string[plugs.length - 1];
        bool found = false;
        int i = 0;
        foreach(var name in plugs)
        {
            if(name != path)
            {
                plugs[i] = name;
            }
            else found = true;
            i++;
        }
        if(found) settings.set_strv(settings_field, plugs_);
        return found;
    }
}

public class Scratch.Plugins.Manager : Scratch.Plugins.BaseManager
{
    public signal void hook_main_menu (Gtk.Menu menu);
    public signal void hook_toolbar (Gtk.Toolbar menu);
    public Manager(Settings s, string f, string d, string? e = null)
    {
        e = e == "scratch" ? null : e;
        base(s, f, d, e);
    }

    public override void connect_signals(Base base_) {
        hook_main_menu.connect(base_.main_menu);
        hook_toolbar.connect(base_.toolbar);
        hook_source_view.connect(base_.source_view);
    }
    
    public void hook_app(Gtk.Application menu)
    {
        foreach(var plugin in plugin_hash.values) plugin.app(menu);
    }
    
    public void hook_notebook_sidebar(Gtk.Notebook menu) 
    {
        foreach(var plugin in plugin_hash.values) plugin.notebook_sidebar(menu);
    }
    
    public signal void hook_source_view(Gtk.TextView view);
    
    public void hook_notebook_context(Gtk.Notebook menu)
    {
        foreach(var plugin in plugin_hash.values) plugin.notebook_context(menu);
    }
    
    public void hook_addons_menu(Gtk.Menu menu)
    {
        foreach(var plugin in plugin_hash.values) plugin.addons_menu(menu);
    }
    
    public void hook_example(string arg)
    {
        foreach(var plugin in plugin_hash.values) plugin.example(arg);
    }
    
}
public abstract class Scratch.Plugins.Base : GLib.Object
{    
    public virtual void example(string arg) { }
    public virtual void addons_menu(Gtk.Menu arg) { }
    public virtual void app(Gtk.Application app) { }
    public virtual void notebook_context(Gtk.Notebook note) { }
    public virtual void notebook_sidebar(Gtk.Notebook note) { }
    public virtual void source_view(Gtk.TextView view) { }
    public virtual void main_menu(Gtk.Menu app_menu) { }
    public virtual void toolbar(Gtk.Toolbar toolbar) { }
}

