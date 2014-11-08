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

using WebKit;

namespace Scratch.Plugins.BrowserPreview {

    internal class BrowserView : WebView {
       
        Gtk.Paned? window;

        public unowned WebView add_inspector_view(WebView v) {
            WebView inspector = new WebView ();
          
            Gtk.ScrolledWindow sw = new Gtk.ScrolledWindow (null, null);
            sw.add (inspector); 
            sw.show_all ();

            window.set_position (100);
            window.add2 (sw);
            sw.show_all ();

            unowned WebView r = inspector;
            return r;
        }

        public BrowserView (Gtk.Paned? window) {
            this.window = window;

            this.get_settings().set_property ("enable-file-access-from-file-uris", true);
            this.get_settings().set_property ("enable-developer-extras", true);

            this.get_inspector().inspect_web_view.connect (add_inspector_view);

            Gtk.ScrolledWindow sw = new Gtk.ScrolledWindow (null, null);
            sw.add (this);
            this.window.add1 (sw);
            sw.show_all ();
        }
    }
}

