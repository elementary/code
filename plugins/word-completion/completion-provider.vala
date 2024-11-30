/*
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

public class Scratch.Plugins.CompletionProvider : Gtk.SourceCompletionProvider, Object {
    public string name;
    public int priority;

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
        Gtk.TextView _view
        ) {

        Object (
            parser: _parser,
            view: _view
        );
    }

    construct {
        Gtk.TextIter iter;
        view.buffer.get_iter_at_offset (out iter, 0);
        completion_end_mark = buffer.create_mark (COMPLETION_END_MARK_NAME, iter, false);
        completion_start_mark = buffer.create_mark (COMPLETION_START_MARK_NAME, iter, false);
    }

    public string get_name () {
        return this.name;
    }

    public int get_priority () {
        return this.priority;
    }

    public bool match (Gtk.SourceCompletionContext context) {
        int start_pos = buffer.cursor_position;
        parser.backward_word_start (buffer.text, ref start_pos);
        current_text_to_find = buffer.text.slice (start_pos, buffer.cursor_position);
        var found = parser.match (current_text_to_find);

        return found;
    }

    private bool is_delimiter (unichar uc) {
        return Euclide.Completion.Parser.is_delimiter (uc);
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
        Gtk.TextIter end_iter;
        Gtk.TextMark mark;

        mark = buffer.get_mark (COMPLETION_END_MARK_NAME);
        buffer.get_iter_at_mark (out end_iter, mark);

        // If inserting in middle of word then completion overwrites end of word
        var end_pos = end_iter.get_offset ();
        unichar? uc;
        if (buffer.text.get_next_char (ref end_pos, out uc) && !is_delimiter (uc)) {
            parser.forward_word_end (buffer.text, ref end_pos);
            buffer.get_iter_at_offset (out end_iter, end_pos);
        }

        mark = buffer.get_mark (COMPLETION_START_MARK_NAME);
        buffer.get_iter_at_mark (out start, mark);

        buffer.@delete (ref start, ref end_iter);
        buffer.insert (ref start, proposal.get_text (), proposal.get_text ().length);
        return true;
    }

    public Gtk.SourceCompletionActivation get_activation () {
        return Gtk.SourceCompletionActivation.INTERACTIVE |
               Gtk.SourceCompletionActivation.USER_REQUESTED;
    }

    public int get_interactive_delay () {
        return 0;
    }

    public bool get_start_iter (Gtk.SourceCompletionContext context,
                                Gtk.SourceCompletionProposal proposal,
                                out Gtk.TextIter iter) {

        var word_start = buffer.cursor_position;
        buffer.get_iter_at_offset (out iter, word_start);
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
            to_find = current_text_to_find;
        }

        buffer.move_mark_by_name (COMPLETION_END_MARK_NAME, end);
        buffer.move_mark_by_name (COMPLETION_START_MARK_NAME, start);

        /* There is no minimum length of word to find if the user requested a completion */
        if (no_minimum || to_find.length >= Euclide.Completion.Parser.MINIMUM_PREFIX_LENGTH) {
            /* Get proposals, if any */
            List<string> completions;
            if (parser.get_completions_for_prefix (to_find, out completions)) {
                foreach (var completion in completions) {
                    if (completion.length > 0) {
                        var item = new Gtk.SourceCompletionItem ();
                        var word = to_find + completion;
                        item.label = word;
                        item.text = completion;
                        props.append (item);
                    }
                }

                return true;
            }
        }
        return false;
    }
}
