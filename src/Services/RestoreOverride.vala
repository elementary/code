public class RestoreOverride : GLib.Object {
    public GLib.File file { get; construct; }
    public SelectionRange range { get; construct; }

    public RestoreOverride (GLib.File file, SelectionRange range) {
        Object (
            file: file,
            range: range
        );
    }
}