public class Scratch.Widgets.GitGutterRenderer : Gtk.SourceGutterRenderer {
    // These style_ids must be present in the "classic" SourceStyleScheme (or allowed Code SourceStyleSchemes) to avoid terminal spam)
    public const string ADDED_STYLE_ID = "diff:added-line";
    public const string REMOVED_STYLE_ID = "diff:removed-line";
    public const string CHANGED_STYLE_ID = "diff:changed-line";
    public const string REPLACES_DELETED_STYLE_ID = "diff:special-case";
    public const string NONE_STYLE_ID = "background-pattern";

    private static Gtk.SourceStyleScheme? fallback_scheme;

    public Gee.HashMap<int, Services.VCStatus> line_status_map;
    public Gee.HashMap<Services.VCStatus, Gdk.RGBA?> status_color_map;
    public FolderManager.ProjectFolderItem? project { get; set; default = null; }

    static construct {
        fallback_scheme = Gtk.SourceStyleSchemeManager.get_default ().get_scheme ("classic"); // We can assume this always exists
    }

    construct {
        line_status_map = new Gee.HashMap<int, Services.VCStatus> ();
        status_color_map = new Gee.HashMap<Services.VCStatus, Gdk.RGBA?> ();

        set_size (5);
        set_visible (true);
    }

    public void set_style_scheme (Gtk.SourceStyleScheme? scheme) {
        update_status_color_map (Services.VCStatus.ADDED, scheme, ADDED_STYLE_ID);
        update_status_color_map (Services.VCStatus.REMOVED, scheme, REMOVED_STYLE_ID);
        update_status_color_map (Services.VCStatus.CHANGED, scheme, CHANGED_STYLE_ID);
        update_status_color_map (Services.VCStatus.REPLACES_DELETED, scheme, REPLACES_DELETED_STYLE_ID);
        update_status_color_map (Services.VCStatus.NONE, scheme, NONE_STYLE_ID, false);
    }

    private void update_status_color_map (Services.VCStatus status,
                                          Gtk.SourceStyleScheme? scheme,
                                          string style_id,
                                          bool use_foreground = true) {

        Gtk.SourceStyle style = null;
        if (scheme != null) {
            style = scheme.get_style (style_id);
            if (style != null) {
                if (use_foreground && style.foreground == null || !use_foreground && style.background == null) {
                    style = null;
                }
            }
        }

        if (style == null) {
            style = fallback_scheme.get_style (style_id);
        }

        var color = Gdk.RGBA ();
        color.parse (use_foreground ? style.foreground : style.background);
        status_color_map.set (status, color);
    }

    public override void draw (Cairo.Context cr,
                               Gdk.Rectangle bg,
                               Gdk.Rectangle area,
                               Gtk.TextIter start,
                               Gtk.TextIter end,
                               Gtk.SourceGutterRendererState state) {

        //Gutter and diff lines numbers start at one, source lines start at 0
        var gutter_line_no = start.get_line () + 1;
        if (line_status_map.has_key (gutter_line_no)) {
            set_background (status_color_map[line_status_map[gutter_line_no]]);
        } else {
            set_background (status_color_map [Services.VCStatus.NONE]);
        }

        base.draw (cr, bg, area, start, end, state);
    }
}
