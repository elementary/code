/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2017–2023 elementary, Inc. <https://elementary.io>
 *                         2013 Mario Guerriero <mefrio.g@gmail.com>
 */

public class Scratch.HeaderBar : Hdy.HeaderBar {
    // Plugins segfault without full access
    public Code.FormatBar format_bar;
    public GLib.Menu share_menu;
    public Gtk.MenuButton share_menu_button;

    public Gtk.Button templates_button { get; private set; }
    public Gtk.ToggleButton find_button { get; private set; }
    public Gtk.ToggleButton outline_button { get; private set; }
    public Gtk.ToggleButton sidebar_button { get; private set; }
    public Gtk.ToggleButton terminal_button { get; private set; }

    private const string STYLE_SCHEME_HIGH_CONTRAST = "elementary-highcontrast-light";
    private const string STYLE_SCHEME_LIGHT = "elementary-light";
    private const string STYLE_SCHEME_DARK = "elementary-dark";

    public HeaderBar () {
        Object (
            has_subtitle: false,
            show_close_button: true
        );
    }

    construct {
        var app_instance = (Gtk.Application) GLib.Application.get_default ();

        var open_button = new Gtk.Button.from_icon_name ("document-open", Gtk.IconSize.LARGE_TOOLBAR) {
            action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_OPEN
        };
        open_button.tooltip_markup = Granite.markup_accel_tooltip (
            app_instance.get_accels_for_action (open_button.action_name),
            _("Open a file")
        );

        templates_button = new Gtk.Button.from_icon_name ("text-x-generic-template", Gtk.IconSize.LARGE_TOOLBAR) {
            action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_TEMPLATES
        };
        templates_button.tooltip_text = _("Project templates");

        var save_button = new Gtk.Button.from_icon_name ("document-save", Gtk.IconSize.LARGE_TOOLBAR) {
            action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_SAVE
        };
        save_button.tooltip_markup = Granite.markup_accel_tooltip (
            app_instance.get_accels_for_action (save_button.action_name),
            _("Save this file")
        );

        var save_as_button = new Gtk.Button.from_icon_name ("document-save-as", Gtk.IconSize.LARGE_TOOLBAR) {
            action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_SAVE_AS
        };
        save_as_button.tooltip_markup = Granite.markup_accel_tooltip (
            app_instance.get_accels_for_action (save_as_button.action_name),
            _("Save this file with a different name")
        );

        var revert_button = new Gtk.Button.from_icon_name ("document-revert", Gtk.IconSize.LARGE_TOOLBAR) {
            action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_REVERT
        };
        revert_button.tooltip_markup = Granite.markup_accel_tooltip (
            app_instance.get_accels_for_action (revert_button.action_name),
            _("Restore this file")
        );

        share_menu = new GLib.Menu ();

        share_menu_button = new Gtk.MenuButton () {
            image = new Gtk.Image.from_icon_name ("document-export", Gtk.IconSize.LARGE_TOOLBAR),
            no_show_all = true,
            menu_model = share_menu,
            tooltip_text = _("Share")
        };

        var zoom_out_button = new Gtk.Button.from_icon_name ("zoom-out-symbolic", Gtk.IconSize.MENU) {
            action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_ZOOM_OUT
        };
        zoom_out_button.tooltip_markup = Granite.markup_accel_tooltip (
            app_instance.get_accels_for_action (zoom_out_button.action_name),
            _("Zoom Out")
        );

        var zoom_default_button = new Gtk.Button.with_label ("100%") {
            action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_ZOOM_DEFAULT
        };
        zoom_default_button.tooltip_markup = Granite.markup_accel_tooltip (
            app_instance.get_accels_for_action (zoom_default_button.action_name),
            _("Zoom 1:1")
        );

        var zoom_in_button = new Gtk.Button.from_icon_name ("zoom-in-symbolic", Gtk.IconSize.MENU) {
            action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_ZOOM_IN
        };
        zoom_in_button.tooltip_markup = Granite.markup_accel_tooltip (
            app_instance.get_accels_for_action (zoom_in_button.action_name),
            _("Zoom In")
        );

        var font_size_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) {
            homogeneous = true,
            hexpand = true,
            margin_top = 12,
            margin_end = 12,
            margin_bottom = 6,
            margin_start = 12
        };
        font_size_box.get_style_context ().add_class (Gtk.STYLE_CLASS_LINKED);
        font_size_box.add (zoom_out_button);
        font_size_box.add (zoom_default_button);
        font_size_box.add (zoom_in_button);

        find_button = new Gtk.ToggleButton () {
            action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_TOGGLE_SHOW_FIND,
            image = new Gtk.Image.from_icon_name ("edit-find-on-page-symbolic", Gtk.IconSize.MENU)
        };
        find_button.tooltip_markup = Granite.markup_accel_tooltip (
            app_instance.get_accels_for_action (MainWindow.ACTION_PREFIX + MainWindow.ACTION_FIND + "::"),
            _("Find on Page…")
        );

