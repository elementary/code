// Folder interface shared with Project folder items used in ListBox
public interface Code.FolderInterface : Object {
    public abstract bool is_expanded { get; set; }
    public abstract ListStore? child_model { get; set; }
    public abstract FileMonitor monitor { get; set; }
    public virtual void on_changed (
        GLib.File source,
        GLib.File? dest,
        GLib.FileMonitorEvent event
    ) {}

    public virtual void init_monitor_directory (GLib.File gfile) {
        try {
            monitor = gfile.monitor_directory (GLib.FileMonitorFlags.NONE);
            monitor.changed.connect (on_changed);
        } catch (GLib.Error e) {
            warning (e.message);
        }
    }

    // Used by both ProjectListItem and FolderItem
    public virtual GLib.MenuItem create_submenu_for_new (string file_path) {
        var new_folder_item = new GLib.MenuItem (
            _("Folder"),
            GLib.Action.print_detailed_name (
                ITEM_ACTION_PREFIX + ACTION_NEW_FOLDER,
                new Variant.string (file_path)
            )
        );

        var new_file_item = new GLib.MenuItem (
            _("Empty File"),
            GLib.Action.print_detailed_name (
                ITEM_ACTION_PREFIX + ACTION_NEW_FILE,
                new Variant.string (file_path)
            )
        );

        var new_menu = new GLib.Menu ();
        new_menu.append_item (new_folder_item);
        new_menu.append_item (new_file_item);

        // Append any templates/template folders.
        unowned string? template_path = GLib.Environment.get_user_special_dir (GLib.UserDirectory.TEMPLATES);
        if (template_path != null) {
            var template_submenu = new Menu ();
            uint template_count = load_templates_from_folder (
                file_path,
                GLib.File.new_for_path (template_path),
                template_submenu
            );
            if (template_count > 0) {
                if (template_count > MAX_TEMPLATES) {
                    template_submenu.append_item (new MenuItem (_("…too many templates"), null));
                }

                new_menu.append_submenu (_("Templates"), template_submenu);
            }
        }

        var new_item = new GLib.MenuItem.submenu (_("Add New"), new_menu);
        new_item.set_submenu (new_menu);

        return new_item;
    }


    public delegate bool IterateChildrenCallback (Object obj);
    public virtual void iterate_children (IterateChildrenCallback cb) {}

        // Recursively load templates from folder and subfolders keeping count of total menuitems
    const int MAX_TEMPLATES = 2048;
    private uint load_templates_from_folder (
        string target_path,
        GLib.File template_folder,
        Menu template_submenu
    ) {
        GLib.List<GLib.File> template_list = null;
        GLib.List<GLib.File> folder_list = null;

        GLib.FileEnumerator enumerator;
        var flags = GLib.FileQueryInfoFlags.NOFOLLOW_SYMLINKS;
        uint count = 0;
        try {
            enumerator = template_folder.enumerate_children ("standard::*", flags, null);
            GLib.File location;
            GLib.FileInfo? info = enumerator.next_file (null);

            while (count < MAX_TEMPLATES && (info != null)) {
                if (!info.get_attribute_boolean (GLib.FileAttribute.STANDARD_IS_BACKUP)) {
                    location = template_folder.get_child (info.get_name ());
                    if (info.get_file_type () == GLib.FileType.DIRECTORY) {
                        folder_list.prepend (location);
                    } else {
                        template_list.prepend (location);
                    }

                    count ++;
                }

                info = enumerator.next_file (null);
            }
        } catch (GLib.Error error) {
            return 0;
        }

        folder_list.sort ((a, b) => {
            return strcmp (a.get_basename ().down (), b.get_basename ().down ());
        });

        unowned List<GLib.File> fl = folder_list;
        while (fl != null && count < MAX_TEMPLATES) {
            var folder = fl.data;
            var folder_submenu = new Menu ();
            var folder_submenuitem = new MenuItem.submenu (
                folder.get_basename (),
                folder_submenu
            );

            var sub_count = load_templates_from_folder (target_path, folder, folder_submenu);
            if (sub_count > 0) {
                template_submenu.append_item (folder_submenuitem);
                count += sub_count;
            } else {
                count -= 1;  // Adjust count for ignored folder
            }

            fl = fl.next;
        }

        if (count > MAX_TEMPLATES) {
            warning ("too many templates! %u", count);
            return count;
        }

        template_list.sort ((a, b) => {
            return strcmp (a.get_basename ().down (), b.get_basename ().down ());
        });

        template_list.@foreach ((template) => {
            var template_menuitem = new MenuItem (
                template.get_basename (),
                GLib.Action.print_detailed_name (
                    ITEM_ACTION_PREFIX + ACTION_NEW_FROM_TEMPLATE,
                    new Variant ("(ss)", target_path, template.get_path ())
                )
            );

            template_submenu.append_item (template_menuitem);
        });

        return count;
    }
}


