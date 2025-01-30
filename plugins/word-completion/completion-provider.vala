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

    private Gtk.TextView? view;
    private Gtk.TextBuffer? buffer;
    private Euclide.Completion.Parser parser;
    private Gtk.TextMark completion_end_mark;
    private Gtk.TextMark completion_start_mark;

    public signal void can_propose (bool b);

    public CompletionProvider (Scratch.Plugins.Completion completion) {
        this.view = completion.current_view as Gtk.TextView;
        this.buffer = completion.current_view.buffer;
        this.parser = completion.parser;
        Gtk.TextIter iter;
        buffer.get_iter_at_offset (out iter, 0);
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
        Gtk.TextIter iter;
        buffer.get_iter_at_offset (out iter, buffer.cursor_position);
        string text = parser.get_word_immediately_before (iter);

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

    public Gtk.SourceCompletionActivation get_activation () {
        return Gtk.SourceCompletionActivation.INTERACTIVE |
               Gtk.SourceCompletionActivation.USER_REQUESTED;
    }

    public int get_interactive_delay () {
        return 0;
    }

    private bool get_proposals (out GLib.List<Gtk.SourceCompletionItem>? props, bool no_minimum) {
        string to_find = "";
        Gtk.TextBuffer temp_buffer = buffer;
        props = null;

        Gtk.TextIter start, end;
        buffer.get_selection_bounds (out start, out end);

        to_find = temp_buffer.get_text (start, end, true);

        if (to_find.length == 0) {
            Gtk.TextIter iter;
            temp_buffer.get_iter_at_offset (out iter, buffer.cursor_position);
            to_find = parser.get_word_immediately_before (iter);
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
