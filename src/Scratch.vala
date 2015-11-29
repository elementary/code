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

namespace Scratch {
    // Settings
    public SavedState saved_state;
    public Settings settings;
    public ServicesSettings services;

    public class ScratchApp : Granite.Application {
        public string app_cmd_name { get { return _app_cmd_name; } }
        public string data_home_folder_unsaved { get { return _data_home_folder_unsaved; } }
        public string default_font { get; set; }
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
            app_years = "2011-2015";
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

            Granite.Services.Logger.initialize ("Scratch");
            Granite.Services.Logger.DisplayLevel = Granite.Services.LogLevel.DEBUG;

            // Init settings
            default_font = new GLib.Settings ("org.gnome.desktop.interface").get_string ("monospace-font-name");
            saved_state = new SavedState ();
            settings = new Settings ();
            services = new ServicesSettings ();

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

            if (print_version) {
                stdout.printf ("Scratch Text Editor %s\n", build_version);
                stdout.printf ("Copyright %s Scratch Text Editor Developers.\n".printf (app_years));
                return Posix.EXIT_SUCCESS;
            }

            // Create (or show) the first window
            activate ();

            // Create a next window if requested and it's not the app launch
            bool is_app_launch = (get_last_window () == null);
            if (create_new_window && !is_app_launch) {
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
                    // We set a message, that later is informed to the user
                    // in a dialog if something noteworthy happens.
                    string msg = "";
                    try {
                        var file = File.new_for_commandline_arg (arg);

                        if (!file.query_exists ()) {
                            try {
                                FileUtils.set_contents (file.get_path (), "");
                            } catch (Error e) {
                                // We list some common errors for quick feedback
                                if (e is FileError.ACCES) {
                                    string reason = _("Maybe you do not have the necessary permissions.");
                                    msg = _("File \"%s\" cannot be created.\n%s").printf ("<b>%s</b>".printf (file.get_uri ()), reason);                                    
                                } else if (e is FileError.NOENT) {
                                    string reason = _("Maybe the file path provided is not valid.");
                                    msg = _("File \"%s\" cannot be created.\n%s").printf ("<b>%s</b>".printf (file.get_uri ()), reason);
                                } else if (e is FileError.ROFS) {
                                    string reason = _("The location is read-only.");
                                    msg = _("File \"%s\" cannot be created.\n%s").printf ("<b>%s</b>".printf (file.get_uri ()), reason);
                                } else {
                                    // Otherwise we simple use the error notification from glib
                                    msg = e.message;
                                }
                            }
                        }

                        var info = file.query_info ("standard::*", FileQueryInfoFlags.NONE, null);
                        if (info.get_file_type () == FileType.REGULAR
                            || info.get_file_type () == FileType.SYMBOLIC_LINK) {
                            files += file;
                        } else if (info.get_file_type () == FileType.MOUNTABLE){
                            string reason = _("Is a mountable location.");
                            msg = _("File \"%s\" cannot be opened.\n%s").printf ("<b>%s</b>".printf (file.get_uri ()), reason);
                        } else if (info.get_file_type () == FileType.DIRECTORY ){
                            string reason = _("Is a directory.");
                            msg = _("File \"%s\" cannot be opened.\n%s").printf ("<b>%s</b>".printf (file.get_uri ()), reason);
                        } else if (info.get_file_type () == FileType.SPECIAL ){
                            string reason = _("Is a \"special\" file such as a socket,\n fifo, block device, or character device.");
                            msg = _("File \"%s\" cannot be opened.\n%s").printf ("<b>%s</b>".printf (file.get_uri ()), reason);
                        } else {
                            string reason = _("Is a \"unknown\" file type.");
                            msg = _("File \"%s\" cannot be opened.\n%s").printf ("<b>%s</b>".printf (file.get_uri ()), reason);
                        }

                    } catch (Error e) {
                        warning (e.message);
                    }

                    // Notify the user that something happened.
                    if (msg.length > 0) {
                        var parent_window = get_last_window () as Gtk.Window;
                        var dialog = new Gtk.MessageDialog.with_markup (parent_window,
                            Gtk.DialogFlags.MODAL,
                            Gtk.MessageType.ERROR,
                            Gtk.ButtonsType.CLOSE,
                            msg);
                        dialog.run ();
                        dialog.destroy ();
                        dialog.close ();
                    }
                }

                if (files.length > 0)
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

                    // Set focus to last focused document, after all documents finished loading
                    string focused_document = settings.schema.get_string("focused-document");
                    if (focused_document != "" && window.split_view.current_view != null) {
                        Scratch.Services.Document document_to_focus = null;
                        var document_view = window.split_view.current_view;
                        foreach (Scratch.Services.Document doc in document_view.docs) {
                            if (doc.file != null) {
                                if (doc.file.get_uri() == focused_document) {
                                    document_to_focus = doc;
                                    break;
                                }
                            }
                        }
                        if (document_to_focus != null)
                            window.split_view.current_view.notebook.current = document_to_focus;
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

            foreach (var file in files) {
                var doc = new Scratch.Services.Document (window.main_actions, file);
                view.open_document (doc);
            }
        }

        public MainWindow? get_last_window () {
            unowned List<weak Gtk.Window> windows = get_windows ();
            return windows.length () > 0 ? windows.last ().data as MainWindow : null;
        }

        public MainWindow new_window () {
            return new MainWindow (this);
        }

        static const OptionEntry[] entries = {
            { "new-tab", 't', 0, OptionArg.NONE, out create_new_tab, N_("New Tab"), null },
            { "new-window", 'n', 0, OptionArg.NONE, out create_new_window, N_("New Window"), null },
            { "version", 'v', 0, OptionArg.NONE, out print_version, N_("Print version info and exit"), null },
            { "set", 's', 0, OptionArg.STRING, ref _app_cmd_name, N_("Set of plugins"), "" },
            { "cwd", 'c', 0, OptionArg.STRING, ref _cwd, N_("Current working directory"), "" },
            { null }
        };

        public static int main (string[] args) {
            _app_cmd_name = "Scratch";
            ScratchApp app = ScratchApp.instance;
            return app.run (args);
        }
    }
}
