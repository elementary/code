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
    public Gtk.Stack stack { get; private set; }
    private Gtk.StackSwitcher stack_switcher;
    construct {
        orientation = Gtk.Orientation.VERTICAL;
        visible = false;
        no_show_all = true;

        get_style_context ().add_class (Gtk.STYLE_CLASS_SIDEBAR);

        stack = new Gtk.Stack ();
        stack.transition_type = Gtk.StackTransitionType.SLIDE_LEFT_RIGHT;

        stack_switcher = new Gtk.StackSwitcher ();
        stack_switcher.no_show_all = true;
        stack_switcher.visible = false;
        stack_switcher.stack = stack;
        stack_switcher.homogeneous = true;

        var actionbar = new Gtk.ActionBar ();
        actionbar.get_style_context ().add_class (Gtk.STYLE_CLASS_INLINE_TOOLBAR);

        var add_folder_button = new Gtk.Button.from_icon_name ("folder-open-symbolic", Gtk.IconSize.SMALL_TOOLBAR) {
            action_name = Scratch.MainWindow.ACTION_PREFIX + Scratch.MainWindow.ACTION_OPEN_FOLDER,
            always_show_image = true,
            label = _("Open Project Folder…")
        };

        var collapse_all_menu_item = new Gtk.MenuItem.with_label (_("Collapse All"));
        collapse_all_menu_item.action_name = Scratch.MainWindow.ACTION_PREFIX + Scratch.MainWindow.ACTION_COLLAPSE_ALL_FOLDERS;

        var order_projects_menu_item = new Gtk.MenuItem.with_label (_("Alphabetize"));
        order_projects_menu_item.action_name = Scratch.MainWindow.ACTION_PREFIX + Scratch.MainWindow.ACTION_ORDER_FOLDERS;

        var project_menu = new Gtk.Menu ();
        project_menu.append (collapse_all_menu_item);
        project_menu.append (order_projects_menu_item);
        project_menu.show_all ();

        var project_more_button = new Gtk.MenuButton ();
        project_more_button.image = new Gtk.Image.from_icon_name ("view-more-symbolic", Gtk.IconSize.SMALL_TOOLBAR);
        project_more_button.popup = project_menu;
        project_more_button.tooltip_text = _("Manage project folders");

        actionbar.add (add_folder_button);
        actionbar.pack_end (project_more_button);

        add (stack_switcher);
        add (stack);
        add (actionbar);

        stack.add.connect (() => {
            if (stack.get_children ().length () > 1) {
                stack_switcher.no_show_all = false;
                stack_switcher.show_all ();
            }

            no_show_all = false;
            show_all ();
        });

        stack.remove.connect (() => {
            switch (stack.get_children ().length ()) {
                case 0:
                    no_show_all = true;
                    hide ();
                    break;
                case 1:
                    stack_switcher.no_show_all = true;
                    stack_switcher.hide ();
                    break;
            }
        });
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
}
