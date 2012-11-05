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

using WebKit;

public class Scratch.Plugins.BrowserPreview : Peas.ExtensionBase,  Peas.Activatable
{
    Interface plugins;
    public Object object { owned get; construct; }
   
    Gtk.ToolButton tool_button;
    WebView view;
    
    public void update_state () {
    }

    public void activate () {
        plugins = (Scratch.Plugins.Interface)object;        
        plugins.register_function(Interface.Hook.TOOLBAR, on_toolbar);
        // Don't use it for the moment
        plugins.register_function(Interface.Hook.CONTEXT, on_context);
    }

    public void deactivate () {
        if (tool_button != null)
            tool_button.destroy ();
        
        if (view != null)
            view.destroy ();
    }
    
    void on_toolbar () {
        if (plugins.toolbar != null && plugins.scratch_app != null) {
            
            var icon = new Gtk.Image.from_icon_name ("emblem-web", Gtk.IconSize.LARGE_TOOLBAR);
            tool_button = new Gtk.ToolButton (icon, _("Get preview!"));
            tool_button.tooltip_text = _("Get preview!");
            tool_button.clicked.connect (() => {              
                // Get uri
                string uri;
                var doc = ((Scratch.ScratchApp)plugins.scratch_app).window.current_document;
                if (doc == null)
                    return;
                uri = doc.filename;
                
                debug ("Previewing: " + doc.file.get_basename ());
                
                view.load_uri (uri);
            });
            
            // Unset button sensitive when it is not usefull
            ((Scratch.ScratchApp)plugins.scratch_app).window.welcome_state_change.connect ((state) => {
                bool val = (state == Scratch.Widgets.ScratchWelcomeState.SHOW == true);
                tool_button.set_sensitive (val);
            });
            
            icon.show ();
            tool_button.show ();
            
            plugins.toolbar.insert (tool_button, -1);
        }
    }
    
    void on_context () {
    	if (plugins.context != null && plugins.scratch_app != null) {

    	    view = new WebView ();
    	    // Enable local loading
    	    var settings = view.get_settings ();
    	    settings.enable_file_access_from_file_uris = true;
    	    
    	    var scrolled = new Gtk.ScrolledWindow (null, null);
    	    scrolled.add (view);
    	    
    	    view.show ();
    	    scrolled.show ();
    	    
    	    plugins.context.append_page (scrolled, new Gtk.Label (_("Web preview")));
        }
    }

}

[ModuleInit]
public void peas_register_types (GLib.TypeModule module) {
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type (typeof (Peas.Activatable),
                                     typeof (Scratch.Plugins.BrowserPreview));
}
