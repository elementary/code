/*-
* Copyright (c) 2017-2025 elementary LLC. (https://elementary.io),
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

/**
 * Class for easily dealing with files.
 */
public class Scratch.FolderManager.File : Object {
    public static int compare (File a, File b) {
        if (a.is_valid_directory && b.is_valid_textfile) {
            return -1;
        }
        if (a.is_valid_textfile && b.is_valid_directory) {
            return 1;
        }

        return strcmp (a.path.collate_key_for_filename (),
                       b.path.collate_key_for_filename ());
    }
    // returns the path the file
    public string path { get; construct; }
    public GLib.File file { get; private set; }

    // returns the name of the file for display
    public string name {
        get {
            if (_name != null) {
                return _name;
            }

            if (info == null) {
                _name = file.get_basename ();
            } else {
                _name = info.get_display_name ();
            }

            return _name;
        }
    }

    // returns the icon of the file's content type
    public GLib.Icon icon {
        get {
            if (_icon != null) {
                return _icon;
            }

            if (info != null) {
                _icon = GLib.ContentType.get_icon (info.get_content_type ());
            } else {
                _icon = new ThemedIcon ("missing-image");
            }

            return _icon;
        }
    }

    // checks if file exists
    public bool exists {
        get { return file.query_exists (); }
    }

    // Checks if we're dealing with a non-backup directory
    // If parent is hidden then inherit validity from parent
    public bool is_valid_directory {
        get {
            if (_is_valid_directory == null) {
                _is_valid_directory = info != null &&
                                      !info.get_is_backup () &&
                                      info.get_file_type () == FileType.DIRECTORY;
            }

            return _is_valid_directory;
        }
    }

    // checks if we're dealing with a textfile
    public bool is_valid_textfile {
        get {
            if (_is_valid_textfile == null) {
                _is_valid_textfile = !path.has_suffix ("~") && Utils.check_if_valid_text_file (path, info);
            }

            return _is_valid_textfile;
        }
    }

    // Files can be executed and folders can be cd'd into
    public bool is_executable {
        get {
            // We queried this attribute on construction
            if (info != null && info.has_attribute (FileAttribute.ACCESS_CAN_EXECUTE)) {
                return info.get_attribute_boolean (FileAttribute.ACCESS_CAN_EXECUTE);
            }

            return false;
        }
    }

    // returns a list of all children of a directory
    public Gee.Collection <File> children {
        owned get {
            if (children_valid) {
                return _children;
            }

            _children.clear ();

            try {
                var enumerator = file.enumerate_children (
                    GLib.FileAttribute.STANDARD_NAME,
                    FileQueryInfoFlags.NONE
                );

                var file_info = new FileInfo ();
                while ((file_info = enumerator.next_file ()) != null) {
                    var child = file.get_child (file_info.get_name ());
                    var child_file = new File (child.get_path ());
                    if (child_file.is_valid_directory || child_file.is_valid_textfile) {
                        _children.add (child_file);
                    }
                }

                children_valid = true;
            } catch (GLib.Error error) {
                warning (error.message);
            }

            return _children;
        }
    }

    private GLib.FileInfo? info = null; // Non-null after loading
    private string _name;
    private GLib.Icon? _icon = null;
    private bool? _is_valid_directory = null;
    private bool? _is_valid_textfile = null;
    private bool children_valid = false;
    private Gee.ArrayList <File> _children = new Gee.ArrayList <File> ();

    public File (string path) {
        Object (path: path);
    }

    construct {
        file = GLib.File.new_for_path (path);
        info = new FileInfo ();
        try {
            var query_string = FileAttribute.STANDARD_CONTENT_TYPE + "," +
                                FileAttribute.STANDARD_IS_BACKUP + "," +
                                FileAttribute.STANDARD_IS_HIDDEN + "," +
                                FileAttribute.STANDARD_DISPLAY_NAME + "," +
                                FileAttribute.STANDARD_TYPE + "," +
                                FileAttribute.ACCESS_CAN_EXECUTE;

            // We assume the attributes do not change during the lifetime of this object
            info = file.query_info (query_string, FileQueryInfoFlags.NONE);
        } catch (GLib.Error error) {
            info = null;
            warning (error.message);
        }
    }

    public void rename (string name) {
        try {
            if (exists) {
                file.set_display_name (name);
            }
        } catch (GLib.Error error) {
            warning (error.message);
        }
    }


    public void trash () {
        try {
            file.trash ();
        } catch (GLib.Error error) {
            warning (error.message);
        }
    }

    public void invalidate_cache () {
        children_valid = false;
    }
}
