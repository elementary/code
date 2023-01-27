// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2022 elementary LLC. (https://elementary.io),
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License version 3
 * as published by the Free Software Foundation, either version 3 of the
 * License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranties of
 * MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
 * PURPOSE. See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Authored by: Jeremy Wootten <jeremy@elementaryos.org>
 */

 public class Scratch.Services.DocumentManager : Object {
    static Gee.HashMultiMap <string, string> project_restorable_docs_map;
    static Gee.HashMultiMap <string, string> project_open_docs_map;
    static Gee.HashMap <Document, uint> doc_timeout_map;
    uint AUTOSAVE_RATE_MSEC = 1000;

    static DocumentManager? instance;
    public static DocumentManager get_instance () {
         if (instance == null) {
             instance = new DocumentManager ();
         }

         return instance;
     }

    static construct {
        project_restorable_docs_map = new Gee.HashMultiMap<string, string> ();
        project_open_docs_map = new Gee.HashMultiMap<string, string> ();
        doc_timeout_map = new Gee.HashMap <Document, uint> ();
    }

    public void make_restorable (Document doc) {
        project_restorable_docs_map.@set (doc.source_view.project.path, doc.file.get_path ());
    }

    public void add_open_document (Document doc) {
        if (doc.source_view.project == null) {
            return;
        }

        project_open_docs_map.@set (doc.source_view.project.path, doc.file.get_path ());
    }

    public void remove_open_document (Document doc) {
        if (doc.source_view.project == null) {
            return;
        }

        project_open_docs_map.remove (doc.source_view.project.path, doc.file.get_path ());
    }

    public void remove_project (string project_path) {
        project_restorable_docs_map.remove_all (project_path);
    }

    public Gee.Collection<string> take_restorable_paths (string project_path) {
        var docs = project_restorable_docs_map.@get (project_path);
        project_restorable_docs_map.remove_all (project_path);
        return docs;
    }

    public uint restorable_for_project (string project_path) {
        return project_restorable_docs_map.@get (project_path).size;
    }

    public uint open_for_project (string project_path) {
        return project_open_docs_map.@get (project_path).size;
    }

    /* Code to manage safe saving of documents */
    /*******************************************/

    // @force is "true" when tab or app is closing or when user activated "action-save"
    // Returns "false" if operation cancelled by user
    public bool save_request (Document doc, bool force) {
        if (doc.inhibit_saving) {
            //TODO Confirm with user whether to proceed?
            return true;
        }

        var autosave = Scratch.settings.get_boolean ("autosave");
        // Always save on closing. Otherwise only if autosave active.
        if (!(force || autosave)) {
            // Comes here when changed
            return true;
        }

        if (force) {
            if (doc_timeout_map.has_key (doc)) {
                Source.remove (doc_timeout_map[doc]);
                doc_timeout_map.unset (doc);
            }
            if (doc.source_view.buffer.get_modified ()) {
                bool save_changes;
                if (!query_save_changes (doc, out save_changes)) {
                    return false;
                }

                if (!save_changes) {
                    delete_if_temporary (doc);
                    return true;
                }
            }

            save_doc (doc, true);
        } else if (!doc_timeout_map.has_key (doc)) {
            // Autosaving - need to create new timeout
           doc_timeout_map[doc] = Timeout.add (AUTOSAVE_RATE_MSEC, () => {
                if (doc.delay_saving || doc.is_saving) {
                    return Source.CONTINUE;
                }
                warning ("autosave doc %s", doc.file.get_path ());
                save_doc (doc, false);
                doc_timeout_map.unset (doc);
                return Source.REMOVE;
           });
        }

        return true;
    }

    // This must only be called when the save is expected to succeed
    // e.g. during autosave.
    private void save_doc (Document doc, bool with_hold) {
        var save_buffer = new Gtk.SourceBuffer (null);
        var source_buffer = (Gtk.SourceBuffer)(doc.source_view.buffer);
        save_buffer.text = source_buffer.text;
        doc.before_undoable_change ();

        if (Scratch.settings.get_boolean ("strip-trailing-on-save") &&
            doc.source_view.language != null) {
            Gtk.TextIter iter;
            var cursor_pos = source_buffer.cursor_position;
            source_buffer.get_iter_at_offset (out iter, cursor_pos);
            var orig_line = iter.get_line ();
            var orig_offset = iter.get_line_offset ();
            strip_trailing_spaces_before_save (save_buffer);
            source_buffer.begin_not_undoable_action ();
                source_buffer.text = save_buffer.text;
                source_buffer.get_iter_at_line_offset (
                    out iter,
                    orig_line,
                    orig_offset
                );
                source_buffer.place_cursor (iter);
            source_buffer.end_not_undoable_action ();
        }

        create_doc_backup (doc);
        // Replace old content with the new one
        //TODO Handle cancellables internally
        doc.save_cancellable.cancel ();
        doc.save_cancellable = new GLib.Cancellable ();
        var source_file_saver = new Gtk.SourceFileSaver (
            source_buffer,
            doc.source_file
        );

        if (with_hold) {
            GLib.Application.get_default ().hold ();
        }
        source_file_saver.save_async.begin (
            GLib.Priority.DEFAULT,
            doc.save_cancellable,
            null,
            (obj, res) => {
                try {
                    if (source_file_saver.save_async.end (res)) {
                        doc.set_saved_status (true);
                        debug ("File \"%s\" saved successfully", doc.get_basename ());
                    }

                    doc.after_undoable_change ();
                } catch (Error e) {
                    if (e.code != 19) { // Not cancelled
                        critical (
                            "Cannot save \"%s\": %s",
                            doc.get_basename (),
                            e.message
                        );
                    }
                } finally {
                    if (with_hold) {
                        GLib.Application.get_default ().release ();
                    }
                }
            }
        );
    }

        // // Backup functions
        // private void create_backup () {
        //     if (!can_write ()) {
        //         return;
        //     }

        //     var backup = File.new_for_path (this.file.get_path () + "~");

        //     if (!backup.query_exists ()) {
        //         try {
        //             file.copy (backup, FileCopyFlags.NONE);
        //         } catch (Error e) {
        //             warning ("Cannot create backup copy for file \"%s\": %s", get_basename (), e.message);
        //         }
        //     }
        // }

    private void create_doc_backup (Document doc) {
        if (!doc.can_write ()) {
            return;
        }

        var backup = File.new_for_path (doc.file.get_path () + "~");
        if (!backup.query_exists ()) {
            try {
                doc.file.copy (backup, FileCopyFlags.NONE);
            } catch (Error e) {
                warning ("Cannot create backup copy for file \"%s\": %s", doc.get_basename (), e.message);
            }
        }
    }

    private void strip_trailing_spaces_before_save (Gtk.SourceBuffer save_buffer) {
        var text = save_buffer.text;
        string[] lines = Regex.split_simple ("""[\r\n]""", text);
        if (lines.length == 0) { // Can legitimately happen at startup or new document
            return;
        }

        if (lines.length != save_buffer.get_line_count ()) {
            critical ("Stripping: Mismatch between line counts, not continuing");
            return;
        }

        MatchInfo info;
        Gtk.TextIter start_delete, end_delete;
        Regex whitespace;

        try {
            whitespace = new Regex ("[ \t]+$", 0);
        } catch (RegexError e) {
            critical ("Stripping: error building regex: %s", e.message);
            assert_not_reached (); // Regex is constant so trap errors on dev
        }

        for (int line_no = 0; line_no < lines.length; line_no++) {
            if (whitespace.match (lines[line_no], 0, out info)) {
                save_buffer.get_iter_at_line (out start_delete, line_no);
                start_delete.forward_to_line_end ();
                end_delete = start_delete;
                end_delete.backward_chars (info.fetch (0).length);


                save_buffer.@delete (ref start_delete, ref end_delete);

            }
        }
    }

    private bool delete_if_temporary (Document doc) {
        if (!doc.is_file_temporary) {
            return false;
        }

        try {
            doc.file.delete ();
            return true;
        } catch (Error e) {
            warning ("Cannot delete temporary file \"%s\": %s", doc.file.get_uri (), e.message);
        }

        return false;
    }

    private bool query_save_changes (Document doc, out bool save_changes) {
        var parent_window = doc.source_view.get_toplevel () as Gtk.Window;
        var dialog = new Granite.MessageDialog (
            _("Save changes to \"%s\" before closing?").printf (doc.get_basename ()),
            _("If you don't save, changes will be permanently lost."),
            new ThemedIcon ("dialog-warning"),
            Gtk.ButtonsType.NONE
        );
        dialog.transient_for = parent_window;
        var no_save_button = (Gtk.Button) dialog.add_button (
            _("Close Without Saving"),
            Gtk.ResponseType.NO
        );
        no_save_button.get_style_context ().add_class (Gtk.STYLE_CLASS_DESTRUCTIVE_ACTION);
        dialog.add_button (_("Cancel"), Gtk.ResponseType.CANCEL);
        dialog.add_button (_("Save"), Gtk.ResponseType.YES);
        dialog.set_default_response (Gtk.ResponseType.YES);
        int response = dialog.run ();
        bool close_document = false;
        switch (response) {
            case Gtk.ResponseType.CANCEL:
            case Gtk.ResponseType.DELETE_EVENT:
                save_changes = false;
                close_document = false;
                break;
            case Gtk.ResponseType.YES:
                save_changes = true;
                close_document = true;
                break;
            case Gtk.ResponseType.NO:
                save_changes = false;
                close_document = true;
                break;
        }

        dialog.destroy ();
        return close_document;
    }
}
