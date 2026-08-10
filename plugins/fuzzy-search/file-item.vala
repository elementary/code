/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2023-2026 elementary, Inc. <https://elementary.io>
 *
 * Authored by: Marvin Ahlgrimm
 *              Colin Kiama <colinkiama@gmail.com>
 */

public class FileItem : Gtk.ListBoxRow {
    public SearchResult result { get; construct; }

    public string filepath {
        get {
            return result.full_path;
        }
    }

    public FileItem (SearchResult result, bool should_distinguish_project = false) {
        Object (result: result);

        var filename_label = new Gtk.Label (Path.get_basename (result.relative_path)) {
            halign = START
        };

        var path_label = new Gtk.Label (
            @"$(should_distinguish_project ? result.project + " → " : "")$(result.relative_path)"
        ) {
            ellipsize = MIDDLE,
            halign = START
        };
        path_label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);
        path_label.get_style_context ().add_class (Granite.STYLE_CLASS_SMALL_LABEL);

        Icon icon;
        try {
            var fi = File.new_for_path (result.full_path);
            var info = fi.query_info ("standard::*", 0);
            icon = ContentType.get_icon (info.get_content_type ());
        } catch (Error e) {
            icon = ContentType.get_icon ("text/plain");
        }

        var image = new Gtk.Image.from_gicon (icon, Gtk.IconSize.DND);

        var path_box = new Gtk.Box (VERTICAL, 0) {
            valign = CENTER
        };
        path_box.add (filename_label);
        path_box.add (path_label);

        var container_box = new Gtk.Box (HORIZONTAL, 12);
        container_box.add (image);
        container_box.add (path_box);

        get_style_context ().add_class ("fuzzy-item");
        get_style_context ().add_class ("flat");
        child = container_box;
    }
}
