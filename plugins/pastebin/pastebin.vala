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
		public const string NEVER = "N";
		public const string TEN_MINUTES = "10M";
		public const string HOUR = "1H";
		public const string DAY = "1D";
		public const string MONTH = "1M";

		public const string PRIVATE = "1";
		public const string PUBLIC = "0";


		public static bool submit (out string link, string paste_code, string paste_name,
                                     string paste_private, string paste_expire_date,
                                     string paste_format) {

            if (paste_code.length == 0) { link = "No text to paste"; return false; }

			string api_url = "http://pastebin.com/api/api_post.php";

			var session = new Session ();
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
		    link = output;
            
            if (Uri.parse_scheme (output) == null) {
                // A URI was not returned
                return false;
            }
            
            return true;
		}
    }
}

public class Scratch.Plugins.Pastebin : Peas.ExtensionBase, Peas.Activatable {
    Gtk.MenuItem? menuitem = null;

    [NoAcessorMethod]
    public Object object { owned get; construct; }
    Scratch.Services.Interface plugins;

    public void update_state () {
    }

    public void activate () {
        plugins = (Scratch.Services.Interface) object;

        plugins.hook_share_menu.connect (on_hook);
    }

    void on_hook (Gtk.Menu menu) {
        plugins.hook_document.connect ((doc) => {
            if (menuitem != null)
                menuitem.destroy ();
            menuitem = new Gtk.MenuItem.with_label (_("Upload to Pastebin"));
            menuitem.activate.connect (() => {
                MainWindow window = plugins.manager.window;
		        new Dialogs.PasteBinDialog (window, doc);
            });
            menu.append (menuitem);
            menuitem.show_all ();
        });
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
