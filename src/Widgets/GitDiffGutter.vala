namespace Scratch.Widgets {
    public class GitDiffGutter : Gtk.SourceGutter {

        private GLib.File repo_path;
        private Ggit.Repository? git_repo = null;
        private Ggit.Diff workdir_diff_List;
        
        public GitDiffGutter () {
            stdout.printf("MAKING NEW DIFF GUTTER\n");
            try {
                repo_path = GLib.File.new_for_path ("/home/puffin/code/code");
                git_repo = Ggit.Repository.open (repo_path);
                workdir_diff_List = new Ggit.Diff.index_to_workdir (git_repo, null, null);
            } catch (GLib.Error e) {
                stdout.printf("Error trying to open repo: %s\n", e.message);
            }
        }

        private int diff_file_callback (Ggit.DiffDelta delta, float progress) {
            return 0;
        }

        private int diff_binary_callback (Ggit.DiffDelta delta, Ggit.DiffBinary binary) {
            return 0;
        }

        private int diff_hunk_callback (Ggit.DiffDelta delta, Ggit.DiffHunk hunk) {
            return 0;
        }

        private int diff_line_callback (Ggit.DiffDelta delta, Ggit.DiffHunk? hunk, Ggit.DiffLine line) {
            Ggit.DiffFile? file_diff = delta.get_old_file ();
            Ggit.DiffLineType type_of_change = line.get_origin();
            string path = file_diff.get_path ();
            stdout.printf("In file: %s\n", path);
            if (type_of_change == Ggit.DiffLineType.ADDITION) {
                stdout.printf("Line -> %d added\n", line.get_new_lineno ());
            }
            return 0;
        }

        public void make_diff () {
            stdout.printf("MAKE_DIFF()\n");
            workdir_diff_List.foreach (diff_file_callback, diff_binary_callback, diff_hunk_callback, diff_line_callback);
        }

    }
}