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
    public GLib.Settings saved_state;
    public GLib.Settings settings;
    public GLib.Settings service_settings;
    public GLib.Settings privacy_settings;

    public class Application : Gtk.Application {
        public string app_cmd_name { get { return _app_cmd_name; } }
        public string data_home_folder_unsaved { get { return _data_home_folder_unsaved; } }
        public string default_font { get; set; }
        private static string _app_cmd_name;
        private static string _data_home_folder_unsaved;
        private static bool print_version = false;
        private static bool create_new_tab = false;
        private static bool create_new_window = false;

        construct {
            flags |= ApplicationFlags.HANDLES_OPEN;
            flags |= ApplicationFlags.HANDLES_COMMAND_LINE;

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
            saved_state = new GLib.Settings (Constants.PROJECT_NAME + ".saved-state");
            settings = new GLib.Settings (Constants.PROJECT_NAME + ".settings");
            service_settings = new GLib.Settings (Constants.PROJECT_NAME + ".services");
            privacy_settings = new GLib.Settings ("org.gnome.desktop.privacy");

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
            context.add_main_entries (ENTRIES, Constants.GETTEXT_PACKAGE);
            context.add_group (Gtk.get_option_group (true));

            string[] args = command_line.get_arguments ();

            try {
                context.parse_strv (ref args);
            } catch (Error e) {
                print (e.message + "\n");

                return Posix.EXIT_FAILURE;
            }

            if (print_version) {
                stdout.printf ("Code %s\n", Constants.VERSION);
                return Posix.EXIT_SUCCESS;
            }

            // Create a next window if requested and it's not the app launch
            bool is_app_launch = (get_last_window () == null);
            if (create_new_window && !is_app_launch) {
                create_new_window = false;
                this.new_window ();
            }

            // Create (or show) the first window
            activate ();

            // Create a new document if requested
            if (create_new_tab) {
                create_new_tab = false;
                var window = get_last_window ();
                Utils.action_from_group (MainWindow.ACTION_NEW_TAB, window.actions).activate (null);
            }

            int args_length = args.length;
            // Open all files given as arguments
            if (args_length > 1) { /* First arg is program name */
                File[] files = {};
                foreach (unowned string arg in args[1:args_length]) {
                    if (arg == null) { /* Recognised options changed to null */
                        continue;
                    }
                    // We set a message, that later is informed to the user
                    // in a dialog if something noteworthy happens.
                    string title = "";
                    string body = "";
                    try {
                        var file = command_line.create_file_for_arg (arg);

                        if (!file.query_exists ()) {
                            try {
                                FileUtils.set_contents (file.get_path (), "");
                            } catch (Error e) {
                                title = _("File \"%s\" Cannot Be Created".printf (file.get_path ()));

                                // We list some common errors for quick feedback
                                if (e is FileError.ACCES) {
                                    body = _("Maybe you do not have the necessary permissions.");
                                } else if (e is FileError.NOENT) {
                                    body = _("Maybe the file path provided is not valid.");
                                } else if (e is FileError.ROFS) {
                                    body = _("The location is read-only.");
                                } else if (e is FileError.NOTDIR) {
                                    body = _("The parent directory doesn't exist.");
                                } else {
                                    // Otherwise we simple use the error notification from glib
                                    body = e.message;
                                }

                                // Escape to the outer catch clause, and overwrite
                                // the weird glib's standard errors.
                                throw new Error (e.domain, e.code, "%s %s".printf (title, body));
                            }
                        }

                        var info = file.query_info ("standard::*", FileQueryInfoFlags.NONE, null);

                        switch (info.get_file_type ()) {
                            case FileType.REGULAR:
                            case FileType.SYMBOLIC_LINK:
                            case FileType.DIRECTORY:
                                files += file;
                                break;
                            case FileType.MOUNTABLE:
                                body = _("It is a mountable location.");
                                break;
                            case FileType.SPECIAL:
                                body = _("It is a \"special\" file such as a socket,\n FIFO, block device, or character device.");
                                break;
                            default:
                                body = _("It is an \"unknown\" file type.");
                                break;
                        }

                        if (body.length > 0) {
                            title = _("File \"%s\" Cannot Be Opened".printf (file.get_path ()));
                        }

                    } catch (Error e) {
                        warning (e.message);
                    }

                    // Notify the user that something happened.
                    if (title.length > 0) {
                        var dialog = new Granite.MessageDialog (
                            title,
                            body,
                            new ThemedIcon ("dialog-error"),
                            Gtk.ButtonsType.CLOSE
                        );
                        dialog.transient_for = get_last_window () as Gtk.Window;
                        dialog.run ();
                        dialog.destroy ();
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

        public MainWindow? get_last_window () {
            unowned List<Gtk.Window> windows = get_windows ();
            return windows.length () > 0 ? windows.last ().data as MainWindow : null;
        }

        public MainWindow new_window () {
            return new MainWindow (this);
        }

        const OptionEntry[] ENTRIES = {
            { "new-tab", 't', 0, OptionArg.NONE, out create_new_tab, N_("New Tab"), null },
            { "new-window", 'n', 0, OptionArg.NONE, out create_new_window, N_("New Window"), null },
            { "version", 'v', 0, OptionArg.NONE, out print_version, N_("Print version info and exit"), null },
            { "set", 's', 0, OptionArg.STRING, ref _app_cmd_name, N_("Set of plugins"), N_("plugin") },
            { null }
        };

        public static int main (string[] args) {
            _app_cmd_name = "Code";
            Application app = Application.instance;
            return app.run (args);
        }
    }
}
