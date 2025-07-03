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
    private Gtk.Image image;
    public string icon_name {
        set {
            image.icon_name = value;
        }
    }
    private Granite.AccelLabel accel_label;
    public string accel_string {
        set {
            accel_label.accel_string = value;
        }
     }

    public PopoverMenuItem (string text) {
        Object (text: text);
    }

    class construct {
        set_css_name ("modelbutton");
    }

    construct {
        image = new Gtk.Image ();
        accel_label = new Granite.AccelLabel (text);

        var box = new Gtk.Box (HORIZONTAL, 6);
        box.add (image);
        box.add (accel_label);

        child = box;

        get_accessible ().accessible_role = MENU_ITEM;

        clicked.connect (() => {
            var popover = (Gtk.Popover) get_ancestor (typeof (Gtk.Popover));
            if (popover != null) {
                popover.popdown ();
            }
        });
    }
}
