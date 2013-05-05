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

using Scratch.Widgets;
using Zeitgeist;

namespace Scratch.Services {

    public enum DocumentStates {
        NORMAL,
        READONLY
    }

    public class Document : Granite.Widgets.Tab {

        // Signals
        public signal void doc_opened ();
        public signal void doc_saved ();
        public signal void doc_closed ();

        // Widgets
        public Scratch.Widgets.SourceView source_view = new Scratch.Widgets.SourceView ();
        private Gtk.InfoBar info_bar =                  new Gtk.InfoBar ();

        // Objects
        public File? file = null;
        public string original_content;
        public string? last_saved_content = null;
        public bool saved = true;

        // Zeitgeist integration
        private ZeitgeistLogger zg_log = new ZeitgeistLogger();
        
        // Delegates
        public delegate void VoidFunc ();
        
        public Document (File? file = null) {
            this.file = file;

            hide_info_bar ();

            open ();

        }

        public bool open () {
            if (file == null) {
                message ("New Document opened");
                this.source_view.focus_in_event.connect (() => {
                    main_actions.get_action ("SaveFile").visible = true;
                    check_file_status ();
                    check_undoable_actions ();
                    return false;
                });
                this.source_view.buffer.changed.connect (() => {
                    check_undoable_actions ();
                    this.saved = false;
                });
                this.saved = true;
                return true;
            }
            
            // If it does not exists, let's create it!
            if (!exists ()) {
                try {
                    FileUtils.set_contents (file.get_path (), "");
                } catch (FileError e) {
                    warning ("Cannot create file \"%s\": %s", get_basename (), e.message);
                }
            }
            
            // Start loading
            this.working = true;
            message ("Opening \"%s\"", get_basename ());

            // Load file's content
            FileHandler.load_content_from_file.begin (file, (obj, res) => {
                var text = FileHandler.load_content_from_file.end (res);
                // Convert non-UTF8 text in UTF8 
                if (!text.validate())
                   text = file_content_to_utf8 (file, text);
                this.source_view.set_text (text);
                this.last_saved_content = this.source_view.buffer.text;
                this.original_content = text;
                // Signals for SourceView
                uint timeout_saving = -1;
                this.source_view.buffer.changed.connect (() => {
                    check_undoable_actions ();
                    // Save if autosave is ON
                    if (settings.autosave) {
                        if (timeout_saving >= 0) {
                            Source.remove (timeout_saving);
                            timeout_saving = -1;
                        }
                        timeout_saving = Timeout.add (250, () => {
                            save ();
                            timeout_saving = -1;
                            return false;
                        });
                    }
                    else if (!settings.autosave || file == null)
                        this.saved = false;
                });
            });

            // Focus in event for SourceView
            this.source_view.focus_in_event.connect (() => {
                main_actions.get_action ("SaveFile").visible = !(settings.autosave);
                check_file_status ();
                check_undoable_actions ();
                return false;
            });

            // Change syntax highlight
            this.source_view.change_syntax_highlight_from_file (this.file);

            // Stop loading
            this.working = false;
            
            // Zeitgeist integration
            zg_log.open_insert (file.get_uri (), get_mime_type ());

            // Grab focus
            this.source_view.grab_focus ();
            
            doc_opened ();

            return true;
        }

        public bool close () {

            message ("Closing \"%s\"", get_basename ());

            bool ret_value = true;

            // Check for unsaved changes
            if (!this.saved) {
                debug ("There are unsaved changes, showing a Message Dialog!");

                // Create a GtkDialog
                var dialog = new Gtk.MessageDialog (null, Gtk.DialogFlags.MODAL,
                                                    Gtk.MessageType.WARNING, Gtk.ButtonsType.NONE, "");
                dialog.type_hint = Gdk.WindowTypeHint.DIALOG;

                dialog.use_markup = true;

	            dialog.text = ("<b>" + _("Save changes to document %s before closing?") +
	                            "</b>").printf (this.get_basename ());
                dialog.text += "\n\n" +
                            _("If you don't save, changes from the last 4 seconds will be permanently lost.");

                var button = new Gtk.Button.with_label (_("Close without saving"));
                button.show ();

                dialog.add_action_widget (button, Gtk.ResponseType.NO);
                dialog.add_button (Gtk.Stock.CANCEL, Gtk.ResponseType.CANCEL);
                dialog.add_button (Gtk.Stock.SAVE, Gtk.ResponseType.YES);
                dialog.set_default_response (Gtk.ResponseType.ACCEPT);

                int response = dialog.run ();
                switch (response) {
                    case Gtk.ResponseType.CANCEL:
                        ret_value = false;
                        break;
                    case Gtk.ResponseType.YES:
                        this.save ();
                        ret_value = true;
                        break;
                    case Gtk.ResponseType.NO:
                        ret_value = true;
                        break;
                }
                dialog.destroy ();
            }

            if (file != null) {
                // Delete backup copy file
                delete_backup ();
                // Zeitgeist integration
                zg_log.close_insert (file.get_uri (), get_mime_type ());
            }

            return ret_value;
        }

