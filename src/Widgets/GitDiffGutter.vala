namespace Scratch.Widgets {
    public class GitDiffGutter : Gtk.SourceGutterRenderer {
        private GLib.File repo_path;
        private Ggit.Repository? git_repo = null;
        private Ggit.Diff workdir_diff_List;
        private Gee.HashSet<int> lines_with_additions;
        private Gee.HashSet<int> lines_with_deletions;
        private Gdk.RGBA gutter_color;
        private string open_file_path = "src/Widgets/GitDiffGutter.vala";

        public GitDiffGutter () {
            stdout.printf("MAKING NEW DIFF GUTTER\n");
            try {
                repo_path = GLib.File.new_for_path ("/home/puffin/code/code");
                git_repo = Ggit.Repository.open (repo_path);
                workdir_diff_List = new Ggit.Diff.index_to_workdir (git_repo, null, null);
            } catch (GLib.Error e) {
                stdout.printf("Error trying to open repo: %s\n", e.message);
            }
            lines_with_additions = new Gee.HashSet<int> ();
            lines_with_deletions = new Gee.HashSet<int> ();
            gutter_color = Gdk.RGBA ();
            this.set_size(10);
            this.set_visible (true);
        }

        public override void draw (Cairo.Context cr, Gdk.Rectangle bg, Gdk.Rectangle area, Gtk.TextIter start, Gtk.TextIter end, Gtk.SourceGutterRendererState state) {
            base.draw (cr, bg, area, start, end, state);
            int gutter_line_no = start.get_line () + 2;
            if (lines_with_additions.contains (gutter_line_no)) {
                gutter_color.parse ("rgba(0,256,0,1)");
                this.set_background (gutter_color);
            }
            else if (lines_with_deletions.contains (gutter_line_no)) {
                gutter_color.parse ("rgba(256,0,0,1)");
                this.set_background (gutter_color);
            } else {
                gutter_color.parse ("rgba(0,0,0,0)");
                this.set_background (gutter_color);
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
            Ggit.DiffLineType type_of_change = delta.get_status ();
            string diff_file_path = file_diff.get_path ();
            int new_diff_line_no = line.get_new_lineno ();
            int old_diff_line_no = line.get_old_lineno ();
            stdout.printf ("path: %s\n", diff_file_path);
            
            if(type_of_change == Ggit.DiffLineType.ADDITION) {
                stdout.printf("ADDED: %d or %d\n", new_diff_line_no, old_diff_line_no);
            } else if(type_of_change == Ggit.DeltaType.DELETION) {
                stdout.printf("DELETED: %d or %d\n", new_diff_line_no, old_diff_line_no);
            } else if(type_of_change == Ggit.DeltaType.MODIFIED) {
                stdout.printf("MODIFIED: %d or %d\n", new_diff_line_no, old_diff_line_no);
            }

            if (diff_file_path == open_file_path && type_of_change == Ggit.DeltaType.ADDED) {
                lines_with_additions.add (new_diff_line_no);
            } else if (diff_file_path == open_file_path && type_of_change == Ggit.DeltaType.DELETED) {
                lines_with_deletions.add (old_diff_line_no);
            }
            return 0;
        }

        public void print_lines_with_additions () {
            foreach (int line_no in lines_with_additions) {
                stdout.printf ("%d\n", line_no);
            }
        }

        public void print_lines_with_deletions () {
            foreach (int line_no in lines_with_deletions) {
                stdout.printf ("%d\n", line_no);
            }
        }


        public void make_diff () {
            stdout.printf("MAKE_DIFF()\n");
            workdir_diff_List.foreach (diff_file_callback, diff_binary_callback, diff_hunk_callback, diff_line_callback);
        }

    }
}
