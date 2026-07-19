/*-
 * Copyright (c) 2017-2026 elementary LLC. (https://elementary.io),
 *               2013 Julien Spautz <spautz.julien@gmail.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License version 3
 * as published by the Free Software Foundation, either version 3 of the
 * License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranties of
 * MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
 * PURPOSE. See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Authored by: Julien Spautz <spautz.julien@gmail.com>, Andrei-Costin Zisu <matzipan@gmail.com>
 */

public interface Code.FolderManagerItemInterface : Object {
    public abstract string path { get; set; }
    public abstract string name { get; set; }
    public abstract string badge { get; set; }
    public bool equal (FolderManagerItemInterface b) {
        return path == b.path;
    }

    public virtual GLib.Menu? get_context_menu () {
        GLib.FileInfo info = null;
        var gfile = GLib.File.new_for_path (path);
        try {
            info = gfile.query_info (GLib.FileAttribute.STANDARD_CONTENT_TYPE, GLib.FileQueryInfoFlags.NONE);
        } catch (Error e) {
            warning (e.message);
        }

        var file_type = info.get_content_type ();

        // external_actions_section holds submenus for "Open In" and "Other Actions"
        // which involve other apps
        var external_actions_section = new GLib.Menu ();
        external_actions_section.append_item (create_submenu_for_open_item_in (gfile, file_type));
        var contractor_items = create_contract_items_for_file (gfile);
        if (contractor_items.get_n_items () > 0) {
            external_actions_section.append_submenu (_("Other Actions"), contractor_items);
        }

        var menu_model = new GLib.Menu ();
        menu_model.append_section (null, external_actions_section);
        var rename_menu_item = new GLib.MenuItem (
            _("Rename"),
            GLib.Action.print_detailed_name (
                ITEM_ACTION_PREFIX + ACTION_RENAME_FOLDER,
                new Variant.string (path)
            )
        );

        var delete_item = new GLib.MenuItem (
            _("Move to Trash"),
            GLib.Action.print_detailed_name (
                ITEM_ACTION_PREFIX + ACTION_DELETE,
                new Variant.string (path)
            )
        );

        return menu_model;
    }

    public virtual GLib.MenuItem create_submenu_for_open_item_in (GLib.File gfile, string? file_type) {
        //TODO Open in Terminal Pane only for projects
        // var open_in_terminal_pane_item = new GLib.MenuItem (
        //     (_("Terminal Pane")),
        //     GLib.Action.print_detailed_name (
        //         Scratch.MainWindow.ACTION_PREFIX + Scratch.MainWindow.ACTION_OPEN_IN_TERMINAL,
        //         new Variant.string (file_path)
        //     )
        // );
        // open_in_terminal_pane_item.set_icon (new ThemedIcon ("panel-bottom-symbolic"));

        var file_path = gfile.get_path ();
        var other_menu_item = new GLib.MenuItem (
            _("Other Application…"),
            GLib.Action.print_detailed_name (
                ITEM_ACTION_PREFIX + ACTION_SHOW_APP_CHOOSER,
                file_path
            )
        );

        var extra_section = new GLib.Menu ();
        extra_section.append_item (other_menu_item);

        // var terminal_pane_section = new Menu ();
        // terminal_pane_section.append_item (open_in_terminal_pane_item);

        file_type = file_type ?? "inode/directory";

        var open_in_menu = new GLib.Menu ();
        // open_in_menu.append_section (null, terminal_pane_section);
        open_in_menu.append_section (null, create_executable_app_items_for_file (
            gfile,
            file_type
        ));
        open_in_menu.append_section (null, extra_section);

        var open_in_menu_item = new GLib.MenuItem.submenu (_("Open In"), open_in_menu);
        open_in_menu_item.set_link ("submenu", open_in_menu); // So overriding methods can modify
        return open_in_menu_item;
    }

