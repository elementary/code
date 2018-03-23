/*-
 * Copyright (c) 2017-2018 elementary LLC. (https://elementary.io)
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Authored by: Corentin Noël <corentin@elementary.io>
 */

public class Code.Plugins.Outline.SidePane : Gtk.Stack, Code.PaneSwitcher {
    public unowned Scratch.Services.Document doc { get; construct; }
    public string icon_name { get; set; }
    public string title { get; set; }
    public Granite.Widgets.SourceList store { get; construct; }

    protected bool fetching {
        set {
            if (value) {
                set_visible_child_name ("fetching");
            } else {
                set_visible_child_name ("symbols");
            }
        }
    }

    construct {
        width_request = 200;
        icon_name = "plugin-outline-symbolic";
        title = _("Symbols");
        store = new Granite.Widgets.SourceList ();
        store.expand = true;
        store.item_selected.connect ((selected) => {
            go_to_line ((selected as Outline.SourceSymbol).line);
        });

        var fetching_label = new Gtk.Label (_("Fetching symbols…"));
        fetching_label.halign = Gtk.Align.CENTER;
        fetching_label.valign = Gtk.Align.CENTER;
        fetching_label.get_style_context ().add_class (Granite.STYLE_CLASS_H3_LABEL);
        fetching_label.wrap = true;
        fetching_label.show_all ();

        add_named (fetching_label, "fetching");
        add_named (store, "symbols");
    }

    protected void go_to_line (int line) {
        var text = doc.source_view;
        Gtk.TextIter iter;
        text.buffer.get_iter_at_line (out iter, line - 1);
        text.buffer.place_cursor (iter);
        text.scroll_to_iter (iter, 0.0, true, 0.5, 0.5);
    }
}
