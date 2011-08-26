// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/***
  BEGIN LICENSE
	
  Copyright (C) 2011 Giulio Collura <random.cpp@gmail.com>
  This program is free software: you can redistribute it and/or modify it	
  under the terms of the GNU Lesser General Public License version 3, as published	
  by the Free Software Foundation.
	
  This program is distributed in the hope that it will be useful, but	
  WITHOUT ANY WARRANTY; without even the implied warranties of	
  MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR	
  PURPOSE.  See the GNU General Public License for more details.
	
  You should have received a copy of the GNU General Public License along	
  with this program.  If not, see <http://www.gnu.org/licenses/>	
  
  END LICENSE	
***/

using Gtk;

using Scratch.Services;

namespace Scratch.Dialogs {

    public class PasteBinDialog : Window {
        
        private MainWindow window;

        private VBox content;
        private HBox padding;

        private Entry name_entry;
		private ComboBoxText format_combo;
        private ComboBoxText expiry_combo;
        private CheckButton private_check;

        private Button cancel_button;
        private Button send_button;


		public string[,] languages = {
			//if default, code, desc, scratch-equivalent
			{"n", "4cs", "4CS", ""},
			{"n", "6502acme", "6502 ACME Cross Assembler", ""},
			{"n", "6502kickass", "6502 Kick Assembler", ""},
			{"n", "6502tasm", "6502 TASM/64TASS", ""},
			{"n", "abap", "ABAP", ""},
			{"n", "actionscript", "ActionScript", ""},
			{"n", "actionscript3", "ActionScript 3", ""},
			{"n", "ada", "Ada", ""},
			{"n", "algol68", "ALGOL 68", ""},
			{"n", "apache", "Apache Log", ""},
			{"n", "applescript", "AppleScript", ""},
			{"n", "apt_sources", "APT Sources", ""},
			{"n", "asm", "ASM (NASM)", ""},
			{"n", "asp", "ASP", ""},
			{"n", "autoconf", "autoconf", ""},
			{"n", "autohotkey", "Autohotkey", ""},
			{"n", "autoit", "AutoIt", ""},
			{"n", "avisynth", "Avisynth", ""},
			{"n", "awk", "Awk", ""},
			{"n", "bascomavr", "BASCOM AVR", ""},
			{"n", "bash", "Bash", "sh"},
			{"n", "basic4gl", "Basic4GL", ""},
			{"n", "bibtex", "BibTeX", ""},
			{"n", "blitzbasic", "Blitz Basic", ""},
			{"n", "bnf", "BNF", ""},
			{"n", "boo", "BOO", ""},
			{"n", "bf", "BrainFuck", ""},
			{"n", "c", "C", "c"},
			{"n", "c_mac", "C for Macs", ""},
			{"n", "cil", "C Intermediate Language", ""},
			{"n", "csharp", "C#", "c-sharp"},
			{"n", "cpp", "C++", "cpp"},
			{"n", "cpp-qt", "C++ (with QT extensions)", ""},
			{"n", "c_loadrunner", "C: Loadrunner", ""},
			{"n", "caddcl", "CAD DCL", ""},
			{"n", "cadlisp", "CAD Lisp", ""},
			{"n", "cfdg", "CFDG", ""},
			{"n", "chaiscript", "ChaiScript", ""},
			{"n", "clojure", "Clojure", ""},
			{"n", "klonec", "Clone C", ""},
			{"n", "klonecpp", "Clone C++", ""},
			{"n", "cmake", "CMake", "cmake"},
			{"n", "cobol", "COBOL", ""},
			{"n", "coffeescript", "CoffeeScript", ""},
			{"n", "cfm", "ColdFusion", ""},
			{"n", "css", "CSS", "css"},
			{"n", "cuesheet", "Cuesheet", ""},
			{"n", "d", "D", ""},
			{"n", "dcs", "DCS", ""},
			{"n", "delphi", "Delphi", ""},
			{"n", "oxygene", "Delphi Prism (Oxygene)", ""},
			{"n", "diff", "Diff", "diff"},
			{"n", "div", "DIV", ""},
			{"n", "dos", "DOS", ""},
			{"n", "dot", "DOT", ""},
			{"n", "e", "E", ""},
			{"n", "ecmascript", "ECMAScript", ""},
			{"n", "eiffel", "Eiffel", ""},
			{"n", "email", "Email", ""},
			{"n", "epc", "EPC", ""},
			{"n", "erlang", "Erlang", ""},
			{"n", "fsharp", "F#", ""},
			{"n", "falcon", "Falcon", ""},
			{"n", "fo", "FO Language", ""},
			{"n", "f1", "Formula One", ""},
			{"n", "fortran", "Fortran", "fortran"},
			{"n", "freebasic", "FreeBasic", ""},
			{"n", "gambas", "GAMBAS", ""},
			{"n", "gml", "Game Maker", ""},
			{"n", "gdb", "GDB", ""},
			{"n", "genero", "Genero", ""},
			{"n", "genie", "Genie", ""},
			{"n", "gettext", "GetText", "gettext-translation"},
			{"n", "go", "Go", ""},
			{"n", "groovy", "Groovy", ""},
			{"n", "gwbasic", "GwBasic", ""},
			{"n", "haskell", "Haskell", ""},
			{"n", "hicest", "HicEst", ""},
			{"n", "hq9plus", "HQ9 Plus", ""},
			{"n", "html4strict", "HTML", "html"},
			{"n", "html5", "HTML 5", ""},
			{"n", "icon", "Icon", ""},
			{"n", "idl", "IDL", ""},
			{"n", "ini", "INI file", "ini"},
			{"n", "inno", "Inno Script", ""},
			{"n", "intercal", "INTERCAL", ""},
			{"n", "io", "IO", ""},
			{"n", "j", "J", ""},
			{"n", "java", "Java", "java"},
			{"n", "java5", "Java 5", ""},
			{"n", "javascript", "JavaScript", "js"},
			{"n", "jquery", "jQuery", ""},
			{"n", "kixtart", "KiXtart", ""},
			{"n", "latex", "Latex", "latex"},
			{"n", "lb", "Liberty BASIC", ""},
			{"n", "lsl2", "Linden Scripting", ""},
			{"n", "lisp", "Lisp", ""},
			{"n", "llvm", "LLVM", ""},
			{"n", "locobasic", "Loco Basic", ""},
			{"n", "logtalk", "Logtalk", ""},
			{"n", "lolcode", "LOL Code", ""},
			{"n", "lotusformulas", "Lotus Formulas", ""},
			{"n", "lotusscript", "Lotus Script", ""},
			{"n", "lscript", "LScript", ""},
			{"n", "lua", "Lua", "lua"},
			{"n", "m68k", "M68000 Assembler", ""},
			{"n", "magiksf", "MagikSF", ""},
			{"n", "make", "Make", "makefile"},
			{"n", "mapbasic", "MapBasic", ""},
			{"n", "matlab", "MatLab", ""},
			{"n", "mirc", "mIRC", ""},
			{"n", "mmix", "MIX Assembler", ""},
			{"n", "modula2", "Modula 2", ""},
			{"n", "modula3", "Modula 3", ""},
			{"n", "68000devpac", "Motorola 68000 HiSoft Dev", ""},
			{"n", "mpasm", "MPASM", ""},
			{"n", "mxml", "MXML", ""},
			{"n", "mysql", "MySQL", ""},
			{"n", "newlisp", "newLISP", ""},
			{"n", "text", "None", "normal"},
			{"n", "nsis", "NullSoft Installer", ""},
			{"n", "oberon2", "Oberon 2", ""},
			{"n", "objeck", "Objeck Programming Langua", ""},
			{"n", "objc", "Objective C", "objc"},
			{"n", "ocaml-brief", "OCalm Brief", ""},
			{"n", "ocaml", "OCaml", ""},
			{"n", "pf", "OpenBSD PACKET FILTER", ""},
			{"n", "glsl", "OpenGL Shading", ""},
			{"n", "oobas", "Openoffice BASIC", ""},
			{"n", "oracle11", "Oracle 11", ""},
			{"n", "oracle8", "Oracle 8", ""},
			{"n", "oz", "Oz", ""},
			{"n", "pascal", "Pascal", "pascal"},
			{"n", "pawn", "PAWN", ""},
			{"n", "pcre", "PCRE", ""},
			{"n", "per", "Per", ""},
			{"n", "perl", "Perl", "perl"},
			{"n", "perl6", "Perl 6", ""},
			{"n", "php", "PHP", "php"},
			{"n", "php-brief", "PHP Brief", ""},
			{"n", "pic16", "Pic 16", ""},
			{"n", "pike", "Pike", ""},
			{"n", "pixelbender", "Pixel Bender", ""},
			{"n", "plsql", "PL/SQL", ""},
			{"n", "postgresql", "PostgreSQL", ""},
			{"n", "povray", "POV-Ray", ""},
			{"n", "powershell", "Power Shell", ""},
			{"n", "powerbuilder", "PowerBuilder", ""},
			{"n", "proftpd", "ProFTPd", ""},
			{"n", "progress", "Progress", ""},
			{"n", "prolog", "Prolog", ""},
			{"n", "properties", "Properties", ""},
			{"n", "providex", "ProvideX", ""},
			{"n", "purebasic", "PureBasic", ""},
			{"n", "pycon", "PyCon", ""},
			{"n", "python", "Python", "python"},
			{"n", "q", "q/kdb+", ""},
			{"n", "qbasic", "QBasic", ""},
			{"n", "rsplus", "R", ""},
			{"n", "rails", "Rails", ""},
			{"n", "rebol", "REBOL", ""},
			{"n", "reg", "REG", ""},
			{"n", "robots", "Robots", ""},
			{"n", "rpmspec", "RPM Spec", ""},
			{"n", "ruby", "Ruby", "ruby"},
			{"n", "gnuplot", "Ruby Gnuplot", ""},
			{"n", "sas", "SAS", ""},
			{"n", "scala", "Scala", ""},
			{"n", "scheme", "Scheme", ""},
			{"n", "scilab", "Scilab", ""},
			{"n", "sdlbasic", "SdlBasic", ""},
			{"n", "smalltalk", "Smalltalk", ""},
			{"n", "smarty", "Smarty", ""},
			{"n", "sql", "SQL", ""},
			{"n", "systemverilog", "SystemVerilog", ""},
			{"n", "tsql", "T-SQL", ""},
			{"n", "tcl", "TCL", ""},
			{"n", "teraterm", "Tera Term", ""},
			{"n", "thinbasic", "thinBasic", ""},
			{"n", "typoscript", "TypoScript", ""},
			{"n", "unicon", "Unicon", ""},
			{"n", "uscript", "UnrealScript", ""},
			{"n", "vala", "Vala", "vala"},
			{"n", "vbnet", "VB.NET", ""},
			{"n", "verilog", "VeriLog", ""},
			{"n", "vhdl", "VHDL", ""},
			{"n", "vim", "VIM", ""},
			{"n", "visualprolog", "Visual Pro Log", ""},
			{"n", "vb", "VisualBasic", ""},
			{"n", "visualfoxpro", "VisualFoxPro", ""},
			{"n", "whitespace", "WhiteSpace", ""},
			{"n", "whois", "WHOIS", ""},
			{"n", "winbatch", "Winbatch", ""},
			{"n", "xbasic", "XBasic", ""},
			{"n", "xml", "XML", "xml"},
			{"n", "xorg_conf", "Xorg Config", ""},
			{"n", "xpp", "XPP", ""},
			{"n", "yaml", "YAML", ""},
			{"n", "z80", "Z80 Assembler", ""},
			{"n", "zxbasic", "ZXBasic", ""} };
        
