[CCode (cheader_filename = "pango/pangofc-fontmap.h")]
namespace PangoFc {
    [CCode (cname = "pango_fc_font_map_set_config")]
    public static void attach_fontconfig_to_fontmap (Pango.FontMap map, Fc.Config config);
}
