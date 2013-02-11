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

using Gtk;

using Scratch.Dialogs;

namespace Scratch.Widgets {

    public class SplitView : Granite.Widgets.HCollapsablePaned {

        //IN THIS CLASS I COMMENTED ALL THE CODE WHICH WAS USED FOR A SPLITVIEW WITH GTK.TABLE

        public const int max = 3;

        public MainWindow window;
        public uint total_view {
            get {return get_children().length();}
        }

        Gtk.Widget? focused_widget = null;

        public bool is_empty { get; private set; default = true; }

        public signal void page_changed (Gtk.Widget w);
        public Gtk.Widget additional_widget { set; private get; }
        public NotificationBar info_bar { set; private get; }

        public SplitView (MainWindow window) {

            this.window = window;

        }


        public void add_view (ScratchNotebook view) {
            add (view);
            this.position = window.get_allocated_width() / 2; //Puts the new view in the middle

            view.tab_added.connect (() => { is_empty = is_empty_or_without_tabs (); });
            view.tab_removed.connect (() => { is_empty = is_empty_or_without_tabs (); return true; });
            view.page_focused.connect (on_page_focused);
            view.additional_widget = additional_widget;
            view.info_bar = info_bar;
        }

        void on_page_focused (Gtk.Widget w) {
            page_changed (w);
        }

        bool is_empty_or_without_tabs () {
            foreach (var widget in get_children ())
            {
                if (!(widget is ScratchNotebook)) {
                    return false;
                }
                else {
                    if (((ScratchNotebook)widget).get_children ().length () > 0)
                        return false;
                }
            }
            return true;
        }

        public bool remove_current_view () {
            focused_widget = get_focus_child ();
            if (focused_widget == null)
                return false;
            else {
                remove (focused_widget);
                var notebook = focused_widget as ScratchNotebook;
                show_save_dialog (notebook);
                focused_widget = null;
            }
            return true;
        }

        public void show_save_dialog (ScratchNotebook notebook) {
            int n;

            for (n = 0; n!=notebook.n_tabs; n++) {
                var label  = (Tab) notebook.tabs.nth_data (n);
                notebook.current = label;

                string isnew = label.label [0:1];

                if (isnew == "*") {
                    var save_dialog = new SaveDialog (label);
                    save_dialog.run();
                }
            }
        }

        public unowned ScratchNotebook get_current_notebook () {
            focused_widget = get_focus_child ();
            
            if (focused_widget != null && focused_widget.get_parent () != this) {
                focused_widget = null;
            }
            
            weak ScratchNotebook child = focused_widget as ScratchNotebook;
            
            if (child == null) {
                child = get_children ().nth_data (0) as ScratchNotebook;
                if( child == null) {
                    debug ("No valid notebook for the split view? Let's create one.");
                    var note = new ScratchNotebook(window);
                    add_view (note);
                    focused_widget = note;
                    child = note;
                }
            }
            return child;
        }

    }
}
