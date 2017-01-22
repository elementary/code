// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/***
  BEGIN LICENSE

  Copyright (C) 2013 Mario Guerriero <mario@elementaryos.org>
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

namespace Scratch.Widgets {

    public class Toolbar : Gtk.HeaderBar {

        public Gtk.ToolButton open_button;
        public Gtk.ToolButton templates_button;
        public Gtk.ToolButton save_button;
        public Gtk.ToolButton save_as_button;
        public Gtk.ToolButton revert_button;
        public Gtk.ToggleToolButton find_button;
        public Gtk.ToolButton zoom_default;

        public Gtk.Menu share_menu;
        public Gtk.Menu menu;

        public Gtk.MenuButton share_app_menu;
        public Gtk.MenuButton app_menu;

        public Toolbar (Gtk.ActionGroup main_actions, Gtk.Menu menu) {
            this.menu = menu;
            // Toolbar properties
            // compliant with elementary HIG
            get_style_context ().add_class ("primary-toolbar");
            
            // Create ToolButtons
            open_button = main_actions.get_action ("Open").create_tool_item () as Gtk.ToolButton;
            templates_button = main_actions.get_action ("Templates").create_tool_item () as Gtk.ToolButton;
            save_button = main_actions.get_action ("SaveFile").create_tool_item () as Gtk.ToolButton;
            save_as_button = main_actions.get_action ("SaveFileAs").create_tool_item () as Gtk.ToolButton;
            revert_button = main_actions.get_action ("Revert").create_tool_item () as Gtk.ToolButton;
            find_button = main_actions.get_action ("ShowFetch").create_tool_item () as Gtk.ToggleToolButton;
            zoom_default = main_actions.get_action ("Zoom").create_tool_item () as Gtk.ToolButton;

            // Create Share and AppMenu
            share_menu = new Gtk.Menu ();
            share_app_menu = new Gtk.MenuButton ();
            share_app_menu.image = new Gtk.Image.from_icon_name ("document-export", Gtk.IconSize.LARGE_TOOLBAR);
            share_app_menu.tooltip_text = _("Share");
            share_app_menu.set_popup (share_menu);

            var share_app_menu_tool = new Gtk.ToolItem ();
            share_app_menu_tool.add (share_app_menu);

            var app_menu = new Gtk.MenuButton ();
            app_menu.image = new Gtk.Image.from_icon_name ("open-menu", Gtk.IconSize.LARGE_TOOLBAR);
            app_menu.tooltip_text = _("Menu");
            app_menu.popup = menu;

            share_menu.insert.connect (() => {
                if (share_menu.get_children ().length () > 0) {
                    share_app_menu.no_show_all = false;
                    share_app_menu.visible = true;
                    share_app_menu.show_all ();
                } else {
                    share_app_menu.no_show_all = true;
                    share_app_menu.visible = false;
                    share_app_menu.hide ();
                }
            });

            share_menu.remove.connect (() => {
                if (share_menu.get_children ().length () > 0) {
                    share_app_menu.no_show_all = false;
                    share_app_menu.visible = true;
                    share_app_menu.show_all ();
                } else {
                    share_app_menu.no_show_all = true;
                    share_app_menu.visible = false;
                    share_app_menu.hide ();
                }
            });

            share_app_menu.no_show_all = true;

            // Add everything to the toolbar
            pack_start (open_button);
            pack_start (templates_button);
            pack_start (save_button);
            pack_start (save_as_button);
            pack_start (new Gtk.SeparatorToolItem ());
            pack_start (revert_button);

            pack_end (app_menu);
            pack_end (share_app_menu_tool);
            pack_end (new Gtk.SeparatorToolItem ());
            pack_end (find_button);
            pack_end (zoom_default);

            // Show/Hide widgets
            show_all ();

            // Some signals...
            settings.changed.connect (() => {
                save_button.visible = !settings.autosave;
                zoom_default.visible = ScratchApp.instance.get_last_window ().get_default_font_size () != ScratchApp.instance.get_last_window ().get_current_font_size ();
            });

        }
    }
}
