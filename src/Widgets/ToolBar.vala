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

namespace Scratch.Widgets {

    public class Toolbar : Gtk.Toolbar {

        private MainWindow window;

        ToolButton new_button;
        ToolButton open_button;
        ToolButton save_button;
        ToolButton undo_button;
        ToolButton repeat_button;
        public ToolItem combo_container;
        public ComboBoxText combobox;
        
        public string selected_language {
        	get { return combobox.get_active_id(); }
        }

        public ShareMenu share_menu;
        public MenuProperties menu;
        public ShareAppMenu share_app_menu;
        public AppMenu app_menu;
        public Scratch.SearchManager search_manager;
		
		public bool replace_active = false;
		public bool goto_active = false;
		
		public enum ToolButtons {
			NEW_BUTTON,
			OPEN_BUTTON,
			SAVE_BUTTON,
			UNDO_BUTTON,
			REPEAT_BUTTON,
			SHARE_BUTTON,
			APP_MENU_BUTTON
		}
		
		public enum ToolEntry {
			SEARCH_ENTRY,
			REPLACE_ENTRY,
			GOTO_ENTRY
		}

        public Toolbar (MainWindow parent, UIManager ui, Gtk.ActionGroup action_group) {

            this.window = parent;
            search_manager = new Scratch.SearchManager (action_group);

            // Toolbar properties
            // compliant with elementary HIG
			get_style_context ().add_class ("primary-toolbar");
            
            new_button = action_group.get_action("New tab").create_tool_item() as Gtk.ToolButton;
            open_button = action_group.get_action("Open").create_tool_item() as Gtk.ToolButton;
            save_button = action_group.get_action("SaveFile").create_tool_item() as Gtk.ToolButton;
            undo_button = action_group.get_action("Undo").create_tool_item() as Gtk.ToolButton;
            repeat_button = action_group.get_action("Redo").create_tool_item() as Gtk.ToolButton;
            
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
						
            share_menu = new ShareMenu (this.window);
            share_app_menu = new ShareAppMenu (share_menu);

            menu = new MenuProperties (this.window);
            plugins.hook_main_menu(menu);
            app_menu = (window.get_application() as Granite.Application).create_appmenu(menu);
            plugins.hook_toolbar(this);
			
            add (add_spacer ());
            add (search_manager.get_search_entry ());
            add (new SeparatorToolItem ());
            add (search_manager.get_replace_entry ());
            add (search_manager.get_go_to_entry ());
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
        
        public void set_actions (bool val) {
            combobox.set_sensitive (val);
            combo_container.set_sensitive (val);
            share_app_menu.set_sensitive(val);
        }
        
        private void set_combobox_text () {
	   //combobox.append (_("File language"));
           combobox.append ("text", _("Normal Text"));
           combobox.append ("sh", "Bash");
           combobox.append ("c", "C");
           combobox.append ("c-sharp", "C#");
           combobox.append ("cpp", "C++");
		   combobox.append ("cmake", "CMake");
           combobox.append ("css", "CSS");
           combobox.append ("desktop", ".desktop");
           combobox.append ("diff", "Diff");
           combobox.append ("fortran", "Fortran"); 
           combobox.append ("gettext-translation", "Gettext");
           combobox.append ("html", "HTML");
           combobox.append ("ini", "INI");
           combobox.append ("java", "Java");
           combobox.append ("js", "JavaScript");
           combobox.append ("latex", "Latex"); 
           combobox.append ("lua", "Lua");
           combobox.append ("makefile", "Makefile");
           combobox.append ("objc", "Objective-C"); 
           combobox.append ("pascal", "Pascal"); 
           combobox.append ("perl", "Perl");
           combobox.append ("php", "PHP");
           combobox.append ("python", "Python");   	
           combobox.append ("ruby", "Ruby");
           combobox.append ("vala", "Vala");
           combobox.append ("xml", "XML");
           /* IMPORTANT: if you add an item in this list, check also pastebin dialog list */
           
           combobox.set_active (0);
        }


        private void set_tooltip () {
        	new_button.set_tooltip_text(_("Create a new file in a new tab"));
        	open_button.set_tooltip_text(_("Open a file"));
			save_button.set_tooltip_text(_("Save the current file"));
       		undo_button.set_tooltip_text(_("Undo the last action"));
        	repeat_button.set_tooltip_text(_("Redo the last undone action"));
			share_menu.set_tooltip_text(_("Share this file"));
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
 			    
 			    case ToolButtons.SHARE_BUTTON:
 				//this.share_app_menu.set_sensitive(sensitive);
				controll_for_share_plugins ();
				break;
				
				case ToolButtons.APP_MENU_BUTTON:
 				this.app_menu.set_sensitive(sensitive);
				break;
 			    
 			}
 		
 		
 		}
 		
 		public void controll_for_share_plugins () {
 			
 			if (share_menu.get_children ().length () == 0) {
        		share_app_menu.no_show_all = true;
        		share_app_menu.hide();
            }
        	
 
 		}
}
} // Namespace  
