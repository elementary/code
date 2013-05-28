// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/***
  BEGIN LICENSE

  Copyright (C) 2013 Julien Spautz <spautz.julien@gmail.com>
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

namespace ProjectManager {

    /**
     * Class for interacting with gsettings.
     */
    internal class Settings : GLib.Object {

        private const string SCHEMA = "org.pantheon.scratch.plugins.project-manager";
        private GLib.Settings settings;
        private GLib.List <File> _opened_projects;

        public GLib.List <File> opened_projects {
            get { return _opened_projects; }
        }

        public Settings () {
            var schema_source = GLib.SettingsSchemaSource.get_default ();
            var schema = schema_source.lookup (SCHEMA, true);

            if (schema == null) {
                critical (@"Schema '$SCHEMA' is not installed on you system.");
                settings = null;
                _opened_projects = null;
            } else {
                settings =  new GLib.Settings.full (schema, null, null);
                _opened_projects = new GLib.List <File> ();
                foreach (var path in settings.get_strv ("opened-projects")) {
                    var project = new File (path);
                    if (is_open (project)) {
                        warning ("Project is already open '%s'", project.path);
                    } else if (!project.is_valid_directory) {
                        warning ("Failed to open invalid directory '%s'", project.path);
                    } else {
                        _opened_projects.append (project);
                    }
                }
                write_data (); 
            }
        }

        public bool remove_project (File project) {
            unowned GLib.List <File> entry = _opened_projects.find_custom (project, File.compare);

            if (entry == null) {
                warning ("Could not close project '%s'", project.path);
                return false;
            }
            
            _opened_projects.delete_link (entry);
            write_data ();
            return true;
        }

        public bool add_project (File project) {
            if (is_open (project)) {
                warning ("Project is already open '%s'", project.path);
            } else if (!project.is_valid_directory) {
                warning ("Failed to open invalid directory '%s'", project.path);
            } else {
                _opened_projects.append (project);
                write_data ();
                return true;
           }

           return false;
        }

        public bool is_open (File project) {
            return _opened_projects.find_custom (project, File.compare) != null;
        }

        private void write_data () {
            string[] val = {};
            _opened_projects.foreach ((p) => {
                val += p.path;
            });
            settings.set_strv ("opened-projects", val);
        }
    }
}
