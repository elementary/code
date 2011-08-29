// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/***
  BEGIN LICENSE
	
  Copyright (C) 2011 Giulio Collura <random.cpp@gmail.com>
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


			string api_url = "http://pastebin.com/api_public.php";
	
			var session = new SessionSync ();
			var message = new Message ("POST", api_url);
            
			string request = Form.encode (
				"option", "paste",
				"paste_code", paste_code,
				"paste_name", paste_name,
				"paste_private", paste_private,
				"paste_expire_date", paste_expire_date,
				"paste_format", paste_format);
            
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

public class Scratch.Plugins.Pastebin : Scratch.Plugins.Base
{
    Gtk.MenuItem pastebin;
    ScratchApp scratch_app;
    public Pastebin()
    {
    }

    public override void app(Gtk.Application app_)
    {
        this.scratch_app = app_ as ScratchApp;
    }

    public override void example(string text)
    {
        print("Why do you want me to say \"%s\"?\n", text);
    }

    public override void addons_menu(Gtk.Menu menu)
    {
            pastebin = new Gtk.MenuItem.with_label (_("Upload to Pastebin..."));
            menu.append (pastebin);
            pastebin.activate.connect (() => {
				new Dialogs.PasteBinDialog (scratch_app.window);
            });

    }
}

public Scratch.Plugins.Base module_init()
{
    return new Scratch.Plugins.Pastebin();
}
