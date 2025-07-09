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

            link = null;
            if (paste_code.length == 0) { link = "No text to paste"; return false; }

            string api_url = "https://pastebin.com/api/api_post.php";

            var session = new Soup.Session ();
            var message = new Soup.Message ("POST", api_url);

            string request = Soup.Form.encode (
                "api_option", "paste",
                "api_dev_key", "67480801fa55fc0977f7561cf650a339",
                "api_paste_code", paste_code,
                "api_paste_name", paste_name,
                "api_paste_private", paste_private,
                "api_paste_expire_date", paste_expire_date,
                "api_paste_format", paste_format);

            message.set_request_body_from_bytes ("application/x-www-form-urlencoded", new Bytes (request.data));
            message.set_flags (Soup.MessageFlags.NO_REDIRECT);

            Bytes output;
            try {
                output = session.send_and_read (message);
            } catch (Error e) {
                return false;
            }


            var output_s = (string) output.get_data ();
            link = output_s;

            if (Uri.parse_scheme (output_s) == null || message.status_code != 200) {
                // A URI was not returned
                return false;
            }

            return true;
        }
    }
}

public class Scratch.Plugins.Pastebin : Peas.ExtensionBase, Scratch.Services.ActivatablePlugin {
    GLib.MenuItem? menuitem = null;
    GLib.Menu? share_menu = null;
    public Object object { owned get; set construct; }

    Scratch.Services.Document? doc = null;
    Scratch.Services.Interface plugins;

    const string ACTION_GROUP = "pastebin";
    const string ACTION_PREFIX = ACTION_GROUP + ".";
    const string ACTION_SHOW = "action-show";
    SimpleActionGroup actions;

    const ActionEntry[] ACTION_ENTRIES = {
        {ACTION_SHOW, show_paste_bin_upload_dialog }
    };

    public void update_state () {
    }

    public void activate () {
        plugins = (Scratch.Services.Interface) object;

        plugins.hook_document.connect ((doc) => {
            this.doc = doc;
        });

        plugins.hook_share_menu.connect (on_hook_share_menu);
    }

    void on_hook_share_menu (GLib.MenuModel menu) {
        if (menuitem != null) {
            return;
        }

        add_actions (menu);
    }

    void add_actions (GLib.MenuModel menu) {
        if (actions == null) {
            actions = new SimpleActionGroup ();
            actions.add_action_entries (ACTION_ENTRIES, this);
        }

        plugins.manager.window.insert_action_group (ACTION_GROUP, actions);
        share_menu = (GLib.Menu) menu;
        menuitem = new GLib.MenuItem (_("Upload to Pastebin"), ACTION_PREFIX + ACTION_SHOW);
        share_menu.append_item (menuitem);
    }

    void remove_actions () {
        int length = share_menu.get_n_items ();
        for (var i = length - 1; i >= 0; i--) {
            var action_name = share_menu.get_item_attribute_value (
                i,
                GLib.Menu.ATTRIBUTE_ACTION,
                GLib.VariantType.STRING
            ).get_string ();
            if (action_name.has_prefix (ACTION_PREFIX)) {
                share_menu.remove (i);
            }
        }

        plugins.manager.window.insert_action_group (ACTION_GROUP, null);
    }

    void show_paste_bin_upload_dialog () {
        MainWindow window = plugins.manager.window;
        new Dialogs.PasteBinDialog (window, doc);
    }

    public void deactivate () {
        remove_actions ();
    }
}

[ModuleInit]
public void peas_register_types (GLib.TypeModule module) {
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type (typeof (Scratch.Services.ActivatablePlugin),
                                     typeof (Scratch.Plugins.Pastebin));
}
