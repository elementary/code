// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/***
  BEGIN LICENSE

  Copyright (C) 2013 Mario Guerriero <mario@elementaryos.org>
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
    public class LoadingView : Gtk.EventBox {
        
        private Spinner spinner;
        private Label label;
        
        public LoadingView () {
            this.get_style_context().add_class (Granite.StyleClass.CONTENT_VIEW);
            this.valign = Align.FILL;
            
            spinner = new Spinner ();
            spinner.set_size_request(32, 32);

            label = new Label (_("Wait while restoring last session..."));
        
            var box = new Box (Orientation.VERTICAL, 0);
            box.valign = Align.CENTER;
            box.pack_start (spinner, false, true, 0);
            box.pack_start (label, false, true, 0);    
        
            this.add (box);
            
            this.visible = false;
            this.no_show_all = true;
        }
        
        public void start () {
            this.visible = true;
            this.no_show_all = false;
            this.show_all ();
            spinner.start ();
        }
        
        public void stop () {
            this.visible = false;
            this.no_show_all = true;
            this.hide ();
            spinner.stop ();
        }
    }
}