        public PasteBinDialog (MainWindow? window) {

            this.window = window;
            this.title = _("Share via PasteBin");
            this.type_hint = Gdk.WindowTypeHint.DIALOG;
            this.set_modal (true);
            this.set_transient_for (window);
           
            create_dialog ();

            send_button.clicked.connect (send_button_clicked);
            cancel_button.clicked.connect (cancel_button_clicked);

        }

        private void create_dialog () {

            content = new VBox (false, 10);
            padding = new HBox (false, 10);

            name_entry = new Entry ();
            name_entry.text = "Test";
            var name_entry_l = new Label (_("Name:"));
            var name_entry_box = new HBox (false, 58);
            name_entry_box.pack_start (name_entry_l, false, true, 0);
            name_entry_box.pack_start (name_entry, true, true, 0);

/*
            format_entry = new Entry ();
            format_entry.text = "None";
            var format_entry_l = new Label (_("Code highlight:"));
            var format_entry_box = new HBox (false, 10);
            format_entry_box.pack_start (format_entry_l, false, true, 0);
            format_entry_box.pack_start (format_entry, true, true, 0);
*/


            format_combo = new ComboBoxText ();

			for (var i=0; i < languages.length[0]; i++)
				if ( (languages[i, 3] != "") || (languages[i, 0] == "y")) format_combo.append (languages[i, 1], languages[i, 2]);

			format_combo.set_active_id("text");
            var format_combo_l = new Label (_("Format:"));
            var format_combo_box = new HBox (false, 28);
            format_combo_box.pack_start (format_combo_l, false, true, 0);
            format_combo_box.pack_start (format_combo, true, true, 0);


            expiry_combo = new ComboBoxText ();
            populate_expiry_combo ();
            var expiry_combo_l = new Label (_("Expiry time:"));
            var expiry_combo_box = new HBox (false, 28);
            expiry_combo_box.pack_start (expiry_combo_l, false, true, 0);
            expiry_combo_box.pack_start (expiry_combo, true, true, 0);

            private_check = new CheckButton.with_label (_("Keep this paste private"));

            cancel_button = new Button.from_stock (Stock.CANCEL);
            send_button = new Button.with_label ("Upload");

            var bottom_buttons = new HButtonBox ();
            bottom_buttons.set_layout (ButtonBoxStyle.CENTER);
            bottom_buttons.set_spacing (10);
            bottom_buttons.pack_start (cancel_button);
            bottom_buttons.pack_end (send_button);

            content.pack_start (wrap_alignment (name_entry_box, 12, 0, 0, 0), true, true, 0);
            content.pack_start (format_combo_box, true, true, 0);
            content.pack_start (expiry_combo_box, true, true, 0);
            content.pack_start (private_check, true, true, 0);
            content.pack_end (bottom_buttons, true, true, 12);

            padding.pack_start (content, false, true, 12);

            add (padding);

            read_settings ();

            show_all ();
            send_button.grab_focus ();

        }

