/*
 * Copyright 2024 elementary, Inc. <https://elementary.io>
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

public class Scratch.Plugins.CompletionProvider : Gtk.SourceCompletionProvider, GLib.Object {
    private const int MAX_COMPLETIONS = 10;
    public string name { get; construct; }
    public int priority { get; construct; }
    public int interactive_delay { get; construct; }
    public Gtk.SourceCompletionActivation activation { get; construct; }

    public const string COMPLETION_END_MARK_NAME = "ScratchWordCompletionEnd";
    public const string COMPLETION_START_MARK_NAME = "ScratchWordCompletionStart";

    public Gtk.TextView? view { get; construct; }
    public Euclide.Completion.Parser parser { get; construct; }

    private unowned Gtk.TextBuffer buffer {
        get {
            return view.buffer;
        }
    }

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
        completion_end_mark = buffer.create_mark (COMPLETION_END_MARK_NAME, iter, false);
        completion_start_mark = buffer.create_mark (COMPLETION_START_MARK_NAME, iter, false);
    }

    public bool match (Gtk.SourceCompletionContext context) {
        Gtk.TextIter start, end;
        buffer.get_iter_at_offset (out end, buffer.cursor_position);
        start = end.copy ();
        Euclide.Completion.Parser.back_to_word_start (ref start);
        string text = buffer.get_text (start, end, true);

        return parser.match (text);
    }

    public void populate (Gtk.SourceCompletionContext context) {
        /*Store current insertion point for use in activate_proposal */
        GLib.List<Gtk.SourceCompletionItem>? file_props;
        bool no_minimum = (context.get_activation () == Gtk.SourceCompletionActivation.USER_REQUESTED);
        get_proposals (out file_props, no_minimum);
        context.add_proposals (this, file_props, true);
    }

    public bool activate_proposal (Gtk.SourceCompletionProposal proposal, Gtk.TextIter iter) {
        Gtk.TextIter start;
        Gtk.TextIter end;
        Gtk.TextMark mark;

        mark = buffer.get_mark (COMPLETION_END_MARK_NAME);
        buffer.get_iter_at_mark (out end, mark);

        mark = buffer.get_mark (COMPLETION_START_MARK_NAME);
        buffer.get_iter_at_mark (out start, mark);

        buffer.@delete (ref start, ref end);
        buffer.insert (ref start, proposal.get_text (), proposal.get_text ().length);
        return true;
    }

    public bool get_start_iter (Gtk.SourceCompletionContext context,
                                Gtk.SourceCompletionProposal proposal,
                                out Gtk.TextIter iter) {
        var mark = buffer.get_insert ();
        Gtk.TextIter cursor_iter;
        buffer.get_iter_at_mark (out cursor_iter, mark);

        iter = cursor_iter;
        Euclide.Completion.Parser.back_to_word_start (ref iter);
        return true;
    }


    private bool get_proposals (out GLib.List<Gtk.SourceCompletionItem>? props, bool no_minimum) {
        string to_find = "";
        Gtk.TextBuffer temp_buffer = buffer;
        props = null;

        Gtk.TextIter start, end;
        buffer.get_selection_bounds (out start, out end);

        to_find = temp_buffer.get_text (start, end, true);

        if (to_find.length == 0) {
            temp_buffer.get_iter_at_offset (out end, buffer.cursor_position);

            start = end;
            Euclide.Completion.Parser.back_to_word_start (ref start);

            to_find = buffer.get_text (start, end, false);
        }

        buffer.move_mark_by_name (COMPLETION_END_MARK_NAME, end);
        buffer.move_mark_by_name (COMPLETION_START_MARK_NAME, start);

        /* There is no minimum length of word to find if the user requested a completion */
        if (no_minimum || to_find.length >= Euclide.Completion.Parser.MINIMUM_WORD_LENGTH) {
            /* Get proposals, if any */
            List<string> prop_word_list;
            if (parser.get_for_word (to_find, out prop_word_list)) {
                foreach (var word in prop_word_list) {
                    var item = new Gtk.SourceCompletionItem ();
                    item.label = word;
                    item.text = word;
                    props.append (item);
                }

                return true;
            }
        }
        return false;
    }
}
