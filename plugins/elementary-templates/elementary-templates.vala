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

public class Scratch.Plugins.Templates : Peas.ExtensionBase,  Peas.Activatable {

    [NoAcessorMethod]
    public Object object { owned get; construct; }
    Scratch.Services.Interface plugins;
    
    public void update_state () {
    }

    public void activate () {
        plugins = (Scratch.Services.Interface) object;        
        
        plugins.template_manager.register_template ("text-editor", "Granite Application", "Granite application template", typeof(Scratch.Templates.Granite));
    }
    
    public void deactivate () {

    }
    
}

[ModuleInit]
public void peas_register_types (GLib.TypeModule module) {
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type (typeof (Peas.Activatable),
                                     typeof (Scratch.Plugins.Templates));
}
