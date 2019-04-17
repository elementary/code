[CCode (cheader_filename = "fontconfig/fontconfig.h")]
namespace Fc {
    [Compact]
    [CCode (cname = "FcConfig", destroy_function = "", has_type_id = "false")]
    public class Config {
        [CCode (cname = "FcConfigAppFontAddFile")]
        public bool add_app_font (string path);
    }

    [CCode (cname = "FcInitLoadConfigAndFonts")]
    public static unowned Config init ();
}
