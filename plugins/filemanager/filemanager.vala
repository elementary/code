using Scratch.Plugins;
public class Euclide.Plugins.FM : Peas.Activatable, Object {
    Interface plugins;
    PluginView view;

    public Object object { owned get; construct; }

    public FM () {
    }
    
    public void activate () {
        plugins = (Scratch.Plugins.Interface)object;
        plugins.register_function (Interface.Hook.SIDEBAR, on_notebook_sidebar);
    }

    public void deactivate () {
        if (view != null)
            view.destroy();
    }

    public void update_state () {
    }

    void on_notebook_sidebar ()
    {
        if (plugins.sidebar != null && plugins.scratch_app != null) {
            view = new PluginView();
            view.select.connect( (a) => { ((Scratch.ScratchApp)plugins.scratch_app).open_file(a.location.get_path()); });
            plugins.sidebar.append_page(view, new Gtk.Label(_("Files")));
        }
    }
}

[ModuleInit]
public void peas_register_types (GLib.TypeModule module) {
  var objmodule = module as Peas.ObjectModule;
  objmodule.register_extension_type (typeof (Peas.Activatable),
                                     typeof (Euclide.Plugins.FM));
}
