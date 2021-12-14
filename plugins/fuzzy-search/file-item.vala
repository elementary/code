public class FileItem : Gtk.Box {
    private SearchResult result;

    public string filepath {
        get {
            return result.full_path;
        }
    }
    public FileItem (SearchResult res) {
        result = res;
        Icon icon;
        var path_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 1);
        path_box.valign = Gtk.Align.CENTER;

        var path_label = new Gtk.Label (result.relative_path);
        path_label.halign = Gtk.Align.START;

        var filename_label = new Gtk.Label (Path.get_basename (result.relative_path));
        filename_label.halign = Gtk.Align.START;
        var attrs = new Pango.AttrList ();
        attrs.insert (Pango.attr_weight_new (Pango.Weight.BOLD));
        filename_label.attributes = attrs;

        try {
            var fi = File.new_for_path (result.full_path);
            var info = fi.query_info ("standard::*", 0);
            icon = ContentType.get_icon (info.get_content_type ());
        } catch (Error e) {
            icon = ContentType.get_icon ("text/plain");
        }

        var image = new Gtk.Image.from_gicon (icon, Gtk.IconSize.DND);
        image.get_style_context ().add_class ("fuzzy-file-icon");

        path_box.add (filename_label);
        path_box.add (path_label);

        add (image);
        add (path_box);
    }

    construct {
        orientation = Gtk.Orientation.HORIZONTAL;
        valign = Gtk.Align.CENTER;
    }
}
