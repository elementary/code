/*
 * Copyright (C) 2011-2012 Lucas Baudin <xapantu@gmail.com>
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
    Gtk.ActionGroup main_actions;
    
    /* The toolitems, accessible via get_*_entry(); */
    Gtk.ToolItem tool_search_entry;
    Gtk.ToolItem tool_replace_entry;
    Gtk.ToolItem tool_go_to_label;
    Gtk.ToolItem tool_go_to_entry;
    Gtk.ToolItem tool_arrow_up;
    Gtk.ToolItem tool_arrow_down;
    Gtk.ToolButton tool_close_button;

    public Granite.Widgets.SearchBar search_entry;
    public Granite.Widgets.SearchBar replace_entry;
    public Gtk.SpinButton go_to_entry;
    public Gtk.Adjustment go_to_adj;
    

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
    
    public signal void need_hide ();

    /**
     * Create a new SearchManager object.
     *
     * @param main_actions A set of actions which contains the
     * following actions : Fetch, ShowGoTo, ShowRreplace, or null.
     **/
    public SearchManager (Gtk.ActionGroup? main_actions) {
        
        this.main_actions = main_actions;

        search_entry = new Granite.Widgets.SearchBar (_("Find"));
        replace_entry = new Granite.Widgets.SearchBar (_("Replace With"));
        go_to_adj = new Gtk.Adjustment (0, 0, 1000, 1, 40, 0);
        go_to_entry = new Gtk.SpinButton (go_to_adj, 1, 1);
        go_to_entry.digits = 0;
        search_entry.width_request = 250;
        replace_entry.width_request = 250;

        tool_search_entry = new Gtk.ToolItem ();
        tool_replace_entry = new Gtk.ToolItem ();
        tool_go_to_label = new Gtk.ToolItem ();
        tool_go_to_entry = new Gtk.ToolItem ();
        tool_close_button = new Gtk.ToolButton.from_stock ("gtk-close");

        tool_search_entry.add (search_entry);
        tool_replace_entry.add (replace_entry);
        tool_go_to_label.add (new Gtk.Label (_("Go To Line:")));
        tool_go_to_entry.add (go_to_entry);

        if(main_actions != null) {
            main_actions.get_action ("Fetch").activate.connect (show_search);
            main_actions.get_action ("ShowGoTo").activate.connect (show_go_to);
            main_actions.get_action ("ShowReplace").activate.connect (show_replace);
            main_actions.get_action ("Fetch").bind_property("sensitive", search_entry, "sensitive", BindingFlags.DEFAULT);
            main_actions.get_action ("ShowGoTo").bind_property("sensitive", replace_entry, "sensitive", BindingFlags.DEFAULT);
            main_actions.get_action ("ShowReplace").bind_property("sensitive", go_to_entry, "sensitive", BindingFlags.DEFAULT);
            
            var next = new Gtk.Button ();
            next.clicked.connect (search_next);
            next.set_relief (Gtk.ReliefStyle.NONE);
            var i = new Gtk.Image.from_icon_name ("go-down-symbolic", Gtk.IconSize.SMALL_TOOLBAR);
            i.pixel_size = 16;
            next.image = i;
            tool_arrow_up = new Gtk.ToolItem ();//(Gtk.ToolItem) main_actions.get_action ("SearchNext").create_tool_item ();
            //main_actions.get_action ("SearchNext").bind_property("sensitive", tool_arrow_up, "sensitive", BindingFlags.DEFAULT);
            tool_arrow_up.add (next);
            
            var previous = new Gtk.Button ();
            previous.clicked.connect (search_previous);
            previous.set_relief (Gtk.ReliefStyle.NONE);
            i = new Gtk.Image.from_icon_name ("go-up-symbolic", Gtk.IconSize.SMALL_TOOLBAR);
            i.pixel_size = 16;
            previous.image = i;
            tool_arrow_down = new Gtk.ToolItem ();//(Gtk.ToolItem) main_actions.get_action ("SearchBack").create_tool_item ();
            //main_actions.get_action ("SearchBack").bind_property("sensitive", tool_arrow_down, "sensitive", BindingFlags.DEFAULT);
            tool_arrow_down.add (previous);
            
            main_actions.get_action ("SearchNext").set_sensitive (false);
            main_actions.get_action ("SearchBack").set_sensitive (false);
        }

        tool_replace_entry.no_show_all = false;
        tool_go_to_entry.no_show_all = false;

        search_entry.changed.connect (on_search_entry_text_changed);
        search_entry.key_press_event.connect (on_search_entry_key_press);
        search_entry.focus_in_event.connect (on_search_entry_focused_in);
        
        tool_close_button.clicked.connect (() => { need_hide (); });

        go_to_entry.activate.connect (on_go_to_entry_activate);
        replace_entry.activate.connect (on_replace_entry_activate);

        /* Get default text color in Gtk.Entry */
        var entry_context = new Gtk.StyleContext ();
        var entry_path = new Gtk.WidgetPath ();
        entry_path.append_type (typeof (Gtk.Widget));
        entry_context.set_path (entry_path);
        entry_context.add_class ("entry");
        normal_color = entry_context.get_color (Gtk.StateFlags.FOCUSED);
        
        settings.show_replace = false;
        settings.show_go_to_line = false;
        
        Scratch.settings.changed.connect (restore_settings);
    }

    public Gtk.ToolItem get_search_entry () {
        return tool_search_entry;
    }

    public Gtk.ToolItem get_close_button () {
        return tool_close_button;
    }

    public Gtk.ToolItem get_arrow_next () {
        return tool_arrow_up;
    }

    public Gtk.ToolItem get_arrow_previous () {
        return tool_arrow_down;
    }

    public Gtk.ToolItem get_replace_entry () {
        return tool_replace_entry;
    }
    
    public Gtk.ToolItem get_go_to_label () {
        return tool_go_to_label;
    }

    public Gtk.ToolItem get_go_to_entry () {
        return tool_go_to_entry;
    }
    
    public Gtk.Adjustment get_go_to_adj () {
        return go_to_adj;
    }

    public void set_text_view (Scratch.Widgets.SourceView? new_text_view) {
        text_view = new_text_view;
        text_buffer = null;
        if (new_text_view != null)
            text_buffer = text_view.get_buffer ();
    }

    /*void show_arrow (bool show) {
        tool_arrow_down.no_show_all = tool_arrow_up.no_show_all = !show;
        if(show) {
            tool_arrow_up.show_all ();
            tool_arrow_down.show_all ();
        }
        else {
            tool_arrow_up.hide ();
            tool_arrow_down.hide ();
        }
    }*/

    void show_search () {
        /*tool_replace_entry.hide ();
        tool_go_to_entry.hide ();
        tool_search_entry.show_all ();*/

        Idle.add (() => { search_entry.grab_focus (); return false; });
    }

    void show_replace () {
        tool_replace_entry.no_show_all = false;
        /*tool_search_entry.show_all ();
        tool_go_to_entry.hide ();
        tool_replace_entry.show_all ();*/

        Idle.add (() => { replace_entry.grab_focus (); return false; });
    }
    
    void hide_replace () {
        //tool_replace_entry.no_show_all = true;
        //tool_search_entry.show_all ();
        //tool_go_to_entry.hide ();
        //tool_replace_entry.hide ();

        Idle.add (() => { search_entry.grab_focus (); return false; });
    }
    
    void show_go_to () {
        tool_go_to_entry.no_show_all = false;
        /*tool_replace_entry.hide ();
        tool_search_entry.hide ();
        tool_go_to_entry.show_all ();*/

        Idle.add (() => { go_to_entry.grab_focus (); return false; });
    }
    
    void hide_go_to () {
        //tool_go_to_entry.no_show_all = true;
        //tool_replace_entry.hide ();
        //tool_search_entry.show_all ();
        //tool_go_to_entry.hide ();

        Idle.add (() => { search_entry.grab_focus (); return false; });
    }
    
    void on_go_to_entry_activate () {
        if( text_view != null) {
            text_view.go_to_line (int.parse(go_to_entry.text));
        }
    }

    void on_replace_entry_activate () {
        if (text_buffer == null) {
            warning ("No valid buffer to replace");
            return;
        }
        if (search ()) {
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
        tool_arrow_up.set_sensitive (true);
        tool_arrow_down.set_sensitive (true);
    }

    bool on_search_entry_focused_in (Gdk.EventFocus event) {

        search_entry.select_region(0, -1);
        
        Gtk.TextIter? start_iter, end_iter;
        text_buffer.get_iter_at_offset (out start_iter, text_buffer.cursor_position);
        
        if (search_for_iter (start_iter, out end_iter, search_entry.text)) {
            search_entry.override_color (Gtk.StateFlags.FOCUSED, normal_color);
        }
        else {
            text_buffer.get_start_iter (out start_iter);
            if (search_for_iter (start_iter, out end_iter, search_entry.text)) {
                search_entry.override_color (Gtk.StateFlags.FOCUSED, normal_color);
            }
            else {
                warning ("Not found : %s", search_entry.text);
                start_iter.set_offset (-1);
                text_buffer.select_range (start_iter, start_iter);
                search_entry.override_color (Gtk.StateFlags.FOCUSED, {1.0, 0.0, 0.0, 1.0});
                return false;
            }

        }
        return false;
    }

    /*void add_section (Gtk.Grid grid, Gtk.Label name, ref int row) {
        name.use_markup = true;
        name.set_markup ("<b>%s</b>".printf (name.get_text ()));
        name.halign = Gtk.Align.START;
        grid.attach (name, 0, row, 1, 1);
        row ++;
    }
    
    void add_option (Gtk.Grid grid, Gtk.Widget label, Gtk.Widget switcher, ref int row) {
        label.hexpand = true;
        label.halign = Gtk.Align.END;
        label.margin_left = 20;
        switcher.halign = Gtk.Align.FILL;
        switcher.hexpand = true;
        
        if (switcher is Gtk.Switch || switcher is Gtk.CheckButton
            || switcher is Gtk.Entry) { /* then we don't want it to be expanded *
            switcher.halign = Gtk.Align.START;
        }
        
        grid.attach (label, 0, row, 1, 1);
        grid.attach_next_to (switcher, label, Gtk.PositionType.RIGHT, 3, 1);
        row ++;
    }*/
    

    public bool search () {
        /* So, first, let's check we can really search something. */
        string search_string = search_entry.text;

        if (search_string == "" && main_actions != null) {
            main_actions.get_action ("SearchNext").set_sensitive (false);
            main_actions.get_action ("SearchBack").set_sensitive (false);        
        }
        else if (main_actions != null) {
            main_actions.get_action ("SearchNext").set_sensitive (true);
            main_actions.get_action ("SearchBack").set_sensitive (true);
        }
        
        if (text_buffer == null || text_buffer.text == "" || search_string == "") {
            warning ("I can't search anything in an inexistant buffer and/or wuthout anything to search.");
            return false;
        }

        Gtk.TextIter? start_iter, end_iter;
        text_buffer.get_iter_at_offset (out start_iter, text_buffer.cursor_position);

        if (search_for_iter (start_iter, out end_iter, search_string)) {
            search_entry.override_color (Gtk.StateFlags.FOCUSED, normal_color);
        }
        else {
            text_buffer.get_start_iter (out start_iter);
            if (search_for_iter (start_iter, out end_iter, search_string)) {
                search_entry.override_color (Gtk.StateFlags.FOCUSED, normal_color);
            }
            else {
                warning ("Not found : %s", search_string);
                start_iter.set_offset (-1);
                text_buffer.select_range (start_iter, start_iter);
                search_entry.override_color (Gtk.StateFlags.FOCUSED, {1.0, 0.0, 0.0, 1.0});
                return false;
            }

        }
       return true;
    }

    bool search_for_iter (Gtk.TextIter? start_iter, out Gtk.TextIter? end_iter, string search_string) {
        end_iter = start_iter;
        bool case_sensitive = !((search_string.up () == search_string) || (search_string.down () == search_string));
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
        bool case_sensitive = !((search_string.up () == search_string) || (search_string.down () == search_string));
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
        if (search_entry.text == "")
            return false;
        string key = Gdk.keyval_name (event.keyval);
        //debug ("%s", key);
        switch (key)
        {
        case "Up":
            search_previous ();
            return true;
        case "Return":
        case "Down":
            search_next ();
            return true;
        case "Escape":
            text_view.grab_focus ();
            return true;
        case "Tab":
            if (search_entry.is_focus) replace_entry.grab_focus ();
            return true;
        }
        return false;
    }
    
    void restore_settings () {
        
        show_search ();
        
        if (settings.show_replace) show_replace ();
        else hide_replace ();
        
        if (settings.show_go_to_line) show_go_to ();
        else hide_go_to ();
    }
}

public class Granite.Widgets.ToolArrow : Gtk.ToolItem
{
    public signal void clicked();
    Gtk.ToggleButton button;
    public ToolArrow()
    {
        Gtk.CssProvider css = new Gtk.CssProvider();
        try {
            css.load_from_data("* { padding-left:0; padding-right:0; }", -1);
        } catch (Error e) {
            warning (e.message);
        }
        var arrow = new Gtk.Arrow(Gtk.ArrowType.DOWN, Gtk.ShadowType.OUT);
        button = new Gtk.ToggleButton();
        button.button_press_event.connect( () => { clicked(); return true; });
        button.add(arrow);
        button.get_style_context().add_provider(css, 800);
        button.set_relief(Gtk.ReliefStyle.NONE);
        add(button);
    }
    
    /*public void set_state(bool v)
    {
        button.active = v;
    }*/
}
