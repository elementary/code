const int SEQUENTIAL_BONUS = 15; // bonus for adjacent matches
const int SEPARATOR_BONUS = 30; // bonus if match occurs after a separator
const int CAMEL_BONUS = 30; // bonus if match is uppercase and prev is lower
const int FIRST_LETTER_BONUS = 15; // bonus if the first letter is matched
const int LEADING_LETTER_PENALTY = -5; // penalty applied for every letter in str before the first match
const int MAX_LEADING_LETTER_PENALTY = -15; // maximum penalty for leading letters
const int UNMATCHED_LETTER_PENALTY = -1;


public class Scratch.Services.FuzzyFinder {
    private class RecursiveFinder {
        int recursion_limit;
        int max_matches;
        int recursion_count;

        public RecursiveFinder (int limit = 10, int mx_mtchs = 40) {
            recursion_limit = limit;
            max_matches = mx_mtchs;
            recursion_count = 0;
        }

        private bool limit_reached () {
            return recursion_count >= recursion_limit;
        }

        public SearchResult fuzzy_match_recursive (string pattern, string str, GLib.Cancellable cancellable) {
            var matches = new Gee.ArrayList<int> ();
            return fuzzy_match_recursive_internal (pattern, str, 0, 0, 0, cancellable, matches);
        }

        private SearchResult fuzzy_match_recursive_internal (string pattern, string str, int pattern_current_index, int str_current_index, int next_match,
            GLib.Cancellable cancellable, Gee.ArrayList<int> matches, Gee.ArrayList<int>? src_matches = null) {
            var out_score = 0;
            // Recursion params
            bool recursive_match = false;
            var best_recursive_matches = new Gee.ArrayList<int> ();
            var best_recursive_score = 0;
            // Loop through pattern and str looking for a match.
            bool first_match = true;

            recursion_count++;
            if (cancellable.is_cancelled () || limit_reached ()) {
                return new SearchResult (false, out_score);
            }

            // Return if we reached ends of strings.
            if (pattern_current_index == pattern.length || str_current_index == str.length) {
                return new SearchResult (false, out_score);
            }

            while (pattern_current_index < pattern.length && str_current_index < str.length) {
                if (cancellable.is_cancelled ()) {
                    return new SearchResult (false, out_score);
                }

                var lower_case_char = pattern.get_char (pattern_current_index).tolower ();
                var lower_case_str_char = str.get_char (str_current_index).tolower ();

                // Match found.
                if (lower_case_char == lower_case_str_char) {
                    if (next_match >= max_matches) {
                        return new SearchResult (false, out_score);
                    }

                    if (first_match && src_matches != null) {
                        matches.clear ();
                        matches.insert_all (0, src_matches);
                        first_match = false;
                    }

                    var recursive_matches = new Gee.ArrayList<int> ();
                    var recursive_result_search = fuzzy_match_recursive_internal (
                        pattern,
                        str,
                        pattern_current_index,
                        str_current_index + 1,
                        next_match,
                        cancellable,
                        recursive_matches,
                        matches
                    );

                    if (recursive_result_search.found) {
                        // Pick best recursive score.
                        if (!recursive_match || recursive_result_search.score > best_recursive_score) {
                            best_recursive_matches.clear ();
                            best_recursive_matches.insert_all (0, recursive_matches);
                            best_recursive_score = recursive_result_search.score;
                        }
                        recursive_match = true;
                    }

                    if (matches.size <= next_match) {
                        matches.add (str_current_index);
                    } else {
                        matches[next_match++] = str_current_index;
                    }
                    ++pattern_current_index;
                }
                ++str_current_index;
            }

            var matched = pattern_current_index == pattern.length;
            if (matched) {
                out_score = 100;

                // Apply leading letter penalty
                var penalty = LEADING_LETTER_PENALTY * matches[0];
                penalty =
                penalty < MAX_LEADING_LETTER_PENALTY
                    ? MAX_LEADING_LETTER_PENALTY
                    : penalty;
                out_score += penalty;

                //Apply unmatched penalty
                var unmatched = str.length - next_match;
                out_score += UNMATCHED_LETTER_PENALTY * unmatched;

                // Apply ordering bonuses
                for (var i = 0; i < next_match; i++) {
                    if (cancellable.is_cancelled ()) {
                        return new SearchResult (false, out_score);
                    }

                    var current_index = matches[i];

                    if (i > 0) {
                        var previous_index = matches[i - 1];

                        if (current_index == previous_index + 1) {
                            out_score += SEQUENTIAL_BONUS;
                        }
                    }

                    // Check for bonuses based on neighbor character value.
                    if (current_index > 0) {
                        // Camel case
                        var neighbor = str[current_index - 1];
                        var curr = str[current_index];
                        if (neighbor != neighbor.toupper () && curr != curr.tolower ()) {
                            out_score += CAMEL_BONUS;
                        }
                        var is_neighbour_separator = neighbor == '_' || neighbor == ' ';
                        if (is_neighbour_separator) {
                            out_score += SEPARATOR_BONUS;
                        }
                    } else {
                        // First letter
                        out_score += FIRST_LETTER_BONUS;
                    }
                }

                // Return best result
                if (out_score <= 0) {
                    return new SearchResult (false, out_score);
                } else if (recursive_match && (!matched || best_recursive_score > out_score)) {
                    // Recursive score is better than "this"
                    matches.insert_all (0, best_recursive_matches);
                    out_score = best_recursive_score;
                    return new SearchResult (true, out_score);
                } else if (matched) {
                    // "this" score is better than recursive
                    return new SearchResult (true, out_score);
                } else {
                    return new SearchResult (false, out_score);
                }
            }
            return new SearchResult (false, out_score);
        }
    }

