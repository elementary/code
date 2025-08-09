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

public enum Scratch.Services.SymbolType {
    CLASS,
    PROPERTY,
    SIGNAL,
    METHOD,
    STRUCT,
    ENUM,
    CONSTANT,
    CONSTRUCTOR,
    INTERFACE,
    NAMESPACE,
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
            case SymbolType.CONSTRUCTOR:
                return _("Constructor");
            case SymbolType.INTERFACE:
                return _("Interface");
            case SymbolType.NAMESPACE:
                return _("Namespace");
            case SymbolType.OTHER:
                return _("Other");
            default:
                assert_not_reached ();
        }
    }
}

public interface Scratch.Services.SymbolItem : Code.Widgets.SourceList.ExpandableItem {
    public abstract SymbolType symbol_type { get; set; default = SymbolType.OTHER;}
}

public class Scratch.Services.SymbolOutline : Gtk.Box {
    protected static SymbolType[] filters; //Initialized by derived classes
    const string ACTION_GROUP = "symbol";
    const string ACTION_PREFIX = ACTION_GROUP + ".";
    const string ACTION_SELECT = "action-select";
    const string ACTION_TOGGLE = "toggle-";
    const uint SPINNER_DELAY_MSEC = 300;
    SimpleActionGroup symbol_action_group;

    public Scratch.Services.Document doc { get; construct; }

    protected Gee.HashMap<SymbolType, SimpleAction> checks;
    protected Gtk.SearchEntry search_entry;
    protected Code.Widgets.SourceList store;
    protected Code.Widgets.SourceList.ExpandableItem root;
    protected Gtk.CssProvider source_list_style_provider;
    public Gtk.Widget get_widget () { return this; }
    public bool tool_box_sensitive {
        set {
            search_entry.sensitive = value;
            filter_button.sensitive = value;
        }
    }

    protected bool took_too_long;
    private uint show_spinner_timeout_id = 0;
    protected void before_parse () {
        tool_box_sensitive = true;
        took_too_long = false;
        show_spinner_timeout_id = Timeout.add (SPINNER_DELAY_MSEC, () => {
            show_spinner_timeout_id = 0;
            stack.visible_child = spinner;
            spinner.start ();
            return Source.REMOVE;
        });
    }

    protected void after_parse () {
        if (show_spinner_timeout_id > 0) {
            Source.remove (show_spinner_timeout_id);
            show_spinner_timeout_id = 0;
        }

        spinner.stop ();
        stack.visible_child = filter_button;
        tool_box_sensitive = !took_too_long;
    }

    public virtual void parse_symbols () {}
    public virtual void add_tooltips (Code.Widgets.SourceList.ExpandableItem root) {}

    private Gtk.MenuButton filter_button;
    private Gtk.Spinner spinner;
    private Gtk.Stack stack;

    construct {
        symbol_action_group = new SimpleActionGroup ();
        insert_action_group (ACTION_GROUP, symbol_action_group);

        checks = new Gee.HashMap<SymbolType, SimpleAction> ();
        store = new Code.Widgets.SourceList ();
        root = new Code.Widgets.SourceList.ExpandableItem (_("Symbols"));
        store.root.add (root);

        search_entry = new Gtk.SearchEntry () {
            placeholder_text = _("Find Symbol"),
            hexpand = true
        };

        filter_button = new Gtk.MenuButton () {
            image = new Gtk.Image.from_icon_name (
                "filter-symbolic",
                Gtk.IconSize.SMALL_TOOLBAR
            ),
            tooltip_text = _("Filter symbol type"),
        };

        var select_section = new Menu ();
        var top_model = new Menu ();
        foreach (var filter in filters) {
            add_filter_menuitem (top_model, filter);
        }

        // Derived classes must not add SymbolType.OTHER
        add_filter_menuitem (top_model, SymbolType.OTHER);

        var select_action = new SimpleAction (
            ACTION_SELECT,
            new VariantType ("b")
        );
        select_action.activate.connect (action_select_filters);
        symbol_action_group.add_action (select_action);

        select_section.append (
            _("Select All"),
            Action.print_detailed_name (
                ACTION_PREFIX + ACTION_SELECT, new Variant ("b", true)
            )
        );
        select_section.append (
            _("Deselect All"),
            Action.print_detailed_name (
                ACTION_PREFIX + ACTION_SELECT, new Variant ("b", false)
            )
        );
        top_model.append_section ("", select_section);

        filter_button.menu_model = top_model;

        spinner = new Gtk.Spinner ();
        stack = new Gtk.Stack ();
        stack.add (filter_button);
        stack.add (spinner);
        stack.visible_child = filter_button;

        var tool_box = new Gtk.Box (HORIZONTAL, 3);
        tool_box.add (search_entry);
        tool_box.add (stack);
        add (tool_box);
        add (store);
        set_up_css ();
        show_all ();

        realize.connect (() => {
            store.set_filter_func (filter_func, false);
            search_entry.changed.connect (schedule_refilter);
        });
    }

