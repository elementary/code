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
    public class StatusBar : Gtk.Statusbar {
    	
    	public ComboBoxText combo_syntax;
    	public SpinButton spin_width;
    	public ComboBoxText combo_scheme;
    	
    	public StatusBar () {
    		set_orientation (Orientation.HORIZONTAL);
    		
    		create ();
    	}
    	
    	void create () {
    	    var syntax_label = new Label (_("Syntax Highlighthing") + ":");
    	    combo_syntax = new ComboBoxText ();
    	    combo_syntax.changed.connect (on_syntax_changed);
    	    populate_syntax ();
    	    pack_start (syntax_label, false, false, 5);
    	    pack_start (combo_syntax, false, false, 5);
    	    pack_start (new VSeparator (), false, false, 5);
    	    
    	    var width_label = new Label (_("Tab width") + ":");
    	    spin_width = new SpinButton.with_range (1, 24, 1);
    	    spin_width.set_value (Scratch.settings.indent_width);
    	    spin_width.value_changed.connect (on_width_value_changed);
    	    pack_start (width_label, false, false, 5);
    	    pack_start (spin_width, false, false, 5);
    	    pack_start (new VSeparator (), false, false, 5);
    	    
    	    var scheme_label = new Label (_("Color Scheme") + ":");
    	    combo_scheme = new ComboBoxText ();
    	    combo_scheme.changed.connect (on_scheme_changed);
    	    populate_style_scheme ();
    	    pack_start (scheme_label, false, false, 5);
    	    pack_start (combo_scheme, false, false, 5);
    	    pack_start (new VSeparator (), false, false, 5);
    	    
    	    //just a spacer
    	    pack_start (new Label (""), true, true, 5);
    	    
    	    
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
    	
    	void populate_style_scheme () {

            string[] scheme_ids;
            var scheme_manager = new Gtk.SourceStyleSchemeManager ();
            scheme_ids = scheme_manager.get_scheme_ids ();

            foreach (string scheme_id in scheme_ids) {
                var scheme = scheme_manager.get_scheme (scheme_id);
                combo_scheme.append (scheme.id, scheme.name); 
            }

            combo_scheme.set_active_id (Scratch.settings.style_scheme);

        }
        
        void on_syntax_changed () {
        
        }
        
        void on_width_value_changed () {
            Scratch.settings.indent_width = (int) spin_width.value;
        }
        
        void on_scheme_changed () {
            Scratch.settings.style_scheme = combo_scheme.active_id;
        }
    }
    
}
