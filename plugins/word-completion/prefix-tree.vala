
namespace Scratch.Plugins {
    public class PrefixNode : Object {
        private enum NodeType {
            ROOT,
            CHAR,
            WORD_END
        }

        public Gee.ArrayList<PrefixNode> children;
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
                return type != WORD_END && children.size > 0;
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
            children = new Gee.ArrayList<PrefixNode> ();
        }

        public bool has_char (unichar c) {
            return uc == c;
        }

        private void increment () requires (type == WORD_END) {
            occurrences++;
        }

        private void decrement () requires (type == WORD_END && occurrences > 0) {
            occurrences--;
            if (occurrences == 0) {
                critical ("remove after decrement");
                parent.remove_child (this);
            }
        }

        private void append_child (owned PrefixNode child) requires (type != WORD_END) {
            children.add (child);
        }

        private void remove_child (PrefixNode child) requires (type != WORD_END) {
            children.remove (child);
        }

        public void remove_word_end () requires (this.has_children) {
            foreach (var child in children) {
                if (child.is_word_end) {
                    child.decrement ();
                    return;
                }
            }
        }

        public void insert_word_end () requires (!this.is_word_end && !this.is_root) {
            foreach (var child in children) {
                if (child.type == WORD_END) {
                    child.increment ();
                    return;
                }
            }

            var new_child = new PrefixNode.word_end (this);
            append_child (new_child);
        }

        public PrefixNode append_char_child (unichar c) requires (!this.is_word_end) {
            foreach (var child in children) {
                if (child.has_char (c)) {
                    return child;
                }
            }

            var new_child = new PrefixNode.from_unichar (c, this);
            append_child (new_child);
            return new_child;
        }

        public PrefixNode? has_char_child (unichar c) requires (!this.is_word_end) {
            foreach (var child in children) {
                if (child.has_char (c)) {
                    return child;
                }
            }

            return null;
        }
    }

    public class PrefixTree : Object {
        private PrefixNode? root = null;
        public bool initial_parse_complete = false;

        construct {
            warning ("construct prefix tree");
            clear ();
        }

        public void clear () {
            root = new PrefixNode.root ();
            initial_parse_complete = false;
        }

        public void insert (string word) {
            if (word.length == 0) {
                return;
            }

            this.insert_at (word, this.root);
        }

        private void insert_at (string word, PrefixNode node, int i = 0) requires (!node.is_word_end) {
            unichar curr = '\0';
            if (!word.get_next_char (ref i, out curr) || curr == '\0') {
                node.insert_word_end ();
                return;
            }

            var child = node.append_char_child (curr);
            insert_at (word, child, i);
        }

        public void remove (string word) requires (word.length > 0) {
            if (word.length == 0) {
                return;
            }

            var word_node = find_prefix_at (word, root);

            if (word_node != null) {
                word_node.remove_word_end (); // Will autoremove unused parents
            }
        }

        public bool find_prefix (string prefix) {
            return find_prefix_at (prefix, root) != null ? true : false;
        }

        private PrefixNode? find_prefix_at (string prefix, PrefixNode node, int i = 0) {
            unichar curr;

            if (!prefix.get_next_char (ref i, out curr)) {
                return node;
            }

            var child = node.has_char_child (curr);
            if (child != null) {
                return find_prefix_at (prefix, child, i);
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
