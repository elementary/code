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

namespace Scratch.Services {

    enum DocumentStates {

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

        public string? name {
            get {
                return File.get_basename (filename);
            }
        }

        public string directory {
            get {
                var home_dir = Environment.get_home_dir ();
                var path = Path.get_dirname (filename).replace (home_dir, "~");
                return path;
            }
        }

        public Language language {
            get {
                return Language.guess_language (filename, null);
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

        public uint64 mtime {
            get {
                return get_mtime ();
            }
        }
        public string mime_type {
            get {
                return get_mime_type ();
            }
        }
        public int64 size {
            get {
                return get_size ();
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
        private Buffer buffer;
        private MainWindow window;
        private File file;

        public Document (string? filename, Buffer buffer, MainWindow? window) {

            if (filename != null) {
                this.filename = filename;
                file = File.new_for_path (filename);
            } else {
                this.filename = null;
            }

            this.buffer = buffer;
            this.window = window;
            
        }

        public bool open () throws FileError {

            if (filename == null)
                return false;

            bool result;
            result = FileUtils.get_contents (filename, out text);
            original_text = text;

            buffer.text = this.text;
            
            this.opened (); // Signal

            return result;

        }

        public bool close () {

            if (!saved)
                return false;

            this.closed ();
            return true;

        }

        public bool save () throws FileError {

            

        }

        public bool rename (string new_name) {

            FileUtils.rename (filename, new_name);
            filename = new_name;
            return true;

        }

        private uint64 get_mtime () throws Error {

            var info = file.query_info (FILE_ATTRIBUTE_TIME_MODIFIED, 0, null);

            return info.get_attribute_uint64 (FILE_ATTRIBUTE_TIME_MODIFIED);
        
        }

        private string get_mime_type () throws Error {

            if (filename == null)
                return "text/plain";
            else {
                FileInfo info;
                string mime_type;
                info = file.query_info ("standard::*", FileQueryInfoFlags.NONE, null);
                mime_type = ContentType.get_mime_type (info.get_content_type ());
            }

            return mime_type;
        
        }

        private int64 get_size () throws Error {

            if (filename != null) {

                FileInfo info;
                int64 size;
                info = file.query_info (FILE_ATTRIBUTE_STANDARD_SIZE, FileQueryInfoFlags.NONE, null);
                size = info.get_size ();
                return size;

            }

        }

        private bool can_write () throws Error {

            if (filename != null) {

                FileInfo info;
                bool writable;
                info = file.query_info (FILE_ATTRIBUTE_ACCESS_CAN_WRITE, FileQueryInfoFlags.NONE, null);
                writable = info.get_attribute_boolean (FILE_ATTRIBUTE_ACCESS_CAN_WRITE);
                return writable;

            }

        }

