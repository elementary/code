// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/***
  BEGIN LICENSE
	
  Copyright (C) 2013 Mario Guerriero <mario@elementaryos.org>
  This program is free software: you can redistribute it and/or modify it	
  under the terms of the GNU Lesser General Public License version 3, as published	
  by the Free Software Foundation.
	
  This program is distributed in the hope that it will be useful, but	
  WITHOUT ANY WARRANTY; without even the implied warranties of	
  MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR	
  PURPOSE.  See the GNU General Public License for more details.
	
  You should have received a copy of the GNU General Public License along	
  with this program.  If not, see <http://www.gnu.org/licenses/>	
  
  END LICENSE	
***/

public class Scratch.Templates.Granite : Scratch.Template {
    Gtk.Entry project_name;
    Gtk.FileChooserButton file_chooser_button;

    public override Gtk.Widget get_creation_box () {
        /*var grid = new Gtk.Grid ();
        project_name = new Gtk.Entry ();
        project_name.placeholder_text = "Project Name";
        project_name.hexpand = true;
        var title = new Gtk.Label ("Granite Application");
        title.hexpand = true;
        title.set_markup ("<b>Granite Application</b>");
        grid.attach (title, 0, 0, 2, 1);
        grid.attach (project_name, 0, 1, 2, 1);
        var destination = new Gtk.Label ("/home/user/");
        destination.sensitive = false;
        file_chooser_button = new Gtk.FileChooserButton ("Create a project", Gtk.FileChooserAction.SELECT_FOLDER);
        grid.attach (destination, 0, 2, 1, 1);
        grid.attach (file_chooser_button, 1, 2, 1, 1);

        var create_button = new Gtk.Button.with_label ("Create!");
        grid.attach (create_button, 1, 3, 1, 1);
        create_button.clicked.connect (on_create_clicked);
        return grid;*/
        var entry = new Gtk.Entry ();
        entry.text = "Yeah!";
        return entry;
    }

    void on_create_clicked () {
        var variables = new Gee.HashMap<string, string> ();
        var low = project_name.text.down ().replace(" ", "-");
        variables["LOWER_CASE_NAME"] = low;
        variables["LOWER_CASE_NAME2"] = low;
        variables["NAME"] = project_name.text;
        variables["DESCRIPTION"] = project_name.text;
        variables["AUTHORS"] = "elementary Developers";
        variables["CATEGORIES"] = "development";
        configure_template ("/home/mario/elementary/scratch/plugins/elementary-templates" + "/templates/granite/", file_chooser_button.get_filename () + "/" + low + "/", variables);
    }
}

public class Scratch.Plugins.Templates : Peas.ExtensionBase,  Peas.Activatable {

    [NoAcessorMethod]
    public Object object { owned get; construct; }
    Scratch.Services.Interface plugins;
    
    public void update_state () {
    }

    public void activate () {
        plugins = (Scratch.Services.Interface) object;        
        
        plugins.template_manager.register_template ("text-editor", "Granite Application", "Granite application template",typeof(Scratch.Templates.Granite));
    }
    
    public void deactivate () {

    }
    
}

[ModuleInit]
public void peas_register_types (GLib.TypeModule module) {
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type (typeof (Peas.Activatable),
                                     typeof (Scratch.Plugins.Templates));
}