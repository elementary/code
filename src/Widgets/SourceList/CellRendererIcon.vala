
/**
 * Class responsible for rendering Item.icon and Item.activatable. It also
 * notifies about clicks through the activated() signal.
 */
private class CellRendererIcon : Gtk.CellRendererPixbuf {
    public signal void activated (string path);

    private const Gtk.IconSize ICON_SIZE = Gtk.IconSize.MENU;

    public CellRendererIcon () {

    }

    construct {
        mode = Gtk.CellRendererMode.ACTIVATABLE;
        stock_size = ICON_SIZE;
    }

    public override bool activate (
        Gdk.Event event,
        Gtk.Widget widget,
        string path,
        Gdk.Rectangle background_area,
        Gdk.Rectangle cell_area,
        Gtk.CellRendererState flags
    ) {
        activated (path);
        return true;
    }
}
