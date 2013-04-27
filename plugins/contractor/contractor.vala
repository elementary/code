// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/***
  BEGIN LICENSE
	
  Copyright (C) 2011-2013 Mario Guerriero <mario@elementaryos.org>
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

public class Scratch.Plugins.ContractMenuItem : Gtk.MenuItem {
    private Granite.Services.Contract contract;
    private File file;

    public ContractMenuItem (Granite.Services.Contract contract, File file) {
        this.contract = contract;
        this.file = file;

        label = contract.get_display_name ();
        tooltip_text = contract.get_description ();
    }

    public override void activate () {
        try {
            contract.execute_with_file (file);
        } catch (Error err) {
            warning (err.message);
        }
    }
}

public class Scratch.Plugins.Contractor : Peas.ExtensionBase,  Peas.Activatable {
    Scratch.Services.Interface plugins;
    GLib.List<Gtk.Widget>? list = null;

    [NoAcessorMethod]
    public Object object { owned get; construct; }
   
    public void update_state () {
    }

    public void activate () {
        plugins = (Scratch.Services.Interface) object;        
        
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
            // Remove old contracts
            this.list.foreach ((item) => { if (item != null) item.destroy (); });
            
            if (doc.file == null)
                return;

            // Create ContractorMenu widget
            Gee.List<Granite.Services.Contract> contracts = null;
            try {
                contracts = Granite.Services.ContractorProxy.get_contracts_by_mime ("text/plain");
            } catch (Error e) {
                warning (e.message);
            }
            
            for (int i = 0; i < contracts.size; i++) {
                var contract = contracts.get (i);
                Gtk.MenuItem menu_item;

                menu_item = new ContractMenuItem (contract, doc.file);
                menu.append (menu_item);
                this.list.append (menu_item);
            }

        });
    }
    
}

[ModuleInit]
public void peas_register_types (GLib.TypeModule module) {
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type (typeof (Peas.Activatable),
                                     typeof (Scratch.Plugins.Contractor));
}
