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

public enum Scratch.SaveReason {
    USER_REQUEST,
    TAB_CLOSING,
    APP_CLOSING,
    AUTOSAVE,
    FOCUS_OUT
}
public enum Scratch.SaveStatus {
    SAVED,
    UNSAVED,
    SAVING,
    SAVE_ERROR
}

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
    public bool save_request (Document doc, Scratch.SaveReason reason) {
warning ("save request reason %s", reason.to_string ());
        if (doc.inhibit_saving) {
            //TODO Confirm with user whether to proceed?
            return true;
        }

        var buffer_modified = doc.source_view.buffer.get_modified ();
        var autosave_on = Scratch.settings.get_boolean ("autosave");
        if (reason == SaveReason.AUTOSAVE) {
            if (autosave_on) {
                if (!doc_timeout_map.has_key (doc)) {
                    doc_timeout_map[doc] = Timeout.add (AUTOSAVE_RATE_MSEC, () => {
                        if (doc.delay_autosaving || doc.is_saving) {
                            doc.delay_autosaving = false;
                            return Source.CONTINUE;
                        }

                        start_to_save (doc, reason);
                        doc_timeout_map.unset (doc);
                        return Source.REMOVE;
                    });
                } else {
                    doc.delay_autosaving = true;
                }
            } else {
                remove_autosave_for_doc (doc);
            }

            return true;
        } 

        remove_autosave_for_doc (doc);

        bool confirm, closing;
        switch (reason) {
            case USER_REQUEST:
            case AUTOSAVE:
            case FOCUS_OUT:
                confirm = false;
                closing = false;
                break;
            case TAB_CLOSING:
            case APP_CLOSING:
                if (buffer_modified) {
                    if (!doc.is_file_temporary) {
                        confirm = !autosave_on;
                    } else {
                        //Always give opportunity to save as permanent file
                        confirm = true;
                    }
                } else {
                    confirm = false;
                }
                
                break;
            default:
                assert_not_reached ();
        }

        if (confirm) {
            bool save_changes;
            if (!query_save_changes (doc, out save_changes)) {
                // User cancelled operation
                return false;
            }

            if (!save_changes && doc.is_file_temporary) {
                //User chose to discard the temporary file rather than save
                delete_doc_file (doc);
                return true;
            }
        }

        start_to_save (doc, reason);
        //Saving was successfully started (but may yet fail asynchronously)
        return true;
    }

    private void remove_autosave_for_doc (Document doc) {
        if (doc_timeout_map.has_key (doc)) {
            Source.remove (doc_timeout_map[doc]);
            doc_timeout_map.unset (doc);
        }
    }

    private void start_to_save (Document doc, SaveReason reason) {
warning ("start to save");
        //Assume buffer was editable if a save request was generated
        doc.before_undoable_change ();
        if (reason != SaveReason.AUTOSAVE &&
            reason != SaveReason.FOCUS_OUT &&
            Scratch.settings.get_boolean ("strip-trailing-on-save")) {

            strip_trailing_spaces_before_save (doc);
        }

        // Saving to the location given in the doc source file will be attempted
        save_doc.begin (doc, reason, (obj, res) => {
            try {
                if (save_doc.end (res)) {
                    doc.set_saved_status (true);
                    doc.source_view.buffer.set_modified (false);
                    doc.last_save_content = doc.source_view.buffer.text;
                    
                    if (doc.outline != null) {
                        doc.outline.parse_symbols ();
                    }
                    debug ("File \"%s\" saved successfully", doc.get_basename ());
                }
            } catch (Error e) {
                if (e.code != 19) { // Not cancelled
                    //TODO Inform user of failure
                    critical (
                        "Cannot save \"%s\": %s",
                        doc.get_basename (),
                        e.message
                    );
                    doc.set_saved_status (false);
                }
            } finally {
                doc.after_undoable_change ();
            }
        });
    }
    // This must only be called when the save is expected to succeed
    // It is expected that the document buffer will not change during this process
    // Any stripping or other automatic change has already taken place
    private async bool save_doc (Document doc, SaveReason reason) throws Error {
warning ("save doc");
        var save_buffer = new Gtk.SourceBuffer (null);
        var source_buffer = (Gtk.SourceBuffer)(doc.source_view.buffer);
        save_buffer.text = source_buffer.text;
        create_doc_backup (doc);
        // Replace old content with the new one
        //TODO Handle cancellables internally
        doc.save_cancellable.cancel ();
        doc.save_cancellable = new GLib.Cancellable ();
        var source_file_saver = new Gtk.SourceFileSaver (
            source_buffer,
            doc.source_file
        );

        if (reason == SaveReason.APP_CLOSING) {
            GLib.Application.get_default ().hold ();
        }

        var success = yield source_file_saver.save_async (
            GLib.Priority.DEFAULT,
            doc.save_cancellable,
            null
        );

        if (reason == SaveReason.APP_CLOSING) {
            GLib.Application.get_default ().release ();
        }
        
        return success;
    }

    private void create_doc_backup (Document doc) {
warning ("create doc backup");
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

    private void strip_trailing_spaces_before_save (Document doc) {
warning ("strup ");
        var source_buffer = (Gtk.SourceBuffer)(doc.source_view.buffer);
        var text = source_buffer.text;
        string[] lines = Regex.split_simple ("""[\r\n]""", text);
        if (lines.length == 0) { // Can legitimately happen at startup or new document
            return;
        }

        if (lines.length != source_buffer.get_line_count ()) {
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
                source_buffer.get_iter_at_line (out start_delete, line_no);
                start_delete.forward_to_line_end ();
                end_delete = start_delete;
                end_delete.backward_chars (info.fetch (0).length);
                source_buffer.@delete (ref start_delete, ref end_delete);
            }
        }
    }

    private bool delete_doc_file (Document doc) {
        try {
            doc.file.delete ();
            return true;
        } catch (Error e) {
            warning ("Cannot delete temporary file \"%s\": %s", doc.file.get_uri (), e.message);
        }

        return false;
    }
      
    private bool query_save_changes (Document doc, out bool save_changes) {
warning ("query save");
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
            default:
                assert_not_reached ();
        }

        dialog.destroy ();
        return close_document;
    }
}
