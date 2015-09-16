/*
 * Copyright (c) 2011 Lucas Baudin <xapantu@gmail.com>
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
 * write to the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 *
 */


public class Scratch.Plugins.Completion : Peas.ExtensionBase,  Peas.Activatable {

    MainWindow main_window;

    public Object object { owned get; construct; }
    Scratch.Services.Interface plugins;

    private List<Gtk.SourceView> text_view_list = new List<Gtk.SourceView> ();
    public Euclide.Completion.Parser parser {get; private set;}
    public Gtk.SourceView? current_view {get; private set;}
    public Scratch.Services.Document current_document {get; private set;}

    private const string NAME = N_("Words Completion");
    private const string DESCRIPTION = N_("Show a completion dialog with most used words from your files");

    private const uint [] activate_keys = {Gdk.Key.Return,
                                           Gdk.Key.KP_Enter,
                                           Gdk.Key.ISO_Enter,
                                           Gdk.Key.Tab,
                                           Gdk.Key.KP_Tab,
                                           Gdk.Key.ISO_Left_Tab,
                                    };

    private const uint USER_REQUESTED_KEY = Gdk.Key.backslash;

    private uint timeout_id = 0;
    private bool completion_visible = false;

    public void activate () {
        plugins = (Scratch.Services.Interface) object;
        parser = new Euclide.Completion.Parser ();
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

            parser.cancel_parsing ();

            if (timeout_id > 0)
                GLib.Source.remove (timeout_id);

            cleanup (current_view);
        }

        current_document = doc;
        current_view = doc.source_view;
        current_view.key_press_event.connect (on_key_press);
        current_view.completion.show.connect (on_completion_shown);
        current_view.completion.hide.connect (on_completion_hidden);

        if (text_view_list.find (current_view) == null)
            text_view_list.append (current_view);


        var comp_provider = new Scratch.Plugins.CompletionProvider (this);
        comp_provider.priority = 1;
        comp_provider.name = provider_name_from_document (doc);
        comp_provider.can_propose.connect (on_propose);

        try {
            current_view.completion.add_provider (comp_provider);
            current_view.completion.show_headers = true;
            current_view.completion.show_icons = true;
            /* Wait a bit to allow text to load then run parser*/
            timeout_id = Timeout.add (1000, on_timeout_update);

        } catch (Error e) {
            warning (e.message);
        }
    }

    private bool on_timeout_update () {
        try {
            new Thread<void*>.try ("word-completion-thread", () => {
                if (current_view != null)
                    parser.parse_text_view (current_view as Gtk.TextView);

                return null;
            });
        } catch (Error e) {
            warning (e.message);
        }

        timeout_id = 0;
        return false;
    }

    private bool on_key_press (Gtk.Widget view, Gdk.EventKey event) {
        uint kv = event.keyval;
        unichar uc = (unichar)(Gdk.keyval_to_unicode (kv));

        /* Pass through any modified keypress except Shift or Capslock */
        Gdk.ModifierType mods = event.state & Gdk.ModifierType.MODIFIER_MASK
                                            & ~Gdk.ModifierType.SHIFT_MASK
                                            & ~Gdk.ModifierType.LOCK_MASK;
        if (mods > 0 ) {
            /* Default key for USER_REQUESTED completion is ControlSpace
             * but this is trapped elsewhere. Control + USER_REQUESTED_KEY acts as an
             * alternative and also purges spelling mistakes and unused words from the list.
             * If used when a word or part of a word is selected, the selection will be
             * used as the word to find. */ 
            if ((mods & Gdk.ModifierType.CONTROL_MASK) > 0 && (kv == USER_REQUESTED_KEY)) {
                parser.rebuild_word_list (current_view);
                current_view.show_completion ();
                return true;
            } else
                return false;
        }

        bool activating = kv in activate_keys;
            
        if (completion_visible && activating) {
            current_view.completion.activate_proposal ();
            parser.add_last_word ();
            return true;
        }

        if (activating || (uc.isprint () && parser.is_delimiter (uc) )) {
            parser.add_last_word ();
            current_view.completion.hide ();
        }

        return false;
    }

    private void on_completion_shown () {
        completion_visible = true;
    }

    private void on_completion_hidden () {
        completion_visible = false;
    }

    private void on_propose (bool can_propose) {
        completion_visible = can_propose;
    }

    private string provider_name_from_document (Scratch.Services.Document doc) {
        return _("%s - Word Completion").printf (doc.get_basename ());
    }

    private void cleanup (Gtk.SourceView view) {
        current_view.key_press_event.disconnect (on_key_press);
        current_view.completion.show.disconnect (on_completion_shown);
        current_view.completion.hide.disconnect (on_completion_hidden);

        current_view.completion.get_providers ().foreach ((p) => {
            try {
                /* Only remove provider added by this plug in */
                if (p.get_name () == provider_name_from_document (current_document)) {
                    debug ("removing provider %s", p.get_name ());
                    current_view.completion.remove_provider (p);
                }
            } catch (Error e) {
                warning (e.message);
            }
        });

        completion_visible = false;
    }
}

[ModuleInit]
public void peas_register_types (GLib.TypeModule module) {
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type (typeof (Peas.Activatable),
                                       typeof (Scratch.Plugins.Completion));
}
