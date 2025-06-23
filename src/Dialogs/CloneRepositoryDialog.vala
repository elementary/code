/*
 * SPDX-License-Identifier: GPL-2.0-or-later
 * SPDX-FileCopyrightText: 2025 elementary, Inc. <https://elementary.io>
 *
 * Authored by: Jeremy Wootten <jeremywootten@gmail.com>
 */

public class Scratch.Dialogs.CloneRepositoryDialog : Granite.MessageDialog {
    public bool can_clone { get; private set; default = false; }


    // Git project name rules according to GitLab
    // - Must start and end with a letter ( a-zA-Z ) or digit ( 0-9 ).
    // - Can contain only letters ( a-zA-Z ), digits ( 0-9 ), underscores ( _ ), dots ( . ), or dashes ( - ).
    // - Must not contain consecutive special characters.
    // - Cannot end in . git or . atom .
    private const string CLONE_REPOSITORY = N_("Clone Button");
    private const string CLONING = N_("Cloning…");

    private const string NAME_REGEX = """^[0-9a-zA-Z].([-_.]?[0-9a-zA-Z])*$"""; //TODO additional validation required
    private Regex name_regex;
    private Gtk.Label projects_folder_label;
    private Granite.ValidatedEntry remote_repository_uri_entry;
    private Granite.ValidatedEntry local_project_name_entry;
    private Gtk.Button clone_button;
    private Gtk.Spinner spinner;
    private Gtk.Revealer revealer;

    public string suggested_local_folder { get; construct; }
    public string suggested_remote { get; construct; }

    public bool cloning_in_progress {
        set {
            if (value) {
                clone_button.label = _(CLONING);
                spinner.start ();

            } else {
                clone_button.label = _(CLONE_REPOSITORY);
                spinner.stop ();
            }

            revealer.reveal_child = value;
        }

        get {
            return revealer.reveal_child;
        }
    }

    public CloneRepositoryDialog (string _suggested_local_folder, string _suggested_remote) {
        Object (
            suggested_local_folder: _suggested_local_folder,
            suggested_remote: _suggested_remote
        );
    }

    construct {
        transient_for = ((Gtk.Application)(GLib.Application.get_default ())).get_active_window ();
        image_icon = new ThemedIcon ("git");
        modal = true;

        try {
            name_regex = new Regex (NAME_REGEX, OPTIMIZE, ANCHORED | NOTEMPTY);
        } catch (RegexError e) {
            warning ("%s\n", e.message);
        }

        var cancel_button = add_button (_("Cancel"), Gtk.ResponseType.CANCEL);

        ///TRANSLATORS "Git" is a proper name and must not be translated
        primary_text = _("Create a local clone of a Git repository");
        secondary_text = _("The source repository and local folder must exist and have the required read and write permissions");
        badge_icon = new ThemedIcon ("emblem-downloads");

        remote_repository_uri_entry = new Granite.ValidatedEntry () {
            placeholder_text = _("https://example.com/username/projectname.git"),
            input_purpose = URL
        };
        remote_repository_uri_entry.changed.connect (on_remote_uri_changed);
        remote_repository_uri_entry.text = suggested_remote;

        // The suggested folder is assumed to be valid as it is generated internally
        projects_folder_label = new Gtk.Label (suggested_local_folder) {
            hexpand = true,
            halign = START
        };

        var folder_chooser_button_child = new Gtk.Box (HORIZONTAL, 6);
        folder_chooser_button_child.add (projects_folder_label);
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
            chooser.set_current_folder (projects_folder_label.label);
            chooser.response.connect ((res) => {
                if (res == Gtk.ResponseType.ACCEPT) {
                    projects_folder_label.label = chooser.get_filename ();
                    update_can_clone ();
                }

                chooser.destroy ();
            });
            chooser.show ();

        });

        local_project_name_entry = new Granite.ValidatedEntry ();
        local_project_name_entry.changed.connect (validate_local_name);

        revealer = new Gtk.Revealer () {
            valign = END
        };
        spinner = new Gtk.Spinner ();
        revealer.add (spinner);

        var content_box = new Gtk.Grid ();
        content_box.attach (new CloneEntry (_("Repository URL"), remote_repository_uri_entry), 0, 0);
        content_box.attach (new CloneEntry (_("Location"), folder_chooser_button), 0, 1);
        content_box.attach (new CloneEntry (_("Name of Clone"), local_project_name_entry), 0, 2);
        content_box.attach (revealer, 1, 2);
        content_box.show_all ();

        custom_bin.add (content_box);
        custom_bin.show_all ();

        clone_button = new Gtk.Button.with_label (_(CLONE_REPOSITORY));
        clone_button.show ();
        add_action_widget (clone_button, Gtk.ResponseType.APPLY);
        bind_property ("can-clone", clone_button, "sensitive", DEFAULT | SYNC_CREATE);

        //Do not want to connect to "is-valid" property notification as this gets changed to "true" every time the entry
        //text changed. So call explicitly after we validate the text.
        can_clone = false;

        // Focus cancel button so that entry placeholder text shows
        cancel_button.grab_focus ();
    }

    public string get_projects_folder () {
        return projects_folder_label.label;
    }

    public string get_remote () {
        if (remote_repository_uri_entry.is_valid) {
            var uri = remote_repository_uri_entry.text;
            var last_separator = uri.last_index_of (Path.DIR_SEPARATOR_S);
            return uri.slice (0, last_separator + 1);
        } else {
            return suggested_remote;
        }
    }

    public string get_valid_source_repository_uri () requires (can_clone) {
        //TODO Further validation here?
        return remote_repository_uri_entry.text;
    }

    public string get_valid_target () requires (can_clone) {
        return Path.build_filename (Path.DIR_SEPARATOR_S, projects_folder_label.label, local_project_name_entry.text);
    }

    private void update_can_clone () {
        can_clone = remote_repository_uri_entry.is_valid &&
                    local_project_name_entry.is_valid &&
                    projects_folder_label.label != "";

        //TODO Check whether the target folder already exists and is not empty?
    }

    private void on_remote_uri_changed (Gtk.Editable source) {
        var entry = (Granite.ValidatedEntry)source;
        if (entry.is_valid) { //entry is a URL
            //Only accept HTTPS url atm but may also accept ssh address in future
            entry.is_valid = validate_https_address (entry.text);
        }

        update_can_clone ();
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
                if (valid) {
                    local_project_name_entry.text = parts[1].slice (0, -4);
                }
            }
        } catch (UriError e) {
            warning ("Uri split error %s", e.message);
        }

        return valid;
    }

    private void validate_local_name () {
        unowned var name = local_project_name_entry.text;
        MatchInfo? match_info;
        bool valid = false;
        if (name_regex.match (name, ANCHORED | NOTEMPTY, out match_info) && match_info.matches ()) {
            valid = !name.has_suffix (".git") && !name.has_suffix (".atom");
        }

        local_project_name_entry.is_valid = valid;
        update_can_clone ();
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
}
