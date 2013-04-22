// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/***
  BEGIN LICENSE

  Copyright (C) 2013 Mario Guerriero <mario@elementaryos.org>
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

using Scratch.Services;

namespace Scratch.Widgets {

    public class Notebook : Granite.Widgets.DynamicNotebook {
        
        
        
        public Notebook () {
            // General objects
            var tab = new Granite.Widgets.Tab ("New Document",
                                            new ThemedIcon ("empty"),
                                            new Scratch.Widgets.SourceView ());
            tab.working = true;

            this.insert_tab (tab, -1);
        }
        
    }

}
