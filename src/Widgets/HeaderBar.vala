// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*
* Copyright (c) 2013 Mario Guerriero <mefrio.g@gmail.com>
*               2017-2018 elementary LLC. <https://elementary.io>
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 3 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*/

namespace Scratch.Widgets {
    public class HeaderBar : Gtk.HeaderBar {
        public Gtk.Menu share_menu;
        public Gtk.MenuButton share_app_menu;
        public Gtk.MenuButton app_menu;
        public Gtk.ToggleButton find_button;
        public Gtk.Button templates_button;
        public Code.FormatBar format_bar;

        public HeaderBar () {
            Object (
                has_subtitle: false,
                show_close_button: true
            );
        }

        construct {
            var open_button = new Gtk.Button.from_icon_name ("document-open", Gtk.IconSize.LARGE_TOOLBAR);
            open_button.action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_OPEN;
            open_button.tooltip_text = _("Open a file");

            templates_button = new Gtk.Button.from_icon_name ("text-x-generic-template", Gtk.IconSize.LARGE_TOOLBAR);
            templates_button.action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_TEMPLATES;
            templates_button.tooltip_text = _("Project templates");

            var save_button = new Gtk.Button.from_icon_name ("document-save", Gtk.IconSize.LARGE_TOOLBAR);
            save_button.action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_SAVE;
            save_button.tooltip_text = _("Save this file");

            var save_as_button = new Gtk.Button.from_icon_name ("document-save-as", Gtk.IconSize.LARGE_TOOLBAR);
            save_as_button.action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_SAVE_AS;
            save_as_button.tooltip_text = _("Save this file with a different name");

            var revert_button = new Gtk.Button.from_icon_name ("document-revert", Gtk.IconSize.LARGE_TOOLBAR);
            revert_button.action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_REVERT;
            revert_button.tooltip_text = _("Restore this file");

            find_button = new Gtk.ToggleButton ();
            find_button.action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_SHOW_FIND;
            find_button.image = new Gtk.Image.from_icon_name ("edit-find", Gtk.IconSize.LARGE_TOOLBAR);
            find_button.tooltip_text = _("Find…");

            share_menu = new Gtk.Menu ();
            share_app_menu = new Gtk.MenuButton ();
            share_app_menu.image = new Gtk.Image.from_icon_name ("document-export", Gtk.IconSize.LARGE_TOOLBAR);
            share_app_menu.no_show_all = true;
            share_app_menu.tooltip_text = _("Share");
            share_app_menu.set_popup (share_menu);

            var zoom_out_button = new Gtk.Button.from_icon_name ("zoom-out-symbolic", Gtk.IconSize.MENU);
            zoom_out_button.action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_ZOOM_OUT;
            zoom_out_button.tooltip_text = _("Zoom Out");

            var zoom_default_button = new Gtk.Button.with_label ("100%");
            zoom_default_button.action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_ZOOM_DEFAULT;
            zoom_default_button.tooltip_text = _("Zoom 1:1");

            var zoom_in_button = new Gtk.Button.from_icon_name ("zoom-in-symbolic", Gtk.IconSize.MENU);
            zoom_in_button.action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_ZOOM_IN;
            zoom_in_button.tooltip_text = _("Zoom In");

            var font_size_grid = new Gtk.Grid ();
            font_size_grid.column_homogeneous = true;
            font_size_grid.hexpand = true;
            font_size_grid.margin = 12;
            font_size_grid.get_style_context ().add_class (Gtk.STYLE_CLASS_LINKED);
            font_size_grid.add (zoom_out_button);
            font_size_grid.add (zoom_default_button);
            font_size_grid.add (zoom_in_button);

            var new_view_menuitem = new Gtk.ModelButton ();
            new_view_menuitem.text = _("Add New View");
            new_view_menuitem.action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_NEW_VIEW;

            var remove_view_menuitem = new Gtk.ModelButton ();
            remove_view_menuitem.text = _("Remove Current View");
            remove_view_menuitem.action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_REMOVE_VIEW;

            var preferences_menuitem = new Gtk.ModelButton ();
            preferences_menuitem.text = _("Preferences");
            preferences_menuitem.action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_PREFERENCES;

            var menu_grid = new Gtk.Grid ();
            menu_grid.margin_bottom = 3;
            menu_grid.orientation = Gtk.Orientation.VERTICAL;
            menu_grid.width_request = 200;
            menu_grid.add (font_size_grid);
            menu_grid.add (new Gtk.Separator (Gtk.Orientation.HORIZONTAL));
            menu_grid.add (new_view_menuitem);
            menu_grid.add (remove_view_menuitem);
            menu_grid.add (preferences_menuitem);
            menu_grid.show_all ();

            var menu = new Gtk.Popover (null);
            menu.add (menu_grid);

            var app_menu = new Gtk.MenuButton ();
            app_menu.image = new Gtk.Image.from_icon_name ("open-menu", Gtk.IconSize.LARGE_TOOLBAR);
            app_menu.tooltip_text = _("Menu");
            app_menu.popover = menu;

            format_bar = new Code.FormatBar ();
            format_bar.no_show_all = true;
            set_custom_title (format_bar);

            pack_start (open_button);
            pack_start (templates_button);
            pack_start (save_button);
            pack_start (save_as_button);
            pack_start (new Gtk.Separator (Gtk.Orientation.HORIZONTAL));
            pack_start (revert_button);
            pack_end (app_menu);
            pack_end (share_app_menu);
            pack_end (new Gtk.Separator (Gtk.Orientation.HORIZONTAL));
            pack_end (find_button);

            show_all ();

            share_menu.insert.connect (on_share_menu_changed);
            share_menu.remove.connect (on_share_menu_changed);

            settings.changed.connect (() => {
                save_button.visible = !settings.autosave;
                var last_window = Application.instance.get_last_window ();
                zoom_default_button.label = "%.0f%%".printf (last_window.get_current_font_size () * 10);
            });

        }

        private void on_share_menu_changed () {
            if (share_menu.get_children ().length () > 0) {
                share_app_menu.no_show_all = false;
                share_app_menu.visible = true;
                share_app_menu.show_all ();
            } else {
                share_app_menu.no_show_all = true;
                share_app_menu.visible = false;
                share_app_menu.hide ();
            }
        }

        public void document_available (bool has_document) {
            if (has_document) {
                format_bar.no_show_all = false;
                format_bar.show_all ();
            } else {
                format_bar.no_show_all = true;
                format_bar.hide ();
            }
        }

        public void set_document_focus (Scratch.Services.Document doc) {
            format_bar.set_document (doc);
        }
    }
}
