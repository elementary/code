/*
* Copyright 2025 elementary, Inc. (https://elementary.io)
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 2 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA.
*
* Authored by: Jeremy Wootten <jeremywootten@gmail.com>
*/

public class Scratch.Dialogs.CloneRepositoryDialog : Granite.MessageDialog {
    public FolderManager.ProjectFolderItem? active_project { get; construct; }
    public bool can_clone { get; private set; default = false; }


    //Taken from "switchboard-plug-parental-controls/src/plug/Views/InternetView.vala"
    private const string NAME_REGEX = "^[0-9a-zA-Z_-]+$";
    private const string LOCAL_FOLDER_REGEX ="""^(/[^/ ]*)+/?$""";
    private const string URL_REGEX = "([^/w.])[-a-zA-Z0-9@:%._\\+~#=]{2,256}\\.[a-z]{1,3}([^/])\\b([-a-zA-Z0-9@:%_\\+.~#?&//=]*\\b)";
    private Regex name_regex;
    private Regex local_folder_regex;
    private Regex url_regex;
    private Granite.ValidatedEntry repository_host_uri_entry;
    private Granite.ValidatedEntry repository_user_entry;
    private Granite.ValidatedEntry repository_name_entry;
    private Granite.ValidatedEntry repository_local_folder_entry;
    private Granite.ValidatedEntry repository_local_name_entry;
    private Gtk.CheckButton set_as_active_check;

    public CloneRepositoryDialog (string local_folder) {
        Object (
            transient_for: ((Gtk.Application)(GLib.Application.get_default ())).get_active_window (),
            image_icon: new ThemedIcon ("git")
        );

        repository_local_folder_entry.text = local_folder;
        repository_host_uri_entry.text = "https://github.com";
        repository_user_entry.text = "elementary";
        repository_name_entry.text = "";
        repository_local_name_entry.text = "";

        on_is_valid_changed ();
    }

    construct {
        try {
            name_regex = new Regex (NAME_REGEX, RegexCompileFlags.OPTIMIZE);
            local_folder_regex = new Regex (LOCAL_FOLDER_REGEX, RegexCompileFlags.OPTIMIZE);
            url_regex = new Regex (URL_REGEX, RegexCompileFlags.OPTIMIZE);
        } catch (RegexError e) {
            warning ("%s\n", e.message);
        }

        add_button (_("Cancel"), Gtk.ResponseType.CANCEL);
        primary_text = _("Create a local clone of a Git repository");
        ///TRANSLATORS "Git" is a proper name and must not be translated
        secondary_text = _("The source repository and local folder must exist and be accessible");
        badge_icon = new ThemedIcon ("download");

        repository_host_uri_entry = new Granite.ValidatedEntry.from_regex (url_regex) {
            input_purpose = URL,
            activates_default = false
        };
        repository_user_entry = new Granite.ValidatedEntry.from_regex (name_regex) {
            activates_default = false
        };
        repository_name_entry = new Granite.ValidatedEntry.from_regex (name_regex) {
            activates_default = false
        };
        repository_local_folder_entry = new Granite.ValidatedEntry.from_regex (local_folder_regex) {
            activates_default = false,
            width_chars = 50
        };
        repository_local_name_entry = new Granite.ValidatedEntry.from_regex (name_regex) {
            activates_default = false,
        };

        set_as_active_check = new Gtk.CheckButton.with_label (_("Set as Active Project")) {
            margin_top = 12,
            active = true
        };

        var content_box = new Gtk.Box (VERTICAL, 12);
        content_box.add (new Granite.HeaderLabel (_("Source Repository")));
        content_box.add (new CloneEntry (_("Host URI"), repository_host_uri_entry));
        content_box.add (new CloneEntry (_("User"), repository_user_entry));
        content_box.add (new CloneEntry (_("Name"), repository_name_entry));
        content_box.add (new Granite.HeaderLabel (_("Clone")));
        content_box.add (new CloneEntry (_("Target Folder"), repository_local_folder_entry));
        content_box.add (new CloneEntry (_("Target Name"), repository_local_name_entry));
        content_box.add (set_as_active_check);

        custom_bin.add (content_box);

        var clone_button = (Gtk.Button) add_button (_("Clone Repository"), Gtk.ResponseType.APPLY);
        clone_button.can_default = true;
        clone_button.has_default = true;
        clone_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);

        repository_host_uri_entry.notify["is-valid"].connect (on_is_valid_changed);
        repository_user_entry.notify["is-valid"].connect (on_is_valid_changed);
        repository_name_entry.notify["is-valid"].connect (on_is_valid_changed);
        repository_local_folder_entry.notify["is-valid"].connect (on_is_valid_changed);

        clone_button.sensitive = can_clone;
        bind_property ("can-clone", clone_button, "sensitive");

        show_all ();
    }

    public string get_source_repository_uri () requires (can_clone) {
        //TODO Further validation here?
        var repo_uri = Path.build_path (
            Path.DIR_SEPARATOR_S,
            repository_host_uri_entry.text,
            repository_user_entry.text,
            repository_name_entry.text
        );

        if (!repo_uri.has_suffix (".git")) {
            repo_uri += ".git";
        }

        return repo_uri;
    }

    public string get_local_folder () requires (can_clone) {
        //TODO Further validation here?
        return repository_local_folder_entry.text;
    }

    public string get_local_name () requires (can_clone) {
        var local_name = repository_local_name_entry.text;
        if (local_name == "") {
            local_name = repository_name_entry.text;
        }
        //TODO Further validation here?
        return local_name;
    }

    private void on_is_valid_changed () {
        can_clone = repository_host_uri_entry.is_valid &&
                    repository_user_entry.is_valid &&
                    repository_name_entry.is_valid &&
                    repository_local_folder_entry.is_valid;
    }

    private class CloneEntry : Gtk.Box {
        public CloneEntry (string label_text, Gtk.Widget entry) {
            var label = new Gtk.Label (label_text) {
                halign = START
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