        private static Alignment wrap_alignment (Widget widget, int top, int right,
                                                 int bottom, int left) {

            var alignment = new Alignment (0.0f, 0.0f, 1.0f, 1.0f);
            alignment.top_padding = top;
            alignment.right_padding = right;
            alignment.bottom_padding = bottom;
            alignment.left_padding = left;
            
            alignment.add(widget);
            return alignment;

        }

        private void read_settings () {

            string paste_name = window.current_tab.label.label.label;
            name_entry.text = paste_name;

//            format_entry.text = Scratch.services.paste_format_code;
            expiry_combo.set_active_id (Scratch.services.expiry_time);
            private_check.set_active (Scratch.services.set_private);

        }

        private void write_settings () {

//            Scratch.services.paste_format_code = format_entry.text;
            Scratch.services.expiry_time = expiry_combo.get_active_id ();
            Scratch.services.set_private = private_check.get_active ();

        }

        private void cancel_button_clicked () {
            
            write_settings ();
            this.destroy ();

        }

        private void close_button_clicked () {
            
            write_settings ();
            this.destroy ();

        }

        private void send_button_clicked () {

            content.hide ();

            // Probably your connection is too fast to not see this
            var spinner = new Spinner ();
            padding.pack_start (spinner, true, true, 10);
            spinner.show ();
            spinner.start ();

            string link;
            var submit_result = submit_paste (out link);

            // Show the new view
            spinner.hide ();

            var box = new VBox (false, 10);
           
            if (submit_result == 0) {
            
                //paste successfully
                var link_button = new LinkButton (link);
                box.pack_start (link_button, false, true, 0);                
                set_clipboard (link);
            } else {
            
                //paste error
                var error_desc = new StringBuilder();
                
                switch(submit_result) {
                    case 2:
                    error_desc.append(_("The text is void!"));
                    break;

                    case 3:
                    error_desc.append(_("The text format doesn't exist"));
                    break;
                    
                    default:
                    error_desc.append(_("An error occured"));                    
                    break;
                       
                }

                error_desc.append("\n" + _("The text is sended"));
                var err_label = new Label(error_desc.str);

                box.pack_start (err_label, false, true, 0);
            }

            var close_button = new Button.from_stock (Stock.CLOSE);
            box.pack_start (close_button, false, true, 0);            
            padding.pack_start (box, false, true, 12);
            padding.halign = Align.CENTER;
            box.valign = Align.CENTER;
            box.show_all ();
            // Connect signal
            close_button.clicked.connect (close_button_clicked);


        }

        private int submit_paste (out string link) {

            // Get the values
            
            string paste_code = window.current_tab.text_view.buffer.text;
            string paste_name = name_entry.text;
//            string paste_format = format_entry.text;
			string paste_format = "text";
            string paste_private = private_check.get_active () == true ? PasteBin.PRIVATE : PasteBin.PUBLIC;
            string paste_expire_date = expiry_combo.get_active_id ();

            int submit_result = PasteBin.submit (out link, paste_code, paste_name, paste_private,
                                           paste_expire_date, paste_format);

            return submit_result;


        }

        
        private void set_clipboard (string link) {

            var display = window.get_display ();
            var clipboard = Clipboard.get_for_display (display, Gdk.SELECTION_CLIPBOARD);
            clipboard.set_text (link, -1);

        }

        private void populate_expiry_combo () {

            expiry_combo.append (PasteBin.NEVER, _("Never"));
            expiry_combo.append (PasteBin.TEN_MINUTES, _("Ten minutes"));
            expiry_combo.append (PasteBin.HOUR, _("One hour"));
            expiry_combo.append (PasteBin.DAY, _("One day"));
            expiry_combo.append (PasteBin.MONTH, _("One month"));

        }

     }

}
