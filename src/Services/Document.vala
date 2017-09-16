// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/***
  BEGIN LICENSE

  Copyright (C) 2011-2012 Giulio Collura <random.cpp@gmail.com>
                2013      Mario Guerriero <mario@elemnetaryos.org>
  This program is free software: you can redistribute it and/or modify it
  under the terms of the GNU Lesser General Public License version 3, as published
  by the Free Software Foundation.

  This program is distributed in the hope that it will be useful, but
  WITHOUT ANY WARRANTY; without even the implied warranties of
  MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
  PURPOSE.  See the GNU General Public License for more details.

  You should have received a copy of the GNU General Public License along
  with this program.  If not, see <http://www.gnu.org/licenses/>

  END LICENSE
***/

namespace Scratch.Services {

    public enum DocumentStates {
        NORMAL,
        READONLY
    }

    public class Document : Granite.Widgets.Tab {
        private const uint LOAD_TIMEOUT_MSEC = 5000;

        public delegate void VoidFunc ();
        public signal void doc_opened ();
        public signal void doc_saved ();
        public signal void doc_closed ();

        // The parent window's actions
        private weak SimpleActionGroup _actions;
        public SimpleActionGroup actions {
            get {
                return _actions;
            }
            set {
                _actions = value;
            }
        }

        public bool is_file_temporary {
            get {
                return file.get_path ().has_prefix (Application.instance.data_home_folder_unsaved);
            }
        }

        private Gtk.SourceFile source_file;
        public File file {
            get {
                return source_file.location;
            }
            set {
                source_file.set_location (value);
                file_changed ();
            }
        }

        public Scratch.Widgets.SourceView source_view;
        public string original_content;
        public bool saved = true;

        private Gtk.ScrolledWindow scroll;
        private Gtk.InfoBar info_bar;

#if GTKSOURCEVIEW_3_18
        private Gtk.SourceMap source_map;
#endif

        private GLib.Cancellable save_cancellable;
        private GLib.Cancellable load_cancellable;
        private ulong onchange_handler_id = 0; // It is used to not mark files as changed on load
        private bool error_shown = false;
        private bool loaded = false;
        private bool mounted = true; // Mount state of the file
        private Mount mount;

#if HAVE_ZEITGEIST
        // Zeitgeist integration
        private ZeitgeistLogger zg_log = new ZeitgeistLogger();
#endif
        public Document (SimpleActionGroup actions, File? file = null) {
            this.actions = actions;
            this.file = file;
        }

        construct {
            source_view = new Scratch.Widgets.SourceView ();

            scroll = new Gtk.ScrolledWindow (null, null);
            scroll.add (source_view);
            info_bar = new Gtk.InfoBar ();
            source_file = new Gtk.SourceFile ();
#if GTKSOURCEVIEW_3_18
            source_map = new Gtk.SourceMap ();
#endif

            // Handle Drag-and-drop functionality on source-view
            Gtk.TargetEntry uris = {"text/uri-list", 0, 0};
            Gtk.TargetEntry text = {"text/plain", 0, 0};
            Gtk.drag_dest_set (source_view, Gtk.DestDefaults.ALL, {uris, text}, Gdk.DragAction.COPY);

            hide_info_bar ();

            restore_settings ();

            settings.changed.connect (restore_settings);
            /* Block user editing while working */
            source_view.key_press_event.connect (() => {
                return working;
            });

            /* Create as loaded - could be new document */
            loaded = true;
        }

        public void toggle_changed_handlers (bool enabled) {
            if (enabled) {
                onchange_handler_id = this.source_view.buffer.changed.connect (() => {
                    if (onchange_handler_id != 0) {
                        this.source_view.buffer.disconnect (onchange_handler_id);
                    }

                    // Signals for SourceView
                    uint timeout_saving = 0;
                    check_undoable_actions ();
                    this.source_view.buffer.changed.connect (() => {
                        check_undoable_actions ();
                        // Save if autosave is ON
                        if (settings.autosave) {
                            if (timeout_saving > 0) {
                                Source.remove (timeout_saving);
                                timeout_saving = 0;
                            }
                            timeout_saving = Timeout.add (1000, () => {
                                save.begin ();
                                timeout_saving = 0;
                                return false;
                            });
                        }
                     });
                });
            } else if (onchange_handler_id != 0) {
                this.source_view.buffer.disconnect(onchange_handler_id);
            }
        }

