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

using Scratch.Services;

namespace Scratch.Widgets {

    public class Toolbar : Gtk.Toolbar {

        private MainWindow window;

        ToolButton new_button;
        ToolButton open_button;
        ToolButton save_button;
        ToolButton save_as_button;
        ToolButton undo_button;
        ToolButton repeat_button;
        public ToolButton revert_button;

        public ShareMenu share_menu;
        public MenuProperties menu;
        public ShareAppMenu share_app_menu;
        public AppMenu app_menu;

        public bool replace_active = false;
        public bool goto_active = false;

        public enum ToolButtons {
            NEW_BUTTON,
            OPEN_BUTTON,
            SAVE_BUTTON,
            UNDO_BUTTON,
            REPEAT_BUTTON,
            REVERT_BUTTON,
            SHARE_BUTTON,
            APP_MENU_BUTTON
        }

        public enum ToolEntry {
            SEARCH_ENTRY,
            REPLACE_ENTRY,
            GOTO_ENTRY
        }
        
        UIManager ui;

        public Toolbar (MainWindow parent, UIManager ui, Gtk.ActionGroup action_group) {

            this.window = parent;
            this.ui = ui;

            // Toolbar properties
            // compliant with elementary HIG
            get_style_context ().add_class ("primary-toolbar");

            new_button = action_group.get_action("New tab").create_tool_item() as Gtk.ToolButton;
            open_button = action_group.get_action("Open").create_tool_item() as Gtk.ToolButton;
            save_as_button = action_group.get_action("SaveFileAs").create_tool_item() as Gtk.ToolButton;
            save_button = action_group.get_action("SaveFile").create_tool_item() as Gtk.ToolButton;
            undo_button = action_group.get_action("Undo").create_tool_item() as Gtk.ToolButton;
            repeat_button = action_group.get_action("Redo").create_tool_item() as Gtk.ToolButton;
            revert_button = action_group.get_action("Revert").create_tool_item() as Gtk.ToolButton;

            add (new_button);
            add (open_button);
            add (save_button);
            add (save_as_button);
            add (new SeparatorToolItem ());
            add (revert_button);
            add (undo_button);
            add (repeat_button);

            add (new SeparatorToolItem ());

            share_menu = new ShareMenu (this.window);
            share_app_menu = new ShareAppMenu (share_menu);

            menu = new MenuProperties (this.window, action_group);
            plugins.hook_main_menu(menu);
            app_menu = (window.get_application() as Granite.Application).create_appmenu(menu);
            plugins.hook_toolbar(this);

            add (add_spacer ());
            add (app_menu);

            set_tooltip ();
        }
        
        Gtk.Menu menu_ui;
        
        public override bool button_press_event (Gdk.EventButton event) {
            if (event.button == 3) {
                (ui.get_widget ("ui/ToolbarContext") as Gtk.Menu).popup (null, null, null, event.button, Gtk.get_current_event_time ());
                return true;
            }
            return false;
        }

        private ToolItem add_spacer () {

            var spacer = new ToolItem ();
            spacer.set_expand (true);

            return spacer;

        }

        public void set_actions (bool val) {
            share_app_menu.set_sensitive(val);
        }

        private void set_tooltip () {
            revert_button.set_tooltip_text (_("Restore the current file"));
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

            case ToolButtons.REVERT_BUTTON:
                this.revert_button.set_sensitive(sensitive);
                break;
            case ToolButtons.SHARE_BUTTON:
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
