// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/***
  BEGIN LICENSE

  Copyright (C) 2011-2013 Mario Guerriero <mario@elementaryos.org>
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

using Gtk;

namespace Scratch.Widgets {

    public class SplitView : Granite.Widgets.CollapsiblePaned {

        // Widgets
        public Granite.Widgets.Welcome welcome_screen;
        public Scratch.Widgets.DocumentView? current_view = null;

        public GLib.List<Scratch.Widgets.DocumentView> views;
        private GLib.List<Scratch.Widgets.DocumentView> hidden_views;

        // Signals
        public signal void welcome_shown ();
        public signal void welcome_hidden ();
        public signal void document_change (Scratch.Services.Document document);

        private weak MainWindow window;
        
        public SplitView (MainWindow window) {
            base (Gtk.Orientation.HORIZONTAL);
            this.window = window;

            // Welcome screen
            this.welcome_screen = new Granite.Widgets.Welcome (_("No Files Open"), 
                                                               _("Open a file to begin editing."));
            this.welcome_screen.valign = Gtk.Align.FILL;
            this.welcome_screen.halign = Gtk.Align.FILL;
            this.welcome_screen.vexpand = true;
            this.welcome_screen.append ("document-new", _("New file"), _("Create a new empty file."));
            this.welcome_screen.append ("document-open", _("Open file"), _("Open a saved file."));
            this.welcome_screen.activated.connect ((i) => {
                // New file
                if (i == 0)
                    window.main_actions.get_action ("NewTab").activate ();
                // Open
                else if (i == 1)
                    window.main_actions.get_action ("Open").activate ();
            });

            // Handle Drag-and-drop functionality on source-view
            Gtk.TargetEntry target = {"text/uri-list", 0, 0};
            Gtk.drag_dest_set (this.welcome_screen, Gtk.DestDefaults.ALL, {target}, Gdk.DragAction.COPY);
            this.welcome_screen.drag_data_received.connect ((ctx, x, y, sel, info, time) => {
                var uris = sel.get_uris ();
                if (uris.length > 0) {
                    var view = this.current_view ?? this.add_view ();

                    for (var i = 0; i < uris.length; i++) {
                        string filename = uris[i];
                        File file = File.new_for_uri (filename);
                        Scratch.Services.Document doc = new Scratch.Services.Document (window.main_actions, file);
                        view.open_document (doc);
                    }

                    Gtk.drag_finish (ctx, true, false, time);
                }
            });

            this.views = new GLib.List<Scratch.Widgets.DocumentView> ();
            this.hidden_views = new GLib.List<Scratch.Widgets.DocumentView> ();
        }

        public Scratch.Widgets.DocumentView? add_view () {
            if (views.length () >= 2) {
                warning ("Maximum view number was already reached!");
                return null;
            }

            // Hide welcome screen
            if (get_children ().length () > 0)
                hide_welcome ();

            Scratch.Widgets.DocumentView view;
            if (hidden_views.length () == 0) {
                view = new Scratch.Widgets.DocumentView (window);

                view.empty.connect (() => {
                    remove_view (view);
                });
            } else { 
                view = hidden_views.nth_data (0);
                hidden_views.remove (view);
            }

            view.document_change.connect (on_document_changed);
            view.vexpand = true;

            if (views.length () < 1)
                this.pack1 (view, true, true);
            else
                this.pack2 (view, true, true);

            view.show_all ();

            views.append (view);
            this.current_view = view;
            debug ("View added succefully");

            // Enbale/Disable useless GtkActions about views
            check_actions ();

            return view;
        }

        public void remove_view (Scratch.Widgets.DocumentView? view = null) {
            // If no specific view is required to be removed, just remove the current one
            if (view == null)
                view = get_focus_child () as Scratch.Widgets.DocumentView;
            if (view == null) {
                warning ("The is no focused view to remove!");
                return;                
            }

            this.remove (view);
            this.views.remove (view);
            view.document_change.disconnect (on_document_changed);
            view.visible = false;
            this.hidden_views.append (view);
            debug ("View removed succefully");

            // Enbale/Disable useless GtkActions about views
            check_actions ();

            // Move the focus on the other view
            if (views.nth_data (0) != null) {
                views.nth_data (0).focus ();
            }

            // Show/Hide welcome screen
            if (this.views.length () == 0)
                show_welcome ();
        }

        public Scratch.Widgets.DocumentView? get_current_view () {
            views.foreach ((v) => {
                if (v.has_focus)
                    current_view = v;
            });

            return current_view;
        }

        public bool is_empty () {
            return (views.length () == 0);
        }

        // Show welcome screen
        public void show_welcome () {
            this.pack1 (welcome_screen, true, true);
            this.welcome_screen.show_all ();
            welcome_shown ();
            debug ("WelcomeScreen shown succefully");
        }

        // Hide welcome screen
        public void hide_welcome () {
            if (this.welcome_screen.get_parent () == this) {
                this.remove (welcome_screen);
                welcome_hidden ();
                debug ("WelcomeScreen hidden succefully");
            }
        }

        // Detect the last focused Document throw a signal
        private void on_document_changed (Scratch.Services.Document? document) {
            if (document != null)
                document_change (document);
        }

        // Check the possibility to add or not a new view
        private void check_actions () {
            window.main_actions.get_action ("NewView").sensitive = (views.length () < 2);
            window.main_actions.get_action ("RemoveView").sensitive = (views.length () > 1);
        }
    }
}