        public bool save () {
            // Create backup copy file if it does not still exist
            create_backup ();
            
            // Show save as dialog if file is null
            if (this.file == null)
                this.save_as ();
            
            // Replace old content with the new one
            try {
                string s;
                file.replace_contents (this.source_view.buffer.text.data, null, false, 0, out s);
            } catch (Error e) {
                warning ("Cannot save \"%s\": %s", get_basename (), e.message);
            }

            // Zeitgeist integration
            zg_log.save_insert (file.get_uri (), get_mime_type ());

            doc_saved ();
            this.saved = true;
            FileHandler.load_content_from_file.begin (file, (obj, res) => {
                this.last_saved_content = FileHandler.load_content_from_file.end (res);
            });
            
            message ("File \"%s\" saved succefully", get_basename ());

            return true;
        }
        
        public bool save_as () {
            // New file
            var filech = Utils.new_file_chooser_dialog (Gtk.FileChooserAction.SAVE, _("Save File"));
            
            if (filech.run () == Gtk.ResponseType.ACCEPT)
                this.file = File.new_for_uri (filech.get_uri ());
                
            filech.close ();
            
            save ();

            // Change syntax highlight
            this.source_view.change_syntax_highlight_from_file (this.file);    
            
            // Change label
            this.label = get_basename ();
            
            return true;
        }
        
        public bool move (File new_dest) {
            // Zeitgeist integration
            zg_log.move_insert (file.get_uri (), new_dest.get_uri (), get_mime_type ());

            return true;
        }

        // Get mime type for the document
        public string get_mime_type () {
            if (file == null)
                return "text/plain";
            else {
                FileInfo info;
                string mime_type;
                try {
                    info = file.query_info ("standard::*", FileQueryInfoFlags.NONE, null);
                    mime_type = ContentType.get_mime_type (info.get_attribute_as_string (FileAttribute.STANDARD_CONTENT_TYPE));
                    return mime_type;
                } catch (Error e) {
                    warning ("%s", e.message);
                    return "undefined";
                }
            }
        }

        // Focus the SourceView
        public new void focus () {
            this.source_view.grab_focus ();
        }

        // Create the page
        public void create_page () {
            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);

            var scroll = new Gtk.ScrolledWindow (null, null);
            scroll.add (this.source_view);

            box.pack_start (info_bar, false, true, 0);
            box.pack_start (scroll, true, true, 0);

            this.page = box;
            this.label = get_basename ();
        }

        // Get file name
        public string get_basename () {
            if (file != null)
                return file.get_basename ();
            else
                return _("New Document");
        }

