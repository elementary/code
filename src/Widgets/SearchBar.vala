/*
* SPDX-License-Identifier: GPL-3.0-or-later
* SPDX-FileCopyrightText:  2014-2026 elementary, Inc. (https://elementary.io)
*                          2013 Mario Guerriero <mario@elementaryos.org>
*                          2011-2012 Lucas Baudin <xapantu@gmail.com>
*/

public enum Scratch.CaseSensitiveMode {
    NEVER,
    MIXED,
    ALWAYS
}

public class Scratch.Widgets.SearchBar : Gtk.Box { //TODO In Gtk4 use a BinLayout Widget
    public weak MainWindow window { get; construct; }

    public bool is_focused {
        get {
            return search_entry.has_focus || replace_entry.has_focus;
        }
    }

    public bool search_mode_enabled {
        get {
            return revealer.child_revealed;
        }
        set {
            revealer.reveal_child = value;
            // Clear entry when searchbar is hidden
            if (!value) {
                search_entry.text = "";
            }
        }
    }

    public string search_text {
        get {
            return search_entry.text;
        }
        set {
            search_entry.text = value;
        }
    }

    public uint search_occurrences {
        get {
             if (search_context == null ||
                 search_context.settings.search_text == "") {

                return 0;
            } else {
                return search_context.get_occurrences_count ();
            }
        }
    }

    public const string ACTION_GROUP = "find";
    public const string ACTION_PREFIX = ACTION_GROUP + ".";
    public const string ACTION_FIND_NEXT = "action-find-next";
    public const string ACTION_FIND_PREVIOUS = "action-find-previous";
    private const string ACTION_REPLACE = "replace";
    private const string ACTION_REPLACE_ALL = "replace-all";

    /**
     * Is the search cyclic? e.g., when you are at the bottom, if you press
     * "Down", it will go at the start of the file to search for the content
     * of the search entry.
     **/
    private Gtk.SearchEntry search_entry;
    private Gtk.SearchEntry replace_entry;
    private Gtk.Label search_occurence_count_label;
    private Scratch.Widgets.SourceView? text_view = null;
    private Gtk.TextBuffer? text_buffer = null;
    private Gtk.SourceSearchContext? search_context;
    private uint update_search_label_timeout_id = 0;
    private Gtk.Revealer revealer;

    private SimpleAction find_next_action;
    private SimpleAction find_previous_action;
    private SimpleAction replace_action;
    private SimpleAction replace_all_action;

    public SearchBar (MainWindow window) {
        Object (window: window);
    }

