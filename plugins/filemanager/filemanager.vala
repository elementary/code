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

public class Euclide.Plugins.FM : Peas.ExtensionBase, Peas.Activatable {
    
    Gtk.Notebook? sidebar = null;
    PluginView view;
    
    Scratch.Services.Interface plugins;
    public Object object { owned get; construct; }

    public FM () {
    }
    
    public void activate () {
        plugins = (Scratch.Services.Interface) object;        
        plugins.hook_notebook_sidebar.connect ((n) => { 
            if (sidebar == null) {
                this.sidebar = n;
                on_hook (this.sidebar);
            }
        });
        if (sidebar != null)
            on_hook (this.sidebar);
    }

    public void deactivate () {
        if (view != null)
            view.destroy();
    }

    public void update_state () {
    }
    
    void on_hook (Gtk.Notebook notebook) {
        view = new PluginView ();
        view.select.connect ((a) => { 
            var file = File.new_for_uri (a.location.get_uri ());
            plugins.open_file (file);
        });
        
        notebook.append_page (view, new Gtk.Label (_("Files")));

        view.show_all ();
    }

}

[ModuleInit]
public void peas_register_types (GLib.TypeModule module) {
  var objmodule = module as Peas.ObjectModule;
  objmodule.register_extension_type (typeof (Peas.Activatable),
                                     typeof (Euclide.Plugins.FM));
}
