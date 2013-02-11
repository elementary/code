// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/***
  BEGIN LICENSE

  Copyright (C) 2011-2012 Mario Guerriero <mefrio.g@gmail.com>
  This program is free software: you can redistribute it and/or modify it
  under the terms of the GNU Lesser      Public License version 3, as published
  by the Free Software Foundation.

  This program is distributed in the hope that it will be useful, but
  WITHOUT ANY WARRANTY; without even the implied warranties of
  MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
  PURPOSE.  See the GNU      Public License for more details.

  You should have received a copy of the GNUon      Public License along
  with this program.  If not, see <http://www.gnu.org/licenses/>

  END LICENSE
***/

using Gtk;
using Gdk;

using Scratch.Dialogs;

namespace Scratch.Widgets {

    public class ScratchNotebook : Granite.Widgets.DynamicNotebook {

        public signal void page_focused (Gtk.Widget w);
        public MainWindow window; //used in dialog

        public Tab current_tab;
        public Gtk.Widget additional_widget { set; private get; }
        public NotificationBar info_bar { set; public get; }

        public ScratchNotebook (MainWindow parent) {

            this.window = parent;

            this.tab_switched.connect_after (on_switch_page);
            
            expand = true;

            show_all ();

            tab_removed.connect(on_page_removed);
            tab_added.connect(on_page_added);
            additional_widget = new Gtk.Label("NoteBook");
            info_bar = new NotificationBar ();
            
            page_focused.connect ( () => { 
                current_tab.set_overlay (additional_widget);
                current_tab.set_overlay (info_bar);
            });

        }

        void on_page_added (Granite.Widgets.Tab tab) {
            /* If it is a Tab (something where we can put text, not a welcome screen)
             * we want to hide the tabs and the welcome screen.
             */
            if (tab is Tab) {
                (tab as Tab).text_view.focus_in_event.connect (on_page_focused);
                current_tab = tab as Tab;
                page_focused ((tab as Tab).text_view);
                //(tab as Tab).label.scroll_event.connect (on_scroll_event);
            }
        }

        /*bool on_scroll_event (EventScroll event) {
            if (event.direction == ScrollDirection.UP || event.direction == ScrollDirection.LEFT)  {
                if (get_current_page() != 0) {
                    set_current_page (get_current_page() - 1);
                }
            }
            if (event.direction == ScrollDirection.DOWN || event.direction == ScrollDirection.RIGHT)  {
                if (tabs.index (current) != tabs.length ()) {
                    set_current_page (get_current_page() + 1);
                }
            }

            return true;
        }*/
        
        bool on_page_focused (Gtk.Widget w, Gdk.EventFocus event) {
            current_tab = w.get_parent ().get_parent () as Tab;
            window.toolbar.show_hide_button ();
            page_focused (w);
            
            if (current_tab.filename != null) {
                window.set_window_title (current_tab.filename);
                if (settings.autosave)
                    window.toolbar.save_button.hide ();
            }
            else {
                window.set_window_title ("Scratch");
                if (settings.autosave)
                    window.toolbar.save_button.show ();
            }
            
            return false;
        }

        bool on_page_removed(Granite.Widgets.Tab tab) {
            
            // Focus new showed page
            GLib.Idle.add_full (GLib.Priority.LOW, () => {
                if (window.current_tab.text_view != null) {
                    bool has_focus = window.current_tab.text_view.has_visible_focus ();
                    if (window.welcome_screen.get_parent () == null && has_focus != true) {
                        window.current_document.focus_sourceview ();
                        return window.current_tab.text_view.has_visible_focus ();
                    } else return false;
                }
                return false;
            });
            
            var parent = ((Gtk.Container) get_parent ());
            
            if (tabs.length () == 0 && parent != null)
                parent.remove (this);
                
            return true;
        }

        public void add_tab (string labeltext="New document") {
            Tab new_tab;
            
            if (labeltext == "New document")
                new_tab = new Tab (this, _("New document"));
            else
                new_tab = new Tab (this, labeltext);
            
            add_existing_tab (new_tab);
        }

        public void add_existing_tab (Tab new_tab) {

            this.insert_tab (new_tab, -1);

            window.set_undo_redo ();
        }

        public void on_switch_page (Granite.Widgets.Tab? old_tab, Granite.Widgets.Tab new_tab) {
            var tab = new_tab as Tab;
            if (tab == null) {
                /* Welcome screen */
                return;
            }
            else {
/*                /* Focus displaied tab *
                GLib.Idle.add (() => {
                    tab.document.focus_sourceview ();
                    return tab.text_view.has_visible_focus ();
                });
*/            }
            /* Ok, it is a real Tab then */
            if (tab.filename != null) {
                window.set_window_title (tab.filename);
                if (settings.autosave)
                    window.toolbar.save_button.hide ();
            }
            else {
                window.set_window_title ("Scratch");
                if (settings.autosave)
                    window.toolbar.save_button.show ();
            }

        }
    }
    
    public enum ScratchWelcomeState {
        SHOW,
        HIDE
    }
    
    public class ScratchWelcome : Granite.Widgets.Welcome {
        MainWindow window;

        public ScratchWelcome(MainWindow window) {

            base(_("No files are open."), _("Open a file to begin editing."));
            
            append("document-new", _("New file"), _("Create a new empty file."));
            append("document-open", _("Open file"), _("Open a saved file."));

            this.activated.connect (on_activated);
            this.window = window;

            show_all();

        }

        private void on_activated(int index) {

            switch (index) {
                case 0: //new
                window.main_actions.get_action ("New tab").activate ();
                break;

                case 1: // open
                window.main_actions.get_action ("Open").activate ();
                break;

            }


        }


    }

} // Namespace
