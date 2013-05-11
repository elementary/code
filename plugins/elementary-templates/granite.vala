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
    Gtk.Grid grid;
    Gtk.Entry project_name;
    Gtk.FileChooserButton file_chooser_button;

    public override Gtk.Widget get_creation_box () {
        grid = new Gtk.Grid ();
        grid.margin = 5;
        
        project_name = new Gtk.Entry ();
        project_name.placeholder_text = "Project Name";
        project_name.hexpand = true;
        
        grid.attach (project_name, 0, 0, 2, 1);
        
        var destination = new Gtk.Label (GLib.Environment.get_home_dir ());
        destination.sensitive = false;
        file_chooser_button = new Gtk.FileChooserButton ("Create a project", Gtk.FileChooserAction.SELECT_FOLDER);
        
        grid.attach (destination, 0, 2, 1, 1);
        grid.attach (file_chooser_button, 1, 2, 1, 1);

        var create_button = new Gtk.Button.with_label ("Create!");
        grid.attach (create_button, 1, 3, 1, 1);
        create_button.clicked.connect (on_create_clicked);
        return grid;
    }

    void on_create_clicked () {
        var variables = new Gee.HashMap<string, string> ();
        var low = project_name.text.down ().replace(" ", "-");
        variables.set ("LOWER_CASE_NAME", low);
        variables.set ("LOWER_CASE_NAME2", low);
        variables.set ("NAME", project_name.text);
        variables.set ("DESCRIPTION", project_name.text);
        variables.set ("AUTHORS", "elementary Developers");
        variables.set ("CATEGORIES", "development");
        string path = Constants.PLUGINDIR + "elementary-templates";
        configure_template (path + "/granite/", file_chooser_button.get_filename () + "/" + low + "/", variables);
        grid.get_parent ().destroy ();
    }
}