/*
 * Copyright (c) 2021 elementary, Inc. (https://elementary.io)
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
 *
 * Authored by: Marius Meisenzahl <mariusmeisenzahl@gmail.com>
 */

public class Scratch.Services.ProjectManager : Object {
    public string path { get; set; }
    public bool is_running { get; set; }

    public signal void on_standard_output (string line);
    public signal void on_standard_error (string line);

    private Pid command_pid;

    private FlatpakManifest? flatpak_manifest () {
        try {
            Dir dir = Dir.open (path, 0);
            string? name = null;
            while ((name = dir.read_name ()) != null) {
                string f = Path.build_filename (path, name);

                if (FileUtils.test (f, FileTest.IS_REGULAR) && f.has_suffix (".yml")) {
                    string content;
                    FileUtils.get_contents (f, out content);

                    var regex = new Regex ("app-id:\\s*(?P<app_id>[A-Za-z0-9-\\.]+)");

                    MatchInfo mi;
                    if (regex.match (content, 0, out mi)) {
                        return new FlatpakManifest () {
                            manifest = f,
                            build_dir = Path.build_filename (path, "build-dir"),
                            app_id = mi.fetch_named ("app_id")
                        };
                    }
                }
            }
        } catch (FileError e) {
            stderr.printf (e.message);
        } catch (RegexError e) {
            stderr.printf (e.message);
        }

        return null;
    }

    private class FlatpakManifest : Object {
        public string manifest { get; set; }
        public string build_dir { get; set; }
        public string app_id { get; set; }
    }

    private bool process_line (IOChannel channel, IOCondition condition, string stream_name) {
        if (condition == IOCondition.HUP) {
            return false;
        }

        try {
            string line;
            channel.read_line (out line, null, null);

            switch (stream_name) {
                case "stdout":
                    print (line);
                    on_standard_output (line);
                    break;
                case "stderr":
                    print (line);
                    on_standard_error (line);
                    break;
            }
        } catch (IOChannelError e) {
            warning ("%s: IOChannelError: %s", stream_name, e.message);
            return false;
        } catch (ConvertError e) {
            warning ("%s: ConvertError: %s", stream_name, e.message);
            return false;
        }

        return true;
    }

    private async bool run_command (string[] cmd) {
        MainLoop loop = new MainLoop ();
        bool exit_status = false;

        try {
            string[] spawn_args = cmd;
            string[] spawn_env = Environ.get ();

            int standard_input;
            int standard_output;
            int standard_error;

            Process.spawn_async_with_pipes (
                path,
                spawn_args,
                spawn_env,
                SpawnFlags.SEARCH_PATH | SpawnFlags.DO_NOT_REAP_CHILD,
                null,
                out command_pid,
                out standard_input,
                out standard_output,
                out standard_error
            );

            // stdout
            IOChannel output = new IOChannel.unix_new (standard_output);
            output.add_watch (IOCondition.IN | IOCondition.HUP, (channel, condition) => {
                return process_line (channel, condition, "stdout");
            });

            // stderr
            IOChannel error = new IOChannel.unix_new (standard_error);
            error.add_watch (IOCondition.IN | IOCondition.HUP, (channel, condition) => {
                return process_line (channel, condition, "stderr");
            });


            ChildWatch.add (command_pid, (pid, status) => {
                // Triggered when the child indicated by command_pid exits
                Process.close_pid (pid);
                exit_status = (status == 0);
                loop.quit ();
            });

            loop.run ();

            return exit_status;
        } catch (SpawnError e) {
            warning ("Could not run command: %s\n", e.message);
            return false;
        }
    }

    private async bool build_project () {
        var flatpak_manifest = flatpak_manifest ();
        if (flatpak_manifest != null) {
            return yield run_command ({
                "flatpak-builder",
                "--force-clean",
                flatpak_manifest.build_dir,
                flatpak_manifest.manifest
            });
        }

        return false;
    }

    private async bool run_project () {
        var flatpak_manifest = flatpak_manifest ();
        if (flatpak_manifest != null) {
            return yield run_command ({
                "flatpak-builder",
                "--run",
                flatpak_manifest.build_dir,
                flatpak_manifest.manifest,
                flatpak_manifest.app_id
            });
        }

        return false;
    }

    public async bool build () {
        if (is_running) {
            debug ("Project “%s“ is already running", path);
            return false;
        }

        is_running = true;
        var result = yield build_project ();
        is_running = false;

        return result;
    }

    public async bool build_install_run () {
        if (is_running) {
            debug ("Project “%s“ is already running", path);
            return false;
        }

        is_running = true;
        if (!yield build_project ()) {
            is_running = false;
            return false;
        }

        var result = yield run_project ();
        is_running = false;

        return result;
    }

    public bool stop () {
        if (!is_running) {
            debug ("Project “%s“ is not running", path);
            return true;
        }

        var result = Posix.kill (command_pid, Posix.Signal.TERM) == 0;
        is_running = !result;

        return result;
    }
}
