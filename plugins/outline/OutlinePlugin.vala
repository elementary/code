// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/***
  BEGIN LICENSE

  Copyright (C) 2013 Tom Beckmann <tomjonabc@gmail.com>
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

public const string NAME = N_("Outline");
public const string DESCRIPTION = N_("Outline symbols in your current file in vala");

namespace Scratch.Plugins {
    public class OutlinePlugin : Peas.ExtensionBase, Peas.Activatable {
        public Object object { owned get; construct; }

        Scratch.Services.Interface scratch_interface;
        SymbolOutline? current_view = null;

        Gtk.Stack? container = null;
        Gtk.Notebook? notebook = null;

        Gee.LinkedList<SymbolOutline> views;

        public void activate () {
            views = new Gee.LinkedList<SymbolOutline> ();
            scratch_interface = (Scratch.Services.Interface)object;
            scratch_interface.hook_document.connect (on_hook_document);
            scratch_interface.hook_notebook_sidebar.connect (on_hook_sidebar);
        }

        public void deactivate () {
            container.destroy ();
        }

        public void update_state () {
            
        }

        void on_hook_sidebar (Gtk.Notebook notebook) {
            if (container != null)
                return;

            if (this.notebook == null)
                this.notebook = notebook;

            container = new Gtk.Stack ();
            container.visible = false;
            if (this.notebook != null)
                notebook.append_page (container, new Gtk.Label (_("Symbols")));
        }

        void on_hook_document (Scratch.Services.Document doc) {
            if (current_view != null && current_view.doc == doc)
                return;

            SymbolOutline view = null;
            foreach (var v in views) {
                if (v.doc == doc) {
                    view = v;
                    break;
                }
            }

            if (view == null && doc.file != null) {
                var mime_type = doc.get_mime_type ();
                switch (mime_type) {
                    case "text/x-vala":
                        view = new ValaSymbolOutline (doc);
                        break;
                    case "text/x-csrc":
                    case "text/x-chdr":
                    case "text/x-c++src":
                    case "text/x-c++hdr":
                        view = new CtagsSymbolOutline (doc);
                        break;
                }

                if (view != null) {
                    view.closed.connect (() => {remove_view (view);});
                    view.goto.connect (goto);
                    views.add (view);
                    view.parse_symbols ();
                }
            }

            if (view != null) {
                var source_list = view.get_source_list ();
                if (source_list.parent == null)
                    container.add (source_list);
                container.set_visible_child (source_list);
                container.show_all ();
                current_view = view;
                add_container ();
            } else {
                remove_container ();
            }
        }

        void add_container () {
            if (notebook.page_num (container) == -1) {
                notebook.append_page (container, new Gtk.Label (_("Symbols")));
                container.show_all ();
            }
        }

        void remove_container () {
            if (notebook.page_num (container) != -1)
                notebook.remove (container);
        }

        void remove_view (SymbolOutline view) {
            views.remove (view);
            var source_list = view.get_source_list ();
            if (source_list.parent == container)
                container.remove (source_list);
            if (views.is_empty)
                remove_container ();
            view.goto.disconnect (goto);
        }

        void goto (Scratch.Services.Document doc, int line) {
            scratch_interface.open_file (doc.file);

            var text = doc.source_view;
            Gtk.TextIter iter;
            text.buffer.get_iter_at_line (out iter, line - 1);
            text.buffer.place_cursor (iter);
            text.scroll_to_iter (iter, 0.0, true, 0.5, 0.5);
        }
    }
}

[ModuleInit]
public void peas_register_types (GLib.TypeModule module)
{
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type (typeof (Peas.Activatable), typeof (Scratch.Plugins.OutlinePlugin));
}
