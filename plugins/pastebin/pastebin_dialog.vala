// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/***
  BEGIN LICENSE
	
  Copyright (C) 2011-2012 Giulio Collura <random.cpp@gmail.com>
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

    public class PasteBinDialog : Granite.Widgets.LightWindow {
        
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
			{"n", "text", "None", "text"},
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
            
            private Scratch.Services.Document doc;
            
			private Box content;
			private Box padding;

			private Entry name_entry;
			private ComboBoxText expiry_combo;
			private CheckButton private_check;
			
			private ComboBoxText format_combo;
			private Window format_others_win;
			private TreeView format_others_view;
			private ListStore format_store;

			private Button send_button;

        
        public PasteBinDialog (Gtk.Window? parent, Scratch.Services.Document doc) {
            this.doc = doc; 
            
            if (parent != null)
                this.set_transient_for (parent);
            set_modal (true);
            this.title = _("Share via PasteBin");
            this.type_hint = Gdk.WindowTypeHint.DIALOG;
            
            create_dialog ();

            send_button.clicked.connect (send_button_clicked);
            this.destroy.connect (() => {
                write_settings ();
            });
        }

        private void create_dialog () {

            content = new Box (Gtk.Orientation.VERTICAL, 10);
            padding = new Box (Gtk.Orientation.HORIZONTAL, 10);

            name_entry = new Entry ();
            name_entry.text = "Test";
            var name_entry_l = new Label (_("Name:"));
            var name_entry_box = new Box (Gtk.Orientation.HORIZONTAL, 58);
            name_entry_box.pack_start (name_entry_l, false, true, 0);
            name_entry_box.pack_start (name_entry, true, true, 0);


			var format_label = new Label (_("Format: "));
			format_combo = new ComboBoxText();
			var format_button = new Button.with_label (_("Others..."));
				format_button.clicked.connect (format_button_clicked);
			
			//populate combo box
			var sel_lang = doc.get_language_id ();
			for (var i=0; i < languages.length[0]; i++) {
			
				//insert all languages that are in the scratch combo, and also those that are marked with "y"
				if ( (languages[i, 3] != "") || (languages[i, 0] == "y")) format_combo.append (languages[i, 1], languages[i, 2]);
				//if the inserted language is selected in scratch combo, select it as default
				if ( languages[i, 3] == sel_lang ) format_combo.set_active_id(languages[i, 1]);
			}
			
			//if no language is selected, select text as default
			if (format_combo.get_active_id() == null) format_combo.set_active_id("text");
		
		
			var format_box = new Box (Gtk.Orientation.HORIZONTAL, 28);
			format_box.pack_start (format_label);
			format_box.pack_start (format_combo);
			format_box.pack_start (format_button);
			

            expiry_combo = new ComboBoxText ();
            populate_expiry_combo ();
            var expiry_combo_l = new Label (_("Expiry time:"));
            var expiry_combo_box = new Box (Gtk.Orientation.HORIZONTAL, 28);
            expiry_combo_box.pack_start (expiry_combo_l, false, true, 0);
            expiry_combo_box.pack_start (expiry_combo, true, true, 0);

            private_check = new CheckButton.with_label (_("Keep this paste private"));

            send_button = new Button.with_label (_("Upload"));

            var bottom_buttons = new ButtonBox (Gtk.Orientation.HORIZONTAL);
            bottom_buttons.set_layout (ButtonBoxStyle.CENTER);
            bottom_buttons.set_spacing (10);
            bottom_buttons.pack_end (send_button);

            content.pack_start (wrap_alignment (name_entry_box, 12, 0, 0, 0), true, true, 0);
            content.pack_start (format_box, true, true, 0);
            content.pack_start (expiry_combo_box, true, true, 0);
            content.pack_start (private_check, true, true, 0);
            content.pack_end (bottom_buttons, true, true, 12);

            padding.pack_start (content, false, true, 12);

            add (padding);

            read_settings ();

            show_all ();
            
            send_button.grab_focus ();

        }


		private void format_button_clicked() {
		
			format_others_win = new Window();
			format_others_win.set_modal(true);
			format_others_win.set_title(_("Other formats"));
			format_others_win.set_default_size (250, 300);
			
				format_others_view = new TreeView();
		        format_others_view.set_headers_visible(false);
				format_store = new ListStore (2, typeof (string), typeof (string));
				format_others_view.set_model (format_store);
				format_others_view.insert_column_with_attributes (-1, "Language", new CellRendererText (), "text", 0);				

				TreeIter iter;
				for (var i=0; i < languages.length[0]; i++) {			
					format_store.append (out iter);
					format_store.set (iter, 0, languages[i, 2], 1, languages[i, 1]);
				}

			var format_others_scroll = new ScrolledWindow(null, null);
				format_others_scroll.add(format_others_view);
				
			var format_others_ok = new Button.from_stock ("gtk-ok");
				format_others_ok.clicked.connect (format_others_ok_clicked);			
			var format_others_cancel = new Button.from_stock ("gtk-cancel");
				format_others_cancel.clicked.connect (format_others_cancel_clicked);
			var format_others_buttons = new ButtonBox (Orientation.HORIZONTAL);
				format_others_buttons.set_layout (ButtonBoxStyle.CENTER);
				format_others_buttons.pack_start (format_others_cancel);
				format_others_buttons.pack_start (format_others_ok);
				
			var format_others_box = new Box (Gtk.Orientation.VERTICAL, 10);
				format_others_box.pack_start (format_others_scroll);
				format_others_box.pack_start (format_others_buttons);				
				
			format_others_win.add (format_others_box);
			format_others_win.show_all();
	
		}
		
		private void format_others_cancel_clicked() {
			format_others_win.destroy();
		}

		private void format_others_ok_clicked() {
		
			var selection = format_others_view.get_selection ();
			TreeIter iter;
			if (selection.get_selected (null, out iter) == true) {
			
				Value lang_name;
				Value lang_code;				
				format_store.get_value(iter, 0, out lang_name);
				format_store.get_value(iter, 1, out lang_code);
				
				format_combo.append ((string) lang_code, (string) lang_name);
				format_combo.set_active_id((string) lang_code);
				
			}
			
			format_others_win.destroy();
			
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

            string paste_name = this.doc.get_basename ();
            name_entry.text = paste_name;

//            format_entry.text = Scratch.services.paste_format_code;
            expiry_combo.set_active_id (Scratch.services.expiry_time);
            private_check.set_active (Scratch.services.set_private);

        }

        private void write_settings () {

            Scratch.services.paste_format_code = format_combo.get_active_id();
            Scratch.services.expiry_time = expiry_combo.get_active_id ();
            Scratch.services.set_private = private_check.get_active ();

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

            var box = new Box (Gtk.Orientation.VERTICAL, 10);
           
            if (submit_result == 0) {
            
                //paste successfully
                var link_button = new LinkButton (link);
                box.pack_start (link_button, false, true, 25);
            } else {
            
                //paste error
                var error_desc = new StringBuilder();
                
                switch(submit_result) {
                    case 2:
                    error_desc.append("The text is void!");
                    break;

                    case 3:
                    error_desc.append("The text format doesn't exist");
                    break;
                    
                    default:
                    error_desc.append("An error occured");                    
                    break;
                       
                }

                error_desc.append("\n" + "The text was sent");
                var err_label = new Label(error_desc.str);

                box.pack_start (err_label, false, true, 0);
            }

            padding.pack_start (box, false, true, 12);
            padding.halign = Align.CENTER;
            box.valign = Align.CENTER;
            box.show_all ();
        }


        private int submit_paste (out string link) {

            // Get the values
            string paste_code = this.doc.get_text ();
            string paste_name = name_entry.text;
            string paste_format = format_combo.get_active_id ();
            string paste_private = private_check.get_active () == true ? PasteBin.PRIVATE : PasteBin.PUBLIC;
            string paste_expire_date = expiry_combo.get_active_id ();

            int submit_result = PasteBin.submit (out link, paste_code, paste_name, paste_private,
                                           paste_expire_date, paste_format);

            return submit_result;


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