        public async bool open () {
            // If it does not exists, let's create it!
            if (!exists ()) {
                try {
                    FileUtils.set_contents (file.get_path (), "");
                } catch (FileError e) {
                    warning ("Cannot create file \"%s\": %s", get_basename (), e.message);
                    return false;
                }
            }

            this.working = true;
            loaded = false;

            /* Loading improper files may hang so we cancel after a certain time as a fallback.
             * In most cases, an error will be thrown and caught. */
            if (load_cancellable != null) { /* just in case */
                load_cancellable.cancel ();
            }

            string content_type = ContentType.from_mime_type (get_mime_type ());

            if (!(ContentType.is_a (content_type, "text/plain"))) {

            var primary_format = _("%s is not a text file.");
            var secondary_text = _("Code will not load this type of file");

#if GRANITE_0_4_1
            var dialog = new Granite.MessageDialog (primary_format.printf (this.get_basename ()),
                                                    secondary_text,
                                                    new ThemedIcon.with_default_fallbacks ("dialog-warning"));
#else
            var dialog = new Gtk.MessageDialog ((Gtk.Window?)source_view.get_toplevel (),
                                                Gtk.DialogFlags.MODAL,
                                                Gtk.MessageType.WARNING,
                                                Gtk.ButtonsType.CANCEL,
                                                "");


                dialog.deletable = false;
                dialog.use_markup = true;

                dialog.text = ("<b>" + primary_format + "</b>").printf (this.get_basename ());
                dialog.format_secondary_markup (secondary_text);
#endif
                dialog.run ();
                dialog.destroy ();
                return false;
            }

            load_cancellable = new Cancellable ();

            while (Gtk.events_pending ()) {
                Gtk.main_iteration ();
            }

            var buffer = new Gtk.SourceBuffer (null); /* Faster to load into a separate buffer */
            source_view.visible = false;

            try {
                var source_file_loader = new Gtk.SourceFileLoader (buffer, source_file);
                yield source_file_loader.load_async (GLib.Priority.LOW, load_cancellable, null);

                source_view.set_text (buffer.text);
                loaded = true;
            } catch (Error e) {
                critical (e.message);
                source_view.buffer.text = "";
                show_error_dialog ();
                return false;
            } finally {
                load_cancellable = null;
            }

            /* Successful load - now do rest of set up */
            this.source_view.buffer.create_tag ("highlight_search_all", "background", "yellow", null);

            toggle_changed_handlers (true);
            // Focus in event for SourceView
            this.source_view.focus_in_event.connect (() => {
                check_file_status ();
                check_undoable_actions ();

                return false;
            });

            // Focus out event for SourceView
            this.source_view.focus_out_event.connect (() => {
                if (settings.autosave) {
                    save.begin ();
                }

                return false;
            });

            // Change syntax highlight
            this.source_view.change_syntax_highlight_from_file (this.file);

#if HAVE_ZEITGEIST
            // Zeitgeist integration
            zg_log.open_insert (file.get_uri (), get_mime_type ());
#endif
            // Grab focus
            this.source_view.grab_focus ();

            source_view.buffer.set_modified (false);
            original_content = source_view.buffer.text;

            this.source_view.buffer.modified_changed.connect (() => {
                if (this.source_view.buffer.get_modified() && !settings.autosave) {
                    this.set_saved_status (false);
                }
            });

            doc_opened ();

            /* Do not stop working (blocks editing) until idle
             * (large documents take time to format/display after loading)
             */
            Idle.add (() => {
                source_view.visible = true;
                this.working = false;
                return false;
            });

            return true;
        }

