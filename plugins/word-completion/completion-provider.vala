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
 * write to the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 *
 */

using Gtk;

public class CompletionProvider : Gtk.SourceCompletionProvider, Object {
    
    static const unichar[] stoppers = {' ', '\n', '(', ';', '}', '{', '.'};
    TextMark completion_mark; /* The mark at which the proposals were generated */
    
    Gdk.Pixbuf icon;
    public string name;
    public int priority;

    public string get_name () {
        return this.name;
    }

    public int get_priority () {
        return this.priority;
    }

    public bool match (Gtk.SourceCompletionContext context) {
        return true;
    }
    
    public void populate (Gtk.SourceCompletionContext context) {        
        var file_props = get_file_proposals ();
        
        /* Get current line */
        completion_mark = current_buffer.get_insert ();
        TextIter iter;
        current_buffer.get_iter_at_mark (out iter, completion_mark);
        var line = iter.get_line () + 1;

        TextIter iter_start;
        current_buffer.get_iter_at_line (out iter_start, line - 1);
        
        // Proposal itself        
        if (file_props != null)
            context.add_proposals (this, file_props, true);
    }

    public unowned Gdk.Pixbuf? get_icon () {
        if (this.icon == null) {
            Gtk.IconTheme theme = Gtk.IconTheme.get_default ();
            try {
                this.icon = theme.load_icon (Gtk.Stock.DIALOG_INFO, 16, 0);
            } catch (GLib.Error e) {
                warning (_("Could not load icon theme: %s\n"), e.message);
            }
        }
        return this.icon;
    }

    public bool activate_proposal (Gtk.SourceCompletionProposal proposal,
                                   Gtk.TextIter iter) {

        // Count backward from completion_mark instead of iter (avoids wrong insertion if the user is typing fast) 
        TextIter start;
        current_buffer.get_iter_at_mark (out start, completion_mark);
        
        start.backward_word_start ();
        
        current_buffer.delete (ref start, ref iter);
        current_buffer.insert (ref start, proposal.get_text (), proposal.get_text ().length);
        return true;
    }

    public Gtk.SourceCompletionActivation get_activation () {
        return Gtk.SourceCompletionActivation.INTERACTIVE |
               Gtk.SourceCompletionActivation.USER_REQUESTED;
    }

    Box box_info_frame = new Box (Orientation.VERTICAL, 0);
    public unowned Gtk.Widget? get_info_widget (Gtk.SourceCompletionProposal proposal) {
        return box_info_frame;
    }

    public int get_interactive_dela () {
        return -1;
    }

    public bool get_start_it (Gtk.SourceCompletionContext context,
                                Gtk.SourceCompletionProposal proposal,
                                Gtk.TextIter iter) {
        var mark = current_buffer.get_insert ();
        TextIter cursor_iter;
        current_buffer.get_iter_at_mark (out cursor_iter, mark);
        
        iter = cursor_iter;
        iter.backward_word_start ();
        return true;
    }

    public void update_info (Gtk.SourceCompletionProposal proposal, Gtk.SourceCompletionInfo info) {
        return;
    }
    
    public GLib.List<Gtk.SourceCompletionItem>? get_file_proposals () {
        /* Compute the string we want compute */
        string to_find = "";
        string last_to_find;
        Gtk.TextIter iter;
        Gtk.TextBuffer buffer = current_buffer;
        buffer.get_iter_at_offset (out iter, buffer.cursor_position);
        iter.backward_find_char ((c) => {
            bool valid = c in stoppers;
            if (!valid)
                to_find += c.to_string ();
            return valid;
        }, null);

        to_find = to_find.reverse ();
        last_to_find = to_find;

            
        if (to_find == "")
            return null;
            
        var props = new GLib.List<Gtk.SourceCompletionItem> ();
        
        foreach (var word in parser.get_for_word (to_find)) {
            GLib.debug (word);
            var item = new Gtk.SourceCompletionItem (word,
                                                    word,
                                                    null,
                                                    null);
            props.append (item);
        }
            
        current_view.grab_focus ();
        
        return props;
    }
}
