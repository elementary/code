using Gtk;

public class ToolButtonWithMenu : ToggleToolButton
{
    protected Menu menu;
    private PositionType _menu_orientation;
    protected PositionType menu_orientation{
        set{
            if(value == PositionType.TOP || value == PositionType.BOTTOM){
                value = PositionType.LEFT;
            }
            
            _menu_orientation = value;
        }
        get{
            return _menu_orientation;
        }
    }

    public ToolButtonWithMenu (Image image, string label, Menu _menu, PositionType menu_orientation = PositionType.LEFT)
    {
        this.menu_orientation = menu_orientation;
    	
        icon_widget = image;
        label_widget = new Label (label);
        ((Label) label_widget).use_underline = true;
        can_focus = true;
        set_tooltip_text ("Menu");
        menu = _menu;
        menu.attach_to_widget (this, null);
        menu.deactivate.connect(() => {
            active = false;
        });

        mnemonic_activate.connect(on_mnemonic_activate);
        menu.deactivate.connect(popdown_menu);
    }

    private bool on_mnemonic_activate (bool group_cycling)
    {
        // ToggleButton always grabs focus away from the editor,
        // so reimplement Widget's version, which only grabs the
        // focus if we are group cycling.
        if (!group_cycling) {
            activate ();
        } else if (can_focus) {
            grab_focus ();
        }

        return true;
    }

    protected new void popup_menu(Gdk.EventButton? ev)
    {
        try {
            menu.popup (null,
                        null,
                        get_menu_position,
                        (ev == null) ? 0 : ev.button,
                        (ev == null) ? get_current_event_time() : ev.time);
        } finally {
            // Highlight the parent
            if (menu.attach_widget != null)
                menu.attach_widget.set_state(StateType.SELECTED);
        }
    }

    protected void popdown_menu ()
    {
        menu.popdown ();

        // Unhighlight the parent
        if (menu.attach_widget != null)
            menu.attach_widget.set_state(Gtk.StateType.NORMAL);
    }
    
    public override void show_all(){
        base.show_all();
        menu.show_all();
    }

    private void get_menu_position (Menu menu, out int x, out int y, out bool push_in)
    {
        if (menu.attach_widget == null ||
            menu.attach_widget.get_window() == null) {
            // Prevent null exception in weird cases
            x = 0;
            y = 0;
            push_in = true;
            return;
        }

        menu.attach_widget.get_window().get_origin (out x, out y);
        Allocation allocation;
        menu.attach_widget.get_allocation(out allocation);


        x += allocation.x;
        y += allocation.y;

        int width, height;
        menu.get_size_request(out width, out height);

        if (y + height >= menu.attach_widget.get_screen().get_height())
            y -= height;
        else
            y += allocation.height;

        push_in = true;
    }
}
