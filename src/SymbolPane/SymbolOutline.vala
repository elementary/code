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

namespace Scratch.Services {
public enum SymbolType {
    CLASS,
    PROPERTY,
    SIGNAL,
    METHOD,
    STRUCT,
    ENUM,
    CONSTANT,
    OTHER;

    public unowned string to_string () {
        switch (this) {
            case SymbolType.CLASS:
                return _("Class");
            case SymbolType.PROPERTY:
                return _("Property");
            case SymbolType.SIGNAL:
                return _("Signal");
            case SymbolType.METHOD:
                return _("Method");
            case SymbolType.STRUCT:
                return _("Struct");
            case SymbolType.ENUM:
                return _("Enum");
            case SymbolType.CONSTANT:
                return _("Constant");
            case SymbolType.OTHER:
                return _("Other");
            default:
                assert_not_reached ();
        }
    }
}

public interface SymbolItem : Granite.Widgets.SourceList.ExpandableItem {
    public abstract SymbolType symbol_type { get; set; default = SymbolType.OTHER;}
}
}

public abstract class Scratch.Services.SymbolOutline : Object {
    protected static SymbolType[] filters;

    public Scratch.Services.Document doc { get; construct; }
    //TODO Should this be a class property or an instance property?

    protected Gee.HashMap<SymbolType, Gtk.CheckButton> checks;
    protected Gtk.Box symbol_pane;
    protected Granite.Widgets.SourceList store;
    protected Granite.Widgets.SourceList.ExpandableItem root;
    protected Gtk.CssProvider source_list_style_provider;
    public Gtk.Widget get_widget () { return (Gtk.Widget)symbol_pane; }
    public abstract void parse_symbols ();

    construct {
        store = new Granite.Widgets.SourceList ();
        checks = new Gee.HashMap<SymbolType, Gtk.CheckButton> ();
        root = new Granite.Widgets.SourceList.ExpandableItem (_("Symbols"));
        store.root.add (root);

        symbol_pane = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) {
            hexpand = true
        };
        var tool_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) ;
        var search_entry = new Gtk.SearchEntry () {
            placeholder_text = _("Find Symbol"),
            hexpand = true
        };

        var filter_popover = new Gtk.Popover (null);
        var popover_content = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        foreach (var filter in filters) {
            var check = new Gtk.CheckButton.with_label (filter.to_string ()) {
                active = true
            };
            popover_content.add (check);
            checks[filter] = check;
        }
        //Always have OTHER category
        var check = new Gtk.CheckButton.with_label (SymbolType.OTHER.to_string ()) {
            active = true
        };
        popover_content.add (check);
        checks[SymbolType.OTHER] = check;

        popover_content.show_all ();
        //TODO Provide "filter" icon?
        filter_popover.add (popover_content);

        var filter_button = new Gtk.MenuButton () {
            image = new Gtk.Image.from_icon_name (
                "open-menu-symbolic",
                Gtk.IconSize.SMALL_TOOLBAR
            ),
            popover = filter_popover,
            tooltip_text = _("Filter symbol type"),
        };

        tool_box.add (search_entry);
        tool_box.add (filter_button);

        symbol_pane.add (tool_box);
        symbol_pane.add (store);
        set_up_css ();
        symbol_pane.show_all ();

        symbol_pane.realize.connect (() => {
            store.set_filter_func (
                (item) => {
                    if (item == null) {
                        critical ("item is null");
                        return false;
                    } else if (search_entry == null) {
                        critical ("search_entry is null");
                        return true;
                    } else if (search_entry.text == null) {
                        warning ("seach entry text is null");
                        return true;
                    } else if ((item is Granite.Widgets.SourceList.ExpandableItem) &&
                                item.n_children > 0) {

                        return true;
                    } else if (item is SymbolItem) {
                        var symbol = (SymbolItem)item;
                        if (checks[symbol.symbol_type] != null &&
                            !checks[symbol.symbol_type].active) {

                            return false;
                        }

                        if (checks[symbol.symbol_type] == null &&
                            !checks[SymbolType.OTHER].active) {

                            return false;
                        }

                        if (!symbol.name.contains (search_entry.text)) {
                            return false;
                        }
                    }

                    return true;
                },
                false
            );

            search_entry.changed.connect (() => {
                //TODO Throttle for fast typing
                store.refilter ();
            });
        });

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
