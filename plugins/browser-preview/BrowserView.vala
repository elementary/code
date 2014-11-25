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

namespace Scratch.Plugins.BrowserPreview {

    internal class BrowserView : WebKit.WebView {

        public Gtk.Paned? paned = null;

        private unowned WebKit.WebView show_inspector_view (WebKit.WebView v) {
            debug ("Show inspector");

            WebKit.WebView inspector = new WebKit.WebView ();

            Gtk.ScrolledWindow sw = new Gtk.ScrolledWindow (null, null);
            sw.add (inspector);

            paned.set_position (200);
            paned.add2 (sw);
            sw.show_all ();

            unowned WebKit.WebView r = inspector;
            return r;
        }

        private void hook_on_popup_menu (WebKit.WebView web_view, Gtk.Menu menu) {
            debug ("Webview popup menu showed");

            if (paned.get_child2 () == null)
                return;

            Gtk.MenuItem close_inspector = new Gtk.MenuItem.with_label (_("Close Inspector"));
            menu.append (close_inspector);

            close_inspector.activate.connect ( () => {
                    paned.remove (paned.get_child2 ());
                });

            menu.show_all ();
        }

        public BrowserView (Gtk.Paned? paned) {
            this.paned = paned;

            this.get_settings ().set_property ("enable-file-access-from-file-uris", true);
            this.get_settings ().set_property ("enable-developer-extras", true);

            this.get_inspector ().inspect_web_view.connect (show_inspector_view);

            this.populate_popup.connect (hook_on_popup_menu);

            Gtk.ScrolledWindow sw = new Gtk.ScrolledWindow (null, null);
            sw.add (this);
            this.paned.add1 (sw);
            sw.show_all ();
        }
    }
}