    construct {
        find_next_action = new SimpleAction (ACTION_FIND_NEXT, null);
        find_next_action.activate.connect (action_find_next);

        find_previous_action = new SimpleAction (ACTION_FIND_PREVIOUS, null);
        find_previous_action.activate.connect (action_find_previous);

        replace_action = new SimpleAction (ACTION_REPLACE, null);
        replace_action.activate.connect (action_replace);

        replace_all_action = new SimpleAction (ACTION_REPLACE_ALL, null);
        replace_all_action.activate.connect (action_replace_all);

        var action_group = new SimpleActionGroup ();
        action_group.add_action (find_next_action);
        action_group.add_action (find_previous_action);
        action_group.add_action (replace_action);
        action_group.add_action (replace_all_action);

        insert_action_group (ACTION_GROUP, action_group);

        var app_instance = (Scratch.Application) GLib.Application.get_default ();
        app_instance.set_accels_for_action (ACTION_PREFIX + ACTION_FIND_NEXT, {"Return", "Down"});
        app_instance.set_accels_for_action (ACTION_PREFIX + ACTION_FIND_PREVIOUS, {"<Shift>Return", "Up"});

        this.orientation = HORIZONTAL;
        search_entry = new Gtk.SearchEntry () {
            hexpand = true,
            placeholder_text = _("Find")
        };

        search_occurence_count_label = new Gtk.Label (_("No Results"));
        search_occurence_count_label.get_style_context ().add_class (Granite.STYLE_CLASS_SMALL_LABEL);

        var tool_arrow_down = new Gtk.Button.from_icon_name ("go-down-symbolic", SMALL_TOOLBAR) {
            action_name = ACTION_PREFIX + ACTION_FIND_NEXT,
            tooltip_markup = Granite.markup_accel_tooltip (
                {"<Control>g"},
                _("Search next")
            )
        };

        var tool_arrow_up = new Gtk.Button.from_icon_name ("go-up-symbolic", SMALL_TOOLBAR) {
            action_name = ACTION_PREFIX + ACTION_FIND_PREVIOUS,
            tooltip_markup = Granite.markup_accel_tooltip (
                {"<Control><shift>g"},
                _("Search previous")
            )
        };

        var cycle_search_button = new Granite.SwitchModelButton (_("Cyclic Search"));

        var case_sensitive_search_button = new Gtk.ComboBoxText ();
        case_sensitive_search_button.append ("never", _("Never"));
        case_sensitive_search_button.append ("mixed", _("Mixed Case"));
        case_sensitive_search_button.append ("always", _("Always"));
        case_sensitive_search_button.active = 1;

        var case_sensitive_search_label = new Gtk.Label (_("Case Sensitive"));

        var case_sensitive_box = new Gtk.Box (HORIZONTAL, 12);
        case_sensitive_box.add (case_sensitive_search_label);
        case_sensitive_box.add (case_sensitive_search_button);
        case_sensitive_box.get_style_context ().add_class (Gtk.STYLE_CLASS_MENUITEM);

        var regex_search_button = new Granite.SwitchModelButton (_("Use Regular Expressions"));
        var whole_word_search_button = new Granite.SwitchModelButton (_("Match Whole Words"));

        var search_option_box = new Gtk.Box (VERTICAL, 0) {
            margin_top = 3,
            margin_bottom = 3
        };
        search_option_box.add (cycle_search_button);
        search_option_box.add (case_sensitive_box);
        search_option_box.add (whole_word_search_button);
        search_option_box.add (regex_search_button);

        var search_popover = new Gtk.Popover (null) {
            child = search_option_box
        };
        search_popover.show_all ();

        var search_buttonbox = new Gtk.Box (HORIZONTAL, 6);
        search_buttonbox.add (search_occurence_count_label);
        search_buttonbox.add (new Gtk.Image.from_icon_name ("pan-down-symbolic", SMALL_TOOLBAR));

        var search_menubutton = new Gtk.MenuButton () {
            popover = search_popover,
            tooltip_text = _("Search Options")
        };
        search_menubutton.add (search_buttonbox);

        settings.changed["case-sensitive-search"].connect (on_search_parameters_changed);
        settings.changed["cyclic-search"].connect (on_search_parameters_changed);
        settings.changed["regex-search"].connect (on_search_parameters_changed);
        settings.changed["wholeword-search"].connect (on_search_parameters_changed);

        // Bind some application settings
        settings.bind ("cyclic-search", cycle_search_button, "active", DEFAULT);
        settings.bind ("wholeword-search", whole_word_search_button, "active", DEFAULT);
        settings.bind ("case-sensitive-search", case_sensitive_search_button, "active-id", DEFAULT);
        settings.bind ("regex-search", regex_search_button, "active", DEFAULT);

        // These settings are ignored when regex searching
        settings.bind ("regex-search", cycle_search_button, "sensitive", INVERT_BOOLEAN);
        settings.bind ("regex-search", whole_word_search_button, "sensitive", INVERT_BOOLEAN);
        settings.bind ("regex-search", case_sensitive_search_button, "sensitive", INVERT_BOOLEAN);
        settings.bind ("regex-search", case_sensitive_search_label, "sensitive", INVERT_BOOLEAN);

        var search_box = new Gtk.Box (HORIZONTAL, 0) {
            margin_top = 3,
            margin_end = 3,
            margin_bottom = 3,
            margin_start = 6
        };
        search_box.get_style_context ().add_class (Gtk.STYLE_CLASS_LINKED);
        search_box.add (search_entry);
        search_box.add (tool_arrow_down);
        search_box.add (tool_arrow_up);
        search_box.add (search_menubutton);

        var search_flow_box_child = new Gtk.FlowBoxChild ();
        search_flow_box_child.can_focus = false;
        search_flow_box_child.add (search_box);

        replace_entry = new Gtk.SearchEntry () {
            hexpand = true,
            placeholder_text = _("Replace With"),
            primary_icon_name = "edit-symbolic"
        };

        var replace_tool_button = new Gtk.Button.with_label (_("Replace")) {
            action_name = ACTION_PREFIX + ACTION_REPLACE
        };

        var replace_all_tool_button = new Gtk.Button.with_label (_("Replace all")) {
            action_name = ACTION_PREFIX + ACTION_REPLACE_ALL
        };

        var replace_grid = new Gtk.Grid () {
            margin_top = 3,
            margin_end = 6,
            margin_bottom = 3,
            margin_start = 3
        };
        replace_grid.get_style_context ().add_class (Gtk.STYLE_CLASS_LINKED);
        replace_grid.add (replace_entry);
        replace_grid.add (replace_tool_button);
        replace_grid.add (replace_all_tool_button);

        var replace_flow_box_child = new Gtk.FlowBoxChild ();
        replace_flow_box_child.can_focus = false;
        replace_flow_box_child.add (replace_grid);

        // Connecting to some signals
        search_entry.changed.connect (on_search_parameters_changed);
        search_entry.notify["is-focus"].connect (() => {
            if (search_entry.is_focus && text_buffer != null) {
                Idle.add (() => {
                    update_search_widgets ();
                    search_entry.select_region (0, -1);
                    return Source.REMOVE;
                });
            }
        });
        search_entry.icon_release.connect ((p0, p1) => {
            if (p0 == Gtk.EntryIconPosition.PRIMARY) {
                action_find_next ();
            }
        });
        replace_entry.activate.connect (action_replace);

        var flowbox = new Gtk.FlowBox () {
            selection_mode = Gtk.SelectionMode.NONE,
            column_spacing = 6,
            max_children_per_line = 2
        };
        flowbox.get_style_context ().add_class ("search-bar");
        flowbox.add (search_flow_box_child);
        flowbox.add (replace_flow_box_child);

        revealer = new Gtk.Revealer () {
            child = flowbox,
            reveal_child = false
        };

        add (revealer);
        update_search_widgets ();
    }

