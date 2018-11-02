/*-
 * Copyright (c) 2017 elementary LLC. (https://elementary.io)
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

public class Code.Pane : Gtk.Grid {
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

        var toolbar = new Gtk.Toolbar ();
        toolbar.get_style_context ().add_class (Gtk.STYLE_CLASS_INLINE_TOOLBAR);
        toolbar.icon_size = Gtk.IconSize.SMALL_TOOLBAR;

        var add_button = new Gtk.ToolButton (new Gtk.Image.from_icon_name ("folder-open-symbolic", Gtk.IconSize.BUTTON), null);
        add_button.action_name = Scratch.MainWindow.ACTION_PREFIX + Scratch.MainWindow.ACTION_OPEN_FOLDER;
        add_button.tooltip_text = _("Add Project Folder…");

        toolbar.add (add_button);

        add (stack_switcher);
        add (stack);
        add (toolbar);

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

