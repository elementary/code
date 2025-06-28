// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/***
  BEGIN LICENSE

  Copyright (C) 2015 James Morgan <james.harmonic@gmail.com>
  This program is free software: you can redistribute it and/or modify it
  under the terms of the GNU Lesser General Public License version 3, as published
  by the Free Software Foundation.

  This program is distributed in the hope that it will be useful, but
  WITHOUT ANY WARRANTY; without even the implied warranties of
  MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
  PURPOSE.  See the GNU General Public License for more details.

  You should have received a copy of the GNU General Public License along
  with this program.  If not, see <http://www.gnu.org/licenses/>

  END LICENSE
***/

public class Scratch.Plugins.PreserveIndent : Peas.ExtensionBase, Scratch.Services.ActivatablePlugin {

    private Scratch.Services.Interface plugins;
    private Gee.TreeSet<weak Services.Document> documents;
    private Services.Document active_document;
    private int last_clipboard_indent_level = 0;
    private bool waiting_for_clipboard_text = false;

    public Object object { owned get; set construct; }

    public void activate () {
        this.documents = new Gee.TreeSet<weak Services.Document> ();
        plugins = (Scratch.Services.Interface) object;

        plugins.hook_document.connect ((d) => {
            this.active_document = d;

            if (documents.add (d)) {
                d.source_view.copy_clipboard.connect (on_cut_or_copy_clipboard);
                d.source_view.cut_clipboard.connect (on_cut_or_copy_clipboard);
                d.source_view.paste_clipboard.connect (on_paste_clipboard);
                d.source_view.buffer.paste_done.connect (on_paste_done);

                d.doc_closed.connect ((d) => {
                    this.documents.remove (d);
                });
            }
        });
    }

    public void deactivate () {
        this.documents.clear ();
    }

    public void update_state () {
    }

    // determine how many characters precede a given iterator position
    private int measure_indent_at_iter (Widgets.SourceView view, Gtk.TextIter iter) {
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

    private void on_cut_or_copy_clipboard () {
        Widgets.SourceView view = this.active_document.source_view;
        if (!view.auto_indent) {
            return;
        }

        // whenever user cuts or copies, store the indent level at beginning of selection
        Gtk.TextIter select_begin, select_end;
        var buffer = view.buffer;

        if (buffer.get_selection_bounds (out select_begin, out select_end)) {
            int indent = this.measure_indent_at_iter (view, select_begin);
            this.last_clipboard_indent_level = indent;
        } else {
            this.last_clipboard_indent_level = 0;
        }
    }

    private void on_paste_clipboard () {
        Widgets.SourceView view = this.active_document.source_view;

        if (! view.auto_indent || this.waiting_for_clipboard_text) {
            return;
        }

        Gtk.TextBuffer buffer = view.buffer;
        Gtk.TextIter insert;

        buffer.get_iter_at_mark (out insert, buffer.get_insert ());
        buffer.create_mark ("paste_start", insert, true);

        this.waiting_for_clipboard_text = true;
        buffer.begin_user_action ();
    }

    // delegate to be called after the raw clipboard text has been inserted
    // finds all text that was inserted by pasting and adjusts the indent level of each
    // as necessary.
    private void on_paste_done () {

        Widgets.SourceView view = this.active_document.source_view;
        if (!view.auto_indent) {
            return;
        }

        // find the bounds of the pasted area
        Gtk.TextIter paste_begin, paste_end;

        Gtk.TextMark? mark_paste_start = view.buffer.get_mark ("paste_start");
        if (mark_paste_start == null) {
            return;
        }

        view.buffer.get_iter_at_mark (out paste_begin, view.buffer.get_mark ("paste_start"));
        view.buffer.get_iter_at_mark (out paste_end, view.buffer.get_insert ());

        int indent_level = this.measure_indent_at_iter (view, paste_begin);
        int indent_diff = indent_level - this.last_clipboard_indent_level;

        paste_begin.forward_line ();

        if (indent_diff > 0) {
            this.increase_indent_in_region (view, paste_begin, paste_end, indent_diff);
        } else if (indent_diff < 0) {
            this.decrease_indent_in_region (view, paste_begin, paste_end, indent_diff.abs ());
        }

        view.buffer.delete_mark_by_name ("paste_start");
        view.buffer.end_user_action ();
        this.waiting_for_clipboard_text = false;
    }

    private void increase_indent_in_region (
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

    private void decrease_indent_in_region (
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
}

[ModuleInit]
public void peas_register_types (GLib.TypeModule module) {
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type (typeof (Scratch.Services.ActivatablePlugin),
                                     typeof (Scratch.Plugins.PreserveIndent));
}