        public new bool close (bool app_closing = false) {
            message ("Closing \"%s\"", get_basename ());

            if (!loaded) {
                load_cancellable.cancel ();
                return true;
            }

            bool ret_value = true;
            if (app_closing && is_file_temporary && !delete_temporary_file ()) {
                debug ("Save temporary file!");
                this.save.begin ();
            }
            // Check for unsaved changes
            else if (!this.saved || (!app_closing && is_file_temporary && !delete_temporary_file ())) {
                debug ("There are unsaved changes, showing a Message Dialog!");

                // Create a GtkDialog
                var parent_window = source_view.get_toplevel () as Gtk.Window;
                var dialog = new Gtk.MessageDialog (parent_window, Gtk.DialogFlags.MODAL,
                                                    Gtk.MessageType.WARNING, Gtk.ButtonsType.NONE, "");
                dialog.type_hint = Gdk.WindowTypeHint.DIALOG;
                dialog.deletable = false;

                dialog.use_markup = true;

                dialog.text = ("<b>" + _("Save changes to document %s before closing?") +
                               "</b>").printf (this.get_basename ());
                dialog.text += "\n\n" +
                            _("If you don't save, changes from the last 4 seconds will be permanently lost.");

                var button = new Gtk.Button.with_label (_("Close without saving"));
                button.show ();

                dialog.add_action_widget (button, Gtk.ResponseType.NO);
                dialog.add_button (_("Cancel"), Gtk.ResponseType.CANCEL);
                dialog.add_button (_("Save"), Gtk.ResponseType.YES);
                dialog.set_default_response (Gtk.ResponseType.ACCEPT);

                int response = dialog.run ();
                switch (response) {
                    case Gtk.ResponseType.CANCEL:
                    case Gtk.ResponseType.DELETE_EVENT:
                        ret_value = false;
                        break;
                    case Gtk.ResponseType.YES:
                        if (this.is_file_temporary)
                            this.save_as.begin ();
                        else
                            this.save.begin ();
                        break;
                    case Gtk.ResponseType.NO:
                        if (this.is_file_temporary)
                            delete_temporary_file (true);
                        break;
                }
                dialog.destroy ();
            }

            if (ret_value) {
                // Delete backup copy file
                delete_backup ();
#if HAVE_ZEITGEIST
                // Zeitgeist integration
                zg_log.close_insert (file.get_uri (), get_mime_type ());
#endif
                doc_closed ();
            }

            return ret_value;
        }

        public async bool save () {
            if (source_view.buffer.get_modified () == false || this.loaded == false) {
                return false;
            }

            this.create_backup ();

            // Replace old content with the new one
            save_cancellable.cancel ();
            save_cancellable = new GLib.Cancellable ();
            var source_file_saver = new Gtk.SourceFileSaver (source_view.buffer, source_file);
            try {
                yield source_file_saver.save_async (GLib.Priority.DEFAULT, save_cancellable, null);
            } catch (Error e) {
                // We don't need to send an error message at cancellation (corresponding to error code 19)
                if (e.code != 19)
                    warning ("Cannot save \"%s\": %s", get_basename (), e.message);
                return false;
            }

            source_view.buffer.set_modified (false);
#if HAVE_ZEITGEIST
            // Zeitgeist integration
            zg_log.save_insert (file.get_uri (), get_mime_type ());
#endif

            doc_saved ();
            this.set_saved_status (true);

            message ("File \"%s\" saved succesfully", get_basename ());

            return true;
        }

        public async bool save_as () {
            // New file
            if (!loaded) {
                return false;
            }


            var filech = Utils.new_file_chooser_dialog (Gtk.FileChooserAction.SAVE, _("Save File"), null);
            filech.do_overwrite_confirmation = true;

            var success = false;
            var current_file = file.get_path ();
            var is_current_file_temporary = this.is_file_temporary;

            if (filech.run () == Gtk.ResponseType.ACCEPT) {
                this.file = File.new_for_uri (filech.get_file ().get_uri ());
                // Update last visited path
                Utils.last_path = Path.get_dirname (filech.get_file ().get_uri ());
                success = true;
            }

            if (success) {
                source_view.buffer.set_modified (true);
                var is_saved = yield save ();

                if (is_saved && is_current_file_temporary) {
                    try {
                        // Delete temporary file
                        File.new_for_path (current_file).delete ();
                    } catch (Error err) {
                        message ("Temporary file cannot be deleted: %s", current_file);
                    }
                }

                delete_backup (current_file + "~");
                this.source_view.change_syntax_highlight_from_file (this.file);

                // Change label
                this.label = get_basename ();
            }

            /* We delay destruction of file chooser dialog til to avoid the document focussing in,
             * which triggers premature loading of overwritten content.
             */
            filech.destroy ();
            return success;
        }

