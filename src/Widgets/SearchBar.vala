/*
 * Copyright (C) 2011-2012 Lucas Baudin <xapantu@gmail.com>
 *               2013      Mario Guerriero <mario@elementaryos.org>
                 2014-2023 elementary, Inc. (https://elementary.io)
 *
 * This file is part of Code.
 *
 * Code is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * Code is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

public enum Scratch.CaseSensitiveMode {
    NEVER,
    MIXED,
    ALWAYS
}

namespace Scratch.Widgets {
    public class SearchBar : Gtk.Box { //TODO In Gtk4 use a BinLayout Widget

        public weak MainWindow window { get; construct; }


        private Gtk.Button tool_arrow_up;
        private Gtk.Button tool_arrow_down;

        /**
         * Is the search cyclic? e.g., when you are at the bottom, if you press
         * "Down", it will go at the start of the file to search for the content
         * of the search entry.
         **/
        private Granite.SwitchModelButton cycle_search_button ;
        private Gtk.ComboBoxText case_sensitive_search_button;
        private Granite.SwitchModelButton regex_search_button;
        private Granite.SwitchModelButton whole_word_search_button;
        private Gtk.SearchEntry search_entry;
        private Gtk.SearchEntry replace_entry;
        private Gtk.Label search_occurence_count_label;
        private Gtk.Button replace_tool_button;
        private Gtk.Button replace_all_tool_button;
        private Scratch.Widgets.SourceView? text_view = null;
        private Gtk.TextBuffer? text_buffer = null;
        private Gtk.SourceSearchContext? search_context;
        private uint update_search_label_timeout_id = 0;
        private Gtk.Revealer revealer;

        public bool is_focused {
            get {
                return search_entry.has_focus || replace_entry.has_focus;
            }
        }

        public bool is_revealed {
            get {
                return revealer.child_revealed;
            }
        }

        public string entry_text {
            get {
                return search_entry.text;
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

        public uint transition_time_msec {
            get {
                return revealer.transition_duration + 10;
            }
        }

        public SearchBar (MainWindow window) {
            Object (window: window);
        }

        construct {
            this.orientation = HORIZONTAL;
            search_entry = new Gtk.SearchEntry () {
                hexpand = true,
                placeholder_text = _("Find")
            };

            search_occurence_count_label = new Gtk.Label (_("No Results"));
            search_occurence_count_label.get_style_context ().add_class (Granite.STYLE_CLASS_SMALL_LABEL);

            var app_instance = (Scratch.Application) GLib.Application.get_default ();

            tool_arrow_down = new Gtk.Button.from_icon_name ("go-down-symbolic", Gtk.IconSize.SMALL_TOOLBAR);
            tool_arrow_down.clicked.connect (search_next);
            tool_arrow_down.sensitive = false;
            tool_arrow_down.tooltip_markup = Granite.markup_accel_tooltip (
                app_instance.get_accels_for_action (
                    Scratch.MainWindow.ACTION_PREFIX + Scratch.MainWindow.ACTION_FIND_NEXT
                ),
                _("Search next")
            );

            tool_arrow_up = new Gtk.Button.from_icon_name ("go-up-symbolic", Gtk.IconSize.SMALL_TOOLBAR);
            tool_arrow_up.clicked.connect (search_previous);
            tool_arrow_up.sensitive = false;
            tool_arrow_up.tooltip_markup = Granite.markup_accel_tooltip (
                app_instance.get_accels_for_action (
                    Scratch.MainWindow.ACTION_PREFIX + Scratch.MainWindow.ACTION_FIND_PREVIOUS
                ),
                _("Search previous")
            );

            cycle_search_button = new Granite.SwitchModelButton (_("Cyclic Search"));

            case_sensitive_search_button = new Gtk.ComboBoxText ();
            case_sensitive_search_button.append ("never", _("Never"));
            case_sensitive_search_button.append ("mixed", _("Mixed Case"));
            case_sensitive_search_button.append ("always", _("Always"));
            case_sensitive_search_button.active = 1;

            var case_sensitive_search_label = new Gtk.Label (_("Case Sensitive"));

            var case_sensitive_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
            case_sensitive_box.add (case_sensitive_search_label);
            case_sensitive_box.add (case_sensitive_search_button);
            case_sensitive_box.get_style_context ().add_class (Gtk.STYLE_CLASS_MENUITEM);

            regex_search_button = new Granite.SwitchModelButton (_("Use Regular Expressions"));
            whole_word_search_button = new Granite.SwitchModelButton (_("Match Whole Words"));

            var search_option_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) {
                margin_top = 3,
                margin_bottom = 3
            };
            search_option_box.add (cycle_search_button);
            search_option_box.add (case_sensitive_box);
            search_option_box.add (whole_word_search_button);
            search_option_box.add (regex_search_button);

            var search_popover = new Gtk.Popover (null);
            search_popover.add (search_option_box);
            search_popover.show_all ();

            var search_buttonbox = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
            search_buttonbox.add (search_occurence_count_label);
            search_buttonbox.add (new Gtk.Image.from_icon_name ("pan-down-symbolic", Gtk.IconSize.SMALL_TOOLBAR));

            var search_menubutton = new Gtk.MenuButton () {
                popover = search_popover,
                tooltip_text = _("Search Options")
            };
            search_menubutton.add (search_buttonbox);

            cycle_search_button.toggled.connect (on_search_parameters_changed);
            case_sensitive_search_button.changed.connect (on_search_parameters_changed);
            whole_word_search_button.toggled.connect (on_search_parameters_changed);
            regex_search_button.toggled.connect (on_search_parameters_changed);

            Scratch.settings.bind ("cyclic-search", cycle_search_button, "active", SettingsBindFlags.DEFAULT);
            Scratch.settings.bind ("wholeword-search", whole_word_search_button, "active", SettingsBindFlags.DEFAULT);
            Scratch.settings.bind ("case-sensitive-search", case_sensitive_search_button, "active-id", SettingsBindFlags.DEFAULT);
            Scratch.settings.bind ("regex-search", regex_search_button, "active", SettingsBindFlags.DEFAULT);
            // These settings are ignored when regex searching
            regex_search_button.bind_property ("active", cycle_search_button, "sensitive", SYNC_CREATE | INVERT_BOOLEAN);
            regex_search_button.bind_property ("active", whole_word_search_button, "sensitive", SYNC_CREATE | INVERT_BOOLEAN);
            regex_search_button.bind_property ("active", case_sensitive_search_label, "sensitive", SYNC_CREATE | INVERT_BOOLEAN);
            regex_search_button.bind_property ("active", case_sensitive_search_button, "sensitive", SYNC_CREATE | INVERT_BOOLEAN);

            var search_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) {
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

            replace_entry = new Gtk.SearchEntry ();
            replace_entry.hexpand = true;
            replace_entry.placeholder_text = _("Replace With");
            replace_entry.set_icon_from_icon_name (Gtk.EntryIconPosition.PRIMARY, "edit-symbolic");

            replace_tool_button = new Gtk.Button.with_label (_("Replace"));
            replace_tool_button.clicked.connect (on_replace_entry_activate);

            replace_all_tool_button = new Gtk.Button.with_label (_("Replace all"));
            replace_all_tool_button.clicked.connect (on_replace_all_entry_activate);

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
            search_entry.key_press_event.connect (on_search_entry_key_press);
            search_entry.focus_in_event.connect (on_search_entry_focused_in);
            search_entry.icon_release.connect ((p0, p1) => {
                if (p0 == Gtk.EntryIconPosition.PRIMARY) {
                    search_next ();
                }
            });
            replace_entry.activate.connect (on_replace_entry_activate);
            replace_entry.key_press_event.connect (on_replace_entry_key_press);

            var entry_path = new Gtk.WidgetPath ();
            entry_path.append_type (typeof (Gtk.Widget));

            var entry_context = new Gtk.StyleContext ();
            entry_context.set_path (entry_path);
            entry_context.add_class ("entry");

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
                this.text_buffer.changed.disconnect (on_text_buffer_changed);
            }

            this.text_view = text_view;
            this.text_buffer = text_view.get_buffer ();
            this.text_buffer.changed.connect (on_text_buffer_changed);
            this.search_context = new Gtk.SourceSearchContext (text_buffer as Gtk.SourceBuffer, null);
            search_context.settings.wrap_around = cycle_search_button.active;
            search_context.settings.regex_enabled = regex_search_button.active;
            search_context.settings.search_text = search_entry.text;
            on_text_buffer_changed ();
        }

        private void on_text_buffer_changed () {
            update_search_widgets ();
        }

        private void on_replace_entry_activate () {
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

        private void on_replace_all_entry_activate () {
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
                var case_mode = (CaseSensitiveMode)(case_sensitive_search_button.active);
                switch (case_mode) {
                    case CaseSensitiveMode.NEVER:
                        search_context.settings.case_sensitive = false;
                        break;
                    case CaseSensitiveMode.MIXED:
                        search_context.settings.case_sensitive = !((search_string.up () == search_string) || (search_string.down () == search_string));
                        break;
                    case CaseSensitiveMode.ALWAYS:
                        search_context.settings.case_sensitive = true;
                        break;
                    default:
                        assert_not_reached ();
                }

                search_context.settings.at_word_boundaries = whole_word_search_button.active;
                search_context.settings.regex_enabled = regex_search_button.active;
            }

            update_search_widgets ();
        }

        private bool on_search_entry_focused_in (Gdk.EventFocus event) {
            if (text_buffer == null) {
                return false;
            }

            Idle.add (() => {
                update_search_widgets ();
                search_entry.select_region (0, -1);
                return Source.REMOVE;
            });

            return Gdk.EVENT_PROPAGATE;
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

        public void highlight_none () {
            if (search_context != null) {
                search_context.highlight = false;
            }
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

        public void search_previous () {
            /* Get selection range */
            Gtk.TextIter? start_iter, end_iter;
            if (text_buffer != null) {
                text_buffer.get_selection_bounds (out start_iter, out end_iter);
                if (!search_for_iter_backward (start_iter, out end_iter) && cycle_search_button.active) {
                    text_buffer.get_end_iter (out start_iter);
                    search_for_iter_backward (start_iter, out end_iter);
                }

                update_search_widgets ();
            }
        }

        public void search_next () {
            /* Get selection range */
            Gtk.TextIter? start_iter, end_iter, end_iter_tmp;
            if (text_buffer != null) {
                text_buffer.get_selection_bounds (out start_iter, out end_iter);
                if (!search_for_iter (end_iter, out end_iter_tmp) && cycle_search_button.active) {
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

        public void reveal (bool to_reveal) {
            revealer.reveal_child = to_reveal;
            // Clear entry when searchbar is hidden
            if (is_revealed && !to_reveal) {
                set_search_entry_text ("");
            }
        }

        public void set_search_entry_text (string text) {
            search_entry.text = text;
        }

        private bool on_search_entry_key_press (Gdk.EventKey event) {
            /* We don't need to perform search if there is nothing to search... */
            if (search_entry.text == "") {
                return false;
            }

            string key = Gdk.keyval_name (event.keyval);
            if (Gdk.ModifierType.SHIFT_MASK in event.state) {
                key = "<Shift>" + key;
            }

            switch (key) {
                case "<Shift>Return":
                case "Up":
                    search_previous ();
                    return true;
                case "Return":
                case "Down":
                    search_next ();
                    return true;
                case "Tab":
                    if (search_entry.is_focus) {
                        replace_entry.grab_focus ();
                    }

                    return true;
            }

            return false;
        }

        private bool on_replace_entry_key_press (Gdk.EventKey event) {
            /* We don't need to perform search if there is nothing to search… */
            if (search_entry.text == "") {
                return false;
            }

            switch (Gdk.keyval_name (event.keyval)) {
                case "Up":
                    search_previous ();
                    return true;
                case "Down":
                    search_next ();
                    return true;
                case "Tab":
                    if (replace_entry.is_focus) {
                        search_entry.grab_focus ();
                    }

                    return true;
            }

            return false;
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
                update_search_label_timeout_id = 0;
                if (search_context == null) {
                    debug ("update occurrence with null context");
                    replace_tool_button.sensitive = false;
                    replace_all_tool_button.sensitive = false;
                    tool_arrow_up.sensitive = false;
                    tool_arrow_down.sensitive = false;
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

                replace_tool_button.sensitive = location_of_search > 0;
                replace_all_tool_button.sensitive = count_of_search > 0;

                // Update tool arrows
                if (text_buffer == null ||
                    search_entry.text == "" ||
                    count_of_search == 0) {

                    tool_arrow_up.sensitive = false;
                    tool_arrow_down.sensitive = false;
                } else {
                    if (cycle_search_button.active) {
                        tool_arrow_down.sensitive = true;
                        tool_arrow_up.sensitive =true;
                    } else {
                        Gtk.TextIter? tmp_start_iter, tmp_end_iter;

                        bool is_in_start, is_in_end;

                        text_buffer.get_start_iter (out tmp_start_iter);
                        text_buffer.get_end_iter (out tmp_end_iter);

                        text_buffer.get_selection_bounds (out start_iter, out end_iter);

                        is_in_start = start_iter.compare (tmp_start_iter) == 0;
                        is_in_end = end_iter.compare (tmp_end_iter) == 0;

                        if (!is_in_end) {
                            tool_arrow_down.sensitive = search_context.forward (
                                end_iter, out tmp_start_iter, out tmp_end_iter, null
                            );
                        } else {
                            tool_arrow_down.sensitive = false;
                        }

                        if (!is_in_start) {
                            tool_arrow_up.sensitive = search_context.backward (
                                start_iter, out tmp_start_iter, out end_iter, null
                            );
                        } else {
                            tool_arrow_up.sensitive = false;
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
}
