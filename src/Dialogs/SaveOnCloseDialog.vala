/***
  BEGIN LICENSE

  Copyright (C) 2011 Giulio Collura <random.cpp@gmail.com>
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

namespace Scratch.Dialogs {

    public class SaveOnCloseDialog : MessageDialog {

        private string filename;
        private MainWindow window;

        public SaveOnCloseDialog (string? filename, MainWindow window) {

            this.type_hint = Gdk.WindowTypeHint.DIALOG;
            this.set_modal (true);
            this.set_transient_for (window);
            this.filename = filename;
            this.window = window;

            message_type = MessageType.WARNING;
            use_markup = true;

            text = _("Save this file? ") + (filename ?? _("New File"));
            text += "\n\n<b>" + _("All your work will be lost!") + "</b>";

            add_button (Stock.CANCEL, ResponseType.CANCEL);
            add_button (Stock.DISCARD, ResponseType.NO);
            add_button (Stock.SAVE, ResponseType.YES);
            set_default_response (ResponseType.ACCEPT);
        }
    }
}
