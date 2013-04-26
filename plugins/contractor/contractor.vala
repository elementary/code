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
    Scratch.Services.Interface plugins;
    GLib.List<Gtk.Widget>? list = null;

    [NoAcessorMethod]
    public Object object { owned get; construct; }
   
    public void update_state () {
    }

    public void activate () {
        Value value = Value (typeof (GLib.Object));
        get_property ("object", ref value);
        plugins = (Scratch.Services.Interface) value.get_object ();
        
        this.list = new List<Gtk.Widget> ();
        
        plugins.hook_share_menu.connect (on_hook);
    }
    
    public void deactivate () {
        if (list != null)
            foreach (var w in list)
                w.destroy ();
    }
    
    private void on_hook (Gtk.Menu menu) {
        plugins.hook_document.connect ((doc) => {
            if (doc.file == null)
                return;
            debug ("Loading Contracts for file: \"%s\"", doc.get_basename ());
            // Remove old contracts
            this.list.foreach ((item) => { if (item != null) item.destroy (); });
            // Create ContractorMenu widget
            var contractor = Granite.Services.Contractor.get_contract (doc.file.get_path (), "text/plain");
            foreach (var contract in contractor) {
                var item = new Gtk.MenuItem.with_label (contract.lookup ("Name"));
                item.activate.connect (() => {
                    try {
                        GLib.Process.spawn_command_line_async (contract.lookup ("Exec"));
                    } catch (SpawnError e) {
                        warning (e.message);
                    }
                });
                menu.append (item);
                this.list.append (item);
            }

            /*this.list = contractor.get_children ().copy ();

            // Append Contracts
            this.list.foreach ((item) => {
                if (item != null)
                    menu.append (item as Gtk.MenuItem);
            });*
            debug ("Loading Contracts for file: \"%s\"", doc.get_basename ());*/
        });
    }
    
}

[ModuleInit]
public void peas_register_types (GLib.TypeModule module) {
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type (typeof (Peas.Activatable),
                                     typeof (Scratch.Plugins.Contractor));
}
