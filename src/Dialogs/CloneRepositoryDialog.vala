/*
 * SPDX-License-Identifier: GPL-2.0-or-later
 * SPDX-FileCopyrightText: 2025 elementary, Inc. <https://elementary.io>
 *
 * Authored by: Jeremy Wootten <jeremywootten@gmail.com>
 */

public class Scratch.Dialogs.CloneRepositoryDialog : Granite.MessageDialog {
    public FolderManager.ProjectFolderItem? active_project { get; construct; }
    public bool can_clone { get; private set; default = false; }


    //Taken from "switchboard-plug-parental-controls/src/plug/Views/InternetView.vala"
    private const string NAME_REGEX = "^[0-9a-zA-Z_-]+$";
    private const string URL_REGEX = "([^/w.])[-a-zA-Z0-9@:%._\\+~#=]{2,256}\\.[a-z]{1,3}([^/])\\b([-a-zA-Z0-9@:%_\\+.~#?&//=]*\\b)";
    private Regex name_regex;
    private Regex url_regex;
    private Gtk.Label clone_parent_folder_label;
    private Granite.ValidatedEntry remote_repository_uri_entry;
    private Granite.ValidatedEntry local_project_name_entry;
    private Gtk.CheckButton set_as_active_check;

    public string suggested_local_folder { get; construct; }

    public CloneRepositoryDialog (string _suggested_local_folder) {
        Object (
            transient_for: ((Gtk.Application)(GLib.Application.get_default ())).get_active_window (),
            image_icon: new ThemedIcon ("git"),
            suggested_local_folder: _suggested_local_folder
        );

    }

    construct {
        try {
            name_regex = new Regex (NAME_REGEX, RegexCompileFlags.OPTIMIZE);
            url_regex = new Regex (URL_REGEX, RegexCompileFlags.OPTIMIZE);
        } catch (RegexError e) {
            warning ("%s\n", e.message);
        }

        var cancel_button = add_button (_("Cancel"), Gtk.ResponseType.CANCEL);
        ///TRANSLATORS "Git" is a proper name and must not be translated
        primary_text = _("Create a local clone of a Git repository");
        secondary_text = _("The source repository and local folder must exist and have the required read and write permissions");
        badge_icon = new ThemedIcon ("emblem-downloads");

        remote_repository_uri_entry = new Granite.ValidatedEntry.from_regex (url_regex) {
            input_purpose = URL,
            placeholder_text = _("https://<hostname>/<username>/<projectname>.git")
        };

        var folder_image = new Gtk.Image.from_icon_name ("folder-download", BUTTON);
        // The suggested folder is assumed to be valid as it is generated internally
        clone_parent_folder_label = new Gtk.Label (suggested_local_folder) {
            hexpand = true,
            halign = START
        };
        var view_more_image = new Gtk.Image.from_icon_name ("view-more-horizontal-symbolic", BUTTON);
        var folder_chooser_button_child = new Gtk.Box (HORIZONTAL, 6);
        folder_chooser_button_child.add (folder_image);
        folder_chooser_button_child.add (clone_parent_folder_label);
        folder_chooser_button_child.add (view_more_image);

        var folder_chooser_button = new Gtk.Button () {
            child = folder_chooser_button_child
        };
        folder_chooser_button.clicked.connect (() => {
            var chooser = new Gtk.FileChooserNative (
                _("Select folder where the cloned repository will be created"),
                this.transient_for,
                SELECT_FOLDER,
                _("Select"),
                _("Cancel")
            );
            chooser.set_current_folder (clone_parent_folder_label.label);
            chooser.response.connect ((res) => {
                if (res == Gtk.ResponseType.ACCEPT) {
                    clone_parent_folder_label.label = chooser.get_filename ();
                }

                chooser.destroy ();
            });
            chooser.show ();

        });

        local_project_name_entry = new Granite.ValidatedEntry.from_regex (name_regex);

        set_as_active_check = new Gtk.CheckButton.with_label (_("Set as Active Project")) {
            margin_top = 12,
            active = true
        };

        var content_box = new Gtk.Box (VERTICAL, 12);
        content_box.add (new Granite.HeaderLabel (_("Source Repository")));
        content_box.add (new CloneEntry (_("Remote Repository URI"), remote_repository_uri_entry));
        content_box.add (new Granite.HeaderLabel (_("Clone")));
        content_box.add (new CloneEntry (_("Parent Folder of Clone"), folder_chooser_button));
        content_box.add (new CloneEntry (_("Name of Clone "), local_project_name_entry));
        content_box.add (set_as_active_check);
        content_box.show_all ();

        custom_bin.add (content_box);

        var clone_button = (Gtk.Button) add_button (_("Clone Repository"), Gtk.ResponseType.APPLY);
        clone_button.can_default = true;
        clone_button.has_default = true;
        clone_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);

        remote_repository_uri_entry.notify["is-valid"].connect (on_is_valid_changed);

        clone_button.sensitive = can_clone;
        bind_property ("can-clone", clone_button, "sensitive");

        on_is_valid_changed ();

        // Focus cancel button so that entry placeholder text shows
        cancel_button.grab_focus ();
    }

    public string get_source_repository_uri () requires (can_clone) {
        //TODO Further validation here?
        return remote_repository_uri_entry.text;
    }

    public string get_local_folder () requires (can_clone) {
        return clone_parent_folder_label.label;
    }

    public string get_local_name () requires (can_clone) {
        var local_name = local_project_name_entry.text;
        if (local_name == "") {
            var uri_string = remote_repository_uri_entry.text;
            string? scheme, userinfo, host, path, query,fragment;
            int port;
            try {
                Uri.split (
                    uri_string,
                    UriFlags.PARSE_RELAXED,
                    out scheme, out userinfo, out host, out port, out path, out query, out fragment
                );

                if (path.has_suffix (".git")) {
                    path = path.slice (0, -4);
                }

                local_name = Path.get_basename (path);
            } catch (UriError e) {
                warning ("Could not parse remote uri");
                can_clone = false;
            }
        }

        return local_name;
    }

    private void on_is_valid_changed () {
        can_clone = remote_repository_uri_entry.is_valid;
    }

    private class CloneEntry : Gtk.Box {
        public CloneEntry (string label_text, Gtk.Widget entry) {
            var label = new Gtk.Label (label_text) {
                halign = START,
                mnemonic_widget = entry
            };
            add (label);
            add (entry);
        }

        construct {
            orientation = VERTICAL;
            spacing = 6;
            hexpand = false;
            margin_start = 12;
            margin_end = 12;
            margin_bottom = 12;
        }
    }
}
