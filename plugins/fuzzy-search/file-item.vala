/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2023-2026 elementary, Inc. <https://elementary.io>
 *
 * Authored by: Marvin Ahlgrimm
 *              Colin Kiama <colinkiama@gmail.com>
 */

public class FileItem : Gtk.ListBoxRow {
    public SearchResult result { get; private set; }

    public string filepath {
        get {
            return result.full_path;
        }
    }

    public FileItem (SearchResult res, bool should_distinguish_project = false) {
        this.get_style_context ().add_class ("fuzzy-item");
        this.get_style_context ().add_class ("flat");

        result = res;
        Icon icon;
        var path_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 1);
        path_box.valign = Gtk.Align.CENTER;

        var path_label = new Gtk.Label (get_path_label (should_distinguish_project)) {
            halign = START,
            ellipsize = MIDDLE
        };

        var filename_label = new Gtk.Label (Path.get_basename (result.relative_path));
        filename_label.halign = Gtk.Align.START;

        try {
            var fi = File.new_for_path (result.full_path);
            var info = fi.query_info ("standard::*", 0);
            icon = ContentType.get_icon (info.get_content_type ());
        } catch (Error e) {
            icon = ContentType.get_icon ("text/plain");
        }

        var image = new Gtk.Image.from_gicon (icon, Gtk.IconSize.DND);
        image.get_style_context ().add_class ("fuzzy-file-icon");

        path_box.add (filename_label);
        path_box.add (path_label);

        var container_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 1) {
            valign = Gtk.Align.CENTER
        };

        container_box.add (image);
        container_box.add (path_box);

        this.child = container_box;
    }

    private string get_path_label (bool show_project) {
        if (!show_project) {
            return result.relative_path;
        }

        if (Gtk.StateFlags.DIR_RTL in get_state_flags ()) {
            return "%s ← %s".printf (result.relative_path, result.project);
        }

        return "%s → %s".printf (result.project, result.relative_path);
    }
}
