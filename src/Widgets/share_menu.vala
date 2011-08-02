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
using Granite.Widgets;

using Scratch.Dialogs;

namespace Scratch.Widgets {

    public class ShareMenu : Menu {
        
        private Window window;
        private MenuItem pastebin;
        private MenuItem share_email;

        public ShareMenu (MainWindow window) {

            this.window = window;

            pastebin = new MenuItem.with_label ("Upload to Pastebin...");
            share_email = new MenuItem.with_label ("Share via email...");

            append (pastebin);
            append (share_email);

            pastebin.activate.connect (() => {new PasteBinDialog (window);});

        }

    }

    public class ShareAppMenu : ToolButtonWithMenu {

        public ShareAppMenu (Menu menu) {

            base (new Image.from_icon_name ("document-import", IconSize.MENU), "Share", menu);

        }


    }

}
