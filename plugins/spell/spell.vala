/* Copyright (C) 2024 elementary, Inc. <https://elementary.io>
 *               2011-2012 Mario Guerriero <mefrio.g@gmail.com> 
 * 
 * This program is free software: you can redistribute it and/or modify it under the
 * terms of the GNU Lesser General Public License version 3, as published by
 * the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranties of
 * MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
 * PURPOSE.  See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program.  If not, see <http://www.gnu.org/licenses/>
 */

public class Scratch.Plugins.Spell: Scratch.Plugins.PluginBase {
    private GLib.Settings settings;
    MainWindow window = null;
    private string lang_dict;

#if SPELLLEGACY
    Gtk.Spell? spell = null;
#else
    GtkSpell.Checker spell = null;
#endif

    public Spell (PluginInfo info, Interface iface) {
        base (info, iface);
    }

    ulong window_hook_handler = 0;
    ulong doc_hook_handler = 0;
    protected override void activate_internal () {
        settings = new GLib.Settings (Constants.PROJECT_NAME + ".plugins.spell");

        // Restore the last dictionary used.
        lang_dict = settings.get_string ("language");

        settings.changed.connect (settings_changed);

        window_hook_handler = iface.hook_window.connect ((w) => {
            if (window != null) {
                return;
            }

            window = w;
            window.destroy.connect (save_settings);
        });

        doc_hook_handler = iface.hook_document.connect ((d) => {
            var view = d.source_view;

            // Create spell object
#if SPELLLEGACY
            if (Gtk.Spell.get_from_text_view (view) == null) {
                try {
                    spell = new Gtk.Spell.attach (view, lang_dict);
                } catch (Error e) {
                    warning (e.message);
                }
#else
            if (GtkSpell.Checker.get_from_text_view (view) == null) {
                spell = new GtkSpell.Checker ();
                try {
                    bool exist_language = false;
                    var language_list = GtkSpell.Checker.get_language_list ();
                    foreach (var element in language_list) {
                        if (lang_dict == element) {
                            exist_language = true;
                            spell.set_language (lang_dict);
                            break;
                        }
                    }

                    if (language_list.length () == 0) {
                        var dialog = new Granite.MessageDialog (
                            _("No Suitable Dictionaries Were Found"),
                            _("Please install at least one [aspell] dictionary."),
                            new ThemedIcon ("dialog-warning"),
                            Gtk.ButtonsType.CLOSE
                        );
                        dialog.run ();
                        dialog.destroy ();

                        // This fallback to the LC used but might fail.
                        spell.set_language (null);

                    } else if (!exist_language) {
                        this.lang_dict = language_list.first ().data;
                        spell.set_language (lang_dict);
                    }

                    spell.attach (view);
                } catch (Error e) {
                    warning (e.message);
                }
#endif
                // Deactivate Spell checker when it is no longer needed
                iface.manager.extension_removed.connect ((info) => {
                    if (info.module_name == "spell")
                        spell.detach ();
                });

                // Deactivate Spell checker when we are editing a code file
                var source_buffer = (Gtk.SourceBuffer) d.source_view.buffer;
                var lang = source_buffer.language;
                if (lang != null && lang.id != "markdown") {
                    spell.detach ();
                }

                // Detect language changed event
                view.notify["language"].connect (() => language_changed_spell (view));

                // Detect changes in language dictionaries in spell instance
                spell.language_changed.connect ((lang_dict) => {
                    this.lang_dict = lang_dict;
                });
            }
        });
    }

    protected override void deactivate_internal () {
        save_settings ();
        window.destroy.disconnect (save_settings);
        this.disconnect (window_hook_handler);
        this.disconnect (doc_hook_handler);
    }

    private void language_changed_spell (Scratch.Widgets.SourceView view) {
        if (view.language != null)
            spell.detach ();
    }

    public void settings_changed () {
        if (spell != null) {
            try {
                spell.set_language (settings.get_string ("language"));
                lang_dict = settings.get_string ("language");
            } catch (Error e) {
                warning (e.message);
            }
        }
    }

    public void save_settings () {
        // Save the last dictionary used.
        settings.set_string ("language", lang_dict);
    }

}

public Scratch.Plugins.PluginBase module_init (
    Scratch.Plugins.PluginInfo info,
    Scratch.Plugins.Interface iface
) {
    return new Scratch.Plugins.Spell (info, iface);
}
