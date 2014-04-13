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
    
    string lang = "en_US"; // FIXME

    Scratch.Services.Interface plugins;
    public Object object {owned get; construct;}
    
    public void update_state () {
    }

    public void activate () {
        plugins = (Scratch.Services.Interface) object;   
        plugins.hook_document.connect ((d) => {
            var view = d.source_view;
            // Create GtkSpell object
#if SPELLLEGACY
            if (Gtk.Spell.get_from_text_view (view) == null) {
                Gtk.Spell? spell = null;
                try {
                    spell = new Gtk.Spell.attach (view, lang);
#else
            if (GtkSpell.Checker.get_from_text_view (view) == null) {
                GtkSpell.Checker spell = new GtkSpell.Checker ();
                try {
                    spell.set_language (lang);
                    spell.attach (view);
#endif
                } catch (Error e) {
                    warning (e.message);
                }
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
            }
        });
    }

    public void deactivate () {
    }

}

[ModuleInit]
public void peas_register_types (GLib.TypeModule module) {
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type (typeof(Peas.Activatable),
                                      typeof(Scratch.Plugins.Spell));
}