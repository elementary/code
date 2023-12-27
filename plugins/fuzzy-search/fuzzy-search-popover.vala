/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2023 elementary, Inc. <https://elementary.io>
 *
 * Authored by: Marvin Ahlgrimm
 *              Colin Kiama
 */

public class Scratch.FuzzySearchPopover : Gtk.Popover {
    private Gtk.SearchEntry search_term_entry;
    private Services.FuzzyFinder fuzzy_finder;
    private Gtk.ListBox search_result_container;
    private int preselected_index;
    private Gtk.ScrolledWindow scrolled;
    private Gee.HashMap<string, Services.SearchProject> project_paths;
    private Gee.ArrayList<FileItem> items;
    private int window_height;
    private int max_items;
    private Gee.LinkedList<GLib.Cancellable> cancellables;
    private bool should_distinguish_projects;
    private Gtk.EventControllerKey search_term_entry_key_controller;
    private Gtk.Label title_label;

    public signal void open_file (string filepath);
    public signal void close_search ();

    public FuzzySearchPopover (Gee.HashMap<string, Services.SearchProject> pps, Gtk.Widget? relative_to, int height) {
        Object (
            modal: true,
            relative_to: relative_to,
            constrain_to: Gtk.PopoverConstraint.WINDOW,
            width_request: 500
        );

        window_height = height;
        fuzzy_finder = new Services.FuzzyFinder (pps);
        project_paths = pps;
        items = new Gee.ArrayList<FileItem> ();
        cancellables = new Gee.LinkedList<GLib.Cancellable> ();

        should_distinguish_projects = project_paths.size > 1;

        // Limit the shown results if the window height is too small
        if (window_height > 400) {
            max_items = 5;
        } else {
            max_items = 3;
        }

        scrolled.set_max_content_height (45 /* height */ * max_items);
    }

    private void calculate_scroll_offset (int old_position, int new_position) {
        // Shortcut if jumping from first to last or the other way round
        if (new_position == 0 && old_position > new_position) {
            scrolled.vadjustment.value = 0;
            return;
        } else if (old_position == 0 && new_position == items.size - 1) {
            scrolled.vadjustment.value = scrolled.vadjustment.get_upper ();
            return;
        }

        var size_box = scrolled.vadjustment.get_upper () / items.size;
        var current_top = scrolled.vadjustment.value;
        var current_bottom = current_top + size_box * (max_items - 2);
        if (old_position < new_position) {
            // Down movement
            var new_adjust = size_box * (preselected_index);
            if (new_adjust >= current_bottom) {
                scrolled.vadjustment.value = size_box * (preselected_index - (max_items - 1));
            }
        } else if (old_position > new_position) {
            // Up movement
            var new_adjust = size_box * (preselected_index);
            if (new_adjust < current_top) {
                scrolled.vadjustment.value = new_adjust;
            }
        }
    }

