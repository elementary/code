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

public interface Code.Plugin : GLib.Object {
    public abstract unowned Code.Editor editor { get; construct; }
    public abstract void activate ();
    public abstract void deactivate ();
}

namespace Scratch.Services {
    public class PluginsManager : GLib.Object {
        // Signals
        public signal void extension_added (Peas.PluginInfo info);
        public signal void extension_removed (Peas.PluginInfo info);

        public PluginsManager (Code.Editor editor) {
            /* Let's init the engine */
            var engine = Peas.Engine.get_default ();
            engine.enable_loader ("python");
            engine.add_search_path (Constants.PLUGINDIR, null);

            Scratch.settings.schema.bind("plugins-enabled", engine, "loaded-plugins", SettingsBindFlags.DEFAULT);

            /* Our extension set */
            var exts = new Peas.ExtensionSet (engine, typeof (Code.Plugin), "editor", editor, null);

            exts.extension_added.connect ((info, ext) => {  
                ((Code.Plugin) ext).activate ();
                extension_added (info);
            });

            exts.extension_removed.connect ((info, ext) => {
                ((Code.Plugin) ext).deactivate ();
                extension_removed (info);
            });

            exts.foreach (on_extension_foreach);
        }

        void on_extension_foreach (Peas.ExtensionSet set, Peas.PluginInfo info, Peas.Extension extension) {
            ((Code.Plugin) extension).activate ();
        }

        public Gtk.Widget get_view () {
            var view = new PeasGtk.PluginManager (Peas.Engine.get_default ());
            var bottom_box = view.get_children ().nth_data (1);
            bottom_box.no_show_all = true;
            return view;
        }
    }
}
