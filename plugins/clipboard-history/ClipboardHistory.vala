// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/***
  BEGIN LICENSE
    
  Copyright (C) 2014 Artem Anufrij <artem.anufrij@live.de>
  This program is free software: you can redistribute it and/or modify it   
  under the terms of the GNU Lesser General Public License version 3, as published  
  by the Free Software Foundation.
    
  This program is distributed in the hope that it will be useful, but   
  WITHOUT ANY WARRANTY; without even the implied warranties of  
  MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR    
  PURPOSE.  See the GNU General Public License for more details.
    
  You should have received a copy of the GNU General Public License along   
  with this program.  If not, see <http://www.gnu.org/licenses/>    
  
  END LICENSE   
***/

public const string NAME = N_("Clipboard History");
public const string DESCRIPTION = N_("Clipboard History");

public class Scratch.Plugins.ClipboardHistory : Peas.ExtensionBase,  Peas.Activatable {

    const int MAX_SIZE = 32;
    MainWindow window = null;
    Gtk.Notebook? contextbar = null;

    Gtk.ScrolledWindow scrolled;
    Gtk.ListStore list_store;
    Gtk.TreeIter iter;
    Gtk.TreeView view;

    List <Scratch.Widgets.SourceView> source_views = new List<Scratch.Widgets.SourceView> ();
    Scratch.Services.Document current_document = null;

    Scratch.Services.Interface plugins;
    public Object object { owned get; construct; }

    public void update_state () {
    }

    public void activate () {
        debug ("-- %s avtivate", NAME);

        plugins = (Scratch.Services.Interface) object;
        
        plugins.hook_window.connect ((w) => {
            if(window != null)
                return;

            window = w;
            add_document(window.get_current_document ());
        });

        plugins.hook_document.connect (add_document);

        plugins.hook_notebook_context.connect ((n) => { 
            if (contextbar == null) {
                this.contextbar = n;

                build_plugin_ui ();
            }
        });
    }

    public void deactivate () {
        debug ("-- %s deavtivate", NAME);

       /* if (connect_handler != null)
            window.disconnect ((ulong)connect_handler);*/
    }

    void add_document (Scratch.Services.Document doc){
        if (doc == null)
            return;

        current_document = doc;
        if (source_views.index (doc.source_view) >= 0)
            return;

        debug ("New Document");            

        source_views.append (doc.source_view);

        doc.source_view.copy_clipboard.connect (clipboard_action);
        doc.source_view.cut_clipboard.connect (clipboard_action);
    }

    void clipboard_action() {
        add_clipboard_item (window.clipboard.wait_for_text ());
    }

    void add_clipboard_item (string? item) {
        if(item == null)
            return;

        debug ("Clipboard added: %s", (string)item);
        
        if (contextbar.page_num (scrolled) == -1)
            contextbar.append_page (scrolled, new Gtk.Label (_("Clipboard History")));
        
        if (list_store.get_iter_from_string (out iter, (MAX_SIZE - 1).to_string ()))
            list_store.remove (iter);

        string[] lines = ((string)item).split ("\n");

        string title = "";
        for (int i = 0; i < lines.length; i++ ){
            if (lines [i].strip () != "") {
                title = lines [i];
                if (i > 0)
                    title = "..." + title;
                if (i + 1 < lines.length)
                    title += "...";
                break;
            }
        }

        if (title == "")
            return;

        list_store.insert (out iter, 0);
        list_store.set (iter, 0, "edit-paste", 1, title, 2, (string)item);
    }

    void build_plugin_ui () {
        scrolled = new Gtk.ScrolledWindow (null, null);
        list_store = new Gtk.ListStore (3, typeof (string), typeof (string), typeof (string));

        // The View:
        view = new Gtk.TreeView.with_model (list_store);
        view.headers_visible = false;
        view.set_tooltip_column (2);

        view.insert_column_with_attributes (-1, "icon-name", new Gtk.CellRendererPixbuf (), "icon_name", 0);
        view.insert_column_with_attributes (-1, "clipboard", new Gtk.CellRendererText (), "text", 1);

        scrolled.add (view);
        scrolled.show_all ();
    }

}

[ModuleInit]
public void peas_register_types (GLib.TypeModule module) {
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type (typeof (Peas.Activatable),
                                     typeof (Scratch.Plugins.ClipboardHistory));
}