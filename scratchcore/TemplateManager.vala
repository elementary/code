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

public class Scratch.TemplateManager : Object {
    
    Gtk.Dialog dialog;
    
    public TemplateManager () {
        dialog = new Gtk.Dialog.with_buttons (_("Templates"), null,
            Gtk.DialogFlags.MODAL,
            Gtk.Stock.CLOSE, Gtk.ResponseType.ACCEPT);
    }
    
    public void show_window (Gtk.Widget? parent) {
        if (parent != null) dialog.set_transient_for ((Gtk.Window)parent);
        dialog.show_all ();
        dialog.run ();
        dialog.hide ();
    }
}