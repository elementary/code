// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*
* Copyright (c) 2013 Mario Guerriero <mefrio.g@gmail.com>
*               2017 elementary LLC. <https://elementary.io>
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
*/

namespace Scratch.Utils {
    public string? last_path = null;

    public SimpleAction action_from_group (string action_name, SimpleActionGroup action_group) {
        return ((SimpleAction) action_group.lookup_action (action_name));
    }

    /* Ported (with corrections and improvements) from libdazzle
     * (https://gitlab.gnome.org/GNOME/libdazzle/-/blob/master/src/util/dzl-pango.c)
     */
    public string pango_font_description_to_css (Pango.FontDescription font_descr) {
        var sb = new StringBuilder ("");
        var mask = font_descr.get_set_fields ();
        if (Pango.FontMask.FAMILY in mask) {
            unowned string family = font_descr.get_family ();
            sb.append_printf ("font-family: \"%s\";", family);
        }

        if (Pango.FontMask.STYLE in mask) {
            var style = font_descr.get_style ();

            switch (style) {
                case Pango.Style.NORMAL:
                    sb.append ("font-style: normal;");
                    break;

                case Pango.Style.ITALIC:
                    sb.append ("font-style: italic;");
                    break;

                case Pango.Style.OBLIQUE:
                    sb.append ("font-style: bold;");
                    break;

                default:
                    break;
            }
        }

        if (Pango.FontMask.VARIANT in mask) {
            var variant = font_descr.get_variant ();
            switch (variant) {
                case Pango.Variant.NORMAL:
                    sb.append ("font-variant: normal;");
                    break;

                case Pango.Variant.SMALL_CAPS:
                    sb.append ("font-variant: small-caps");
                    break;

                default:
                    break;
            }
        }

        if (Pango.FontMask.WEIGHT in mask) {
            var weight = ((int)(font_descr.get_weight () / 100 * 100)).clamp (100, 900);

            sb.append_printf ("font-weight: %i;", weight);
        }

        if (Pango.FontMask.STRETCH in mask) {
            var stretch = font_descr.get_stretch ();

            switch (stretch) {
                case Pango.Stretch.NORMAL:
                    sb.append_printf ("font-stretch: %s;", "normal");
                    break;

                case Pango.Stretch.ULTRA_CONDENSED:
                    sb.append_printf ("font-stretch: %s;", "condensed");
                    break;

                case Pango.Stretch.EXTRA_CONDENSED:
                    sb.append_printf ("font-stretch: %s;", "extra-condensed");
                    break;

                case Pango.Stretch.CONDENSED:
                    sb.append_printf ("font-stretch: %s;", "condensed");
                    break;

                case Pango.Stretch.SEMI_CONDENSED:
                    sb.append_printf ("font-stretch: %s;", "normal");
                    break;

                case Pango.Stretch.SEMI_EXPANDED:
                    sb.append_printf ("font-stretch: %s;", "semi-expanded");
                    break;

                case Pango.Stretch.EXPANDED:
                    sb.append_printf ("font-stretch: %s;", "expanded");
                    break;

                case Pango.Stretch.EXTRA_EXPANDED:
                    sb.append_printf ("font-stretch: %s;", "extra-expanded");
                    break;

                case Pango.Stretch.ULTRA_EXPANDED:
                    sb.append_printf ("font-stretch: %s;", "ultra-expanded");
                    break;

                default:
                    break;

            }
        }

        if (Pango.FontMask.SIZE in mask) {
            var font_size = font_descr.get_size () / Pango.SCALE;
            sb.append_printf ("font-size: %dpt;", font_size);
        }

        return sb.str;
    }

    public string replace_home_with_tilde (string path) {
        var home_dir = Environment.get_home_dir ();
        if (path.has_prefix (home_dir)) {
            return "~" + path.substring (home_dir.length);
        } else {
            return path;
        }
    }

