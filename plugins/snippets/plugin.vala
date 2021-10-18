/*
 * Copyright (c) 2021 Igor Montagner <igordsm@gmail.com>
 *
 * This is a free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; either version 2 of the
 * License, or (at your option) any later version.
 *
 * This is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public
 * License along with this program; see the file COPYING.  If not,
 * write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301 USA.
 *
 */


 private class Code.Plugins.Snippets.Snippet : Object {
    public string name {get; construct; }
    public string tag {get; construct; }
    public string language {get; construct; }

    public Gee.ArrayList<int> tabstops;
    public uint n_tabstops {
        get {
            return tabstops.size;
        }
    }

    private string _body;
    public string body {
        get { return _body; }
        set {
            _body = value;

            // PARSE $1 - $n
            int next_tabstop = 1;
            int next_tabstop_idx = 1;
            while ((next_tabstop_idx = _body.index_of ("$%d".printf (next_tabstop), 0)) >= 0) {
                for (int i = 0; i < next_tabstop - 1; i++) {
                    if (tabstops[i] > next_tabstop_idx) {
                        tabstops[i] -= 2;
                    }
                }

                tabstops.add (next_tabstop_idx);
                _body = _body.splice (next_tabstop_idx, next_tabstop_idx + 2);
                next_tabstop++;
            }

            // PARSE $0
            next_tabstop_idx = _body.index_of ("$0", 0);
            if (next_tabstop_idx >= 0) {
                for (int i = 0; i < next_tabstop - 1; i++) {
                    if (tabstops[i] > next_tabstop_idx) {
                        tabstops[i] -= 2;
                    }
                }
                tabstops.add (next_tabstop_idx);
                _body = _body.splice (next_tabstop_idx, next_tabstop_idx + 2);
            } else {
                tabstops.add (_body.length);
            }
        }
    }

    public Snippet (string name, string tag, string body, string language) {
        Object (
            name: name,
            tag: tag,
            body: body,
            language: language
        );
    }

    construct {
        tabstops = new Gee.ArrayList<int> ();
    }
}

private class Code.Plugins.Snippets.Provider : Gtk.SourceCompletionProvider, Object {
    public Code.Plugins.Snippets.Plugin snippets;
    public Gee.HashMultiMap<string, Snippet> snippet_map;

    private int current_tabstop = 0;
    private Snippet current_editing_snippet;
    private uint placeholder_edit_timeout = -1;
    private bool still_editing_placeholder = false;

    private const int FINISH_EDITING_TIMEOUT = 1000;

    construct {
        snippet_map = new Gee.HashMultiMap<string, Snippet> ();

        var par = new Json.Parser ();
        string user_snippets_filename = GLib.Path.build_filename (Constants.PLUGINDIR, "snippets", "snippets.json");
        par.load_from_file (user_snippets_filename);
        var reader = new Json.Reader (par.get_root ());

        foreach (string language in reader.list_members ()) {
            reader.read_member (language);

            var n_snippets = reader.count_elements ();
            for (int i = 0; i < n_snippets; i++) {
                reader.read_element (i);

                reader.read_member ("name");
                var name = reader.get_string_value ();
                reader.end_member ();

                reader.read_member ("tag");
                var tag = reader.get_string_value ();
                reader.end_member ();

                reader.read_member ("body");
                var body = reader.get_string_value ();
                reader.end_member ();

                var snippet = new Snippet (name, tag, body, language);

                snippet_map.@set (language, snippet);
                reader.end_element ();
            }
            reader.end_member ();
        }

    }

    public string get_name () {
        return "Snippets";
    }

    private string word_prefix (Gtk.SourceCompletionContext context) {
        Gtk.TextIter word;
        context.get_iter (out word);
        var word_start = word.copy ();
        word_start.backward_word_start ();

        return word.get_buffer ().get_text (word_start, word, false);
    }

    public bool match (Gtk.SourceCompletionContext context) {
        var word = word_prefix (context);
        var snips = snippet_map.@get (snippets.current_document.get_language_name ());
        var found = false;
        snips.foreach ((sni) => {
            if (sni.tag.has_prefix (word)) found = true;
            return !found;
        });
        return found;
    }

    public void populate (Gtk.SourceCompletionContext context) {
        var word = word_prefix (context);
        var snips = snippet_map.@get (snippets.current_document.get_language_name ());
        var props = new List<Gtk.SourceCompletionProposal> ();

        snips.foreach ((sni) => {
            if (sni.tag.has_prefix (word)) {
                var item = new Gtk.SourceCompletionItem () {
                    label = sni.name,
                    text = sni.body
                };
                item.set_data<Snippet> ("snippet", sni);
                props.append (item);
            }
            return true;
        });
        context.add_proposals (this, props, true);
    }

