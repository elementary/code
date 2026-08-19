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
    public Scratch.Services.FuzzySearchIndexer indexer { get; construct; }

    private ListStore search_list_store;
    private Gee.LinkedList<GLib.Cancellable> cancellables;
    private Gtk.EventControllerKey search_term_entry_key_controller;
    private string current_doc_project;

    public FuzzySearchPopover (Scratch.Services.FuzzySearchIndexer search_indexer, Scratch.MainWindow window) {
        Object (
            current_window: window,
            indexer: search_indexer
        );
    }

    construct {
        modal = true;
        relative_to = current_window.document_view;
        width_request = 500;
        pointing_to = { 0, 32, 1, 1 };
        get_style_context ().add_class ("fuzzy-popover");

        var search_term_entry = new Gtk.SearchEntry () {
            placeholder_text = _("Find project files"),
            hexpand = true,
            valign = START
        };

        var title_label = new Granite.HeaderLabel (_("Find project files")) {
            mnemonic_widget = search_term_entry
        };

        var entry_layout = new Gtk.Box (VERTICAL, 0) {
            valign = START
        };
        entry_layout.add (title_label);
        entry_layout.add (search_term_entry);

        search_list_store = new ListStore (typeof (FileItem));

        var search_result_container = new Gtk.ListBox () {
            selection_mode = BROWSE,
            activate_on_single_click = true
        };
        search_result_container.bind_model (search_list_store, (obj) => (FileItem)obj);

        var scrolled = new Gtk.ScrolledWindow (null, null) {
            propagate_natural_height = true,
            child = search_result_container,
            hscrollbar_policy = NEVER
        };

        var box = new Gtk.Box (VERTICAL, 0);
        box.add (entry_layout);
        box.add (scrolled);
        box.show_all ();
        child = box;

        var fuzzy_finder = new Services.FuzzyFinder (indexer.project_paths);
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
            switch (keyval) {
                // Handle seperately, otherwise it takes 2 escape hits to close the modal
                case Gdk.Key.Escape:
                    close_search ();
                    return Gdk.EVENT_STOP;
                default:
                    break;
            }

            return Gdk.EVENT_PROPAGATE;
        });

        int preselected_index;
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

                                if (first) {
                                    first = false;
                                    preselected_index = 0;
                                }

                                search_list_store.insert_sorted (file_item, sort_func);
                            }

                            // Reset scrolling
                            scrolled.vadjustment.value = 0;
                        }
                    );

                    return Source.REMOVE;
                });
            } else {
                search_list_store.remove_all ();
            }
        });

        search_term_entry.realize.connect_after (() => {
            int height, max_items;
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

        search_result_container.move_cursor.connect (move_cursor);
        search_result_container.move_cursor.connect_after (move_cursor_after);
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

    /* focus_child not selected_row because selected_row sometimes lags behind focus
     * wrap in connect_after otherwise cursor will move after refocus
     */
    private bool wrap_cursor = false;
    private void move_cursor (Gtk.ListBox list_box, Gtk.MovementStep step, int count) requires (step == DISPLAY_LINES) {
        // Move up to the searchbar
        if (list_box.get_focus_child () == list_box.get_row_at_index (0) && count == -1) {
            move_focus (TAB_BACKWARD);
            return;
        }

        if (list_box.get_focus_child () == list_box.get_row_at_index ((int) search_list_store.n_items - 1) && count == 1) {
            wrap_cursor = true;
        }
    }

    private void move_cursor_after (Gtk.ListBox list_box, Gtk.MovementStep step, int count) {
        if (!wrap_cursor) {
            return;
        }

        list_box.get_row_at_index (0).grab_focus ();
        wrap_cursor = false;
    }

    private void handle_item_selection (FileItem item) {
        open_file (item.filepath.strip ());
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
