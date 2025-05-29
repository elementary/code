/*-
 * Copyright 2017-2020 elementary, Inc. (https://elementary.io)
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
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

public class Code.Sidebar : Gtk.Grid {
    public enum TargetType {
        URI_LIST
    }

    public Gtk.Stack stack { get; private set; }
    public Code.ChooseProjectButton choose_project_button { get; private set; }
    public Hdy.HeaderBar headerbar { get; private set; }
    public GLib.MenuModel project_menu_model { get; construct; }

    private Gtk.StackSwitcher stack_switcher;

    construct {
        orientation = Gtk.Orientation.VERTICAL;
        get_style_context ().add_class (Gtk.STYLE_CLASS_SIDEBAR);

        choose_project_button = new Code.ChooseProjectButton () {
            hexpand = true,
            valign = Gtk.Align.CENTER
        };

        headerbar = new Hdy.HeaderBar () {
            custom_title = choose_project_button,
            show_close_button = true
        };
        headerbar.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);

        stack = new Gtk.Stack ();
        stack.transition_type = Gtk.StackTransitionType.SLIDE_LEFT_RIGHT;

        stack_switcher = new Gtk.StackSwitcher ();
        stack_switcher.no_show_all = true;
        stack_switcher.visible = false;
        stack_switcher.stack = stack;
        stack_switcher.homogeneous = true;

        var actionbar = new Gtk.ActionBar ();
        actionbar.get_style_context ().add_class (Gtk.STYLE_CLASS_INLINE_TOOLBAR);

        var collapse_all_menu_item = new GLib.MenuItem (_("Collapse All"), Scratch.MainWindow.ACTION_PREFIX
        + Scratch.MainWindow.ACTION_COLLAPSE_ALL_FOLDERS);

        var order_projects_menu_item = new GLib.MenuItem (_("Alphabetize"), Scratch.MainWindow.ACTION_PREFIX
                + Scratch.MainWindow.ACTION_ORDER_FOLDERS);

        var project_menu = new GLib.Menu ();
        project_menu.append_item (collapse_all_menu_item);
        project_menu.append_item (order_projects_menu_item);
        project_menu_model = project_menu;

        var project_more_button = new Gtk.MenuButton () {
            hexpand = true,
            use_popover = false,
            menu_model = project_menu_model,
            label = _("Manage project folders…"),
            xalign = 0.0f
        };

        actionbar.pack_start (project_more_button);

        add (headerbar);
        add (stack_switcher);
        add (stack);
        add (actionbar);

        stack.add.connect (() => {
            if (stack.get_children ().length () > 1) {
                stack_switcher.no_show_all = false;
                stack_switcher.show_all ();
            }

            stack.no_show_all = false;
            stack.show_all ();
        });

        stack.remove.connect (() => {
            switch (stack.get_children ().length ()) {
                case 0:
                    stack.no_show_all = true;
                    stack.hide ();
                    break;
                case 1:
                    stack_switcher.no_show_all = true;
                    stack_switcher.hide ();
                    break;
            }
        });

        Gtk.TargetEntry uris = {"text/uri-list", 0, TargetType.URI_LIST};
        Gtk.drag_dest_set (this, Gtk.DestDefaults.ALL, {uris}, Gdk.DragAction.COPY);
        drag_data_received.connect (drag_received);
    }

    private void drag_received (Gtk.Widget w,
                                Gdk.DragContext ctx,
                                int x,
                                int y,
                                Gtk.SelectionData sel,
                                uint info,
                                uint time) {

        if (info == TargetType.URI_LIST) {
            var uri_list = sel.get_uris ();
            GLib.List<GLib.File> folder_list = null;
            foreach (unowned var uri in uri_list) {
                var file = GLib.File.new_for_uri (uri);
                // Blocking but for simplicity omit cancellable for now
                var ftype = file.query_file_type (FileQueryInfoFlags.NOFOLLOW_SYMLINKS);
                if (ftype == GLib.FileType.DIRECTORY) {
                  folder_list.prepend (file);
                }
            }

            foreach (var folder in folder_list) {
                var win_group = get_action_group (Scratch.MainWindow.ACTION_GROUP);
                win_group.activate_action (
                    Scratch.MainWindow.ACTION_OPEN_FOLDER,
                    new Variant.string (folder.get_path ())
                );
            }

            Gtk.drag_finish (ctx, folder_list.length () > 0, false, time);
        }
    }

    public void add_tab (Code.PaneSwitcher tab) {
        stack.add (tab);
        stack.child_set_property (tab, "title", tab.title);
        stack.child_set_property (tab, "icon-name", tab.icon_name);

        tab.notify["title"].connect (() => {
            stack.child_set_property (tab, "title", tab.title);
        });

        tab.notify["icon-name"].connect (() => {
            stack.child_set_property (tab, "icon-name", tab.icon_name);
        });
    }

    public void remove_tab (Code.PaneSwitcher tab) {
        stack.remove (tab);
    }
}
