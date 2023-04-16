/* Copyright 2023 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
public class Scratch.Dialogs.AskExternalChangesDialog : Granite.MessageDialog {

    public AskExternalChangesDialog (string primary_text, string secondary_text) {
        Object (
            buttons: Gtk.ButtonsType.NONE,
            primary_text: primary_text,
            secondary_text: secondary_text
        );
    }

    construct {
        var app_instance = (Gtk.Application) GLib.Application.get_default ();
        transient_for = app_instance.active_window;
        image_icon = new ThemedIcon ("dialog-warning");

        add_button (_("Continue"), Gtk.ResponseType.REJECT);

        var reload_button = (Gtk.Button) add_button (_("Reload"), 0);
        reload_button.get_style_context ().add_class (Gtk.STYLE_CLASS_DESTRUCTIVE_ACTION);

        var overwrite_button = (Gtk.Button) add_button (_("Overwrite"), 1);
        overwrite_button.get_style_context ().add_class (Gtk.STYLE_CLASS_DESTRUCTIVE_ACTION);

        var saveas_button = (Gtk.Button) add_button (_("Save Document elsewhere"), Gtk.ResponseType.ACCEPT);
        saveas_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);
    }
}
