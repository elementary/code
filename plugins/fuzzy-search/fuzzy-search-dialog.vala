public class Scratch.Dialogs.FuzzySearchDialog : Gtk.Dialog {
    private Gtk.Entry search_term_entry;
    private Services.FuzzyFinder fuzzy_finder;
    private Gtk.Box search_result_container;
    private int preselected_index;
    Gee.HashMap<string, Services.SearchProject> project_paths;
    Gee.ArrayList<FileItem> items;

    public signal void open_file (string filepath);
    public signal void close_search ();

    public FuzzySearchDialog (Gee.HashMap<string, Services.SearchProject> pps) {
        Object (
            transient_for: ((Gtk.Application) GLib.Application.get_default ()).active_window,
            deletable: false,
            modal: true,
            title:  _("Search project files…"),
            resizable: false,
            width_request: 600
        );
        fuzzy_finder = new Services.FuzzyFinder (pps);
        project_paths = pps;
        items = new Gee.ArrayList<FileItem> ();
    }

    construct {
        search_term_entry = new Gtk.Entry ();
        search_term_entry.halign = Gtk.Align.CENTER;
        search_term_entry.expand = true;
        search_term_entry.width_request = 575;

        var box = get_content_area ();
        box.orientation = Gtk.Orientation.VERTICAL;

        var layout = new Gtk.Grid () {
            column_spacing = 12,
            row_spacing = 6
        };
        layout.attach (search_term_entry, 0, 0, 2);
        layout.show_all ();

        search_result_container = new Gtk.Box (Gtk.Orientation.VERTICAL, 1);
        var scrolled = new Gtk.ScrolledWindow (null, null);
        scrolled.add (search_result_container);
        scrolled.margin_top = 10;

        search_term_entry.key_press_event.connect ((e) => {
            // Handle key up/down to select other files found by fuzzy search
            if (e.keyval == Gdk.Key.Down) {
                var item = items.get (preselected_index++);
                if (preselected_index >= items.size) {
                    preselected_index = 0;
                }
                var next_item = items.get (preselected_index);
                preselect_new_item (item, next_item);

                return true;
            } else if (e.keyval == Gdk.Key.Up) {
                var item = items.get (preselected_index--);
                if (preselected_index < 0) {
                    preselected_index = items.size -1;
                }
                var next_item = items.get (preselected_index);
                preselect_new_item (item, next_item);
                return true;
            } else if (e.keyval == Gdk.Key.Escape) {
                // Handle seperatly, otherwise it takes 2 escape hits to close the
                // modal
                close_search ();
                return true;
            }
            return false;
        });

        search_term_entry.activate.connect (() => {
            if (items.size > 0) {
                var item = items.get (preselected_index);
                open_file (item.filepath.strip ());
            }
        });

        search_term_entry.changed.connect ((e) => {
            if (search_term_entry.text.length >= 1) {
                var previous_text = search_term_entry.text;
                fuzzy_finder.fuzzy_find_async.begin (search_term_entry.text, (obj, res)  =>{
                    var results = fuzzy_finder.fuzzy_find_async.end(res);
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
                        var file_item = new FileItem (result);

                        if (first) {
                            first = false;
                            file_item.get_style_context ().add_class ("preselect-fuzzy");
                            preselected_index = 0;
                        }

                        file_item.get_style_context ().add_class ("fuzzy-item");

                        search_result_container.add (file_item);
                        items.add (file_item);
                    }

                    scrolled.show_all ();
                });
            } else {
                foreach (var c in search_result_container.get_children ()) {
                    search_result_container.remove (c);
                }
                items.clear ();
            }
        });

        scrolled.height_request = 42 * 5;

        box.add (layout);
        box.add (scrolled);
    }

    private void preselect_new_item (FileItem old_item, FileItem new_item) {
        var class_name = "preselect-fuzzy";
        old_item.get_style_context ().remove_class (class_name);
        new_item.get_style_context ().add_class (class_name);
    }
 }
