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

namespace Scratch.Widgets {

    public class Toolbar : Gtk.Toolbar {

        MainWindow parent;

        public ToolButton new_button;
        public ToolButton open_button;
        public ToolButton save_button;
        public ToolButton undo_button;
        public ToolButton repeat_button;
        public ToolItem combo_container;
        public ComboBox combobox;
        
        public Entry entry;
        public AppMenu app_menu;


        public Toolbar (MainWindow parent) {

            this.parent = parent;

            // Toolbar properties
            // compliant with elementary HIG
			get_style_context ().add_class ("primary-toolbar");
            
            new_button = new ToolButton.from_stock (Stock.NEW);
            open_button = new ToolButton.from_stock (Stock.OPEN);
            save_button = new ToolButton.from_stock (Stock.SAVE);
            undo_button = new ToolButton.from_stock (Stock.UNDO);
            repeat_button = new ToolButton.from_stock (Stock.REDO);
            
            combobox = new ComboBox ();
            
            add (new_button);
            add (open_button);
            add (save_button);
            add (new SeparatorToolItem ());
            add (undo_button);
            add (repeat_button);

            add (new SeparatorToolItem ());
            add (toolitem (combobox, false));

            entry = new SearchBar ("Search in the text...");
                
            var menu = new MenuProperties ();     
            app_menu = new AppMenu (menu);

            add (add_spacer ());
            add (toolitem (entry));
            add (app_menu);

        }

        private ToolItem add_spacer () {
			
			var spacer = new ToolItem ();
			spacer.set_expand (true);
			
			return spacer;
			
		}
		
		private ToolItem toolitem (Widget widget, bool expand = true, int border_width = 0) {
		
		    var new_tool_item = new ToolItem ();
		    new_tool_item.add (widget);

		    if (border_width > 0) {
		        new_tool_item.set_border_width (border_width);
		    }
            new_tool_item.set_expand (expand);

		    return new_tool_item;
    
        }
    }
} // Namespace   
