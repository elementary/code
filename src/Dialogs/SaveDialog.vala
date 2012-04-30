/***
  BEGIN LICENSE

  Copyright (C) 2011-2012 Gabriele Coletta <gdmg92@gmail.com>
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

    private class SaveDialog : Window {

        private Tab caller;

        public SaveDialog (Tab callertab) {

            this.caller = callertab;
	   
            string path = callertab.document.filename;
            var file = File.new_for_path (path);
            string filename = file.get_basename ();
            
            Gtk.Label main_label;
            
            if (filename == null)
                main_label = new Label (_("Save unsaved changes to file before closing?"));
            else
                main_label = new Label (_("Save unsaved changes to file \"" + filename + "\" " + _("before closing?")));
            main_label.set_markup ("<b>%s</b>".printf(_(main_label.get_text ())));

            var label = new Label(_("Changes to this file haven't been saved.") + "\n" + _("Do you want to save changes before closing this file?"));
            var image = new Image.from_stock(Stock.DIALOG_WARNING, IconSize.DIALOG);

            var headbox = new Box (Orientation.HORIZONTAL, 10);
            var label_box = new Box (Orientation.VERTICAL, 10);
            headbox.pack_start (image, true, false, 5);
            label_box.pack_start (main_label, true, true, 5);
            label_box.pack_start (label, true, true, 5); 
            headbox.pack_start (label_box, true, true, 5);
            
            var discard = new Button.with_label(Stock.DISCARD);
            discard.set_use_stock(true);
            discard.clicked.connect(this.on_discard_clicked);
            
            var cancel = new Button.with_label(Stock.CANCEL);
            cancel.set_use_stock(true);
            cancel.clicked.connect(this.on_cancel_clicked);
            
            var save = new Button.with_label(Stock.SAVE);
            save.set_use_stock(true);
            save.clicked.connect(this.on_save_clicked);

            var buttonbox = new ButtonBox (Orientation.HORIZONTAL);
            buttonbox.set_margin_right (10);
            buttonbox.set_margin_left (10);
            buttonbox.set_spacing (5);
            buttonbox.set_margin_top (8);
            buttonbox.set_layout (ButtonBoxStyle.END);
            buttonbox.pack_start (cancel, false, false, 5);
            buttonbox.pack_start (discard, false, false, 5);
            buttonbox.pack_start (save, false, false, 5);

            var container = new Box (Orientation.VERTICAL, 10);
            container.pack_start (headbox, true, true, 5);
            container.pack_start (buttonbox, false, false, 5);

            //window properties
            this.title = "";
            this.set_skip_taskbar_hint(true);
            this.set_transient_for ((Gtk.Window)caller.get_toplevel());
            this.set_resizable(false);
            this.window_position  = WindowPosition.CENTER;

            this.add(container);

        }

        public void run() {
            this.show_all();
        }

        //responses
        private void on_discard_clicked() {
            this.destroy();
            caller.close();
        }

        private void on_cancel_clicked() {
            this.destroy();
        }

        private void on_save_clicked() {
            this.destroy();
            if (caller.save() == 0)
                caller.close();
        }


    }
}
