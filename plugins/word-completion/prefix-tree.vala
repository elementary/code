/*
 * Copyright 2024 elementary, Inc. <https://elementary.io>
 *           2011 Lucas Baudin <xapantu@gmail.com>
 *  *
 * This is a free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; either version 2 of the
 * License, or (at your option) any later version.
 *
 * This is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public
 * License along with this program; see the file COPYING.  If not,
 * write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301 USA.
 *
 */

 public class Scratch.Plugins.PrefixTree : Object {
    private PrefixNode? root = null;
    private GLib.StringBuilder sb;
    private uint reaper_timeout_id = 0;
    private bool delay_reaping = false;
    private const uint REAPING_THROTTLE_MS = 500;
    private bool reaping_cancelled = false;

    public bool initial_parse_complete = false;
    public bool completed { get; set; default = false; }
    public Gee.LinkedList<PrefixNode> words_to_remove { get; construct; }

    construct {
        clear ();
        sb = new GLib.StringBuilder ("");
        words_to_remove = new Gee.LinkedList<PrefixNode> ();
    }

    public void clear () {
        root = new PrefixNode.root ();
        initial_parse_complete = false;
    }

    public void add_word (string word) requires (word.length > 0) {
        debug ("add '%s' to root", word);
        root.insert_word (word);
    }

    public bool has_prefix (string prefix) {
        return root.find_last_node_for (prefix) != null ? true : false;
    }

    public List<string> get_all_completions (string prefix) {
        var list = new List<string> ();
        var node = root.find_last_node_for (prefix);
        if (node != null) {
            sb.erase ();
            node.get_all_completions (ref list, ref sb);
        }

        return (owned)list;
    }



    // public void add_word (string word_to_add) requires (current_tree != null) {
    //     if (is_valid_word (word_to_add)) {
    //         if (current_tree.has_key (word_to_add)) {
    //             var wo = current_tree.@get (word_to_add);
    //             debug ("incrementing");
    //             wo.increment ();
    //         } else {
    //             debug ("adding new %s length %u", word_to_add, word_to_add.length);
    //             current_tree.@set (word_to_add, new WordOccurrence ());
    //         }
    //     } else {
    //         debug ("Not valid to add %s", word_to_add);
    //     }
    // }

    public void remove_word (string word_to_remove) {
        debug ("remove word %s", word_to_remove);
        var end_node = root.find_last_node_for (word_to_remove);
        if (end_node != null && end_node.is_word_end) {
            end_node.decrement ();
            if (!end_node.occurs ()) {
                debug ("schedule remove %s", word_to_remove);
                words_to_remove.add (end_node);
                schedule_reaping ();
            } else {
                debug ("not removing %s", word_to_remove);
            }
        } else {
            debug ("%s not found in tree", word_to_remove);
        }
    }

    // private unowned Gee.LinkedList<string> get_words_to_remove () {
    //     return current_tree.get_data<Gee.LinkedList<string>> (WORDS_TO_REMOVE);
    // }

    private void schedule_reaping () {
        reaping_cancelled = false;
        if (reaper_timeout_id > 0) {
            delay_reaping = true;
            return;
        } else {
            reaper_timeout_id = Timeout.add (REAPING_THROTTLE_MS, () => {
                if (delay_reaping) {
                    delay_reaping = false;
                    return Source.CONTINUE;
                } else {
                    reaper_timeout_id = 0;
                    // var words_to_remove = get_words_to_remove ();
                    debug ("reaping");
                    words_to_remove.foreach ((end_node) => {
                        if (reaping_cancelled) {
                            debug ("reaping was cancelled");
                            return false;
                        }

                        // var wo = current_tree.@get (word);
                        if (!end_node.occurs ()) {
                            end_node.parent.remove_child (end_node); 
                        }

                        return true;
                    });

                    // Cannot remove inside @foreach loop so do it now
                    words_to_remove.clear ();
                    return Source.REMOVE;
                }
            });
        }
    }
}
