/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2023 elementary, Inc. <https://elementary.io>
 *
 * Authored by: Marvin Ahlgrimm
 *              Colin Kiama <colinkiama@gmail.com>
 */

public class Scratch.FuzzySearchPopover : Gtk.Popover {
    private Gtk.SearchEntry search_term_entry;
    private Services.FuzzyFinder fuzzy_finder;
    private Gtk.ListBox search_result_container;
    private int preselected_index;
    private Gtk.ScrolledWindow scrolled;
    private Gee.ArrayList<FileItem> items;
    private Scratch.Services.FuzzySearchIndexer indexer;
    private int window_height;
    private int max_items;
    private Gee.LinkedList<GLib.Cancellable> cancellables;
    private Gtk.EventControllerKey search_term_entry_key_controller;
    private Gtk.Label title_label;
    public Scratch.MainWindow current_window { get; construct; }
    public bool sidebar_is_visible { get; set; }

    public signal void open_file (string filepath);
    public signal void close_search ();

    public FuzzySearchPopover (Scratch.Services.FuzzySearchIndexer search_indexer, Scratch.MainWindow window) {
        Object (
            modal: true,
            relative_to: window.document_view,
            width_request: 500,
            current_window: window
        );

        int height;
        current_window.get_size (null, out height);
        window_height = height;

        fuzzy_finder = new Services.FuzzyFinder (search_indexer.project_paths);
        indexer = search_indexer;
        items = new Gee.ArrayList<FileItem> ();
        cancellables = new Gee.LinkedList<GLib.Cancellable> ();

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
        pointing_to = { 0, 32, 1, 1 };
        this.get_style_context ().add_class ("fuzzy-popover");

        title_label = new Gtk.Label (_("Find project files"));
        title_label.halign = Gtk.Align.START;
        title_label.get_style_context ().add_class ("h4");

        search_term_entry = new Gtk.SearchEntry ();
        search_term_entry.halign = Gtk.Align.FILL;
        search_term_entry.hexpand = true;

        search_result_container = new Gtk.ListBox () {
            selection_mode = Gtk.SelectionMode.NONE,
            activate_on_single_click = true,
            can_focus = false
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
                        // If the entry is empty or the text has changed
                        // since searching, do nothing
                        if (previous_text.length == 0 || previous_text != search_term_entry.text) {
                            return Source.REMOVE;
                        }

                        var next_cancellable = new GLib.Cancellable ();
                        cancellables.add (next_cancellable);

                        var dir_length = 0, term = search_term_entry.text;
                        var parts = term.split (Path.DIR_SEPARATOR_S, 0);
                        var rev_parts = term.reverse ().split (Path.DIR_SEPARATOR_S, 2);
                        if (rev_parts.length == 2) {
                            dir_length = rev_parts[0].length + 1;
                        }

                        fuzzy_finder.fuzzy_find_async.begin (term, dir_length,
                                                             get_current_project (),
                                                             next_cancellable,
                                                             (obj, res) => {
                        if (next_cancellable.is_cancelled ()) {
                            cancellables.remove (next_cancellable);
                            return;
                        }

                        var results = fuzzy_finder.fuzzy_find_async.end (res);
                        if (results == null) {
                            return;
                        }

                        bool first = true;



                        foreach (var c in search_result_container.get_children ()) {
                            search_result_container.remove (c);
                        }

                        items.clear ();

                        foreach (var result in results) {
                            var file_item = new FileItem (result, indexer.project_paths.size > 1);
                            file_item.can_focus = false;

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

    private string get_current_project () {
        Scratch.Services.Document current_document = current_window.document_view.current_document;
        if (current_document == null) {
            return "";
        }

        if (current_document.is_file_temporary) {
            return "";
        }

        string file_path = current_document.file.get_path ();

        var iter = indexer.project_paths.keys.iterator ();
        while (iter.next ()) {
            string project_path = iter.get ();
            if (file_path.has_prefix (project_path)) {
                return project_path;
            }
        }

        return "";
    }
 }
