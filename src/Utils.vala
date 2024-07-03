// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*
* Copyright (c) 2013 Mario Guerriero <mefrio.g@gmail.com>
*               2017 elementary LLC. <https://elementary.io>
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

namespace Scratch.Utils {
    public string? last_path = null;

    public SimpleAction action_from_group (string action_name, SimpleActionGroup action_group) {
        return ((SimpleAction) action_group.lookup_action (action_name));
    }

    /* Ported (with corrections and improvements) from libdazzle
     * (https://gitlab.gnome.org/GNOME/libdazzle/-/blob/master/src/util/dzl-pango.c)
     */
    public string pango_font_description_to_css (Pango.FontDescription font_descr) {
        var sb = new StringBuilder ("");
        var mask = font_descr.get_set_fields ();
        if (Pango.FontMask.FAMILY in mask) {
            unowned string family = font_descr.get_family ();
            sb.append_printf ("font-family: \"%s\";", family);
        }

        if (Pango.FontMask.STYLE in mask) {
            var style = font_descr.get_style ();

            switch (style) {
                case Pango.Style.NORMAL:
                    sb.append ("font-style: normal;");
                    break;

                case Pango.Style.ITALIC:
                    sb.append ("font-style: italic;");
                    break;

                case Pango.Style.OBLIQUE:
                    sb.append ("font-style: bold;");
                    break;

                default:
                    break;
            }
        }

        if (Pango.FontMask.VARIANT in mask) {
            var variant = font_descr.get_variant ();
            switch (variant) {
                case Pango.Variant.NORMAL:
                    sb.append ("font-variant: normal;");
                    break;

                case Pango.Variant.SMALL_CAPS:
                    sb.append ("font-variant: small-caps");
                    break;

                default:
                    break;
            }
        }

        if (Pango.FontMask.WEIGHT in mask) {
            var weight = ((int)(font_descr.get_weight () / 100 * 100)).clamp (100, 900);

            sb.append_printf ("font-weight: %i;", weight);
        }

        if (Pango.FontMask.STRETCH in mask) {
            var stretch = font_descr.get_stretch ();

            switch (stretch) {
                case Pango.Stretch.NORMAL:
                    sb.append_printf ("font-stretch: %s;", "normal");
                    break;

                case Pango.Stretch.ULTRA_CONDENSED:
                    sb.append_printf ("font-stretch: %s;", "condensed");
                    break;

                case Pango.Stretch.EXTRA_CONDENSED:
                    sb.append_printf ("font-stretch: %s;", "extra-condensed");
                    break;

                case Pango.Stretch.CONDENSED:
                    sb.append_printf ("font-stretch: %s;", "condensed");
                    break;

                case Pango.Stretch.SEMI_CONDENSED:
                    sb.append_printf ("font-stretch: %s;", "normal");
                    break;

                case Pango.Stretch.SEMI_EXPANDED:
                    sb.append_printf ("font-stretch: %s;", "semi-expanded");
                    break;

                case Pango.Stretch.EXPANDED:
                    sb.append_printf ("font-stretch: %s;", "expanded");
                    break;

                case Pango.Stretch.EXTRA_EXPANDED:
                    sb.append_printf ("font-stretch: %s;", "extra-expanded");
                    break;

                case Pango.Stretch.ULTRA_EXPANDED:
                    sb.append_printf ("font-stretch: %s;", "ultra-expanded");
                    break;

                default:
                    break;

            }
        }

        if (Pango.FontMask.SIZE in mask) {
            var font_size = font_descr.get_size () / Pango.SCALE;
            sb.append_printf ("font-size: %dpt;", font_size);
        }

        return sb.str;
    }

    public string replace_home_with_tilde (string path) {
        var home_dir = Environment.get_home_dir ();
        if (path.has_prefix (home_dir)) {
            return "~" + path.substring (home_dir.length);
        } else {
            return path;
        }
    }

    public bool find_unique_path (File f1, File f2, out string? path1, out string? path2) {
        if (f1.equal (f2)) {
            path1 = null;
            path2 = null;
            return false;
        }

        var f1_parent = f1.get_parent ();
        var f2_parent = f2.get_parent ();

        while (f1_parent.get_relative_path (f1) == f2_parent.get_relative_path (f2)) {
            f1_parent = f1_parent.get_parent ();
            f2_parent = f2_parent.get_parent ();
        }

        path1 = f1_parent.get_relative_path (f1);
        path2 = f2_parent.get_relative_path (f2);
        return true;
    }

