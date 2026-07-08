/*
 * Copyright 2024-2025 elementary, Inc. <https://elementary.io>
 * Copyright (c) 2013 Mario Guerriero <mario@elementaryos.org>
 *
 * This is a free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; either version 2 of the
 * License, or (at your option) any later version.
 *
 * This is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public
 * License along with this program; see the file COPYING.  If not,
 * write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301 USA.
 *
 */

public class Scratch.Plugins.CompletionProvider : GtkSource.CompletionProvider, GLib.Object {
    private const int MAX_COMPLETIONS = 10;
    public string name { get; construct; }
    public int priority { get; construct; }
    public int interactive_delay { get; construct; }
    public GtkSource.CompletionActivation activation { get; construct; }

    public const string COMPLETION_END_MARK_NAME = "ScratchWordCompletionEnd";
    public const string COMPLETION_START_MARK_NAME = "ScratchWordCompletionStart";

    public Gtk.TextView? view { get; construct; }
    public Euclide.Completion.Parser parser { get; construct; }

    // private unowned Gtk.TextBuffer buffer {
    //     get {
    //         return view.buffer;
    //     }
    // }

    private Gtk.TextMark completion_end_mark;
    private Gtk.TextMark completion_start_mark;
    private string current_text_to_find = "";

    public signal void can_propose (bool b);

    public CompletionProvider (
        Euclide.Completion.Parser _parser,
        Scratch.Services.Document _doc
        ) {

        Object (
            parser: _parser,
            view: _doc.source_view,
            name: _("%s - Word Completion").printf (_doc.get_basename ())
        );
    }

    construct {
        interactive_delay = (int) Completion.INTERACTIVE_DELAY;
        activation = INTERACTIVE | USER_REQUESTED;
        Gtk.TextIter iter;
        view.buffer.get_iter_at_offset (out iter, 0);
        completion_end_mark = view.buffer.create_mark (COMPLETION_END_MARK_NAME, iter, false);
        completion_start_mark = view.buffer.create_mark (COMPLETION_START_MARK_NAME, iter, false);
    }

    public bool match (GtkSource.CompletionContext context) {
        Gtk.TextIter start, end;
        var buff = context.get_buffer ();
        buff.get_iter_at_offset (out end, buff.cursor_position);
        start = end.copy ();
        Euclide.Completion.Parser.back_to_word_start (ref start);
        string text = buff.get_text (start, end, true);

        return parser.match (text);
    }

    public async ListModel populate_async (GtkSource.CompletionContext context, Cancellable? cancellable) throws Error {
        /*Store current insertion point for use in activate_proposal */
        bool no_minimum = (context.get_activation () == GtkSource.CompletionActivation.USER_REQUESTED);
        return yield get_proposals (context, no_minimum);
    }

    public void display (
        GtkSource.CompletionContext context,
        GtkSource.CompletionProposal proposal,
        GtkSource.CompletionCell cell
    ) {
        var columntype = cell.column;
        warning ("filling column %s", columntype.to_string ());
        // For now only fill TYPED_TEXT
        if (columntype == TYPED_TEXT) {
            cell.text = ((CompletionItem) proposal).label;
        };
    }

    public void activate (
        GtkSource.CompletionContext context,
        GtkSource.CompletionProposal proposal
    ) {
        Gtk.TextIter start;
        Gtk.TextIter end;
        Gtk.TextMark mark;
        var completion_item = (CompletionItem) proposal;
        var buff = context.get_buffer ();
        mark = buff.get_mark (COMPLETION_END_MARK_NAME);
        buff.get_iter_at_mark (out end, mark);

        mark = buff.get_mark (COMPLETION_START_MARK_NAME);
        buff.get_iter_at_mark (out start, mark);

        buff.@delete (ref start, ref end);
        buff.insert (ref start, completion_item.text, completion_item.text.length);
    }

    public void refilter (GtkSource.CompletionContext context, ListModel model) {
        //TODO Allow refiltering of the model
    }

    public bool get_start_iter (GtkSource.CompletionContext context,
                                GtkSource.CompletionProposal proposal,
                                out Gtk.TextIter iter) {
        var mark = context.get_buffer ().get_insert ();
        Gtk.TextIter cursor_iter;
        context.get_buffer ().get_iter_at_mark (out cursor_iter, mark);

        iter = cursor_iter;
        Euclide.Completion.Parser.back_to_word_start (ref iter);
        return true;
    }

    private async ListModel get_proposals (GtkSource.CompletionContext context, bool no_minimum) throws Error {
        // Just throw IOERROR for now - not worth registering domain
        var model = new ListStore (typeof (GtkSource.CompletionProposal));
        // string to_find = "";
        var buff = context.get_buffer ();
        // props = null;

        Gtk.TextIter start, end;
        context.get_bounds (out start, out end);

        var to_find = context.get_word ();

        if (to_find.length == 0) {
            buff.get_iter_at_offset (out end, buff.cursor_position);
            start = end;
            Euclide.Completion.Parser.back_to_word_start (ref start);
        }

        // Do we need this?
        buff.move_mark_by_name (COMPLETION_END_MARK_NAME, end);
        buff.move_mark_by_name (COMPLETION_START_MARK_NAME, start);

        /* There is no minimum length of word to find if the user requested a completion */
        if (!no_minimum && to_find.length < Euclide.Completion.Parser.MINIMUM_WORD_LENGTH) {
            throw new IOError.INVALID_DATA ("Word to find shorter than minimum");
        } else {
            /* Get proposals, if any */
            List<string> prop_word_list;
            if (parser.get_for_word (to_find, out prop_word_list)) {
                foreach (var word in prop_word_list) {
                    var item = new CompletionItem () {
                        label = word,  // What is displayed
                        text = word  // What gets inserted
                    };

                    model.append (item);
                }
            } else {
                throw new IOError.NOT_FOUND ("No proposals found");
            }
        }

        return model;
    }

    private class CompletionItem : Object, GtkSource.CompletionProposal {
        public string label { get; set construct; }
        public string text { get; set construct; }
    }
}
