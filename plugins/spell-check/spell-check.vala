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

public class Scratch.Plugins.SpellCheck : Peas.ExtensionBase,  Peas.Activatable
{

    string lang;   
      
    Interface plugins;
    public Object object { owned get; construct; }
   
    public void update_state () {
    }

    public void activate () {
        // Delete encoding string
        string lang_enc = GLib.Environment.get_variable ("$LANG");
        string[] s_lang = lang_enc.split (".");
        for (int n=0; n<=s_lang.length-1; n++)
            lang += s_lang[n];
        
        // Now the plugin itself
        plugins = (Scratch.Plugins.Interface)object;
        plugins.register_function_arg (Scratch.Plugins.Interface.Hook.SOURCE_VIEW, on_new_source_view);
    }

    public void deactivate () {

    }
    
    public void on_new_source_view (Object obj) {
        var view = obj as Gtk.TextView;
        try {
            var spell = new Gtk.Spell.attach (view, lang);   
        } catch (Error e) {
            warning (e.message);
        }
    }

}

[ModuleInit]
public void peas_register_types (GLib.TypeModule module) {
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type (typeof (Peas.Activatable),
                                     typeof (Scratch.Plugins.SpellCheck));
}
