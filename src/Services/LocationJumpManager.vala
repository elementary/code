/*  
 * SPDX-License-Identifier: GPL-3.0-or-later  
 * SPDX-FileCopyrightText: 2023 elementary, Inc. <https://elementary.io>  
 *
 * Authored by: Colin Kiama <colinkiama@gmail.com>
 */

namespace Scratch {
    public class LocationJumpManager : GLib.Object {
        public GLib.File file { get; set; }
        public SelectionRange range { get; set; }

        public bool has_override_target () {
            if (file == null) {
                return false;
            }

            bool is_override_target = false;

            if (privacy_settings.get_boolean ("remember-recent-files")) {
                var doc_infos = settings.get_value ("opened-files");
                var doc_info_iter = new VariantIter (doc_infos);

                string uri;
                int pos;
                while (doc_info_iter.next ("(si)", out uri, out pos)) {
                if (uri != "") {
                        GLib.File file_to_restore;
                        if (Uri.parse_scheme (uri) != null) {
                            file_to_restore = File.new_for_uri (uri);
                        } else {
                            file_to_restore = File.new_for_commandline_arg (uri);
                        }

                        if (file_to_restore.query_exists () && file_to_restore.get_path () == file.get_path ()) {
                            is_override_target = true;
                            break;
                        }
                    }
                }
            }

            return is_override_target;
        }

        public RestoreOverride create_restore_override () {
            return new RestoreOverride (file, range);
        }

        public void clear () {
            range = SelectionRange.EMPTY;
            file = null;
        }

        public bool has_selection_range () {
            return range != SelectionRange.EMPTY;
        }

        public bool parse_selection_range_string (string selection_range_string) {
            Regex go_to_line_regex = /^(?<start_line>[0-9]+)+(?:\.(?<start_column>[0-9]+)+)?(?:-(?:(?<end_line>[0-9]+)+(?:\.(?<end_column>[0-9]+)+)?))?$/;  // vala-lint=space-before-paren, line-length
                MatchInfo match_info;
                if (go_to_line_regex.match (selection_range_string, 0, out match_info)) {
                    range = parse_go_to_range_from_match_info (match_info);
                    debug ("Selection Range - start_line: %d", range.start_line);
                    debug ("Selection Range - start_column: %d", range.start_column);
                    debug ("Selection Range - end_line: %d", range.end_line);
                    debug ("Selection Range - end_column: %d", range.end_column);
                }

            return true;
        }

        private static SelectionRange parse_go_to_range_from_match_info (GLib.MatchInfo match_info) {
            return SelectionRange () {
                start_line = parse_num_from_match_info (match_info, "start_line"),
                end_line = parse_num_from_match_info (match_info, "end_line"),
                start_column = parse_num_from_match_info (match_info, "start_column"),
                end_column = parse_num_from_match_info (match_info, "end_column"),
            };
        }

        private static int parse_num_from_match_info (MatchInfo match_info, string match_name) {
            var str = match_info.fetch_named (match_name);
            int num = 0;

            if (str != null) {
                int.try_parse (str, out num);
            }

            return num;
        }
    }
}
