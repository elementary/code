/* gvls-sourceview.vala
 *
 * Copyright 2018 Daniel Espinosa <esodan@gmail.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

using Gee;
using GVls;

public class Scratch.Plugins.GVlsCompletion : Peas.ExtensionBase, Peas.Activatable {
  MainWindow main_window;
  private GVls.Server _server;
  private ulong cn = 0;
  private uint timeout_id = -1;

  public Object object { owned get; construct; }
  public Gtk.SourceView view { get; set; }
  Scratch.Services.Interface plugins;

  construct {
    _server = new GVls.GServer ();
    try {
      _server.add_default_vapi_dirs ();
      _server.add_default_namespaces ();
    } catch (GLib.Error e) {
      warning ("Initialization Error: %s", e.message);
    }
  }
  ~GVlsCompletion () {
    if (timeout_id != -1) {
      var source = MainContext.@default ().find_source_by_id (timeout_id);
      if (source != null) {
        source.destroy ();
      }
    }
  }

  public void activate () {
    plugins = (Scratch.Services.Interface) object;
    plugins.hook_window.connect ((w) => {
      this.main_window = w;
    });
    cn = plugins.hook_document.connect ((doc)=>{
      try {
        var view = doc.source_view;
        var prov = new GVlsui.CompletionProvider ();
        prov.server = _server;
        view.get_completion ().add_provider (prov);
        view.set_data<GVlsui.CompletionProvider> ("gvls-provider", prov);
        view.set_data<bool> ("gvls-view-dirty", true);
        var buf = view.get_buffer ();
        buf.insert_text.connect ((ref pos, ntext, tlen)=>{
          view.set_data<bool> ("gvls-view-dirty", true);
        });
      } catch (GLib.Error e) {
        warning ("Error setting completion provider: %s", e.message);
      }
      
    });
    timeout_id = GLib.Timeout.add (1, update_symbols);
  }
  public void deactivate () {
      plugins.disconnect (cn);
      var prov = view.get_data<GVlsui.CompletionProvider> ("gvls-provider");
      if (prov == null) return;
      view.get_completion ().remove_provider (prov);
  }
  public void update_state () {
  }

  private bool update_symbols () {
    if (view == null) return true;
    var prov = view.get_data<GVlsui.CompletionProvider> ("gvls-provider");
    if (prov == null) return true;
    bool dirty = view.get_data<bool> ("gvls-view-dirty");
    if (!dirty) return true;
    prov.current_server.content = view.get_buffer ().text;
    view.set_data<bool> ("gvls-view-dirty", false);
    return true;
  }
}

[ModuleInit]
public void peas_register_types (TypeModule module)
{
  var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type (typeof (Peas.Activatable),
                                       typeof (Scratch.Plugins.GVlsCompletion));
}