        public bool move (File new_dest) {
            this.file = new_dest;
            this.save.begin ();

#if HAVE_ZEITGEIST
            // Zeitgeist integration
            zg_log.move_insert (file.get_uri (), new_dest.get_uri (), get_mime_type ());
#endif

            return true;
        }

        // Get mime type for the document
        public string get_mime_type () {
            try {
                var info = file.query_info ("standard::*", FileQueryInfoFlags.NONE, null);
                var mime_type = ContentType.get_mime_type (info.get_attribute_as_string (FileAttribute.STANDARD_CONTENT_TYPE));
                return mime_type;
            } catch (Error e) {
                debug (e.message);
                return "undefined";
            }
        }

        private void restore_settings () {
#if GTKSOURCEVIEW_3_18
            if (settings.show_mini_map) {
                source_map.show ();
                scroll.vscrollbar_policy = Gtk.PolicyType.EXTERNAL;
            } else {
                source_map.hide ();
                source_map.no_show_all = true;
                scroll.vscrollbar_policy = Gtk.PolicyType.AUTOMATIC;
            }
#endif
        }
        // Focus the SourceView
        public new void focus () {
            this.source_view.grab_focus ();
        }

        // Create the page
        public void create_page () {
            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);

#if GTKSOURCEVIEW_3_18
            var hbox = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            source_map.set_view (source_view);

            hbox.pack_start (scroll, true, true, 0);
            hbox.pack_start (source_map, false, true, 0);

            box.pack_start (info_bar, false, true, 0);
            box.pack_start (hbox, true, true, 0);
#else
            box.pack_start (info_bar, false, true, 0);
            box.pack_start (scroll, true, true, 0);
#endif
            this.page = box;
            this.label = get_basename ();
        }

        // Get file uri
        public string get_uri () {
            return this.file.get_uri ();
        }

        // Get file name
        public string get_basename () {
            if (is_file_temporary) {
                return _("New Document");
            } else {
                return file.get_basename ();
            }
        }

        // Set InfoBars message
        public void set_message (Gtk.MessageType type, string label,
                                  string? button1 = null, owned VoidFunc? callback1 = null,
                                  string? button2 = null, owned VoidFunc? callback2 = null) {

            // Show InfoBar
            info_bar.no_show_all = false;
            info_bar.visible = true;

            // Clear from useless widgets
            ((Gtk.Box) info_bar.get_content_area ()).get_children ().foreach ((widget) => {
                if (widget != null) {
                    widget.destroy ();
                }
            });

            ((Gtk.Box) info_bar.get_action_area ()).get_children ().foreach ((widget) => {
                if (widget != null) {
                    widget.destroy ();
                }
            });

            // Type
            info_bar.message_type = type;

            // Layout
            var l = new Gtk.Label (label);
            l.ellipsize = Pango.EllipsizeMode.END;
            l.use_markup = true;
            l.set_markup (label);
            ((Gtk.Box) info_bar.get_action_area ()).orientation = Gtk.Orientation.HORIZONTAL;
            var main = info_bar.get_content_area () as Gtk.Box;
            main.orientation = Gtk.Orientation.HORIZONTAL;
            main.pack_start (l, false, false, 0);
            if (button1 != null) {
                info_bar.add_button (button1, 0);
            } if (button2 != null) {
                info_bar.add_button (button2, 1);
            }

            // Response
            info_bar.response.connect ((id) => {
                if (id == 0) {
                    callback1 ();
                } else if (id == 1) {
                    callback2 ();
                }
            });

            // Show everything
            info_bar.show_all ();
        }

