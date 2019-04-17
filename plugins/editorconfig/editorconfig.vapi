[CCode (cprefix = "editorconfig_", lower_case_cprefix = "editorconfig_", cheader_filename = "editorconfig/editorconfig.h")]
namespace EditorConfig {
    [CCode (cname = "editorconfig_handle", free_function = "editorconfig_handle_destroy")]
    [Compact]
    public class Handle {
        [CCode (cname="editorconfig_handle_init")]
        public Handle ();
        public void get_version (out int major, out int minor, out int patch);
        public void set_version (int major, int minor, int patch);
        public void set_conf_file_name (string conf_file_name);
        public unowned string? get_conf_file_name ();
        public void get_name_value (int n, out unowned string? name, out unowned string? value);
        public int get_name_value_count ();
        [CCode (cname="editorconfig_parse", instance_pos = 2.9)]
        public int parse (string full_filename);
    }

    public enum ParsingErrorCode {
        [CCode (cname = "EDITORCONFIG_PARSE_NOT_FULL_PATH")]
        NOT_FULL_PATH,
        [CCode (cname = "EDITORCONFIG_PARSE_MEMORY_ERROR")]
        MEMORY_ERROR,
        [CCode (cname = "EDITORCONFIG_PARSE_VERSION_TOO_NEW")]
        VERSION_TOO_NEW
    }

    public unowned string? get_error_msg (int err_num);
    public void get_version (out int major, out int minor, out int patch);
    public unowned string? get_version_suffix ();
}
