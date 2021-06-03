public class Scratch.Widgets.SourceGutterRenderer : Gtk.SourceGutterRenderer {
    public const string ADDED_STYLE_ID = "diff:added-line";
    public const string REMOVED_STYLE_ID = "diff:removed-line";
    public const string CHANGED_STYLE_ID = "diff:changed-line";
    public const string REPLACES_DELETED_STYLE_ID = "diff:removed-line";
    public const string NONE_STYLE_ID = "background-pattern";

    private static Gtk.SourceStyleScheme? fallback_scheme;

    public Gee.HashMap<int, Services.VCStatus> line_status_map;
    public Gee.HashMap<Services.VCStatus, Gdk.RGBA?> status_color_map;
    public FolderManager.ProjectFolderItem? project { get; set; default = null; }
    public string workdir_path {
        get {
            return project != null ? project.top_level_path : "";
        }
    }

    public void set_style_scheme (Gtk.SourceStyleScheme? scheme) {
            update_status_color_map (Services.VCStatus.ADDED, get_style (scheme, ADDED_STYLE_ID), true);
            update_status_color_map (Services.VCStatus.REMOVED, get_style (scheme, REMOVED_STYLE_ID), true);
            update_status_color_map (Services.VCStatus.CHANGED, get_style (scheme, CHANGED_STYLE_ID), true);
            update_status_color_map (Services.VCStatus.REPLACES_DELETED, get_style (scheme, REPLACES_DELETED_STYLE_ID), true);
            update_status_color_map (Services.VCStatus.NONE, get_style (scheme, NONE_STYLE_ID, false), false);
    }

    static construct {
        fallback_scheme = Gtk.SourceStyleSchemeManager.get_default ().get_scheme ("classic"); // Assume this always exists?
    }

    construct {
        line_status_map = new Gee.HashMap<int, Services.VCStatus> ();
        status_color_map = new Gee.HashMap<Services.VCStatus, Gdk.RGBA?> ();

        set_size (3);
        set_visible (true);
    }

    private Gtk.SourceStyle? get_style (Gtk.SourceStyleScheme? scheme, string style_id, bool use_foreground = true) {
        if (scheme != null) {
            var style = scheme.get_style (style_id);
            if (style != null) {
                if (use_foreground && style.foreground != null || !use_foreground && style.background != null) {
                    return style;
                }
            }
        }

        if (fallback_scheme != null) {
            var style = fallback_scheme.get_style (style_id);
            if (use_foreground && style.foreground != null || !use_foreground && style.background != null) {
                return style;
            }
        }

        return null;
    }

    private void update_status_color_map (Services.VCStatus status, Gtk.SourceStyle? style, bool use_foreground = true) {
        var color = Gdk.RGBA ();
        string? spec = null;
        if (style != null) {
            if (use_foreground) {
                spec = style.foreground;
            } else {
                spec = style.background;
            }
        }

        if (spec == null) {
            spec = status.get_default_rgba_s ();
        }

        color.parse (spec);
        status_color_map.unset (status);
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
            var status = line_status_map [gutter_line_no];
            if (status_color_map.has_key (status)) {
                var color = status_color_map[status];
                set_background (color);
            }
            set_background (status_color_map[line_status_map[gutter_line_no]]);
        } else {
            set_background (status_color_map [Services.VCStatus.NONE]);
        }

        base.draw (cr, bg, area, start, end, state);
    }
}
