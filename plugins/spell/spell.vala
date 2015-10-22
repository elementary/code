/*
 * Copyright (C) 2011-2012 Mario Guerriero <mefrio.g@gmail.com> This program
 * is free software: you can redistribute it and/or modify it under the
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

using Gtk;

public const string NAME = N_("Spell Checker");
public const string DESCRIPTION = N_("Checks the spelling of your documents");

public class Scratch.Plugins.Spell: Peas.ExtensionBase, Peas.Activatable {

    Scratch.Services.Interface plugins;

    Scratch.Plugins.SpellSettings.Settings settings;
    
    MainWindow window = null;

    private string lang_dict;

#if SPELLLEGACY
    Gtk.Spell? spell = null;
#else
    GtkSpell.Checker spell = null;
#endif

    public Object object {owned get; construct;}
    
    public void update_state () {
    }

    public void activate () {

        this.settings = new Scratch.Plugins.SpellSettings.Settings ();

        //Restore the last dictionary used.
        this.lang_dict = settings.language;

        settings.changed.connect (settings_changed);

        plugins = (Scratch.Services.Interface) object;
        plugins.hook_document.connect ((d) => {
            var view = d.source_view;
            // Create GtkSpell object
#if SPELLLEGACY
            if (Gtk.Spell.get_from_text_view (view) == null) {
                spell = null;
                try {
                    spell = new Gtk.Spell.attach (view, lang_dict);
                } catch (Error e) {
                    warning (e.message);
                }
#else
            if (GtkSpell.Checker.get_from_text_view (view) == null) {
                spell = new GtkSpell.Checker ();
                try {
                    bool exist = false;
                    var language_list = spell.get_language_list ();
                    foreach (var element in language_list) {
                        if (strcmp (lang_dict, element) == 0) {
                            exist = true;
                            spell.set_language (lang_dict);
                            break;
                        }
                    }

                    if (language_list.length () == 0) {
                        var dialog = new Gtk.MessageDialog (null, Gtk.DialogFlags.MODAL,
                            Gtk.MessageType.WARNING, Gtk.ButtonsType.OK, _("There are not suitable Dictionaries in your system please install one."));
                        dialog.show ();
                        dialog.response.connect ((response_id) => {
                            dialog.destroy();
                        });
                        spell.set_language (null);
                    } else if (!exist) {
                        spell.set_language (language_list.first ().data);
                    }

                    spell.attach (view);
                } catch (Error e) {
                    warning (e.message);
                }
#endif
                // Deactivate Spell checker when it is no longer needed
                plugins.manager.extension_removed.connect ((info) => {
                    if (info.get_module_name () == "spell")
                        spell.detach ();
                });
                // Deactivate Spell checker when we are editing a code file
                var lang = d.source_view.buffer.language;
                if (lang != null)
                    spell.detach ();
 
                // Detect language changed event
                view.language_changed.connect ((lang) => {
                    if (lang != null)
                        spell.detach ();
                });

                // Detect changes in language dictionaries in spell instance
                spell.language_changed.connect ((lang) => {
                    this.lang_dict = lang;
                });

            }
        });

        plugins.hook_window.connect ((w) => {
            if (window != null)
                return;

            window = w;
            window.destroy.connect (save_settings);
        });

    }

    public void settings_changed () {
        if (spell != null) {
            try {
                spell.set_language (settings.language);
                this.lang_dict = settings.language;
            } catch (Error e) {
                    warning (e.message);
            }
        }
    }

    public void save_settings () {
        //Save the last dictionary used.
        settings.language = this.lang_dict;
    }

    public void deactivate () {
        save_settings();
        window.destroy.disconnect (save_settings);
    }

}

[ModuleInit]
public void peas_register_types (GLib.TypeModule module) {
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type (typeof(Peas.Activatable),
                                      typeof(Scratch.Plugins.Spell));
}
