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

public interface Code.Plugins.SymbolOutline : Object {
    public abstract Scratch.Services.Document doc { get; construct; }
    public abstract void parse_symbols ();
    public abstract Gtk.CssProvider source_list_style_provider { get; set construct; }
    public abstract Granite.Widgets.SourceList get_source_list ();
    public signal void goto (Scratch.Services.Document doc, int line);

    protected void set_up_css () {
        source_list_style_provider = new Gtk.CssProvider ();
        Gtk.StyleContext.add_provider_for_screen (
            Gdk.Screen.get_default (),
            source_list_style_provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        );
        // Add a class to distinguish from foldermanager sourcelist
        get_source_list ().get_style_context ().add_class ("symbol-outline");

        update_source_list_colors ();
        Scratch.settings.changed["style-scheme"].connect (update_source_list_colors);
    }

    protected void update_source_list_colors () {
        var sssm = Gtk.SourceStyleSchemeManager.get_default ();
        var style_scheme = Scratch.settings.get_string ("style-scheme");
        if (style_scheme in sssm.scheme_ids) {
            var theme = sssm.get_scheme (style_scheme);
            var text_color_data = theme.get_style ("text");

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
}
