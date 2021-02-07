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

    private string? project_name () {
        try {
            string content;
            FileUtils.get_contents (Path.build_filename (path, "meson.build"), out content);

            var regex = new Regex ("project\\s*\\(\\s*'(?P<name>[^']*)'[^\\)]*\\)");

            MatchInfo mi;
            if (regex.match (content, 0, out mi)) {
                return mi.fetch_named ("name");
            }
        } catch (FileError e) {
            stderr.printf (e.message);
        } catch (RegexError e) {
            stderr.printf (e.message);
        }

        return null;
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
        var meson_build = Path.build_filename (path, "meson.build");
        if (FileUtils.test (meson_build, FileTest.IS_REGULAR)) {
            var build_folder = Path.build_filename (path, "build");
            var is_ready = FileUtils.test (build_folder, FileTest.IS_DIR);
            if (!is_ready) {
                is_ready = yield run_command ({
                    "meson",
                    "build",
                    "--prefix=/usr"
                });
            }

            if (!is_ready) {
                return false;
            }

            return yield run_command ({
                "ninja",
                "-C",
                "%s".printf (Path.build_filename (path, "build"))
            });
        }

        return false;
    }

    private async bool install_project () {
        return yield run_command ({
            "pkexec",
            "bash",
            "-c",
            "ninja -C %s install; chown %s:%s %s".printf (
                Path.build_filename (path, "build"),
                Environment.get_variable ("USER"),
                Environment.get_variable ("USER"),
                Path.build_filename (path, "build", ".ninja_*")
            )
        });
    }

    private async bool run_project () {
        var project_name = project_name ();
        if (project_name != null) {
            return yield run_command ({project_name});
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

        if (!yield install_project ()) {
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