        var search_button = new Gtk.Button.from_icon_name ("edit-find-symbolic", Gtk.IconSize.MENU) {
            action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_FIND_GLOBAL,
            action_target = new Variant.string ("")
        };
        search_button.tooltip_markup = Granite.markup_accel_tooltip (
            app_instance.get_accels_for_action (search_button.action_name + "::"),
            _("Find in Project…")
        );

        var find_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) {
            hexpand = true,
            homogeneous = true,
            margin_end = 12,
            margin_bottom = 12,
            margin_start = 12
        };
        find_box.get_style_context ().add_class (Gtk.STYLE_CLASS_LINKED);
        find_box.add (find_button);
        find_box.add (search_button);

        var follow_system_switchmodelbutton = new Granite.SwitchModelButton (_("Follow System Style")) {
            margin_top = 3
        };

        // Intentionally never attached so we can have a non-selected state
        var color_button_none = new Gtk.RadioButton (null);

        var color_button_white = new Gtk.RadioButton.from_widget (color_button_none) {
            halign = Gtk.Align.CENTER
        };
        style_color_button (color_button_white, STYLE_SCHEME_HIGH_CONTRAST);

        var color_button_light = new Gtk.RadioButton.from_widget (color_button_none) {
            halign = Gtk.Align.CENTER
        };
        style_color_button (color_button_light, STYLE_SCHEME_LIGHT);

        var color_button_dark = new Gtk.RadioButton.from_widget (color_button_none) {
            halign = Gtk.Align.CENTER
        };
        style_color_button (color_button_dark, STYLE_SCHEME_DARK);

        var color_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 3) {
            homogeneous = true,
            margin_top = 6,
            margin_bottom = 6
        };
        color_box.add (color_button_white);
        color_box.add (color_button_light);
        color_box.add (color_button_dark);

        var color_revealer = new Gtk.Revealer ();
        color_revealer.add (color_box);

        var menu_separator = new Gtk.Separator (Gtk.Orientation.HORIZONTAL) {
            margin_bottom = 3,
            margin_top = 3
        };

        sidebar_button = new Gtk.ToggleButton () {
            action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_TOGGLE_SIDEBAR,
            image = new Gtk.Image.from_icon_name ("panel-left-symbolic", Gtk.IconSize.MENU)
        };

        terminal_button = new Gtk.ToggleButton () {
            action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_TOGGLE_TERMINAL,
            image = new Gtk.Image.from_icon_name ("panel-bottom-symbolic", Gtk.IconSize.MENU)
        };
        terminal_button.tooltip_markup = Granite.markup_accel_tooltip (
            app_instance.get_accels_for_action (terminal_button.action_name),
            _("Show Terminal")
        );

        outline_button = new Gtk.ToggleButton () {
            action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_TOGGLE_OUTLINE,
            image = new Gtk.Image.from_icon_name ("panel-right-symbolic", Gtk.IconSize.MENU)
        };

        var panels_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) {
            homogeneous = true,
            margin_top = 6,
            margin_end = 12,
            margin_bottom = 6,
            margin_start = 12
        };
        panels_box.get_style_context ().add_class (Gtk.STYLE_CLASS_LINKED);
        panels_box.add (sidebar_button);
        panels_box.add (terminal_button);
        panels_box.add (outline_button);

        var preferences_menuitem = new Gtk.ModelButton () {
            action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_PREFERENCES,
            text = _("Preferences")
        };

        var menu_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) {
            margin_bottom = 3
        };
        menu_box.add (font_size_box);
        menu_box.add (find_box);
        menu_box.add (new Gtk.Separator (Gtk.Orientation.HORIZONTAL));
        menu_box.add (follow_system_switchmodelbutton);
        menu_box.add (color_revealer);
        menu_box.add (panels_box);
        menu_box.add (menu_separator);
        menu_box.add (preferences_menuitem);
        menu_box.show_all ();

        var menu = new Gtk.Popover (null);
        menu.add (menu_box);

        var app_menu = new Gtk.MenuButton () {
            image = new Gtk.Image.from_icon_name ("open-menu", Gtk.IconSize.LARGE_TOOLBAR),
            popover = menu,
            tooltip_text = _("Menu")
        };

        format_bar = new Code.FormatBar () {
            no_show_all = true,
            valign = Gtk.Align.CENTER
        };
        set_custom_title (format_bar);

        pack_start (open_button);
        pack_start (templates_button);
        pack_start (save_button);
        pack_start (save_as_button);
        pack_start (revert_button);
        pack_end (app_menu);
        pack_end (share_menu_button);

        share_menu.items_changed.connect (on_share_menu_changed);

        realize.connect (() => {
            save_button.visible = !Scratch.settings.get_boolean ("autosave");
        });

        Scratch.settings.changed["autosave"].connect (() => {
            save_button.visible = !Scratch.settings.get_boolean ("autosave");
        });

        Scratch.settings.changed["font"].connect (() => {
            var active_window = (MainWindow) app_instance.active_window;
            if (active_window != null) {
                zoom_default_button.label = "%.0f%%".printf (active_window.get_current_font_size () * 10);
            }
        });

        follow_system_switchmodelbutton.bind_property (
            "active",
            color_revealer,
            "reveal-child",
            GLib.BindingFlags.SYNC_CREATE | BindingFlags.INVERT_BOOLEAN
        );

        Scratch.settings.bind (
            "follow-system-style",
            follow_system_switchmodelbutton,
            "active",
            SettingsBindFlags.DEFAULT
        );

        var gtk_settings = Gtk.Settings.get_default ();

        switch (Scratch.settings.get_string ("style-scheme")) {
            case STYLE_SCHEME_HIGH_CONTRAST:
                color_button_white.active = true;
                break;
            case STYLE_SCHEME_LIGHT:
                color_button_light.active = true;
                break;
            case STYLE_SCHEME_DARK:
                color_button_dark.active = true;
                break;
            default:
                color_button_none.active = true;
        }

        color_button_dark.clicked.connect (() => {
            Scratch.settings.set_boolean ("prefer-dark-style", true);
            Scratch.settings.set_string ("style-scheme", STYLE_SCHEME_DARK);
            gtk_settings.gtk_application_prefer_dark_theme = true;
        });

        color_button_light.clicked.connect (() => {
            Scratch.settings.set_boolean ("prefer-dark-style", false);
            Scratch.settings.set_string ("style-scheme", STYLE_SCHEME_LIGHT);
            gtk_settings.gtk_application_prefer_dark_theme = false;
        });

        color_button_white.clicked.connect (() => {
            Scratch.settings.set_boolean ("prefer-dark-style", false);
            Scratch.settings.set_string ("style-scheme", STYLE_SCHEME_HIGH_CONTRAST);
            gtk_settings.gtk_application_prefer_dark_theme = false;
        });
    }

    private void style_color_button (Gtk.ToggleButton color_button, string style_id) {
        var background = "";
        var foreground = "";

        Gtk.SourceStyleScheme? scheme = null;
        var sssm = Gtk.SourceStyleSchemeManager.get_default ();
        if (style_id in sssm.scheme_ids) {
            scheme = sssm.get_scheme (style_id);
            // We currently ship and hard-code the style schemes so can assume the "text" key
            // is present but if in future we permit the user to specify their own default
            // schemes(e.g. through separate settings keys) then this may not be the case.
            // so do a certain amount of validity checking
            var text_style = scheme.get_style ("text");
            var background_pattern_style = scheme.get_style ("background-pattern");
            if (text_style != null) {
                if (text_style.background_set) {
                    background = text_style.background;
                }

                if (text_style.foreground_set) {
                    foreground = text_style.foreground;
                }
            }

            if (background_pattern_style != null) {
                if (background == "" && background_pattern_style.background_set) {
                    background = background_pattern_style.background;
                }

                if (foreground == "" && background_pattern_style.foreground_set) {
                    foreground = background_pattern_style.foreground;
                }
            }

            //Fallback to white and grey  if necessary
            if (background == "" || background.contains ("rgba")) {
                background ="";
            }

            if (foreground == "" || foreground.contains ("rgba")) {
                foreground ="";
            }
        }

        if (background != "" && foreground != "") {
            var style_css = """
            .color-button radio {
                background-color: %s;
                color: %s;
                padding: 10px;
                -gtk-icon-shadow: none;
            }
        """.printf (background, foreground);

            var css_provider = new Gtk.CssProvider ();

            try {
                css_provider.load_from_data (style_css);
            } catch (Error e) {
                critical ("Unable to style color button: %s", e.message);
            }

            unowned var style_context = color_button.get_style_context ();
            style_context.add_class (Granite.STYLE_CLASS_COLOR_BUTTON);
            style_context.add_provider (css_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
            color_button.tooltip_text = scheme.name;
        } else if (scheme != null || background == "" || foreground == "") {
            //Fallback to standard radio buttons (shouldnt happen)
            switch (style_id) {
                case STYLE_SCHEME_LIGHT:
                    color_button.label = _("Light");
                    break;
                case STYLE_SCHEME_DARK:
                    color_button.label = _("Dark");
                    break;
                case STYLE_SCHEME_HIGH_CONTRAST:
                    color_button.label = _("Contrast");
                    break;
                default:
                    assert_not_reached ();
            }
        }
    }

    private void on_share_menu_changed () {
        if (share_menu.get_n_items () > 0) {
            share_menu_button.no_show_all = false;
            share_menu_button.visible = true;
            share_menu_button.show_all ();
        } else {
            share_menu_button.no_show_all = true;
            share_menu_button.visible = false;
            share_menu_button.hide ();
        }
    }

    public void document_available (bool has_document) {
        if (has_document) {
            format_bar.no_show_all = false;
            format_bar.show_all ();
        } else {
            format_bar.no_show_all = true;
            format_bar.hide ();
        }
    }

    public void set_document_focus (Scratch.Services.Document doc) {
        format_bar.set_document (doc);
    }
}
