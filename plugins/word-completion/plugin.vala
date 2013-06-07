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


using Scratch;
using Scratch.Services;

public Euclide.Completion.Parser? parser = null;
public Document? current_document = null;
public Gtk.SourceView? current_view = null;
public Gtk.SourceBuffer? current_buffer = null;

public const string NAME = N_("Words Completion");
public const string DESCRIPTION = N_("Show a completion dialog with most used words from your files");

public class Scratch.Plugins.Completion : Peas.ExtensionBase,  Peas.Activatable {

    MainWindow main_window;

    public Object object { owned get; construct; }
    Scratch.Services.Interface plugins;
    
    static const unichar[] stoppers = {' ', '\n', '(', ';', '}', '{', '.'};

    List<Gtk.SourceView> text_view = new List<Gtk.SourceView> ();
    
    uint timeout = 0;
    uint timeout_parse = -1;
    
    public void activate () {
        plugins = (Scratch.Services.Interface) object;
        parser = new Euclide.Completion.Parser ();
        timeout_parse = Timeout.add (5000, on_timeout_update);

        plugins.hook_window.connect ((w) => {
            this.main_window = w;
        });
        
        plugins.hook_document.connect (on_new_source_view);
    }

    public void deactivate () {
        if (timeout_parse > 0) Source.remove (timeout_parse);
        text_view.foreach ((v) => {
            v.completion.get_providers ().foreach ((p) => { 
                try {
                    v.completion.remove_provider (p); 
                } catch (Error e) {
                    warning (e.message);
                }
            });
        });
    }

    public void update_state () {
    
    }

    public void on_new_source_view (Scratch.Services.Document doc) {
        // Globals vars
        current_document = doc;
        current_view = doc.source_view;
        current_buffer = doc.source_view.buffer;
        
        var view = doc.source_view;
        //assert(view != null);
        view.key_press_event.connect (on_key_press);
        //view.focus_out_event.connect (() => { window.hide(); return false; });
        //view.button_press_event.connect( () => { window.hide(); return false;});
        text_view.append (view);
        
        // Provider
        current_view.completion.get_providers ().foreach ((p) => { 
            try {
                current_view.completion.remove_provider (p); 
            } catch (Error e) {
                warning (e.message);
            }
        });
        var comp_provider = new CompletionProvider ();
        comp_provider.priority = 1;
        comp_provider.name = _("%s - Word Completion").printf (doc.get_basename ());
        try {
            current_view.completion.add_provider (comp_provider);
        } catch (Error e) {
            warning (e.message);
        }
    }
    
    bool on_timeout_update () {
        try {
            unowned Thread<void*> thread_a = Thread.create<void*> (threaded_update, true);
            thread_a.set_priority (ThreadPriority.LOW);
        } catch (ThreadError e) {
            warning (e.message);
        }
        return true;
    }
    
    void* threaded_update () {
        parser.clear ();
        foreach (var view in text_view) {
            if (view != null)
                parser.parse_text_view (view);
        }
        return null;
    }
    
    bool on_key_press (Gtk.Widget view, Gdk.EventKey event) {
        if (timeout > 0) Source.remove (timeout);
        //timeout = Timeout.add (100, () => { update_completion (); return false; });
        return false;
    }

}

[ModuleInit]
public void peas_register_types (GLib.TypeModule module) {
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type (typeof (Peas.Activatable),
                                       typeof (Scratch.Plugins.Completion));
}
