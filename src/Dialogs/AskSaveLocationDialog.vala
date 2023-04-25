/* Copyright 2023 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
public class Scratch.Dialogs.AskSaveLocationDialog : Granite.MessageDialog {

    public AskSaveLocationDialog (string primary_text, string secondary_text, string error_message) {
        Object (
            buttons: Gtk.ButtonsType.NONE,
            primary_text: primary_text,
            secondary_text: secondary_text
        );

        if (error_message != "") {
            show_error_details (error_message);
        }
    }

    construct {
        var app_instance = (Gtk.Application) GLib.Application.get_default ();
        transient_for = app_instance.active_window;
        image_icon = new ThemedIcon ("document-save");
        badge_icon = new ThemedIcon ("dialog-question");

        add_button (_("Ignore"), Gtk.ResponseType.REJECT);

        var saveas_button = (Gtk.Button) add_button (_("Save Duplicate…"), Gtk.ResponseType.ACCEPT);
        saveas_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);
    }
}
