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

namespace Scratch.Widgets {
	
    public enum NotificationType {
        NO_WRITE
    }

    public class NotificationBar : Gtk.InfoBar {
        
        private string filename;
        private Scratch.Services.Document doc;
        private NotificationType type;
        
        Gtk.Label label;
        
        public NotificationBar () {
            set_message_type (Gtk.MessageType.QUESTION);

            label = new Gtk.Label ("");
            label.halign = Gtk.Align.START;
            label.use_markup = true;

            var no = new Gtk.Button.with_label (("   ") + _("No") + ("   "));
            no.clicked.connect (() => {
                hide ();
                no_show_all = true;                    
            });

            var yes = new Gtk.Button.with_label (("   ") + _("Yes") + ("   "));
            yes.clicked.connect (() => {
                if (type == NotificationType.NO_WRITE) {
                    
                    var mw = get_toplevel () as MainWindow;
                    
                    var f = File.new_for_path (filename);
                    
                    var filech = new FileChooserDialog (_("Choose the new location"), mw, FileChooserAction.SELECT_FOLDER, null);
                    filech.add_button (Stock.CANCEL, ResponseType.CANCEL);
                    filech.add_button (Stock.OPEN, ResponseType.ACCEPT);
                    filech.set_default_response (ResponseType.ACCEPT);

                    if (filech.run () == ResponseType.ACCEPT) {
                        try {
                            GLib.FileUtils.set_contents (filech.get_filename () + "/" + f.get_basename (), doc.tab.text_view.buffer.text);
                            doc.tab.filename = filech.get_filename () + "/" + f.get_basename ();
                            doc.save ();
                        } catch (Error e) { warning (e.message); }
                    }
                    filech.destroy ();
                }   
                hide ();
                no_show_all = true;
            });

            pack_start (label, true, true, 3);
            pack_end (yes, false, false, 3);
            pack_end (no, false, false, 3);

            no_show_all = false;

        }
        
        public void set_notification_label (string text) {
            label.set_markup (text);
        }
        
        public void set_attributes (string filename, Scratch.Services.Document doc) {
            this.filename = filename;
            this.doc = doc;
        }
        
        public void set_notification_type (NotificationType type) {
            this.type = type;
        }
    }
}