/*
 * SPDX-License-Identifier: GPL-2.0-or-later
 * SPDX-FileCopyrightText: 2011-2024 elementary, Inc. (https://elementary.io)
 *
 * Authored by: Giulio Collura <random.cpp@gmail.com>
 *              Mario Guerriero <mario@elementaryos.org>
 *              Fabio Zaramella <ffabio.96.x@gmail.com>
 */

public class Scratch.Dialogs.Preferences : Granite.Dialog {
    public Services.PluginsManager plugins { get; construct; }

    public Preferences (Gtk.Window? parent, Services.PluginsManager plugins) {
        Object (
            title: _("Preferences"),
            transient_for: parent,
            plugins: plugins
        );
    }

    construct {
        var general_box = new Gtk.Box (VERTICAL, 12);
        general_box.add (new Granite.HeaderLabel (_("General")));
        general_box.add (new SettingSwitch (_("Save files when changed"), "autosave"));
        general_box.add (new SettingSwitch (_("Strip trailing whitespace on save"), "strip-trailing-on-save"));
        general_box.add (new SettingSwitch (
            _("Smart cut/copy lines"),
            "smart-cut-copy",
            _("Cutting or copying without an active selection will cut or copy the entire current line")
        ));

        var indent_width = new Gtk.SpinButton.with_range (1, 24, 1);
        Scratch.settings.bind ("indent-width", indent_width, "value", DEFAULT);

        var indent_width_label = new Gtk.Label (_("Indentation width")) {
            halign = START,
            hexpand = true,
            mnemonic_widget = indent_width
        };

        var indent_width_box = new Gtk.Box (HORIZONTAL, 12);
        indent_width_box.add (indent_width_label);
        indent_width_box.add (indent_width);

        var indentation_box = new Gtk.Box (VERTICAL, 12);
        indentation_box.add (new Granite.HeaderLabel (_("Indentation")));
        indentation_box.add (new SettingSwitch (_("Automatic indentation"), "auto-indent"));
        indentation_box.add (new SettingSwitch (_("Insert spaces instead of tabs"), "spaces-instead-of-tabs"));
        indentation_box.add (indent_width_box);

        var build_dir_entry = new Gtk.Entry () {
            hexpand = true,
            placeholder_text = "."
        };
        Scratch.settings.bind ("default-build-directory", build_dir_entry, "text", DEFAULT);

        var buid_dir_label = new Gtk.Label (_("Default build directory")) {
            halign = START,
            mnemonic_widget = build_dir_entry
        };

        var build_dir_box = new Gtk.Box (HORIZONTAL, 12);
        build_dir_box.add (buid_dir_label);
        build_dir_box.add (build_dir_entry);

        var projects_box = new Gtk.Box (VERTICAL, 12);
        projects_box.add (new Granite.HeaderLabel (_("Projects")));
        projects_box.add (build_dir_box);

        var behavior_box = new Gtk.Box (VERTICAL, 24);
        behavior_box.add (general_box);
        behavior_box.add (indentation_box);
        behavior_box.add (projects_box);

        var drawspaces_combobox = new Gtk.ComboBoxText () {
            hexpand = true
        };
        drawspaces_combobox.append_text (_("None"));
        drawspaces_combobox.append_text (_("Current Line"));
        drawspaces_combobox.append_text (_("All"));
        drawspaces_combobox.active = Scratch.settings.get_enum ("draw-spaces").clamp (0, 2);
        drawspaces_combobox.changed.connect (() => {
            switch (drawspaces_combobox.active) {
                case 0:
                    Scratch.settings.set_enum ("draw-spaces", (int)ScratchDrawSpacesState.NEVER);
                    break;
                case 1:
                    Scratch.settings.set_enum ("draw-spaces", (int)ScratchDrawSpacesState.CURRENT);
                    break;
                case 2:
                    Scratch.settings.set_enum ("draw-spaces", (int)ScratchDrawSpacesState.ALWAYS);
                    break;
            }
        });

        var draw_spaces_label = new Gtk.Label (_("Whitespace visible when not selected")) {
            halign = START,
            hexpand = true,
            mnemonic_widget = drawspaces_combobox
        };

        var draw_spaces_box = new Gtk.Box (HORIZONTAL, 12);
        draw_spaces_box.add (draw_spaces_label);
        draw_spaces_box.add (drawspaces_combobox);

        var right_margin_position = new Gtk.SpinButton.with_range (1, 250, 1);
        Scratch.settings.bind ("right-margin-position", right_margin_position, "value", DEFAULT);
        Scratch.settings.bind ("show-right-margin", right_margin_position, "sensitive", DEFAULT);

        var editor_box = new Gtk.Box (VERTICAL, 12);
        editor_box.add (new Granite.HeaderLabel (_("Editor")));
        editor_box.add (new SettingSwitch (_("Highlight matching brackets"), "highlight-matching-brackets"));
        editor_box.add (draw_spaces_box);
        editor_box.add (new SettingSwitch (_("Mini Map"), "show-mini-map"));
        editor_box.add (new SettingSwitch (_("Wrap lines"), "line-wrap"));
        editor_box.add (new SettingSwitch (_("Line width guide"), "show-right-margin"));
        editor_box.add (right_margin_position);

        var select_font = new Gtk.FontButton ();
        Scratch.settings.bind ("font", select_font, "font-name", DEFAULT);
        Scratch.settings.bind ("use-system-font", select_font, "sensitive", INVERT_BOOLEAN);

        var font_box = new Gtk.Box (VERTICAL, 12);
        font_box.add (new Granite.HeaderLabel (_("Font")));
        font_box.add (new SettingSwitch (_("Use system font"), "use-system-font"));
        font_box.add (select_font);

        var interface_box = new Gtk.Box (VERTICAL, 24);
        interface_box.add (editor_box);
        interface_box.add (font_box);

        var stack = new Gtk.Stack () {
            margin = 12,
            vhomogeneous = true
        };
        stack.add_titled (behavior_box, "behavior", _("Behavior"));
        stack.add_titled (interface_box, "interface", _("Interface"));

        var stackswitcher = new Gtk.StackSwitcher ();
        stackswitcher.set_stack (stack);
        stackswitcher.halign = Gtk.Align.CENTER;

        var main_box = new Gtk.Box (VERTICAL, 12);
        main_box.add (stackswitcher);
        main_box.add (stack);

        plugins.hook_preferences_dialog (this); // Unused?

        if (plugins.get_n_plugins () > 0) {
            var pbox = plugins.get_view ();
            pbox.vexpand = true;

            stack.add_titled (pbox, "extensions", _("Extensions"));
        }

        border_width = 0;
        get_content_area ().add (main_box);

        var close_button = (Gtk.Button) add_button (_("Close"), Gtk.ResponseType.CLOSE);
        close_button.clicked.connect (() => {
            destroy ();
        });

        //Ensure appearance correct after using libpeas-2
        realize.connect (() => {
            stack.set_visible_child_name ("behavior");
        });
    }

    private class SettingSwitch : Gtk.Grid {
        public string label { get; construct; }
        public string settings_key { get; construct; }
        public string description { get; construct; }

        public SettingSwitch (string label, string settings_key, string description = "") {
            Object (
                description: description,
                label: label,
                settings_key: settings_key
            );
        }

        construct {
            var switch_widget = new Gtk.Switch () {
                valign = CENTER
            };

            var label_widget = new Gtk.Label (label) {
                halign = START,
                hexpand = true,
                mnemonic_widget = switch_widget
            };

            column_spacing = 12;
            attach (label_widget, 0, 0);
            attach (switch_widget, 1, 0, 1, 2);

            if (description != "") {
                var description_label = new Gtk.Label (description) {
                    halign = START,
                    wrap = true,
                    xalign = 0
                };
                description_label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);
                description_label.get_style_context ().add_class (Granite.STYLE_CLASS_SMALL_LABEL);

                attach (description_label, 0, 1);

                switch_widget.get_accessible ().accessible_description = description;
            }

            Scratch.settings.bind (settings_key, switch_widget, "active", DEFAULT);
        }
    }
}