    public void set_text_view (Scratch.Widgets.SourceView? text_view) {
        if (this.text_view == text_view) {
            // Do not needlessly recreate SearchContext - may interfere with ongoing search
            return;
        }

        cancel_update_search_widgets ();
        this.text_view = text_view;
        if (text_view == null) {
            warning ("No SourceView is associated with SearchManager!");
            search_context = null;
            return;
        } else if (this.text_buffer != null) {
            this.text_buffer.changed.disconnect (update_search_widgets);
        }

        this.text_view = text_view;
        this.text_buffer = text_view.get_buffer ();
        this.text_buffer.changed.connect (update_search_widgets);
        this.search_context = new Gtk.SourceSearchContext (text_buffer as Gtk.SourceBuffer, null);
        search_context.settings.wrap_around = settings.get_boolean ("cyclic-search");
        search_context.settings.regex_enabled = settings.get_boolean ("regex-search");
        search_context.settings.search_text = search_entry.text;
        update_search_widgets ();
    }

    public bool search () {
        search_entry.grab_focus ();
        if (search_context == null) {
            return false;
        }

        search_context.highlight = false;

        if (!has_matches ()) {
            debug ("Can't search anything in a non-existent buffer and/or without anything to search.");
            return false;
        }

        search_context.highlight = true;

        Gtk.TextIter? start_iter, end_iter;
        text_buffer.get_iter_at_offset (out start_iter, text_buffer.cursor_position);

        if (search_for_iter (start_iter, out end_iter)) {
            search_entry.get_style_context ().remove_class (Gtk.STYLE_CLASS_ERROR);
            search_entry.primary_icon_name = "edit-find-symbolic";
        } else {
            text_buffer.get_start_iter (out start_iter);
            if (search_for_iter (start_iter, out end_iter)) {
                search_entry.get_style_context ().remove_class (Gtk.STYLE_CLASS_ERROR);
                search_entry.primary_icon_name = "edit-find-symbolic";
            } else {
                debug ("Not found: \"%s\"", search_entry.text);
                start_iter.set_offset (-1);
                text_buffer.select_range (start_iter, start_iter);
                search_entry.get_style_context ().add_class (Gtk.STYLE_CLASS_ERROR);
                search_entry.primary_icon_name = "dialog-error-symbolic";
                return false;
            }
        }

        return true;
    }

