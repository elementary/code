public class Scratch.Services.ProjectManager : Object{
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

    private bool run_command (string[] cmd) {
        try {
            string[] spawn_args = cmd;
            string[] spawn_env = Environ.get ();
            int status;

            Process.spawn_sync (path,
                                spawn_args,
                                spawn_env,
                                SpawnFlags.SEARCH_PATH,
                                null,
                                null,
                                null,
                                out status);

            if (status != 0) {
                return false;
            }    
        } catch (SpawnError e) {
            print ("Error: %s\n", e.message);
            return false;
        }

        return true;
    }

    public bool build () {
        var meson_build = Path.build_filename (path, "meson.build");
        if (FileUtils.test (meson_build, FileTest.IS_REGULAR)) {
            var build_folder = Path.build_filename (path, "build");
            var is_ready = FileUtils.test (build_folder, FileTest.IS_DIR);
            if (!is_ready) {
                is_ready = run_command ({
                    "meson",
                    "build",
                    "--prefix=/usr"
                });
            }

            if (!is_ready) {
                return false;
            }

            return run_command ({
                "ninja",
                "-C",
                "%s".printf (Path.build_filename (path, "build"))
            });
        }

        return false;
    }

    public bool install () {
        return run_command ({
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

    public bool run () {
        var project_name = project_name ();
        if (project_name != null) {
            return run_command ({project_name});
        }

        return false;
    }
}
