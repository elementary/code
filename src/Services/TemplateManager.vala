/*
 * Copyright (C) 2011-2012 Lucas Baudin <xapantu@gmail.com>
 *               2013      Mario Guerriero <mario@elementaryos.org>
 *
 * This file is part of Scratch.
 *
 * Scratch is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 * 
 * Scratch is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See the GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License along
 * with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

using Gtk;

public abstract class Scratch.Template : Object {
    
    public abstract Gtk.Widget get_creation_box ();
    public abstract signal void loaded (File file);
    
    public static void configure_template (string origin, string destination, Gee.HashMap<string, string> variables) {
        debug ("Origin: %s, destination: %s\n", origin, destination);
        
        configure_directory (File.new_for_path(origin), File.new_for_path(destination), variables);
    }
    
    static void configure_directory (File origin, File destination, Gee.HashMap<string, string> variables) {
        /* First, let's check that these files actually exists and are directory */
        bool is_directory, exists;
        info_directory (origin, out is_directory, out exists);
        if (!is_directory || !exists) {
            warning ("Origin directory doesn't exist or isn't a directory.");
            return;
        }
        
        info_directory (destination, out is_directory, out exists);
        if (is_directory || exists) {
            warning ("Destination directory already exists...");
            return;
        }
        
        try {
            destination.make_directory ();
        } catch (Error e) {
            warning (e.message);
            return;
        }
        
        List<FileInfo> files;
        List<File> dirs;
        enumerate_directory (origin, out files, out dirs);
        foreach (var file in files) {
            if (file.get_content_type ().contains ("text") || 
                file.get_content_type ().contains ("x-desktop")) {
                
                var gfile = File.new_for_path (Path.build_filename (origin.get_path (), file.get_name ()));

                string content = Scratch.Services.FileHandler.load_content_from_file_sync (gfile);
                
                if (variables != null) {
                    foreach (var entry in variables.entries)
                        content = content.replace ("$$" + entry.key, entry.value);
                }
                try {
                    string dest_path = Path.build_filename (destination.get_path (), file.get_name ());
                    foreach (var entry in variables.entries)
                        dest_path = dest_path.replace ("$$" + entry.key, entry.value);
                    FileUtils.set_contents (dest_path, content);
                } catch (Error e) {
                    warning (e.message);
                }
            }
            else {
                var orig = File.new_for_path (Path.build_filename (origin.get_path (), file.get_name ()));
                var dest = File.new_for_path (Path.build_filename (destination.get_path (), file.get_name ()));
                try {
                    orig.copy (dest, 0);
                } catch (Error e) {
                    warning (e.message);
                    return;
                }
            }
                
        }
        foreach (var dir in dirs) {
            configure_directory (dir, File.new_for_path (destination.get_path () + "/" + dir.get_basename ()), variables);
        }
    }
    
    public static void enumerate_directory (File origin, out List<FileInfo> files, out List<File> directories) {
        files = new List<FileInfo> ();
        directories = new List<File> ();
        
        FileEnumerator? enumerator = null;
        
        try {
            enumerator = origin.enumerate_children ("standard::type,standard::name,standard::content-type", 0);
        } catch (Error e) {
            warning (e.message);
            return;
        }
        
        FileInfo? file_info = null;
        
        try {
            file_info = enumerator.next_file ();
        } catch (Error e) {
            warning (e.message);
        }
        
        while (file_info != null) {
            if (file_info.get_file_type () == FileType.DIRECTORY) {
                directories.append (File.new_for_path (origin.get_path () + "/" + file_info.get_name ()));
            }
            else if (file_info.get_file_type () == FileType.REGULAR) {
                files.append (file_info);
            }
            try {
                file_info = enumerator.next_file ();
            } catch (Error e) {
                warning (e.message);
            }
        }
    }
    
    public static void info_directory (File file, out bool is_directory, out bool exists) {
        //var origin_info = origin.query_info ("standard::type", 0);
        var file_type = file.query_file_type (0 /* info flags: none */);
        exists = file_type != FileType.UNKNOWN;
        is_directory = file_type == FileType.DIRECTORY;
    }
}

public class Scratch.TestTemplate : Template {
    
    public override Gtk.Widget get_creation_box () {
        return new Gtk.Label("Test");
    }
    
}

public class TemplateButton : Button {
        
    private Image icon_image;
       
