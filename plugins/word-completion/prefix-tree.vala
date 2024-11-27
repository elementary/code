
namespace Scratch.Plugins {

    private class PrefixNode : Object {
        private enum NodeType {
            ROOT,
            CHAR,
            WORD_END
        }

        public GLib.List<PrefixNode> children;
        private unichar? uc = null;
        private NodeType type = ROOT;
        public uint occurrences { get; set construct; default = 0; }
        public PrefixNode? parent { get; construct; default = null; }

        public bool is_word_end {
            get {
                return type == WORD_END;
            }
        }

        public bool is_root {
            get {
                return type == ROOT;
            }
        }

        public uint length {
            get {
                return char_s.length;
            }
        }

        public string char_s {
            owned get {
                if (uc != null) {
                    return uc.to_string ();
                } else {
                    return "";
                }
            }
        }

        public bool has_children {
            get {
                return type != WORD_END && children.first ().data != null;
            }
        }

        public PrefixNode.from_unichar (unichar c, PrefixNode? _parent) requires (c != '\0') {
            Object (
                parent: _parent,
                occurrences: 1
            );

            uc = c;
            type = CHAR;
        }

        public PrefixNode.root () {
            Object (
                parent: null,
                occurrences: 0
            );

            type = ROOT;
        }

        public PrefixNode.word_end (PrefixNode _parent) {
            Object (
                parent: _parent,
                occurrences: 1
            );

            uc = '\0';
            type = WORD_END;
        }

        construct {
            children = new List<PrefixNode> ();
        }

        public bool has_char (unichar c) {
            return uc == c;
        }

        private void increment () requires (type == WORD_END && occurrences < Scratch.MAX_TOKENS) {
            occurrences++;
        }

        public void decrement () requires (type != WORD_END && occurrences > 0) {
            occurrences--;
        }

        public void append_child (PrefixNode child) requires (type != WORD_END) {
            children.append (child);
        }

        public void remove_child (PrefixNode child) requires (this.has_children) {
            children.remove (child);
            if (children.length () < 1 && parent != null) {
                parent.remove_child (this);
            }
        }

        public void insert_word_end () {
            foreach (var child in children) {
                if (child.is_word_end) {
                    child.increment ();
                    return;
                }
            }

            var new_child = new PrefixNode.word_end (this);
            append_child (new_child);
        }

        public void insert_char_child (unichar c) requires (!this.is_word_end) {
            foreach (var child in children) {
                if (child.has_char (c)) {
                    return;
                }
            }

            var new_child = new PrefixNode.word_end (this);
            append_child (new_child);
        }
    }

    public class PrefixTree : Object {
        private PrefixNode root;

        construct {
            clear ();
        }

        public void clear () {
            root = new PrefixNode.root ();
        }

        public void insert (string word) {
            if (word.length == 0) {
                return;
            }
warning ("prefix tree insert %s", word);
            this.insert_at (word, this.root);
        }

        public void decrement_word_occurrences (string word) {

        }

        private void insert_at (string word, PrefixNode node, int i = 0) requires (!node.is_word_end) {
            unichar curr = '\0';
            if (!word.get_next_char (ref i, out curr) || curr == '\0') {
                insert_word_end_at (node);
                return;
            }

            foreach (var child in node.children) {
                if (child.has_char (curr)) {
                    insert_at (word, child, i);
                    return;
                }
            }

            assert (curr != '\0');
            var new_child = new PrefixNode.from_unichar (curr, node);
            node.append_child (new_child);
            insert_at (word, new_child, i);
        }

        private void insert_word_end_at (PrefixNode node) {
            node.insert_word_end ();
        }

        public void remove (string word) requires (word.length > 0) {
            // if (word.length == 0) {
            //     return;
            // }
            // var word_node = find_prefix_at (word, root);
            // assert (word_node.occurrences > 0);
            // word_node.decrement ();
            // remove_at (word, root, min_deletion_index);
        }

        // private bool remove_at (string word, PrefixNode node, int min_deletion_index, int char_index = 0) {
        //     unichar curr;

        //     word.get_next_char (ref char_index, out curr);
        //     if (curr == '\0') {
        //         return true;
        //     }

        //     foreach (var child in node.children) {
        //         if (child.value == curr) {
        //             bool should_continue = this.remove_at (word, node, min_deletion_index, char_index + 1);

        //             if (should_continue && child.children.length () == 0) {
        //                 node.children.remove (child);
        //                 return char_index < min_deletion_index;
        //             }

        //             break;
        //         }
        //     }

        //     return false;
        // }

        public bool find_prefix (string prefix) {
            return find_prefix_at (prefix, root) != null ? true : false;
        }

        private PrefixNode? find_prefix_at (string prefix, PrefixNode node, int i = 0) {
            unichar curr;

            if (!prefix.get_next_char (ref i, out curr)) {
            // if (curr == '\0') {
                return node;
            }

            foreach (var child in node.children) {
                if (child.has_char (curr)) {
                    return find_prefix_at (prefix, child, i);
                }
            }

            return null;
        }

        public List<string> get_all_matches (string prefix) {
            var list = new List<string> ();
            var node = find_prefix_at (prefix, root, 0);
            if (node != null && !node.is_word_end) {
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
                if (child.is_word_end) {
                    matches.append (sbuilder.str);
                } else {
                    sbuilder.append (child.char_s);
                    get_all_matches_rec (child, ref sbuilder, ref matches);
                    sbuilder.erase (sbuilder.len - child.length, -1);
                }
            }
        }
    }
}