    public GLib.Menu? create_executable_app_items_for_file (GLib.File file, string file_type) {
        var scratch_app = (Scratch.Application) (GLib.Application.get_default ());
        var this_id = scratch_app.application_id + ".desktop";
        var menu = new GLib.Menu ();

        if (scratch_app.is_running_in_flatpak) {
            var menu_item = new MenuItem (
                ///TRANSLATORS '%s' represents the quoted basename of a uri to be opened with the default app
                _("Show '%s' with default app").printf (file.get_basename ()),
                GLib.Action.print_detailed_name (
                    ITEM_ACTION_PREFIX + ACTION_LAUNCH_APP_WITH_FILE_PATH,
                    new GLib.Variant.array (
                        GLib.VariantType.STRING,
                        { file.get_path (), "" }
                    )
                )
            );
            menu.append_item (menu_item);
        } else {
            List<AppInfo> external_apps = null;
            if (file_type == "") {
                var files_appinfo = AppInfo.get_default_for_type ("inode/directory", true);
                external_apps.prepend (files_appinfo);
            } else {
                external_apps = GLib.AppInfo.get_all_for_type (file_type);
                external_apps.sort ((a, b) => {
                    return a.get_name ().collate (b.get_name ());
                });
            }

            foreach (AppInfo app_info in external_apps) {
                string app_id = app_info.get_id ();
                if (app_id == this_id) {
                    continue;
                }

                var menu_item = new MenuItem (
                    app_info.get_name (),
                    GLib.Action.print_detailed_name (
                        ITEM_ACTION_PREFIX + ACTION_LAUNCH_APP_WITH_FILE_PATH,
                        new GLib.Variant.array (
                            GLib.VariantType.STRING,
                            { file.get_path (), app_id }
                        )
                    )
                );
                menu_item.set_icon (app_info.get_icon ());
                menu.append_item (menu_item);
            }
        }

        return menu;
    }

    public GLib.Menu create_contract_items_for_file (GLib.File file) {
        var menu = new GLib.Menu ();

        try {
            var contracts = Granite.Services.ContractorProxy.get_contracts_for_file (file);
            foreach (var contract in contracts) {
                string contract_name = contract.get_display_name ();
                var menu_item = new GLib.MenuItem (
                    contract_name,
                    GLib.Action.print_detailed_name (
                        ITEM_ACTION_PREFIX + ACTION_EXECUTE_CONTRACT_WITH_FILE_PATH,
                        new GLib.Variant.array (
                            GLib.VariantType.STRING,
                            { file.get_path (), contract_name }
                        )
                    )
                );

                menu.append_item (menu_item);
            }
        } catch (Error e) {
            warning (e.message);
        }

        return menu;
    }
}

public abstract class Code.FolderManagerItem: Code.TreeListItem, Code.FolderManagerItemInterface {
    public signal void edited (string new_name);

    public Code.File file { get; construct; }
    public Code.FolderTree view { get; construct; }

    // interface Code.FolderManagerItemInterface
    public string name {
        get {
            return text;
        }

        set {
            text = value;
        }
    }

    public string path { get; set; }
    public string badge { get; set; }


    construct {
        is_selectable = true;
        is_editable = true;
        text = file.name;
        icon = file.icon;
        edited.connect (rename);
        tooltip = Scratch.Utils.replace_home_with_tilde (file.path);

        notify["activatable-tooltip"].connect (() => {
            tooltip = ("%s\n" + Granite.TOOLTIP_SECONDARY_TEXT_MARKUP).printf (
                Scratch.Utils.replace_home_with_tilde (file.path),
                secondary_icon_tooltip
            );
        });

        file.bind_property ("path", this, "path", SYNC_CREATE);
    }

    protected void rename (string new_name) {
        file.rename (new_name);
    }

    public bool equal (FolderManagerItem b) {
        return path == b.path;
    }

    public void trash () {
        file.trash ();
    }

    public int compare (Code.TreeListItem a, Code.TreeListItem  b) {
        // if (a is RenameItem) {
        //     return -1;
        // } else
        // if (b is RenameItem) {
        //     return 1;
        // }
        warning ("compare item");
        if (a is FolderItem && b is FileItem) {
            return -1;
        } else if (a is FileItem && b is FolderItem) {
            return 1;
        }

        assert (a is FolderManagerItem && b is FolderManagerItem); //Ensure more informative error message

        return File.compare (((FolderManagerItem)a).file, ((FolderManagerItem)b).file);
    }

    public bool allow_dnd_sorting () {
        return false;
    }

    public ProjectFolderItem? get_root_folder (Code.TreeListItem start = null) {
        if (start == null) {
            start = this;
        }

        if (start is ProjectFolderItem) {
            return start as ProjectFolderItem;
        } else if (start.parent is ProjectFolderItem) {
            return start.parent as ProjectFolderItem;
        } else if (start.parent != null) {
            return get_root_folder (start.parent);
        } else {
            return null;
        }
    }

    // protected class RenameItem : Code.TreeListItem {
    //     public bool is_folder { get; construct; }
    //     public string name { get; set construct; }

    //     public RenameItem (string name, bool is_folder) {
    //         Object (
    //             name: name
    //             is_folder: is_folder
    //         );
    //     }

    //     construct {
    //         is_editable = true;
    //         is_selectable = true;
    //         edited.connect (on_edited);

    //         if (is_folder) {
    //             icon = GLib.ContentType.get_icon ("inode/directory");
    //         } else {
    //             icon = GLib.ContentType.get_icon ("text");
    //         }
    //     }

    //     private void on_edited (string new_name) {
    //         if (new_name != "") {
    //             name = new_name;
    //         }
    //     }
    // }
}