    public TemplateButton (string title, string description, string icon) {
        can_focus = false;
        set_relief (ReliefStyle.NONE);
           
        var main_box = new Box (Orientation.HORIZONTAL, 3);
        var text_box = new Box (Orientation.VERTICAL, 3);
        text_box.halign = Align.START;
            
        var title_label = new Label (Markup.printf_escaped ("<span weight='medium' size='11700'>%s</span>", title));
        title_label.use_markup = true;
        title_label.ellipsize = Pango.EllipsizeMode.END;
        title_label.halign = Align.START;
        title_label.valign = Align.START;
            
        var description_label = new Label (Markup.printf_escaped ("<span weight='medium' size='11400'>%s</span>", description));
        description_label.use_markup = true;
        description_label.ellipsize = Pango.EllipsizeMode.END;
        description_label.halign = Align.START;
        description_label.valign = Align.START;
        description_label.sensitive = false;
        
        Gdk.Pixbuf? pixbuf = null;    
        try {
            pixbuf = Gtk.IconTheme.get_default ().load_icon (icon, 64, 0);
        } catch (Error e) {
            warning (e.message);
        }
        
        if (pixbuf != null)
            icon_image = new Image.from_pixbuf (pixbuf);
        else
            icon_image = new Image.from_icon_name (icon, IconSize.DIALOG);
        icon_image.halign = Align.START;
            
        text_box.pack_start (new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0), true, true, 0); // Top spacing
        text_box.pack_start (title_label, false, false, 0);
        text_box.pack_start (description_label, false, false, 0);
        text_box.pack_start (new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0), true, true, 0); // Bottom spacing
            
        main_box.pack_start (icon_image, false, true, 0);
        main_box.pack_start (text_box, false, true, 0);
        
        this.add (main_box);
        this.show_all ();
    }
        
    public void set_icon_from_pixbuf (Gdk.Pixbuf pixbuf) {
        icon_image.set_from_pixbuf (pixbuf);
    }
        
}

/**
 * Global Template Manager for Scratch. Only one instance of this object should
 * be used at once. It is created by the main Granite.Application (ScratchApp) and
 * a reference can be got from the plugin manager.
 **/
public class Scratch.TemplateManager : GLib.Object {
    
    private Granite.Widgets.LightWindow dialog;
    
    private Scratch.Template current_template;
    
    private Gtk.Widget? parent = null;
    
    private Gtk.Grid grid;
    private int n_columns = 0; // One column
    private int left = 0; // No more than 1
    private int top = 0; // No more than 1
    private int width = 1; // Event 1
    private int height = 1; // Event 1
    
    public bool template_available = false;
    
    public signal void template_loaded (Template template, File file);
    
    public TemplateManager () {
        dialog = new Granite.Widgets.LightWindow (_("Templates"));
        
        this.grid = new Gtk.Grid ();
        this.grid.margin = 5;
        this.grid.row_spacing = 5;
        this.grid.column_spacing = 5;
        this.grid.row_homogeneous = true;
        this.grid.column_homogeneous = true;
        
        // Viewport
        ScrolledWindow scroll = new ScrolledWindow (null, null);
        scroll.height_request = 250;
        scroll.set_policy (PolicyType.NEVER, PolicyType.AUTOMATIC);
        scroll.add_with_viewport (grid);
        ((Viewport)scroll.get_child()).set_shadow_type (ShadowType.NONE);
        
        dialog.add (scroll);
        
        //register_template ("text-editor", "Sample", "sample template", typeof(TestTemplate));

    }
    
    /**
     * Register a new template
     * 
     * @param icon_id the icon id used in the IconView which shows all the template.
     * It will be used to launch an icon via Gtk.IconTheme.load_icon, so, any icon is
     * fine.
     * @param label The name of your template.
     * @param template_type The object type which must be instanciated when we click on
     * the icon on the IconView. It will be used to get the creation box and therefore must
     * inherit from #Scratch.Template.
     **/
    public void register_template (string icon_id, string label, string description, Type template_type) {
        var button = new TemplateButton (label, description, icon_id);
        append_button (button);
        
        button.clicked.connect (() => {
            current_template = (Scratch.Template) Object.new (template_type);
            this.dialog.hide ();
            var window = new Granite.Widgets.LightWindow (label);
            if (parent != null) window.set_transient_for ((Gtk.Window)parent);
            window.add (current_template.get_creation_box ());
            window.show_all ();
            current_template.loaded.connect ((file) => {
                template_loaded (current_template, file);
            });
        });
        
        template_available = true;
    }
    
    private void append_button (Widget button) {
        if (left > n_columns)
           left = 0;
               
        this.grid.attach (button, left, top, width, height);
            
        button.show ();
            
        if (left == n_columns) top++;
        left++;
    }
    
    /**
     * Show a dialog which contains an #Gtk.IconView with all templates available.
     * 
     * @param parent The parent window, or null.
     **/
    public void show_window (Gtk.Widget? parent) {
        this.parent = parent;
        
        if (template_available) {
            if (parent != null) dialog.set_transient_for ((Gtk.Window)parent);
            
            dialog.show_all ();
        }
    }
}
