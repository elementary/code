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
    public abstract int n_symbols { get; protected set; }
    public abstract Granite.Widgets.SourceList get_source_list ();
    public signal void closed ();
    public signal void goto (Scratch.Services.Document doc, int line);
}

namespace Scratch.Plugins {
    public class OutlinePlugin : Peas.ExtensionBase, Peas.Activatable {
        public Object object { owned get; construct; }

        Gtk.ToggleToolButton? tool_button = null;
        Scratch.Services.Interface scratch_interface;
        SymbolOutline? current_view = null;
        Gtk.EventBox? container = null;
        Gtk.Notebook? notebook = null;

        uint refresh_timeout = 0;

        Gee.List<SymbolOutline> views;

        public void activate () {
            scratch_interface = (Scratch.Services.Interface)object;

            scratch_interface.hook_document.connect (on_hook_document);

            scratch_interface.hook_split_view.connect (on_hook_split_view);

            scratch_interface.hook_notebook_context.connect (on_hook_context);

            scratch_interface.hook_toolbar.connect (on_hook_toolbar);

            views = new Gee.LinkedList<SymbolOutline> ();
        }

        public void deactivate () {
            if (tool_button != null)
                tool_button.destroy ();

            container.destroy ();
        }

        public void update_state () {
        }

        void on_hook_toolbar (Scratch.Widgets.Toolbar toolbar) {
            if (tool_button != null)
                return;

            var icon = new Gtk.Image.from_icon_name ("error", Gtk.IconSize.LARGE_TOOLBAR);
            tool_button = new Gtk.ToggleToolButton ();
            tool_button.set_icon_widget (icon);
            tool_button.tooltip_text = _("Show Ouline");
            tool_button.toggled.connect (toggle_plugin_visibility);

            tool_button.show_all ();

            toolbar.pack_end (tool_button);
        }

        void toggle_plugin_visibility () {
            if (tool_button.active) {
                notebook.set_current_page (notebook.append_page (container, new Gtk.Label (_("Symbols"))));
                tool_button.tooltip_text = _("Hide Outline");
            } else {
                notebook.remove (container);
                tool_button.tooltip_text = _("Show Outline");
            }
        }

        void on_hook_context (Gtk.Notebook notebook) {
            if (container != null)
                return;
            if (this.notebook == null)
                this.notebook = notebook;

            this.notebook.switch_page.connect ((page, page_num) => {
                if(tool_button.active != (container == page))
                    tool_button.active = (container == page);
            });

            container = new Gtk.EventBox ();
            container.visible = false;
            if (this.notebook == null)
                notebook.append_page (container, new Gtk.Label (_("Symbols")));
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
            if (view == null && doc.file != null) {
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

            if (view.n_symbols > 1) {
                add_container ();
            }
            else if (doc.file == null || view.n_symbols <= 1) {
                remove_container ();
            }
        }

        void add_container () {
            if(notebook.page_num (container) == -1) {
                notebook.append_page (container, new Gtk.Label (_("Symbols")));
                container.show_all ();
            }
        }

        void remove_container () {
            if (notebook.page_num (container) != -1)
                notebook.remove (container);
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
