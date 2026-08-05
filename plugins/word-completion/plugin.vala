/*
 * Copyright (c) 2011 Lucas Baudin <xapantu@gmail.com>
 * Copyright (c) 2014-2025 elementary, Inc. (https://elementary.io)
 *
 * This is a free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; either version 2 of the
 * License, or (at your option) any later version.
 *
 * This is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public
 * License along with this program; see the file COPYING.  If not,
 * write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301 USA.
 *
 */

public class Scratch.Plugins.Completion : Peas.ExtensionBase, Scratch.Services.ActivatablePlugin {
    public const uint INTERACTIVE_DELAY = 500;

    public Object object { owned get; set construct; }

    private List<Gtk.SourceView> text_view_list = new List<Gtk.SourceView> ();
    private Gtk.EventControllerKey key_controller;
    public Gtk.SourceView? current_view {get; private set;}
    public Scratch.Services.Document current_document {get; private set;}

    private MainWindow main_window;
    private Scratch.Services.Interface plugins;

    private const uint [] ACTIVATE_KEYS = {
        Gdk.Key.Return,
        Gdk.Key.KP_Enter,
        Gdk.Key.ISO_Enter,
        Gdk.Key.Tab,
        Gdk.Key.KP_Tab,
        Gdk.Key.ISO_Left_Tab,
    };

    private const uint REFRESH_SHORTCUT = Gdk.Key.bar; //"|" in combination with <Ctrl> will cause refresh

    private uint timeout_id = 0;

    public void activate () {
        plugins = (Scratch.Services.Interface) object;
        plugins.hook_window.connect ((w) => {
            this.main_window = w;
        });

        plugins.hook_document.connect (on_new_source_view);
    }

    public void deactivate () {
        text_view_list.@foreach (cleanup);
    }

    public void update_state () {

    }

    public void on_new_source_view (Scratch.Services.Document doc) {
        if (current_view != null) {
            if (current_view == doc.source_view)
                return;

            if (timeout_id > 0)
                GLib.Source.remove (timeout_id);

            cleanup (current_view);
        }

        current_document = doc;
        current_view = doc.source_view;

        if (text_view_list.find (current_view) == null)
            text_view_list.append (current_view);

        var comp_provider = new Gtk.SourceCompletionWords (
            provider_name_from_document (doc),
            null
        );
        comp_provider.register (current_view.buffer);

        try {
            current_view.completion.add_provider (comp_provider);
            current_view.completion.show_headers = true;
            current_view.completion.show_icons = true;
        } catch (Error e) {
            warning (e.message);
        }
    }

    private string provider_name_from_document (Scratch.Services.Document doc) {
        return _("%s - Word Completion").printf (doc.get_basename ());
    }

    private void cleanup (Gtk.SourceView view) {
        current_view.completion.get_providers ().foreach ((p) => {
            try {
                /* Only remove provider added by this plug in */
                if (p.get_name () == provider_name_from_document (current_document)) {
                    debug ("removing provider %s", p.get_name ());
                    current_view.completion.remove_provider (p);
                }
            } catch (Error e) {
                warning (e.message);
            }
        });
    }
}

[ModuleInit]
public void peas_register_types (GLib.TypeModule module) {
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type (typeof (Scratch.Services.ActivatablePlugin),
                                       typeof (Scratch.Plugins.Completion));
}
