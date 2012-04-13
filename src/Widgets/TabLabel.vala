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
using Gdk;

namespace Scratch.Widgets {

    public class TabLabel : HBox {

        public HBox tablabel;
        private EventBox event_box;
        public Label label;
        public Entry entry;
        public Button close;
        private Tab tab;

        public string label_text;

        public TabLabel (Tab my_tab, string labeltext) {

            homogeneous = false;

            this.tab = my_tab;

            label_text = labeltext;
            label = new Label (labeltext);
            label.use_markup = true;
            entry = new Entry ();

            event_box = new EventBox ();
            event_box.set_visible_window (false);
            event_box.add (label);

            var image = new Image.from_stock(Stock.CLOSE, IconSize.MENU);
            close = new Button ();
            close.clicked.connect (my_tab.on_close_clicked);
            close.set_relief (ReliefStyle.NONE);
            close.set_image (image);

            if (is_close_first ()) {
                pack_start (close, false, false, 0);
                pack_start (event_box, false, false, 0);
            } else {
                pack_start (event_box, false, false, 0);
                pack_start (close, false, false, 0);
            }

            event_box.button_press_event.connect (click_event);

            this.show_all ();
            button_press_event.connect(on_main_click);
        }

        bool on_main_click(Gdk.EventButton event) {
            if(event.button == 2) {
                tab.on_close_clicked();
                return true;
            }

            return false;
        }

        protected bool click_event (EventButton event) {

            string filename = tab.filename;

            if (filename != null) {

                if ((event.type == EventType.2BUTTON_PRESS) || (event.type == EventType.3BUTTON_PRESS)) {
                    if (tab.document.state == Scratch.Services.DocumentStates.NORMAL) {
                        event_box.hide ();
                        add (entry);
                        entry.text = label.get_text ();
                        entry.show ();
                        entry.grab_focus ();
                        entry.key_press_event.connect (return_event);
                        entry.focus_out_event.connect (on_entry_focus_out);
                    }
                }
            }
            return false;
        }

        protected bool return_event (EventKey event) {
            if (event.keyval == 65293) { // 65293 is the return key
                string old = tab.document.filename;
                var sold = old.split ("/");
                string newname = "";
                foreach (string s in sold) {
                    if (s != "" && s != sold[sold.length-1])
                        newname = newname +  "/" + s;
                    if (s == sold[sold.length-1])
                        newname = newname +  "/" + entry.text;
                }
                
                debug ("%s", newname);
                
                entry.hide ();
                event_box.show ();
                tab.filename = newname;
                tab.document.rename (newname);
                
                label.label = entry.text;
            }
            return false;
        }
        
        private bool on_entry_focus_out (EventFocus event) {
            string old = tab.document.filename;
            var sold = old.split ("/");
            string newname = "";
            foreach (string s in sold) {
                if (s != "" && s != sold[sold.length-1])
                    newname = newname +  "/" + s;
                if (s == sold[sold.length-1])
                    newname = newname +  "/" + entry.text;
            }
              
            debug ("%s", newname);
                
            entry.hide ();
            event_box.show ();
            tab.filename = newname;
            tab.document.rename (newname);
               
            label.label = entry.text;
            
            return true;
        }
        
        private bool is_close_first () {

            string path = "/apps/metacity/general/button_layout";
            GConf.Client cl = GConf.Client.get_default ();
            string key;

            try {
                if (cl.get (path) != null)
                    key = cl.get_string (path);
                else
                    return false;
            } catch (GLib.Error err) {
                warning ("Unable to read metacity settings: %s", err.message);
            }

            string[] keys = key.split (":");
            if ("close" in keys[0])
                return true;
            else
                return false;

        }

    }
}
