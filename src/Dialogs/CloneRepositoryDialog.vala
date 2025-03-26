/*
* Copyright 2021 elementary, Inc. (https://elementary.io)
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
* Authored by: Jeremy Wootten <jeremy@elementaryos.org>
*/

public class Scratch.Dialogs.CloneRepositoryDialog : Granite.MessageDialog {
    public FolderManager.ProjectFolderItem? active_project { get; construct; }
    public bool can_clone { get; private set; default = false; }


    //Taken from "switchboard-plug-parental-controls/src/plug/Views/InternetView.vala"
    private const string NAME_REGEX = """[/w.-]+""";
    private const string LOCAL_FOLDER_REGEX ="^/[0-9a-zA-Z_-]+$";
    private const string URL_REGEX = "([^/w.])[-a-zA-Z0-9@:%._\\+~#=]{2,256}\\.[a-z]{1,3}([^/])\\b([-a-zA-Z0-9@:%_\\+.~#?&//=]*\\b)";
    private Regex name_regex;
    private Regex local_folder_regex;
    private Regex url_regex;
    private Granite.ValidatedEntry repository_host_uri_entry;
    private Granite.ValidatedEntry repository_user_entry;
    private Granite.ValidatedEntry repository_name_entry;
    private Granite.ValidatedEntry repository_local_folder_entry;
    public string initial_folder = "";

    public CloneRepositoryDialog (string local_folder) {
        Object (
            transient_for: ((Gtk.Application)(GLib.Application.get_default ())).get_active_window (),
            image_icon: new ThemedIcon ("git")
        );

        repository_local_folder_entry.text = local_folder;
        repository_host_uri_entry.text = "https://github.com";
        repository_user_entry.text = "elementary";
        repository_name_entry.text = "";
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
        primary_text = _("Create a local clone of a git repository");
        ///TRANSLATORS "Git" is a proper name and must not be translated
        secondary_text = _("The source repository and local folder must exist and be accessible");
        badge_icon = new ThemedIcon ("download");
        var repository_name_label = new Gtk.Label (_("Source Repository Name"));
        repository_name_entry = new Granite.ValidatedEntry.from_regex (name_regex) {
            activates_default = false
        };
        var repository_user_label = new Gtk.Label (_("Source Repository User"));
        repository_user_entry = new Granite.ValidatedEntry.from_regex (name_regex) {
            activates_default = false
        };
        var repository_host_uri_label = new Gtk.Label (_("Source Repository Host URI"));
        repository_host_uri_entry = new Granite.ValidatedEntry.from_regex (url_regex) {
            activates_default = false
        };
        var repository_local_folder_label = new Gtk.Label (_("Target Folder"));
        repository_local_folder_entry = new Granite.ValidatedEntry.from_regex (local_folder_regex) {
            activates_default = false
        };
        var content_grid = new Gtk.Grid ();
        content_grid.attach (repository_host_uri_label, 0, 0);
        content_grid.attach (repository_host_uri_entry, 1, 0);
        content_grid.attach (repository_user_label, 0, 1);
        content_grid.attach (repository_user_entry, 1, 1);
        content_grid.attach (repository_name_label, 0, 2);
        content_grid.attach (repository_name_entry, 1, 2);
        content_grid.attach (repository_local_folder_label, 0, 3);
        content_grid.attach (repository_local_folder_entry, 1, 3);
        custom_bin.add (content_grid);

        var clone_button = (Gtk.Button) add_button (_("Clone Repository"), Gtk.ResponseType.APPLY);
        clone_button.can_default = true;
        clone_button.has_default = true;
        clone_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);

        repository_host_uri_entry.notify["is-valid"].connect (on_is_valid_changed);
        repository_user_entry.notify["is-valid"].connect (on_is_valid_changed);
        repository_name_entry.notify["is-valid"].connect (on_is_valid_changed);
        repository_local_folder_entry.notify["is-valid"].connect (on_is_valid_changed);

        bind_property ("can-clone", clone_button, "sensitive");
    }

    public string get_source_repository_uri () {
        if (!can_clone) {
            return "";
        }

        //TODO Further validation here?
        return Path.build_path (
            Path.DIR_SEPARATOR_S,
            repository_host_uri_entry.text,
            repository_user_entry.text,
            repository_name_entry.text
        );
    }

    public string get_local_folder () {
        if (!can_clone) {
            return "";
        }

        //TODO Further validation here?
        return repository_local_folder_entry.text;
    }
    private void on_is_valid_changed () {
        can_clone = repository_host_uri_entry.is_valid &&
                    repository_user_entry.is_valid &&
                    repository_name_entry.is_valid &&
                    repository_local_folder_entry.is_valid;
    }
}
