/*-
 * Copyright (c) 2018 elementary LLC. (https://elementary.io)
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Authored by: David Hewitt <davidmhewitt@gmail.com>
 */

public const string NAME = _("Toggle Code Comments");
public const string DESCRIPTION = _("Add/remove comments with Ctrl+M and Ctrl+Shift+M");

public class Scratch.Plugins.ToggleCodeComments: Peas.ExtensionBase, Peas.Activatable {

    Scratch.Services.Interface plugins;
    public Object object {owned get; construct;}
    Scratch.MainWindow main_window;
    public void update_state () {return;}

    /*
     * Activate plugin.
     */
    public void activate () {
        plugins = (Scratch.Services.Interface) object;
        plugins.hook_window.connect ((w) => {
            this.main_window = w;
        });
    }

    /*
     * Deactivate plugin.
     */
    public void deactivate () {
    }
}

[ModuleInit]
public void peas_register_types (GLib.TypeModule module) {
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type(typeof(Peas.Activatable),
                                      typeof(Scratch.Plugins.ToggleCodeComments));
}
