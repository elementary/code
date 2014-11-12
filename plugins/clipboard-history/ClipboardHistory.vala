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
public const string DESCRIPTION = N_("Clipboard to view history");

public class Scratch.Plugins.ClipboardHistory : Peas.ExtensionBase,  Peas.Activatable {

    const int MAX_SIZE = 32;
    const int MAX_LINE_LENGTH = 24;
    const string DOTS = _("...");
    MainWindow window = null;
    Gtk.Notebook? contextbar = null;

    Gtk.ScrolledWindow scrolled;
    Gtk.ListStore list_store;
    Gtk.TreeIter iter;
    Gtk.TreeView view;

    Gtk.Menu menu;
    Gtk.MenuItem menu_paste;
    Gtk.MenuItem menu_delete;

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
            window.clipboard.owner_change.connect (clipboard_action);
        });

        plugins.hook_notebook_context.connect ((n) => { 
            if (contextbar == null) {
                this.contextbar = n;

                build_plugin_ui ();
            }
        });
    }

    public void deactivate () {
        debug ("-- %s deavtivate", NAME);

        contextbar.remove_page (contextbar.page_num (scrolled));

        window.clipboard.owner_change.disconnect (clipboard_action);
    }

    void clipboard_action(Gdk.Event event) {
        string? clipboard_content = window.clipboard.wait_for_text ();
        if (clipboard_content != null)
            add_clipboard_item (clipboard_content);
    }

    void add_clipboard_item (string clipboard_content) {
        if(clipboard_content == "")
            return;
        
        // Set the plugin visible
        if (contextbar.page_num (scrolled) == -1)
            contextbar.append_page (scrolled, new Gtk.Label (_("Clipboard History")));
        
        // Delete last item, if the size of the list store > MAX_SIZE
        if (list_store.get_iter_from_string (out iter, (MAX_SIZE - 1).to_string ()))
            list_store.remove (iter);

        // Delete dupplicates from list store, if exists
        delete_dupplicates (clipboard_content);

        // Create a short title
        string title = create_clipboard_item_title (clipboard_content);

        if (title == "")
            return;

        // Add a new item
        list_store.insert (out iter, 0);
        list_store.set (iter, 0, "edit-paste", 1, title, 2, clipboard_content);
    }

    string create_clipboard_item_title (string clipboard_content) {

        string [] lines = clipboard_content.split ("\n");

        string title = "";
        
        for (int i = 0; i < lines.length; i++ ){
            if (lines [i].strip () != "") {
                title = lines [i];
                if (i > 0)
                    title = DOTS + title;                                   // ...Code
                if (title.length > MAX_LINE_LENGTH)
                    title = title.substring (0, MAX_LINE_LENGTH) + DOTS;    // Code...
                else if (i + 1 < lines.length)
                    title += DOTS;                                          // Code...
                break;
            }
        }

        return title;
    }

    void delete_dupplicates (string new_clipboard_string) {
        Gtk.TreeIter? to_delete = null;
        list_store.foreach ((model, path, it) => {
            Value content;
            list_store.get_value (it, 2, out content);
            string clipboard_string = content.get_string ();
            if (clipboard_string == new_clipboard_string) {
                to_delete = it;
                return true;
            }

            return false;
        });

        if (to_delete != null)
            list_store.remove (to_delete);
    }

    void build_plugin_ui () {
        scrolled = new Gtk.ScrolledWindow (null, null);
        list_store = new Gtk.ListStore (3, typeof (string), typeof (string), typeof (string));

        // Context Menu
        menu = new Gtk.Menu ();

        menu_delete = new Gtk.MenuItem.with_label (_("Delete"));
        menu_delete.activate.connect (delete_selected);

        menu_paste = new Gtk.MenuItem.with_label (_("Paste"));
        menu_paste.activate.connect (paste_selected);

        menu.append (menu_paste);
        menu.append (menu_delete);

        menu.show_all ();

        // The View
        view = new Gtk.TreeView.with_model (list_store);
        view.headers_visible = false;
        view.set_tooltip_column (2);

        view.insert_column_with_attributes (-1, "icon-name", new Gtk.CellRendererPixbuf (), "icon_name", 0);
        view.insert_column_with_attributes (-1, "clipboard", new Gtk.CellRendererText (), "text", 1);
        view.button_press_event.connect (show_context_menu);

        scrolled.add (view);
        scrolled.show_all ();
    }

    public bool show_context_menu (Gtk.Widget sender, Gdk.EventButton evt) {
        if (evt.type == Gdk.EventType.BUTTON_PRESS && evt.button == 3)
            menu.popup (null, null, null, evt.button, evt.time);
            
        return false;
    }

    public void paste_selected () {
        var selection = view.get_selection();
        selection.set_mode(Gtk.SelectionMode.SINGLE);
        Gtk.TreeModel model;
        Gtk.TreeIter iter;
        if (!selection.get_selected(out model, out iter)) {
            return;
        }
        Value content;
        model.get_value(iter, 2, out content);
        string clipboard_string = content.get_string ();

        Scratch.Services.Document? current_document = window.get_current_document ();

        if (current_document == null)
            return;
        // Set focus on active document, delete selected text and paste the value from selected item.
        current_document.focus();
        current_document.source_view.delete_from_cursor (Gtk.DeleteType.CHARS, current_document.source_view.get_selected_text ().length);
        current_document.source_view.insert_at_cursor (clipboard_string);
    }

    public void delete_selected () {
        var selection = view.get_selection();
        selection.set_mode(Gtk.SelectionMode.SINGLE);
        Gtk.TreeModel model;
        Gtk.TreeIter iter;
        if (!selection.get_selected(out model, out iter)) {
            return;
        }
        list_store.remove (iter);

        // Hiding PlugIn, if no more items exist in the list store.
        if (!list_store.get_iter_first (out iter))
            contextbar.remove_page (contextbar.page_num (scrolled));
    }
}

[ModuleInit]
public void peas_register_types (GLib.TypeModule module) {
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type (typeof (Peas.Activatable),
                                     typeof (Scratch.Plugins.ClipboardHistory));
}