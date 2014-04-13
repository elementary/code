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

public interface SymbolOutline : Object
{
    public abstract Scratch.Services.Document doc { get; protected set; }
    public abstract void parse_symbols ();
    public abstract Granite.Widgets.SourceList get_source_list ();
    public signal void closed ();
    public signal void goto (Scratch.Services.Document doc, int line);
}

namespace Scratch.Plugins {
    public class OutlinePlugin : Peas.ExtensionBase, Peas.Activatable {
        public Object object { owned get; construct; }

        Scratch.Services.Interface scratch_interface;
        SymbolOutline? current_view = null;
        Gtk.EventBox? container = null;

        uint refresh_timeout = 0;

        Gee.List<SymbolOutline> views;

        public void activate () {
            scratch_interface = (Scratch.Services.Interface)object;
            scratch_interface.hook_notebook_context.connect (on_hook_context);
            scratch_interface.hook_document.connect (on_hook_document);
            scratch_interface.hook_split_view.connect (on_hook_split_view);
            views = new Gee.LinkedList<SymbolOutline> ();
        }

        public void deactivate () {
            container.destroy ();
        }

        public void update_state () {
        }

        void on_hook_context (Gtk.Notebook notebook) {
            if (container != null)
                return;
            
            container = new Gtk.EventBox ();
            container.visible = false;            
            notebook.append_page (container, new Gtk.Label (_("Symbols")));
            container.show_all ();
        }

        void on_hook_document (Scratch.Services.Document doc) {
            if (current_view != null && current_view.doc == doc) 
                return;

            if (current_view != null)
                container.remove (current_view.get_source_list ());

            SymbolOutline view = null;
            foreach (var v in views) {
                if (v.doc == doc) {
                    view = v;
                    break;
                }
            }
            if (view == null) {
                if (doc.get_mime_type () == "text/x-vala") {
                    view = new ValaSymbolOutline (doc);
                } else {
                    view = new CtagsSymbolOutline (doc);
                }
                view.closed.connect (remove_view);
                view.goto.connect (goto);
                views.add (view);
                view.parse_symbols ();

                doc.doc_saved.connect (update_timeout);
            }

            container.add (view.get_source_list ());
            container.show_all ();
            current_view = view;
        }
        
        void on_hook_split_view (Scratch.Widgets.SplitView view) {
            view.welcome_shown.connect (() => {
                container.visible = false;
            });
            view.welcome_hidden.connect (() => {
                container.visible = true;
            });
        }
        
        void update_timeout () {
            if (refresh_timeout != 0)
                Source.remove (refresh_timeout);

            refresh_timeout = Timeout.add (1000, () => {
                current_view.parse_symbols ();
                refresh_timeout = 0;
                return false;
            });
        }

        void remove_view (SymbolOutline view) {
            views.remove (view);
            view.doc.doc_saved.disconnect (update_timeout);
            view.closed.disconnect (remove_view);
            view.goto.disconnect (goto);
        }

        void goto (Scratch.Services.Document doc, int line)    {
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