    construct {
        this.get_style_context ().add_class ("fuzzy-popover");

        title_label = new Gtk.Label (_("Search for project files"));
        title_label.halign = Gtk.Align.START;
        title_label.get_style_context ().add_class ("h4");

        search_term_entry = new Gtk.SearchEntry ();
        search_term_entry.halign = Gtk.Align.FILL;
        search_term_entry.hexpand = true;

        search_result_container = new Gtk.ListBox () {
            selection_mode = Gtk.SelectionMode.NONE,
            activate_on_single_click = true
        };

        search_result_container.get_style_context ().add_class ("fuzzy-list");

        search_result_container.row_activated.connect ((row) => {
            var file_item = row as FileItem;
            if (file_item == null) {
                return;
            }

            handle_item_selection (items.index_of (file_item));
        });

        search_term_entry_key_controller = new Gtk.EventControllerKey (search_term_entry);
        search_term_entry_key_controller.key_pressed.connect ((keyval, keycode, state) => {
            // Handle key up/down to select other files found by fuzzy search
            switch (keyval) {
                case Gdk.Key.Down:
                    if (items.size > 0) {
                        var old_index = preselected_index;
                        var item = items.get (preselected_index++);
                        if (preselected_index >= items.size) {
                            preselected_index = 0;
                        }

                        var next_item = items.get (preselected_index);
                        preselect_new_item (item, next_item);
                        calculate_scroll_offset (old_index, preselected_index);
                    }

                    return true;
                case Gdk.Key.Up:
                    if (items.size > 0) {
                        var old_index = preselected_index;
                        var item = items.get (preselected_index--);
                        if (preselected_index < 0) {
                            preselected_index = items.size - 1;
                        }

                        var next_item = items.get (preselected_index);
                        preselect_new_item (item, next_item);
                        calculate_scroll_offset (old_index, preselected_index);
                    }
                    return true;
                case Gdk.Key.Escape:
                    // Handle seperately, otherwise it takes 2 escape hits to close the modal
                    close_search ();
                    return true;
                default:
                    break;
            }

            return false;
        });

        search_term_entry.activate.connect (() => {
            if (items.size > 0) {
                handle_item_selection (preselected_index);
            }
        });

        search_term_entry.changed.connect ((e) => {
            if (search_term_entry.text.length >= 1) {
                var previous_text = search_term_entry.text;
                if (cancellables.size > 0) {
                    var last_cancellable = cancellables.last ();
                    last_cancellable.cancel ();
                }

                Timeout.add (1, () => {
                        var next_cancellable = new GLib.Cancellable ();
                        cancellables.add (next_cancellable);
                        fuzzy_finder.fuzzy_find_async.begin (search_term_entry.text, next_cancellable, (obj, res) =>{
                        if (next_cancellable.is_cancelled ()) {
                            cancellables.remove (next_cancellable);
                            return;
                        }

                        var results = fuzzy_finder.fuzzy_find_async.end (res);
                        if (results == null) {
                            return;
                        }

                        bool first = true;

                        // If the entry is empty or the text has changed
                        // since searching, do nothing
                        if (previous_text.length == 0 || previous_text != search_term_entry.text) {
                            return;
                        }

                        foreach (var c in search_result_container.get_children ()) {
                            search_result_container.remove (c);
                        }

                        items.clear ();

                        foreach (var result in results) {
                            var file_item = new FileItem (result, should_distinguish_projects);

                            if (first) {
                                first = false;
                                file_item.get_style_context ().add_class ("preselect-fuzzy");
                                preselected_index = 0;
                            }

                            search_result_container.add (file_item);
                            items.add (file_item);
                        }

                        scrolled.hide ();
                        scrolled.show_all ();

                        // Reset scrolling
                        scrolled.vadjustment.value = 0;
                    });

                    return Source.REMOVE;
                });
            } else {
                foreach (var c in search_result_container.get_children ()) {
                    search_result_container.remove (c);
                }

                items.clear ();
                scrolled.hide ();
            }
        });


        var entry_layout = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        entry_layout.valign = Gtk.Align.START;

        entry_layout.add (title_label);
        entry_layout.add (search_term_entry);
        search_term_entry.valign = Gtk.Align.START;

        scrolled = new Gtk.ScrolledWindow (null, null) {
            propagate_natural_height = true,
            hexpand = true,
        };

        scrolled.add (search_result_container);

        var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        box.pack_start (entry_layout, false, false);
        box.pack_end (scrolled, true, true);
        box.show_all ();

        scrolled.hide ();
        this.add (box);
    }

    private void handle_item_selection (int index) {
        var item = items.get (index);
        open_file (item.filepath.strip ());
    }

    private void preselect_new_item (FileItem old_item, FileItem new_item) {
        var class_name = "preselect-fuzzy";
        old_item.get_style_context ().remove_class (class_name);
        new_item.get_style_context ().add_class (class_name);
    }
 }
