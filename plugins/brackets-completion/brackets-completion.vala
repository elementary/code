// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/***
  BEGIN LICENSE
	
  Copyright (C) 2013 Mario Guerriero <mario@elementaryos.org>
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

public const string NAME = _("Brackets Completion");
public const string DESCRIPTION = _("Complete brackets while typing");

public class Scratch.Plugins.BracketsCompletion : Peas.ExtensionBase,  Peas.Activatable {
    Gee.HashMap<string, string> brackets;
    
    /* saves, when left bracket is deleted, if right bracket will also be deleted 
    We take ( and " as an example. If you type '(' and then you also get ')' and then you hit Backspace
    it is very unlikely the user wants to keep ')'
    But it might be different with " because the user maybe wants to have only one.
    */

    Gee.TreeSet<Gtk.TextBuffer> buffers;
    Gtk.TextBuffer current_buffer;
    string last_inserted;
    
    bool attention_bracket;
    

    Scratch.Services.Interface plugins;
    public Object object { owned get; construct; }

    public void update_state () {
        
    }

    public void activate () {
        this.buffers = new Gee.TreeSet<Gtk.TextBuffer> ();
        
        this.brackets = new Gee.HashMap<string, string> ();
        this.brackets.set ("(", ")");
        this.brackets.set ("[", "]");
        this.brackets.set ("{", "}");
        this.brackets.set ("<", ">");
        this.brackets.set ("⟨", "⟩");
        this.brackets.set ("｢", "｣");
        this.brackets.set ("⸤", "⸥");
        this.brackets.set ("‘", "‘");
        this.brackets.set ("'", "'");
        this.brackets.set ("\"", "\"");
  
        
        attention_bracket = false;    
        
        plugins = (Scratch.Services.Interface) object;
        plugins.hook_document.connect ((doc) => {
            var buf = doc.source_view.buffer;
            buf.insert_text.disconnect (on_insert_text);
            buf.insert_text.connect (on_insert_text);
            this.buffers.add (buf);
            this.current_buffer = buf;
            
            doc.source_view.move_cursor.connect ((a, b, c) => {
                // if cursor moves around code doesnt care about brackets anymore
                attention_bracket = false;
            });
            
            doc.source_view.backspace.connect (() => {
                if (attention_bracket) {
                    
                    Gtk.TextIter left_iter;
                    buf.get_iter_at_mark(out left_iter, buf.get_insert());
                    
                    var right_iter = left_iter;
                    
                    right_iter.forward_cursor_positions (1);
                    buf.@delete(ref left_iter, ref right_iter); 
                    
                    attention_bracket = false;                      
                }
            });  
        });
    }

    public void deactivate () {
        foreach (var buf in buffers) {
            buf.insert_text.disconnect (on_insert_text);
        }
    }

    void on_insert_text (ref Gtk.TextIter pos, string new_text, int new_text_length) {
        // if text changes code doesnt care about last brackets anymore
        attention_bracket = false;
        
        // If you are copy/pasting a large amount of text...
        if (new_text_length > 1) {
            return;
        }

        // To avoid infinite loop
        if (this.last_inserted == new_text) {
            return;
        }

        if (new_text in this.brackets.keys) {
            var buf = this.current_buffer;

            string text = this.brackets.get (new_text);
            int len = text.length;
            this.last_inserted = text;
            buf.insert (ref pos, text, len);

            attention_bracket = true;

            //To make " and ' brackets work correctly (opening and closing chars are the same)
            this.last_inserted = null;

            pos.backward_chars (len);
            buf.place_cursor (pos);
        } else if (new_text in this.brackets.values) { // Handle matching closing brackets.
            var buf = this.current_buffer;
            var end_pos = pos;
            end_pos.forward_chars (1);

            if (new_text == buf.get_text (pos, end_pos, true)) {
                buf.delete (ref pos, ref end_pos);
                buf.place_cursor (pos);
            }
        }
    }
}

[ModuleInit]
public void peas_register_types (GLib.TypeModule module) {
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type (typeof (Peas.Activatable),
                                     typeof (Scratch.Plugins.BracketsCompletion));
}
