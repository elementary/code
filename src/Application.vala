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
        public bool is_running_in_flatpak { get; construct; }

        private static string _data_home_folder_unsaved;
        private static bool create_new_tab = false;
        private static bool create_new_window = false;

        private LocationJumpManager location_jump_manager;

        const OptionEntry[] ENTRIES = {
            { "new-tab", 't', 0, OptionArg.NONE, null, N_("New Tab"), null },
            { "new-window", 'n', 0, OptionArg.NONE, null, N_("New Window"), null },
            { "version", 'v', 0, OptionArg.NONE, null, N_("Print version info and exit"), null },
            { "go-to", 'g', 0, OptionArg.STRING, null, N_("Open file at specified selection range"), N_("<START_LINE[.START_COLUMN][-END_LINE[.END_COLUMN]]>") },
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

            is_running_in_flatpak = FileUtils.test ("/.flatpak-info", FileTest.IS_REGULAR);
            add_main_option_entries (ENTRIES);

            // Init settings
            default_font = new GLib.Settings ("org.gnome.desktop.interface").get_string ("monospace-font-name");
            saved_state = new GLib.Settings (Constants.PROJECT_NAME + ".saved-state");
            settings = new GLib.Settings (Constants.PROJECT_NAME + ".settings");
            service_settings = new GLib.Settings (Constants.PROJECT_NAME + ".services");
            privacy_settings = new GLib.Settings ("org.gnome.desktop.privacy");

            location_jump_manager = new LocationJumpManager ();
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
            location_jump_manager.clear ();

            if (options.contains ("new-tab")) {
                create_new_tab = true;
            }

            if (options.contains ("new-window")) {
                create_new_window = true;
            }

            if (options.contains ("go-to")) {
                var go_to_string_variant = options.lookup_value ("go-to", GLib.VariantType.STRING);
                string selection_range_string = (string) go_to_string_variant.get_string ();
                location_jump_manager.parse_selection_range_string (selection_range_string);
                debug ("go-to arg value: %s", selection_range_string);
            }

            if (location_jump_manager.has_selection_range () && options.contains (GLib.OPTION_REMAINING)) {
                (unowned string)[] file_list = options.lookup_value (
                    GLib.OPTION_REMAINING,
                    VariantType.BYTESTRING_ARRAY
                ).get_bytestring_array ();

                if (file_list.length == 1) {
                    unowned string selection_range_file_path = file_list[0];
                    location_jump_manager.file = command_line.create_file_for_arg (selection_range_file_path);
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
                if (location_jump_manager.has_selection_range () && location_jump_manager.has_override_target ()) {
                    RestoreOverride restore_override = location_jump_manager.create_restore_override ();
                    add_window (new MainWindow.with_restore_override (true, restore_override));
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
                var active_window_action_group = active_window.get_action_group (MainWindow.ACTION_GROUP);
                active_window_action_group.activate_action (MainWindow.ACTION_NEW_TAB, null);
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
                        if (location_jump_manager.has_selection_range != null && files.length == 1) {
                            window.open_document_at_selected_range.begin (doc, true, location_jump_manager.range);
                        } else {
                            window.open_document.begin (doc);
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
// By default, profile whole app when profiling is enabled in meson_options.txt
// These conditional statements can be moved to profile sections of code
// The gperftools library must be installed (libgoogle-perftools-dev)
// Amend the profile report paths as required
#if PROFILING
            // Visualize the cpu profile with e.g. google-pprof --functions --gv /usr/bin/io.elementary.code <profile_path>
            // Use --focus=<regexp> and --ignore=<regexp> to filter/prune nodes displayed
            var profile_path = Path.build_filename (Environment.get_home_dir (), "CpuProfileCodeApplication.prof");
            // Start CPU profiling
            Profiler.start (profile_path);
            warning ("start cpu profiling - output to %s", profile_path);
#endif
#if HEAP_PROFILING
            // NOTE: Heap profiling at this point slows the program down **a lot** It will take tens of seconds to load.
            // The output path will have the suffix '.NNNN.heap' appended
            // Visualize the profile with e.g. google-pprof --gv /usr/bin/io.elementary.code <profile_path>
            // Use --focus=<regexp> and --ignore=<regexp> to filter/prune nodes displayed
            var heap_profile_path = Path.build_filename (Environment.get_home_dir (), "HeapProfileCodeApplication");
            // Start heap profiling
            HeapProfiler.start (heap_profile_path);
            warning ("start heap profiling - output to %s", heap_profile_path);
#endif

            return new Application ().run (args);

#if PROFILING
            Profiler.stop ();
            warning ("stop cpu profiling");
#endif
#if HEAP_PROFILING
            HeapProfiler.stop ();
            warning ("stop heap profiling");
#endif
        }
    }
}
