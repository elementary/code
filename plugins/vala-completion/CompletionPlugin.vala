/*-
 * Copyright (c) 2017 elementary LLC. (https://elementary.io)
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Authored by: Adam Bieńkowski <donadigos159@gmail.com>
 */

public class Scratch.Plugins.ValaCompletion : Peas.ExtensionBase, Peas.Activatable {
    public Object object { owned get; construct; }

    private const uint PARSE_INTERVAL_MS = 2000;

    private Scratch.Services.Interface plugins;
    private Gee.ArrayList<Scratch.Services.Document> documents_hooked;
    private unowned Scratch.MainWindow window;
    private ValaCodeParser? parser;
    private uint parse_timeout_id = 0;
    private uint show_info_timeout_id = 0;

    public void update_state () {

    }

    public void activate () {
        documents_hooked = new Gee.ArrayList<Scratch.Services.Document> ();
        parser = new ValaCodeParser ();

        plugins = (Scratch.Services.Interface) object;
        plugins.hook_document.connect (on_hook_document);
        plugins.hook_window.connect (on_hook_window);

        weak Gtk.IconTheme default_theme = Gtk.IconTheme.get_default ();
        default_theme.add_resource_path ("/com/github/scratch/vala-completion");

        reset_parse_timeout ();
    }

    // TODO: deactivate the plugin
    public void deactivate () {

    }

    private void on_hook_window (Scratch.MainWindow window) {
        this.window = window;
    }

    private void on_hook_document (Scratch.Services.Document document) {
        if (document in documents_hooked) {
            return;
        }

        // TODO: we only add the documents that were opened.
        // It would be better to auto-detect all the sources
        // automatically (not just iterating through the files
        // in the project root directory)
        parser.add_document (document);

        var provider = new ValaDocumentProvider (window, parser);
        var source_view = document.source_view;
        source_view.completion.select_on_show = true;
        source_view.completion.show_icons = true;
        source_view.completion.auto_complete_delay = 0;
        source_view.completion.remember_info_visibility = true;
        source_view.completion.get_info_window ().border_width = 0;
        try {
            source_view.completion.add_provider (provider);
        } catch (Error e) {
            warning (e.message);
        }

        source_view.buffer.modified_changed.connect (() => on_source_view_buffer_changed (document));

        source_view.event_after.connect ((event) => {
            if (event.get_event_type () == Gdk.EventType.MOTION_NOTIFY) {
                on_source_view_motion_notify_event (source_view, event.motion);
            }
        });

        documents_hooked.add (document);
    }

    private void on_source_view_buffer_changed (Scratch.Services.Document document) {
        parser.update_document_content (document);
        reset_parse_timeout ();
    }
    
    private void reset_parse_timeout () {
        if (parse_timeout_id > 0) {
            Source.remove (parse_timeout_id);
            parse_timeout_id = 0;
        }

        parse_timeout_id = Timeout.add (PARSE_INTERVAL_MS, () => {
            parse_timeout_id = 0;

            if (window.get_current_document () == null) {
                return Source.REMOVE;
            }

            parser.queue_parse ();
            return Source.REMOVE;
        });
    }

    private bool on_source_view_motion_notify_event (Scratch.Widgets.SourceView source_view, Gdk.EventMotion event) {
        if (show_info_timeout_id > 0) {
            Source.remove (show_info_timeout_id);
            show_info_timeout_id = 0;
        }

        if (source_view.tooltip_text != null) {
            source_view.tooltip_text = null;
        }

        show_info_timeout_id = Timeout.add (400, () => {
            return show_info_func (source_view, event);
        });

        Gtk.Widget wid = source_view as Gtk.Widget;
        return wid.motion_notify_event (event);
    }
    
    // TODO: this doesn't work that good
    private bool show_info_func (Scratch.Widgets.SourceView source_view, Gdk.EventMotion event) {
        show_info_timeout_id = 0;

        Gdk.Rectangle rect;
        source_view.get_visible_rect (out rect);

        int x = (int)event.x + rect.x;
        int y = (int)event.y + rect.y;

        Gtk.TextIter start_iter;
        source_view.get_iter_at_location (out start_iter, x, y);


        var source_buffer = source_view.get_buffer ();

        Gtk.TextIter start_buffer_iter;
        source_buffer.get_start_iter (out start_buffer_iter);
        if (start_buffer_iter.compare (start_iter) == 0) {
            return Source.REMOVE;
        }

        Gtk.TextIter end_iter = Gtk.TextIter ();
        end_iter.assign (start_iter);
        end_iter.forward_to_line_end ();

        if (end_iter.get_line () > start_iter.get_line ()
            || source_buffer.get_text (start_iter, end_iter, false).strip () == ""
            || end_iter.get_line_offset () <= start_iter.get_line_offset ()) {
            return Source.REMOVE;
        }

        var document = window.get_current_document ();
        if (document == null) {
            return Source.REMOVE;
        }

        string filename = document.file.get_path ();
        var symbol = parser.lookup_symbol_at (filename, start_iter.get_line () + 1, start_iter.get_line_offset ());
        if (symbol == null || symbol.name == null) {
            return Source.REMOVE;
        }

        string definition = parser.write_symbol_definition (symbol);
        if (definition == "") {
            definition = null;
        }

        source_view.tooltip_text = definition;
        source_view.trigger_tooltip_query ();

        return Source.REMOVE;
    }    
}

[ModuleInit]
public void peas_register_types (GLib.TypeModule module) {
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type (typeof (Peas.Activatable),
                                      typeof (Scratch.Plugins.ValaCompletion));
}
