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

public class Scratch.Plugins.PreserveIndent : Peas.ExtensionBase, Peas.Activatable {

    private Scratch.Services.Interface plugins;
    private Gee.TreeSet<weak Services.Document> documents;
    private Services.Document active_document;
    private int last_clipboard_indent_level = 0;
    private bool waiting_for_clipboard_text = false;

    public Object object { owned get; construct; }

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

    private void on_cut_or_copy_clipboard () {
        Widgets.SourceView view = this.active_document.source_view;
        if (!view.auto_indent) {
            return;
        }

        // whenever user cuts or copies, store the indent level at beginning of selection
        Gtk.TextIter select_begin, select_end;
        var buffer = view.buffer;

        if (buffer.get_selection_bounds (out select_begin, out select_end)) {
            int indent = Scratch.Utils.measure_indent_at_iter (view, select_begin);
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

        int indent_level = Scratch.Utils.measure_indent_at_iter (view, paste_begin);
        int indent_diff = indent_level - this.last_clipboard_indent_level;

        paste_begin.forward_line ();

        if (indent_diff > 0) {
            Scratch.Utils.increase_indent_in_region (view, paste_begin, paste_end, indent_diff);
        } else if (indent_diff < 0) {
            Scratch.Utils.decrease_indent_in_region (view, paste_begin, paste_end, indent_diff.abs ());
        }

        view.buffer.delete_mark_by_name ("paste_start");
        view.buffer.end_user_action ();
        this.waiting_for_clipboard_text = false;
    }
}

[ModuleInit]
public void peas_register_types (GLib.TypeModule module) {
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type (typeof (Peas.Activatable),
                                     typeof (Scratch.Plugins.PreserveIndent));
}
