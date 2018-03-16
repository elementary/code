/*
* Copyright (c) 2018 elementary LLC. (https://github.com/elementary)
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 3 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*/

[CCode (cheader_filename = "editorconfig/editorconfig_handle.h,editorconfig/editorconfig.h")]
namespace EditorConfig {

    [CCode (cname = "void", free_function = "editorconfig_handle_destroy")]
    [Compact]
    public class Handle {
        [CCode (cname = "editorconfig_handle_init")]
        public Handle ();

        [CCode (cname = "editorconfig_handle_get_version")]
        public void handle_get_version (out int major, out int minor, out int patch);

        [CCode (cname = "editorconfig_handle_set_version")]
        public void handle_set_version (int major, int minor, int patch);

        [CCode (cname = "editorconfig_handle_set_conf_file_name")]
        public void set_conf_file_name (string conf_file_name);

        [CCode (cname = "editorconfig_handle_get_conf_file_name")]
        public unowned string? get_conf_file_name ();

        [CCode (cname = "editorconfig_handle_get_name_value")]
        public void get_name_value (int n, out unowned string? name, out unowned string? value);

        [CCode (cname = "editorconfig_handle_get_name_value_count")]
        public int get_name_value_count ();
    }

    public const int EDITORCONFIG_PARSE_NOT_FULL_PATH;
    public const int EDITORCONFIG_PARSE_MEMORY_ERROR;
    public const int EDITORCONFIG_PARSE_VERSION_TOO_NEW;

    [CCode (cname = "editorconfig_parse")]
    public int parse (string full_filename, Handle h);

    [CCode (cname = "editorconfig_get_error_msg")]
    public unowned string? get_error_msg (int err_num);

    [CCode (cname = "editorconfig_get_version")]
    public void get_version (out int major, out int minor, out int patch);

    [CCode (cname = "editorconfig_get_version_suffix")]
    public unowned string? get_version_suffix ();
}
