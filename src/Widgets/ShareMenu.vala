// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
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

    public class ShareMenu : Gtk.Menu {
        
        private Window window;
        /*private MenuItem pastebin;*/
        //private MenuItem share_email;

        public ShareMenu (MainWindow window) {

            this.window = window;

            plugins.hook_addons_menu(this);


        }

    }

    public class ShareAppMenu : ToolButtonWithMenu {

        public ShareAppMenu (Gtk.Menu menu) {

            base (new Image.from_icon_name ("document-export", IconSize.MENU), "Share", menu);

        }


    }

}
