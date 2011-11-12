/*
 * Copyright (C) 2011 Lucas Baudin <xapantu@gmail.com>
 *
 * This file is part of Scratch.
 *
 * Scratch is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 * 
 * Scratch is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See the GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License along
 * with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

public class Scratch.Services.SearchManager : GLib.Object {
    /* The toolitems, accessible via get_*_entry(); */
    Gtk.ToolItem tool_search_entry;
    Gtk.ToolItem tool_replace_entry;
    Gtk.ToolItem tool_go_to_entry;
    
    Granite.Widgets.SearchBar search_entry;
    Granite.Widgets.SearchBar replace_entry;
    Granite.Widgets.SearchBar go_to_entry;
    
    Scratch.Widgets.SourceView? text_view = null;
    Gtk.TextBuffer? text_buffer = null;
    
    /* The normal color for GtkEntry, used when we put the text in red
     * (when something is not found), and/or we want to re-put the normal
     * color
     */
    Gdk.RGBA normal_color;
    
    /**
     * Is the search cyclic? e.g., when you are at the bottom, if you press
     * "Down", it will go at the start of the file to search for the content
     * of the search entry.
     **/
    public bool cycle_search {get; set; default = false; }
    
    /**
     * Wether the search is or isn't case sensitive.
     **/
    public bool case_sensitive {get; set; default = false; }
    
    /**
     * Create a new SearchManager object.
     *
     * @param main_actions A set of actions which contains the
     * following actions : Fetch, ShowGoTo, ShowRreplace, or null.
     **/
    public SearchManager (Gtk.ActionGroup? main_actions) {
	    search_entry = new Granite.Widgets.SearchBar (_("Search..."));
	    replace_entry = new Granite.Widgets.SearchBar (_("Replace..."));
	    go_to_entry = new Granite.Widgets.SearchBar (_("Go to line..."));
	    search_entry.width_request = 250;
	    replace_entry.width_request = 250;
	    go_to_entry.width_request = 250;
	
	    tool_search_entry = new Gtk.ToolItem ();
	    tool_replace_entry = new Gtk.ToolItem ();
	    tool_go_to_entry = new Gtk.ToolItem ();
	
	    tool_search_entry.add (search_entry);
	    tool_replace_entry.add (replace_entry);
	    tool_go_to_entry.add (go_to_entry);
	
	    if(main_actions != null) {
	        main_actions.get_action ("Fetch").activate.connect (show_search);
	        main_actions.get_action ("ShowGoTo").activate.connect (show_go_to);
	        main_actions.get_action ("ShowReplace").activate.connect (show_replace);
	        main_actions.get_action ("Fetch").bind_property("sensitive", search_entry, "sensitive", BindingFlags.DEFAULT);
	        main_actions.get_action ("ShowGoTo").bind_property("sensitive", replace_entry, "sensitive", BindingFlags.DEFAULT);
	        main_actions.get_action ("ShowReplace").bind_property("sensitive", go_to_entry, "sensitive", BindingFlags.DEFAULT);
	    }
	
	    tool_replace_entry.no_show_all = true;
	    tool_go_to_entry.no_show_all = true;
	
	    search_entry.changed.connect (on_search_entry_text_changed);
	    search_entry.key_press_event.connect (on_search_entry_key_press);
	
	    go_to_entry.activate.connect (on_go_to_entry_activate);
	    replace_entry.activate.connect (on_replace_entry_activate);
	
	
	    /* Get default text color in Gtk.Entry */
	    var entry_context = new Gtk.StyleContext ();
	    var entry_path = new Gtk.WidgetPath ();
	    entry_path.append_type(typeof(Gtk.Widget));
	    entry_context.set_path (entry_path);
	    entry_context.add_class ("entry");
	    normal_color = entry_context.get_color(Gtk.StateFlags.FOCUSED);
    }
    
    public Gtk.ToolItem get_search_entry () {
	    return tool_search_entry;
    }
    
    public Gtk.ToolItem get_replace_entry () {
	    return tool_replace_entry;
    }
    
    public Gtk.ToolItem get_go_to_entry () {
	    return tool_go_to_entry;
    }
    
    public void set_text_view (Scratch.Widgets.SourceView? new_text_view) {
	    text_view = new_text_view;
	    text_buffer = null;
	    if(new_text_view != null)
	        text_buffer = text_view.get_buffer ();
    }
    
    void show_search () {
	    tool_replace_entry.hide ();
	    tool_go_to_entry.hide ();
	    tool_search_entry.show_all ();

	    Idle.add (() => { search_entry.grab_focus (); return false; });
    }
    
    void show_replace () {
	    tool_replace_entry.no_show_all = false;
	    tool_search_entry.show_all ();
	    tool_go_to_entry.hide ();
	    tool_replace_entry.show_all ();

	    Idle.add (() => { replace_entry.grab_focus (); return false; });
    }
    
    void show_go_to () {
	    tool_go_to_entry.no_show_all = false;
	    tool_replace_entry.hide ();
	    tool_search_entry.hide ();
	    tool_go_to_entry.show_all ();
	
	    Idle.add (() => { go_to_entry.grab_focus (); return false; });
    }
    
    void on_go_to_entry_activate () {
	    if(text_view != null) {
	        text_view.go_to_line (int.parse(go_to_entry.text));
	    }
    }
    
    void on_replace_entry_activate () {
	    if(text_buffer == null) {
	        warning ("No valid buffer to replace");
	        return;
	    }
	    if(search ()) {
	        string replace_string = replace_entry.text;
	        text_buffer.delete_selection (true, true);
	        text_buffer.insert_at_cursor (replace_string, replace_string.length);
	        search ();
	    }
    }
    
    public void set_search_string (string to_search) {
        search_entry.text = to_search;
    }

    void on_search_entry_text_changed () {
	    search ();
    }

    public bool search () {
	    /* So, first, let's check we can really search something. */
	    string search_string = search_entry.text;
	    if(text_buffer == null || text_buffer.text == "" || search_string == "") {
	        warning ("I can't search anything in an inexistant buffer and/or wuthout anything to search.");
	        return false;
	    }

	    Gtk.TextIter? start_iter, end_iter;
	    text_buffer.get_iter_at_offset(out start_iter, text_buffer.cursor_position);

	    if (search_for_iter(start_iter, out end_iter, search_string)) {
	        search_entry.override_color(Gtk.StateFlags.FOCUSED, normal_color);
	    }
	    else {
	        text_buffer.get_start_iter (out start_iter);
	        if (search_for_iter(start_iter, out end_iter, search_string)) {
	            search_entry.override_color(Gtk.StateFlags.FOCUSED, normal_color);
	        }
	        else {
	            warning ("Not found : %s", search_string);
	            search_entry.override_color(Gtk.StateFlags.FOCUSED, {1.0, 0.0, 0.0, 1.0});
	            return false;
	        }
        }
       return true;
    }
        
    bool search_for_iter (Gtk.TextIter? start_iter, out Gtk.TextIter? end_iter, string search_string) {
	    end_iter = start_iter;
	    bool found = start_iter.forward_search (search_string,
	                                            case_sensitive ? 0 : Gtk.TextSearchFlags.CASE_INSENSITIVE,
	                                            out start_iter, out end_iter, null);
	    if (found) {
	        text_buffer.select_range (start_iter, end_iter);
	        text_view.scroll_to_iter (start_iter, 0, false, 0, 0);
	        return true;
	    }
	    else {
	        return false;
	    }
    }
        
    bool search_for_iter_backward (Gtk.TextIter? start_iter, out Gtk.TextIter? end_iter, string search_string) {
	    end_iter = start_iter;
	    bool found = start_iter.backward_search (search_string,
	                                            case_sensitive ? 0 : Gtk.TextSearchFlags.CASE_INSENSITIVE,
	                                             out start_iter, out end_iter, null);
	    if (found) {
	        text_buffer.select_range (start_iter, end_iter);
	        text_view.scroll_to_iter (start_iter, 0, false, 0, 0);
	        return true;
	    }
	    else {
	        return false;
	    }
    }
    
    public void search_previous () {
	    /* Get selection range */
	    Gtk.TextIter? start_iter, end_iter;
	    if(text_buffer != null) {
	        string search_string = search_entry.text;
	        text_buffer.get_selection_bounds (out start_iter, out end_iter);
	        if(!search_for_iter_backward (start_iter, out end_iter, search_string) && cycle_search) {
	            text_buffer.get_end_iter (out start_iter);
	            search_for_iter_backward (start_iter, out end_iter, search_string);
	        }
	        
	    }
    }
    
    public void search_next () {
	    /* Get selection range */
	    Gtk.TextIter? start_iter, end_iter, end_iter_tmp;
	    if(text_buffer != null) {
	        string search_string = search_entry.text;
	        text_buffer.get_selection_bounds (out start_iter, out end_iter);
	        if(!search_for_iter (end_iter, out end_iter_tmp, search_string) && cycle_search) {
	            text_buffer.get_start_iter (out start_iter);
	            search_for_iter (start_iter, out end_iter, search_string);
	        }
	    }
    }
    
    bool on_search_entry_key_press (Gdk.EventKey event) {
	    /* We don't need to perform search if there is nothing to search... */
	    if(search_entry.text == "")
	        return false;
	    string key = Gdk.keyval_name(event.keyval);
	    switch(key)
	    {
	    case "Up":
	        search_previous ();
	        return true;
	    case "Return":
	    case "Down":
	        search_next ();
		    return true;
	    }
	    return false;
    }
}
