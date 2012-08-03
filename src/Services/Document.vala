// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/***
  BEGIN LICENSE

  Copyright (C) 2011-2012 Giulio Collura <random.cpp@gmail.com>
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

    public class Document : GLib.Object {

        // Signals
        public signal void opened ();
        public signal void closed ();

        // Public properties
        public bool saved {
            get {
                if (original_text == text)
                    return true;
                else
                    return false;
            }
        }
        public string? name { get; private set; default  = null; }
        
        private ZeitgeistLogger zg_log;
        
        // Detect if the file is opened now
        public bool opening = true;
        
        private string _directory;
        public string directory {
            get {
                return _directory;
            }
        }

        public Gtk.SourceLanguage language {
            get {
                var manager = new Gtk.SourceLanguageManager ();
                return manager.guess_language (filename, null);
            }
        }

        public string filename      { get; public set; }
        public string text          { get; set; }
        
        public bool show_notification = true;
        
        // Cookie requested for session managment
        uint? cookie = null;
        
        private bool force_normal_state;
        private DocumentStates _state;
        public DocumentStates state {
            get {
                if (force_normal_state)
                    return DocumentStates.NORMAL;
                
                if (can_write ())
                    return DocumentStates.NORMAL;
                else
                    return DocumentStates.READONLY;
                return _state;
            }
        }

        public bool exists {
            get {
                if (filename != null)
                    return file.query_exists ();
                else
                    return false;
            }
        }

        public bool can_undo { get { return buffer.can_undo; } }
        public bool can_redo { get { return buffer.can_redo; } }
        
        // Private string and bool to watch for an warn about files changed by other programs 
        public string last_saved_text = null;
        private bool want_reload = false;
        
        // Private variables
        private string original_text;
        private Gtk.SourceBuffer buffer;
        private SourceView source_view;
        private MainWindow window;
        public File _file;
        public File? file { 
            get { 
                if (filename != null) {
                    _file = File.new_for_uri (filename); 
                    return _file;
                }
                else
                    return null;
            } 
        }
        private static string home_dir = Environment.get_home_dir ();
        public Tab tab;
        /**
         * It returns the value of the modified field of the text_view of the tab of
         * this document
         **/
        public bool modified { get; public set; }

        public Document (string filename, MainWindow? window) {

            this.filename = filename;
            zg_log = new ZeitgeistLogger();

            register_recent ();

            name = file.get_basename ();
            _directory = Path.get_dirname (filename).replace (home_dir, "~");

            this.window = window;

        }

        void register_recent () {
            Gtk.RecentManager recent_manager = Gtk.RecentManager.get_default();
            recent_manager.add_item (file.get_uri ());
        }

        public void focus_sourceview () {
            if(tab == null) {
                critical("No tab created for this document");
            }
            ScratchNotebook notebook = tab.get_parent () as ScratchNotebook;
            if (notebook == null) {
                critical ("Can't get tab parent.");
            }
            notebook.page = notebook.page_num(tab);
            tab.text_view.grab_focus ();
        }

        public void undo () {
            tab.text_view.undo ();
        }

        public void redo () {
            tab.text_view.redo ();
        }

        /**
         * In this function, we create a new tab and we load the content of the file in it.
         **/
        public void create_sourceview ()
        {
            //get the filename from strig filename =)
            string name = _("New document");
            if(filename != null)
                name = Filename.display_basename (filename);


            //create new tab
            tab = new Tab (window.current_notebook, name);
            tab.closed.connect( () => { close(); });
            tab.document = this;

            //set new values
            tab.filename = filename;
            tab.saved = true;
            
            buffer = tab.text_view.buffer;
            
            source_view = tab.text_view;
            source_view.focus_in_event.connect (on_source_view_focus_in);
            source_view.drag_data_received.connect (on_drag_data_received);
            
            tab.change_syntax_highlight_for_filename (filename);
            window.current_notebook.set_current_page (window.current_notebook.add_existing_tab(tab));

            open ();
            
            buffer.changed.connect (on_buffer_changed);
        }

        public Document.empty (MainWindow? window) {

            filename = null;
            name = null;
            this.window = window;

        }

        /**
         * Open the file and put it content inside the given buffer.
         **/
        public bool open () {

            if (filename == null)
                return false;
            
            foreach(var doc in window.scratch_app.documents)
            {
                if(doc.filename == filename) {
                    /* Already opened, then, we will just focus it */
                    doc.focus_sourceview();
                    return false;
                }
            }
            
            string contents = null;
            try {
                if (file != null) {
                    var dis = new DataInputStream (file.read ());
                    var text = new StringBuilder ();
                    string line;
                    size_t len;
                    while ((line = dis.read_line (null)) != null) {
                        text.append (line);
                        text.append_c ('\n');
                    }
                    contents = text.str;
                }
            } catch (Error e) {
                warning ("Couldn't open the file");
                return false;
            }

            try {
                if(!contents.validate()) contents = convert (contents, -1, "UTF-8", "ISO-8859-1");
            }
            catch (Error e) {
                warning ("Couldn't convert the content of the document to UTF-8 (I guessed it was in ISO-8859-1?)");
            }
            original_text = text = contents;

            if (buffer != null) {
                buffer.begin_not_undoable_action ();
                buffer.text = this.text;
                buffer.end_not_undoable_action ();
            }
            else
                warning ("No buffer selected.");

            if (tab != null) {
                tab.text_view.modified = false;
            }
            else
                warning ("No tab selected.");

            /* TODO: real encoding detection */
            
            this.filename = filename;
            
            this.last_saved_text = contents;
     
            this.opened (); // Signal

            if (state == DocumentStates.READONLY) {
                if (settings.autosave) source_view.editable = false;    
                else window.toolbar.save_button.set_sensitive (false);
                
                window.current_notebook.info_bar.set_notification_type (Scratch.Widgets.NotificationType.NO_WRITE);
                window.current_notebook.info_bar.set_notification_label (_("You can't save changes to:") + " <b>" + file.get_basename () + "</b>. " + _("Do you want to save the changes to this file in a different location?"));
                window.current_notebook.info_bar.set_attributes (filename, this);
                if (show_notification)
                    window.current_notebook.info_bar.no_show_all = false;
            }
            else 
                window.current_notebook.info_bar.no_show_all = true;
                
            zg_log.open_insert(file.get_uri(), get_mime_type ());

            return true;

        }

        public bool backup () {
            
            if (!settings.make_backup)
                return false;
            
            /* Check for the requested permissions */
            if (state == DocumentStates.READONLY)
               return false; 
                
            /* Check if the file is real */
            if (filename == null)
                return false;

            /* Make the backup copy */
            string contents;
            try {
                contents = FileHandler.load_content_from_uri (filename + "~");
            } catch (Error e) {
                warning ("Couldn't create a backup for the file");
                return false;
            }

            try {
                if(!contents.validate()) contents = convert (contents, -1, "UTF-8", "ISO-8859-1");
            }
            catch (Error e) {
                warning ("Couldn't convert the content of the document to UTF-8 (I guessed it was in ISO-8859-1?)");
            }
            original_text = text = contents;

            if (buffer != null) {
                //buffer.begin_not_undoable_action ();
                buffer.text = this.text;
                //buffer.end_not_undoable_action ();
            }
            else
                warning ("No buffer selected.");

            if (tab != null) {
                tab.text_view.modified = false;
            }
            else
                warning ("No tab selected.");

            /* TODO: real encoding detection */

            return true;

        }
        
        public void delete_backup () {
            var bk = File.new_for_uri (filename + "~");
            if (bk != null && bk.query_exists ()) {
                try {
                    bk.delete ();
                } catch (Error e) {
                    debug ("Cannot delete %s~, it doesn't exist", filename);
                }
            }
        }
        
        public bool close () {

            if (!saved) 
                return false;
            
            zg_log.close_insert(this.filename, get_mime_type ());

            this.closed (); // Signal
            return true;

        }

        public void set_label_font (string style) {
            string label;
            if (filename != null) {
                label = file.get_basename ();
            }
            else {
                label = _("New document");
            }
            
            if (state == DocumentStates.READONLY) {
                tab.label.label.set_markup ("<span font_style='normal'>%s</span>".printf(label));
                return; 
            }
            
            switch (style) {

                case "modified":
                    tab.label.label.set_markup ("<span font_style='italic'>%s</span>".printf(label));
                break;

                case "saved":
                    tab.label.label.set_markup ("<span font_style='normal'>%s</span>".printf(label));
                break;

            }
            
        }
        
        uint timeout_saving = -1;
        
        void on_buffer_changed () {

            window.set_undo_redo ();
            
            if (settings.autosave && filename != null) {
                if (timeout_saving >= 0) {
                    Source.remove(timeout_saving);
                    timeout_saving = -1;
                }
                timeout_saving = Timeout.add(250, () => {
                    if (!opening) save ();//Thread.create (save_a, false);
                    modified = false;
                    opening = false;
                    tab.text_view.modified = false;
                    return false;
                    timeout_saving = -1;
                });
            }
            else {
                if (filename != null) {
                    if (buffer.text == original_text) {
                        /*window.main_actions.get_action ("Revert").set_sensitive (false);
                        set_label_font ("saved");
                        modified = false;*/
                    }
                    else {
                        window.main_actions.get_action ("Revert").set_sensitive (true);
                        set_label_font ("modified");
                        modified = true;
                        tab.text_view.modified = true;
                    }
                }
                else {
                    window.main_actions.get_action ("Revert").set_sensitive (false);
                    set_label_font ("modified");
                    modified = true;
                    tab.text_view.modified = true;
                }
            }
            if (state == DocumentStates.READONLY) modified = false;
            
            /* Set revert button sensitive */
            if (original_text == source_view.buffer.text)
                window.toolbar.revert_button.set_sensitive (false);
            else
                window.toolbar.revert_button.set_sensitive (true);
            
            window.search_manager.get_go_to_adj ().upper = buffer.text.split ("\n").length;
            
            check_session_manager ();
            
        }
        
        /**
         * In this function, called each time a source view is focused, we check that
         * the file in the buffer hasn't been modified, and, if it is the case, we propose
         * to reload it.
         **/
        bool on_source_view_focus_in (Gdk.EventFocus event) {
            string contents = null;            
            
            /* Set the right highligh_current_line setting again */
            source_view.set_highlight_current_line (settings.highlight_current_line);
            
            if (filename != null)
                window.main_actions.get_action ("Revert").set_sensitive (true);
            
            /* First, we check that this is a real file, and not a new document */
            if (filename == null && settings.autosave == false) {
                window.toolbar.save_button.set_sensitive (true);
                window.toolbar.save_button.show ();
            }
            
            /* Check if an external thing modified the file */
            try {
                contents = FileHandler.load_content_from_uri (filename);//FileUtils.get_contents (filename, out contents);
            } catch (Error e) {
                warning (e.message);
            }
            
            if (contents != this.last_saved_text && this.last_saved_text != null) want_reload = true;
                
            if (want_reload) {
                if (settings.autosave && settings.autoupdate && exists) {
                    reload ();
                    save ();
                }
                else {
                    var type = Scratch.Dialogs.WarnType.RELOAD; 
                    if (!exists)   
                        type = Scratch.Dialogs.WarnType.FILE_DELETED; 
                    
                    var warn = new Scratch.Dialogs.WarnDialog (filename, window, type);
                    warn.run ();
                    warn.destroy ();  
                }  
                want_reload = false;
                this.last_saved_text = contents; 
            }
 
            /* Set revert button sensitive */
            if (original_text == source_view.buffer.text)
                window.toolbar.revert_button.set_sensitive (false);
            else
                window.toolbar.revert_button.set_sensitive (true);
            
            /* Set undo/redo buttons sensitive */
            window.set_undo_redo ();
            
            /* Check the document state */
            if (state == DocumentStates.READONLY) {
                if (settings.autosave) source_view.editable = false;    
                else window.toolbar.save_button.set_sensitive (false);
                window.current_notebook.info_bar.show_all ();
            }
            if (state == DocumentStates.NORMAL) {
                force_normal_state = true;
                if (settings.autosave) source_view.editable = true;    
                else window.toolbar.save_button.set_sensitive (true);
                window.current_notebook.info_bar.hide ();
            }
            
            if (state == DocumentStates.READONLY) {
                window.current_notebook.info_bar.set_notification_type (Scratch.Widgets.NotificationType.NO_WRITE);
                window.current_notebook.info_bar.set_notification_label (_("You can't save changes to:") + " <b>" + file.get_basename () + "</b>. " + _("Do you want to save the changes to this file in a different location?"));
                window.current_notebook.info_bar.set_attributes (filename, this);
                if (show_notification)
                    window.current_notebook.info_bar.no_show_all = false;
            }
            else    
                window.current_notebook.info_bar.no_show_all = true;

            
            window.search_manager.get_go_to_adj ().upper = buffer.text.split ("\n").length;
            window.search_manager.get_go_to_adj ().value = 0;
            
            /* Check Share menu button status */
            window.toolbar.controll_for_share_plugins ();
            
            return false;
        }
        
        void on_drag_data_received (Gdk.DragContext context, int x, int y, Gtk.SelectionData selection_data, uint info, uint time_) {
            foreach (string s in selection_data.get_uris ()){
                try {
                    window.open (s);
                }
                catch (Error e) {
                    warning ("%s doesn't seem to be a valid URI, couldn't open it.", s);
                }
            }
        }
        
        void check_session_manager () {
            var app = window.scratch_app;
            var documents = app.documents.copy ();
            foreach(var doc in documents) {                
                if(doc.modified && !app.is_inhibited (Gtk.ApplicationInhibitFlags.LOGOUT)) {
                    cookie = app.inhibit (window, Gtk.ApplicationInhibitFlags.LOGOUT, _("There are unsaved changes!"));
                }
                else if (!doc.modified)
                    if (cookie != null && app.is_inhibited (Gtk.ApplicationInhibitFlags.LOGOUT)) {
                        app.uninhibit (cookie);
                    }
            }
        }
        
        public bool save () {
            
            /* Check for the requested permissions */
            if (state == DocumentStates.READONLY)
               return false; 
            
            opening = false;
            
            string f = filename;
            int n = tab.save ();
            if (f == null && n == 0) {
                message ("Saving: %s", this.filename);
                window.toolbar.save_button.hide ();
                set_label_font ("saved");
                modified = false;
                force_normal_state = true;
                
                string contents = null;   
                try {
                    contents = FileHandler.load_content_from_uri (filename);
                } catch (Error e) {
                    warning (e.message);
                }
                
                source_view.change_syntax_highlight_for_filename (filename);
                
                check_session_manager ();
                
                this.last_saved_text = contents;
             
                this.want_reload = false;
            }

            zg_log.save_insert(this.filename, get_mime_type ());

            return true;
        }

        public bool save_as () {
            
            /* Check for the requested permissions */
            if (state == DocumentStates.READONLY)
               return false; 
            
            string f = filename;
            int n = tab.save_as ();
            if (f == null && n == 0) {
                window.toolbar.save_button.hide ();
                modified = false;
                _state = DocumentStates.NORMAL;
                force_normal_state = true;
                
                string contents;   
                try {
                    contents = FileHandler.load_content_from_uri (filename);
                } catch (Error e) {
                    warning (e.message);
                }
                
                check_session_manager ();
                
                this.last_saved_text = contents;
             
                this.want_reload = false;
            }
                
            zg_log.save_insert(this.filename, get_mime_type ());
        
            return false;
        }

        public bool rename (string new_name) {

            FileHandler.move_uri (filename, new_name);
            zg_log.move_insert(filename, new_name, get_mime_type());

            this.filename = new_name;
            
            source_view.change_syntax_highlight_for_filename (filename);
            
            if (can_write ()) {
                force_normal_state = true;
                _state = DocumentStates.NORMAL;
            }
            
            this.save ();

            return true;

        }
        
        public bool reload () {
            string contents;
            try {
                contents = FileHandler.load_content_from_uri (filename);
                buffer.text = contents;
                return true;
            } catch (Error e) {
                warning (e.message);
                return false;
            }
        }
        
        public uint64 get_mtime () {

            try {
                var info = file.query_info (FileAttribute.TIME_MODIFIED, 0, null);
                return info.get_attribute_uint64 (FileAttribute.TIME_MODIFIED);
            } catch  (Error e) {
                warning ("%s", e.message);
                return 0;
            }

        }

        public string get_mime_type () {

            if (filename == null)
                return "text/plain";
            else {
                FileInfo info;
                string mime_type;
                try {
                    info = file.query_info ("standard::*", FileQueryInfoFlags.NONE, null);
                    mime_type = ContentType.get_mime_type (info.get_content_type ());
                    return mime_type;
                } catch (Error e) {
                    warning ("%s", e.message);
                    return "undefined";
                }
            }


        }

        public int64 get_size () {

            if (filename != null) {

                FileInfo info;
                int64 size;
                try {
                    info = file.query_info (FileAttribute.STANDARD_SIZE, FileQueryInfoFlags.NONE, null);
                    size = info.get_size ();
                    return size;
                } catch (Error e) {
                    warning ("%s", e.message);
                    return 0;
                }

            } else {

                return 0;

            }

        }
        
        public bool can_write () {
            
            if (filename != null) {

                FileInfo info;
                bool writable;

                try {

                    info = file.query_info (FileAttribute.ACCESS_CAN_WRITE, FileQueryInfoFlags.NONE, null);
                    writable = info.get_attribute_boolean (FileAttribute.ACCESS_CAN_WRITE);

                    return writable;

                } catch (Error e) {

                    warning ("%s", e.message);
                    return false;

                }

            } else {

                return true;

            }

        }

    }

}
