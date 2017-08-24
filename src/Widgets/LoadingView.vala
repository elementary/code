// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*
* Copyright (c) 2013 Mario Guerriero <mefrio.g@gmail.com>
*               2017 elementary LLC. <https://elementary.io>
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 3 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*/

namespace Scratch.Widgets {
    public class LoadingView : Gtk.EventBox {
        private Gtk.Spinner spinner;

        public LoadingView () {
            get_style_context ().add_class (Gtk.STYLE_CLASS_VIEW);
            valign = Gtk.Align.FILL;

            spinner = new Gtk.Spinner ();
            spinner.set_size_request (32, 32);

            var label = new Gtk.Label (_("Wait while restoring last session..."));
            label.margin = 12;

            var grid = new Gtk.Grid ();
            grid.orientation = Gtk.Orientation.VERTICAL;
            grid.valign = Gtk.Align.CENTER;
            grid.add (spinner);
            grid.add (label);

            add (grid);
            visible = false;
            no_show_all = true;
        }

        public void start () {
            visible = true;
            no_show_all = false;
            show_all ();
            spinner.start ();
        }

        public void stop () {
            visible = false;
            no_show_all = true;
            hide ();
            spinner.stop ();
        }
    }
}
