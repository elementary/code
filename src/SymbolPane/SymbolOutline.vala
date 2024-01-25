/*-
 * Copyright (c) 2013-2018 elementary LLC. (https://elementary.io)
 * Copyright (C) 2013 Tom Beckmann <tomjonabc@gmail.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

public abstract class Scratch.Services.SymbolOutline : Object {
    public Scratch.Services.Document doc { get; construct; }

    protected Code.Widgets.SourceList store;
    protected Code.Widgets.SourceList.ExpandableItem root;
    protected Gtk.CssProvider source_list_style_provider;
    public Gtk.Widget get_widget () { return store; }
    public abstract void parse_symbols ();

    construct {
        store = new Code.Widgets.SourceList ();
        root = new Code.Widgets.SourceList.ExpandableItem (_("Symbols"));
        store.root.add (root);

        set_up_css ();
    }

    protected void set_up_css () {
        source_list_style_provider = new Gtk.CssProvider ();
        Gtk.StyleContext.add_provider_for_screen (
            Gdk.Screen.get_default (),
            source_list_style_provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        );
        // Add a class to distinguish from foldermanager sourcelist
        store.get_style_context ().add_class ("symbol-outline");

        update_style_scheme (((Gtk.SourceBuffer)(doc.source_view.buffer)).style_scheme);
        doc.source_view.style_changed.connect (update_style_scheme);
    }

    protected void update_style_scheme (Gtk.SourceStyleScheme style_scheme) {
        var text_color_data = style_scheme.get_style ("text");

        // Default gtksourceview background color is white
        var color = "#FFFFFF";
        if (text_color_data != null) {
            color = text_color_data.background;
        }

        var define = ".symbol-outline .sidebar {background-color: %s;}".printf (color);

        try {
            source_list_style_provider.load_from_data (define);
        } catch (Error e) {
            critical ("Unable to sourcelist styling, going back to classic styling");
        }
    }
}
