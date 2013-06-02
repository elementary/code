/*
 * Copyright (c) 2011 Lucas Baudin <xapantu@gmail.com>
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

public class Euclide.Completion.Parser : GLib.Object {
    const char[] stoppers = {'\n', ' ', '.', ';', '\t', '(', ')', ',', '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '+', '-', '"', '\'', '&', '|'};
    const string[] to_ignore = {"ref", "var"};
    /* Read-only for external use */
    public Gee.ArrayList<string> words;
    public Gee.HashMap<Gtk.TextView,Gee.LinkedList<string>> text_views;
    public Parser () {
         words = new Gee.ArrayList<string> ();
         text_views = new Gee.HashMap<Gtk.TextView,Gee.LinkedList<string>> ();
    }
    
    public void clear () {
        lock (words) {
            words.clear ();
        }
    }
    
    public void parse_string (string text, Gee.List<string>? words_ = null) {
        in_comment = false;
        in_string = false;
        in_single_string = false;
        words_ = words_ ?? words;
        lock (words) {
            string current_word = "";
            for (int i = 0; i < text.length; i++) {
                var text_char = text[i];
                if (text_char in stoppers) {
                    if (current_word != "") {
                        parse_word (current_word);
                        current_word = "";
                    }
                    if (text_char == '\'')
                        in_single_string = !in_single_string;
                    if (text_char == '"')
                        in_string = !in_string;
                }
                else
                    current_word += text_char.to_string ();
            }
        }
    }
    
    bool in_comment;
    bool in_string;
    bool in_single_string;
    
    void parse_word (string word, Gee.List<string>? words_ = null) {
        if (word.contains ("/*"))
            in_comment = true;
        if (word.contains ("*/"))
            in_comment = false;
        if (in_comment || in_single_string || in_string)
            return;
        words_ = words_ ?? words;
        assert (word != "");
        if (word in to_ignore || word in words_) {
            return;
        }
        words_.add (word);
    }
    
    public List<string> get_for_word (string to_find) {
        List<string> list = new List<string> ();
        foreach (var word in words) {
            if (word.length > to_find.length 
                    && word.slice (0, to_find.length) == to_find) {
                list.append (word);
            }
        }
        return list;
    }
    
    void add_list (Gee.LinkedList<string> list) {
        foreach (var word in list) parse_word (word);
    }
    
    public void parse_text_view (Gtk.TextView view) {
        if (text_views.has_key (view)) {
            if (!view.get_data<bool> ("damaged"))
                add_list (text_views[view]);
            else {
                text_views[view].clear ();
                parse_string (view.buffer.text, text_views[view]);
                add_list (text_views[view]);
                view.set_data<bool> ("damaged", false);
            }
        }
        else {
            text_views[view] = new Gee.LinkedList<string> ();
            parse_string (view.buffer.text, text_views[view]);
            add_list (text_views[view]);
            view.set_data<bool> ("damaged", false);
            view.key_press_event.connect (() => { view.set_data<bool> ("damaged", true); return false; });
        }
    }
}
