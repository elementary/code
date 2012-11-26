// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/***
  BEGIN LICENSE
	
  Copyright (C) 2011-2012 Giulio Collura <random.cpp@gmail.com>
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

using Soup;
 
namespace Scratch.Services {
 
    public class PasteBin : GLib.Object {

        public const int PASTE_ID_LEN = 8;

		public const string NEVER = "N";
		public const string TEN_MINUTES = "10M";
		public const string HOUR = "1H";
		public const string DAY = "1D";
		public const string MONTH = "1M";

		public const string PRIVATE = "1";
		public const string PUBLIC = "0";


		public static int submit (out string link, string paste_code, string paste_name, 
                                     string paste_private, string paste_expire_date, 
                                     string paste_format) {

            /* Code meaning:
            0 = it's all ok
            1 = generic error
            2 = text (paste_code) is empty
            3 = invalid file format
            ... maybe we should add and handle other errors...
            */

            //check input values
            if (paste_code.length == 0) {link=""; return 2; }


			string api_url = "http://pastebin.com/api/api_post.php";
	
			var session = new SessionSync ();
			var message = new Message ("POST", api_url);
            
			string request = Form.encode (
				"api_option", "paste",
				"api_dev_key", "67480801fa55fc0977f7561cf650a339",
				"api_paste_code", paste_code,
				"api_paste_name", paste_name,
				"api_paste_private", paste_private,
				"api_paste_expire_date", paste_expire_date,
				"api_paste_format", paste_format);
            
			message.set_request ("application/x-www-form-urlencoded", MemoryUse.COPY, request.data);
			message.set_flags (MessageFlags.NO_REDIRECT);
            
			session.send_message (message);

			var output = (string) message.response_body.data;

			//check return value
			if (output[0:6] != "ERROR:") {
			
                //we need only pastebin url len + id len
			    output = output[0:20+PASTE_ID_LEN];
    			debug(output);			    
			    
    			link = output;
                
			} else {

                //paste error

                link = "";				
                switch(output) {
                    case "ERROR: Invalid POST request, or \"paste_code\" value empty":
                    return 2;

                    case "ERROR: Invalid file format":
                    return 3;

                    default:
                    return 1;
                        
                }
	            
			}
			
            return 0;
			
		}
			 
    }
}

public class Scratch.Plugins.Pastebin : Peas.ExtensionBase, Peas.Activatable
{
    Interface plugins;
    Gtk.MenuItem? menuitem = null;
    
    [NoAcessorMethod]
    public Object object { owned get; construct; }
   
    public void update_state () {
    }

    public void activate () {
        Value value = Value(typeof(GLib.Object));
        get_property("object", ref value);
        plugins = (Scratch.Plugins.Interface)value.get_object();
        plugins.register_function(Interface.Hook.WINDOW, () => {
            ((MainWindow)plugins.window).split_view.page_changed.connect(on_page_changed);
        });
    }
    
    void on_page_changed () {
        if (plugins.addons_menu == null)
            return;
        
        if (menuitem != null)
            return;
        
        menuitem = new Gtk.MenuItem.with_label ("Upload to Pastebin");
        menuitem.activate.connect (() => {
		    new Dialogs.PasteBinDialog (((ScratchApp)plugins.scratch_app).window);
        });
        plugins.addons_menu.append (menuitem);
        plugins.addons_menu.show_all ();
    }
    
    public void deactivate () {
        menuitem.destroy ();
    } 
    
}

[ModuleInit]
public void peas_register_types (GLib.TypeModule module) {
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type (typeof (Peas.Activatable),
                                     typeof (Scratch.Plugins.Pastebin));
}