        // Set InfoBars message
        public void set_message (Gtk.MessageType type, string label,
                                  string? button1 = null, owned VoidFunc? callback1 = null,
                                  string? button2 = null, owned VoidFunc? callback2 = null) {

            // Show InfoBar
            info_bar.no_show_all = false;
            info_bar.visible = true;

            // Clear from useless widgets
            ((Gtk.Box)info_bar.get_content_area ()).get_children ().foreach ((w) => {
                if (w != null)
                    w.destroy ();
            });
            ((Gtk.Box)info_bar.get_action_area ()).get_children ().foreach ((w) => {
                if (w != null)
                    w.destroy ();
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
            if (button1 != null)
                info_bar.add_button (button1, 0);
            if (button2 != null)
                info_bar.add_button (button2, 1);

            // Response
            info_bar.response.connect ((id) => {
                if (id == 0)
                    callback1 ();
                else if (id == 1)
                    callback2 ();
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
            this.last_saved_content = original_content;
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
            if (lang != null)
                return lang.name;
            else
                return "";
        }
        
        // Get language id
        public string get_language_id () {
            var lang = this.source_view.buffer.language;
            if (lang != null)
                return lang.id;
            else  
                return "";
        }
        
        // Duplicate selected text
        public void duplicate_selection () {
            this.source_view.duplicate_selection ();
        }

        // Check if the file was deleted/changed by an external source
        public void check_file_status () {
            if (file != null) {
                // If the file does not exist anymore
                if (!exists ()) {
                    string message = _("File ") +  " \"<b>%s</b>\" ".printf (get_basename ()) +
                                     _("was deleted. Do you want to save it anyway?");

                    set_message (Gtk.MessageType.WARNING, message, _("Save"), () => {
                        this.save ();
                        hide_info_bar ();
                    });
                    main_actions.get_action ("SaveFile").sensitive = false;
                    this.source_view.editable = false;
                    return;
                }
                // If the file can't be written
                if (!can_write ()) {
                    string message = _("You cannot save changes on file") +  " \"<b>%s</b>\". ".printf (get_basename ()) +
                                     _("Do you want to save the changes to this file in a different location?");

                    set_message (Gtk.MessageType.WARNING, message, _("Save changes elsewhere"), () => {
                        this.save_as ();
                        hide_info_bar ();
                    });
                    main_actions.get_action ("SaveFile").sensitive = false;
                    this.source_view.editable = !settings.autosave;
                }
                else {
                    main_actions.get_action ("SaveFile").sensitive = true;
                    this.source_view.editable = true;
                }
                // Detect external changes
                FileHandler.load_content_from_file.begin (file, (obj, res) => {
                    var text = FileHandler.load_content_from_file.end (res);
                    // Reload automatically if auto save is ON
                    if (settings.autosave)
                        if (text != this.source_view.buffer.text)
                            this.source_view.set_text (text, false);
                    else {
                        if (last_saved_content != null && text != last_saved_content) {
                            string message = _("File ") +  " \"<b>%s</b>\" ".printf (get_basename ()) +
                                             _("was modified by an external application. Do you want to load it again or continue your editing?");

                            set_message (Gtk.MessageType.WARNING, message, _("Load"), () => {
                                this.source_view.set_text (text, false);
                                hide_info_bar ();
                            }, _("Continue"), () => {
                                hide_info_bar ();
                            });
                        }
                    }
                });
            }
            else {
                main_actions.get_action ("SaveFile").sensitive = true;
                this.source_view.editable = true;
            }
        }

        // Set Undo/Redo action sensitive property
        public void check_undoable_actions () {
            main_actions.get_action ("Undo").sensitive = this.source_view.buffer.can_undo;
            main_actions.get_action ("Redo").sensitive = this.source_view.buffer.can_redo;
            main_actions.get_action ("Revert").sensitive = (file != null && original_content != source_view.buffer.text);
        }

        // Backup functions
        private void create_backup () {
            if (!can_write ())
                return;
            
            var backup = File.new_for_path (this.file.get_path () + "~");

            if (!backup.query_exists ()) {
                try {
                    file.copy (backup, FileCopyFlags.NONE);
                } catch (Error e) {
                    warning ("Cannot create backup copy for file \"%s\": %s", get_basename (), e.message);
                }
            }
        }

        private void delete_backup () {
            var backup = File.new_for_path (this.file.get_path () + "~");
            try {
                backup.delete ();
            } catch (Error e) {
                warning ("Cannot delete backup for file \"%s\": %s", get_basename (), e.message);
            }
        }

        // Return true if the file is writable
        public bool can_write () {
            FileInfo info;

            bool writable = false;

            if (this.file == null)
                return writable = true;

            try {
                info = this.file.query_info (FileAttribute.ACCESS_CAN_WRITE, FileQueryInfoFlags.NONE, null);
                writable = info.get_attribute_boolean (FileAttribute.ACCESS_CAN_WRITE);
                return writable;
            } catch (Error e) {
                if (this.file != null ) {
                    warning ("query_info failed, but filename appears to be correct, allowing as new file");
                    writable = true;
                }
                return writable;
            }
        }

        // Return true if the file exists
        public bool exists () {
            return this.file.query_exists ();
        }
    }

}
