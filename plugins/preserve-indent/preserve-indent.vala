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

using Gtk;
using Scratch;

public const string NAME = N_("Preserve Indent");
public const string DESCRIPTION = N_("Maintains indent level of pasted text when auto-indent is active");

public class Scratch.Plugins.PreserveIndent : Peas.ExtensionBase,  Peas.Activatable {
    
    public Object                      object { owned get; construct; }

    private MainWindow                 window;
    private int                        last_clipboard_indent_level = 0;
    private Services.Document?         active_document = null;        
    private Scratch.Services.Interface plugins;

    public void activate () {
        plugins = (Scratch.Services.Interface) object;
        
        plugins.hook_window.connect((w) => {
            window = w;
        });

        plugins.hook_document.connect ((d) => {
            this.active_document = this.window.get_current_document ();

            if (this.active_document == d) {
                d.source_view.copy_clipboard.connect(on_cut_or_copy_clipboard);
                d.source_view.cut_clipboard.connect(on_cut_or_copy_clipboard);
                d.source_view.paste_clipboard.connect(on_paste_clipboard);
                d.source_view.buffer.paste_done.connect(on_paste_done);       
            }
            else {
                d.source_view.copy_clipboard.disconnect(on_cut_or_copy_clipboard);
                d.source_view.cut_clipboard.disconnect(on_cut_or_copy_clipboard);
                d.source_view.paste_clipboard.disconnect(on_paste_clipboard);
                d.source_view.buffer.paste_done.disconnect(on_paste_done);       
            }
        });
    }
    
    public void deactivate () {
    }
    public void update_state () {
    }

    // determine how many whitespace characters precede a given iterator position
    private int measure_indent_at_iter(Scratch.Widgets.SourceView view, TextIter iter) {
        TextIter line_begin, pos;

        view.buffer.get_iter_at_line(out line_begin, iter.get_line());

        pos = line_begin;
        int indent = 0;
        int tabwidth = Scratch.settings.indent_width;

        unichar ch = pos.get_char();
        while (pos.get_offset() < iter.get_offset() && !ch.isgraph() && ch != '\n') {
            if (ch == ' ') 
                ++indent;   
            else if (ch == '\t') 
                indent += tabwidth;

            pos.forward_char ();
            ch = pos.get_char ();
        }
        return indent;
    }

    private void on_cut_or_copy_clipboard() {
        Scratch.Widgets.SourceView view = window.get_current_document ().source_view;
        if (! view.auto_indent)
            return;

        // whenever user cuts or copies, store the indent level at beginning of selection
        TextIter select_begin, select_end;
        var buffer = view.buffer;

        if ( buffer.get_selection_bounds (out select_begin, out select_end)) {
            int indent = this.measure_indent_at_iter(view, select_begin);
            this.last_clipboard_indent_level = indent;
        }
        else
            this.last_clipboard_indent_level = 0;
    }

    // mark the current position, so that on_paste_done knows where the cursor was 
    private void on_paste_clipboard() {
        Scratch.Widgets.SourceView view = window.get_current_document ().source_view;
        if (! view.auto_indent)
            return;

        TextBuffer buffer = view.buffer;
        TextIter insert;

        buffer.get_iter_at_mark (out insert, buffer.get_insert());
        buffer.create_mark ("paste_start", insert, true);
        buffer.begin_user_action ();
    }

    // delegate to be called after the raw clipboard text has been inserted 
    // finds all text that was inserted by pasting and adjusts the indent level of each 
    // as necessary.
    private void on_paste_done() {

        Scratch.Widgets.SourceView view = window.get_current_document ().source_view;
        if (! view.auto_indent)
            return;
            
        // find the bounds of the pasted area
        TextIter paste_begin, paste_end;

        TextMark? mark_paste_start = view.buffer.get_mark("paste_start");
        if( mark_paste_start == null) 
            return;
        
        view.buffer.get_iter_at_mark (out paste_begin, view.buffer.get_mark("paste_start"));
        view.buffer.get_iter_at_mark (out paste_end, view.buffer.get_insert());

        // compare indent level based on the indent level at last cut/copy event 
        // and the current position
        int indent_level = this.measure_indent_at_iter (view, paste_begin);
        int indent_diff  = indent_level - this.last_clipboard_indent_level;

        paste_begin.forward_line ();

        if (indent_diff > 0) 
            this.increase_indent_in_region(view, paste_begin, paste_end, indent_diff);

        else if (indent_diff < 0) 
            this.decrease_indent_in_region(view, paste_begin, paste_end, indent_diff.abs());

        view.buffer.delete_mark_by_name ("paste_start");
        view.buffer.end_user_action ();
    }

    private void increase_indent_in_region (Scratch.Widgets.SourceView view, 
                                            TextIter region_begin, 
                                            TextIter region_end, 
                                            int nchars) 
    {
        int first_line = region_begin.get_line();
        int last_line = region_end.get_line();

        int nlines = (first_line - last_line).abs() + 1;
        if ( nlines < 1 || nchars < 1 || last_line < first_line || !view.editable) 
            return;

        // add a string of whitespace to each line after the first pasted line
        string indent_str;

        if (view.insert_spaces_instead_of_tabs) 
            indent_str = string.nfill(nchars, ' ');

        else {
            int tabwidth = Scratch.settings.indent_width;
            int tabs = nchars / tabwidth;
            int spaces = nchars % tabwidth;

            indent_str = string.nfill(tabs, '\t');
            if (spaces > 0)
                indent_str += string.nfill(spaces, ' ');
        }

        TextIter itr;
        for (var i=first_line; i<=last_line; ++i) {
            view.buffer.get_iter_at_line(out itr, i);
            view.buffer.insert(ref itr, indent_str, indent_str.length);
        } 
    }

    private void decrease_indent_in_region (Scratch.Widgets.SourceView view, 
                                            TextIter region_begin, TextIter region_end, 
                                            int nchars) 
    {
        int first_line = region_begin.get_line();
        int last_line = region_end.get_line();

        int nlines = (first_line - last_line).abs() + 1;
        if ( nlines < 1 || nchars < 1 || last_line < first_line || !view.editable) 
            return;

        TextBuffer buffer = view.buffer;
        int tabwidth = Scratch.settings.indent_width;
        TextIter del_begin, del_end, itr;

        for (var line = first_line; line <= last_line; ++line) {
            buffer.get_iter_at_line(out itr, line);
            // crawl along the line and tally indentation as we go,
            // when requested number of chars is hit, or if we run out of whitespace (eg. find glyphs or newline),
            // delete the segment from line start to where we are now 
            int chars_to_delete = 0;
            int indent_chars_found = 0;
            unichar ch = itr.get_char(); 
            while(ch != '\n' && !ch.isgraph() && indent_chars_found < nchars) {
                if(ch == ' ') {
                    ++chars_to_delete;
                    ++indent_chars_found;
                }
                else if (ch == '\t') {
                    ++chars_to_delete;
                    indent_chars_found += tabwidth; 
                }
                itr.forward_char();
                ch = itr.get_char();
            }

            if( ch == '\n' || chars_to_delete < 1)
                continue;

            buffer.get_iter_at_line(out del_begin, line);
            buffer.get_iter_at_line_offset(out del_end, line, chars_to_delete);
            buffer.delete(ref del_begin, ref del_end);
        }

    }
}



[ModuleInit]
public void peas_register_types (GLib.TypeModule module) {
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type (typeof (Peas.Activatable),
                                     typeof (Scratch.Plugins.PreserveIndent));
}
