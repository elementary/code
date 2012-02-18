/*
 * Copyright (C) 2011-2012 Lucas Baudin <xapantu@gmail.com>
 *
 *
 * This file is part of Scratch.
 *
 * Scratch is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 * 
 * Scratch is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See the GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License along
 * with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

public abstract class Scratch.Template : Object {
    public abstract Gtk.Widget get_creation_box ();
    public void configure_template (string origin, string destination, Gee.HashMap<string, string> variables) {
        debug ("Origin: %s, destination: %s\n", origin, destination);
        
        configure_directory (File.new_for_path(origin), File.new_for_path(destination));
    }
    
    void configure_directory (File origin, File destination) {
        /* First, let's check that these files actually exists and are directory */
        var origin_info = origin.query_info ("standard::type", 0);
        var destination_info = destination.query_info ("standard::type", 0);
    }
}

public class Scratch.TestTemplate : Template {
    
    public override Gtk.Widget get_creation_box () {
        return new Gtk.Label("Test");
    }
}

/**
 * Global Template Manager for Scratch. Only one instance of this object should
 * be used at once. It is created by the main Granite.Application (ScratchApp) and
 * a reference can be got from the plugin manager.
 **/
public class Scratch.TemplateManager : Object {
    
    Gtk.Dialog dialog;
    
    Gtk.ListStore list_store;
    Gtk.IconView icon_view;
    Scratch.Template current_template;
    
    Gtk.Container hbox { get { return ((Gtk.Container)dialog.get_content_area ()); } }
    
    public TemplateManager () {
        dialog = new Gtk.Dialog.with_buttons (_("Templates"), null,
            Gtk.DialogFlags.MODAL,
            Gtk.Stock.CLOSE, Gtk.ResponseType.ACCEPT);
        list_store = new Gtk.ListStore (4, 
            typeof (string) /* icon_id */,
            typeof (string) /* label */,
            typeof(Type) /* object_type */,
            typeof (Gdk.Pixbuf) /* icon */);
        icon_view = new Gtk.IconView.with_model (list_store);
        hbox.add (icon_view);
        icon_view.set_markup_column (1);
        icon_view.set_pixbuf_column (3);
        
        icon_view.selection_changed.connect (on_icon_selection_changed);
        icon_view.item_activated.connect ( () => {
            on_icon_selection_changed ();
        });
        
        register_template ("text-editor", "Sample", typeof(TestTemplate));
    }
    
    void on_icon_selection_changed () {
        var selected_items = icon_view.get_selected_items ();
        if (selected_items.length () > 0) {
            Gtk.TreeIter iter;
            list_store.get_iter (out iter, selected_items.nth_data (0));
            
            string id;
            Type tpl_type;
            list_store.get (iter, 0, out id, 2, out tpl_type);
            
            current_template = (Scratch.Template)Object.new (tpl_type);
            hbox.remove (icon_view);
            hbox.add (current_template.get_creation_box ());
            
            hbox.show_all ();
        }
    }
    
    /**
     * Register a new template
     * 
     * @param icon_id the icon id used in the IconView which shows all the template.
     * It will be used to launch an icon via Gtk.IconTheme.load_icon, so, any icon is
     * fine.
     * @param label The name of your template.
     * @param template_type The object type which must be instanciated when we click on
     * the icon on the IconView. It will be used to get the creation box and therefore must
     * inherit from #Scratch.Template.
     **/
    public void register_template (string icon_id, string label, Type template_type) {
        try {
            Gtk.TreeIter iter;
            var pixbuf = Gtk.IconTheme.get_default ().load_icon (icon_id, 64, 0);
            list_store.append (out iter);
            list_store.set (iter, 0, icon_id, 1, label, 2, template_type, 3, pixbuf);
        }
        catch (Error e) {
            warning ("Couldn't add template %s, %s icon can't be found.", label, icon_id);
        }
    }
    
    /**
     * Show a dialog which contains an #Gtk.IconView with all templates available.
     * 
     * @param parent The parent window, or null.
     **/
    public void show_window (Gtk.Widget? parent) {
        if (parent != null) dialog.set_transient_for ((Gtk.Window)parent);
        
        if (current_template != null) {
            hbox.remove (hbox.get_children ().nth_data (0));
            hbox.add (icon_view);
        }
        
        icon_view.unselect_all ();
        
        dialog.show_all ();
        dialog.run ();
        dialog.hide ();
    }
}