    public void action_find_previous () {
        /* Get selection range */
        Gtk.TextIter? start_iter, end_iter;
        if (text_buffer != null) {
            text_buffer.get_selection_bounds (out start_iter, out end_iter);
            if (!search_for_iter_backward (start_iter, out end_iter) && settings.get_boolean ("cyclic-search")) {
                text_buffer.get_end_iter (out start_iter);
                search_for_iter_backward (start_iter, out end_iter);
            }

            update_search_widgets ();
        }
    }

    public void action_find_next () {
        /* Get selection range */
        Gtk.TextIter? start_iter, end_iter, end_iter_tmp;
        if (text_buffer != null) {
            text_buffer.get_selection_bounds (out start_iter, out end_iter);
            if (!search_for_iter (end_iter, out end_iter_tmp) && settings.get_boolean ("cyclic-search")) {
                text_buffer.get_start_iter (out start_iter);
                search_for_iter (start_iter, out end_iter);
            }

            update_search_widgets ();
        }
    }

    public void focus_search_entry () {
        search_entry.grab_focus ();
    }

    public void focus_replace_entry () {
        replace_entry.grab_focus ();
    }

    private void action_replace () {
        if (text_buffer == null) {
            warning ("No valid buffer to replace");
            return;
        }

        Gtk.TextIter? start_iter, end_iter;
        text_buffer.get_iter_at_offset (out start_iter, text_buffer.cursor_position);

        if (search_for_iter (start_iter, out end_iter)) {
            string replace_string = replace_entry.text;
            try {
                cancel_update_search_widgets ();
                search_context.replace (start_iter, end_iter, replace_string, replace_string.length);
                update_search_widgets ();
                debug ("Replaced \"%s\" with \"%s\"", search_entry.text, replace_entry.text);
            } catch (Error e) {
                critical (e.message);
            }
        }
    }

    private void action_replace_all () {
        if (text_buffer == null || this.window.get_current_document () == null) {
            debug ("No valid buffer to replace");
            return;
        }

        string replace_string = replace_entry.text;
        this.window.get_current_document ().toggle_changed_handlers (false);
        try {
            cancel_update_search_widgets ();
            search_context.replace_all (replace_string, replace_string.length);
            update_search_widgets ();
        } catch (Error e) {
            critical (e.message);
        }

        this.window.get_current_document ().toggle_changed_handlers (true);
    }

    // Called when one of the settings buttons or the search term changes
    private void on_search_parameters_changed () {
        if (search_context != null) {
            var search_string = search_entry.text;
            search_context.settings.search_text = search_string;
            var case_mode = settings.get_enum ("case-sensitive-search");
            switch (case_mode) {
                case CaseSensitiveMode.NEVER:
                    search_context.settings.case_sensitive = false;
                    break;
                case CaseSensitiveMode.MIXED:
                    var found = ((search_string.up () == search_string) ||
                                (search_string.down () == search_string)
                    );
                    search_context.settings.case_sensitive = !found;
                    break;
                case CaseSensitiveMode.ALWAYS:
                    search_context.settings.case_sensitive = true;
                    break;
                default:
                    assert_not_reached ();
            }

            search_context.settings.at_word_boundaries = settings.get_boolean ("wholeword-search");
            search_context.settings.regex_enabled = settings.get_boolean ("regex-search");
        }

        update_search_widgets ();
    }

    private bool has_matches () {
        if (text_buffer == null || search_entry.text == "") {
            return false;
        }

        bool has_wrapped_around;
        Gtk.TextIter? start_iter, end_iter;
        text_buffer.get_start_iter (out start_iter);
        return search_context.forward (start_iter, out start_iter, out end_iter, out has_wrapped_around);
    }

    private bool search_for_iter (Gtk.TextIter? start_iter, out Gtk.TextIter? end_iter) {
        end_iter = start_iter;

        if (search_context == null) {
            critical ("Trying to search forwards with no search context");
            return false;
        }

        bool has_wrapped_around;
        bool found = search_context.forward (start_iter, out start_iter, out end_iter, out has_wrapped_around);
        if (found) {
            text_buffer.select_range (start_iter, end_iter);
            if (has_wrapped_around) {
                start_iter.backward_lines (3);
            } else {
                start_iter.forward_lines (3);
            }
            text_view.scroll_to_iter (start_iter, 0, false, 0, 0);
        }

        return found;
    }

