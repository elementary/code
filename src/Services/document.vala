/***
  BEGIN LICENSE
	
  Copyright (C) 2011 Giulio Collura <random.cpp@gmail.com>
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

using GtkSource;
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
        private string? _name;
        public string? name {
            get {
                return _name;
            }
        }
        
        private string _directory;
        public string directory {
            get {
                return _directory;
            }
        }

        public Language language {
            get {
                var manager = new LanguageManager ();
                return manager.guess_language (filename, null);
            }
        }

        public string filename      { get; private set; }
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
        
        // Private variables
        private string original_text;
        private SourceView source_view;
        private Buffer buffer;
        private MainWindow window;
        private File file;
        private static string home_dir = Environment.get_home_dir ();

        public Document (string filename, SourceView source_view, MainWindow? window) {

            
            this.filename = filename;
            file = File.new_for_path (filename);
            
            _name = file.get_basename ();
            _directory = Path.get_dirname (filename).replace (home_dir, "~");

            this.buffer = source_view.buffer;
            this.source_view = source_view;
            this.window = window;
            
        }

        public Document.empty (SourceView source_view, MainWindow? window) {
            
            filename = null;
            
            this.source_view = source_view;
            this.buffer = source_view.buffer;
            this.window = window;

        }

        public bool open () throws FileError {

            if (filename == null)
                return false;

            bool result;
            string contents;
            result = FileUtils.get_contents (filename, out contents);
            original_text = text = contents;

            buffer.text = this.text;
            
            this.opened (); // Signal

            return result;

        }

        public bool close () {

            if (!saved)
                return false;

            this.closed (); // Signal
            return true;

        }

        public bool save () throws FileError {
            
            // TODO: need smart implementation
            return false;

        }

        public bool rename (string new_name) {

            FileUtils.rename (filename, new_name);
            filename = new_name;
            return true;

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

        private bool can_write () {

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
