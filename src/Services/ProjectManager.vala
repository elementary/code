public class Scratch.Services.ProjectManager : Object {
    public string path { get; set; }

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

    private async bool run_command (string[] cmd) {
        MainLoop loop = new MainLoop ();
        bool exit_status = false;

        try {
            string[] spawn_args = cmd;
            string[] spawn_env = Environ.get ();
            Pid child_pid;

            Process.spawn_async (
                path,
                spawn_args,
                spawn_env,
                SpawnFlags.SEARCH_PATH | SpawnFlags.DO_NOT_REAP_CHILD,
                null,
                out child_pid
            );

            ChildWatch.add (child_pid, (pid, status) => {
                // Triggered when the child indicated by child_pid exits
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

    private async bool build () {
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

    private async bool install () {
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

    private async bool run () {
        var project_name = project_name ();
        if (project_name != null) {
            return yield run_command ({project_name});
        }

        return false;
    }

    public async bool build_install_run () {
        if (!yield build ()) {
            return false;
        }

        if (!yield install ()) {
            return false;
        }

        return yield run ();
    }
}
