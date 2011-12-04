/*
 * Copyright (C) 2011 Lucas Baudin <xapantu@gmail.com>
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

public class Scratch.Widgets.ComboBoxSyntax : Gtk.ComboBoxText
{
    public string language_id {get; set;}
    public ComboBoxSyntax () {
    }
    
    public void load () {
        id_column = 1;
        populate_syntax ();
        language_id = "normal";
        active_id = language_id;
        changed.connect( () => {
            language_id = active_id;
        });
        notify["language-id"].connect( () => { active_id = language_id; });
    }

    void populate_syntax () {
         append ("normal", _("Normal text"));
         append ("sh", "Bash");
         append ("c", "C");
         append ("C#", "c-sharp");
         append ("cpp", "C++");
         append ("cmake", "CMake");
         append ("css", "CSS");
         append ("desktop", ".desktop");
         append ("diff", "Diff");
         append ("fortran", "Fortran");
         append ("gettext-translation", "Gettext");
         append ("html", "HTML");
         append ("ini", "ini");
         append ("java", "Java");
         append ("js", "JavaScript");
         append ("latext", "LaTex");
         append ("lua", "Lua");
         append ("makefile", "MakeFile");
         append ("objc", "Objective-C");
         append ("pascal", "Pascal");
         append ("perl", "Perl");
         append ("php", "PHP");
         append ("python", "Python");
         append ("ruby", "Ruby");
         append ("vala", "Vala");
         append ("xml", "XML");
    }
}