        // Hide InfoBar when not needed
        public void hide_info_bar () {
            info_bar.no_show_all = true;
            info_bar.visible = false;
        }

        // SourceView releated functions
        // Undo
        public void undo () {
            this.source_view.undo ();
            check_undoable_actions ();
        }

        // Redo
        public void redo () {
            this.source_view.redo ();
            check_undoable_actions ();
        }

        // Revert
        public void revert () {
            this.source_view.set_text (original_content, false);
            check_undoable_actions ();
        }

        // Get text
        public string get_text () {
            return this.source_view.buffer.text;
        }

        // Get selcted text
        public string get_selected_text () {
            return this.source_view.get_selected_text ();
        }

        // Get language name
        public string get_language_name () {
            var lang = this.source_view.buffer.language;
            if (lang != null) {
                return lang.name;
            } else {
                return "";
            }
        }

        // Get language id
        public string get_language_id () {
            var lang = this.source_view.buffer.language;
            if (lang != null) {
                return lang.id;
            } else {
                return "";
            }
        }

        // Duplicate selected text
        public void duplicate_selection () {
            this.source_view.duplicate_selection ();
        }

        // Show an error dialog which says "Hey, I cannot read that file!"
        private void show_error_dialog () {
            if (this.error_shown) {
                return;
            }

            this.error_shown = true;

            var parent_window = source_view.get_toplevel () as Gtk.Window;
            /* Using ".with_markup () " constructor does not work properly */
            /* FIXME: This dialog needs changing to Elementary HIG style */
            var dialog = new Gtk.MessageDialog  (parent_window,
                                                 Gtk.DialogFlags.MODAL,
                                                 Gtk.MessageType.ERROR,
                                                 Gtk.ButtonsType.CLOSE, null);

            /* Setting markup now works */
            dialog.set_markup ( _("File \"%s\" cannot be read. Maybe it is corrupt\nor you do not have the necessary permissions to read it.").printf ("<b>%s</b>".printf (get_basename ())));
            dialog.run ();
            dialog.destroy ();
            this.close ();
        }

        // Check if the file was deleted/changed by an external source
        public void check_file_status () {
            // If the file does not exist anymore
            if (!exists ()) {
                if (mounted == false) {
                    string message = _("The location containing the file \"%s\" was unmounted. Do you want to save somewhere else?").printf ("<b>%s</b>".printf (get_basename ()));

                    set_message (Gtk.MessageType.WARNING, message, _("Save As…"), () => {
                        this.save_as.begin ();
                        hide_info_bar ();
                    });
                } else {
                    string message = _("File \"%s\" was deleted. Do you want to save it anyway?").printf ("<b>%s</b>".printf (get_basename ()));

                    set_message (Gtk.MessageType.WARNING, message, _("Save"), () => {
                        this.save.begin ();
                        hide_info_bar ();
                    });
                }

                Utils.action_from_group (MainWindow.ACTION_SAVE, actions).set_enabled (false);
                this.source_view.editable = false;
                return;
            }

            // If the file can't be written
            if (!can_write ()) {
                string message = _("You cannot save changes on file \"%s\". Do you want to save the changes to this file in a different location?").printf ("<b>%s</b>".printf (get_basename ()));

                set_message (Gtk.MessageType.WARNING, message, _("Save changes elsewhere"), () => {
                    this.save_as.begin ();
                    hide_info_bar ();
                });

                Utils.action_from_group (MainWindow.ACTION_SAVE, actions).set_enabled (false);
                this.source_view.editable = !settings.autosave;
            } else {
                Utils.action_from_group (MainWindow.ACTION_SAVE, actions).set_enabled (true);
                this.source_view.editable = true;
            }

            // Detect external changes
            if (loaded) {
                var new_buffer = new Gtk.SourceBuffer (null);
                var source_file_loader = new Gtk.SourceFileLoader (new_buffer, source_file);
                source_file_loader.load_async.begin (GLib.Priority.DEFAULT, null, null, (obj, res) => {
                    try {
                        source_file_loader.load_async.end (res);
                    } catch (Error e) {
                        critical (e.message);
                        show_error_dialog ();
                        return;
                    }

                    if (source_view.buffer.text == new_buffer.text) {
                        return;
                    }

                    if (!source_view.buffer.get_modified ()) {
                        if (settings.autosave) {
                            source_view.set_text (new_buffer.text, false);
                        } else {
                            string message =  _("File \"%s\" was modified by an external application. Do you want to load it again or continue your editing?").printf ("<b>%s</b>".printf (get_basename ()));
                            set_message (Gtk.MessageType.WARNING, message, _("Load"), () => {
                                this.source_view.set_text (new_buffer.text, false);
                                hide_info_bar ();
                            }, _("Continue"), () => {
                                hide_info_bar ();
                            });
                        }
                    }
                });
            }
        }

