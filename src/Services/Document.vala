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
        public DocumentStates state {
            get {
                if (can_write ())
                    return DocumentStates.NORMAL;
                else
                    return DocumentStates.READONLY;
            }
        }

        public bool exists {
            get {
                if (filename != null)
                    return FileUtils.test (filename, FileTest.EXISTS);
                else
                    return false;
            }
        }

        public bool can_undo { get { return buffer.can_undo; } }
        public bool can_redo { get { return buffer.can_redo; } }
        
        // Public string and bool to watch for an warn about files changed by other programs 
        public string last_saved_text = null;
        public bool want_reload = true;
        
        // Private variables
        private string original_text;
        private Gtk.SourceBuffer buffer;
        private Gtk.SourceView source_view;
        private MainWindow window;
        private File file;
        private static string home_dir = Environment.get_home_dir ();
        public Tab tab;
        /**
         * It returns the value of the modified field of the text_view of the tab of
         * this document
         **/
        public bool modified { get; private set; }

        public Document (string filename, MainWindow? window) {


            this.filename = filename;
            file = File.new_for_path (filename);

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
            tab.grab_focus ();
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
            buffer.changed.connect (on_buffer_changed);
            
            source_view = tab.text_view;
            source_view.focus_in_event.connect (on_source_view_focus_in);
            source_view.drag_data_received.connect (on_drag_data_received);
            
            tab.change_syntax_highlight_for_filename(filename);
            window.current_notebook.set_current_page (window.current_notebook.add_existing_tab(tab));

            open();
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
            
            string contents;
            try {
                FileUtils.get_contents (filename, out contents);
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

            return true;

        }

        public bool backup () {

            if (filename == null)
                return false;

            string contents;
            try {
                FileUtils.get_contents (filename + "~", out contents);
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

        public bool close () {

            if (!saved)
                return false;

            this.closed (); // Signal
            return true;

        }

        public void set_label_font (string style) {
            string label;
            if (filename != null) {
                var f = File.new_for_path (this.filename);
                label = f.get_basename ();
            }
            else {
                label = _("New document");
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
        
        bool need_saving = false;

        void on_buffer_changed () {

            window.set_undo_redo ();
            want_reload = true;
            
            if (settings.autosave && filename != null) {
                if(!need_saving) {
                    need_saving = true;
                    Idle.add( () => {
                        need_saving = false;
                        save ();
                        modified = false;
                        tab.text_view.modified = false;
                        return false;
                    });
                }
            }
            else {
                if (filename != null) {
                    if (buffer.text == original_text) {
                        //window.main_actions.get_action ("Revert").set_sensitive (false);
                        //set_label_font ("saved");
                        //modified = true;
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
        }
        
        /**
         * In this function, called each time a source view is focused, we check that
         * the file in the buffer hasn't been modified, and, if it is the case, we propose
         * to reload it.
         **/
        bool on_source_view_focus_in (Gdk.EventFocus event) {
            string contents;            

            /* First, we check that this is a real file, and not a new document */
            if (filename == null)
                return false;

            try {
                FileUtils.get_contents (file.get_path (), out contents);
            } catch (Error e) {
                warning (e.message);
                return false;
            }
            if (want_reload) {
                if (contents != this.last_saved_text) {
                    var warn = new Scratch.Dialogs.WarnDialog (filename, window);
                    warn.run ();
                    warn.destroy ();
                    want_reload = false;
                    return true;
                }  
            }
            return false;
        }
        
        void on_drag_data_received (Gdk.DragContext context, int x, int y, Gtk.SelectionData selection_data, uint info, uint time_) {
            foreach (string s in selection_data.get_uris ()){
                try {
                    window.open (Filename.from_uri (s));
                }
                catch (Error e) {
                    warning ("%s doesn't seem to be a valid URI, couldn't open it.", s);
                }
            }
        }
        
        public bool save () {
            string f = filename;
            int n = tab.save ();
            if (f == null && n == 0) {
                window.toolbar.save_button.hide ();
                modified = false;
                want_reload = false;
                this.last_saved_text = this.buffer.text;
            }
            return false;
        }

        public bool save_as () {
            string f = filename;
            int n = tab.save_as ();
            if (f == null && n == 0) {
                window.toolbar.save_button.hide ();
                modified = false;
                want_reload = false;
                this.last_saved_text = this.buffer.text;
            }
            return false;
        }

        public bool rename (string new_name) {

            FileUtils.rename (filename, new_name);
            
            this.filename = new_name;
            
            this.save ();
            
            return true;

        }
        
        public bool reload () {
            string contents;
            try {
                FileUtils.get_contents (file.get_path (), out contents);
                buffer.text = contents;
                return true;
            } catch (Error e) {
                warning (e.message);
                return false;
            }
        }
        
        public uint64 get_mtime () {

            try {
                var info = file.query_info (FILE_ATTRIBUTE_TIME_MODIFIED, 0, null);
                return info.get_attribute_uint64 (FILE_ATTRIBUTE_TIME_MODIFIED);
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
                    info = file.query_info (FILE_ATTRIBUTE_STANDARD_SIZE, FileQueryInfoFlags.NONE, null);
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

                    info = file.query_info (FILE_ATTRIBUTE_ACCESS_CAN_WRITE, FileQueryInfoFlags.NONE, null);
                    writable = info.get_attribute_boolean (FILE_ATTRIBUTE_ACCESS_CAN_WRITE);

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
