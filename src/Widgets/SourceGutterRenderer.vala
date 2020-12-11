namespace Scratch.Widgets {
    public class SourceGutterRenderer : Gtk.SourceGutterRenderer {
        private Ggit.Diff? repo_diff_list = null;
        // Use the previously seen diff to compare with the current diff to determine the "type" of diff
        private Ggit.DiffLine previous_line_diff = null;

        // This keeps track of what lines had which kind of modification 
        // (either new additions, modifying an existing line, or deleting lines)
        private Gee.HashMap<int, string> lines_to_status;

        // Use this to represent the color of a cell in the gutter before it is drawn
        private Gdk.RGBA gutter_color;

        private string workdir_path = null;
        private string doc_path = null;

        // Use these to note what lines were modified, which lines are newly added, which lines were removed.
        private const string ADDED = "GREEN";
        private const string MODIFIED = "BLUE";
        private const string DELETED = "RED";//

        public bool git_repo_set { get {return workdir_path != null;}}

        public SourceGutterRenderer () {
            debug ("MAKING NEW DIFF GUTTER\n");

            lines_to_status = new Gee.HashMap<int, string> ();
            gutter_color = Gdk.RGBA ();
            set_size (3);
            set_visible (true);
        }

        public void set_git_repo (Ggit.Repository? repo) {
            workdir_path = "";
            if (repo != null) {
                workdir_path = repo.workdir.get_path ();
                try {
                    repo_diff_list = new Ggit.Diff.index_to_workdir (repo, null, null);
                } catch (Error e) {
                    critical ("Error getting diff list %s", e.message);
                    workdir_path = "";
                }
            }
        }

        // Here we take advantage of the method that draws each cell in the gutter
        // to determine if said line has been modified in some way. If it has,
        // we set the cell's color appropriately.
        public override void draw (Cairo.Context cr,
                                   Gdk.Rectangle bg,
                                   Gdk.Rectangle area,
                                   Gtk.TextIter start,
                                   Gtk.TextIter end,
                                   Gtk.SourceGutterRendererState state) {

            base.draw (cr, bg, area, start, end, state);
            var gutter_line_no = start.get_line () + 2; // For some reason, all the diffs are off by two lines...?
            gutter_color.parse ("rgba(0,0,0,0)");

            if (lines_to_status.has_key (gutter_line_no)) {
                switch (lines_to_status.get (gutter_line_no)) {
                    case ADDED:
                        gutter_color.parse ("#68b723");
                        break;
                    case MODIFIED:
                        gutter_color.parse ("#f37329");
                        break;
                    case DELETED:
                        gutter_color.parse ("#c6262e");
                        break;
                    default:
                        break;
                }
            }

            set_background (gutter_color);
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

        private bool is_modified (Ggit.DiffLine line) {
            if (previous_line_diff != null) {
                // In order to be a modified line they need to be "opposites" of each other
                return (is_addition (line) != is_addition (previous_line_diff)) &&
                       (is_deletion (line) != is_deletion (previous_line_diff));
            }

            return false;
        }

        private bool is_addition (Ggit.DiffLine line) {
            return line.get_origin () == Ggit.DiffLineType.ADDITION;
        }

        private bool is_deletion (Ggit.DiffLine line) {
            return line.get_origin () == Ggit.DiffLineType.ADDITION;
        }

        private bool is_deleted (Ggit.DiffLine line) {
            if (previous_line_diff != null) {
                // We will color the current line red if the previous line looked like a deleted diff-line.
                return (is_addition (line) == is_addition (previous_line_diff)) &&
                       (is_deletion (line) != is_deletion (previous_line_diff));
            }

            return false;
        }

        // We look through every diff line of the repo (unfortunately...) and determine if 
        // the diff is for the file that is in focus. Then we determine the kind of modification,
        // and save it with the line number. That way we have line numbers mapped to modifications
        // when it comes time to draw the gutter's cells.
        private int diff_line_callback (Ggit.DiffDelta delta, Ggit.DiffHunk? hunk, Ggit.DiffLine line) {
            Ggit.DiffFile? file_diff = delta.get_old_file ();
            string? diff_file_path = null;
            if (file_diff != null) {
                diff_file_path = file_diff.get_path ();
            }

            // Only process the diff if its for the file in focus.
            if (diff_file_path == null ||
                !(doc_path.has_suffix (diff_file_path))) {
                return 0;
            }

            if (is_modified (line)) {
                lines_to_status.set (line.get_new_lineno (), MODIFIED);
            } else if (is_addition (line)) {

                lines_to_status.set (line.get_new_lineno (), ADDED);
            } else if (is_deleted (line)) {

                lines_to_status.set (line.get_new_lineno (), DELETED);
            }

            previous_line_diff = line;
            return 0;
        }

        private bool loading = false;
        public void reload (string doc_path) {
            if (loading) {
                return;
            } else {
                loading = true;
            }

            lines_to_status.clear ();
            if (repo_diff_list == null) {
                return;
            }

            debug ("Reloading with: %s\n", doc_path);
            this.doc_path = doc_path;
            try {
                repo_diff_list.foreach (
                    diff_file_callback, diff_binary_callback, diff_hunk_callback, diff_line_callback
                );
            } catch (Error e) {
                warning ("Error getting repo diff %s", e.message);
            } finally {
                loading = false;
            }
        }
    }
}
