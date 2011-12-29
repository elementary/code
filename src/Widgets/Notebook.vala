// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/***
  BEGIN LICENSE

  Copyright (C) 2011 Mario Guerriero <mefrio.g@gmail.com>
  This program is free software: you can redistribute it and/or modify it
  under the terms of the GNU Lesser      Public License version 3, as published
  by the Free Software Foundation.

  This program is distributed in the hope that it will be useful, but
  WITHOUT ANY WARRANTY; without even the implied warranties of
  MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
  PURPOSE.  See the GNU      Public License for more details.

  You should have received a copy of the GNU      Public License along
  with this program.  If not, see <http://www.gnu.org/licenses/>

  END LICENSE
***/

using Gtk;
using Gdk;

using Scratch.Dialogs;

namespace Scratch.Widgets {

    public class ScratchNotebook : Notebook {

        public signal void page_focused (Gtk.Widget w);
        public MainWindow window; //used in dialog

        public Tab current_tab;

        public ScratchNotebook (MainWindow parent) {

            this.window = parent;

            this.switch_page.connect_after (on_switch_page);

            expand = true;
            set_scrollable (true);
            set_group_name ("s");

            drag_end.connect (on_drag_end);

            show_all ();

            page_removed.connect(on_page_removed);
            page_added.connect(on_page_added);

        }

        void on_page_added(Gtk.Widget w, uint page_num)
        {
            /* If it is a Tab (something where we can put text, not a welcome screen)
             * we want to hide the tabs and the welcome screen.
             */
            if(w is Tab) {
                (w as Tab).text_view.focus_in_event.connect (on_page_focused);
                current_tab = w as Tab;
                page_focused ((w as Tab).text_view);
                (w as Tab).label.scroll_event.connect (on_scroll_event);
            }
        }

        bool on_scroll_event (EventScroll event) {
            if (event.direction == ScrollDirection.UP || event.direction == ScrollDirection.LEFT)  {
                if (get_current_page() != 0) {
                    set_current_page (get_current_page() - 1);
                }
            }
            if (event.direction == ScrollDirection.DOWN || event.direction == ScrollDirection.RIGHT)  {
                if (get_current_page() != get_n_pages ()) {
                    set_current_page (get_current_page() + 1);
                }
            }

            return true;
        }

        bool on_page_focused (Gtk.Widget w, Gdk.EventFocus event) {
            current_tab = w.get_parent() as Tab;
            page_focused (w);
            return false;
        }

        void on_page_removed(Gtk.Widget w, uint page_num)
        {
            if(get_n_pages () == 0) {
                ((Gtk.Container)get_parent()).remove(this);
            }

            set_tab ();
            /*if (get_n_pages() == 0 || (get_n_pages() == 1 && welcome_screen.get_parent() != null))
                show_welcome ();*/
        }

        public int add_tab (string labeltext="New document") {
            Tab new_tab;

            if (labeltext == "New document")
                new_tab = new Tab (this, _("New document"));
            else
                new_tab = new Tab (this, labeltext);
            return add_existing_tab(new_tab);
        }

        public int add_existing_tab (Tab new_tab) {
            int index = this.append_page (new_tab, new_tab.label);
            set_tab_reorderable(new_tab, true);
            set_tab_detachable(new_tab, true);

            set_tab ();
            window.set_undo_redo ();

            return index;
        }

        public void set_tab () {

            /*if (get_n_pages () == 1)
                set_show_tabs (false);
            else
                set_show_tabs (true);*/
        }

        public void on_switch_page (Widget page, uint number) {

            var tab = page as Tab;
            if(tab == null) {
                /* Welcome screen */
                return;
            }
            /* Ok, it is a real Tab then */
            if (tab.filename != null)
                window.set_window_title (tab.filename);
            else
                window.set_window_title ("Scratch");

            //tab.text_view.grab_focus ();

        }

        public void on_drag_end (DragContext context) {

            /*List<Widget> children = ((Gtk.Container)get_parent ()).get_children ();
            int i;

            for (i = 0; i!=children.length(); i++) {//ScratchNotebook notebook in children) {
                var notebook = children.nth_data (i) as ScratchNotebook;
                if (notebook.get_n_pages () == 0) {
                    window.split_view.remove (notebook);
                }
            }
            window.split_view.set_menu_item_sensitive ();*/
        }

        public void show_tabs_view () {

            /*if (welcome_screen.active) {

                this.remove_page (this.page_num(welcome_screen));
                this.set_show_tabs (true);
                this.welcome_screen.active = false;

            }*/

        }




    }

    public class ScratchWelcome : Granite.Widgets.Welcome {
        MainWindow window;

        public ScratchWelcome(MainWindow window) {

            base(_("No files are open."), _("Open a file to begin editing."));

            //notebook = caller;

            append("document-open", _("Open file"), _("Open a saved file."));
            append("document-new", _("New file"), _("Create a new empty file."));
            this.activated.connect (on_activated);
            this.window = window;

            show_all();

        }

        private void on_activated(int index) {

            switch (index) {
                case 0: //open
                window.main_actions.get_action ("Open").activate ();
                break;

                case 1: // new
                window.main_actions.get_action ("New tab").activate ();
                break;

            }


        }


    }

} // Namespace
