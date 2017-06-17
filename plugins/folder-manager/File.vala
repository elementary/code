/*-
 * Copyright (c) 2017 elementary LLC. (https://elementary.io),
 *               2013 Julien Spautz <spautz.julien@gmail.com>
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
 * Authored by: Julien Spautz <spautz.julien@gmail.com>, Andrei-Costin Zisu <matzipan@gmail.com>
 */

namespace Scratch.Plugins.FolderManager {

    /**
     * Class for easily dealing with files.
     */
    internal class File : GLib.Object {
        public GLib.File file { get; private set; }
        private GLib.FileInfo info;

        public File (string path) {
            Object (path: path);
        }

        // returns the path the file
        public string path {
            owned get {
                return file.get_path ();
            }
            set construct {
                load_file_for_path (value);
            }
        }

        // returns the basename of the file
        private string _name;
        public string name {
            get {
                if (_name != null) {
                    return _name;
                }

                if (info == null) {
                    return "";
                }

                _name = info.get_display_name ();
                return _name;
            }
        }

        // returns the icon of the file's content type
        private GLib.Icon? _icon = null;
        public GLib.Icon icon {
            get {
                if (_icon != null) {
                    return _icon;
                }

                _icon = GLib.ContentType.get_icon (info.get_content_type ());
                return _icon;
            }
        }

        // checks if file exists
        public bool exists {
            get { return file.query_exists (); }
        }

        // checks if we're dealing with a non-hidden, non-backup directory
        public bool is_valid_directory {
            get {
                if (info.get_is_hidden () || info.get_is_backup ()) {
                    return false;
                }

                if (info.get_file_type () == FileType.DIRECTORY) {
                    return true;
                }

                return false;
            }
        }

        // checks if we're dealing with a textfile
        public bool is_valid_textfile {
            get {
                if (info.get_is_hidden () || info.get_is_backup ()) {
                    return false;
                }

                if (info.get_file_type () == FileType.REGULAR &&
                    ContentType.is_a (info.get_content_type (), "text/*")) {
                    return true;
                }

                return false;
            }
        }

        // returns a list of all children of a directory
        private bool children_valid = false;
        private Gee.ArrayList <File> _children = new Gee.ArrayList <File> ();
        public Gee.Collection <File> children {
            owned get {
                if (children_valid) {
                    return _children;
                }

                _children.clear ();

                var parent = GLib.File.new_for_path (file.get_path ());
                try {
                    var enumerator = parent.enumerate_children (
                        GLib.FileAttribute.STANDARD_NAME,
                        FileQueryInfoFlags.NONE
                    );

                    var file_info = new FileInfo ();
                    while ((file_info = enumerator.next_file ()) != null) {
                        var child = parent.get_child (file_info.get_name ());
                        var file = new File (child.get_path ());

                        if (file.is_valid_directory || file.is_valid_textfile) {
                            _children.add (new File (child.get_path ()));
                        }
                    }

                    children_valid = true;
                } catch (GLib.Error error) {
                    warning (error.message);
                }

                return _children;
            }
        }

        private void load_file_for_path (string path) {
            file = GLib.File.new_for_path (path);

            info = new FileInfo ();
            try {
                var query_string = GLib.FileAttribute.STANDARD_CONTENT_TYPE + "," +
                                    GLib.FileAttribute.STANDARD_IS_BACKUP + "," +
                                    GLib.FileAttribute.STANDARD_IS_HIDDEN + "," +
                                    GLib.FileAttribute.STANDARD_DISPLAY_NAME + "," +
                                    GLib.FileAttribute.STANDARD_TYPE;

                info = file.query_info (query_string, FileQueryInfoFlags.NONE);
            } catch (GLib.Error error) {
                info = null;
                warning (error.message);
            }
        }

        /*public void rename (string name) {
            try {
                file.set_display_name (name);
            } catch (GLib.Error error) {
                warning (error.message);
            }
        }*/

        public void trash () {
            try {
                file.trash ();
            } catch (GLib.Error error) {
                warning (error.message);
            }
        }

        public void reset_cache () {
            _name = null;
            _icon = null;
            children_valid = false;
        }

        public static int compare (File a, File b) {
            if (a.is_valid_directory && b.is_valid_textfile)
                return -1;
            if (a.is_valid_textfile && b.is_valid_directory)
                return 1;
            return strcmp (a.path.collate_key_for_filename (),
                           b.path.collate_key_for_filename ());
        }
    }
}
