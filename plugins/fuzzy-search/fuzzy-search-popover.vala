/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2023-2026 elementary, Inc. <https://elementary.io>
 *
 * Authored by: Marvin Ahlgrimm
 *              Colin Kiama <colinkiama@gmail.com>
 */

public class Scratch.FuzzySearchPopover : Gtk.Popover {
    public signal void open_file (string filepath);
    public signal void close_search ();

    public Scratch.MainWindow current_window { get; construct; }
    public Scratch.Services.FuzzySearchIndexer search_indexer { get; construct; }
    public bool sidebar_is_visible { get; set; }

    private Gtk.SearchEntry search_term_entry;
    private Services.FuzzyFinder fuzzy_finder;
    private Gtk.ListBox search_result_container;
    private ListStore search_list_store;
    private int preselected_index;
    private Gtk.ScrolledWindow scrolled;
    private Scratch.Services.FuzzySearchIndexer indexer;
    private int window_height;
    private int max_items;
    private Gee.LinkedList<GLib.Cancellable> cancellables;
    private Gtk.EventControllerKey search_term_entry_key_controller;
    private Gtk.Label title_label;
    private string current_doc_project;

    public FuzzySearchPopover (Scratch.Services.FuzzySearchIndexer search_indexer, Scratch.MainWindow window) {
        Object (
            current_window: window,
            search_indexer: search_indexer
        );
    }

    construct {
        modal = true;
        relative_to = current_window.document_view;
        width_request = 500;
        pointing_to = { 0, 32, 1, 1 };
        get_style_context ().add_class ("fuzzy-popover");

        title_label = new Granite.HeaderLabel (_("Find project files"));

        search_term_entry = new Gtk.SearchEntry () {
            hexpand = true,
            valign = START
        };

        search_list_store = new ListStore (typeof (FileItem));
        search_result_container = new Gtk.ListBox () {
            selection_mode = NONE,
            activate_on_single_click = true,
            can_focus = false
        };
        search_result_container.get_style_context ().add_class ("fuzzy-list");
        search_result_container.bind_model (search_list_store, (obj) => (FileItem)obj);

        var entry_layout = new Gtk.Box (VERTICAL, 0) {
            valign = START
        };
        entry_layout.add (title_label);
        entry_layout.add (search_term_entry);

        scrolled = new Gtk.ScrolledWindow (null, null) {
            propagate_natural_height = true,
            hexpand = true,
            vexpand = true,
            child = search_result_container
        };

        var box = new Gtk.Box (VERTICAL, 0);
        box.add (entry_layout);
        box.add (scrolled);
        box.show_all ();

        scrolled.hide ();

        add (box);

        fuzzy_finder = new Services.FuzzyFinder (search_indexer.project_paths);
        indexer = search_indexer;
        cancellables = new Gee.LinkedList<GLib.Cancellable> ();

        search_result_container.row_activated.connect ((row) => {
            var file_item = row as FileItem;
            if (file_item == null) {
                return;
            }

            handle_item_selection (file_item);
        });

        search_term_entry_key_controller = new Gtk.EventControllerKey (search_term_entry);
        search_term_entry_key_controller.key_pressed.connect ((keyval, keycode, state) => {
            // Handle key up/down to select other files found by fuzzy search
            switch (keyval) {
                case Gdk.Key.Down:
                    if (search_list_store.n_items > 0) {
                    // if (items.size > 0) {
                        var old_index = preselected_index;
                        var item = search_list_store.get_item (preselected_index++);
                        // var item = items.get (preselected_index++);
                        if (preselected_index >= search_list_store.n_items) {
                            preselected_index = 0;
                        }

                        var next_item = search_list_store.get_item (preselected_index);
                        preselect_new_item ((FileItem) item, (FileItem) next_item);
                        calculate_scroll_offset (old_index, preselected_index);
                    }

                    return true;
                case Gdk.Key.Up:
                    if (search_list_store.n_items > 0) {
                        var old_index = preselected_index;
                        var item = search_list_store.get_item (preselected_index--);
                        if (preselected_index < 0) {
                            preselected_index = (int) search_list_store.n_items - 1;
                        }

                        var next_item = search_list_store.get_item (preselected_index);
                        preselect_new_item ((FileItem) item, (FileItem) next_item);
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
            if (search_list_store.n_items > 0) {
                handle_item_selection ((FileItem) search_list_store.get_item (preselected_index));
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

                    fuzzy_finder.fuzzy_find_async.begin (
                        term,
                        dir_length,
                        current_doc_project,
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

                            search_list_store.remove_all ();

                            foreach (var result in results) {
                                var file_item = new FileItem (result, indexer.project_paths.size > 1);
                                file_item.can_focus = false;

                                if (first) {
                                    first = false;
                                    file_item.get_style_context ().add_class ("preselect-fuzzy");
                                    preselected_index = 0;
                                }

                                search_list_store.insert_sorted (file_item, sort_func);
                            }

                            scrolled.hide ();
                            scrolled.show_all ();

                            // Reset scrolling
                            scrolled.vadjustment.value = 0;
                        }
                    );

                    return Source.REMOVE;
                });
            } else {
                search_list_store.remove_all ();

                scrolled.hide ();
            }
        });

        search_term_entry.realize.connect_after (() => {
            int height;
            current_window.get_size (null, out height);

            // Limit the shown results if the window height is too small
            if (height > 400) {
                max_items = height / 80;
            } else {
                max_items = 3;
            }

            scrolled.set_max_content_height (45 /* height */ * max_items);

            current_doc_project = get_current_project (); // This will not change while popover is showing
        });
    }

    private int sort_func (Object a, Object b) {
        var result_a = ((FileItem)a).result;
        var result_b = ((FileItem)b).result;
        var project_a_is_current = result_a.project == current_doc_project;
        var project_b_is_current = result_b.project == current_doc_project;
        if (project_a_is_current && !project_b_is_current) {
            return 1;
        } else if (project_b_is_current && !project_a_is_current) {
            return -1;
        } else if (result_a.score > result_b.score) {
            return -1;
        } else if (result_b.score > result_a.score) {
            return 1;
        } else {
            return strcmp (((FileItem)a).result.full_path, ((FileItem)b).result.full_path);
        }
    }

    private void calculate_scroll_offset (int old_position, int new_position) {
        // Shortcut if jumping from first to last or the other way round
        if (new_position == 0 && old_position > new_position) {
            scrolled.vadjustment.value = 0;
            return;
        } else if (old_position == 0 && new_position == search_list_store.n_items - 1) {
            scrolled.vadjustment.value = scrolled.vadjustment.get_upper ();
            return;
        }

        var size_box = scrolled.vadjustment.get_upper () / search_list_store.n_items;
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

    private void handle_item_selection (FileItem item) {
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
