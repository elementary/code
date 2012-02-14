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
}

public class Scratch.TestTemplate : Template {
    
    public override Gtk.Widget get_creation_box () {
        return null;
    }
}

public class Scratch.TemplateManager : Object {
    
    Gtk.Dialog dialog;
    
    Gtk.ListStore list_store;
    Gtk.IconView icon_view;
    
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
        ((Gtk.Container)dialog.get_content_area ()).add (icon_view);
        icon_view.set_markup_column (1);
        icon_view.set_pixbuf_column (3);
    }
    
    public void register_template (string icon_id, string label, Type template_type) {
        Gtk.TreeIter iter;
        list_store.append (out iter);
        list_store.set (iter, 0, icon_id, 1, label, 2, template_type, 3, Gtk.IconTheme.get_default ().load_icon (icon_id, 64, 0));
    }
    
    public void show_window (Gtk.Widget? parent) {
        if (parent != null) dialog.set_transient_for ((Gtk.Window)parent);
        dialog.show_all ();
        dialog.run ();
        dialog.hide ();
    }
}