namespace Scratch.Widgets {
    public class GitDiffGutter : Gtk.SourceGutterRenderer {
        private GLib.File repo_path;
        private Ggit.Repository? git_repo = null;
        private Ggit.Diff workdir_diff_List;
        private Ggit.DiffLine previous_line_diff = null;
        private Gee.HashMap<int, string> lines_to_status;
        private Gdk.RGBA gutter_color;
        private string open_file_path = "src/Widgets/GitDiffGutter.vala";
        private const string ADDED = "GREEN";
        private const string MODIFIED = "BLUE";
        private const string DELETED = "RED";//

        public GitDiffGutter () {
            stdout.printf("MAKING NEW DIFF GUTTER\n");
            try {
                repo_path = GLib.File.new_for_path ("/home/puffin/code/code");
                git_repo = Ggit.Repository.open (repo_path);//
                workdir_diff_List = new Ggit.Diff.index_to_workdir (git_repo, null, null);
            } catch (GLib.Error e) {
                stdout.printf("Error trying to open repo: %s\n", e.message);
            }
            lines_to_status = new Gee.HashMap<int, string> ();
            gutter_color = Gdk.RGBA ();
            this.set_size(3);
            this.set_visible (true);
        }



        public override void draw (Cairo.Context cr, Gdk.Rectangle bg, Gdk.Rectangle area, Gtk.TextIter start, Gtk.TextIter end, Gtk.SourceGutterRendererState state) {
            base.draw (cr, bg, area, start, end, state);
            int gutter_line_no = start.get_line () + 2;
            if (lines_to_status.contains (gutter_line_no)) {
                string change = lines_to_status.get (gutter_line_no);
                if (change == ADDED) {
                    gutter_color.parse ("rgba(0,256,0,1)");
                } else if (change == MODIFIED) {
                    gutter_color.parse ("rgba(0,0,256,1)");
                } else if (change == DELETED) {
                    gutter_color.parse ("rgba(256,0,0,1)");
                }
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

        private bool is_modified (Ggit.DiffLine line) {
            bool is_modified_diff = false;
            if (previous_line_diff != null) {
                // current diff
                Ggit.DiffLineType type_of_change = line.get_origin ();
                bool is_added_line = type_of_change == Ggit.DiffLineType.ADDITION ? true : false;
                bool is_deleted_line = type_of_change == Ggit.DiffLineType.DELETION ? true : false;

                // Compare to previous diff
                Ggit.DiffLineType prev_type_of_change = previous_line_diff.get_origin ();
                bool prev_is_added_line = prev_type_of_change == Ggit.DiffLineType.ADDITION ? true : false;
                bool prev_is_deleted_line = prev_type_of_change == Ggit.DiffLineType.DELETION ? true : false;

                // In order to be a modified line they need to be "opposites" of each other
                bool added_line_opposite = is_added_line != prev_is_added_line;
                bool deleted_line_opposite = is_deleted_line != prev_is_deleted_line;

                is_modified_diff = added_line_opposite && deleted_line_opposite ? true : false;
            }
            return is_modified_diff;
        }

        private bool is_added (Ggit.DiffLine line) {
            Ggit.DiffLineType type_of_change = line.get_origin ();
            return type_of_change == Ggit.DiffLineType.ADDITION ? true : false;
        }

        private bool is_deleted (Ggit.DiffLine line) {
            bool is_deleted = false;
            if (previous_line_diff != null) {
                // current diff
                Ggit.DiffLineType type_of_change = line.get_origin ();
                bool is_added_line = type_of_change == Ggit.DiffLineType.ADDITION ? true : false;
                bool is_deleted_line = type_of_change == Ggit.DiffLineType.DELETION ? true : false;

                // Compare to previous diff
                Ggit.DiffLineType prev_type_of_change = previous_line_diff.get_origin ();
                bool prev_is_added_line = prev_type_of_change == Ggit.DiffLineType.ADDITION ? true : false;
                bool prev_is_deleted_line = prev_type_of_change == Ggit.DiffLineType.DELETION ? true : false;

                // We will color the current line red if the previous line looked like a deleted diff-line.
                bool added_line_equal = is_added_line == prev_is_added_line;
                bool deleted_line_opposite = is_deleted_line != prev_is_deleted_line;

                is_deleted = added_line_equal && deleted_line_opposite;
            }
            return is_deleted;
        }

        private int diff_line_callback (Ggit.DiffDelta delta, Ggit.DiffHunk? hunk, Ggit.DiffLine line) {
            Ggit.DiffFile? file_diff = delta.get_old_file ();
            Ggit.DiffLineType type_of_change = line.get_origin ();

            string diff_file_path = file_diff.get_path ();
            int new_diff_line_no = line.get_new_lineno ();
            int old_diff_line_no = line.get_old_lineno ();
            bool is_added_line = type_of_change == Ggit.DiffLineType.ADDITION ? true : false;
            bool is_deleted_line = type_of_change == Ggit.DiffLineType.DELETION ? true : false;
            string str_is_added_line = type_of_change == Ggit.DiffLineType.ADDITION ? "Yes" : "No";
            string str_is_deleted_line = type_of_change == Ggit.DiffLineType.DELETION ? "Yes" : "No";


            if (is_modified (line)) {
                lines_to_status.set (line.get_new_lineno (), MODIFIED);
            } else if (is_added (line)) {
                lines_to_status.set (line.get_new_lineno (), ADDED);
            } else if (is_deleted (line)) {
                lines_to_status.set (line.get_new_lineno (), DELETED);
            }
            previous_line_diff = line;
            return 0;
            /* Modified an existing line
                is_added_line: No
                is_deleted_line: No
                new_diff_line_no: 18
                old_diff_line_no: 14

                // Modification begins
                is_added_line: No
                is_deleted_line: Yes
                new_diff_line_no: -1
                old_diff_line_no: 15

                is_added_line: Yes
                is_deleted_line: No
                new_diff_line_no: 19
                old_diff_line_no: -1
                // Ends

                is_added_line: No
                is_deleted_line: No
                new_diff_line_no: 20
                old_diff_line_no: 16
            */

            /* Added a completely new line
                // All of these are seperate additions
                is_added_line: Yes
                is_deleted_line: No
                new_diff_line_no: 11
                old_diff_line_no: -1

                is_added_line: Yes
                is_deleted_line: No
                new_diff_line_no: 12
                old_diff_line_no: -1

                is_added_line: Yes
                is_deleted_line: No
                new_diff_line_no: 13
                old_diff_line_no: -1
            */

            /* Deleted a line
                is_added_line: No
                is_deleted_line: No
                new_diff_line_no: 47
                old_diff_line_no: 40

                is_added_line: No
                is_deleted_line: No
                new_diff_line_no: 48
                old_diff_line_no: 41

                // Deleted line
                is_added_line: No
                is_deleted_line: Yes
                new_diff_line_no: -1
                old_diff_line_no: 42

                is_added_line: No
                is_deleted_line: No
                new_diff_line_no: 49
                old_diff_line_no: 43
            */

            /* Untouched lines
                is_added_line: No
                is_deleted_line: No
                new_diff_line_no: 5
                old_diff_line_no: 5

                or


                is_added_line: No
                is_deleted_line: No
                new_diff_line_no: 15
                old_diff_line_no: 11
            */

            //  if (lines_to_status.has_key (line_no)) {
            //      // Seen line before? Line must be modified instead
            //      lines_to_status.set (line_no, MODIFIED);
            //  } else {
            //      // First time seeing a line, record its status
            //      if (is_added_line) {
            //          lines_to_status.set (line_no, ADDED);
            //      } else if (is_deleted_line) {
            //          lines_to_status.set (line_no, DELETED);
            //      }
            //  }

            //  if (diff_file_path == open_file_path) {
            //      stdout.printf("is_added_line: %s\n", str_is_added_line);
            //      stdout.printf("is_deleted_line: %s\n", str_is_deleted_line);
            //      stdout.printf("new_diff_line_no: %d\n", new_diff_line_no);
            //      stdout.printf("old_diff_line_no: %d\n\n", old_diff_line_no);
            //  }

            //  if (diff_file_path == open_file_path && type_of_change == Ggit.DiffLineType.ADDITION) {
            //      lines_with_additions.add (new_diff_line_no);
            //  } else if (diff_file_path == open_file_path && type_of_change == Ggit.DiffLineType.DELETION) {
            //      lines_with_deletions.add (old_diff_line_no);
            //  }
            //  return 0;
        }

        public void print_lines_status () {
            foreach (var line in lines_to_status.entries) {
                stdout.printf ("%d => %s\n", line.key, line.value);
            }
        }


        public void make_diff () {
            stdout.printf("MAKE_DIFF()\n");
            workdir_diff_List.foreach (diff_file_callback, diff_binary_callback, diff_hunk_callback, diff_line_callback);
        }

    }
}