    private void add_filter_menuitem (Menu menu, SymbolType filter) {
        var filter_action = new SimpleAction.stateful (
            ACTION_TOGGLE + ((uint)filter).to_string (),
            null,
            new Variant.boolean (true)
        );

        checks[filter] = filter_action;
        filter_action.activate.connect (action_toggle_filter);
        symbol_action_group.add_action (filter_action);

        var filter_item = new MenuItem (
            filter.to_string (),
            ACTION_PREFIX + filter_action.get_name ()
        );

        menu.append_item (filter_item);
    }

    protected bool filter_func (Object item) {
        if (!(item is SymbolItem)) {
            return true;
        }

        var symbol_type = ((SymbolItem)item).symbol_type;
        if (symbol_type == SymbolType.NAMESPACE) {
            return true;
        }

        if (checks[symbol_type] == null) {
            symbol_type = SymbolType.OTHER;
        }

        var filter_action = checks[symbol_type];

        if (!filter_action.get_state ().get_boolean ()) {
            return false;
        }

        // Do not exclude text search misses on Item with children as may
        // hide hits on its children
        if (item is Code.Widgets.SourceList.ExpandableItem) {
            var expandable = (Code.Widgets.SourceList.ExpandableItem)item;
            if (expandable.n_children > 0) {
                return true;
            }

            return ((SymbolItem)item).name.contains (search_entry.text);
        }

        return true;
    }

    uint refilter_timeout_id = 0;
    bool delay_refilter = false;
    protected void schedule_refilter () {
        // Ensure a refilter happens at least 500mS later if not already
        // delayed.
        if (refilter_timeout_id > 0) {
            delay_refilter = true;
            return;
        }

        refilter_timeout_id = Timeout.add (500, () => {
            if (delay_refilter) {
                delay_refilter = false;
                return Source.CONTINUE;
            } else {
                refilter_timeout_id = 0;
                store.refilter ();
                // Ensure new visible items shown when filter removed
                store.root.expand_all (true, true);
                return Source.REMOVE;
            }
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
        get_style_context ().add_class ("symbol-outline");
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

        var define = ".symbol-outline {background-color: %s;}".printf (color);

        try {
            source_list_style_provider.load_from_data (define);
        } catch (Error e) {
            critical ("Unable to sourcelist styling, going back to classic styling");
        }
    }

    private void action_select_filters (SimpleAction action, Variant? param) {
        foreach (var filter_action in checks.values) {
           filter_action.set_state (new Variant ("b", param.get_boolean ()));
        }
        schedule_refilter ();
        // Keep menu open
        Idle.add (() => {
            filter_button.set_active (true);
            return Source.REMOVE;
        });
    }

    private void action_toggle_filter (SimpleAction action, Variant? param) {
        var state = action.get_state ().get_boolean ();
        action.set_state (new Variant ("b", !state));
        schedule_refilter ();
    }
}
