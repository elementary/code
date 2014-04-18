// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/***
  BEGIN LICENSE

  Copyright (C) 2011-2012 Giulio Collura <random.cpp@gmail.com>
                2013      Mario Guerriero <mario@elementaryos.org>
  This program is free software: you can redistribute it and/or modify it
  under the terms of the GNU Lesser General Public License version 3, as
  published    by the Free Software Foundation.

  This program is distributed in the hope that it will be useful, but
  WITHOUT ANY WARRANTY; without even the implied warranties of
  MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
  PURPOSE.  See the GNU General Public License for more details.

  You should have received a copy of the GNU General Public License along
  with this program.  If not, see <http://www.gnu.org/licenses>

  END LICENSE
***/

using Granite;
using Granite.Services;

namespace Scratch {
    
    // Settings
    public SavedState saved_state;
    public Settings settings;
    public ServicesSettings services;
    
    // Plugins;
    public Scratch.Services.PluginsManager? plugins = null;
    
    public class ScratchApp : Granite.Application {

        public MainWindow window = null;
        public string app_cmd_name { get { return _app_cmd_name; } }
        public static string _app_cmd_name;
        public static bool new_instance = false;
        
        construct {

            build_data_dir = Constants.DATADIR;
            build_pkg_data_dir = Constants.PKGDATADIR;
            build_release_name = Constants.RELEASE_NAME;
            build_version = Constants.VERSION;
            build_version_info = Constants.VERSION_INFO;

            program_name = app_cmd_name;
            exec_name = "scratch-text-editor";
            app_years = "2011-2013";
            app_icon = "accessories-text-editor";
            app_launcher = "scratch-text-editor.desktop";
            application_id = "org.elementary." + app_cmd_name.down ();
            main_url = "https://launchpad.net/scratch";
            bug_url = "https://bugs.launchpad.net/scratch";
            help_url = "http://elementaryos.org/answers/+/scratch/all/newest";
            translate_url = "https://translations.launchpad.net/scratch";
            about_authors = { "Mario Guerriero <mario@elementaryos.org>",
                         "Giulio Collura <random.cpp@gmail.com>",
                         "Lucas Baudin <xapantu@gmail.com>",
                         null
                         };
            about_documenters = { "Mario Guerriero <mario@elementaryos.org>",
                              null };
            about_artists = { "Harvey Cabaguio <harveycabaguio@gmail.com>",
                         null
                         };
            about_translators = "Launchpad Translators";
            about_license_type = Gtk.License.GPL_3_0;
        }

        public ScratchApp () {
            // Init internationalization support
            Intl.setlocale (LocaleCategory.ALL, "");
            string langpack_dir = Path.build_filename (Constants.INSTALL_PREFIX, "share", "locale");
            Intl.bindtextdomain (Constants.GETTEXT_PACKAGE, langpack_dir);
            Intl.bind_textdomain_codeset (Constants.GETTEXT_PACKAGE, "UTF-8");
            Intl.textdomain (Constants.GETTEXT_PACKAGE);

            Logger.initialize ("Scratch");
            Logger.DisplayLevel = LogLevel.DEBUG;

            ApplicationFlags flags = ApplicationFlags.HANDLES_OPEN;
            if(new_instance)
                flags |= ApplicationFlags.NON_UNIQUE;
            set_flags (flags);

            // Init settings
            saved_state = new SavedState ();
            settings = new Settings ();
            services = new ServicesSettings ();
            
        }

        protected override void activate () {
            
            // Plugins
            if (plugins == null)
                plugins = new Scratch.Services.PluginsManager (this, app_cmd_name.down ());
            
            if (get_windows () == null) {
                window = new MainWindow (this);
                window.show ();
                // Restore opened documents
                if (settings.show_at_start == "last-tabs") {
                    window.start_loading ();
                    
                    string[] uris = settings.schema.get_strv ("opened-files");
                
                    foreach (string uri in uris) {
                       if (uri != "") {
                            var file = File.new_for_uri (uri);
                            if (file.query_exists ()) {
                                var doc = new Scratch.Services.Document (file);
                                window.open_document (doc);
                            }
                        }
                    }
                    window.stop_loading ();
                }
            } else {
                window.present ();
            }

        }
        
        protected override void open (File[] files, string hint) {
            // Create window if it was not yet done
            activate ();
            
            // Add a view if there aren't and get the current DocumentView
            Scratch.Widgets.DocumentView? view = null;
            
            if (window.is_empty ())
                view = window.add_view ();
            else
                view = window.get_current_view ();
            
            for (int i = 0; i < files.length; i++) {
                if (files[i].get_basename () == "--new-tab")
                    main_actions.get_action ("NewTab").activate ();
                // Check if the given path is a directory
                try {
                    var info = files[i].query_info ("standard::*", FileQueryInfoFlags.NONE, null);
                    if (info.get_file_type () != FileType.DIRECTORY) {
                        var doc = new Scratch.Services.Document (files[i]);
                        view.open_document (doc);
                    }
                    else
                        warning ("\"%s\" is a directory, not opening it", files[i].get_basename ());
                } catch (Error e) {
                    warning (e.message);
                }
            }
        }
        
        static const OptionEntry[] entries = {
            { "set", 's', 0, OptionArg.STRING, ref _app_cmd_name, N_("Set of plugins"), "" },
            { "new-instance", 'n', 0, OptionArg.NONE, ref new_instance, N_("Create a new instance"), null },
            { null }
        };

        public static int main (string[] args) {
            _app_cmd_name = "Scratch";
            var context = new OptionContext ("File");
            context.add_main_entries (entries, Constants.GETTEXT_PACKAGE);
            
            try {
                context.parse(ref args);
            }
            catch(Error e) {
                print(e.message + "\n");
            }

            var app = new ScratchApp ();

            return app.run (args);

        }
        
    }
}
