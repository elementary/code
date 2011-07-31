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

        private MainWindow window;

        public ToolButton new_button;
        public ToolButton open_button;
        public ToolButton save_button;
        public ToolButton undo_button;
        public ToolButton repeat_button;
        public ToolItem combo_container;
        public ComboBoxText combobox;
        
        public Entry entry;
        public AppMenu app_menu;

        public Toolbar (MainWindow parent) {

            this.window = parent;

            // Toolbar properties
            // compliant with elementary HIG
			get_style_context ().add_class ("primary-toolbar");
            
            new_button = new ToolButton.from_stock (Stock.NEW);
            open_button = new ToolButton.from_stock (Stock.OPEN);
            save_button = new ToolButton.from_stock (Stock.SAVE);
            undo_button = new ToolButton.from_stock (Stock.UNDO);
            repeat_button = new ToolButton.from_stock (Stock.REDO);
            
            combobox = new ComboBoxText ();
            set_combobox_text ();
            
            add (new_button);
            add (open_button);
            add (save_button);
            add (new SeparatorToolItem ());
            add (undo_button);
            add (repeat_button);

            add (new SeparatorToolItem ());
            add (toolitem (combobox, false));

            entry = new SearchBar ("Search in the text...");

            var menu = new MenuProperties (this.window);

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
        
        private void set_combobox_text () {
           combobox.append_text ("Normal Text");
           combobox.append_text ("C");
           combobox.append_text ("C#");
           combobox.append_text ("C++");
           combobox.append_text ("CSS");
           combobox.append_text ("CMake");
           combobox.append_text (".desktop");
           combobox.append_text ("Diff");
           combobox.append_text ("Fortran"); 
           combobox.append_text ("Gettext");
           combobox.append_text ("HTML");
           combobox.append_text ("ini");
           combobox.append_text ("Java");
           combobox.append_text ("JavaScript");
           combobox.append_text ("Latex"); 
           combobox.append_text ("Lua");
           combobox.append_text ("Makefile");
           combobox.append_text ("Objective-C"); 
           combobox.append_text ("Perl");
           combobox.append_text ("PHP");
           combobox.append_text ("Pascal"); 
           combobox.append_text ("Python");   	
           combobox.append_text ("Ruby");
           combobox.append_text ("sh");
           combobox.append_text ("Vala");
           combobox.append_text ("XML");
           combobox.set_active (0);
        }
        
        
     
}
} // Namespace   
