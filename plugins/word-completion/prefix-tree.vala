
namespace Scratch.Plugins {
    public class PrefixTree : Object {
        private PrefixNode root;

        construct {
            clear ();
        }

        public void clear () {
            root = new PrefixNode ();
        }

        public void insert (string word) {
            if (word.length == 0) {
                return;
            }

            this.insert_at (word, this.root);
        }

        private void insert_at (string word, PrefixNode node, int i = 0) {
            unichar curr = '\0';

            bool has_next_character = false;
            do {
                has_next_character = word.get_next_char (ref i, out curr);
            } while (has_next_character && Euclide.Completion.Parser.is_delimiter (curr));

            foreach (var child in node.children) {
                if (child.value == curr) {
                    if (curr != '\0') {
                        insert_at (word, child, i);
                    }
                    return;
                }
            }

            var new_child = new PrefixNode.from_unichar (curr, null);
            node.children.insert (0, new_child);
            node.children.sort ((c1, c2) => {
                if (c1.value > c2.value) {
                    return 1;
                } else if (c1.value == c2.value) {
                    return 0;
                }
                return -1;
            });
            if (curr != '\0') {
                insert_at (word, new_child, i);
            }
        }

        public bool find_prefix (string prefix) {
            return find_prefix_at (prefix, root) != null? true : false;
        }

        private PrefixNode? find_prefix_at (string prefix, PrefixNode node, int i = 0) {
            unichar curr;

            prefix.get_next_char (ref i, out curr);
            if (curr == '\0') {
                return node;
            }

            foreach (var child in node.children) {
                if (child.value == curr) {
                    return find_prefix_at (prefix, child, i);
                }
            }

            return null;
        }

        public List<string> get_all_matches (string prefix) {
            var list = new List<string> ();
            var node = find_prefix_at (prefix, root, 0);
            if (node != null) {
                var sb = new StringBuilder (prefix);
                get_all_matches_rec (node, ref sb, ref list);
            }

            return list;
        }

        private void get_all_matches_rec (
                    PrefixNode node,
                    ref StringBuilder sbuilder,
                    ref List<string> matches) {

            foreach (var child in node.children) {
                if (child.value == '\0') {
                    matches.append (sbuilder.str);
                } else {
                    sbuilder.append_unichar (child.value);
                    get_all_matches_rec (child, ref sbuilder, ref matches);
                    var length = child.value.to_string ().length;
                    sbuilder.erase (sbuilder.len - length, -1);
                }
            }
        }
    }
}
