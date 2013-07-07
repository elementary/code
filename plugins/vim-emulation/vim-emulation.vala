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

public const string NAME = N_("Vim Emulation");
public const string DESCRIPTION = N_("Use Vim commands in Scratch");

public class Scratch.Plugins.VimEmulation : Peas.ExtensionBase,  Peas.Activatable {
    
    public enum Mode {
        COMMAND,
        INSERT,
        VISUAL
    }
	
    Mode mode = Mode.INSERT;
    string number = "";
    bool g = false;
    
    GLib.List<Scratch.Widgets.SourceView> views = new GLib.List<Scratch.Widgets.SourceView> (); 
    Scratch.Widgets.SourceView? view = null;
    
    Scratch.Services.Interface plugins;
    public Object object { owned get; construct; }
   
    public void update_state () {
    }

    public void activate () {
        plugins = (Scratch.Services.Interface) object;
        plugins.hook_document.connect ((doc) => {
            this.view = doc.source_view;
            this.view.key_press_event.disconnect (handle_key_press);
            this.view.key_press_event.connect (handle_key_press);
            this.views.append (view);
        });
    }

    public void deactivate () {
        this.views.foreach ((v) => {
            v.key_press_event.disconnect (handle_key_press);
        });
    }
    
    private bool handle_key_press (Gdk.EventKey event) {
        //some extensions to the default navigating
		bool ctrl = (event.state & Gdk.ModifierType.CONTROL_MASK) != 0;
		bool shift = (event.state & Gdk.ModifierType.SHIFT_MASK) != 0;
		
		if (ctrl && event.keyval == Gdk.Key.Up) {
			move_paragraph (true, shift);
			return true;
		}
		if (ctrl && event.keyval == Gdk.Key.Down) {
			move_paragraph (false, shift);
			return true;
		}
	
		int old_len = number.length;
		
		// Firstly let's set the mode
		switch (event.keyval) {
			//mode changing
			case Gdk.Key.i:
			    if (mode == Mode.INSERT)
			        return false;
				mode = Mode.INSERT;
				debug ("Vim Emulation: INSERT Mode!");
				return true;
			case Gdk.Key.Escape:
				mode = Mode.COMMAND;
				debug ("Vim Emulation: COMMAND Mode!");
				break;
		}
		
		if (mode == Mode.INSERT)
			return false;
		
		// Parse commands
		switch (event.keyval) {
		    //numbers
			case Gdk.Key.@1:
				number += "1";
				break;
			case Gdk.Key.@2:
				number += "2";
				break;
			case Gdk.Key.@3:
				number += "3";
				break;
			case Gdk.Key.@4:
				number += "4";
				break;
			case Gdk.Key.@5:
				number += "5";
				break;
			case Gdk.Key.@6:
				number += "6";
				break;
			case Gdk.Key.@7:
				number += "7";
				break;
			case Gdk.Key.@8:
				number += "8";
				break;
			case Gdk.Key.@9:
				number += "9";
				break;
			//case 0, see below
			
			//navigation
			case Gdk.Key.Left:
			case Gdk.Key.h:
				view.move_cursor (Gtk.MovementStep.VISUAL_POSITIONS, -1, false);
				break;
			case Gdk.Key.Down:
			case Gdk.Key.j:
				view.move_cursor (Gtk.MovementStep.DISPLAY_LINES, 1, false);
				break;
			case Gdk.Key.Up:
			case Gdk.Key.k:
				view.move_cursor (Gtk.MovementStep.DISPLAY_LINES, -1, false);
				break;
			case Gdk.Key.Right:
			case Gdk.Key.l:
				view.move_cursor (Gtk.MovementStep.VISUAL_POSITIONS, 1, false);
				break;
			case Gdk.Key.End:
			case Gdk.Key.dollar:
				view.move_cursor (Gtk.MovementStep.DISPLAY_LINE_ENDS, 1, false);
				break;
			case Gdk.Key.Home:
			case Gdk.Key.@0:
				if (number == "")
					view.move_cursor (Gtk.MovementStep.DISPLAY_LINES, 1, false);
				else
					number += "0";
				break;
			case Gdk.Key.e:
				view.move_cursor (Gtk.MovementStep.WORDS, number == "" ? 1 : int.parse (number), false);
				break;
			case Gdk.Key.g:
				g = true;
				view.go_to_line (int.parse (number));
				break;
		}

		//if there weren't any numbers added, we probably used it, so we reset it
		if (old_len == number.length)
			number = "";

		return true;
    }
    
    private void move_paragraph (bool up, bool select) 	{
		var buffer = view.buffer;
		
		Gtk.TextIter iter, start, end;
		buffer.get_iter_at_offset (out iter, buffer.cursor_position);
		
		var search = "\n\n";
		
		bool success = false;
		if (up)
			success = iter.backward_search (search, 0, out start, out end, null);
		else
			success = iter.forward_search (search, 0, out start, out end, null);
		
		if (!success) {
			if (up)
				buffer.get_start_iter (out start);
			else
				buffer.get_end_iter (out start);
		} else
			start.forward_char ();
		
		if (select) {
				buffer.select_range (start, iter);
		} else
			buffer.place_cursor (start);
		
		view.scroll_to_iter (start, 0, false, 0, 0);
	}
    
}

[ModuleInit]
public void peas_register_types (GLib.TypeModule module) {
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type (typeof (Peas.Activatable),
                                     typeof (Scratch.Plugins.VimEmulation));
}