    // determine how many characters precede a given iterator position
    public int measure_indent_at_iter (Widgets.SourceView view, Gtk.TextIter iter) {
        Gtk.TextIter line_begin, pos;

        view.buffer.get_iter_at_line (out line_begin, iter.get_line ());

        pos = line_begin;
        int indent = 0;
        int tabwidth = Scratch.settings.get_int ("indent-width");

        unichar ch = pos.get_char ();
        while (pos.get_offset () < iter.get_offset () && ch != '\n' && ch.isspace ()) {
            if (ch == '\t') {
                indent += tabwidth;
            } else {
                ++indent;
            }

            pos.forward_char ();
            ch = pos.get_char ();
        }
        return indent;
    }

    public void increase_indent_in_region (
        Widgets.SourceView view,
        Gtk.TextIter region_begin,
        Gtk.TextIter region_end,
        int nchars
    ) {
        int first_line = region_begin.get_line ();
        int last_line = region_end.get_line ();
        int buf_last_line = view.buffer.get_line_count () - 1;

        int nlines = (first_line - last_line).abs () + 1;
        if (nlines < 1 || nchars < 1 || last_line < first_line || !view.editable
            || first_line == buf_last_line
        ) {
            return;
        }

        // add a string of whitespace to each line after the first pasted line
        string indent_str;

        if (view.insert_spaces_instead_of_tabs) {
            indent_str = string.nfill (nchars, ' ');
        } else {
            int tabwidth = Scratch.settings.get_int ("indent-width");
            int tabs = nchars / tabwidth;
            int spaces = nchars % tabwidth;

            indent_str = string.nfill (tabs, '\t');
            if (spaces > 0) {
                indent_str += string.nfill (spaces, ' ');
            }
        }

        Gtk.TextIter itr;
        for (var i = first_line; i <= last_line; ++i) {
            view.buffer.get_iter_at_line (out itr, i);
            view.buffer.insert (ref itr, indent_str, indent_str.length);
        }
    }

    public void decrease_indent_in_region (
        Widgets.SourceView view,
        Gtk.TextIter region_begin,
        Gtk.TextIter region_end,
        int nchars
    ) {
        int first_line = region_begin.get_line ();
        int last_line = region_end.get_line ();

        int nlines = (first_line - last_line).abs () + 1;
        if (nlines < 1 || nchars < 1 || last_line < first_line || !view.editable) {
            return;
        }

        Gtk.TextBuffer buffer = view.buffer;
        int tabwidth = Scratch.settings.get_int ("indent-width");
        Gtk.TextIter del_begin, del_end, itr;

        for (var line = first_line; line <= last_line; ++line) {
            buffer.get_iter_at_line (out itr, line);
            // crawl along the line and tally indentation as we go,
            // when requested number of chars is hit, or if we run out of whitespace (eg. find glyphs or newline),
            // delete the segment from line start to where we are now
            int chars_to_delete = 0;
            int indent_chars_found = 0;
            unichar ch = itr.get_char ();
            while (ch != '\n' && !ch.isgraph () && indent_chars_found < nchars) {
                if (ch == ' ') {
                    ++chars_to_delete;
                    ++indent_chars_found;
                } else if (ch == '\t') {
                    ++chars_to_delete;
                    indent_chars_found += tabwidth;
                }
                itr.forward_char ();
                ch = itr.get_char ();
            }

            if (ch == '\n' || chars_to_delete < 1) {
                continue;
            }

            buffer.get_iter_at_line (out del_begin, line);
            buffer.get_iter_at_line_offset (out del_end, line, chars_to_delete);
            buffer.delete (ref del_begin, ref del_end);
        }
    }

    public bool find_unique_path (File f1, File f2, out string? path1, out string? path2) {
        if (f1.equal (f2)) {
            path1 = null;
            path2 = null;
            return false;
        }

        var f1_parent = f1.get_parent ();
        var f2_parent = f2.get_parent ();

        while (f1_parent.get_relative_path (f1) == f2_parent.get_relative_path (f2)) {
            f1_parent = f1_parent.get_parent ();
            f2_parent = f2_parent.get_parent ();
        }

        path1 = f1_parent.get_relative_path (f1);
        path2 = f2_parent.get_relative_path (f2);
        return true;
    }

}
