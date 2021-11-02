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

using Scratch.Services;

namespace Scratch.Dialogs {

    public class PasteBinDialog : Granite.Dialog {

        public string[,] languages = {
            //if default, code, desc, Code-equivalent
            {"n", "text", "None", "text"},
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
            {"n", "zxbasic", "ZXBasic", ""}
        };

        public Scratch.Services.Document doc { get; construct; }

        private Gtk.Button close_button;
        private Gtk.Button upload_button;
        private Gtk.Entry name_entry;
        private Gtk.ComboBoxText expiry_combo;
        private Gtk.CheckButton private_check;
        private Gtk.ComboBoxText format_combo;
        private Granite.Dialog format_dialog;
        private Gtk.Stack stack;
        private Gtk.ListBox languages_listbox;

        public PasteBinDialog (Gtk.Window? parent, Scratch.Services.Document doc) {
            Object (
                resizable: false,
                doc: doc,
                transient_for: parent,
                title: _("Upload to Pastebin")
            );
        }

        construct {
            name_entry = new Gtk.Entry () {
                hexpand = true
            };

            var name_entry_l = new Gtk.Label (_("Name:")) {
                halign = Gtk.Align.END
            };

            var format_label = new Gtk.Label (_("Format:")) {
                halign = Gtk.Align.END
            };

            format_combo = new Gtk.ComboBoxText ();

            var format_button = new Gtk.Button.from_icon_name ("view-more-horizontal-symbolic") {
                tooltip_text = _("Choose different format")
            };

            //populate combo box
            var sel_lang = doc.get_language_id ();
            for (var i = 0; i < languages.length[0]; i++) {
                //insert all languages that are in the Code combo, and also those that are marked with "y"
                if ((languages[i, 3] != "") || (languages[i, 0] == "y")) {
                    format_combo.append (languages[i, 1], languages[i, 2]);
                }

                //if the inserted language is selected in Code combo, select it as default
                if (languages[i, 3] == sel_lang ) {
                    format_combo.set_active_id (languages[i, 1]);
                }
            }

            //if no language is selected, select text as default
            if (format_combo.get_active_id () == null) {
                format_combo.set_active_id ("text");
            }

            var expiry_combo_l = new Gtk.Label (_("Expiration:")) {
                halign = Gtk.Align.END
            };

            expiry_combo = new Gtk.ComboBoxText ();
            populate_expiry_combo ();

            private_check = new Gtk.CheckButton.with_label (_("Keep this paste private"));

            var grid = new Gtk.Grid () {
                column_spacing = 6,
                row_spacing = 12
            };
            grid.attach (name_entry_l, 0, 0, 1, 1);
            grid.attach (name_entry, 1, 0, 1, 1);
            grid.attach (format_label, 0, 1, 1, 1);
            grid.attach (format_combo, 1, 1, 1, 1);
            grid.attach (format_button, 2, 1, 1, 1);
            grid.attach (expiry_combo_l, 0, 2, 1, 1);
            grid.attach (expiry_combo, 1, 2, 1, 1);
            grid.attach (private_check, 1, 3, 1, 1);

            var spinner = new Gtk.Spinner () {
                active = true,
                height_request = 32,
                valign = Gtk.Align.CENTER
            };

            stack = new Gtk.Stack () {
                margin = 12,
                margin_top = 0
            };
            stack.add (grid);
            stack.add (spinner);

            get_content_area ().add (stack);

            close_button = (Gtk.Button)add_button (_("Cancel"), Gtk.ResponseType.CANCEL);
            upload_button = (Gtk.Button)add_button (_("Upload to Pastebin"), Gtk.ResponseType.OK);
            upload_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);

            read_settings ();

            show_all ();

            format_button.clicked.connect (format_button_clicked);

            upload_button.clicked.connect (() => {
                stack.visible_child = spinner;
                upload_button_clicked ();
            });

            close_button.clicked.connect (() => {
                destroy ();
            });

            this.destroy.connect (() => {
                write_settings ();
            });
        }

        private void format_button_clicked () {
            format_dialog = new Granite.Dialog () {
                resizable = false,
                title = _("Available Formats")
            };
            format_dialog.set_default_size (220, 300);

            languages_listbox = new Gtk.ListBox () {
                selection_mode = Gtk.SelectionMode.SINGLE
            };

            for (var i=0; i < languages.length[0]; i++) {
                var label = new Gtk.Label (languages[i, 2]) {
                    halign = Gtk.Align.START,
                    margin = 6
                };

                languages_listbox.add (label);
            }

            var languages_scrolled = new Gtk.ScrolledWindow (null, null) {
                hscrollbar_policy = Gtk.PolicyType.NEVER,
                height_request = 250,
                expand = true
            };
            languages_scrolled.add (languages_listbox);

            var cancel_button = (Gtk.Button)format_dialog.add_button (_("Cancel"), Gtk.ResponseType.CANCEL);

            var select_button = (Gtk.Button)format_dialog.add_button (_("Select Format"), Gtk.ResponseType.OK);
            select_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);
            select_button.clicked.connect (select_button_clicked);

            var frame = new Gtk.Frame (null) {
                margin = 12,
                margin_top = 0
            };
            frame.add (languages_scrolled);

            format_dialog.get_content_area ().add (frame);
            format_dialog.show_all ();

            cancel_button.clicked.connect (() => {
                format_dialog.destroy ();
            });
        }

        private void select_button_clicked () {
            var selection = languages_listbox.get_selected_row ();
            if (selection != null) {
                var label = (Gtk.Label)selection.get_child ();
                var lang_name = label.label;
                var lang_code = "";

                for (var i=0; i < languages.length[0]; i++) {
                    if (languages[i, 2] == lang_name) {
                        lang_code = languages[i, 1];
                        format_combo.append (lang_code, lang_name);
                        format_combo.set_active_id (lang_code);
                        break;
                    }
                }
            }

            format_dialog.destroy ();
        }

        private void read_settings () {
            string paste_name = this.doc.get_basename ();
            name_entry.text = paste_name;

            expiry_combo.set_active_id (Scratch.service_settings.get_string ("expiry-time"));
            private_check.set_active (Scratch.service_settings.get_boolean ("set-private"));
        }

        private void write_settings () {
            Scratch.service_settings.set_string ("paste-format-code", format_combo.active_id);
            Scratch.service_settings.set_string ("expiry-time", expiry_combo.active_id);
            Scratch.service_settings.set_boolean ("set-private", private_check.active);
        }

        private void upload_button_clicked () {
            upload_button.sensitive = false;
            close_button.label = _("Close");

            string link;
            var submit_result = submit_paste (out link);

            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 10);
            stack.add (box);

            if (submit_result) {
                //paste successfully
                var link_button = new Gtk.LinkButton (link);
                box.pack_start (link_button, false, true, 25);
            } else {
                var err_label = new Gtk.Label (link);
                box.pack_start (err_label, false, true, 0);
            }

            box.show_all ();
            stack.visible_child = box;
        }

        private bool submit_paste (out string link) {
            // Get the values
            string paste_code = this.doc.get_text ();
            string paste_name = name_entry.text;
            string paste_format = format_combo.get_active_id ();
            string paste_private = private_check.get_active () == true ? PasteBin.PRIVATE : PasteBin.PUBLIC;
            string paste_expire_date = expiry_combo.get_active_id ();

            return PasteBin.submit (out link, paste_code, paste_name, paste_private, paste_expire_date, paste_format);
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
