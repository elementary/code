/*
 * SPDX-License-Identifier: GPL-2.0-or-later
 * SPDX-FileCopyrightText: 2025 elementary, Inc. <https://elementary.io>
 *
 * Authored by: Jeremy Wootten <jeremywootten@gmail.com>
 */

public class Scratch.Dialogs.CloningProgressDialog : Granite.MessageDialog {

    public string remote_uri { get; construct; }
    public string local_folder_path { get; construct; }

    public CloningProgressDialog (MainWindow parent, string remote_uri, string local_folder_path) {
        Object (
            transient_for: parent,
            buttons: Gtk.ButtonsType.NONE,
            remote_uri: remote_uri,
            local_folder_path: local_folder_path
        );
    }

    construct {
        image_icon = new ThemedIcon ("git");
        primary_text = _("Cloning a remote repository is in progress");
        secondary_text = _("Source: '%s'  Cloning to: '%s'").printf (remote_uri, local_folder_path);
    }

    public void update_status (Scratch.Services.CloningStatus status, string? message = null) {
        switch (status) {
            case START:
                return;
            case END_SUCCESS:
                primary_text = _("Cloning succeeded");
                break;
            case END_FAIL:
                primary_text = _("Cloning failed");
                break;
        }

        secondary_text = message;
        add_button (_("Ok"), Gtk.ResponseType.ACCEPT);
    }
}
