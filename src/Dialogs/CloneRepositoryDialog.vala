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
    private Regex name_regex;
    private Gtk.Label clone_parent_folder_label;
    private Granite.ValidatedEntry remote_repository_uri_entry;
    private Granite.ValidatedEntry local_project_name_entry;
    private Gtk.CheckButton set_as_active_check;
    private ProtocolChooser protocol_chooser;

    public string suggested_local_folder { get; construct; }

    public CloneRepositoryDialog (string _suggested_local_folder) {
        Object (
            transient_for: ((Gtk.Application)(GLib.Application.get_default ())).get_active_window (),
            image_icon: new ThemedIcon ("git"),
            modal: true,
            suggested_local_folder: _suggested_local_folder
        );
    }

    construct {
        try {
            name_regex = new Regex (NAME_REGEX, RegexCompileFlags.OPTIMIZE);
        } catch (RegexError e) {
            warning ("%s\n", e.message);
        }

        var cancel_button = add_button (_("Cancel"), Gtk.ResponseType.CANCEL);

        ///TRANSLATORS "Git" is a proper name and must not be translated
        primary_text = _("Create a local clone of a Git repository");
        secondary_text = _("The source repository and local folder must exist and have the required read and write permissions");
        badge_icon = new ThemedIcon ("emblem-downloads");

        remote_repository_uri_entry = new Granite.ValidatedEntry ();
        remote_repository_uri_entry.changed.connect (on_remote_uri_changed);

        // The suggested folder is assumed to be valid as it is generated internally
        clone_parent_folder_label = new Gtk.Label (suggested_local_folder) {
            hexpand = true,
            halign = START
        };

        var folder_chooser_button_child = new Gtk.Box (HORIZONTAL, 6);
        folder_chooser_button_child.add (clone_parent_folder_label);
        folder_chooser_button_child.add (
            new Gtk.Image.from_icon_name ("folder-open-symbolic", BUTTON)
        );

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

        protocol_chooser = new ProtocolChooser ();
        protocol_chooser.set_active (0);
        protocol_chooser.changed.connect (() => {
            if (protocol_chooser.is_https ()) {
                remote_repository_uri_entry.placeholder_text = _("https://example.com/username/projectname.git");
                remote_repository_uri_entry.input_purpose = URL;
            } else {
                remote_repository_uri_entry.placeholder_text = _("git@example.com:username/projectname.git");
                remote_repository_uri_entry.input_purpose = EMAIL; // TODO Implement specific SSH purpose. Email seems to work tho.
            }

            remote_repository_uri_entry.changed ();
        });

        var content_box = new Gtk.Box (VERTICAL, 12);
        content_box.add (protocol_chooser);
        content_box.add (new CloneEntry (_("Repository URL"), remote_repository_uri_entry));
        content_box.add (new CloneEntry (_("Location"), folder_chooser_button));
        content_box.add (new CloneEntry (_("Name of Clone"), local_project_name_entry));
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

        protocol_chooser.changed ();

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

    private void on_remote_uri_changed (Gtk.Editable source) {
        var entry = (Granite.ValidatedEntry)source;
        if (!entry.is_valid) {
            return; // No need for further validation
        }

        if (protocol_chooser.is_https ()) {
            entry.is_valid = validate_https_address (entry.text);
        } else {
            entry.is_valid = validate_ssh_address (entry.text);
        }
    }

    private bool validate_https_address (string address) {
        var valid = false;
        string? scheme, userinfo, host, path, query, fragment;
        int port;
        try {
            Uri.split (
                address,
                UriFlags.NONE,
                out scheme,
                out userinfo,
                out host,
                out port,
                out path,
                out query,
                out fragment
            );

            if (query == null &&
                fragment == null &&
                scheme == "https" &&
                host != null && //e.g. github.com
                userinfo == null &&  //User is first part of pat
                (port < 0 || port == 443)) { //TODO Allow non-standard port to be selected

                if (path.has_prefix (Path.DIR_SEPARATOR_S)) {
                    path = path.substring (1, -1);
                }

                var parts = path.split (Path.DIR_SEPARATOR_S);
                valid = parts.length == 2 && parts[1].has_suffix (".git");
            }
        } catch (UriError e) {
            warning ("Uri split error %s", e.message);
        }

       return valid;
    }

    private bool validate_ssh_address (string address) {
        if (!address.has_prefix ("git@")) {
            return false;
        }

        var parts = address.substring (4, -1).split (":");
        if (parts.length != 2) {
            return false;
        }

        var path = parts[1];
        parts = path.split (Path.DIR_SEPARATOR_S);
        return parts.length == 2 && parts[1].has_suffix (".git");
    }

    private void on_is_valid_changed () {
        can_clone = remote_repository_uri_entry.is_valid;
    }

    private class CloneEntry : Gtk.Box {
        public CloneEntry (string label_text, Gtk.Widget entry) {
            var label = new Granite.HeaderLabel (label_text) {
                mnemonic_widget = entry
            };

            add (label);
            add (entry);
        }

        construct {
            orientation = VERTICAL;
        }
    }

    //Simplistic version as we only handle two protocols at present
    private class ProtocolChooser : Gtk.Box {
        private Gtk.ToggleButton https_button;
        private Gtk.ToggleButton ssh_button;
        public signal void changed ();

        construct {
            orientation = HORIZONTAL;
            spacing = 0;
            homogeneous = true;
            hexpand = false;
            halign = Gtk.Align.CENTER;

            get_style_context ().add_class ("linked");
            https_button = new Gtk.ToggleButton.with_label ("HTTPS") {
                draw_indicator = false
            };
            ssh_button = new Gtk.ToggleButton.with_label ("SSH");
            add (https_button);
            add (ssh_button);

            https_button.toggled.connect (button_toggled);
            ssh_button.toggled.connect (button_toggled);
        }

        private void button_toggled (Gtk.Widget source) {
            if (ssh_button.active != https_button.active) {
                return;
            }

            var button = (Gtk.ToggleButton)source;
            if (button == https_button) {
                ssh_button.active = !https_button.active;
            } else {
                https_button.active = !ssh_button.active;
            }

            changed ();
        }

        public void set_active (int index) {
            switch (index) {
                case 0:
                    https_button.active = true;
                    break;
                case 1:
                    https_button.active = false;
                    break;
                default:
                    assert_not_reached ();
            }
        }

        public bool is_https () {
            return https_button.active;
        }
    }
}
