/*
* SPDX-License-Identifier: GPL-2.0-or-later
* SPDX-FileCopyrightText: 2017-2023 elementary, Inc. (https://elementary.io)
*/

public class Code.PopoverMenuItem : Gtk.Button {
    /**
     * The label for the button
     */
    public string text { get; construct; }

    /**
     * The icon name for the button
     */
    public string icon_name { get; set; }

    public PopoverMenuItem (string text) {
        Object (text: text);
    }

    class construct {
        set_css_name ("modelbutton");
    }

    construct {
        var image = new Gtk.Image ();

        var label = new Granite.AccelLabel (text);

        var box = new Gtk.Box (HORIZONTAL, 6);
        box.add (image);
        box.add (label);

        child = box;

        get_accessible ().accessible_role = MENU_ITEM;

        clicked.connect (() => {
            var popover = (Gtk.Popover) get_ancestor (typeof (Gtk.Popover));
            if (popover != null) {
                popover.popdown ();
            }
        });

        bind_property ("action-name", label, "action-name");
        bind_property ("icon-name", image, "icon-name");
    }
}
