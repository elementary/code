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
        public ShareMenu share_menu;
        public AppMenu app_menu;

		public enum ToolButtons {
			NEW_BUTTON,
			OPEN_BUTTON,
			SAVE_BUTTON,
			UNDO_BUTTON,
			REPEAT_BUTTON,
		}

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

            entry = new SearchBar (_("Search in the text..."));
            entry.width_request = 250;

            share_menu = new ShareMenu (this.window);
            var share_app_menu = new ShareAppMenu (share_menu);

            var menu = new MenuProperties (this.window);
            app_menu = new AppMenu (menu);

            add (add_spacer ());
            add (toolitem (entry, false));
            add (share_app_menu);
            add (app_menu);
            
            set_tooltip ();

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
	   //combobox.append (_("File language"));
           combobox.append ("normal", _("Normal Text"));
           combobox.append ("c", "C");
           combobox.append ("c-sharp", "C#");
           combobox.append ("cpp", "C++");
           combobox.append ("css", "CSS");
           combobox.append ("cmake", "CMake");
           combobox.append ("desktop", ".desktop");
           combobox.append ("diff", "Diff");
           combobox.append ("fortran", "Fortran"); 
           combobox.append ("gettext-translation", "Gettext");
           combobox.append ("html", "HTML");
           combobox.append ("ini", "ini");
           combobox.append ("java", "Java");
           combobox.append ("js", "JavaScript");
           combobox.append ("latex", "Latex"); 
           combobox.append ("lua", "Lua");
           combobox.append ("makefile", "Makefile");
           combobox.append ("objc", "Objective-C"); 
           combobox.append ("perl", "Perl");
           combobox.append ("php", "PHP");
           combobox.append ("pascal", "Pascal"); 
           combobox.append ("python", "Python");   	
           combobox.append ("ruby", "Ruby");
           combobox.append ("sh", "sh");
           combobox.append ("vala", "Vala");
           combobox.append ("xml", "XML");
           combobox.set_active (0);
        }
        
        private void set_tooltip () {
        	new_button.set_tooltip_text(_("Create a new file in a new tab"));
        	open_button.set_tooltip_text(_("Open an existing file"));
		save_button.set_tooltip_text(_("Save the current file"));
       		undo_button.set_tooltip_text(_("Cancel the last operation"));
        	repeat_button.set_tooltip_text(_("Repeat the last cancelled operation"));
		share_menu.set_tooltip_text(_("Share this file with others"));
        }
        
 		public void set_button_sensitive(int button, bool sensitive) {
 		
 			switch (button) {
 				case ToolButtons.NEW_BUTTON:
 				this.new_button.set_sensitive(sensitive);
 				break;
 				 					
				case ToolButtons.OPEN_BUTTON:
 				this.open_button.set_sensitive(sensitive);
				break;
				
				case ToolButtons.SAVE_BUTTON:
 				this.save_button.set_sensitive(sensitive);
				break;
				
				case ToolButtons.UNDO_BUTTON:
 				this.undo_button.set_sensitive(sensitive);				
				break;
				
				case ToolButtons.REPEAT_BUTTON:
 				this.repeat_button.set_sensitive(sensitive);
				break;
 			
 			}
 		
 		
 		}
        
     
}
} // Namespace   