    int recursion_limit;
    int max_matches;
    Gee.HashMap<string, SearchProject> project_paths;

    public FuzzyFinder (Gee.HashMap<string, SearchProject> pps, int limit = 10, int mx_mtchs = 256) {
      max_matches = mx_mtchs;
      recursion_limit = limit;
      project_paths = pps;
    }

    public async Gee.ArrayList<SearchResult> fuzzy_find_async (string search_str, GLib.Cancellable cancellable) {
        var results = new Gee.ArrayList<SearchResult> ();

        SourceFunc callback = fuzzy_find_async.callback;
        new Thread<void> ("fuzzy-find", () => {
            results = fuzzy_find (search_str, cancellable);
            Idle.add ((owned) callback);
        });

        yield;
        return results;
    }

    public Gee.ArrayList<SearchResult> fuzzy_find (string search_str, GLib.Cancellable cancellable) {
        var results = new Gee.ArrayList<SearchResult> ();
        var projects = project_paths.values.to_array ();

        for (int i = 0; i < projects.length; i++) {
            if (cancellable.is_cancelled ()) {
                if (results.size <= 20) {
                    return results;
                }

                return (Gee.ArrayList<SearchResult>) results.slice (0, 20);
            }

            var project = projects[i];

            for (int j = 0; j < project.relative_file_paths.size; j++) {
                if (cancellable.is_cancelled ()) {
                    return results;
                }

                var path = project.relative_file_paths[j];
                SearchResult search_result;

                // If there is more than one project prepend the project name
                // to the front of the path
                // This helps to search for specific files only in one project, e.g.
                // "code/fuzfind" will probably only return fuzzy_finder.vala from this project
                // even if their is a "fuzzy_finder" file in another project
                string project_name = "";
                if (project_paths.size > 1) {
                    project_name = Path.get_basename (project.root_path);
                    search_result = fuzzy_match (search_str, @"$project_name/$path", cancellable);
                } else {
                    search_result = fuzzy_match (search_str, path, cancellable);
                }

                if (search_result.found) {
                    var root_path = project.root_path;
                    search_result.relative_path = path;
                    search_result.full_path = @"$root_path/$path";
                    search_result.project = project_name;
                    results.add (search_result);
                }
            }
        }

        results.sort ((a, b) => {
            return b.score - a.score;
        });

        if (results.size <= 20) {
            return results;
        }

        return (Gee.ArrayList<SearchResult>) results.slice (0, 20);
    }

    private SearchResult fuzzy_match (string pattern, string str, GLib.Cancellable cancellable) {
        var finder = new RecursiveFinder (recursion_limit, max_matches);
        return finder.fuzzy_match_recursive (pattern, str, cancellable);
    }
}
