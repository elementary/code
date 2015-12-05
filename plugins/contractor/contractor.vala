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

public const string DESCRIPTION = _("Share your files with Contractor");

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
    Gee.TreeSet<Gtk.Widget> list;

    public Object object { owned get; construct; }
    Scratch.Services.Interface plugins;

    construct {
        list = new Gee.TreeSet<Gtk.Widget> ();
    }

    public void update_state () {
    }

    public void activate () {
        plugins = (Scratch.Services.Interface) object;
        plugins.hook_share_menu.connect (on_hook);
    }
    
    public void deactivate () {
        foreach (var item in list) {
            var parent = item.get_parent ();
            if (parent != null) {
                parent.remove (item);
            }
        }

        list.clear ();
    }
    
    private void on_hook (Gtk.Menu menu) {
        plugins.hook_document.connect ((doc) => {
            // Remove old contracts
            foreach (var item in list) {
                var parent = item.get_parent ();
                if (parent != null) {
                    parent.remove (item);
                }
            }

            list.clear ();
            if (doc.file == null)
                return;

            // Create ContractorMenu widget
            try {
                var contracts = Granite.Services.ContractorProxy.get_contracts_by_mime (doc.get_mime_type ());
                foreach (var contract in contracts) {
                    var menu_item = new ContractMenuItem (contract, doc.file);
                    menu.append (menu_item);
                    menu_item.show_all ();
                    list.add (menu_item);
                }
            } catch (Error e) {
                warning (e.message);
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
