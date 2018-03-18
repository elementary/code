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

public class Scratch.Plugins.OpenWith : Peas.ExtensionBase,  Peas.Activatable {
    Gtk.MenuItem? item = null;

    public Object object { owned get; construct; }
    Scratch.Services.Interface plugins;

    public void update_state () {

    }

    public void activate () {
        plugins = (Scratch.Services.Interface) object;
        plugins.hook_share_menu.connect (on_hook);
    }

    public void deactivate () {
        if (item != null)
            item.destroy ();
    }

    private void on_hook (Gtk.Menu menu) {
        plugins.hook_document.connect ((doc) => {
            // Remove old item
            if (item != null)
                item.destroy ();

            if (doc.file == null)
                return;

            // Create new item
            this.item = new Gtk.MenuItem.with_label (_("Open With…"));
            this.item.activate.connect (() => {
                var dialog = new Gtk.AppChooserDialog (new Gtk.Window (), Gtk.DialogFlags.MODAL, doc.file);
                if (dialog.run () == Gtk.ResponseType.OK) {
                    var info = dialog.get_app_info ();
                    if (info != null) {
                        var list = new GLib.List<File> ();
                        list.append (doc.file);
                        try {
                            info.launch (list, null);
                        } catch (Error e) {
                            warning (e.message);
                        }
                    }
                }

                dialog.destroy ();
            });
            menu.append (this.item);
            this.item.show_all ();
        });
    }

}

[ModuleInit]
public void peas_register_types (GLib.TypeModule module) {
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type (typeof (Peas.Activatable),
                                     typeof (Scratch.Plugins.OpenWith));
}
