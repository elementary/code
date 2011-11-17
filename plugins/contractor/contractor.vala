// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/***
  BEGIN LICENSE
	
  Copyright (C) 2011 Mario Guerriero <mefrio.g@gmail.com>
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


public class Scratch.Plugins.Contractor : Scratch.Plugins.Base
{
    Gtk.MenuItem contractor;
    ScratchApp scratch_app;
    List<Gtk.MenuItem>? list = null;
    public Contractor()
    {
    }

    public override void app(Gtk.Application app_)
    {
        this.scratch_app = app_ as ScratchApp;
        Scratch.plugins.hook_new_window.connect( () => {
            scratch_app.window.split_view.page_changed.connect(on_page_changed);
        });
    }
    
    Gtk.Menu share_menu;
    
    void on_page_changed()
    {
        if(list != null)
            foreach(var w in list)
                w.destroy();
        list  = new List<Gtk.MenuItem>();
        foreach(var contract in Granite.Services.Contractor.get_contract("file:///" + scratch_app.window.current_document.filename, "text/plain"))
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
            share_menu.append (menuitem);
            share_menu.show_all ();
            list.append(menuitem);
        }
    }

    public override void addons_menu(Gtk.Menu menu)
    {
        this.share_menu = menu;
    }
}

public Scratch.Plugins.Base module_init()
{
    return new Scratch.Plugins.Contractor();
}
