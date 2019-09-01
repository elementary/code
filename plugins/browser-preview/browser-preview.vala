// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/***
  BEGIN LICENSE

  Copyright (C) 2011-2012 Mario Guerriero <mefrio.g@gmail.com>
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

namespace Scratch.Plugins {

    public class BrowserPreviewPlugin : Peas.ExtensionBase,  Peas.Activatable {

        Gtk.ToggleButton? tool_button = null;
        Gee.LinkedList<BrowserPreview.BrowserView> previews = new Gee.LinkedList<BrowserPreview.BrowserView> ();

        unowned BrowserPreview.BrowserView? view = null;
        Scratch.Services.Document? doc = null;

        Scratch.Services.Interface plugins;
        public Object object { owned get; construct; }

        public void update_state () {
        }

        public void activate () {
            plugins = (Scratch.Services.Interface) object;

            plugins.hook_window.connect ((w) => {
                this.doc = w.get_current_document ();
            });

            plugins.hook_document.connect (set_current_document);

            plugins.hook_split_view.connect (on_hook_split_view);

            plugins.hook_toolbar.connect (on_hook_toolbar);
        }

        public void deactivate () {
            if (tool_button != null)
                tool_button.destroy ();
        }

        void on_hook_split_view (Scratch.Widgets.SplitView view) {
            this.tool_button.visible = ! view.is_empty ();
            view.welcome_shown.connect (() => {
                this.tool_button.visible = false;
            });
            view.welcome_hidden.connect (() => {
                this.tool_button.visible = true;
            });
        }

        void on_hook_toolbar (Scratch.Widgets.HeaderBar toolbar) {
            if (tool_button != null)
                return;

            tool_button = new Gtk.ToggleButton ();
            tool_button.image = new Gtk.Image.from_icon_name ("emblem-web", Gtk.IconSize.LARGE_TOOLBAR);
            tool_button.tooltip_text = _("Show Preview");
            tool_button.clicked.connect (toggle_plugin_visibility);

            tool_button.show_all ();

            toolbar.pack_end (tool_button);
        }

        void toggle_plugin_visibility () {
            if (tool_button.active) {
                if (view == null) {
                    var preview = new BrowserPreview.BrowserView (doc);
                    preview.show_all ();
                    previews.add (preview);
                    doc.pane.add_tab (preview);
                    view = preview;
                }

                tool_button.tooltip_text = _("Hide Preview");
            } else {
                if (view != null) {
                    previews.remove (view);
                    view.destroy ();
                    view = null;
                }

                tool_button.tooltip_text = _("Show Preview");
            }
        }

        void set_current_document (Scratch.Services.Document? d) {
            if (d != null) {
                doc = d;
                view = null;
                foreach (var preview in previews) {
                    if (preview.doc == doc) {
                        view = preview;
                    }
                }

                tool_button.active = view != null;
            }
        }
    }
}

[ModuleInit]
public void peas_register_types (GLib.TypeModule module) {
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type (typeof (Peas.Activatable),
                                     typeof (Scratch.Plugins.BrowserPreviewPlugin));
}
