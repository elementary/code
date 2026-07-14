/*-
 * Copyright 2017-2026 elementary, Inc. (https://elementary.io)
 *
 * This program is free software: you can redistribute it and/or * it under the terms of the GNU General Public License as published by

 modify * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Authored by: Corentin Noël <corentin@elementary.io>
 */

public class Code.Sidebar : Gtk.Box {
    public enum TargetType {
        URI_LIST
    }

    public const string SIDEBAR_ACTION_GROUP = "sidebar";
    public const string SIDEBAR_ACTION_PREFIX = SIDEBAR_ACTION_GROUP + ".";
    public Gtk.Stack stack { get; private set; }
    public Code.ChooseProjectButton choose_project_button { get; private set; }
    public Adw.HeaderBar headerbar { get; private set; }
    public GLib.MenuModel project_menu_model { get; construct; }
    // May show progress in different way in future
    public bool cloning_in_progress {
        get {
            return choose_project_button.cloning_in_progress;
        }

        set {
            choose_project_button.cloning_in_progress = value;
        }
    }

    private Gtk.StackSwitcher stack_switcher;
    private Granite.Toast cloning_success_toast;

    construct {
        orientation = Gtk.Orientation.VERTICAL;
        vexpand = true;
        hexpand = true;

        add_css_class (Granite.STYLE_CLASS_SIDEBAR);

        choose_project_button = new Code.ChooseProjectButton () {
            hexpand = true,
            valign = Gtk.Align.CENTER
        };

        cloning_success_toast = new Granite.Toast (_("Cloning complete")) {
            halign = CENTER,
            valign = START
        };

        headerbar = new Adw.HeaderBar () {
            title_widget = choose_project_button,
            decoration_layout = "close:"
        };
        headerbar.add_css_class (Granite.STYLE_CLASS_FLAT);

        stack = new Gtk.Stack () {
            vexpand = true
        };
        stack.transition_type = Gtk.StackTransitionType.SLIDE_LEFT_RIGHT;

        var overlay = new Gtk.Overlay () {
            child = stack
        };
        overlay.add_overlay (cloning_success_toast);

        stack_switcher = new Gtk.StackSwitcher ();
        stack_switcher.visible = false;
        stack_switcher.stack = stack;

        var actionbar = new Gtk.ActionBar () {
            valign = END
        };
        actionbar.add_css_class (Granite.STYLE_CLASS_FLAT);

        var collapse_all_menu_item = new GLib.MenuItem (_("Collapse All"), Scratch.MainWindow.ACTION_PREFIX
        + Scratch.MainWindow.ACTION_COLLAPSE_ALL_FOLDERS);

        var action_group = new SimpleActionGroup ();
        var sort_action = Scratch.saved_state.create_action ("order-folders");
        action_group.add_action (sort_action);
        insert_action_group (SIDEBAR_ACTION_GROUP, action_group);

        var order_projects_menu_item = new GLib.MenuItem (
            _("Keep Sorted"),
            SIDEBAR_ACTION_PREFIX + sort_action.name
        );

        var project_menu = new GLib.Menu ();
        project_menu.append_item (collapse_all_menu_item);
        project_menu.append_item (order_projects_menu_item);
        project_menu_model = project_menu;

        var label = new Gtk.Label ( _("Manage project folders…")) {
            halign = START,
            valign = CENTER
        };
        var project_menu_button = new Gtk.MenuButton () {
            hexpand = true,
            menu_model = project_menu_model,
            child = label
        };

        actionbar.pack_start (project_menu_button);

        append (headerbar);
        append (stack_switcher);
        append (overlay);
        append (actionbar);

        // stack.remove.connect (() => {

        // });

        // Gtk.TargetEntry uris = {"text/uri-list", 0, TargetType.URI_LIST};
        // Gtk.drag_dest_set (this, Gtk.DestDefaults.ALL, {uris}, Gdk.DragAction.COPY);
        // drag_data_received.connect (drag_received);
    }

    // private void drag_received (Gtk.Widget w,
    //                             Gdk.DragContext ctx,
    //                             int x,
    //                             int y,
    //                             Gtk.SelectionData sel,
    //                             uint info,
    //                             uint time) {

    //     if (info == TargetType.URI_LIST) {
    //         var uri_list = sel.get_uris ();
    //         GLib.List<GLib.File> folder_list = null;
    //         foreach (unowned var uri in uri_list) {
    //             var file = GLib.File.new_for_uri (uri);
    //             // Blocking but for simplicity omit cancellable for now
    //             var ftype = file.query_file_type (FileQueryInfoFlags.NOFOLLOW_SYMLINKS);
    //             if (ftype == GLib.FileType.DIRECTORY) {
    //               folder_list.prepend (file);
    //             }
    //         }

    //         foreach (var folder in folder_list) {
    //             activate_action (
    //                 Scratch.MainWindow.ACTION_PREFIX + Scratch.MainWindow.ACTION_OPEN_FOLDER,
    //                 "s",
    //                  folder.get_path ()
    //             );
    //         }

    //         Gtk.drag_finish (ctx, folder_list.length () > 0, false, time);
    //     }
    // }

    public void add_tab (Code.PaneSwitcher tab) {
        stack.add_child (tab);
        var page = stack.get_page (tab);
        tab.bind_property ("title", page, "title", DEFAULT | SYNC_CREATE);
        tab.bind_property ("icon-name", page, "icon-name", DEFAULT | SYNC_CREATE);
    }

    public void remove_tab (Code.PaneSwitcher tab) {
        stack.remove (tab);
        switch (stack.pages.get_n_items ()) {
            case 0:
                stack.hide ();
                break;
            case 1:
                stack_switcher.hide ();
                break;
        }
    }

    public void notify_cloning_success () {
        cloning_success_toast.send_notification ();
    }

    public void focus_sidebar () {
        // if (stack.visible_child is Code.TreeList) {
        //     ((Code.Widgets.SourceList) stack.visible_child).grab_focus ();
        // }
    }
}
