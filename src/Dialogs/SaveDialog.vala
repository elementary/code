/***
  BEGIN LICENSE
	
  Copyright (C) 2011 Gabriele Coletta <gdmg92@gmail.com>
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
        
        private Box headbox;
        private Label label;
        private Image image;

        private Box buttonbox;
        private Button discard;
        private Button cancel;
        private Button save;

        private Box container; 

        public SaveDialog (Tab callertab) {

            caller = callertab;
			
            label = new Label(_("Changes to this file haven't been saved.") + "\n" + _("Do you want to save changes before closing this file?"));
            image = new Image.from_stock(Stock.DIALOG_WARNING, IconSize.DIALOG);				
            
            headbox = new Box(Orientation.HORIZONTAL, 10);
            headbox.add(image);
            headbox.add(label);				
    
            discard = new Button.with_label(Stock.DISCARD);
                discard.set_use_stock(true);
                discard.clicked.connect(this.on_discard_clicked);
            cancel = new Button.with_label(Stock.CANCEL);
                cancel.set_use_stock(true);
                cancel.clicked.connect(this.on_cancel_clicked);
            save = new Button.with_label(Stock.SAVE);
                save.set_use_stock(true);
                save.clicked.connect(this.on_save_clicked);
    
            buttonbox = new Box (Orientation.HORIZONTAL, 10);
            buttonbox.set_homogeneous(true);
            buttonbox.add(discard);
            buttonbox.add(cancel);
            buttonbox.add(save);				

            container = new Box(Orientation.VERTICAL, 10);
            container.add(headbox);
            container.add(buttonbox);

            //window properties
            this.title = "";
            this.set_skip_taskbar_hint(true);
            this.set_modal(false);
            this.set_transient_for ((Gtk.Window)caller.get_toplevel());
            this.set_resizable(false);
    
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
