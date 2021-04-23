/*
 * Copyright (c) 2021 elementary, Inc. (https://elementary.io)
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public
 * License as published by the Free Software Foundation; either
 * version 3 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public
 * License along with this program; if not, write to the
 * Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301 USA
 *
 * Authored by: Marius Meisenzahl <mariusmeisenzahl@gmail.com>
 */

public class Scratch.Widgets.NewAppDialog : Granite.Dialog {
    private Gtk.Entry app_name_entry;
    private Gtk.Entry your_name_entry;
    private Gtk.Entry your_email_entry;
    private Gtk.Entry your_github_entry;
    private Gtk.Button create_button;

    public signal void open_folder (string path);

    public NewAppDialog (Gtk.Window parent) {
        Object (transient_for: parent);
    }

    construct {
        var app_name_label = new Granite.HeaderLabel (_("App Name"));

        app_name_entry = new Gtk.Entry () {
            hexpand = true
        };

        var license_label = new Granite.HeaderLabel (_("License Type"));

        var license_combobox = new Gtk.ComboBoxText ();
        license_combobox.append_text ("GNU General Public License v3.0");
        license_combobox.set_active (0);

        var location_label = new Granite.HeaderLabel (_("Location"));

        var location_chooser = new Gtk.FileChooserButton (_("Select the folder where your app should be located"), Gtk.FileChooserAction.SELECT_FOLDER) {
            hexpand = true
        };
        try {
            location_chooser.set_file (File.new_for_path (Environment.get_home_dir ()));
        } catch (Error e) {
            warning ("The folder path is invalid: %s", e.message);
        }

        var your_name_label = new Granite.HeaderLabel (_("Your Name"));

        your_name_entry = new Gtk.Entry () {
            hexpand = true
        };

        var your_email_label = new Granite.HeaderLabel (_("Your Email"));

        your_email_entry = new Gtk.Entry () {
            hexpand = true
        };

        var your_github_label = new Granite.HeaderLabel (_("Your GitHub Account"));

        your_github_entry = new Gtk.Entry () {
            hexpand = true
        };

        var link_button = new Gtk.LinkButton.with_label ("https://docs.elementary.io/develop/", _("Developer Documentation…")) {
            margin_top = 14
        };

        var form_grid = new Gtk.Grid ();
        form_grid.margin_start = form_grid.margin_end = 12;
        form_grid.orientation = Gtk.Orientation.VERTICAL;
        form_grid.row_spacing = 3;
        form_grid.valign = Gtk.Align.CENTER;
        form_grid.vexpand = true;
        form_grid.add (app_name_label);
        form_grid.add (app_name_entry);
        form_grid.add (license_label);
        form_grid.add (license_combobox);
        form_grid.add (location_label);
        form_grid.add (location_chooser);
        form_grid.add (your_name_label);
        form_grid.add (your_name_entry);
        form_grid.add (your_email_label);
        form_grid.add (your_email_entry);
        form_grid.add (your_github_label);
        form_grid.add (your_github_entry);
        form_grid.add (link_button);
        form_grid.show_all ();

        deletable = false;
        modal = true;
        resizable= false;
        width_request = 560;
        window_position = Gtk.WindowPosition.CENTER_ON_PARENT;
        get_content_area ().add (form_grid);

        var cancel_button = add_button (_("Cancel"), Gtk.ResponseType.CANCEL);
        cancel_button.margin_bottom = 6;
        cancel_button.margin_top = 14;

        create_button = (Gtk.Button) add_button (_("Create App"), Gtk.ResponseType.OK);
        create_button.margin = 6;
        create_button.margin_start = 0;
        create_button.margin_top = 14;
        create_button.can_default = true;
        create_button.sensitive = false;
        create_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);

        app_name_entry.changed.connect (() => {
            update_create_button ();
        });

        your_name_entry.changed.connect (() => {
            update_create_button ();
        });

        your_email_entry.changed.connect (() => {
            update_create_button ();
        });

        your_github_entry.changed.connect (() => {
            update_create_button ();
        });

        response.connect ((response_id) => {
            if (response_id == Gtk.ResponseType.OK) {
                var context = new Gee.HashMap<string, string> ();
                context["app_name"] = app_name_entry.text;
                context["your_name"] = your_name_entry.text;
                context["your_email"] = your_email_entry.text;
                context["github_username"] = your_github_entry.text;
                context["github_repository"] = app_name_entry.text.down ().replace (" ", "-");
                context["github_sha"] = "{{ github.sha }}";
                context["license_code"] = "gpl-3.0";
                context["current_year"] = "%d".printf (new DateTime.now_local ().get_year ());

                const string APP_TEMPLATE_FOLDER = "/home/marius/Projekte/github.com/elementary/code/data/templates/app";
                var src = APP_TEMPLATE_FOLDER;
                var dest = Path.build_filename (location_chooser.get_filename (), context["github_repository"]);
                copy_recursive_with_context (src, dest, context);

                open_folder (dest);
            }

            destroy ();
        });
    }

    private void update_create_button () {
        if (app_name_entry.text.length > 0 &&
            your_name_entry.text.length > 0 &&
            your_email_entry.text.length > 0 &&
            your_github_entry.text.length > 0) {
            create_button.sensitive = true;
            create_button.has_default = true;
        } else {
            create_button.sensitive = false;
        }
    }

    private bool copy_recursive_with_context (string src, string dest, Gee.HashMap<string, string> context, FileCopyFlags flags = FileCopyFlags.NONE, Cancellable? cancellable = null) throws Error {
        var template = new Services.AppTemplate (dest);
        var src_path = src;
        var dest_path = template.render (context);

        var src_file = File.new_for_path (src_path);
        var dest_file = File.new_for_path (dest_path);

        FileType src_type = src_file.query_file_type (FileQueryInfoFlags.NONE, cancellable);
        if (src_type == FileType.DIRECTORY) {
            dest_file.make_directory (cancellable);
            src_file.copy_attributes (dest_file, flags, cancellable);

            FileEnumerator enumerator = src_file.enumerate_children (FileAttribute.STANDARD_NAME, FileQueryInfoFlags.NONE, cancellable);
            for (FileInfo? info = enumerator.next_file (cancellable); info != null; info = enumerator.next_file (cancellable)) {
                copy_recursive_with_context (
                    Path.build_filename (src_path, info.get_name ()),
                    Path.build_filename (dest_path, info.get_name ()),
                    context,
                    flags,
                    cancellable
                );
            }
        } else if (src_type == FileType.REGULAR) {
            src_file.copy (dest_file, flags, cancellable);
            string content;
            FileUtils.get_contents (dest_path, out content);
            template = new Services.AppTemplate (content);
            string new_content = template.render (context);
            FileUtils.set_contents (dest_path, new_content);
            // TODO: set mode
        }

        return true;
    }
}
