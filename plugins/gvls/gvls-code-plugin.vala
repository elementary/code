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
    private MainWindow main_window;
    private ulong cn = 0;
    private uint timed_id = -1;
    private bool lsp_sync_in_progress = false;
    private bool initiated = false;

    public Object object { owned get; construct; }
    Scratch.Services.Interface plugins;

    ~GVlsCompletion () {
        if (timed_id != -1) {
            var source = MainContext.@default ().find_source_by_id (timed_id);
            if (source != null) {
                source.destroy ();
            }
        }
    }

    public void activate () {
        plugins = (Scratch.Services.Interface) object;

        GVlsp.ServerInetLocal server = new GVlsp.ServerInetLocal ();

        server.run ();
        server.target_manager.add_default_vapi_dirs ();

        plugins.set_data<GVls.Server> ("gvls-server", server);

        GVls.Client client = new GVlsp.ClientInetLocal ();
        plugins.set_data<GVls.Client> ("gvls-client", client);

        timed_id = Timeout.add (1000, push_document_changes);

        plugins.hook_window.connect ((w) => {
            this.main_window = w;
        });
        cn = plugins.hook_document.connect ((doc)=>{
            try {
                var cl = plugins.get_data<GVls.Client> ("gvls-client");
                if (cl == null) {
                    return;
                }
                var file = doc.file;
                if (file == null) {
                    return;
                }
                if (!initiated) {
                    cl.initialize.begin (file.get_uri (), (obj, res)=>{
                        try {
                            cl.initialize.end (res);
                            initiated = true;
                            init_doc (doc, cl);
                        } catch (GLib.Error e) {
                            warning ("Error setting completion provider: %s", e.message);
                        }
                    });
                } else {
                    init_doc (doc, cl);
                }
            } catch (GLib.Error e) {
                warning ("Error setting completion provider: %s", e.message);
            }
        });
    }

    private void init_doc (Scratch.Services.Document doc,
                            GVls.Client client) throws GLib.Error
    {
        var cl = plugins.get_data<GVls.Client> ("gvls-client");
        if (cl == null) {
            return;
        }

        var view = doc.source_view;
        var file = doc.file;
        if (file == null) {
            return;
        }

        var ptmp = view.get_data<GVlsui.CompletionProvider> ("gvls-provider");
        if (ptmp != null) {
            return;
        }

        var prov = new GVlsui.CompletionProvider ();
        prov.client = client;
        view.get_completion ().add_provider (prov);
        view.set_data<GVlsui.CompletionProvider> ("gvls-provider", prov);
        view.set_data<bool> ("gvls-view-dirty", true);
        GVls.Container changes = new GVls.ContainerHashList.for_type (typeof (TextDocumentContentChangeEventInfo));
        view.set_data<GVls.Container> ("gvls-changes", changes);
        var buf = view.get_buffer ();
        buf.delete_range.connect ((start, end)=>{
            var chgs = view.get_data<GVls.Container> ("gvls-changes");
            var pstart = new SourcePosition.from_values (start.get_line (), start.get_line_offset ());
            var pend = new SourcePosition.from_values (end.get_line (), end.get_line_offset ());
            var change = new TextDocumentContentChangeEventInfo ();
            change.range.start = pstart;
            change.range.end = pend;
            change.text = null;
            chgs.add (change);
        });

        buf.insert_text.connect ((ref pos, text)=>{
            var chgs = view.get_data<GVls.Container> ("gvls-changes");
            var pstart = new SourcePosition.from_values (pos.get_line (), pos.get_line_offset ());
            var pend = new SourcePosition.from_values (pos.get_line (), pos.get_line_offset ());
            var change = new TextDocumentContentChangeEventInfo ();
            change.range.start = pstart;
            change.range.end = pend;
            change.text = text;
            chgs.add (change);
        });

        client.document_open.begin (file.get_uri (), buf.text, (obj, res)=>{
            try {
                client.document_open.end (res);
            } catch (GLib.Error e) {
                warning ("Error while send didOpen notification: %s", e.message);
            }
        });
    }


    public void deactivate () {
        plugins.disconnect (cn);
        if (main_window == null) {
            message ("No MainWindow was set");
            return;
        }

        var docview = main_window.get_current_view ();
        if (!(docview is Scratch.Widgets.DocumentView)) {
            return;
        }

        foreach (Services.Document doc in docview.docs) {
            var view = doc.source_view;
            var prov = view.get_data<GVlsui.CompletionProvider> ("gvls-provider");
            if (prov == null) return;
            try {
                view.get_completion ().remove_provider (prov);
            } catch (GLib.Error e) {
                warning (_("Error deactivating GVls Plugin: %s"), e.message);
            }
        }

        var client = plugins.get_data<GVls.Client> ("gvls-client");
        if (client != null) {
            client.server_shutdown.begin ();
        }

        if (timed_id != -1) {
            var source = MainContext.@default ().find_source_by_id (timed_id);
            if (source != null) {
                source.destroy ();
            }
        }
    }
    public void update_state () {
    }
    private bool push_document_changes () {
        if (lsp_sync_in_progress) {
            return true;
        }

        var client = plugins.get_data<GVls.Client> ("gvls-client");
        if (client == null) {
            return true;
        }

        if (main_window == null) {
            message ("No MainWindow was set");
            return true;
        }

        var doc = main_window.get_current_document ();
        if (doc == null) {
            return true;
        }

        var view = doc.source_view;
        if (view == null) {
            return true;
        }

        if (!(view is Scratch.Widgets.DocumentView)) {
            return true;
        }

        var file = doc.file;
        if (file == null) {
            return true;
        }

        var chgs = view.get_data<GVls.Container> ("gvls-changes");
        if (chgs == null) {
            return true;
        }

        if (chgs.get_n_items () != 0) {
            GVls.Container current_changes = chgs;
            chgs = new GVls.ContainerHashList.for_type (typeof (TextDocumentContentChangeEventInfo));
            view.set_data<GVls.Container> ("gvls-changes", chgs);
            lsp_sync_in_progress = true;
            var uri = file.get_uri ();
            client.document_change.begin (uri, current_changes, (obj, res)=>{
                try {
                    client.document_change.end (res);
                    lsp_sync_in_progress = false;
                } catch (GLib.Error e) {
                    warning ("Error while pushing changes to the server: %s", e.message);
                }
            });
        }

        return true;
    }
}

[ModuleInit]
public void peas_register_types (TypeModule module) {
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type (typeof (Peas.Activatable),
                                       typeof (Scratch.Plugins.GVlsCompletion));
}

