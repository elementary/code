// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/***
  BEGIN LICENSE
  Copyright (C) 2024 elementary, Inc. <https://elementary.io>
                2011-2012 Giulio Collura <random.cpp@gmail.com>
                
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



public class Scratch.Plugins.Pastebin : Scratch.Plugins.PluginBase {
    GLib.MenuItem? menuitem = null;
    GLib.Menu? share_menu = null;
    // public Object object { owned get; construct; }

    Scratch.Services.Document? doc = null;

    const string ACTION_GROUP = "pastebin";
    const string ACTION_PREFIX = ACTION_GROUP + ".";
    const string ACTION_SHOW = "action-show";
    SimpleActionGroup actions;

    const ActionEntry[] ACTION_ENTRIES = {
        {ACTION_SHOW, show_paste_bin_upload_dialog }
    };

    public Pastebin (PluginInfo info, Interface iface) {
        base (info, iface);
    }

    ulong doc_hook_handler = 0;
    ulong menu_hook_handler = 0;
    protected override void activate_internal () {
        doc_hook_handler = iface.hook_document.connect ((doc) => {
            this.doc = doc;
        });

        menu_hook_handler = iface.hook_share_menu.connect (on_hook_share_menu);
    }

    protected override void deactivate_internal () {
        remove_actions ();
        this.disconnect (menu_hook_handler);
        this.disconnect (doc_hook_handler);
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

        iface.manager.window.insert_action_group (ACTION_GROUP, actions);
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

        iface.manager.window.insert_action_group (ACTION_GROUP, null);
    }

    void show_paste_bin_upload_dialog () {
        MainWindow window = iface.manager.window;
        new Dialogs.PasteBinDialog (window, doc);
    }
}

public Scratch.Plugins.PluginBase module_init (
    Scratch.Plugins.PluginInfo info,
    Scratch.Plugins.Interface iface
) {
    return new Scratch.Plugins.Pastebin (info, iface);
}
