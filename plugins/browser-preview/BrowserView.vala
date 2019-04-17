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
    public class BrowserView : Gtk.Grid, Code.PaneSwitcher {
        public string icon_name { get; set; }
        public string title { get; set; }

        private WebKit.WebView web_view;
        public unowned Scratch.Services.Document doc;

        public BrowserView (Scratch.Services.Document doc) {
            this.doc = doc;
            width_request = 200;
            title = _("Web Preview");
            icon_name = "web-browser-symbolic";
            web_view = new WebKit.WebView ();
            web_view.expand = true;
            add (web_view);
            web_view.get_settings ().enable_developer_extras = true;
            web_view.get_settings ().allow_file_access_from_file_urls = true;
            web_view.get_inspector ().open_window.connect (() => {return false;});

            web_view.load_uri (doc.file.get_uri ());
            doc.doc_saved.connect (reload_preview);
        }

        private void reload_preview () {
            var doc_uri = doc.file.get_uri ();
            if (web_view.uri != doc_uri) {
                web_view.load_uri (doc_uri);
            } else {
                web_view.reload ();
            }
        }
    }
}