        // Set Undo/Redo action sensitive property
        public void check_undoable_actions () {
            Utils.action_from_group (MainWindow.ACTION_UNDO, actions).set_enabled (source_view.buffer.can_undo);
            Utils.action_from_group (MainWindow.ACTION_REDO, actions).set_enabled (source_view.buffer.can_redo);
            Utils.action_from_group (MainWindow.ACTION_REVERT, actions).set_enabled (original_content != source_view.buffer.text);
        }

        // Set saved status
        public void set_saved_status (bool val) {
            this.saved = val;

            string unsaved_identifier = "* ";

            if (!val) {
                if (!(unsaved_identifier in this.label)) {
                    this.label = unsaved_identifier + this.label;
                }
            } else {
                this.label = this.label.replace (unsaved_identifier, "");
            }
        }

        // Backup functions
        private void create_backup () {
            if (!can_write ()) {
                return;
            }

            var backup = File.new_for_path (this.file.get_path () + "~");

            if (!backup.query_exists ()) {
                try {
                    file.copy (backup, FileCopyFlags.NONE);
                } catch (Error e) {
                    warning ("Cannot create backup copy for file \"%s\": %s", get_basename (), e.message);
                }
            }
        }

        private void delete_backup (string? backup_path = null) {
            string backup_file;

            if (backup_path == null) {
                backup_file = file.get_path () + "~";
            } else {
                backup_file = backup_path;
            }

            debug ("Backup file deleting: %s", backup_file);
            var backup = File.new_for_path (backup_file);
            if (backup == null || !backup.query_exists ()) {
                debug ("Backup file doesn't exists: %s", backup.get_path ());
                return;
            }

            try {
                backup.delete ();
                debug ("Backup file deleted: %s", backup_file);
            } catch (Error e) {
                warning ("Cannot delete backup for file \"%s\": %s", get_basename (), e.message);
            }
        }

        private bool delete_temporary_file (bool force = false) {
            if (!is_file_temporary || (get_text ().length > 0 && !force)) {
                return false;
            }

            try {
                file.delete ();
                return true;
            } catch (Error e) {
                warning ("Cannot delete temporary file \"%s\": %s", file.get_uri (), e.message);
            }

            return false;
        }

        // Return true if the file is writable
        public bool can_write () {
            FileInfo info;

            bool writable = false;

            try {
                info = this.file.query_info (FileAttribute.ACCESS_CAN_WRITE, FileQueryInfoFlags.NONE, null);
                writable = info.get_attribute_boolean (FileAttribute.ACCESS_CAN_WRITE);
                return writable;
            } catch (Error e) {
                warning ("query_info failed, but filename appears to be correct, allowing as new file");
                writable = true;
                return writable;
            }
        }

        // Return true if the file exists
        public bool exists () {
            return this.file.query_exists ();
        }

        private void file_changed () {
            if (mount != null) {
                mount.unmounted.disconnect (unmounted_cb);
                mount = null;
            }

            try {
                mount = file.find_enclosing_mount ();
                mount.unmounted.connect (unmounted_cb);
            } catch (Error e) {
                debug ("Could not find mount location");
                return;
            }
            mounted = true;
        }

        private void unmounted_cb () {
            warning ("Folder containing the file was unmounted");
            mounted = false;
        }
    }
}
