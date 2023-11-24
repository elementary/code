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
        public string data_home_folder_unsaved { get { return _data_home_folder_unsaved; } }
        public string default_font { get; set; }
        private static string _data_home_folder_unsaved;
        private static bool create_new_tab = false;
        private static bool create_new_window = false;
        private static string selection_range_string = null;
        private static SelectionRange selection_range = SelectionRange.empty;
        private static GLib.File selection_range_file;

        const OptionEntry[] ENTRIES = {
            { "new-tab", 't', 0, OptionArg.NONE, null, N_("New Tab"), null },
            { "new-window", 'n', 0, OptionArg.NONE, null, N_("New Window"), null },
            { "version", 'v', 0, OptionArg.NONE, null, N_("Print version info and exit"), null },
            { "go-to", 'g', 0, OptionArg.STRING, null, "Open file at specified selection range", "<start_line[.start_column][-end_line[.end_column]]>" },
            { GLib.OPTION_REMAINING, 0, 0, OptionArg.FILENAME_ARRAY, null, null, N_("[FILE…]") },
            { null }
        };

        static construct {
            // Init data home folder for unsaved text files
            _data_home_folder_unsaved = Path.build_filename (
                                            Environment.get_user_data_dir (), Constants.PROJECT_NAME, "unsaved"
                                        );
        }

        construct {
            flags |= ApplicationFlags.HANDLES_OPEN;
            flags |= ApplicationFlags.HANDLES_COMMAND_LINE;

            application_id = Constants.PROJECT_NAME;
            if (Constants.BRANCH != "") {
                application_id += "." + Constants.BRANCH.replace ("/", ".").replace ("-", "_");
            }

            add_main_option_entries (ENTRIES);

            // Init settings
            default_font = new GLib.Settings ("org.gnome.desktop.interface").get_string ("monospace-font-name");
            saved_state = new GLib.Settings (Constants.PROJECT_NAME + ".saved-state");
            settings = new GLib.Settings (Constants.PROJECT_NAME + ".settings");
            service_settings = new GLib.Settings (Constants.PROJECT_NAME + ".services");
            privacy_settings = new GLib.Settings ("org.gnome.desktop.privacy");

            Environment.set_variable ("GTK_USE_PORTAL", "1", true);

            GLib.Intl.setlocale (LocaleCategory.ALL, "");
            GLib.Intl.bindtextdomain (Constants.GETTEXT_PACKAGE, Constants.LOCALEDIR);
            GLib.Intl.bind_textdomain_codeset (Constants.GETTEXT_PACKAGE, "UTF-8");
            GLib.Intl.textdomain (Constants.GETTEXT_PACKAGE);
        }

        public override int handle_local_options (VariantDict options) {
            if (options.contains ("version")) {
                stdout.printf ("Code %s\n", Constants.VERSION);
                return Posix.EXIT_SUCCESS;
            }

            return -1;
        }

        public override int command_line (GLib.ApplicationCommandLine command_line) {
            /* Only allow running with root privileges using pkexec, not using sudo */
            if (Posix.getuid () == 0 && GLib.Environment.get_variable ("PKEXEC_UID") == null) {
#if HAVE_PKEXEC
                warning ("Running Code using sudo is not possible. Use: pkexec io.elementary.code");
#endif
                quit ();
                return 1;
            };

            var options = command_line.get_options_dict ();

            if (options.contains ("new-tab")) {
                create_new_tab = true;
            }

            if (options.contains ("new-window")) {
                create_new_window = true;
            }

            if (options.contains ("go-to")) {
                var go_to_string_variant =  options.lookup_value ("go-to", GLib.VariantType.STRING);
                selection_range_string = (string) go_to_string_variant.get_string ();
            } else {
                selection_range_string = null;
            }

            debug ("Go to string %s:", selection_range_string);

            bool matched_selection_range = false;
            if (selection_range_string != null) {
                Regex go_to_line_regex = /^(?<start_line>[0-9]+)+(?:\.(?<start_column>[0-9]+)+)?(?:-(?:(?<end_line>[0-9]+)+(?:\.(?<end_column>[0-9]+)+)?))?$/;  // vala-lint=space-before-paren, line-length
                MatchInfo match_info;
                matched_selection_range = go_to_line_regex.match (selection_range_string, 0, out match_info);
                if (matched_selection_range) {
                    selection_range = parse_go_to_range_from_match_info (match_info);
                    debug ("Selection Range - start_line: %d", selection_range.start_line);
                    debug ("Selection Range - start_column: %d", selection_range.start_column);
                    debug ("Selection Range - end_line: %d", selection_range.end_line);
                    debug ("Selection Range - end_column: %d", selection_range.end_column);
                }
            } else {
                selection_range = SelectionRange.empty;
            }

            if (matched_selection_range && options.contains (GLib.OPTION_REMAINING)) {
                (unowned string)[] file_list = options.lookup_value (
                    GLib.OPTION_REMAINING,
                    VariantType.BYTESTRING_ARRAY
                ).get_bytestring_array ();

                if (file_list.length == 1) {
                    unowned string selection_range_file_path = file_list[0];
                    //  selection_range_file = command_line.create_file_for_arg (selection_range_file_path);
                    selection_range_file = command_line.create_file_for_arg (selection_range_file_path);
                }
            }

            activate ();

            if (options.contains (GLib.OPTION_REMAINING)) {
                File[] files = {};

                (unowned string)[] remaining = options.lookup_value (
                    GLib.OPTION_REMAINING,
                    VariantType.BYTESTRING_ARRAY
                ).get_bytestring_array ();

                for (int i = 0; i < remaining.length; i++) {
                    unowned string file = remaining[i];
                    files += command_line.create_file_for_arg (file);
                }

                open (files, "");
            }



            return Posix.EXIT_SUCCESS;
        }

        protected override void activate () {
            if (active_window == null) {
                if (selection_range != SelectionRange.empty
                    && selection_range_file != null
                    && is_file_to_restore (selection_range_file))
                {
                    add_window (new MainWindow.with_restore_override (true, new RestoreOverride (selection_range_file, selection_range)));
                } else {
                    add_window (new MainWindow (true)); // Will restore documents if required
                }
            } else if (create_new_window) {
                create_new_window = false;
                add_window (new MainWindow (false)); // Will NOT restore documents in additional windows
            }

            active_window.present ();

            // Create a new document if requested
            if (create_new_tab) {
                create_new_tab = false;
                activate_action (MainWindow.ACTION_PREFIX + MainWindow.ACTION_NEW_TAB, null);
            }
        }

        protected override void open (File[] files, string hint) {
            var window = get_last_window ();
            foreach (var file in files) {
                bool is_folder;
                if (Scratch.Services.FileHandler.can_open_file (file, out is_folder)) {
                    if (is_folder) {
                        window.open_folder (file);
                    } else {
                        debug ("Files length: %d\n", files.length);
                        var doc = new Scratch.Services.Document (window.actions, file);
                        if (selection_range_string != null && files.length == 1) {
                            window.open_document_at_selected_range (doc, true, selection_range);
                        } else {
                            window.open_document (doc);
                        }

                    }
                }
            }
        }

        public MainWindow? get_last_window () {
            unowned List<Gtk.Window> windows = get_windows ();
            return windows.length () > 0 ? windows.last ().data as MainWindow : null;
        }

        public static int main (string[] args) {
            return new Application ().run (args);
        }

        private SelectionRange parse_go_to_range_from_match_info (GLib.MatchInfo match_info) {
            return SelectionRange () {
                start_line = parse_num_from_match_info (match_info, "start_line"),
                end_line = parse_num_from_match_info (match_info, "end_line"),
                start_column = parse_num_from_match_info (match_info, "start_column"),
                end_column = parse_num_from_match_info (match_info, "end_column"),
            };
        }

        private int parse_num_from_match_info (MatchInfo match_info, string match_name) {
            string str = match_info.fetch_named (match_name);
            int num;

            if (int.try_parse (str, out num)) {
                return num;
            }

            return 0;
        }

        private bool is_file_to_restore (File file_to_check) {
            bool will_restore = false;
            if (privacy_settings.get_boolean ("remember-recent-files")) {
                var doc_infos = settings.get_value ("opened-files");
                var doc_info_iter = new VariantIter (doc_infos);
                
                string uri;
                int pos;
                while (doc_info_iter.next ("(si)", out uri, out pos)) {
                   if (uri != "") {
                        GLib.File file;
                        if (Uri.parse_scheme (uri) != null) {
                            file = File.new_for_uri (uri);
                        } else {
                            file = File.new_for_commandline_arg (uri);
                        }

                        if (file.query_exists () && file.get_path () == file_to_check.get_path ()) {
                            will_restore = true;
                            return will_restore;
                        }
                    }
                }
            }

            return will_restore;
        }
    }
}
