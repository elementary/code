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
using Scratch.Widgets;

namespace Scratch.Dialogs {

    private class WarnDialog : MessageDialog {

        MainWindow window;

        public WarnDialog (string filename, MainWindow? window) {

	        this.window = window;
            this.title = title;
            this.set_transient_for (window);
	        set_default_size (300, 150);
            modal = true;
            resizable = false;
	        
	        message_type = MessageType.WARNING;
            use_markup = true;
	        
	        text = "<b>" + _("The file:") + " \"" + filename + "\" " + "was modified." + "</b>";
            text += "\n\n" + _("Do you want to reload it?");
	        
	        add_button (Stock.REFRESH, ResponseType.ACCEPT);
            add_button (Stock.CLOSE, ResponseType.CANCEL);
            
            response.connect (on_response);
                
        }

        void on_response (int response) {
        
            switch (response) {
                case ResponseType.ACCEPT:
                    window.current_document.reload ();
                    window.current_document.save ();
                    destroy ();
                break;
                case ResponseType.CANCEL:
                    window.current_document.set_label_font ("modified");
                    destroy ();
                break;
            }
        
        }

    }
}