    public bool check_if_valid_text_file (string path, FileInfo info) {
        if (path.has_prefix (".goutputstream")) {
            return false;
        }

        if (info.get_is_backup ()) {
            return false;
        }

        var content_type = info.get_content_type ();
        if (info.get_file_type () == FileType.REGULAR &&
            ContentType.is_a (content_type, "text/*") ||
            ContentType.is_a (content_type, "application/x-zerosize")
            ) {

            return true;
        }

        return false;
    }

    public void create_executable_app_items_for_file (GLib.File file, string file_type, Gtk.Menu menu) {
        List<AppInfo> external_apps = GLib.AppInfo.get_all_for_type (file_type);
        var files_appinfo = AppInfo.get_default_for_type ("inode/directory", true);
        external_apps.prepend (files_appinfo);

        string this_id = GLib.Application.get_default ().application_id + ".desktop";

        foreach (AppInfo app_info in external_apps) {
            string app_id = app_info.get_id ();
            if (app_id == this_id) {
                continue;
            }

            var menuitem_icon = new Gtk.Image.from_gicon (
                app_info.get_icon (),
                Gtk.IconSize.MENU
            );
            menuitem_icon.pixel_size = 16;

            var menuitem_grid = new Gtk.Grid ();
            menuitem_grid.add (menuitem_icon);
            menuitem_grid.add (new Gtk.Label (app_info.get_name ()));

            var menuitem = new Gtk.MenuItem () {
                action_name = Scratch.FolderManager.FileView.ACTION_PREFIX
                    + Scratch.FolderManager.FileView.ACTION_LAUNCH_APP_WITH_FILE_PATH,
                action_target = new GLib.Variant.array (
                    GLib.VariantType.STRING,
                    { file.get_path (), app_id, file_type }
                )
            };

            menuitem.add (menuitem_grid);

            menu.add (menuitem);
        }
    }


    public void launch_app_with_file (AppInfo app_info, GLib.File file) {
        var file_list = new List<GLib.File> ();
        file_list.append (file);

        try {
            app_info.launch (file_list, null);
        } catch (Error e) {
            warning (e.message);
        }
    }

    public void launch_app_with_file_path (string path, string app_id, string file_type) {
        var file = GLib.File.new_for_path (path);
        var file_list = new List<GLib.File> ();
        file_list.append (file);
        var app_info = new GLib.DesktopAppInfo (app_id);
        try {
            app_info.launch (file_list, null);
            print ("Launching app!\n");
        } catch (Error e) {
            warning (e.message);
        }
    }

    public GLib.Menu create_contract_items_for_file (GLib.File file, string file_type) {
        var menu = new GLib.Menu ();

        try {
            var contracts = Granite.Services.ContractorProxy.get_contracts_by_mime (file_type);
            foreach (var contract in contracts) {
                string contract_name = contract.get_display_name ();
                var menu_item = new MenuItem (
                    contract_name,
                    Scratch.FolderManager.FileView.ACTION_PREFIX
                    + Scratch.FolderManager.FileView.ACTION_EXECUTE_CONTRACT_WITH_FILE_PATH
                );

                menu_item.set_attribute_value (GLib.Menu.ATTRIBUTE_TARGET, new GLib.Variant.array (
                    GLib.VariantType.STRING,
                    { file.get_path (), contract_name, file_type })
                );

                menu.append_item (menu_item);
            }
        } catch (Error e) {
            warning (e.message);
        }

        return menu;
    }


    public void execute_contract_with_file_path (string path, string contract_name, string file_type) {
        var file = GLib.File.new_for_path (path);

        try {
            var contracts = Granite.Services.ContractorProxy.get_contracts_by_mime (file_type);
            int length = contracts.size;
            for (int i = 0; i < length; i++) {
                var contract = contracts[i];
                if (contract.get_display_name () == contract_name) {
                    contract.execute_with_file (file);
                    break;
                }
            }
        } catch (Error e) {
            warning (e.message);
        }
    }

}
