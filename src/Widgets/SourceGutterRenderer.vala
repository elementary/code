public class Scratch.Widgets.SourceGutterRenderer : Gtk.SourceGutterRenderer {
    public Gee.HashMap<int, Services.VCStatus> line_status_map;
    public FolderManager.ProjectFolderItem? project { get; set; default = null; }
    public string workdir_path {
        get {
            return project != null ? project.top_level_path : "";
        }
    }

    construct {
        line_status_map = new Gee.HashMap<int, Services.VCStatus> ();
        set_size (3);
        set_visible (true);
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
            set_background (line_status_map.get (gutter_line_no).to_rgba ());
        } else {
            set_background (Services.VCStatus.NONE.to_rgba ());
        }

        base.draw (cr, bg, area, start, end, state);
    }
}
