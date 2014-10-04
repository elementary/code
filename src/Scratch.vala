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
    
    public class ScratchApp : Granite.Application {

        private GLib.List <MainWindow> windows;

        public string app_cmd_name { get { return _app_cmd_name; } }
        public string data_home_folder_unsaved { get { return _data_home_folder_unsaved; } }
        private static string _app_cmd_name;
        private static string _data_home_folder_unsaved;
        private static string _cwd;
        private static bool print_version = false;
        private static bool create_new_tab = false;
        private static bool create_new_window = false;
        
        construct {
            flags |= ApplicationFlags.HANDLES_OPEN;
            flags |= ApplicationFlags.HANDLES_COMMAND_LINE;
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

            // Init settings
            saved_state = new SavedState ();
            settings = new Settings ();
            services = new ServicesSettings ();
            windows = new GLib.List <MainWindow> ();
            
            // Init data home folder for unsaved text files
            _data_home_folder_unsaved = Environment.get_user_data_dir () + "/" + exec_name + "/unsaved/";
        }

        public static ScratchApp _instance = null;

        public static ScratchApp instance {
            get {
                if (_instance == null)
                    _instance = new ScratchApp ();
                return _instance;
            }
        }

        protected override int command_line (ApplicationCommandLine command_line) {
            var context = new OptionContext ("File");
            context.add_main_entries (entries, Constants.GETTEXT_PACKAGE);
            context.add_group (Gtk.get_option_group (true));

            string[] args = command_line.get_arguments ();
            int unclaimed_args;

            try {
                unowned string[] tmp = args;
                context.parse (ref tmp);
                unclaimed_args = tmp.length - 1;
            } catch(Error e) {
                print (e.message + "\n");

                return Posix.EXIT_FAILURE;
            }

            // Create (or show) the first window
            activate ();

            // Create a second window if requested
            if (create_new_window) {
                create_new_window = false;
                this.new_window ();
            }

            // Create a new document if requested
            if (create_new_tab) {
                create_new_tab = false;
                var window = get_last_window ();
                window.main_actions.get_action ("NewTab").activate ();
            }

            // Set Current Directory
            Environment.set_current_dir (_cwd); 

            // Open all files given as arguments
            if (unclaimed_args > 0) {
                File[] files = new File[unclaimed_args];
                files.length = 0;

                foreach (string arg in args[1:unclaimed_args + 1]) {
                    files += File.new_for_commandline_arg (arg);
                }

                open (files, "");
            }

            return Posix.EXIT_SUCCESS;
        }

        protected override void activate () {
            var window = get_last_window ();
            if (window == null) {
                window = this.new_window ();
                window.show ();
                // Restore opened documents
                if (settings.show_at_start == "last-tabs") {
                    window.start_loading ();
                    
                    string[] uris = settings.schema.get_strv ("opened-files");
                
                    foreach (string uri in uris) {
                       if (uri != "") {
                            var file = File.new_for_uri (uri);
                            if (file.query_exists ()) {
                                var doc = new Scratch.Services.Document (window.main_actions, file);
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
            // Add a view if there aren't and get the current DocumentView
            Scratch.Widgets.DocumentView? view = null;
            var window = get_last_window ();

            if (window.is_empty ())
                view = window.add_view ();
            else
                view = window.get_current_view ();
            
            for (int i = 0; i < files.length; i++) {
                // Check if the given path is a directory
                try {
                    var info = files[i].query_info ("standard::*", FileQueryInfoFlags.NONE, null);
                    if (info.get_file_type () != FileType.DIRECTORY) {
                        var doc = new Scratch.Services.Document (window.main_actions, files[i]);
                        view.open_document (doc);
                    }
                    else
                        warning ("\"%s\" is a directory, not opening it", files[i].get_basename ());
                } catch (Error e) {
                    warning (e.message);
                }
            }
        }

        public MainWindow? get_last_window () {
            uint length = windows.length ();

            return length > 0 ? windows.nth_data (length - 1) : null;
        }

        public MainWindow new_window () {
            return new MainWindow (this);
        }

        protected override void window_added (Gtk.Window window) {
            windows.append (window as MainWindow);
            base.window_added (window);
        }

        protected override void window_removed (Gtk.Window window) {
            windows.remove (window as MainWindow);
            base.window_removed (window);
        }
        
        static const OptionEntry[] entries = {
            { "new-tab", 't', 0, OptionArg.NONE, out create_new_tab, N_("New Tab"), null },
            { "new-window", 'n', 0, OptionArg.NONE, out create_new_window, N_("New Window"), null },
            { "version", 'v', 0, OptionArg.NONE, out print_version, N_("Print version info and exit"), null },
            { "set", 's', 0, OptionArg.STRING, ref _app_cmd_name, N_("Set of plugins"), "" },
            { "cwd", 'c', 0, OptionArg.STRING, ref _cwd, N_("Current working directoy"), "" },            
            { null }
        };

        public static int main (string[] args) {
            _app_cmd_name = "Scratch";

            var context = new OptionContext ("File");
            context.add_main_entries (entries, Constants.GETTEXT_PACKAGE);
            context.add_group (Gtk.get_option_group (true));

            string[] args_primary_instance = args;
            args_primary_instance += "-c";
            args_primary_instance += Environment.get_current_dir (); 

            try {
                context.parse (ref args);
            } catch(Error e) {
                print (e.message + "\n");

                return Posix.EXIT_FAILURE;
            }

            if (print_version) {
                stdout.printf ("Scratch Text Editor %s\n", Constants.VERSION);
                stdout.printf ("Copyright 2011-2014 Scratch Text Editor Developers.\n");

                return Posix.EXIT_SUCCESS;
            }

            ScratchApp app = ScratchApp.instance;
            return app.run (args_primary_instance);
        }
    }
}
