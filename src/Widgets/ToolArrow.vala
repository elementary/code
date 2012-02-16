public class Granite.Widgets.ToolArrow : Gtk.ToolItem
{
    public signal void clicked();
    Gtk.ToggleButton button;
    public ToolArrow()
    {
        Gtk.CssProvider css = new Gtk.CssProvider();
        css.load_from_data("* { padding-left:0; padding-right:0; }", -1);
        var arrow = new Gtk.Arrow(Gtk.ArrowType.DOWN, Gtk.ShadowType.OUT);
        button = new Gtk.ToggleButton();
        button.button_press_event.connect( () => { clicked(); return true; });
        button.add(arrow);
        button.get_style_context().add_provider(css, 800);
        button.set_relief(Gtk.ReliefStyle.NONE);
        add(button);
    }
    
    public void set_state(bool v)
    {
        button.active = v;
    }
}