    public void start_editing_placeholders () {
        var current_view = snippets.current_view;
        var buffer = current_view.buffer;
        Gtk.TextIter snippet_start, snippet_end;
        buffer.get_iter_at_mark (out snippet_start, buffer.get_mark ("SNIPPET_START"));
        buffer.get_iter_at_mark (out snippet_end, buffer.get_mark ("SNIPPET_END"));

        for (int i = 0; i < current_editing_snippet.n_tabstops; i++) {
            Gtk.TextIter tab_i = snippet_start.copy ();
            tab_i.forward_chars (current_editing_snippet.tabstops[i]);
            current_view.buffer.create_mark ("SNIPPET_TAB_%d".printf (i), tab_i, true);
        }

        var indent_start = Scratch.Utils.measure_indent_at_iter (current_view, snippet_start);
        var snippet_line2 = snippet_start.copy ();
        snippet_line2.forward_line ();
        Scratch.Utils.increase_indent_in_region (current_view, snippet_line2, snippet_end, indent_start);

        current_tabstop = 0;
        place_cursor_at_tabstop (buffer, current_tabstop);
        if (current_editing_snippet.n_tabstops > 1) {
            current_view.completion.block_interactive ();
            current_view.key_press_event.connect (next_placeholder);

            still_editing_placeholder = true;
            placeholder_edit_timeout = Timeout.add (FINISH_EDITING_TIMEOUT, () => {
                if (!still_editing_placeholder) {
                    end_editing_placeholders ();
                    return false;
                }
                still_editing_placeholder = false;
                return true;
            });
        } else {
            end_editing_placeholders ();
        }
    }

    public bool next_placeholder (Gdk.EventKey evt) {
        still_editing_placeholder = true;
        if (evt.keyval == Gdk.Key.Tab) {
            var current_view = snippets.current_view;
            var buffer = current_view.buffer;

            current_tabstop++;
            place_cursor_at_tabstop (buffer, current_tabstop);
            if (current_tabstop == current_editing_snippet.n_tabstops - 1) {
                end_editing_placeholders ();
            }

            return true;
        }

        return false;
    }

    public void place_cursor_at_tabstop (Gtk.TextBuffer buffer, int tabstop) {
        Gtk.TextIter iter_start;
        var mark = buffer.get_mark ("SNIPPET_TAB_%d".printf (tabstop));
        buffer.get_iter_at_mark (out iter_start, mark);
        buffer.place_cursor (iter_start);
    }

    public void end_editing_placeholders () {
        still_editing_placeholder = false;
        if (current_editing_snippet.n_tabstops > 0) {
            snippets.current_view.completion.unblock_interactive ();
            snippets.current_view.key_press_event.disconnect (next_placeholder);
        }

        for (int i = 0; i < current_editing_snippet.n_tabstops; i++) {
            snippets.current_view.buffer.delete_mark_by_name ("SNIPPET_TAB_%d".printf (i));
        }

        snippets.current_view.buffer.delete_mark_by_name ("SNIPPET_START");
        snippets.current_view.buffer.delete_mark_by_name ("SNIPPET_END");
        Source.remove (placeholder_edit_timeout);
        placeholder_edit_timeout = -1;
    }

    public bool activate_proposal (Gtk.SourceCompletionProposal proposal, Gtk.TextIter iter) {
        current_editing_snippet = proposal.get_data<Snippet> ("snippet");
        var iter_start = iter.copy ();
        iter_start.backward_word_start ();

        var current_buffer = iter.get_buffer ();
        current_buffer.delete (ref iter_start, ref iter);
        current_buffer.create_mark ("SNIPPET_START", iter_start, true);
        current_buffer.create_mark ("SNIPPET_END", iter_start, false);
        iter.get_buffer ().insert (ref iter, current_editing_snippet.body, current_editing_snippet.body.length);
        start_editing_placeholders ();
        return true;
    }
}


public class Code.Plugins.Snippets.Plugin : Peas.ExtensionBase, Peas.Activatable {
    public Object object { owned get; construct; }

    private List<Gtk.SourceView> text_view_list = new List<Gtk.SourceView> ();
    public Scratch.Widgets.SourceView? current_view {get; private set;}
    public Scratch.Services.Document current_document {get; private set;}

    private Scratch.MainWindow main_window;
    private Scratch.Services.Interface plugins;

    public void activate () {
        plugins = (Scratch.Services.Interface) object;
        plugins.hook_window.connect ((w) => {
            this.main_window = w;
        });

        plugins.hook_document.connect (on_new_source_view);
    }

    public void deactivate () {
        text_view_list.@foreach (cleanup);
    }

    public void update_state () {

    }

    public void on_new_source_view (Scratch.Services.Document doc) {
        if (current_view != null) {
            if (current_view == doc.source_view)
                return;

            cleanup (current_view);
        }

        current_document = doc;
        current_view = doc.source_view;

        if (text_view_list.find (current_view) == null)
            text_view_list.append (current_view);

        var comp_provider = new Code.Plugins.Snippets.Provider () {
            snippets = this
        };

        try {
            current_view.completion.add_provider (comp_provider);
            current_view.completion.show_headers = true;
            current_view.completion.show_icons = true;
        } catch (Error e) {
            warning (e.message);
        }
    }

    private void cleanup (Gtk.SourceView view) {
        current_view.completion.get_providers ().foreach ((p) => {
            try {
                /* Only remove provider added by this plug in */
                if (p.get_name () == "Snippets") {
                    debug ("removing provider %s", p.get_name ());
                    current_view.completion.remove_provider (p);
                }
            } catch (Error e) {
                warning (e.message);
            }
        });
    }
}

[ModuleInit]
public void peas_register_types (GLib.TypeModule module) {
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type (typeof (Peas.Activatable),
                                       typeof (Code.Plugins.Snippets.Plugin));
}