    private bool search_for_iter_backward (Gtk.TextIter? start_iter, out Gtk.TextIter? end_iter) {
        end_iter = start_iter;

        if (search_context == null) {
            critical ("Trying to search backwards with no search context");
            return false;
        }

        bool has_wrapped_around;
        bool found = search_context.backward (start_iter, out start_iter, out end_iter, out has_wrapped_around);
        if (found) {
            text_buffer.select_range (start_iter, end_iter);
            if (has_wrapped_around) {
                start_iter.forward_lines (3);
            } else {
                start_iter.backward_lines (3);
            }
            text_view.scroll_to_iter (start_iter, 0, false, 0, 0);
        }
        return found;
    }

    private void cancel_update_search_widgets () {
        if (update_search_label_timeout_id > 0) {
            Source.remove (update_search_label_timeout_id);
            update_search_label_timeout_id = 0;
        }
    }

    // Update search occurrence label, tool arrows and replace buttons in sync
    private void update_search_widgets () {
        cancel_update_search_widgets ();
        update_search_label_timeout_id = Timeout.add (100, () => {
            var is_current_doc = window.get_current_document () != null;
            find_next_action.set_enabled (is_current_doc);
            find_previous_action.set_enabled (is_current_doc);

            update_search_label_timeout_id = 0;
            if (search_context == null) {
                debug ("update occurrence with null context");
                replace_action.set_enabled (false);
                replace_all_action.set_enabled (false);
                find_next_action.set_enabled (false);
                find_previous_action.set_enabled (false);
                return Source.REMOVE;
            }

            Gtk.TextIter? iter, start_iter, end_iter;
            text_buffer.get_iter_at_offset (out iter, text_buffer.cursor_position);

            int count_of_search = search_context.get_occurrences_count ();

            int location_of_search = 0;
            bool found = search_context.forward (iter, out start_iter, out end_iter, null);
            if (count_of_search > 0 && found) {
                location_of_search = search_context.get_occurrence_position (start_iter, end_iter);
            }

            if (count_of_search > -1) {
                if (count_of_search > 0) {
                    search_occurence_count_label.label = _("%d of %d").printf (
                        location_of_search,
                        count_of_search
                    );
                } else {
                    search_occurence_count_label.label = _("no results");
                }
            }

            replace_action.set_enabled (location_of_search > 0);
            replace_all_action.set_enabled (count_of_search > 0);

            // Update tool arrows
            if (text_buffer == null ||
                search_entry.text == "" ||
                count_of_search == 0) {

                find_previous_action.set_enabled (false);
                find_next_action.set_enabled (false);
            } else {
                if (settings.get_boolean ("cyclic-search")) {
                    find_next_action.set_enabled (true);
                    find_previous_action.set_enabled (true);
                } else {
                    Gtk.TextIter? tmp_start_iter, tmp_end_iter;

                    bool is_in_start, is_in_end;

                    text_buffer.get_start_iter (out tmp_start_iter);
                    text_buffer.get_end_iter (out tmp_end_iter);

                    text_buffer.get_selection_bounds (out start_iter, out end_iter);

                    is_in_start = start_iter.compare (tmp_start_iter) == 0;
                    is_in_end = end_iter.compare (tmp_end_iter) == 0;

                    if (!is_in_end) {
                        find_next_action.set_enabled (search_context.forward (
                            end_iter, out tmp_start_iter, out tmp_end_iter, null
                        ));
                    } else {
                        find_next_action.set_enabled (false);
                    }

                    if (!is_in_start) {
                        find_previous_action.set_enabled (search_context.backward (
                            start_iter, out tmp_start_iter, out end_iter, null
                        ));
                    } else {
                        find_next_action.set_enabled (false);
                    }
                }
            }

            // Update appearance of search entry
            var ctx = search_entry.get_style_context ();

            if (search_entry.text != "" && count_of_search == 0) {
                ctx.add_class (Gtk.STYLE_CLASS_ERROR);
                search_entry.primary_icon_name = "dialog-error-symbolic";
            } else if (ctx.has_class (Gtk.STYLE_CLASS_ERROR)) {
                ctx.remove_class (Gtk.STYLE_CLASS_ERROR);
                search_entry.primary_icon_name = "edit-find-symbolic";
            }

            return Source.REMOVE;
        });

    }
}
