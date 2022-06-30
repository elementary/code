// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/***
  BEGIN LICENSE

  Copyright (C) 2011-2013 Mario Guerriero <mario@elementaryos.org>
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
        public static bool can_open_file (File file, out bool is_folder) {
            is_folder = false;
            if (file == null || file.get_path () == null) {
                warning ("Ignoring  file %s. Cannot determine path",
                    file != null ? file.get_uri () ?? "null" : "null"
                );

                return false;
            }

            // For now only allow diretories and regular files to be opened from commandline
            // TODO Consider need for handling other types
            var type = file.query_file_type (FileQueryInfoFlags.NONE);
            switch (type) {
                case FileType.DIRECTORY:
                     is_folder = true;
                     return true;
                case FileType.REGULAR:
                case FileType.UNKNOWN: // Cannot be sure it is not a text file so try
                    return true;
                default:
                    warning ("Cannot open %s. Cannot handle file type %s", file.get_path (), type.to_string ());
                    return false;
            }
        }

        public static async string? load_content_from_file (File file) {
            var text = new StringBuilder ();

            try {
                var dis = new DataInputStream (file.read ());
                string line = null;
                while ((line = yield dis.read_line_async (Priority.DEFAULT)) != null) {
                    if (text.len != 0)
                        text.append_c ('\n');

                    text.append (line);
                }
                return text.str;
            } catch (Error e) {
                warning ("Cannot read \"%s\": %s", file.get_basename (), e.message);
                return null;
            }
        }

        public static string? load_content_from_file_sync (File file) {
            var text = new StringBuilder ();

            try {
                var dis = new DataInputStream (file.read ());
                string line = null;
                while ((line = dis.read_line (null, null)) != null) {
                    if (line != "\n") {
                        if (text.len != 0)
                            text.append_c ('\n');

                        text.append (line);
                    }
                }
                return text.str;
            } catch (Error e) {
                warning ("Cannot read \"%s\": %s", file.get_basename (), e.message);
                return null;
            }
        }

        public static bool move (string path, string new_path) {
            var old = File.new_for_path (path);
            var newpath = File.new_for_path (new_path);

            if (!newpath.query_exists ()) {
                try {
                    old.move (newpath, FileCopyFlags.NONE);
                    return true;
                } catch (Error e) {
                    warning (e.message);
                    return false;
                }
            }
            else
                return false;
        }

        public static bool move_uri (string uri, string new_uri) {
            var old = File.new_for_uri (uri);
            var newuri = File.new_for_uri (new_uri);

            if (!newuri.query_exists ()) {
                try {
                    old.move (newuri, FileCopyFlags.NONE);
                    return true;
                } catch (Error e) {
                    warning (e.message);
                    return false;
                }
            }
            else
                return false;
        }

        public static bool copy (string path, string new_path) {
            var old = File.new_for_path (path);
            var newpath = File.new_for_path (new_path);

            if (!newpath.query_exists ()) {
                try {
                    old.copy (newpath, FileCopyFlags.NONE);
                    return true;
                } catch (Error e) {
                    warning (e.message);
                    return false;
                }
            }
            else
                return false;
        }
    }

}
