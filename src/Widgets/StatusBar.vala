// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*
 * Copyright (c) 2011 Mario Guerriero <mefrio.g@gmail.com>
 *
 * This is a free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; either version 2 of the
 * License, or (at your option) any later version.
 *
 * This is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public
 * License along with this program; see the file COPYING.  If not,
 * write to the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 *
 */

using Gtk;

namespace Granite.Widgets {
    Pango.FontDescription small_font;
    class ToolItemLabel : Gtk.ToolItem
    {
        Gtk.Label _label;
        public string label { get { return _label.label; } set { _label.label = value; } }
        
        public ToolItemLabel(string label)
        {
            _label = new Gtk.Label(label);
            _label.modify_font(small_font);
            add(_label);
        }
    }
    public class StatusBar : Gtk.Toolbar {
	    
	    Scratch.MainWindow window;
	    
    	public ComboBoxText combo_syntax;
    	public SpinButton spin_width;
    	
    	public string language_id { set; get; }
    	ComboBoxText combo_scheme;
    	public Scratch.Services.SearchManager search_manager;
    	
    	public StatusBar (Gtk.ActionGroup action_group) {
    	    
    	    this.window = get_toplevel () as Scratch.MainWindow;
    	    
            small_font = get_style_context().get_font(Gtk.StateFlags.NORMAL);
            small_font.set_size(small_font.get_size() - Pango.units_from_double(2));
    		set_orientation (Orientation.HORIZONTAL);
    		search_manager = new Scratch.Services.SearchManager (action_group);
            Scratch.settings.schema.bind("search-sensitive", search_manager, "case-sensitive", SettingsBindFlags.DEFAULT);
            Scratch.settings.schema.bind("search-loop", search_manager, "cycle-search", SettingsBindFlags.DEFAULT);
    		
    		get_style_context().add_class("status-toolbar");
    		
    		notify["language-id"].connect(on_language_id_changed);
    		
    		create ();
        }
        
        void on_language_id_changed()
        {
            combo_syntax.active_id = language_id;
        }
	
        void create () {
             add(new ToolItemLabel (_("Syntax Highlighthing") + ":   "));
             combo_syntax = new ComboBoxText ();
             combo_syntax.changed.connect (on_syntax_changed);
             populate_syntax ();
             var combo_tool = new Gtk.ToolItem ();
             combo_tool.add(combo_syntax);
             add(combo_tool);
             combo_syntax.get_child().modify_font(small_font);

             add (new Gtk.SeparatorToolItem ());

             add(new ToolItemLabel (_("Tab width") + ":   "));
             spin_width = new SpinButton.with_range (1, 24, 1);
             spin_width.modify_font(small_font);
             Scratch.settings.schema.bind("indent-width", spin_width, "value", SettingsBindFlags.DEFAULT);
             var spin_tool = new Gtk.ToolItem ();
             spin_tool.add(spin_width);
             add(spin_tool);

             add (new Gtk.SeparatorToolItem ());

             add(new ToolItemLabel (_("Color Scheme") + ":   "));
             combo_scheme = new ComboBoxText ();
             populate_style_scheme ();
             combo_scheme.get_child().modify_font(small_font);
             Scratch.settings.schema.bind("style-scheme", combo_scheme, "active-id", 0);
             var scheme_tool = new Gtk.ToolItem ();
             scheme_tool.add (combo_scheme);
             add(scheme_tool);
             add (new Gtk.SeparatorToolItem ());

             add_spacer ();
             
             
             Scratch.settings.schema.bind("search-sensitive", search_manager, "case-sensitive", SettingsBindFlags.DEFAULT);
             Scratch.settings.schema.bind("search-loop", search_manager, "cycle-search", SettingsBindFlags.DEFAULT);
             
             add (new SeparatorToolItem ());
             add (search_manager.get_arrow_previous ());
             add (search_manager.get_arrow_next ());
             add (search_manager.get_search_entry ());
             add (search_manager.get_replace_entry ());
             add (search_manager.get_go_to_entry ());
             
             show_all ();
    	    
    	}
    	
        void populate_syntax () {
             combo_syntax.append ("normal", _("Normal text"));
             combo_syntax.append ("sh", "Bash");
             combo_syntax.append ("c", "C");
             combo_syntax.append ("C#", "c-sharp");
             combo_syntax.append ("cpp", "C++");
             combo_syntax.append ("cmake", "CMake");
             combo_syntax.append ("css", "CSS");
             combo_syntax.append ("desktop", ".desktop");
             combo_syntax.append ("diff", "Diff");
             combo_syntax.append ("fortran", "Fortran");
             combo_syntax.append ("gettext-translation", "Gettext");
             combo_syntax.append ("html", "HTML");
             combo_syntax.append ("ini", "ini");
             combo_syntax.append ("java", "Java");
             combo_syntax.append ("js", "JavaScript");
             combo_syntax.append ("latext", "LaTex");
             combo_syntax.append ("lua", "Lua");
             combo_syntax.append ("makefile", "MakeFile");
             combo_syntax.append ("objc", "Objective-C");
             combo_syntax.append ("pascal", "Pascal");
             combo_syntax.append ("perl", "Perl");
             combo_syntax.append ("php", "PHP");
             combo_syntax.append ("python", "Python");
             combo_syntax.append ("ruby", "Ruby");
             combo_syntax.append ("vala", "Vala");
             combo_syntax.append ("xml", "XML");
        }
    	
    	void add_spacer () {
	
	        var spacer = new ToolItem ();
	        spacer.set_expand (true);
	        add (spacer);
	
        }
    	
    	void populate_style_scheme () {

            string[] scheme_ids;
            var scheme_manager = new Gtk.SourceStyleSchemeManager ();
            scheme_ids = scheme_manager.get_scheme_ids ();

            foreach (string scheme_id in scheme_ids) {
                var scheme = scheme_manager.get_scheme (scheme_id);
                combo_scheme.append (scheme.id, 
                scheme.name);
            }
        }

        void on_syntax_changed () {
            language_id = combo_syntax.active_id;
            /*Gtk.SourceLanguage lang;
            lang = window.current_tab.text_view.manager.get_language ( combo_syntax.get_active_id () );
            window.current_tab.text_view.buffer.set_language (lang);*/
        }
    }
    
}
