// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*
* Copyright (c) 2011-2012 Giulio Collura <random.cpp@gmail.com>
*               2013 Mario Guerriero <mefrio.g@gmail.com>
*               2017 elementary LLC. <https://elementary.io>
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 3 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*/

namespace Scratch {
    public SavedState saved_state;
    public Settings settings;
    public ServicesSettings services;

    public class Application : Granite.Application {
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
            build_version = Constants.VERSION;

            program_name = app_cmd_name;
            exec_name = Constants.PROJECT_NAME;
            app_launcher = Constants.PROJECT_NAME + ".desktop";
            application_id = Constants.PROJECT_NAME;
        }

        public Application () {
            // Init internationalization support
            Intl.setlocale (LocaleCategory.ALL, "");
            string langpack_dir = Path.build_filename (Constants.INSTALL_PREFIX, "share", "locale");
            Intl.bindtextdomain (Constants.GETTEXT_PACKAGE, langpack_dir);
            Intl.bind_textdomain_codeset (Constants.GETTEXT_PACKAGE, "UTF-8");
            Intl.textdomain (Constants.GETTEXT_PACKAGE);

            Granite.Services.Logger.initialize ("Code");

            // Init settings
            default_font = new GLib.Settings ("org.gnome.desktop.interface").get_string ("monospace-font-name");
            saved_state = new SavedState ();
            settings = new Settings ();
            services = new ServicesSettings ();

            // Init data home folder for unsaved text files
            _data_home_folder_unsaved = Path.build_filename (Environment.get_user_data_dir (), Constants.PROJECT_NAME, "unsaved");
        }

        public static Application _instance = null;

        public static Application instance {
            get {
                if (_instance == null) {
                    _instance = new Application ();
                }
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
                context.parse_strv (ref args);
                unclaimed_args = args.length - 1;
            } catch(Error e) {
                print (e.message + "\n");

                return Posix.EXIT_FAILURE;
            }

            if (print_version) {
                stdout.printf ("Code %s\n", build_version);
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
                Utils.action_from_group (MainWindow.ACTION_NEW_TAB, window.actions).activate (null);
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
                                string reason = "";
                                // We list some common errors for quick feedback
                                if (e is FileError.ACCES) {
                                    reason = _("Maybe you do not have the necessary permissions.");
                                } else if (e is FileError.NOENT) {
                                    reason = _("Maybe the file path provided is not valid.");
                                } else if (e is FileError.ROFS) {
                                    reason = _("The location is read-only.");
                                } else if (e is FileError.NOTDIR) {
                                    reason = _("The parent directory doesn't exist.");
                                } else {
                                    // Otherwise we simple use the error notification from glib
                                    msg = e.message;
                                }

                                if (reason.length > 0) {
                                    msg = _("File \"%s\" cannot be created.\n%s").printf ("<b>%s</b>".printf (file.get_path ()), reason);
                                }

                                // Escape to the outer catch clause, and overwrite
                                // the weird glib's standard errors.
                                throw new Error (e.domain, e.code, msg);
                            }
                        }

                        var info = file.query_info ("standard::*", FileQueryInfoFlags.NONE, null);
                        string err_msg = _("File \"%s\" cannot be opened.\n%s");
                        string reason = "";

                        switch (info.get_file_type ()) {
                            case FileType.REGULAR:
                            case FileType.SYMBOLIC_LINK:
                            case FileType.DIRECTORY:
                                files += file;
                                break;
                            case FileType.MOUNTABLE:
                                reason = _("It is a mountable location.");
                                break;
                            case FileType.SPECIAL:
                                reason = _("It is a \"special\" file such as a socket,\n FIFO, block device, or character device.");
                                break;
                            default:
                                reason = _("It is an \"unknown\" file type.");
                                break;
                        }

                        if (reason.length > 0) {
                            msg = err_msg.printf ("<b>%s</b>".printf (file.get_path ()), reason);
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

                if (files.length > 0) {
                    open (files, "");
                }
            }

            return Posix.EXIT_SUCCESS;
        }

        protected override void activate () {
            var window = get_last_window ();
            if (window == null) {
                window = this.new_window ();
                window.show ();
                window.restore_opened_documents ();
            } else {
                window.present ();
            }
        }

        protected override void open (File[] files, string hint) {
            // Add a view if there aren't and get the current DocumentView
            Scratch.Widgets.DocumentView? view = null;
            var window = get_last_window ();

            if (window.is_empty ()) {
                view = window.add_view ();
            } else {
                view = window.get_current_view ();
            }

            foreach (var file in files) {
                var type = file.query_file_type (FileQueryInfoFlags.NONE);
                if (type == FileType.DIRECTORY) {
                    window.open_folder (file);
                } else {
                    var doc = new Scratch.Services.Document (window.actions, file);
                    window.open_document (doc, view);
                }
            }
        }

        public override bool local_command_line (ref weak string[] arguments, out int exit_status) {
            // Resolve any CWD paths to explicit paths before passing to remote instance as that will
            // have different CWD
            for (int i = 0; i < arguments.length; i++) {
                if (arguments[i] == ".") {
                    arguments[i] = File.new_for_commandline_arg (".").get_path ();
                }
            }

            return base.local_command_line (ref arguments, out exit_status);
        }

        public MainWindow? get_last_window () {
            unowned List<weak Gtk.Window> windows = get_windows ();
            return windows.length () > 0 ? windows.last ().data as MainWindow : null;
        }

        public MainWindow new_window () {
            return new MainWindow (this);
        }

        const OptionEntry[] entries = {
            { "new-tab", 't', 0, OptionArg.NONE, out create_new_tab, N_("New Tab"), null },
            { "new-window", 'n', 0, OptionArg.NONE, out create_new_window, N_("New Window"), null },
            { "version", 'v', 0, OptionArg.NONE, out print_version, N_("Print version info and exit"), null },
            { "set", 's', 0, OptionArg.STRING, ref _app_cmd_name, N_("Set of plugins"), "" },
            { "cwd", 'c', 0, OptionArg.STRING, ref _cwd, N_("Current working directory"), "" },
            { null }
        };

        public static int main (string[] args) {
            _app_cmd_name = "Code";
            Application app = Application.instance;
            return app.run (args);
        }
    }
}
