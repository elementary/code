// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/***
  BEGIN LICENSE
	
  Copyright (C) 2011-2012 Mario Guerriero <mefrio.g@gmail.com>
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


public class Scratch.Plugins.Contractor : Peas.ExtensionBase,  Peas.Activatable
{
    Interface plugins;
    List<Gtk.MenuItem>? list = null;

    public Object object { owned get; construct; }
   
    public void update_state () {
    }

    public void activate () {
        plugins = (Scratch.Plugins.Interface)object;
        plugins.register_function(Interface.Hook.WINDOW, () => {
            ((MainWindow)plugins.window).split_view.page_changed.connect(on_page_changed);
        });
    }

    public void deactivate () {
        if (list != null)
            foreach (var w in list)
                w.destroy ();
    }
    
    void on_page_changed()
    {
        if(plugins.addons_menu == null)
            return;
        if(list != null)
            foreach(var w in list)
                w.destroy();
        list  = new List<Gtk.MenuItem>();

        foreach(var contract in Granite.Services.Contractor.get_contract("file:///" + ((ScratchApp)plugins.scratch_app).window.current_tab.filename, "text/plain"))
        {
            var menuitem = new Gtk.MenuItem.with_label (contract["Description"]);
            string exec = contract["Exec"];
            menuitem.activate.connect( () => {
                try {
                    GLib.Process.spawn_command_line_async(exec);
                } catch (SpawnError e) {
                    stderr.printf ("error spawn command line %s: %s", exec, e.message);
                }
            });
            plugins.addons_menu.append (menuitem);
            plugins.addons_menu.show_all ();
            list.append(menuitem);
        }
    }
}

[ModuleInit]
public void peas_register_types (GLib.TypeModule module) {
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type (typeof (Peas.Activatable),
                                     typeof (Scratch.Plugins.Contractor));
}
