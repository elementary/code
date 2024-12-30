/**
 * A cell renderer that only adds space.
 */
private class CellRendererSpacer : Gtk.CellRenderer {
    /**
     * Indentation level represented by this cell renderer
     */
    public int level { get; set; default = -1; }

    public override Gtk.SizeRequestMode get_request_mode () {
        return Gtk.SizeRequestMode.HEIGHT_FOR_WIDTH;
    }

    public override void get_preferred_width (Gtk.Widget widget, out int min_size, out int natural_size) {
        min_size = natural_size = 2 * (int) xpad;
    }

    public override void get_preferred_height_for_width (
        Gtk.Widget widget,
        int width,
        out int min_height,
        out int natural_height
    ) {
        min_height = natural_height = 2 * (int) ypad;
    }

    public override void render (
        Cairo.Context context,
        Gtk.Widget widget,
        Gdk.Rectangle bg_area,
        Gdk.Rectangle cell_area,
        Gtk.CellRendererState flags
    ) {
        // Nothing to do. This renderer only adds space.
    }
}
