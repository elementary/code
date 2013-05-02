public class FMView : Gtk.ScrolledWindow {
    FM.ListModel model;
    GOF.Directory.Async dir;
    Gtk.TreeView view;
    Gtk.TreeSelection selection;
    public signal void select (GOF.File file);
    public FMView (GOF.File file) {
        model = Object.new (typeof (FM.ListModel)) as FM.ListModel;
        model.set ("has-child", true);
        view = new Gtk.TreeView ();
        view.set_model (model);
        add (view);
        dir = GOF.Directory.Async.from_file (file);
        load_dir (dir);

        var renderer_pix = new Gtk.CellRendererPixbuf ();
        var renderer = new Gtk.CellRendererText ();
        var column = new Gtk.TreeViewColumn ();
        column.pack_start (renderer_pix, false);
        column.set_cell_data_func (renderer_pix, (layout, renderer, model, iter) => {
            GOF.File file_pix;
            model.get (iter, 0, out file_pix, -1);

            if (file_pix != null)
                ((Gtk.CellRendererPixbuf)renderer).pixbuf = file_pix.pix;
            if(file_pix != null) {
                ((Gtk.CellRendererPixbuf)renderer).pixbuf = file_pix.pix;
                renderer.visible=true;
                renderer_pix.visible=true;
            }
            else {
                renderer.visible=false;
                renderer_pix.visible=false;
            }
        });
        column.pack_start (renderer, true);
        column.set_attributes (renderer, "text", 2);
        renderer.ellipsize = Pango.EllipsizeMode.END;
        view.append_column (column);
        
        selection = view.get_selection ();
        
        view.row_expanded.connect (on_expand);
        selection.changed.connect (on_selection_changed);
        view.headers_visible = false;
        view.enable_search = true;
        view.rules_hint = true;
        width_request = 150;
    }

    void on_selection_changed() {
        // Getting objects...
        Gtk.TreeIter? iter = null;
        Gtk.TreeModel? mod = null;
        selection.get_selected (out mod, out iter);
        // Check if selected file is dummy, if so do not act on selection (otherwise crashes)
        GOF.File sf;
        mod.get(iter,0,out sf,-1);
        if (sf==null) 
            return;
        var path = view.model.get_path (iter);
        // If there is something to expand...
        GOF.Directory.Async dir;
        if(model.file_for_path (path).is_folder ()) {
            model.load_subdirectory (path, out dir);
            load_dir (dir);
            dir.ref();
        }
        // else...
        else
            select (model.file_for_path (path));
    }

    void on_expand (Gtk.TreeIter iter, Gtk.TreePath path) {
        GOF.Directory.Async dir;
        if (model.load_subdirectory (path, out dir)) load_dir (dir);
        dir.ref();
    }

    void load_dir(GOF.Directory.Async dir)
    {
        dir.file_added.connect(on_file_added);
        if(dir.state == GOF.Directory.Async.State.NOT_LOADED)
        {
            dir.load();
            dir.file_loaded.connect(on_file_added);
        }
        else
        {
            load_file_hash_menu(dir);
        }
    }

    private bool load_file_hash_menu (GOF.Directory.Async dir)
    {
        foreach (var file in dir.file_hash.get_values ())
        {
            on_file_added (dir, (GOF.File) file);
        }
        return false;
    }

    void on_file_added(GOF.Directory.Async dir, GOF.File file)
    {
        //print(file.name + dir.file.name + "\n");
        file.update_icon(16);
        model.add_file(file, dir);
    }
}

//Gtk.Window win;
//FMView fm_view;

/*void on_select(GOF.File a)
{
    var fm = new FMView(a);
    fm_view.destroy();
    win.add(fm);
    win.show_all();
    fm_view = fm;
    fm_view.select.connect(on_select);
}*/

public class PluginView : Gtk.VBox
{
    FMView fm_view;
    public signal void select(GOF.File file);
    GOF.File current;
    public PluginView()
    {
        current = GOF.File.get(File.new_for_path("."));
        var fm = new FMView(current);
        pack_end(fm);
        fm_view = fm;
        fm_view.select.connect(on_select);
        show_all();
        add_combo();
    }

    Gtk.ComboBoxText combo;

    void add_combo()
    {
        if(combo == null)
        {
            combo = new Gtk.ComboBoxText();
            pack_start(combo, false, false);
            show_all();
        }
        else combo.disconnect(handler_id);
        combo.remove_all();
        combo.append_text("/");
        int i = 0;
        foreach(var dir in current.location.get_path().split("/"))
        {
            if(dir != "")
            {
                combo.append_text(dir);
                i++;
            }
        }
        combo.active = i;
        file_combo = current;
        combo_size = i;
        handler_id = combo.changed.connect(on_combo_changed);
    }

    ulong handler_id;

    int combo_size;
    GOF.File  file_combo;

    void on_combo_changed()
    {
        warning("comno changed");
        if(file_combo != null)
        {
            assert(file_combo.location != null);
            File file = file_combo.location.get_parent();
            print("%d", combo_size);
            for(int i = 0; i < combo_size - combo.active - 1; i++)
            {
                warning("current_file: %s", file.get_path());
                file = file.get_parent();
            }
            if(combo_size == combo.active) file = file_combo.location;
            var gof_file = new GOF.Directory.Async(file);
            on_select(gof_file.file);
        }
    }

    void on_select(GOF.File a)
    {
        if(a.is_directory)
        {
            var fm = new FMView(a);
            fm_view.destroy();
            pack_start(fm);
            show_all();
            fm_view = fm;
            fm_view.select.connect(on_select);
            current = a;
            add_combo();
        }
        else
        {
            select(a);
        }
    }


}

