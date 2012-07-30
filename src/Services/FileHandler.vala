// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/***
  BEGIN LICENSE

  Copyright (C) 2011-2012 Mario Guerriero <mefrio.g@gmail.com>
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
    
    public enum FileOption {
        EXISTS,
        IS_DIR,
        IS_EXECUTABLE
    }
    
    public class FileHandler : GLib.Object {
    
        public static string load_content (string path) {
            var file = File.new_for_path (path);
            var dis = new DataInputStream (file.read ());
                var text = new StringBuilder ();
                string line;
                while ((line = dis.read_line (null)) != null) {
                    text.append (line);
                    text.append_c ('\n');
            }
            return text.str;
        }    
        
        public static string load_content_from_uri (string uri) {
            var file = File.new_for_uri (uri);
            var dis = new DataInputStream (file.read ());
                var text = new StringBuilder ();
                string line;
                while ((line = dis.read_line (null)) != null) {
                    text.append (line);
                    text.append_c ('\n');
            }
            return text.str;
        }
        
        /*public static bool set_content (string path, string content) {
        }    
        
        public static bool set_content_uri (string uri, string content) {
        }
        
        public static bool move (string path, string new_path) {
        }
        
        public static bool move_uri (string uri, string new_uri) {
        }
        
        public static bool copy (string path, string new_path) {
        }
        
        public static bool copy_uri (string uri, string new_uri) {
        }
        
        public static bool backup (string path) {
        }

        public static bool backup_uri (string uri) {
        }
        
        public static bool query_option (FileOption option) {
        }*/
        
    }

}