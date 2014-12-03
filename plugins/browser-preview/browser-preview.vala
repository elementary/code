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

public const string NAME = N_("Browser Preview");
public const string DESCRIPTION = N_("Get a preview your work in a web page");

namespace Scratch.Plugins {

    public class BrowserPreviewPlugin : Peas.ExtensionBase,  Peas.Activatable {

        Gtk.ToolButton? tool_button = null;
        GLib.HashTable<Scratch.Services.Document, BrowserPreview.BrowserView> previews = new  GLib.HashTable<Scratch.Services.Document, BrowserPreview.BrowserView> (null, null);

        BrowserPreview.BrowserView? view = null;
        Scratch.Services.Document? doc = null;

        Gtk.Notebook? notebook = null;

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

            plugins.hook_notebook_context.connect (on_hook_context);

            plugins.hook_toolbar.connect (on_hook_toolbar);
        }

        public void deactivate () {
            if (tool_button != null)
                tool_button.destroy ();

            previews.foreach ((key, val) => {
                key.doc_saved.disconnect (show_preview);
                val.paned.destroy ();
            });
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

        void on_hook_toolbar (Scratch.Widgets.Toolbar toolbar) {
            if (tool_button != null)
                return;

            var icon = new Gtk.Image.from_icon_name ("emblem-web", Gtk.IconSize.LARGE_TOOLBAR);
            tool_button = new Gtk.ToolButton (icon, _("Get preview!"));
            tool_button.tooltip_text = _("Hide preview");
            tool_button.clicked.connect (toggle_plugin_visibility);

            icon.show ();
            tool_button.show ();

            toolbar.pack_start (tool_button);
        }

        void on_hook_context (Gtk.Notebook notebook) {
            if (this.notebook != null)
                return;

            this.notebook = notebook;

            set_current_document (this.doc);
        }

        void toggle_plugin_visibility () {
            if (notebook.page_num (view.paned) == -1) {
                notebook.set_current_page (notebook.append_page (view.paned, new Gtk.Label (_("Web preview"))));
                tool_button.tooltip_text = _("Hide preview");
            } else {
                notebook.remove (view.paned);
                tool_button.tooltip_text = _("Show preview");
            }
        }

        void set_current_document (Scratch.Services.Document? d) {
            if (d != null) {

                this.doc = d;

                if (previews.get (this.doc) == null) {

                    previews.insert (this.doc, new BrowserPreview.BrowserView (new Gtk.Paned (Gtk.Orientation.VERTICAL)));

                    this.doc.doc_saved.disconnect (show_preview);
                    this.doc.doc_saved.connect (show_preview);
                }

                show_preview ();
            }
        }

        void show_preview () {

            bool tab_is_selected = false;
            int tab_page_number = 0;

            // Remove preview tab
            if (view != null) {
                // Check if Preview-Tab is selected
                tab_page_number = notebook.page_num (view.paned);
                tab_is_selected = notebook.get_current_page () == tab_page_number;
                notebook.remove (view.paned);
            }

            view = previews.get (this.doc);
            view.paned.show_all ();

            // Check if removed tab was visible
            if (tab_page_number > -1) {
                notebook.insert_page (view.paned, new Gtk.Label (_("Web preview")), tab_page_number);

                // Select new tab if the removed tab was selected
                if (tab_is_selected)
                    notebook.set_current_page (tab_page_number);
            }

            if (view.uri == null || view.uri == "" || view.uri != this.doc.file.get_uri ())
                view.load_uri (this.doc.file.get_uri ());
            else
                view.reload ();
        }
    }
}

[ModuleInit]
public void peas_register_types (GLib.TypeModule module) {
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type (typeof (Peas.Activatable),
                                     typeof (Scratch.Plugins.BrowserPreviewPlugin));
}

